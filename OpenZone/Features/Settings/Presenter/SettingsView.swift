import ComposableArchitecture
import SwiftUI

/// Settings sheet for secure provider credential entry.
///
/// A single secure field accepts the API key; saving persists it to the Keychain
/// via the reducer. The field is never pre-filled with the stored secret — the
/// secret is write-only from the UI's perspective — and shows only whether a key
/// is currently stored.
struct SettingsView: View {
    @Bindable var store: StoreOf<SettingsFeature>

    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isKeyFieldFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                palette.surfaceBase.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        header
                        keyField
                        if let errorMessage = store.errorMessage {
                            Text(errorMessage)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(palette.accentPrimary)
                                .accessibilityIdentifier("settings-error")
                        }
                        actions
                        Spacer(minLength: 0)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(palette.textPrimary)
                }
            }
            .onAppear { store.send(.onAppear) }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Provider API key")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(palette.textPrimary)

            Text(store.hasStoredKey
                 ? "A key is stored securely in the Keychain. Enter a new value to replace it."
                 : "Add your provider API key to enable sending. It is stored securely in the Keychain and never leaves this device.")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var keyField: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: store.hasStoredKey ? "key.fill" : "key")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(palette.textTertiary)
                    .accessibilityHidden(true)

                SecureField("sk-...", text: $store.draftAPIKey)
                    .textContentType(.password)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(palette.textPrimary)
                    .focused($isKeyFieldFocused)
                    .submitLabel(.done)
                    .onSubmit { store.send(.saveTapped) }
                    .accessibilityIdentifier("settings-api-key-field")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(palette.surfaceRaised.opacity(palette.isDark ? 0.5 : 0.85))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(palette.lineSoft.opacity(palette.isDark ? 0.45 : 0.6), lineWidth: 1)
            }

            if store.hasStoredKey {
                Label("Key stored", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(palette.textSecondary)
                    .accessibilityIdentifier("settings-key-stored")
            }
        }
    }

    private var actions: some View {
        VStack(spacing: 10) {
            Button {
                isKeyFieldFocused = false
                store.send(.saveTapped)
            } label: {
                Text(store.hasStoredKey ? "Update key" : "Save key")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(store.canSave ? palette.controlStrongText : palette.textTertiary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(store.canSave ? palette.controlStrong : palette.surfaceSubtle.opacity(0.9))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!store.canSave)
            .accessibilityIdentifier("settings-save-button")

            if store.hasStoredKey {
                Button(role: .destructive) {
                    isKeyFieldFocused = false
                    store.send(.clearTapped)
                } label: {
                    Text("Remove stored key")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(palette.accentPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("settings-clear-button")
            }
        }
    }
}

#Preview {
    SettingsView(
        store: Store(initialState: SettingsFeature.State()) {
            SettingsFeature()
        }
    )
    .environment(\.palette, .resolve(.light))
}
