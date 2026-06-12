import Foundation

/// Data model for a single onboarding page.
struct OnboardingPage: Equatable, Sendable, Identifiable {
    public let id: String
    public let type: OnboardingPageType
    public let indexLabel: String
    public let eyebrow: String
    public let headline: String
    public let body: String
    public let metric: String
    public let command: String
    public let shaderIntensity: Double
    public let highlights: [OnboardingFeatureHighlight]

    public init(
        id: String,
        type: OnboardingPageType,
        indexLabel: String,
        eyebrow: String,
        headline: String,
        body: String,
        metric: String,
        command: String,
        shaderIntensity: Double,
        highlights: [OnboardingFeatureHighlight]
    ) {
        self.id = id
        self.type = type
        self.indexLabel = indexLabel
        self.eyebrow = eyebrow
        self.headline = headline
        self.body = body
        self.metric = metric
        self.command = command
        self.shaderIntensity = shaderIntensity
        self.highlights = highlights
    }

    /// All onboarding pages in sequence.
    public static let all: [OnboardingPage] = [
        OnboardingPage(
            id: "encrypted-pairing",
            type: .encryptedPairing,
            indexLabel: "SEC-01",
            eyebrow: "Encrypted pairing",
            headline: "End-to-end encrypted pairing and chats",
            body: "Pair trusted devices, keep local workspace context private, and open AI chats without leaking the conversation boundary.",
            metric: "E2E CHANNEL",
            command: "pair --device workspace --mode sealed",
            shaderIntensity: 0.78,
            highlights: [
                OnboardingFeatureHighlight(title: "Local memory", detail: "Persists offline", symbol: "externaldrive.badge.checkmark"),
                OnboardingFeatureHighlight(title: "Secure session", detail: "Rotates keys", symbol: "lock.shield")
            ]
        ),
        OnboardingPage(
            id: "idea-studio",
            type: .ideaStudio,
            indexLabel: "AI-02",
            eyebrow: "Model workspace",
            headline: "Ask questions, write, and explore ideas with AI models",
            body: "OpenZone turns prompts into a focused working surface for drafting, refactoring, research, and interface decisions.",
            metric: "MODEL STUDIO",
            command: "ask --model adaptive --context project",
            shaderIntensity: 0.55,
            highlights: [
                OnboardingFeatureHighlight(title: "Design canvas", detail: "Native cards", symbol: "square.stack.3d.up"),
                OnboardingFeatureHighlight(title: "AI assistance", detail: "Structured sessions", symbol: "sparkles")
            ]
        ),
        OnboardingPage(
            id: "prompt-queue",
            type: .promptQueue,
            indexLabel: "RUN-03",
            eyebrow: "Queue control",
            headline: "Queue follow-up prompts while a turn is still running",
            body: "Keep momentum by lining up the next question, test request, or implementation step before the current model turn finishes.",
            metric: "LIVE QUEUE",
            command: "queue append --while-running follow-up",
            shaderIntensity: 0.66,
            highlights: [
                OnboardingFeatureHighlight(title: "State engine", detail: "Explicit actions", symbol: "point.3.connected.trianglepath.dotted"),
                OnboardingFeatureHighlight(title: "Run steering", detail: "Visible follow-ups", symbol: "arrow.triangle.branch")
            ]
        ),
        OnboardingPage(
            id: "reasoning-controls",
            type: .reasoningControl,
            indexLabel: "THK-04",
            eyebrow: "Reasoning dial",
            headline: "Tune how much thinking the AI uses",
            body: "Choose faster answers, balanced planning, or deeper reasoning before the AI model commits compute to the task.",
            metric: "THINK BUDGET",
            command: "model set reasoning --level balanced",
            shaderIntensity: 0.82,
            highlights: [
                OnboardingFeatureHighlight(title: "Model controls", detail: "Adjust thinking", symbol: "slider.horizontal.3"),
                OnboardingFeatureHighlight(title: "Human steering", detail: "User-set compute", symbol: "person.crop.circle.badge.checkmark")
            ]
        ),
        OnboardingPage(
            id: "workspace-ready",
            type: .workspaceReady,
            indexLabel: "RDY-05",
            eyebrow: "Workspace ready",
            headline: "OpenZone",
            body: "Your AI-native command center. Deploy specialized agents to handle code, review, test, and ship — all within your existing workflow without context switching.",
            metric: "WORKSPACE",
            command: "openzone enter --mode production",
            shaderIntensity: 0.45,
            highlights: [
                OnboardingFeatureHighlight(title: "Agents", detail: "Specialized runners", symbol: "cpu"),
                OnboardingFeatureHighlight(title: "Prompts", detail: "Structured input", symbol: "text.bubble"),
                OnboardingFeatureHighlight(title: "Models", detail: "Adaptive compute", symbol: "cube"),
                OnboardingFeatureHighlight(title: "Review", detail: "Iterative feedback", symbol: "checkmark.shield"),
                OnboardingFeatureHighlight(title: "Ship", detail: "Deploy ready", symbol: "paperplane.fill")
            ]
        )
    ]
}
