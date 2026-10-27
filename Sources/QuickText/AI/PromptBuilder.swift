import Foundation

enum PromptBuilder {
    static func instruction(for action: TextAction, targetLanguage: String? = nil) -> String {
        switch action {
        case .correct:
            "Correct grammar, spelling, and punctuation. Preserve the original language, meaning, formatting, and tone. Return only the corrected text."
        case .translate:
            "Translate the text into \(targetLanguage ?? "English"). Preserve its meaning and formatting. Return only the translation."
        }
    }
}
