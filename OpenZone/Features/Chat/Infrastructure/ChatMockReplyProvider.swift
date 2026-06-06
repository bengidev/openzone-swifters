import Foundation

enum ChatMockReplyProvider {
    /// Longer, more realistic multi-step reasoning ("chain of thought").
    /// Each step is separate so the reasoning feels like it streams in gradually.
    nonisolated static func thinkingSnippet(for userText: String) -> String {
        let trimmed = userText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return "Setting up the initial context. No user input yet, "
                + "so I'll prepare a default greeting while waiting for the next question."
        }

        let preview = trimmed.prefix(64)
        let steps = [
            "Reading the user message: \"\(preview)\". ",
            "Identifying the main intent and the relevant keywords. ",
            "Breaking the request into smaller sub-parts so it's easier to answer. ",
            "Considering a few approaches, then picking the clearest and most concise one. ",
            "Checking whether any assumptions need to be confirmed before answering. ",
            "Drafting the answer outline step by step. ",
        ]
        return steps.joined()
    }

    /// A late reasoning "summary" chunk emitted after the answer — dummy,
    /// used to exercise merging of reasoning deltas that arrive afterwards.
    nonisolated static func thinkingTail(for userText: String) -> String? {
        let trimmed = userText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return "Reviewing the answer once more to ensure consistency. "
            + "Tidying up the final points and adding a short summary. Done."
    }

    nonisolated static func reply(for userText: String) -> String {
        let trimmed = userText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return """
            Hi! This is a dummy reply from OpenZone. \
            The chat feature streams in real time, token by token, just like a real \
            assistant typing. The reasoning above shows the step-by-step thinking process \
            before the answer appears. Type something to see a longer streaming response \
            along with its reasoning steps.
            """
        }

        let templates = [
            """
            Thanks for your message: "\(trimmed)".

            Here is a longer dummy reply that simulates a real response. \
            This text is streamed token by token with a small delay between each word, \
            so it feels like an assistant typing live.

            First, this chat feature separates two streams: the reasoning stream, which is \
            shown first, and then the main answer stream. Both are merged into the same \
            message row so no duplicate "Thinking" rows appear.

            Second, all of this content is generated locally without any network connection. \
            When a real API integration is ready, `ChatMockStreamingClient` can simply be \
            swapped for an actual client without touching the presentation layer.

            Finally, a short summary will follow in the reasoning section as a closing note. \
            Hopefully this real-time simulation helps you test your streaming UI.
            """,
            """
            I (the mock) received your message: "\(trimmed)".

            Let me walk through it step by step. This dummy data stream is intentionally long \
            so you can see how text appears gradually, word by word, like a real conversation \
            with a language model.

            Step 1 — Receive: the incoming message is captured by the reducer and triggers a \
            streaming request. Step 2 — Reason: reasoning chunks are streamed first to show the \
            thinking process. Step 3 — Answer: the answer tokens follow one by one.

            Note that this architecture follows the Composable Architecture (TCA) pattern: each \
            incoming delta is merged into the existing message row by a stable ID, rather than \
            creating a new row. This prevents duplication when a late reasoning chunk arrives.

            If you type a longer message, this reply will still flow at the same rhythm — \
            consistent, smooth, and without sudden jumps in the text.
            """,
            """
            A long sample response for "\(trimmed)".

            All of this text is generated without a network, purely from local dummy data. \
            The goal is to test the real-time streaming experience end to end, from the \
            reasoning indicator to the final answer that streams in gradually.

            Think of this as a placeholder for a real model answer. It is structured into \
            paragraphs so you can inspect auto-scroll behavior, line wrapping, and reasoning \
            merging under reasonably large content.

            Technical detail: the inter-token delay can be tuned via `delayNanoseconds` and \
            `thinkingDelayNanoseconds`. The defaults give a comfortable typing feel, while \
            `fastClient()` removes the delay for automated testing.

            That's the end of this dummy reply. A short note will be appended at the end of \
            the reasoning section as a closing to the thinking process.
            """,
        ]
        return templates[abs(trimmed.hashValue) % templates.count]
    }
}
