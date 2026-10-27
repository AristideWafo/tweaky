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
        Form {
            Section("AI Provider") {
                Picker("Provider", selection: $store.settings.provider) {
                    ForEach(AIProviderID.allCases) { Text($0.displayName).tag($0) }
                }
                .onChange(of: store.settings.provider) { _, provider in
                    store.settings.model = provider.defaultModel
                    store.settings.baseURL = provider.defaultBaseURL
                    status = ""
                    refreshStoredKeyStatus()
                }
                LabeledContent("Model") {
                    HStack {
                        TextField("Model identifier", text: $store.settings.model)
                        Button("Use Default") {
                            store.settings.model = store.settings.provider.defaultModel
                            status = "Default model restored."
                        }
                    }
                }
                if store.settings.provider == .openAICompatible {
                    LabeledContent("Base URL") {
                        TextField("https://…", text: $store.settings.baseURL)
                    }
                }
                LabeledContent("API key") {
                    HStack {
                        let prompt = hasStoredAPIKey ? "Stored in Keychain" : "Paste provider key"
                        if isKeyVisible {
                            TextField(prompt, text: $apiKey)
                        } else {
                            SecureField(prompt, text: $apiKey)
                        }
                        Button(isKeyVisible ? "Hide" : "Show", systemImage: isKeyVisible ? "eye.slash" : "eye") {
                            isKeyVisible.toggle()
                        }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                    }
                }
                if hasStoredAPIKey {
                    Label("Saved in Keychain", systemImage: "lock.fill")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Button("Save") { saveKey() }
                        .buttonStyle(.borderedProminent)
                        .disabled(apiKey.isEmpty)
                    Button("Test Connection") { testConnection() }
                        .disabled(isTesting)
                    Button("Remove", role: .destructive) { removeKey() }
                    Spacer()
                    if isTesting { ProgressView().controlSize(.small) }
                }
                if !status.isEmpty {
                    Label(status, systemImage: statusIsError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .symbolRenderingMode(.multicolor)
                }
            }
            Section("Writing") {
                TextField("Default translation language", text: $store.settings.targetLanguage)
            }
            Section("Keyboard") {
                Picker("Shortcut", selection: $store.settings.shortcut) {
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
        .formStyle(.grouped)
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
