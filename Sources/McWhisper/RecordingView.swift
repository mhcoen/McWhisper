import SwiftUI

/// SwiftUI view displayed inside the floating recording panel.
/// Drives visibility and content from `RecordingCoordinator.State`.
struct RecordingView: View {
    @ObservedObject var coordinator: RecordingCoordinator

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
                TranscribingStateView(partialText: coordinator.partialText)
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

    var body: some View {
        VStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            if !partialText.isEmpty {
                Text(partialText)
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

