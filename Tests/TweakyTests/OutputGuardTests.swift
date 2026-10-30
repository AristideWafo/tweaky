import Testing
@testable import Tweaky

@Suite("Output guard")
struct OutputGuardTests {
    @Test("Accepts a normal correction")
    func acceptsCorrection() {
        #expect(OutputGuard.isPlausibleCorrection(
            original: "la reunion de demain est decaler a 15h",
            result: "La réunion de demain est décalée à 15 h."
        ))
    }

    @Test("Rejects empty output and chatty preambles")
    func rejectsPreamble() {
        #expect(!OutputGuard.isPlausibleCorrection(original: "salut", result: "  "))
        #expect(!OutputGuard.isPlausibleCorrection(original: "salut ca va", result: "Voici le texte corrigé : Salut, ça va ?"))
        #expect(!OutputGuard.isPlausibleCorrection(original: "helo", result: "Here is the corrected text: Hello"))
        // The opener is legitimate when the original starts with it too.
        #expect(OutputGuard.isPlausibleCorrection(original: "here is my adress", result: "Here is my address"))
    }

    @Test("Rejects output whose length drifts too far")
    func rejectsLengthDrift() {
        let original = "Can you send me the report before Friday please"
        #expect(!OutputGuard.isPlausibleCorrection(original: original, result: "Sure."))
        #expect(!OutputGuard.isPlausibleCorrection(original: original, result: String(repeating: original + " ", count: 2)))
    }

    @Test("Keeps the selection's surrounding whitespace")
    func keepsWhitespace() {
        #expect(OutputGuard.matchingWhitespace(of: "  helo world\n", "Hello world.") == "  Hello world.\n")
        #expect(OutputGuard.matchingWhitespace(of: "helo", " Hello ") == "Hello")
    }
}
