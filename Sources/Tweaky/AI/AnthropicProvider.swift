import Foundation

struct AnthropicProvider: AIProvider {
    let apiKey: String
    let model: String
    let baseURL: URL
    let session: URLSession

    func process(text: String, action: TextAction, targetLanguage: String?) async throws -> String {
        guard !apiKey.isEmpty else { throw AIProviderError.missingAPIKey }
        guard !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AIProviderError.invalidConfiguration("Choose a model in Settings.")
        }

        let body = RequestBody(
            model: model,
            maxTokens: 4096,
            system: PromptBuilder.instruction(for: action, targetLanguage: targetLanguage),
            messages: [.init(role: "user", content: text)]
        )
        var request = URLRequest(url: baseURL.appending(path: "messages"), timeoutInterval: 45)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        do {
            let (data, response) = try await session.data(for: request)
            try HTTPValidation.validate(response)
            let decoded = try JSONDecoder().decode(ResponseBody.self, from: data)
            guard let value = decoded.content.first(where: { $0.type == "text" })?.text?
                .trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
                throw AIProviderError.invalidResponse
            }
            return value
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

    enum CodingKeys: String, CodingKey { case model, maxTokens = "max_tokens", system, messages }
    struct Message: Encodable { let role: String; let content: String }
}

private struct ResponseBody: Decodable {
    let content: [Content]
    struct Content: Decodable { let type: String; let text: String? }
}
