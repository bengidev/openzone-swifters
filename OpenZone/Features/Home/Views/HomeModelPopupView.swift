import ComposableArchitecture
import SwiftUI

/// Full-screen sheet presenting the live model catalog with debounced search
/// and a free-tier filter. Selecting a model writes to the preference store
/// (via `HomeFeature`) and dismisses the sheet.
struct HomeModelPopupView: View {
    @Bindable var store: StoreOf<HomeFeature>

    @Environment(\.sharedPalette) private var palette
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                if store.selectedProviderID == ExternalAIProviderAPI.openRouter.id {
                    filterBar
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                }

                Divider()
                    .overlay(palette.lineSoft)

                modelList
            }
            .background(palette.surfaceBase.ignoresSafeArea())
            .navigationTitle("Select model")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        store.send(.modelPopupPresented(false))
                        dismiss()
                    }
                    .foregroundStyle(palette.textSecondary)
                }
            }
        }
    }

    // MARK: - Search bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(palette.textTertiary)
                .accessibilityHidden(true)

            TextField("Search models…", text: Binding(
                get: { store.modelSearchQuery },
                set: { store.send(.modelSearchQueryChanged($0)) }
            ))
            .font(.system(size: 15))
            .foregroundStyle(palette.textPrimary)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .accessibilityLabel("Search models")

            if !store.modelSearchQuery.isEmpty {
                Button {
                    store.send(.modelSearchQueryChanged(""))
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(palette.textTertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(palette.surfaceSubtle.opacity(palette.isDark ? 0.6 : 0.9))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(palette.lineSoft.opacity(palette.isDark ? 0.4 : 0.55), lineWidth: 1)
        }
    }

    // MARK: - Filter bar

    private var filterBar: some View {
        HStack(spacing: 8) {
            Toggle(isOn: Binding(
                get: { store.modelFilterFreeOnly },
                set: { store.send(.modelFilterFreeOnlyChanged($0)) }
            )) {
                Label("Free only", systemImage: "star.circle")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(
                        store.modelFilterFreeOnly
                            ? palette.accentPrimary
                            : palette.textSecondary
                    )
            }
            .toggleStyle(FilterToggleStyle(palette: palette))
            .accessibilityLabel("Show free models only")

            Spacer()

            if !store.catalogModels.isEmpty {
                Text("\(store.filteredModels.count) models")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(palette.textTertiary)
            }
        }
    }

    // MARK: - Model list

    private var modelList: some View {
        Group {
            if store.filteredModels.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(store.filteredModels) { option in
                            ModelRow(
                                option: option,
                                isSelected: store.selectedModelID == option.id,
                                palette: palette
                            ) {
                                store.send(.composerModelSelected(option.id))
                                dismiss()
                            }

                            if option.id != store.filteredModels.last?.id {
                                Divider()
                                    .overlay(palette.lineSoft.opacity(0.5))
                                    .padding(.leading, 56)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(palette.textTertiary)
                .accessibilityHidden(true)

            Text("No models found")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(palette.textPrimary)

            Text("Try a different search term or remove the free-only filter.")
                .font(.system(size: 14))
                .foregroundStyle(palette.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Model row

private struct ModelRow: View {
    let option: HomeModelOption
    let isSelected: Bool
    let palette: SharedOpenZonePalette
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Leading icon — checkmark when selected, model icon otherwise.
                ZStack {
                    Circle()
                        .fill(isSelected
                            ? palette.accentPrimary.opacity(palette.isDark ? 0.25 : 0.15)
                            : palette.surfaceSubtle.opacity(0.7)
                        )
                        .frame(width: 36, height: 36)

                    Image(systemName: isSelected ? "checkmark" : modelIcon)
                        .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
                        .foregroundStyle(isSelected ? palette.accentPrimary : palette.textTertiary)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(option.title)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(palette.textPrimary)
                            .lineLimit(1)

                        if option.isFree {
                            Text("FREE")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(palette.accentPrimary)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(palette.accentSoft.opacity(palette.isDark ? 0.3 : 0.9))
                                )
                        }

                        if option.supportsReasoning {
                            Image(systemName: "circle.hexagongrid")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(palette.textTertiary)
                                .accessibilityLabel("Supports reasoning")
                        }
                    }

                    if let contextLength = option.contextLength {
                        Text(contextLengthLabel(contextLength))
                            .font(.system(size: 12, weight: .regular, design: .monospaced))
                            .foregroundStyle(palette.textTertiary)
                    }
                }

                Spacer(minLength: 4)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            isSelected
                ? palette.accentSoft.opacity(palette.isDark ? 0.08 : 0.06)
                : Color.clear
        )
        .accessibilityLabel("\(option.title)\(option.isFree ? ", free" : "")\(isSelected ? ", selected" : "")")
    }

    private var modelIcon: String {
        if option.supportsReasoning { return "circle.hexagongrid" }
        return "sparkles"
    }

    private func contextLengthLabel(_ tokens: Int) -> String {
        let count = Double(tokens)
        if count >= 1_000_000 {
            return "\(Int(count / 1_000_000))M ctx"
        } else if count >= 1_000 {
            return "\(Int(count / 1_000))K ctx"
        }
        return "\(tokens) ctx"
    }
}

// MARK: - Filter toggle style

private struct FilterToggleStyle: ToggleStyle {
    let palette: SharedOpenZonePalette

    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(spacing: 5) {
                configuration.label
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(configuration.isOn
                        ? palette.accentSoft.opacity(palette.isDark ? 0.3 : 0.9)
                        : palette.surfaceSubtle.opacity(0.7)
                    )
            )
            .overlay {
                Capsule()
                    .stroke(
                        configuration.isOn
                            ? palette.accentPrimary.opacity(0.4)
                            : palette.lineSoft.opacity(0.5),
                        lineWidth: 1
                    )
            }
        }
        .buttonStyle(.plain)
    }
}
