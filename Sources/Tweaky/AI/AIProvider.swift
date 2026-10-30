import Foundation

/// Receives the full text generated so far, each time a streamed chunk arrives.
typealias PartialHandler = @MainActor @Sendable (String) -> Void

protocol AIProvider: Sendable {
    /// Streams the response, reporting accumulated text through `onPartial`, and returns the final trimmed text.
    func process(text: String, action: TextAction, targetLanguage: String?, onPartial: PartialHandler?) async throws -> String
}

extension AIProvider {
    func process(text: String, action: TextAction, targetLanguage: String?) async throws -> String {
        try await process(text: text, action: action, targetLanguage: targetLanguage, onPartial: nil)
    }
}

/// Server-sent events: each `data:` line carries one JSON chunk; OpenAI ends with `[DONE]`.
enum ServerSentEvents {
    static func payload(of line: String) -> String? {
        guard line.hasPrefix("data:") else { return nil }
        return line.dropFirst(5).trimmingCharacters(in: .whitespaces)
    }

    /// Reads the stream, appending the text each event carries, and returns the trimmed result.
    static func collect(
        _ bytes: URLSession.AsyncBytes,
        onPartial: PartialHandler?,
        text: (Data) throws -> String?
    ) async throws -> String {
        var accumulated = ""
        for try await line in bytes.lines {
            guard let payload = payload(of: line) else { continue }
            if payload == "[DONE]" { break }
            guard let chunk = try text(Data(payload.utf8)), !chunk.isEmpty else { continue }
            accumulated += chunk
            await onPartial?(accumulated)
        }
        let value = accumulated.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { throw AIProviderError.invalidResponse }
        return value
    }
}

enum AIProviderError: LocalizedError {
    case missingAPIKey
    case invalidConfiguration(String)
    case invalidResponse
    case authenticationFailed
    case rateLimited
    case serviceUnavailable
    case serverError(Int)
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: "Add an API key in Settings before processing text."
        case .invalidConfiguration(let message): message
        case .invalidResponse: "The provider returned an unreadable response."
        case .authenticationFailed: "The API key was rejected. Check it in Settings."
        case .rateLimited: "The provider rate limit was reached. Try again shortly."
        case .serviceUnavailable: "Google Gemini is temporarily unavailable after three attempts. Try again in a moment."
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
        case .gemini:
            return GeminiProvider(apiKey: apiKey, model: settings.model, baseURL: baseURL, session: session)
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
        case 502, 503, 504: throw AIProviderError.serviceUnavailable
        default: throw AIProviderError.serverError(http.statusCode)
        }
    }
}
