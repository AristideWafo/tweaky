import Foundation

enum TextAction: String, CaseIterable, Identifiable {
    case correct
    case translate

    var id: String { rawValue }
    var title: String { self == .correct ? "Correct" : "Translate" }
    var systemImage: String { self == .correct ? "checkmark.circle" : "globe" }
}

enum CaptureSource {
    /// Read through Accessibility: the field can usually be written back directly.
    case accessibility
    /// Read by sending Command-C in an app that hides its selection from Accessibility.
    case copiedSelection
    case clipboard, ocr, manual
}

struct CaptureResult {
    let text: String
    let source: CaptureSource
}
