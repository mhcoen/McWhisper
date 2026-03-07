import Testing
import Foundation
@testable import McWhisper

@Suite("TranscriptionMode")
struct TranscriptionModeTests {
    @Test("Built-in modes have expected count")
    func builtInCount() {
        #expect(TranscriptionMode.builtIn.count == 5)
    }

    @Test("Built-in mode IDs are unique")
    func builtInIDsUnique() {
        let ids = TranscriptionMode.builtIn.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test("Display names are non-empty")
    func displayNames() {
        for mode in TranscriptionMode.builtIn {
            #expect(!mode.displayName.isEmpty)
        }
    }

    @Test("Custom mode stores name and prompt")
    func customMode() {
        let mode = TranscriptionMode.custom(name: "Haiku", prompt: "Format as haiku")
        #expect(mode.displayName == "Haiku")
        #expect(mode.id == "custom:Haiku")
        if case .custom(_, let prompt) = mode {
            #expect(prompt == "Format as haiku")
        } else {
            Issue.record("Expected custom case")
        }
    }

    @Test("Lookup by ID finds built-in modes")
    func lookupBuiltIn() {
        for mode in TranscriptionMode.builtIn {
            #expect(TranscriptionMode.from(id: mode.id) == mode)
        }
    }

    @Test("JSON round-trip preserves custom modes")
    func jsonRoundTrip() throws {
        let modes: [TranscriptionMode] = [
            .custom(name: "Summary", prompt: "Summarize"),
            .custom(name: "Bullet", prompt: "Use bullet points"),
        ]
        let data = try JSONEncoder().encode(modes)
        let decoded = try JSONDecoder().decode([TranscriptionMode].self, from: data)
        #expect(decoded == modes)
    }

    @Test("Save and load custom modes via UserDefaults")
    func persistCustomModes() {
        let key = "customTranscriptionModes"
        let saved = UserDefaults.standard.data(forKey: key)
        defer {
            if let saved {
                UserDefaults.standard.set(saved, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }

        let modes: [TranscriptionMode] = [
            .custom(name: "Test1", prompt: "p1"),
            .custom(name: "Test2", prompt: "p2"),
        ]
        TranscriptionMode.saveCustomModes(modes)
        let loaded = TranscriptionMode.loadCustomModes()
        #expect(loaded == modes)
    }

    @Test("Save filters out built-in modes")
    func saveFiltersBuiltIn() {
        let key = "customTranscriptionModes"
        let saved = UserDefaults.standard.data(forKey: key)
        defer {
            if let saved {
                UserDefaults.standard.set(saved, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }

        let mixed: [TranscriptionMode] = [.voice, .custom(name: "X", prompt: "y")]
        TranscriptionMode.saveCustomModes(mixed)
        let loaded = TranscriptionMode.loadCustomModes()
        #expect(loaded.count == 1)
        #expect(loaded[0] == .custom(name: "X", prompt: "y"))
    }

    @Test("allModes includes built-in and custom")
    func allModesIncludesBoth() {
        let key = "customTranscriptionModes"
        let saved = UserDefaults.standard.data(forKey: key)
        defer {
            if let saved {
                UserDefaults.standard.set(saved, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }

        TranscriptionMode.saveCustomModes([.custom(name: "Z", prompt: "zz")])
        let all = TranscriptionMode.allModes()
        #expect(all.count == 6)
        #expect(all.last == .custom(name: "Z", prompt: "zz"))
    }

    @Test("Lookup finds custom modes")
    func lookupCustom() {
        let key = "customTranscriptionModes"
        let saved = UserDefaults.standard.data(forKey: key)
        defer {
            if let saved {
                UserDefaults.standard.set(saved, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }

        TranscriptionMode.saveCustomModes([.custom(name: "Abc", prompt: "def")])
        let found = TranscriptionMode.from(id: "custom:Abc")
        #expect(found == .custom(name: "Abc", prompt: "def"))
    }
}
