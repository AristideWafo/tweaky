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
    @State private var accessibilityGranted = PermissionManager.hasAccessibilityAccess
    @State private var screenRecordingGranted = PermissionManager.hasScreenRecordingAccess

    var body: some View {
        Form {
            Section("AI") {
                Picker("Provider", selection: $store.settings.provider) {
                    ForEach(AIProviderID.allCases) { Text($0.displayName).tag($0) }
                }
                .onChange(of: store.settings.provider) { _, provider in
                    store.settings.model = provider.defaultModel
                    store.settings.baseURL = provider.defaultBaseURL
                    status = ""
                    refreshStoredKeyStatus()
                }
                TextField("Model", text: $store.settings.model)
                if store.settings.provider == .openAICompatible {
                    TextField("Base URL", text: $store.settings.baseURL)
                }
                SecureField(hasStoredAPIKey ? "API key stored in Keychain" : "API key", text: $apiKey)
                if hasStoredAPIKey {
                    Label("API key saved for \(store.settings.provider.displayName)", systemImage: "checkmark.circle.fill")
                        .font(.callout)
                        .foregroundStyle(.green)
                }
                HStack {
                    Button("Save API Key") { saveKey() }.disabled(apiKey.isEmpty)
                    Button("Test Connection") { testConnection() }
                        .disabled(isTesting)
                    Button("Remove API Key", role: .destructive) { removeKey() }
                    if isTesting { ProgressView().controlSize(.small) }
                }
                if !status.isEmpty { Text(status).foregroundStyle(.secondary).font(.callout) }
            }
            Section("Writing") {
                TextField("Default translation language", text: $store.settings.targetLanguage)
            }
            Section("Keyboard") {
                Picker("Global shortcut", selection: $store.settings.shortcut) {
                    ForEach(GlobalShortcut.allCases) { Text($0.displayName).tag($0) }
                }
            }
            Section("Permissions") {
                permissionRow("Accessibility", granted: accessibilityGranted) {
                    accessibilityGranted = PermissionManager.requestAccessibilityAccess()
                }
                permissionRow("Screen Recording", granted: screenRecordingGranted) {
                    screenRecordingGranted = PermissionManager.requestScreenRecordingAccess()
                }
            }
            Section("Privacy") {
                Text("Your API key is stored in the macOS Keychain. Text is sent only after you trigger an action.")
                    .font(.callout).foregroundStyle(.secondary)
            }
        }
        .padding()
        .onAppear { refreshStoredKeyStatus() }
    }

    private func permissionRow(_ name: String, granted: Bool, request: @escaping () -> Void) -> some View {
        HStack {
            Label(name, systemImage: granted ? "checkmark.circle.fill" : "exclamationmark.circle")
                .foregroundStyle(granted ? .green : .secondary)
            Spacer()
            if !granted { Button("Grant Access", action: request) }
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
                status = error.localizedDescription
            }
        }
    }
}
