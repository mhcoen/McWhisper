import Foundation

enum TranscriptionMode: Codable, Equatable, Hashable {
    case voice
    case message
    case email
    case note
    case meeting
    case custom(name: String, prompt: String)

    var displayName: String {
        switch self {
        case .voice: "Voice"
        case .message: "Message"
        case .email: "Email"
        case .note: "Note"
        case .meeting: "Meeting"
        case .custom(let name, _): name
        }
    }

    /// The mode identifier used for `AppSettings.selectedMode`.
    var id: String {
        switch self {
        case .voice: "voice"
        case .message: "message"
        case .email: "email"
        case .note: "note"
        case .meeting: "meeting"
        case .custom(let name, _): "custom:\(name)"
        }
    }

    static let builtIn: [TranscriptionMode] = [.voice, .message, .email, .note, .meeting]

    // MARK: - Custom mode persistence

    private static let customModesKey = "customTranscriptionModes"

    static func loadCustomModes() -> [TranscriptionMode] {
        guard let data = UserDefaults.standard.data(forKey: customModesKey) else { return [] }
        return (try? JSONDecoder().decode([TranscriptionMode].self, from: data)) ?? []
    }

    static func saveCustomModes(_ modes: [TranscriptionMode]) {
        let customOnly = modes.filter {
            if case .custom = $0 { return true }
            return false
        }
        if let data = try? JSONEncoder().encode(customOnly) {
            UserDefaults.standard.set(data, forKey: customModesKey)
        }
    }

    /// All available modes: built-in + saved custom modes.
    static func allModes() -> [TranscriptionMode] {
        builtIn + loadCustomModes()
    }

    /// Look up a mode by its `id` string, checking built-in then custom modes.
    static func from(id: String) -> TranscriptionMode? {
        allModes().first { $0.id == id }
    }
}
