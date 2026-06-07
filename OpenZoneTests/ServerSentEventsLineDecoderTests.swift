import Foundation
import Testing

@testable import OpenZone

/// Unit tests for the generic SSE line decoder. These assert wire behavior at
/// the decoder's boundary — bytes in, semantic events out — not its private
/// buffering mechanics.
struct ServerSentEventsLineDecoderTests {

    private func feed(_ decoder: inout ServerSentEventsLineDecoder, _ string: String) -> [ServerSentEventsLineDecoder.Event] {
        decoder.append(Data(string.utf8))
    }

    @Test("Emits a data event for a complete data line")
    func emitsDataLine() {
        var decoder = ServerSentEventsLineDecoder()
        let events = feed(&decoder, "data: hello\n")
        #expect(events == [.data("hello")])
    }

    @Test("Buffers a partial line across chunk boundaries")
    func buffersPartialLineAcrossChunks() {
        var decoder = ServerSentEventsLineDecoder()

        // First chunk ends mid-line: nothing complete yet.
        let first = feed(&decoder, "data: hel")
        #expect(first.isEmpty)

        // Second chunk completes the line.
        let second = feed(&decoder, "lo world\n")
        #expect(second == [.data("hello world")])
    }

    @Test("Splits multiple lines arriving in one chunk")
    func splitsMultipleLinesInOneChunk() {
        var decoder = ServerSentEventsLineDecoder()
        let events = feed(&decoder, "data: one\ndata: two\ndata: three\n")
        #expect(events == [.data("one"), .data("two"), .data("three")])
    }

    @Test("Skips keep-alive comment lines")
    func skipsKeepAliveComments() {
        var decoder = ServerSentEventsLineDecoder()
        let events = feed(&decoder, ": OPENROUTER PROCESSING\ndata: payload\n")
        #expect(events == [.data("payload")])
    }

    @Test("Skips blank separator lines")
    func skipsBlankLines() {
        var decoder = ServerSentEventsLineDecoder()
        let events = feed(&decoder, "data: a\n\ndata: b\n")
        #expect(events == [.data("a"), .data("b")])
    }

    @Test("Terminates on the done sentinel")
    func terminatesOnDoneSentinel() {
        var decoder = ServerSentEventsLineDecoder()
        let events = feed(&decoder, "data: last\ndata: [DONE]\n")
        #expect(events == [.data("last"), .done])
    }

    @Test("Strips exactly one leading space after the colon")
    func stripsSingleLeadingSpace() {
        var decoder = ServerSentEventsLineDecoder()
        // Two spaces => one is preserved as payload content.
        let events = feed(&decoder, "data:  spaced\n")
        #expect(events == [.data(" spaced")])
    }

    @Test("Tolerates CRLF line endings")
    func toleratesCRLF() {
        var decoder = ServerSentEventsLineDecoder()
        let events = feed(&decoder, "data: crlf\r\n")
        #expect(events == [.data("crlf")])
    }

    @Test("A done sentinel split across chunks still terminates")
    func doneSentinelSplitAcrossChunks() {
        var decoder = ServerSentEventsLineDecoder()
        #expect(feed(&decoder, "data: [DO").isEmpty)
        let events = feed(&decoder, "NE]\n")
        #expect(events == [.done])
    }
}
