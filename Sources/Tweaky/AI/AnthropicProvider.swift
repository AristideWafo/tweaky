import Foundation

struct AnthropicProvider: AIProvider {
    let apiKey: String
    let model: String
    let baseURL: URL
    let session: URLSession

    func process(text: String, action: TextAction, targetLanguage: String?, onPartial: PartialHandler?) async throws -> String {
        guard !apiKey.isEmpty else { throw AIProviderError.missingAPIKey }
        guard !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AIProviderError.invalidConfiguration("Choose a model in Settings.")
        }

        let body = RequestBody(
            model: model,
            maxTokens: 4096,
            system: PromptBuilder.instruction(for: action, targetLanguage: targetLanguage),
            messages: [.init(role: "user", content: text)],
            stream: true
        )
        var request = URLRequest(url: baseURL.appending(path: "messages"), timeoutInterval: 45)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        do {
            let (bytes, response) = try await session.bytes(for: request)
            try HTTPValidation.validate(response)
            return try await ServerSentEvents.collect(bytes, onPartial: onPartial) { data in
                guard let event = try? JSONDecoder().decode(StreamEvent.self, from: data) else { return nil }
                switch event.type {
                case "content_block_delta": return event.delta?.text
                case "error": throw event.error?.type == "overloaded_error" ? AIProviderError.serviceUnavailable : AIProviderError.invalidResponse
                default: return nil
                }
            }
        } catch let error as AIProviderError {
            throw error
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw AIProviderError.transport(error.localizedDescription)
        }
    }
}

private struct RequestBody: Encodable {
    let model: String
    let maxTokens: Int
    let system: String
    let messages: [Message]
    let stream: Bool

    enum CodingKeys: String, CodingKey { case model, maxTokens = "max_tokens", system, messages, stream }
    struct Message: Encodable { let role: String; let content: String }
}

private struct StreamEvent: Decodable {
    let type: String
    let delta: Delta?
    let error: StreamError?
    struct Delta: Decodable { let text: String? }
    struct StreamError: Decodable { let type: String }
}
