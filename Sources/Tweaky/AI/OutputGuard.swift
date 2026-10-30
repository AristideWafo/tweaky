import Foundation

/// Checks applied before a correction replaces text the user has not reviewed.
enum OutputGuard {
    /// Openers a model uses when it talks about the text instead of returning it.
    private static let preambles = ["here is", "here's", "sure", "certainly", "corrected text", "voici", "texte corrigé"]

    static func isPlausibleCorrection(original: String, result: String) -> Bool {
        let original = original.trimmingCharacters(in: .whitespacesAndNewlines)
        let result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !result.isEmpty else { return false }
        let opener = result.lowercased()
        if let preamble = preambles.first(where: opener.hasPrefix), !original.lowercased().hasPrefix(preamble) {
            return false
        }
        // A correction keeps roughly the same length; short texts vary too much in ratio to judge.
        guard original.count >= 20 else { return true }
        let ratio = Double(result.count) / Double(original.count)
        return (0.5...1.6).contains(ratio)
    }

    /// Model output is trimmed; put back the selection's leading and trailing whitespace so replacing
    /// "word \n" does not glue it to the next line.
    static func matchingWhitespace(of original: String, _ result: String) -> String {
        let leading = original.prefix(while: \.isWhitespace)
        let trailing = original.reversed().prefix(while: \.isWhitespace).reversed()
        return String(leading) + result.trimmingCharacters(in: .whitespacesAndNewlines) + String(trailing)
    }
}
