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

    var canReplaceSelection: Bool {
        [.accessibility, .copiedSelection].contains(captureSource) && !resultText.isEmpty && !isProcessing
    }

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
                let provider = try Self.makeProvider(settings)
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
        let text = OutputGuard.matchingWhitespace(of: inputText, resultText)
        Task {
            if await !selectionReader.replaceSelection(with: text) {
                ClipboardService.copy(text)
                statusMessage = "Direct replacement is unavailable; the result was copied instead."
            }
        }
    }

    enum InstantOutcome {
        case replaced, unchanged, noSelection
        /// The correction is on the clipboard instead of in the text field.
        case copied(String)
        case failed(String)
    }

    /// Corrects the current selection in place without the panel. Never replaces blindly: a suspicious result or
    /// a focus change since the shortcut leaves the correction on the clipboard instead.
    func instantCorrect() async -> InstantOutcome {
        guard let capture = await selectionReader.readSelectedText() else { return .noSelection }
        do {
            let corrected = try await Self.makeProvider(settingsStore.settings)
                .process(text: capture.text, action: .correct, targetLanguage: nil)
            guard corrected != capture.text.trimmingCharacters(in: .whitespacesAndNewlines) else { return .unchanged }
            guard OutputGuard.isPlausibleCorrection(original: capture.text, result: corrected) else {
                ClipboardService.copy(corrected)
                return .copied("The correction looked unusual, so it was copied instead of replaced.")
            }
            let replacement = OutputGuard.matchingWhitespace(of: capture.text, corrected)
            if await selectionReader.replaceSelection(with: replacement, requireSameFocus: true) { return .replaced }
            ClipboardService.copy(corrected)
            return .copied("You moved to another field before the correction was ready, so it was copied instead.")
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    private static func makeProvider(_ settings: AppSettings) throws -> any AIProvider {
        guard let apiKey = try KeychainService.apiKey(for: settings.provider), !apiKey.isEmpty else {
            throw AIProviderError.missingAPIKey
        }
        return try ProviderFactory.make(settings: settings, apiKey: apiKey)
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
