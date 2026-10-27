import Foundation
import Testing
@testable import Tweaky

@Suite("AI providers", .serialized)
struct ProviderTests {
    @Test("OpenAI Responses parses output text")
    func openAIResponses() async throws {
        let session = makeSession { request in
            #expect(request.url?.path == "/v1/responses")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer secret")
            let body = #"{"output":[{"content":[{"type":"output_text","text":"Corrected text"}]}]}"#.data(using: .utf8)!
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, body)
        }
        let provider = OpenAIProvider(
            apiKey: "secret", model: "test-model", baseURL: URL(string: "https://api.openai.com/v1")!,
            style: .responses, session: session
        )
        #expect(try await provider.process(text: "Text", action: .correct, targetLanguage: nil) == "Corrected text")
    }

    @Test("Anthropic parses text content")
    func anthropicMessages() async throws {
        let session = makeSession { request in
            #expect(request.url?.path == "/v1/messages")
            #expect(request.value(forHTTPHeaderField: "x-api-key") == "secret")
            let body = #"{"content":[{"type":"text","text":"Texte corrigé"}]}"#.data(using: .utf8)!
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, body)
        }
        let provider = AnthropicProvider(
            apiKey: "secret", model: "test-model", baseURL: URL(string: "https://api.anthropic.com/v1")!, session: session
        )
        #expect(try await provider.process(text: "Texte", action: .correct, targetLanguage: nil) == "Texte corrigé")
    }

    @Test("Gemini generates and parses content without putting the key in the URL")
    func geminiGenerateContent() async throws {
        let session = makeSession { request in
            #expect(request.url?.path == "/v1beta/models/test-model:generateContent")
            #expect(request.url?.query == nil)
            #expect(request.value(forHTTPHeaderField: "x-goog-api-key") == "secret")
            let body = #"{"candidates":[{"content":{"parts":[{"text":"Corrected by Gemini"}]}}]}"#.data(using: .utf8)!
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, body)
        }
        let provider = GeminiProvider(
            apiKey: "secret", model: "test-model",
            baseURL: URL(string: "https://generativelanguage.googleapis.com/v1beta")!, session: session
        )
        #expect(try await provider.process(text: "Text", action: .correct, targetLanguage: nil) == "Corrected by Gemini")
    }

    @Test("Provider factory rejects insecure remote URLs")
    func rejectsInsecureRemoteURL() {
        var settings = AppSettings()
        settings.baseURL = "http://example.com/v1"
        #expect(throws: AIProviderError.self) {
            _ = try ProviderFactory.make(settings: settings, apiKey: "secret")
        }
    }

    private func makeSession(
        handler: @escaping @Sendable (URLRequest) throws -> (HTTPURLResponse, Data)
    ) -> URLSession {
        MockURLProtocol.handler = handler
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}

private final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            guard let handler = Self.handler else { throw AIProviderError.invalidResponse }
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
    override func stopLoading() {}
}
