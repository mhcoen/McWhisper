import Combine
import Foundation

final class HistoryStore: ObservableObject {
    private let fileURL: URL
    @Published private(set) var records: [TranscriptionRecord] = []

    init(directory: URL? = nil) {
        let dir = directory ?? HistoryStore.defaultDirectory
        self.fileURL = dir.appendingPathComponent("history.json")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        load()
    }

    static var defaultDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("McWhisper", isDirectory: true)
    }

    func add(_ record: TranscriptionRecord) {
        records.append(record)
        save()
    }

    func updateRecord(_ record: TranscriptionRecord) {
        guard let index = records.firstIndex(where: { $0.id == record.id }) else { return }
        records[index] = record
        save()
    }

    func deleteRecord(id: UUID) {
        if let record = records.first(where: { $0.id == id }) {
            deleteAudioFile(for: record)
        }
        records.removeAll { $0.id == id }
        save()
    }

    func deleteRecords(ids: Set<UUID>) {
        guard !ids.isEmpty else { return }
        for record in records where ids.contains(record.id) {
            deleteAudioFile(for: record)
        }
        records.removeAll { ids.contains($0.id) }
        save()
    }

    func clearAll() {
        for record in records {
            deleteAudioFile(for: record)
        }
        records.removeAll()
        save()
    }

    private func deleteAudioFile(for record: TranscriptionRecord) {
        guard let url = record.audioFileURL else { return }
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Persistence

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        records = (try? JSONDecoder().decode([TranscriptionRecord].self, from: data)) ?? []
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(records) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
