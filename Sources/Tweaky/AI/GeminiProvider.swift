import Foundation

struct GeminiProvider: AIProvider {
    let apiKey: String
    let model: String
    let baseURL: URL
    let session: URLSession

    func process(text: String, action: TextAction, targetLanguage: String?, onPartial: PartialHandler?) async throws -> String {
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
            .appending(path: "\(cleanModel):streamGenerateContent")
            .appending(queryItems: [URLQueryItem(name: "alt", value: "sse")])
        let body = RequestBody(
            systemInstruction: .init(parts: [.init(text: PromptBuilder.instruction(for: action, targetLanguage: targetLanguage))]),
            contents: [.init(parts: [.init(text: text)])],
            generationConfig: Self.minimalThinking(for: cleanModel)
        )
        var request = URLRequest(url: endpoint, timeoutInterval: 45)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        do {
            for attempt in 0..<3 {
                let (bytes, response) = try await session.bytes(for: request)
                if attempt < 2, isTransient(response) {
                    try await Task.sleep(for: .milliseconds(500 * (attempt + 1)))
                    continue
                }
                try HTTPValidation.validate(response)
                return try await ServerSentEvents.collect(bytes, onPartial: onPartial) { data in
                    try JSONDecoder().decode(ResponseBody.self, from: data).candidates?
                        .flatMap(\.content.parts)
                        .filter { $0.thought != true }
                        .compactMap(\.text)
                        .joined()
                }
            }
            throw AIProviderError.serviceUnavailable
        } catch let error as AIProviderError {
            throw error
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw AIProviderError.transport(error.localizedDescription)
        }
    }

    /// Correction and translation need no reasoning; thinking made replies about 5x slower (5.6 s vs 1.0 s).
    /// Gemini 1.x/2.x models predate `thinkingLevel` and would reject it.
    static func minimalThinking(for model: String) -> GeminiGenerationConfig? {
        guard !model.hasPrefix("gemini-1"), !model.hasPrefix("gemini-2") else { return nil }
        return .init(thinkingConfig: .init(thinkingLevel: "minimal"))
    }

    private func isTransient(_ response: URLResponse) -> Bool {
        guard let status = (response as? HTTPURLResponse)?.statusCode else { return false }
        return status == 429 || [500, 502, 503, 504].contains(status)
    }
}

struct GeminiGenerationConfig: Encodable, Equatable {
    let thinkingConfig: ThinkingConfig
    struct ThinkingConfig: Encodable, Equatable { let thinkingLevel: String }
}

private struct RequestBody: Encodable {
    let systemInstruction: Content
    let contents: [Content]
    let generationConfig: GeminiGenerationConfig?

    enum CodingKeys: String, CodingKey {
        case systemInstruction = "system_instruction"
        case contents, generationConfig
    }

    struct Content: Encodable { let parts: [Part] }
    struct Part: Encodable { let text: String }
}

private struct ResponseBody: Decodable {
    let candidates: [Candidate]?
    struct Candidate: Decodable { let content: Content }
    struct Content: Decodable { let parts: [Part] }
    struct Part: Decodable { let text: String?; let thought: Bool? }
}
