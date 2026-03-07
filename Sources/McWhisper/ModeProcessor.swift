import Foundation

enum ModeProcessor {
    /// Apply mode-specific formatting to raw transcription text.
    static func process(_ text: String, mode: TranscriptionMode) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        switch mode {
        case .voice:
            return trimmed
        case .message:
            return formatMessage(trimmed)
        case .email:
            return formatEmail(trimmed)
        case .note:
            return formatNote(trimmed)
        case .meeting:
            return formatMeeting(trimmed)
        case .custom:
            return trimmed
        }
    }

    // MARK: - Message

    /// Ensure sentence case and trailing punctuation.
    private static func formatMessage(_ text: String) -> String {
        var result = sentenceCase(text)
        if !result.isEmpty, let last = result.unicodeScalars.last,
           !CharacterSet.punctuationCharacters.contains(last) {
            result.append(".")
        }
        return result
    }

    // MARK: - Email

    /// Wrap body with greeting and sign-off placeholders.
    private static func formatEmail(_ text: String) -> String {
        let body = sentenceCase(text)
        var result = body
        if !result.isEmpty, let last = result.unicodeScalars.last,
           !CharacterSet.punctuationCharacters.contains(last) {
            result.append(".")
        }
        return "Hi [Name],\n\n\(result)\n\nBest,\n[Your Name]"
    }

    // MARK: - Note

    /// Convert sentences to bullet-point lines.
    private static func formatNote(_ text: String) -> String {
        let sentences = splitSentences(text)
        return sentences.map { "- \(sentenceCase($0))" }.joined(separator: "\n")
    }

    // MARK: - Meeting

    /// Insert paragraph breaks between sentences.
    private static func formatMeeting(_ text: String) -> String {
        let sentences = splitSentences(text)
        return sentences.map { sentenceCase($0) }.joined(separator: "\n\n")
    }

    // MARK: - Helpers

    /// Capitalize the first letter, leave the rest unchanged.
    static func sentenceCase(_ text: String) -> String {
        guard let first = text.first else { return text }
        return first.uppercased() + text.dropFirst()
    }

    /// Split text into sentences by punctuation boundaries.
    static func splitSentences(_ text: String) -> [String] {
        var sentences: [String] = []
        text.enumerateSubstrings(in: text.startIndex..., options: .bySentences) { substring, _, _, _ in
            if let s = substring?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty {
                sentences.append(s)
            }
        }
        if sentences.isEmpty {
            sentences.append(text.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return sentences
    }
}
