import Foundation

enum TextAction: String, CaseIterable, Identifiable {
    case correct
    case translate

    var id: String { rawValue }
    var title: String { self == .correct ? "Correct" : "Translate" }
    var systemImage: String { self == .correct ? "checkmark.circle" : "globe" }
}

enum CaptureSource { case accessibility, clipboard, ocr, manual }

struct CaptureResult {
    let text: String
    let source: CaptureSource
}
