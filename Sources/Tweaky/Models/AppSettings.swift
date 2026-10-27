import Foundation

enum AIProviderID: String, CaseIterable, Codable, Identifiable {
    case openAI
    case anthropic
    case gemini
    case openAICompatible

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .openAI: "OpenAI"
        case .anthropic: "Anthropic"
        case .gemini: "Google Gemini"
        case .openAICompatible: "OpenAI-compatible"
        }
    }

    var defaultModel: String {
        switch self {
        case .openAI: "gpt-5-mini"
        case .anthropic: "claude-sonnet-4-5"
        case .gemini: "gemini-3.8-flash"
        case .openAICompatible: ""
        }
    }

    var defaultBaseURL: String {
        switch self {
        case .openAI, .openAICompatible: "https://api.openai.com/v1"
        case .anthropic: "https://api.anthropic.com/v1"
        case .gemini: "https://generativelanguage.googleapis.com/v1beta"
        }
    }
}

enum GlobalShortcut: String, CaseIterable, Codable, Identifiable {
    case optionSpace
    case commandShiftT

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .optionSpace: "Option + Space"
        case .commandShiftT: "Command + Shift + T"
        }
    }
}

struct AppSettings: Codable, Equatable {
    var provider: AIProviderID = .openAI
    var model = "gpt-5-mini"
    var baseURL = "https://api.openai.com/v1"
    var targetLanguage = "English"
    var shortcut: GlobalShortcut = .optionSpace
}

@MainActor
final class SettingsStore: ObservableObject {
    @Published var settings: AppSettings { didSet { save() } }
    private let key = "app-settings"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key), let value = try? JSONDecoder().decode(AppSettings.self, from: data) {
            settings = value
        } else {
            settings = AppSettings()
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: key)
        NotificationCenter.default.post(name: .tweakySettingsChanged, object: nil)
    }
}

extension Notification.Name {
    static let tweakySettingsChanged = Notification.Name("TweakySettingsChanged")
}
