import SwiftUI

/// SwiftUI view displayed inside the floating recording panel.
/// Drives visibility and content from `RecordingCoordinator.State`.
struct RecordingView: View {
    @ObservedObject var coordinator: RecordingCoordinator
    @State private var showProcessed = true

    var body: some View {
        Group {
            switch coordinator.state {
            case .idle:
                StandbyWaveformView()
                    .frame(height: 32)
                    .padding(12)
            case .recording:
                RecordingStateView(
                    levelSamples: coordinator.levelSamples,
                    partialText: coordinator.partialText
                )
            case .transcribing:
                TranscribingStateView(
                    partialText: coordinator.partialText,
                    rawText: coordinator.rawText,
                    processedText: coordinator.processedText,
                    showProcessed: $showProcessed
                )
            case .error(let message):
                ErrorStateView(message: message)
            }
        }
        .frame(width: 280)
        .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Recording State

struct RecordingStateView: View {
    let levelSamples: [Float]
    let partialText: String

    var body: some View {
        VStack(spacing: 8) {
            WaveformView(levels: levelSamples)
                .frame(height: 32)
            if !partialText.isEmpty {
                Text(partialText)
                    .font(.system(.body, design: .rounded))
                    .lineLimit(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(12)
    }
}

// MARK: - Transcribing State

struct TranscribingStateView: View {
    let partialText: String
    let rawText: String
    let processedText: String
    @Binding var showProcessed: Bool

    /// Whether the final transcription result is available with formatting applied.
    var hasResult: Bool {
        !rawText.isEmpty && !processedText.isEmpty
    }

    /// The text to display based on current toggle state and availability.
    var displayText: String {
        if hasResult {
            return showProcessed ? processedText : rawText
        }
        return partialText
    }

    var body: some View {
        VStack(spacing: 8) {
            if !hasResult {
                ProgressView()
                    .controlSize(.small)
            }
            if hasResult {
                TextToggleView(showProcessed: $showProcessed)
            }
            if !displayText.isEmpty {
                Text(displayText)
                    .font(.system(.body, design: .rounded))
                    .lineLimit(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("Transcribing...")
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
    }
}

// MARK: - Text Toggle

struct TextToggleView: View {
    @Binding var showProcessed: Bool

    var body: some View {
        HStack(spacing: 4) {
            toggleButton(label: "Raw", active: !showProcessed) {
                showProcessed = false
            }
            toggleButton(label: "Processed", active: showProcessed) {
                showProcessed = true
            }
        }
        .font(.system(.caption2, design: .rounded))
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private func toggleButton(label: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(active ? Color.accentColor.opacity(0.2) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
        .foregroundStyle(active ? .primary : .secondary)
    }
}

// MARK: - Error State

struct ErrorStateView: View {
    let message: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            Text(message)
                .font(.system(.caption, design: .rounded))
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
    }
}

