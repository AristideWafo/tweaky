import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        SettingsForm(store: state.settingsStore)
    }
}

private struct SettingsForm: View {
    @ObservedObject var store: SettingsStore
    @State private var apiKey = ""
    @State private var status = ""
    @State private var isTesting = false
    @State private var hasStoredAPIKey = false
    @State private var isKeyVisible = false
    @State private var statusIsError = false
    @State private var accessibilityGranted = PermissionManager.hasAccessibilityAccess
    @State private var screenRecordingGranted = PermissionManager.hasScreenRecordingAccess

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Text("Settings").font(.brand(30))
                providerSection
                section("Writing") {
                    row("Translate to") {
                        TextField("Language", text: $store.settings.targetLanguage).multilineTextAlignment(.trailing)
                    }
                }
                section("Keyboard") {
                    row("Shortcut") {
                        Picker("Shortcut", selection: $store.settings.shortcut) {
                            ForEach(GlobalShortcut.allCases) { Text($0.displayName).tag($0) }
                        }
                        .labelsHidden()
                        .fixedSize()
                    }
                }
                section("Permissions") {
                    permissionRow("Accessibility", granted: accessibilityGranted) {
                        accessibilityGranted = PermissionManager.requestAccessibilityAccess()
                    }
                    Divider()
                    permissionRow("Screen Recording", granted: screenRecordingGranted) {
                        screenRecordingGranted = PermissionManager.requestScreenRecordingAccess()
                    }
                }
                Text("Your API key is stored in the macOS Keychain. Text is sent only after you trigger an action.")
                    .font(.brand(12))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 32)
            .padding(.top, 44)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.never)
        .textFieldStyle(.plain)
        .font(.brand(14))
        .background(BrandSurface().ignoresSafeArea())
        .onAppear { refreshStoredKeyStatus() }
    }

    private var providerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            section("AI provider") {
                row("Provider") {
                    Picker("Provider", selection: $store.settings.provider) {
                        ForEach(AIProviderID.allCases) { Text($0.displayName).tag($0) }
                    }
                    .labelsHidden()
                    .fixedSize()
                    .onChange(of: store.settings.provider) { _, provider in
                        store.settings.model = provider.defaultModel
                        store.settings.baseURL = provider.defaultBaseURL
                        status = ""
                        refreshStoredKeyStatus()
                    }
                }
                Divider()
                row("Model") {
                    TextField("Model identifier", text: $store.settings.model).multilineTextAlignment(.trailing)
                    Button("Default") {
                        store.settings.model = store.settings.provider.defaultModel
                        status = "Default model restored."
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                }
                if store.settings.provider == .openAICompatible {
                    Divider()
                    row("Base URL") {
                        TextField("https://…", text: $store.settings.baseURL).multilineTextAlignment(.trailing)
                    }
                }
                Divider()
                row("API key") {
                    let prompt = hasStoredAPIKey ? "Saved in Keychain" : "Paste provider key"
                    Group {
                        if isKeyVisible {
                            TextField(prompt, text: $apiKey)
                        } else {
                            SecureField(prompt, text: $apiKey)
                        }
                    }
                    .multilineTextAlignment(.trailing)
                    Button(isKeyVisible ? "Hide" : "Show", systemImage: isKeyVisible ? "eye.slash" : "eye") {
                        isKeyVisible.toggle()
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                }
                Divider()
                HStack(spacing: 8) {
                    Button("Save") { saveKey() }
                        .buttonStyle(PillButtonStyle(prominent: true))
                        .disabled(apiKey.isEmpty)
                    Button("Test Connection") { testConnection() }
                        .disabled(isTesting)
                    Spacer()
                    if isTesting { ProgressView().controlSize(.small) }
                    Button("Remove Key") { removeKey() }
                        .disabled(!hasStoredAPIKey)
                }
                .buttonStyle(PillButtonStyle())
                .padding(.vertical, 12)
            }
            if !status.isEmpty {
                Label(status, systemImage: statusIsError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                    .font(.brand(12))
                    .foregroundStyle(statusIsError ? Color.red : Color.secondary)
                    .padding(.horizontal, 4)
            }
        }
    }

    /// A titled card with a hairline border; rows inside are separated by `Divider()`.
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.brand(13, weight: .medium)).foregroundStyle(.secondary).padding(.horizontal, 4)
            VStack(alignment: .leading, spacing: 0, content: content)
                .padding(.horizontal, 16)
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.primary.opacity(0.1)))
        }
    }

    private func row<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 10) {
            Text(label)
            Spacer(minLength: 24)
            content()
        }
        .frame(minHeight: 28)
        .padding(.vertical, 10)
    }

    private func permissionRow(_ name: String, granted: Bool, request: @escaping () -> Void) -> some View {
        row(name) {
            if granted {
                Label("Granted", systemImage: "checkmark.circle.fill")
                    .font(.brand(13))
                    .foregroundStyle(.secondary)
            } else {
                Button("Grant Access", action: request).buttonStyle(PillButtonStyle())
            }
        }
    }

    private func saveKey() {
        let cleanKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanKey.isEmpty else { return }
        do {
            try KeychainService.saveAPIKey(cleanKey, for: store.settings.provider)
            apiKey = ""
            hasStoredAPIKey = true
            status = "Saved securely. Use Test Connection to validate the provider and model."
        } catch {
            hasStoredAPIKey = false
            status = error.localizedDescription
        }
    }
    private func removeKey() {
        do {
            try KeychainService.deleteAPIKey(for: store.settings.provider)
            hasStoredAPIKey = false
            status = "API key removed."
        } catch {
            status = error.localizedDescription
        }
    }

    private func refreshStoredKeyStatus() {
        do {
            hasStoredAPIKey = try KeychainService.apiKey(for: store.settings.provider)?.isEmpty == false
        } catch {
            hasStoredAPIKey = false
            status = error.localizedDescription
        }
    }

    private func testConnection() {
        status = ""
        statusIsError = false
        isTesting = true
        Task { @MainActor in
            defer { isTesting = false }
            do {
                let key = apiKey.isEmpty ? try KeychainService.apiKey(for: store.settings.provider) : apiKey
                guard let key, !key.isEmpty else { throw AIProviderError.missingAPIKey }
                let provider = try ProviderFactory.make(settings: store.settings, apiKey: key)
                _ = try await provider.process(text: "Connection test.", action: .correct, targetLanguage: nil)
                status = "Connection successful."
            } catch {
                statusIsError = true
                status = error.localizedDescription
            }
        }
    }
}
