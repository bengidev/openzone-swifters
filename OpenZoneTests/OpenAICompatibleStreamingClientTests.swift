import Foundation
import Testing

@testable import OpenZone

/// URLProtocol stub that returns canned HTTP + SSE responses with no real
/// network. Each test installs a response (status + body) and the client reads
/// it through a `URLSession` configured with this protocol.
nonisolated final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    struct Stub: Sendable {
        var statusCode: Int
        var body: Data
        var headers: [String: String]
    }

    // Protected by the URL loading system's serial use per session config.
    nonisolated(unsafe) static var stub: Stub?
    nonisolated(unsafe) static var lastRequestBody: Data?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        // Capture the outgoing body (URLProtocol strips httpBody into a stream,
        // so read it back from the body stream when present).
        if let stream = request.httpBodyStream {
            stream.open()
            var data = Data()
            let bufferSize = 4096
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
            while stream.hasBytesAvailable {
                let read = stream.read(buffer, maxLength: bufferSize)
                if read <= 0 { break }
                data.append(buffer, count: read)
            }
            buffer.deallocate()
            stream.close()
            Self.lastRequestBody = data
        } else {
            Self.lastRequestBody = request.httpBody
        }

        let stub = Self.stub ?? Stub(statusCode: 200, body: Data(), headers: [:])
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: stub.statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: stub.headers
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: stub.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

@Suite("OpenAI-Compatible Streaming Client", .serialized)
struct OpenAICompatibleStreamingClientTests {

    private func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    private func makeClient(secret: String? = "test-key") -> OpenAICompatibleStreamingClient {
        OpenAICompatibleStreamingClient(
            credentialProvider: AIProviderCredentialAPI { _ in secret },
            urlSession: makeSession()
        )
    }

    private func request() -> ChatRequest {
        ChatRequest(
            conversationID: UUID(),
            messages: [.text(role: .user, content: "Hello")],
            provider: .openRouter,
            modelID: "meta-llama/llama-3.3-70b-instruct:free"
        )
    }

    private func collect(_ stream: AsyncStream<ChatStreamingEvent>) async -> [ChatStreamingEvent] {
        var events: [ChatStreamingEvent] = []
        for await event in stream { events.append(event) }
        return events
    }

    @Test("Content deltas map to text events and [DONE] terminates")
    func contentDeltasMapToTextEvents() async {
        let sse = """
        data: {"choices":[{"delta":{"content":"Hello"}}]}

        data: {"choices":[{"delta":{"content":" world"}}]}

        data: [DONE]

        """
        StubURLProtocol.stub = .init(statusCode: 200, body: Data(sse.utf8), headers: ["Content-Type": "text/event-stream"])

        let events = await collect(makeClient().stream(request: request()))

        #expect(events == [.textDelta("Hello"), .textDelta(" world"), .done])
    }

    @Test("Reasoning deltas map to thinking events")
    func reasoningDeltasMapToThinking() async {
        let sse = """
        data: {"choices":[{"delta":{"reasoning":"Weighing "}}]}

        data: {"choices":[{"delta":{"reasoning":"options."}}]}

        data: {"choices":[{"delta":{"content":"Answer"}}]}

        data: [DONE]

        """
        StubURLProtocol.stub = .init(statusCode: 200, body: Data(sse.utf8), headers: [:])

        let events = await collect(makeClient().stream(request: request()))

        #expect(events == [
            .thinkingDelta("Weighing "),
            .thinkingDelta("options."),
            .textDelta("Answer"),
            .done
        ])
    }

    @Test("reasoning_content field also maps to thinking events")
    func reasoningContentFieldMapsToThinking() async {
        let sse = """
        data: {"choices":[{"delta":{"reasoning_content":"hmm"}}]}

        data: [DONE]

        """
        StubURLProtocol.stub = .init(statusCode: 200, body: Data(sse.utf8), headers: [:])

        let events = await collect(makeClient().stream(request: request()))

        #expect(events == [.thinkingDelta("hmm"), .done])
    }

    @Test("Keep-alive comment lines are skipped in the stream")
    func keepAliveCommentsSkipped() async {
        let sse = """
        : OPENROUTER PROCESSING
        data: {"choices":[{"delta":{"content":"ok"}}]}

        data: [DONE]

        """
        StubURLProtocol.stub = .init(statusCode: 200, body: Data(sse.utf8), headers: [:])

        let events = await collect(makeClient().stream(request: request()))

        #expect(events == [.textDelta("ok"), .done])
    }

    @Test("HTTP 401 maps to an error event")
    func http401MapsToError() async {
        let body = #"{"error":{"message":"No auth credentials found","code":401}}"#
        StubURLProtocol.stub = .init(statusCode: 401, body: Data(body.utf8), headers: [:])

        let events = await collect(makeClient().stream(request: request()))

        #expect(events.count == 1)
        guard case let .error(streamError) = events.first else {
            Issue.record("Expected an error event, got \(String(describing: events.first))")
            return
        }
        #expect(streamError.message.contains("401"))
    }

    @Test("Missing credential short-circuits to an error event")
    func missingCredentialMapsToError() async {
        StubURLProtocol.stub = .init(statusCode: 200, body: Data(), headers: [:])

        let events = await collect(makeClient(secret: nil).stream(request: request()))

        #expect(events.count == 1)
        guard case let .error(streamError) = events.first else {
            Issue.record("Expected an error event, got \(String(describing: events.first))")
            return
        }
        #expect(streamError.message.contains("API key"))
    }

    @Test("Non-2xx with provider error body surfaces the provider message")
    func providerErrorBodySurfaced() async {
        let body = #"{"error":{"message":"Rate limited","code":429}}"#
        StubURLProtocol.stub = .init(statusCode: 429, body: Data(body.utf8), headers: [:])

        let events = await collect(makeClient().stream(request: request()))

        guard case let .error(streamError) = events.first else {
            Issue.record("Expected an error event")
            return
        }
        #expect(streamError.message.contains("Rate limited"))
        #expect(streamError.message.contains("429"))
    }

    @Test("Mid-stream error object maps to an error event")
    func midStreamErrorMapsToError() async {
        let sse = """
        data: {"choices":[{"delta":{"content":"partial"}}]}

        data: {"error":{"message":"upstream exploded"}}

        """
        StubURLProtocol.stub = .init(statusCode: 200, body: Data(sse.utf8), headers: [:])

        let events = await collect(makeClient().stream(request: request()))

        #expect(events.first == .textDelta("partial"))
        guard case let .error(streamError) = events.last else {
            Issue.record("Expected a trailing error event")
            return
        }
        #expect(streamError.message.contains("upstream exploded"))
    }

    @Test("Request body carries model, stream flag, and user message")
    func requestBodyShape() async {
        let sse = "data: [DONE]\n\n"
        StubURLProtocol.stub = .init(statusCode: 200, body: Data(sse.utf8), headers: [:])

        _ = await collect(makeClient().stream(request: request()))

        guard let body = StubURLProtocol.lastRequestBody,
              let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else {
            Issue.record("Expected a JSON request body")
            return
        }
        #expect(json["model"] as? String == "meta-llama/llama-3.3-70b-instruct:free")
        #expect(json["stream"] as? Bool == true)
        let messages = json["messages"] as? [[String: Any]]
        #expect(messages?.first?["role"] as? String == "user")
        #expect(messages?.first?["content"] as? String == "Hello")
    }

    // MARK: - Reasoning effort (Slice 5)

    private func reasoningRequest(effort: String?) -> ChatRequest {
        ChatRequest(
            conversationID: UUID(),
            messages: [.text(role: .user, content: "Hello")],
            provider: .openRouter,
            modelID: "deepseek/deepseek-r1:free",
            reasoningEffort: effort
        )
    }

    private func bodyJSON(for request: ChatRequest) async -> [String: Any]? {
        let sse = "data: [DONE]\n\n"
        StubURLProtocol.stub = .init(statusCode: 200, body: Data(sse.utf8), headers: [:])
        _ = await collect(makeClient().stream(request: request))
        guard let body = StubURLProtocol.lastRequestBody else { return nil }
        return try? JSONSerialization.jsonObject(with: body) as? [String: Any]
    }

    @Test("A selected effort emits reasoning.effort on the wire")
    func emitsReasoningEffort() async {
        guard let json = await bodyJSON(for: reasoningRequest(effort: "high")) else {
            Issue.record("Expected a JSON request body")
            return
        }
        let reasoning = json["reasoning"] as? [String: Any]
        #expect(reasoning?["effort"] as? String == "high")
    }

    @Test("No selected effort omits the reasoning parameter entirely")
    func omitsReasoningWhenNil() async {
        guard let json = await bodyJSON(for: reasoningRequest(effort: nil)) else {
            Issue.record("Expected a JSON request body")
            return
        }
        #expect(json["reasoning"] == nil)
        #expect(json["model"] as? String == "deepseek/deepseek-r1:free")
        #expect(json["stream"] as? Bool == true)
    }
}
