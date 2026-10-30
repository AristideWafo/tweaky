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
            let body = sse(
                #"{"type":"response.created"}"#,
                #"{"type":"response.output_text.delta","delta":"Corrected "}"#,
                #"{"type":"response.output_text.delta","delta":"text"}"#,
                #"{"type":"response.completed","response":{"output":[]}}"#
            )
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
            let body = sse(
                #"{"type":"message_start","message":{}}"#,
                #"{"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Texte "}}"#,
                #"{"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"corrigé"}}"#,
                #"{"type":"message_stop"}"#
            )
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, body)
        }
        let provider = AnthropicProvider(
            apiKey: "secret", model: "test-model", baseURL: URL(string: "https://api.anthropic.com/v1")!, session: session
        )
        let partials = PartialRecorder()
        let result = try await provider.process(text: "Texte", action: .correct, targetLanguage: nil) { partials.append($0) }
        #expect(result == "Texte corrigé")
        #expect(await partials.values == ["Texte ", "Texte corrigé"])
    }

    @Test("Anthropic surfaces an overloaded error sent mid-stream")
    func anthropicStreamError() async throws {
        let session = makeSession { request in
            let body = sse(#"{"type":"error","error":{"type":"overloaded_error","message":"Overloaded"}}"#)
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, body)
        }
        let provider = AnthropicProvider(
            apiKey: "secret", model: "test-model", baseURL: URL(string: "https://api.anthropic.com/v1")!, session: session
        )
        await #expect(throws: AIProviderError.self) {
            _ = try await provider.process(text: "Texte", action: .correct, targetLanguage: nil)
        }
    }

    @Test("OpenAI-compatible chat completions stream until DONE")
    func chatCompletionsStream() async throws {
        let session = makeSession { request in
            #expect(request.url?.path == "/v1/chat/completions")
            let body = sse(
                #"{"choices":[{"delta":{"role":"assistant"}}]}"#,
                #"{"choices":[{"delta":{"content":"Bonjour"}}]}"#,
                "[DONE]",
                #"{"choices":[{"delta":{"content":" ignored"}}]}"#
            )
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, body)
        }
        let provider = OpenAIProvider(
            apiKey: "secret", model: "local", baseURL: URL(string: "http://localhost:1234/v1")!,
            style: .chatCompletions, session: session
        )
        #expect(try await provider.process(text: "Hello", action: .translate, targetLanguage: "French") == "Bonjour")
    }

    @Test("Gemini generates and parses content without putting the key in the URL")
    func geminiGenerateContent() async throws {
        let session = makeSession { request in
            #expect(request.url?.path == "/v1beta/models/test-model:streamGenerateContent")
            #expect(request.url?.query == "alt=sse")
            #expect(request.value(forHTTPHeaderField: "x-goog-api-key") == "secret")
            let body = sse(
                #"{"candidates":[{"content":{"parts":[{"text":"Planning","thought":true},{"text":"Corrected "}]}}]}"#,
                #"{"candidates":[{"content":{"parts":[{"text":"by Gemini"}]}}]}"#,
                #"{"usageMetadata":{"totalTokenCount":5}}"#
            )
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, body)
        }
        let provider = GeminiProvider(
            apiKey: "secret", model: "test-model",
            baseURL: URL(string: "https://generativelanguage.googleapis.com/v1beta")!, session: session
        )
        #expect(try await provider.process(text: "Text", action: .correct, targetLanguage: nil) == "Corrected by Gemini")
    }

    @Test("Gemini retries a transient service error")
    func geminiRetriesTransientFailure() async throws {
        let attempts = AttemptCounter()
        let session = makeSession { request in
            let attempt = attempts.increment()
            if attempt == 1 {
                return (HTTPURLResponse(url: request.url!, statusCode: 503, httpVersion: nil, headerFields: nil)!, Data())
            }
            let body = sse(#"{"candidates":[{"content":{"parts":[{"text":"Recovered"}]}}]}"#)
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, body)
        }
        let provider = GeminiProvider(
            apiKey: "secret", model: "test-model",
            baseURL: URL(string: "https://generativelanguage.googleapis.com/v1beta")!, session: session
        )
        #expect(try await provider.process(text: "Text", action: .correct, targetLanguage: nil) == "Recovered")
        #expect(attempts.current == 2)
    }

    @Test("Gemini asks for minimal thinking only on models that support it")
    func geminiMinimalThinking() {
        #expect(GeminiProvider.minimalThinking(for: "gemini-3.5-flash")?.thinkingConfig.thinkingLevel == "minimal")
        #expect(GeminiProvider.minimalThinking(for: "gemini-2.5-flash") == nil)
        #expect(GeminiProvider.minimalThinking(for: "gemini-1.5-pro") == nil)
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

private func sse(_ events: String...) -> Data {
    Data(events.map { "data: \($0)\n\n" }.joined().utf8)
}

@MainActor
private final class PartialRecorder {
    private(set) var values: [String] = []
    func append(_ value: String) { values.append(value) }
}

private final class AttemptCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0

    func increment() -> Int {
        lock.lock()
        defer { lock.unlock() }
        value += 1
        return value
    }

    var current: Int {
        lock.lock()
        defer { lock.unlock() }
        return value
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
