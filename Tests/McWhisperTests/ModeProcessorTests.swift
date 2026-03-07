import Testing
@testable import McWhisper

@Suite("ModeProcessor")
struct ModeProcessorTests {

    // MARK: - Voice mode (raw passthrough)

    @Test func voiceReturnsRawText() {
        let result = ModeProcessor.process("hello world", mode: .voice)
        #expect(result == "hello world")
    }

    @Test func voiceTrimsWhitespace() {
        let result = ModeProcessor.process("  hello  ", mode: .voice)
        #expect(result == "hello")
    }

    // MARK: - Message mode

    @Test func messageCapitalizesFirstLetter() {
        let result = ModeProcessor.process("hello", mode: .message)
        #expect(result == "Hello.")
    }

    @Test func messagePreservesExistingPunctuation() {
        let result = ModeProcessor.process("hello!", mode: .message)
        #expect(result == "Hello!")
    }

    @Test func messagePreservesQuestionMark() {
        let result = ModeProcessor.process("are you there?", mode: .message)
        #expect(result == "Are you there?")
    }

    @Test func messageAlreadyCapitalized() {
        let result = ModeProcessor.process("Already fine.", mode: .message)
        #expect(result == "Already fine.")
    }

    // MARK: - Email mode

    @Test func emailWrapsWithGreetingAndSignoff() {
        let result = ModeProcessor.process("please send the report", mode: .email)
        #expect(result.hasPrefix("Hi [Name],"))
        #expect(result.hasSuffix("Best,\n[Your Name]"))
        #expect(result.contains("Please send the report."))
    }

    @Test func emailPreservesExistingPunctuation() {
        let result = ModeProcessor.process("is the report ready?", mode: .email)
        #expect(result.contains("Is the report ready?"))
        #expect(!result.contains("?."))
    }

    // MARK: - Note mode

    @Test func noteCreatesBulletPoints() {
        let result = ModeProcessor.process("First item. Second item.", mode: .note)
        let lines = result.split(separator: "\n")
        #expect(lines.count == 2)
        #expect(lines.allSatisfy { $0.hasPrefix("- ") })
    }

    @Test func noteSingleSentence() {
        let result = ModeProcessor.process("just one thing", mode: .note)
        #expect(result == "- Just one thing")
    }

    // MARK: - Meeting mode

    @Test func meetingInsertsParagraphBreaks() {
        let result = ModeProcessor.process("First point. Second point.", mode: .meeting)
        #expect(result.contains("\n\n"))
        let paragraphs = result.components(separatedBy: "\n\n")
        #expect(paragraphs.count == 2)
    }

    @Test func meetingSingleSentence() {
        let result = ModeProcessor.process("one statement", mode: .meeting)
        #expect(result == "One statement")
    }

    // MARK: - Custom mode (passthrough)

    @Test func customReturnsRawText() {
        let result = ModeProcessor.process("hello world", mode: .custom(name: "Test", prompt: "p"))
        #expect(result == "hello world")
    }

    // MARK: - Empty input

    @Test func emptyInputReturnsEmpty() {
        for mode in TranscriptionMode.builtIn {
            let result = ModeProcessor.process("", mode: mode)
            #expect(result.isEmpty, "Expected empty for mode \(mode.id)")
        }
    }

    @Test func whitespaceOnlyReturnsEmpty() {
        let result = ModeProcessor.process("   \n  ", mode: .message)
        #expect(result.isEmpty)
    }

    // MARK: - Helpers

    @Test func sentenceCaseCapitalizesFirst() {
        #expect(ModeProcessor.sentenceCase("hello") == "Hello")
        #expect(ModeProcessor.sentenceCase("Hello") == "Hello")
        #expect(ModeProcessor.sentenceCase("") == "")
    }

    @Test func splitSentencesHandlesMultiple() {
        let sentences = ModeProcessor.splitSentences("One. Two. Three.")
        #expect(sentences.count == 3)
    }

    @Test func splitSentencesHandlesNoPunctuation() {
        let sentences = ModeProcessor.splitSentences("just some words")
        #expect(sentences.count == 1)
        #expect(sentences.first == "just some words")
    }
}
