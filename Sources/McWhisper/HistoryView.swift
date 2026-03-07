import SwiftUI

struct HistoryView: View {
    let historyStore: HistoryStore
    @State private var searchText = ""

    private var filteredRecords: [TranscriptionRecord] {
        let sorted = historyStore.records.sorted { $0.date > $1.date }
        guard !searchText.isEmpty else { return sorted }
        return sorted.filter { record in
            let text = record.processedText.isEmpty ? record.rawText : record.processedText
            return text.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack {
            if historyStore.records.isEmpty {
                Text("No recordings yet.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(filteredRecords) { record in
                    HistoryRow(record: record)
                }
                .searchable(text: $searchText, prompt: "Search recordings")
            }
        }
        .frame(minWidth: 300, minHeight: 200)
    }
}

struct HistoryRow: View {
    let record: TranscriptionRecord

    private var firstLine: String {
        let text = record.processedText.isEmpty ? record.rawText : record.processedText
        let line = text.split(separator: "\n", maxSplits: 1).first.map(String.init) ?? text
        return line.trimmingCharacters(in: .whitespaces)
    }

    private var durationLabel: String {
        let seconds = Int(record.duration)
        if seconds < 60 {
            return "\(seconds)s"
        }
        let minutes = seconds / 60
        let remainder = seconds % 60
        return "\(minutes)m \(remainder)s"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(firstLine)
                .lineLimit(1)
            HStack(spacing: 6) {
                Text(record.date, format: .dateTime.month(.abbreviated).day().hour().minute())
                Text("·")
                Text(durationLabel)
                Text("·")
                ModeBadge(mode: record.mode)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

struct ModeBadge: View {
    let mode: TranscriptionMode

    var body: some View {
        Text(mode.displayName)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(.quaternary)
            .clipShape(Capsule())
    }
}
