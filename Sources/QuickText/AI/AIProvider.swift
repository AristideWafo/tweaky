import Foundation

protocol AIProvider: Sendable {
    func process(text: String, action: TextAction, targetLanguage: String?) async throws -> String
}

enum AIProviderError: LocalizedError {
    case missingAPIKey
    case invalidConfiguration(String)
    case invalidResponse
    case authenticationFailed
    case rateLimited
    case serverError(Int)
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: "Add an API key in Settings before processing text."
        case .invalidConfiguration(let message): message
        case .invalidResponse: "The provider returned an unreadable response."
        case .authenticationFailed: "The API key was rejected. Check it in Settings."
        case .rateLimited: "The provider rate limit was reached. Try again shortly."
        case .serverError(let code): "The provider returned an error (HTTP \(code))."
        case .transport(let message): "Network request failed: \(message)"
        }
    }
}

enum ProviderFactory {
    static func make(settings: AppSettings, apiKey: String, session: URLSession = .shared) throws -> any AIProvider {
        guard let baseURL = URL(string: settings.baseURL),
              let scheme = baseURL.scheme?.lowercased(),
              scheme == "https" || isLocalhost(baseURL) else {
            throw AIProviderError.invalidConfiguration("Use an HTTPS provider URL (HTTP is allowed only for localhost).")
        }

        switch settings.provider {
        case .openAI:
            return OpenAIProvider(apiKey: apiKey, model: settings.model, baseURL: baseURL, style: .responses, session: session)
        case .openAICompatible:
            return OpenAIProvider(apiKey: apiKey, model: settings.model, baseURL: baseURL, style: .chatCompletions, session: session)
        case .anthropic:
            return AnthropicProvider(apiKey: apiKey, model: settings.model, baseURL: baseURL, session: session)
        }
    }

    private static func isLocalhost(_ url: URL) -> Bool {
        ["localhost", "127.0.0.1", "::1"].contains(url.host?.lowercased() ?? "")
    }
}

enum HTTPValidation {
    static func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { throw AIProviderError.invalidResponse }
        switch http.statusCode {
        case 200..<300: return
        case 401, 403: throw AIProviderError.authenticationFailed
        case 429: throw AIProviderError.rateLimited
        default: throw AIProviderError.serverError(http.statusCode)
        }
    }
}
