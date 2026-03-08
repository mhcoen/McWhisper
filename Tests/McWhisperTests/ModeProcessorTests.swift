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

    // MARK: - Cross-mode formatting differences

    @Test func allModesProduceDistinctOutput() {
        // Use lowercase input without trailing punctuation so voice (passthrough)
        // and message (adds capitalization + period) differ.
        let input = "remember this"
        var outputs: [String: String] = [:]
        for mode in TranscriptionMode.builtIn {
            outputs[mode.id] = ModeProcessor.process(input, mode: mode)
        }
        // Each built-in mode should produce a unique output
        let uniqueOutputs = Set(outputs.values)
        #expect(uniqueOutputs.count == TranscriptionMode.builtIn.count,
                "Expected \(TranscriptionMode.builtIn.count) distinct outputs, got \(uniqueOutputs.count)")
    }

    @Test func modeSwitchingViaSettingsID() {
        // Verify that resolving a mode by its AppSettings ID and processing
        // text through it produces the expected format.
        let input = "remember to buy milk"

        let voiceMode = TranscriptionMode.from(id: "voice")!
        let messageMode = TranscriptionMode.from(id: "message")!
        let noteMode = TranscriptionMode.from(id: "note")!

        let voiceResult = ModeProcessor.process(input, mode: voiceMode)
        let messageResult = ModeProcessor.process(input, mode: messageMode)
        let noteResult = ModeProcessor.process(input, mode: noteMode)

        // Voice: raw passthrough
        #expect(voiceResult == "remember to buy milk")
        // Message: sentence case + punctuation
        #expect(messageResult == "Remember to buy milk.")
        // Note: bullet point
        #expect(noteResult == "- Remember to buy milk")
    }

    @Test func emailFormatStructure() {
        let result = ModeProcessor.process("check the logs. restart the server.", mode: .email)
        let lines = result.components(separatedBy: "\n")
        // Structure: greeting, blank, body, blank, sign-off line 1, sign-off line 2
        #expect(lines.first == "Hi [Name],")
        #expect(lines.last == "[Your Name]")
        #expect(lines[lines.count - 2] == "Best,")
    }

    @Test func meetingMultiSentenceStructure() {
        // Foundation .bySentences requires capitalized sentence starts
        let result = ModeProcessor.process("We discussed the budget. Timeline was reviewed. Next steps agreed.", mode: .meeting)
        let paragraphs = result.components(separatedBy: "\n\n")
        #expect(paragraphs.count == 3)
        for para in paragraphs {
            #expect(para.first?.isUppercase == true)
        }
    }

    @Test func noteMultiSentenceBullets() {
        // Foundation .bySentences requires capitalized sentence starts
        let result = ModeProcessor.process("Buy groceries. Clean the house. Call mom.", mode: .note)
        let lines = result.components(separatedBy: "\n")
        #expect(lines.count == 3)
        for line in lines {
            #expect(line.hasPrefix("- "))
            let content = String(line.dropFirst(2))
            #expect(content.first?.isUppercase == true)
        }
    }
}
