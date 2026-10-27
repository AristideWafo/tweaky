import Testing
@testable import Tweaky

@Suite("Prompt builder")
struct PromptBuilderTests {
    @Test("Correction preserves original intent")
    func correctionPromptPreservesMeaning() {
        #expect(PromptBuilder.instruction(for: .correct).contains("Preserve"))
    }

    @Test("Translation includes requested language")
    func translationPromptContainsRequestedLanguage() {
        #expect(PromptBuilder.instruction(for: .translate, targetLanguage: "French").contains("French"))
    }
}
