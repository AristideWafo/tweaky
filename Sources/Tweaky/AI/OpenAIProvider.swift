import Foundation

struct OpenAIProvider: AIProvider {
    enum APIStyle: Sendable { case responses, chatCompletions }

    let apiKey: String
    let model: String
    let baseURL: URL
    let style: APIStyle
    let session: URLSession

    func process(text: String, action: TextAction, targetLanguage: String?) async throws -> String {
        guard !apiKey.isEmpty else { throw AIProviderError.missingAPIKey }
        guard !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AIProviderError.invalidConfiguration("Choose a model in Settings.")
        }

        let instruction = PromptBuilder.instruction(for: action, targetLanguage: targetLanguage)
        let endpoint = style == .responses ? "responses" : "chat/completions"
        var request = URLRequest(url: baseURL.appending(path: endpoint), timeoutInterval: 45)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(style == .responses
            ? OpenAIRequest.responses(model: model, instruction: instruction, text: text)
            : OpenAIRequest.chat(model: model, instruction: instruction, text: text))

        do {
            let (data, response) = try await session.data(for: request)
            try HTTPValidation.validate(response)
            let decoded = try JSONDecoder().decode(OpenAIResponse.self, from: data)
            guard let value = decoded.text?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
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

private struct OpenAIRequest: Encodable {
    let model: String
    let instructions: String?
    let input: String?
    let messages: [Message]?

    struct Message: Encodable { let role: String; let content: String }

    static func responses(model: String, instruction: String, text: String) -> Self {
        Self(model: model, instructions: instruction, input: text, messages: nil)
    }

    static func chat(model: String, instruction: String, text: String) -> Self {
        Self(model: model, instructions: nil, input: nil, messages: [
            Message(role: "system", content: instruction), Message(role: "user", content: text)
        ])
    }
}

private struct OpenAIResponse: Decodable {
    let output: [Output]?
    let choices: [Choice]?

    struct Output: Decodable { let content: [Content]? }
    struct Content: Decodable { let type: String?; let text: String? }
    struct Choice: Decodable { let message: Message }
    struct Message: Decodable { let content: String }

    var text: String? {
        output?.flatMap { $0.content ?? [] }.first(where: { $0.type == "output_text" })?.text
            ?? choices?.first?.message.content
    }
}
