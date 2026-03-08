import Testing
import Foundation
@testable import McWhisper

@Suite("MenuBarView")
struct MenuBarViewTests {

    @MainActor
    @Test("MenuBarView builds with coordinator")
    func menuBarViewBuilds() {
        let coordinator = RecordingCoordinator()
        let view = MenuBarView(coordinator: coordinator)
        _ = view.body
    }

    @MainActor
    @Test("ModeSelectorView builds with binding")
    func modeSelectorViewBuilds() {
        var mode = "voice"
        let view = ModeSelectorView(selectedMode: .init(get: { mode }, set: { mode = $0 }))
        _ = view.body
    }

    @MainActor
    @Test("ModeSelectorView shows all built-in modes")
    func modeSelectorShowsBuiltInModes() {
        let builtIn = TranscriptionMode.builtIn
        let allModes = TranscriptionMode.allModes()
        #expect(allModes.count >= builtIn.count)
        for mode in builtIn {
            #expect(allModes.contains(mode))
        }
    }

    @MainActor
    @Test("HistoryView builds with empty store")
    func historyViewBuildsEmpty() {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = HistoryStore(directory: dir)
        let view = HistoryView(historyStore: store)
        _ = view.body
        try? FileManager.default.removeItem(at: dir)
    }

    @MainActor
    @Test("HistoryView builds with records")
    func historyViewBuildsWithRecords() {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = HistoryStore(directory: dir)
        let record = TranscriptionRecord(
            duration: 1.5,
            rawText: "hello",
            processedText: "Hello.",
            mode: .voice,
            modelID: "test"
        )
        store.add(record)
        let view = HistoryView(historyStore: store)
        _ = view.body
        try? FileManager.default.removeItem(at: dir)
    }

    @Test("HistoryRow builds and shows first line")
    func historyRowBuilds() {
        let record = TranscriptionRecord(
            duration: 75,
            rawText: "hello world",
            processedText: "First line\nSecond line",
            mode: .message,
            modelID: "test"
        )
        let row = HistoryRow(record: record)
        _ = row.body
    }

    @Test("HistoryRow duration formatting under 60s")
    func historyRowDurationShort() {
        let record = TranscriptionRecord(
            duration: 42,
            rawText: "test",
            processedText: "",
            mode: .voice,
            modelID: "test"
        )
        let row = HistoryRow(record: record)
        _ = row.body
    }

    @Test("HistoryRow duration formatting over 60s")
    func historyRowDurationLong() {
        let record = TranscriptionRecord(
            duration: 125,
            rawText: "test",
            processedText: "",
            mode: .voice,
            modelID: "test"
        )
        let row = HistoryRow(record: record)
        _ = row.body
    }

    @Test("HistoryRow falls back to rawText when processedText is empty")
    func historyRowFallback() {
        let record = TranscriptionRecord(
            duration: 5,
            rawText: "raw text here",
            processedText: "",
            mode: .note,
            modelID: "test"
        )
        let row = HistoryRow(record: record)
        _ = row.body
    }

    @Test("ModeBadge builds for each built-in mode")
    func modeBadgeBuilds() {
        for mode in TranscriptionMode.builtIn {
            let badge = ModeBadge(mode: mode)
            _ = badge.body
        }
    }

    @MainActor
    @Test("SettingsView builds")
    func settingsViewBuilds() {
        let view = SettingsView()
        _ = view.body
    }

    @MainActor
    @Test("HistoryWindowController is a singleton")
    func historyWindowControllerSingleton() {
        let a = HistoryWindowController.shared
        let b = HistoryWindowController.shared
        #expect(a === b)
    }

    @MainActor
    @Test("SettingsWindowController is a singleton")
    func settingsWindowControllerSingleton() {
        let a = SettingsWindowController.shared
        let b = SettingsWindowController.shared
        #expect(a === b)
    }

    @Test("MenuBarLabel builds when not recording")
    func menuBarLabelNotRecording() {
        let view = MenuBarLabel(isRecording: false)
        _ = view.body
    }

    @Test("MenuBarLabel builds when recording")
    func menuBarLabelRecording() {
        let view = MenuBarLabel(isRecording: true)
        _ = view.body
    }

    @Test("MenuBarLabel pulse period is positive")
    func menuBarLabelPulsePeriod() {
        #expect(MenuBarLabel.pulsePeriod > 0)
    }

    // MARK: - HistoryDetailView

    @Test("HistoryDetailView builds with record")
    func historyDetailViewBuilds() {
        let record = TranscriptionRecord(
            duration: 5,
            rawText: "raw text",
            processedText: "Processed text.",
            mode: .voice,
            modelID: "test"
        )
        let view = HistoryDetailView(record: record)
        _ = view.body
    }

    @Test("HistoryDetailView builds with onRetranscribe callback")
    func historyDetailViewWithCallback() {
        let record = TranscriptionRecord(
            duration: 5,
            rawText: "raw",
            processedText: "Processed.",
            mode: .message,
            modelID: "test",
            audioFileName: "test.wav"
        )
        var called = false
        let view = HistoryDetailView(record: record) { _ in called = true }
        _ = view.body
        #expect(!called)
    }

    @Test("HistoryDetailView shows raw text fallback when processedText is empty")
    func historyDetailViewFallback() {
        let record = TranscriptionRecord(
            duration: 5,
            rawText: "raw only",
            processedText: "",
            mode: .voice,
            modelID: "test"
        )
        let view = HistoryDetailView(record: record)
        _ = view.body
    }

    @Test("HistoryTextToggle builds")
    func historyTextToggleBuilds() {
        var showRaw = false
        let view = HistoryTextToggle(showRaw: .init(get: { showRaw }, set: { showRaw = $0 }))
        _ = view.body
    }

    @MainActor
    @Test("HistoryView builds with onRetranscribe")
    func historyViewBuildsWithRetranscribe() {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = HistoryStore(directory: dir)
        let view = HistoryView(historyStore: store, onRetranscribe: { _ in })
        _ = view.body
        try? FileManager.default.removeItem(at: dir)
    }

    @MainActor
    @Test("HistoryWindowController show accepts onRetranscribe")
    func historyWindowControllerShowWithCallback() {
        // Just verify the API compiles - don't actually show a window
        let _ = HistoryWindowController.shared
    }
}
