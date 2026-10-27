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
                }
                TextField("Model", text: $store.settings.model)
                if store.settings.provider == .openAICompatible {
                    TextField("Base URL", text: $store.settings.baseURL)
                }
                SecureField("API key", text: $apiKey)
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
        do { try KeychainService.saveAPIKey(apiKey, for: store.settings.provider); apiKey = ""; status = "API key saved in Keychain." }
        catch { status = "Could not save the API key." }
    }
    private func removeKey() {
        do { try KeychainService.deleteAPIKey(for: store.settings.provider); status = "API key removed." }
        catch { status = "Could not remove the API key." }
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
