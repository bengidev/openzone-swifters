import SwiftUI

/// Encrypted pairing demo — device nodes with animated traveling dot on dashed line.
struct OnboardingEncryptedPairingVisualView: View {
    let isConfirmed: Bool
    let appeared: Bool
    let onToggle: () -> Void

    @Environment(\.palette) private var palette

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                OnboardingDeviceNodeView(title: "LOCAL", subtitle: "Local key", systemImage: "iphone", active: isConfirmed)
                    .offset(x: appeared ? 0 : -24)
                Spacer(minLength: 6)
                OnboardingDeviceNodeView(title: "OPENZONE", subtitle: "AI chat lane", systemImage: "macbook", active: true)
                    .offset(x: appeared ? 0 : 24)
            }
            .padding(.horizontal, 8)

            VStack(spacing: 8) {
                ZStack {
                    // Dashed connection line
                    Capsule(style: .continuous)
                        .stroke(palette.lineSoft.opacity(0.8), style: StrokeStyle(lineWidth: 1, dash: [5, 7]))
                        .frame(height: 3)
                        .padding(.horizontal, 82)

                    // Traveling encryption dot
                    Circle()
                        .fill(palette.accentPrimary)
                        .frame(width: 9, height: 9)
                        .shadow(color: palette.accentPrimary.opacity(0.45), radius: 10)
                        .offset(x: isConfirmed ? 56 : -56)
                        .animation(.spring(response: 0.46, dampingFraction: 0.72), value: isConfirmed)

                    // Central encryption icon
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(palette.surfaceRaised)
                        .frame(width: 82, height: 82)
                        .overlay(
                            Image(systemName: isConfirmed ? "lock.shield.fill" : "lock.open.trianglebadge.exclamationmark")
                                .font(.system(size: 30, weight: .semibold))
                                .foregroundStyle(isConfirmed ? palette.accentPrimary : palette.warning)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(palette.lineSoft, lineWidth: 1)
                        )
                }

                Button(action: onToggle) {
                    HStack(spacing: 7) {
                        Image(systemName: isConfirmed ? "arrow.triangle.2.circlepath" : "link.badge.plus")
                        Text(isConfirmed ? "ROTATE KEY" : "PAIR DEVICE")
                    }
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .monoTracking()
                    .foregroundStyle(isConfirmed ? palette.accentPrimary : palette.warning)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill((isConfirmed ? palette.accentPrimary : palette.warning).opacity(0.12))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke((isConfirmed ? palette.accentPrimary : palette.warning).opacity(0.32), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isConfirmed ? "Rotate encryption key" : "Pair device")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
