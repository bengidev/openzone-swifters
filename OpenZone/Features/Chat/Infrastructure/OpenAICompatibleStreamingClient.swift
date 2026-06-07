import Foundation

/// An OpenAI-compatible, provider-agnostic streaming chat client.
///
/// Parameterized by a `ChatProvider` descriptor plus a `ChatCredentialProvider`,
/// this single client serves OpenRouter and any other OpenAI-shaped backend. It
/// conforms to the existing `ChatAPIClientProtocol` seam, so the reducer and UI
/// never learn which provider is behind them.
///
/// Wire behavior:
///   - POSTs an OpenAI `chat/completions` request with `stream: true`;
///   - resolves the secret at request time (never captured at construction);
///   - decodes the SSE byte stream with the generic `ServerSentEventsLineDecoder`;
///   - maps `choices[].delta.content` to `.textDelta`, `delta.reasoning` (and
///     `reasoning_content`) to `.thinkingDelta`, the `[DONE]` sentinel to `.done`;
///   - maps HTTP 401, non-2xx responses, mid-stream `error` objects, and
///     transport failures to `.error`.
nonisolated struct OpenAICompatibleStreamingClient: ChatAPIClientProtocol, Sendable {
    let provider: ChatProvider
    let credentialProvider: ChatCredentialProvider
    let urlSession: URLSession

    init(
        provider: ChatProvider,
        credentialProvider: ChatCredentialProvider,
        urlSession: URLSession = .shared
    ) {
        self.provider = provider
        self.credentialProvider = credentialProvider
        self.urlSession = urlSession
    }

    nonisolated func stream(request: ChatRequest) -> AsyncStream<ChatStreamingEvent> {
        let provider = self.provider
        let credentialProvider = self.credentialProvider
        let urlSession = self.urlSession

        return AsyncStream { continuation in
            let task = Task {
                do {
                    guard let secret = credentialProvider.resolve() else {
                        continuation.yield(.error("Missing API key. Add your provider key to continue."))
                        continuation.finish()
                        return
                    }

                    let urlRequest = try Self.makeURLRequest(
                        provider: provider,
                        secret: secret,
                        chatRequest: request
                    )

                    let (bytes, response) = try await urlSession.bytes(for: urlRequest)

                    if let httpResponse = response as? HTTPURLResponse,
                       !(200...299).contains(httpResponse.statusCode) {
                        let message = await Self.errorMessage(
                            forStatus: httpResponse.statusCode,
                            bytes: bytes
                        )
                        continuation.yield(.error(ChatStreamError(message: message)))
                        continuation.finish()
                        return
                    }

                    var decoder = ServerSentEventsLineDecoder()
                    var didEmitDone = false

                    for try await line in bytes.lines {
                        // `bytes.lines` already splits on newlines; re-feed each
                        // line (with a trailing newline) through the SSE decoder
                        // so comment-skipping, done-sentinel, and field parsing
                        // live in one tested place.
                        guard let lineData = (line + "\n").data(using: .utf8) else { continue }
                        for event in decoder.append(lineData) {
                            switch event {
                            case .done:
                                continuation.yield(.done)
                                didEmitDone = true
                            case let .data(payload):
                                if let mapped = Self.mapDataPayload(payload) {
                                    for chatEvent in mapped {
                                        continuation.yield(chatEvent)
                                        if case .error = chatEvent { didEmitDone = true }
                                    }
                                }
                            }
                        }
                        if didEmitDone { break }
                    }

                    if !didEmitDone {
                        // Stream ended without an explicit sentinel — treat a
                        // clean close as completion.
                        continuation.yield(.done)
                    }
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.yield(.error(ChatStreamError(message: error.localizedDescription)))
                    continuation.finish()
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    // MARK: - Request construction

    static func makeURLRequest(
        provider: ChatProvider,
        secret: String,
        chatRequest: ChatRequest
    ) throws -> URLRequest {
        var urlRequest = URLRequest(url: provider.chatCompletionsURL)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("text/event-stream", forHTTPHeaderField: "Accept")

        for (field, value) in provider.defaultHeaders {
            urlRequest.setValue(value, forHTTPHeaderField: field)
        }

        switch provider.authScheme {
        case .bearer:
            urlRequest.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")
        }

        let payload = ChatCompletionsRequestBody(
            model: chatRequest.modelID,
            messages: Self.wireMessages(from: chatRequest.messages),
            stream: true
        )
        urlRequest.httpBody = try JSONEncoder().encode(payload)
        return urlRequest
    }

    /// Maps domain messages to OpenAI wire messages. Thinking rows are internal
    /// UI state and are never sent upstream; only user/assistant/system text
    /// participates in the prompt.
    static func wireMessages(from messages: [ChatMessage]) -> [ChatCompletionsRequestBody.Message] {
        messages.compactMap { message in
            switch message {
            case let .text(text):
                return ChatCompletionsRequestBody.Message(
                    role: text.role.rawValue,
                    content: text.content
                )
            case let .system(system):
                return ChatCompletionsRequestBody.Message(
                    role: system.role.rawValue,
                    content: system.content
                )
            case .thinking:
                return nil
            }
        }
    }

    // MARK: - Response mapping

    /// Maps one `data:` payload's JSON to zero or more chat events.
    static func mapDataPayload(_ payload: String) -> [ChatStreamingEvent]? {
        guard let data = payload.data(using: .utf8) else { return nil }

        let chunk = try? JSONDecoder().decode(ChatCompletionsStreamChunk.self, from: data)
        guard let chunk else { return nil }

        // A mid-stream error object maps to the error event.
        if let error = chunk.error {
            return [.error(ChatStreamError(message: error.message))]
        }

        var events: [ChatStreamingEvent] = []
        for choice in chunk.choices ?? [] {
            if let reasoning = choice.delta?.reasoningText, !reasoning.isEmpty {
                events.append(.thinkingDelta(reasoning))
            }
            if let content = choice.delta?.content, !content.isEmpty {
                events.append(.textDelta(content))
            }
        }
        return events.isEmpty ? nil : events
    }

    /// Builds a human-facing message for a non-2xx HTTP response, draining the
    /// body for a provider error string when present.
    static func errorMessage(forStatus status: Int, bytes: URLSession.AsyncBytes) async -> String {
        var body = Data()
        var iterator = bytes.makeAsyncIterator()
        // Cap the drained body so a hostile/huge error body cannot grow unbounded.
        while body.count < 64 * 1024, let byte = try? await iterator.next() {
            body.append(byte)
        }

        if status == 401 {
            return "Unauthorized (401). Check that your API key is valid."
        }

        if let providerMessage = decodeErrorBody(body) {
            return "Request failed (\(status)): \(providerMessage)"
        }
        return "Request failed with status \(status)."
    }

    static func decodeErrorBody(_ data: Data) -> String? {
        guard !data.isEmpty,
              let envelope = try? JSONDecoder().decode(ChatCompletionsErrorEnvelope.self, from: data)
        else { return nil }
        return envelope.error?.message
    }
}

// MARK: - Wire types

/// OpenAI-compatible request body (subset used by this slice).
nonisolated struct ChatCompletionsRequestBody: Encodable, Sendable {
    nonisolated struct Message: Encodable, Sendable {
        let role: String
        let content: String
    }

    let model: String
    let messages: [Message]
    let stream: Bool
}

/// One streamed SSE chunk (`chat.completion.chunk`), decoding only the fields
/// this slice consumes.
nonisolated struct ChatCompletionsStreamChunk: Decodable, Sendable {
    nonisolated struct Choice: Decodable, Sendable {
        let delta: Delta?
    }

    nonisolated struct Delta: Decodable, Sendable {
        let content: String?
        let reasoning: String?
        let reasoningContent: String?

        /// Providers disagree on the reasoning field name; accept both
        /// `reasoning` (OpenRouter) and `reasoning_content` (others).
        var reasoningText: String? {
            reasoning ?? reasoningContent
        }

        enum CodingKeys: String, CodingKey {
            case content
            case reasoning
            case reasoningContent = "reasoning_content"
        }
    }

    let choices: [Choice]?
    let error: ErrorPayload?
}

/// A provider error object, whether mid-stream or in a non-2xx body.
nonisolated struct ChatCompletionsErrorEnvelope: Decodable, Sendable {
    let error: ErrorPayload?
}

nonisolated struct ErrorPayload: Decodable, Sendable {
    let message: String
    let code: String?

    enum CodingKeys: String, CodingKey {
        case message
        case code
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.message = (try? container.decode(String.self, forKey: .message)) ?? "Unknown error"
        // `code` is sometimes a string, sometimes an int; decode leniently.
        if let stringCode = try? container.decode(String.self, forKey: .code) {
            self.code = stringCode
        } else if let intCode = try? container.decode(Int.self, forKey: .code) {
            self.code = String(intCode)
        } else {
            self.code = nil
        }
    }
}
