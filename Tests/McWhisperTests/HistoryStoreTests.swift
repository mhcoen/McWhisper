import Testing
import Foundation
@testable import McWhisper

@Suite("TranscriptionRecord & HistoryStore")
struct HistoryStoreTests {

    private func makeTempDir() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("McWhisperTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func makeRecord(
        rawText: String = "hello world",
        processedText: String = "Hello world.",
        duration: TimeInterval = 2.5,
        mode: TranscriptionMode = .voice,
        modelID: String = "whisper-small"
    ) -> TranscriptionRecord {
        TranscriptionRecord(
            duration: duration,
            rawText: rawText,
            processedText: processedText,
            mode: mode,
            modelID: modelID
        )
    }

    // MARK: - TranscriptionRecord

    @Test("Record has stable UUID")
    func recordID() {
        let id = UUID()
        let record = TranscriptionRecord(
            id: id, duration: 1.0, rawText: "a", processedText: "b",
            mode: .voice, modelID: "m"
        )
        #expect(record.id == id)
    }

    @Test("Record JSON round-trip preserves all fields")
    func recordRoundTrip() throws {
        let record = makeRecord(mode: .custom(name: "Test", prompt: "p"))
        let data = try JSONEncoder().encode(record)
        let decoded = try JSONDecoder().decode(TranscriptionRecord.self, from: data)
        #expect(decoded == record)
    }

    // MARK: - HistoryStore

    @Test("Add and retrieve records")
    func addRecords() {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = HistoryStore(directory: dir)
        let r1 = makeRecord(rawText: "first")
        let r2 = makeRecord(rawText: "second")
        store.add(r1)
        store.add(r2)
        #expect(store.records.count == 2)
        #expect(store.records[0] == r1)
        #expect(store.records[1] == r2)
    }

    @Test("Persists to disk and reloads")
    func persistence() {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let record = makeRecord()
        let store1 = HistoryStore(directory: dir)
        store1.add(record)

        let store2 = HistoryStore(directory: dir)
        #expect(store2.records.count == 1)
        #expect(store2.records[0] == record)
    }

    @Test("Delete record by ID")
    func deleteRecord() {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = HistoryStore(directory: dir)
        let r1 = makeRecord(rawText: "keep")
        let r2 = makeRecord(rawText: "remove")
        store.add(r1)
        store.add(r2)
        store.deleteRecord(id: r2.id)
        #expect(store.records.count == 1)
        #expect(store.records[0] == r1)
    }

    @Test("Clear all records")
    func clearAll() {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = HistoryStore(directory: dir)
        store.add(makeRecord())
        store.add(makeRecord())
        store.clearAll()
        #expect(store.records.isEmpty)

        let reloaded = HistoryStore(directory: dir)
        #expect(reloaded.records.isEmpty)
    }

    @Test("Empty store has no records")
    func emptyStore() {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = HistoryStore(directory: dir)
        #expect(store.records.isEmpty)
    }

    @Test("Default directory points to Application Support/McWhisper")
    func defaultDirectory() {
        let dir = HistoryStore.defaultDirectory
        #expect(dir.lastPathComponent == "McWhisper")
        #expect(dir.pathComponents.contains("Application Support"))
    }
}
