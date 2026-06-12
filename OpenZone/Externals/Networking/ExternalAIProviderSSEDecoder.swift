import Foundation

/// Externals networking primitive: it knows nothing about chat, models,
/// or any feature vocabulary. It buffers raw bytes arriving across arbitrary
/// network chunk boundaries, splits them into complete lines on `\n`, and
/// interprets each line under the SSE wire rules:
///
///   - lines beginning with `:` are keep-alive comments and are skipped;
///   - blank lines are event separators and are skipped;
///   - `data:` lines yield their payload (one leading space after the colon is
///     stripped, per the SSE spec);
///   - a `data:` payload equal to the done sentinel terminates the stream.
///
/// Partial lines are retained in the buffer until their terminating newline
/// arrives, so a multi-byte UTF-8 sequence or a half-delivered JSON object is
/// never decoded prematurely.
nonisolated struct ExternalAIProviderSSEDecoder: Sendable {
    /// The OpenAI/OpenRouter stream-termination sentinel.
    static let doneSentinel = "[DONE]"

    /// A semantic SSE result. Generic on purpose — callers map `.data` payloads
    /// to their own domain events.
    enum Event: Equatable, Sendable {
        case data(String)
        case done
    }

    private var buffer: [UInt8] = []
    private let newline = UInt8(ascii: "\n")

    init() {}

    /// Feeds the next raw network chunk and returns any complete SSE events it
    /// completed. Bytes that do not yet form a full line are retained.
    mutating func append(_ data: Data) -> [Event] {
        buffer.append(contentsOf: data)

        var events: [Event] = []
        var lineStart = 0
        var index = 0
        while index < buffer.count {
            if buffer[index] == newline {
                let lineBytes = buffer[lineStart..<index]
                let rawLine = String(bytes: lineBytes, encoding: .utf8) ?? ""
                if let event = Self.interpret(rawLine) {
                    events.append(event)
                }
                lineStart = index + 1
            }
            index += 1
        }

        if lineStart > 0 {
            buffer.removeFirst(lineStart)
        }
        return events
    }

    /// Interprets a single raw SSE line. Returns `nil` for lines that carry no
    /// payload (comments, blanks, non-`data:` fields).
    static func interpret(_ rawLine: String) -> Event? {
        // Tolerate CRLF line endings.
        let line = rawLine.hasSuffix("\r") ? String(rawLine.dropLast()) : rawLine

        if line.isEmpty { return nil }       // event separator
        if line.hasPrefix(":") { return nil } // keep-alive comment
        guard line.hasPrefix("data:") else { return nil }

        var payload = String(line.dropFirst("data:".count))
        if payload.hasPrefix(" ") { payload.removeFirst() }

        if payload == doneSentinel { return .done }
        return .data(payload)
    }
}
