import AppKit
import SwiftUI

struct HistoryView: View {
    let historyStore: HistoryStore
    var onRetranscribe: ((TranscriptionRecord) -> Void)?
    @State private var searchText = ""
    @State private var selectedRecordID: UUID?

    private var filteredRecords: [TranscriptionRecord] {
        let sorted = historyStore.records.sorted { $0.date > $1.date }
        guard !searchText.isEmpty else { return sorted }
        return sorted.filter { record in
            let text = record.processedText.isEmpty ? record.rawText : record.processedText
            return text.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var selectedRecord: TranscriptionRecord? {
        guard let id = selectedRecordID else { return nil }
        return historyStore.records.first { $0.id == id }
    }

    var body: some View {
        VStack {
            if historyStore.records.isEmpty {
                Text("No recordings yet.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HSplitView {
                    List(filteredRecords, selection: $selectedRecordID) { record in
                        HistoryRow(record: record)
                            .tag(record.id)
                    }
                    .searchable(text: $searchText, prompt: "Search recordings")
                    .frame(minWidth: 200)

                    if let record = selectedRecord {
                        HistoryDetailView(
                            record: record,
                            onRetranscribe: onRetranscribe
                        )
                        .frame(minWidth: 250)
                        .id(record.id)
                    } else {
                        Text("Select a recording")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .frame(minWidth: 250)
                    }
                }
            }
        }
        .frame(minWidth: 550, minHeight: 300)
    }
}

struct HistoryDetailView: View {
    let record: TranscriptionRecord
    var onRetranscribe: ((TranscriptionRecord) -> Void)?
    @State private var showRaw = false

    private var displayText: String {
        if showRaw {
            return record.rawText
        }
        return record.processedText.isEmpty ? record.rawText : record.processedText
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Text(record.date, format: .dateTime.month(.abbreviated).day().hour().minute())
                Text("·")
                ModeBadge(mode: record.mode)
                Spacer()
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if !record.rawText.isEmpty && !record.processedText.isEmpty
                && record.rawText != record.processedText {
                HistoryTextToggle(showRaw: $showRaw)
            }

            ScrollView {
                Text(displayText)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()

            HStack {
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(displayText, forType: .string)
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }

                if record.hasAudioFile {
                    Button {
                        onRetranscribe?(record)
                    } label: {
                        Label("Re-transcribe", systemImage: "arrow.clockwise")
                    }
                }

                Spacer()
            }
        }
        .padding()
    }
}

struct HistoryTextToggle: View {
    @Binding var showRaw: Bool

    var body: some View {
        HStack(spacing: 0) {
            Button {
                showRaw = false
            } label: {
                Text("Processed")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
            }
            .buttonStyle(.plain)
            .background(showRaw ? .clear : Color.accentColor.opacity(0.2))
            .cornerRadius(4)

            Button {
                showRaw = true
            } label: {
                Text("Raw")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
            }
            .buttonStyle(.plain)
            .background(showRaw ? Color.accentColor.opacity(0.2) : .clear)
            .cornerRadius(4)
        }
        .background(.quaternary)
        .cornerRadius(4)
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
