import Foundation

struct GeminiProvider: AIProvider {
    let apiKey: String
    let model: String
    let baseURL: URL
    let session: URLSession

    func process(text: String, action: TextAction, targetLanguage: String?) async throws -> String {
        guard !apiKey.isEmpty else { throw AIProviderError.missingAPIKey }
        let cleanModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanModel.isEmpty else {
            throw AIProviderError.invalidConfiguration("Choose a model in Settings.")
        }
        let allowedModelCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-"))
        guard cleanModel.unicodeScalars.allSatisfy(allowedModelCharacters.contains) else {
            throw AIProviderError.invalidConfiguration("The Gemini model name contains unsupported characters.")
        }

        let endpoint = baseURL
            .appending(path: "models")
            .appending(path: "\(cleanModel):generateContent")
        let body = RequestBody(
            systemInstruction: .init(parts: [.init(text: PromptBuilder.instruction(for: action, targetLanguage: targetLanguage))]),
            contents: [.init(parts: [.init(text: text)])]
        )
        var request = URLRequest(url: endpoint, timeoutInterval: 45)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        do {
            let (data, response) = try await session.data(for: request)
            try HTTPValidation.validate(response)
            let decoded = try JSONDecoder().decode(ResponseBody.self, from: data)
            let value = decoded.candidates
                .flatMap(\.content.parts)
                .compactMap(\.text)
                .joined()
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty else { throw AIProviderError.invalidResponse }
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
    let systemInstruction: Content
    let contents: [Content]

    enum CodingKeys: String, CodingKey {
        case systemInstruction = "system_instruction"
        case contents
    }

    struct Content: Encodable { let parts: [Part] }
    struct Part: Encodable { let text: String }
}

private struct ResponseBody: Decodable {
    let candidates: [Candidate]
    struct Candidate: Decodable { let content: Content }
    struct Content: Decodable { let parts: [Part] }
    struct Part: Decodable { let text: String? }
}
