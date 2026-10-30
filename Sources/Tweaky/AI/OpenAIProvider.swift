import Foundation

struct OpenAIProvider: AIProvider {
    enum APIStyle: Sendable { case responses, chatCompletions }

    let apiKey: String
    let model: String
    let baseURL: URL
    let style: APIStyle
    let session: URLSession

    func process(text: String, action: TextAction, targetLanguage: String?, onPartial: PartialHandler?) async throws -> String {
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
            let (bytes, response) = try await session.bytes(for: request)
            try HTTPValidation.validate(response)
            return try await ServerSentEvents.collect(bytes, onPartial: onPartial) { data in
                guard let event = try? JSONDecoder().decode(StreamEvent.self, from: data) else { return nil }
                if event.type == "error" || event.type == "response.failed" { throw AIProviderError.invalidResponse }
                return event.type == "response.output_text.delta" ? event.delta : event.choices?.first?.delta.content
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

private struct OpenAIRequest: Encodable {
    let model: String
    let instructions: String?
    let input: String?
    let messages: [Message]?
    let reasoning: Reasoning?
    let stream = true

    struct Message: Encodable { let role: String; let content: String }
    struct Reasoning: Encodable { let effort: String }

    static func responses(model: String, instruction: String, text: String) -> Self {
        Self(model: model, instructions: instruction, input: text, messages: nil, reasoning: OpenAIProvider.minimalReasoning(for: model))
    }

    static func chat(model: String, instruction: String, text: String) -> Self {
        Self(model: model, instructions: nil, input: nil, messages: [
            Message(role: "system", content: instruction), Message(role: "user", content: text)
        ], reasoning: nil)
    }
}

extension OpenAIProvider {
    /// Correction needs no reasoning. Only the original GPT-5 family accepts "minimal";
    /// other models either reject `reasoning` or use different effort values, so they keep their default.
    fileprivate static func minimalReasoning(for model: String) -> OpenAIRequest.Reasoning? {
        guard model.hasPrefix("gpt-5"), !model.hasPrefix("gpt-5.") else { return nil }
        return .init(effort: "minimal")
    }
}

/// One streamed event: Responses API (`type` + `delta`) or Chat Completions (`choices[].delta.content`).
private struct StreamEvent: Decodable {
    let type: String?
    let delta: String?
    let choices: [Choice]?
    struct Choice: Decodable { let delta: ChoiceDelta }
    struct ChoiceDelta: Decodable { let content: String? }
}
