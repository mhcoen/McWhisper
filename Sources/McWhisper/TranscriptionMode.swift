import Foundation

enum TranscriptionMode: Equatable, Hashable {
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

extension TranscriptionMode: Codable {
    private enum CodingKeys: String, CodingKey {
        case type, name, prompt
    }

    private static let builtInByID: [String: TranscriptionMode] = {
        var map: [String: TranscriptionMode] = [:]
        for mode in builtIn { map[mode.id] = mode }
        return map
    }()

    init(from decoder: Decoder) throws {
        // Try decoding as a plain string first (backward compatibility).
        if let container = try? decoder.singleValueContainer(),
           let raw = try? container.decode(String.self),
           let mode = Self.builtInByID[raw] {
            self = mode
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        if let mode = Self.builtInByID[type] {
            self = mode
        } else if type == "custom" {
            let name = try container.decode(String.self, forKey: .name)
            let prompt = try container.decode(String.self, forKey: .prompt)
            self = .custom(name: name, prompt: prompt)
        } else {
            throw DecodingError.dataCorruptedError(forKey: .type,
                in: container, debugDescription: "Unknown mode type: \(type)")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .voice, .message, .email, .note, .meeting:
            try container.encode(id, forKey: .type)
        case .custom(let name, let prompt):
            try container.encode("custom", forKey: .type)
            try container.encode(name, forKey: .name)
            try container.encode(prompt, forKey: .prompt)
        }
    }
}
