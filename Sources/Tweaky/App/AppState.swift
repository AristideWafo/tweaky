import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var inputText = ""
    @Published var resultText = ""
    @Published var isProcessing = false
    @Published var errorMessage: String?
    @Published var statusMessage: String?
    @Published var captureSource: CaptureSource = .manual

    let settingsStore: SettingsStore
    private let selectionReader = SelectionReader()
    private let screenCaptureService = ScreenCaptureService()
    private let ocrService = OCRService()
    private var processingTask: Task<Void, Never>?

    init(settingsStore: SettingsStore = SettingsStore()) {
        self.settingsStore = settingsStore
    }

    var canReplaceSelection: Bool { captureSource == .accessibility && !resultText.isEmpty }

    func prepareForPresentation() async {
        cancel()
        resultText = ""
        errorMessage = nil
        statusMessage = nil
        if let capture = await selectionReader.readSelectedText() {
            inputText = capture.text
            captureSource = capture.source
        } else {
            inputText = ""
            captureSource = .manual
        }
    }

    func paste() {
        guard let capture = ClipboardService.readText() else {
            statusMessage = "The clipboard does not contain text."
            return
        }
        inputText = capture.text
        captureSource = capture.source
        statusMessage = "Text loaded from the clipboard."
    }

    func readScreen() {
        cancel()
        isProcessing = true
        errorMessage = nil
        statusMessage = "Reading the main display locally…"
        processingTask = Task { [weak self] in
            guard let self else { return }
            do {
                let image = try await screenCaptureService.captureMainDisplay()
                let text = try await ocrService.recognizeText(in: image)
                guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    throw AIProviderError.invalidResponse
                }
                inputText = text
                captureSource = .ocr
                statusMessage = "OCR complete. Review the text before sending it."
            } catch is CancellationError {
                statusMessage = nil
            } catch {
                errorMessage = error.localizedDescription
                statusMessage = nil
            }
            isProcessing = false
        }
    }

    func process(_ action: TextAction) {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        cancel()
        isProcessing = true
        resultText = ""
        errorMessage = nil
        statusMessage = "Contacting \(settingsStore.settings.provider.displayName)…"
        let settings = settingsStore.settings

        processingTask = Task { [weak self] in
            guard let self else { return }
            do {
                guard let apiKey = try KeychainService.apiKey(for: settings.provider), !apiKey.isEmpty else {
                    throw AIProviderError.missingAPIKey
                }
                let provider = try ProviderFactory.make(settings: settings, apiKey: apiKey)
                resultText = try await provider.process(text: text, action: action, targetLanguage: settings.targetLanguage) { [weak self] partial in
                    self?.resultText = partial
                }
                statusMessage = "Done."
            } catch is CancellationError {
                statusMessage = "Cancelled."
            } catch {
                errorMessage = error.localizedDescription
                statusMessage = nil
            }
            isProcessing = false
        }
    }

    func cancel() {
        processingTask?.cancel()
        processingTask = nil
        isProcessing = false
    }

    func copyResult() {
        guard !resultText.isEmpty else { return }
        ClipboardService.copy(resultText)
        statusMessage = "Result copied."
    }

    func replaceSelection() {
        guard !resultText.isEmpty else { return }
        let text = resultText
        Task {
            if await !selectionReader.replaceSelection(with: text) {
                ClipboardService.copy(text)
                statusMessage = "Direct replacement is unavailable; the result was copied instead."
            }
        }
    }

    func reset() {
        inputText = ""
        resultText = ""
        errorMessage = nil
        statusMessage = nil
        isProcessing = false
        captureSource = .manual
    }
}
