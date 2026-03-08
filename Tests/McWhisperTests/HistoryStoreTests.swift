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

    @Test("Update record replaces matching record")
    func updateRecord() {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = HistoryStore(directory: dir)
        let original = makeRecord(rawText: "original", processedText: "Original.")
        store.add(original)

        let updated = TranscriptionRecord(
            id: original.id,
            date: original.date,
            duration: original.duration,
            rawText: "updated",
            processedText: "Updated.",
            mode: original.mode,
            modelID: original.modelID,
            audioFileName: "test.wav"
        )
        store.updateRecord(updated)
        #expect(store.records.count == 1)
        #expect(store.records[0].rawText == "updated")
        #expect(store.records[0].processedText == "Updated.")
        #expect(store.records[0].audioFileName == "test.wav")
    }

    @Test("Update record with unknown ID is a no-op")
    func updateRecordUnknownID() {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = HistoryStore(directory: dir)
        store.add(makeRecord())
        let unknown = TranscriptionRecord(
            id: UUID(),
            duration: 1.0,
            rawText: "x",
            processedText: "X.",
            mode: .voice,
            modelID: "m"
        )
        store.updateRecord(unknown)
        #expect(store.records.count == 1)
    }

    @Test("Update record persists to disk")
    func updateRecordPersists() {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = HistoryStore(directory: dir)
        let original = makeRecord()
        store.add(original)

        let updated = TranscriptionRecord(
            id: original.id,
            date: original.date,
            duration: original.duration,
            rawText: "persisted",
            processedText: "Persisted.",
            mode: original.mode,
            modelID: original.modelID
        )
        store.updateRecord(updated)

        let reloaded = HistoryStore(directory: dir)
        #expect(reloaded.records.count == 1)
        #expect(reloaded.records[0].rawText == "persisted")
    }

    // MARK: - Batch delete

    @Test("Delete multiple records by IDs")
    func deleteRecordsBatch() {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = HistoryStore(directory: dir)
        let r1 = makeRecord(rawText: "first")
        let r2 = makeRecord(rawText: "second")
        let r3 = makeRecord(rawText: "third")
        store.add(r1)
        store.add(r2)
        store.add(r3)
        store.deleteRecords(ids: [r1.id, r3.id])
        #expect(store.records.count == 1)
        #expect(store.records[0] == r2)
    }

    @Test("Batch delete persists to disk")
    func deleteRecordsBatchPersists() {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = HistoryStore(directory: dir)
        let r1 = makeRecord(rawText: "keep")
        let r2 = makeRecord(rawText: "remove")
        store.add(r1)
        store.add(r2)
        store.deleteRecords(ids: [r2.id])

        let reloaded = HistoryStore(directory: dir)
        #expect(reloaded.records.count == 1)
        #expect(reloaded.records[0] == r1)
    }

    @Test("Batch delete with empty set is a no-op")
    func deleteRecordsEmptySet() {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = HistoryStore(directory: dir)
        store.add(makeRecord())
        store.deleteRecords(ids: [])
        #expect(store.records.count == 1)
    }

    @Test("Batch delete with unknown IDs is safe")
    func deleteRecordsUnknownIDs() {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = HistoryStore(directory: dir)
        store.add(makeRecord())
        store.deleteRecords(ids: [UUID(), UUID()])
        #expect(store.records.count == 1)
    }

    @Test("Single delete persists to disk")
    func deleteRecordPersists() {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = HistoryStore(directory: dir)
        let r1 = makeRecord(rawText: "keep")
        let r2 = makeRecord(rawText: "remove")
        store.add(r1)
        store.add(r2)
        store.deleteRecord(id: r2.id)

        let reloaded = HistoryStore(directory: dir)
        #expect(reloaded.records.count == 1)
        #expect(reloaded.records[0] == r1)
    }

    @Test("Single delete with unknown ID is safe")
    func deleteRecordUnknownID() {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = HistoryStore(directory: dir)
        store.add(makeRecord())
        store.deleteRecord(id: UUID())
        #expect(store.records.count == 1)
    }

    @Test("Records preserve insertion order for retrieval")
    func recordsPreserveOrder() {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = HistoryStore(directory: dir)
        let r1 = makeRecord(rawText: "first")
        let r2 = makeRecord(rawText: "second")
        let r3 = makeRecord(rawText: "third")
        store.add(r1)
        store.add(r2)
        store.add(r3)
        #expect(store.records.map(\.rawText) == ["first", "second", "third"])
    }

    // MARK: - TranscriptionRecord audioFileName

    @Test("Record audioFileName defaults to nil")
    func recordAudioFileNameDefault() {
        let record = makeRecord()
        #expect(record.audioFileName == nil)
    }

    @Test("Record with audioFileName produces audioFileURL")
    func recordAudioFileURL() {
        let record = TranscriptionRecord(
            duration: 1.0,
            rawText: "a",
            processedText: "b",
            mode: .voice,
            modelID: "m",
            audioFileName: "test.wav"
        )
        let url = record.audioFileURL
        #expect(url != nil)
        #expect(url!.lastPathComponent == "test.wav")
        #expect(url!.pathComponents.contains("Audio"))
    }

    @Test("Record without audioFileName has nil audioFileURL")
    func recordNoAudioFileURL() {
        let record = makeRecord()
        #expect(record.audioFileURL == nil)
    }

    @Test("Record hasAudioFile is false when file missing")
    func recordHasAudioFileFalse() {
        let record = TranscriptionRecord(
            duration: 1.0,
            rawText: "a",
            processedText: "b",
            mode: .voice,
            modelID: "m",
            audioFileName: "nonexistent.wav"
        )
        #expect(!record.hasAudioFile)
    }

    @Test("Record hasAudioFile is false when audioFileName is nil")
    func recordHasAudioFileNil() {
        let record = makeRecord()
        #expect(!record.hasAudioFile)
    }

    @Test("Record JSON round-trip preserves audioFileName")
    func recordRoundTripAudioFileName() throws {
        let record = TranscriptionRecord(
            duration: 1.0,
            rawText: "a",
            processedText: "b",
            mode: .voice,
            modelID: "m",
            audioFileName: "audio.wav"
        )
        let data = try JSONEncoder().encode(record)
        let decoded = try JSONDecoder().decode(TranscriptionRecord.self, from: data)
        #expect(decoded.audioFileName == "audio.wav")
        #expect(decoded == record)
    }

    @Test("Record decodes without audioFileName for backward compatibility")
    func recordBackwardCompatibility() throws {
        let json = """
        {"id":"550e8400-e29b-41d4-a716-446655440000","date":0,"duration":1.0,\
        "rawText":"hello","processedText":"Hello.","mode":"voice","modelID":"m"}
        """
        let data = Data(json.utf8)
        let record = try JSONDecoder().decode(TranscriptionRecord.self, from: data)
        #expect(record.audioFileName == nil)
        #expect(record.rawText == "hello")
    }
}
