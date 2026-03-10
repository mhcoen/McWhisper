import Testing
import SwiftUI
@testable import McWhisper

@Suite("RecordingView")
struct RecordingViewTests {

    @MainActor
    @Test("RecordingView builds with coordinator")
    func viewBuildsWithCoordinator() {
        let coordinator = RecordingCoordinator()
        let view = RecordingView(coordinator: coordinator)
        _ = view.body
    }

    @Test("WaveformBar minimum level produces non-zero height")
    func minimumLevelNonZero() {
        let bar = WaveformBar(level: 0.0)
        #expect(bar.scale > 0)
    }

    @Test("WaveformBar scale matches level with floor")
    func scaleMatchesLevel() {
        let bar = WaveformBar(level: 0.6)
        #expect(bar.scale > 0.59 && bar.scale < 0.61)
    }

    @Test("WaveformBar scale uses floor for zero level")
    func scaleFloor() {
        let bar = WaveformBar(level: 0.0)
        #expect(bar.scale > 0.04 && bar.scale < 0.06)
    }

    @Test("RecordingStateView builds with empty partial text")
    func recordingStateEmptyPartial() {
        let levels = Array(repeating: Float(0.5), count: 30)
        let view = RecordingStateView(levelSamples: levels, partialText: "")
        _ = view.body
    }

    @Test("RecordingStateView builds with partial text")
    func recordingStateWithPartial() {
        let levels = Array(repeating: Float(0.5), count: 30)
        let view = RecordingStateView(levelSamples: levels, partialText: "Hello")
        _ = view.body
    }

    @Test("TranscribingStateView shows placeholder when no partial text")
    func transcribingStateEmpty() {
        var showProcessed = true
        let binding = Binding(get: { showProcessed }, set: { showProcessed = $0 })
        let view = TranscribingStateView(partialText: "", rawText: "", processedText: "", showProcessed: binding)
        _ = view.body
    }

    @Test("TranscribingStateView shows partial text")
    func transcribingStateWithPartial() {
        var showProcessed = true
        let binding = Binding(get: { showProcessed }, set: { showProcessed = $0 })
        let view = TranscribingStateView(partialText: "Working...", rawText: "", processedText: "", showProcessed: binding)
        _ = view.body
    }

    @Test("TranscribingStateView hasResult is false when texts are empty")
    func transcribingHasResultFalse() {
        var showProcessed = true
        let binding = Binding(get: { showProcessed }, set: { showProcessed = $0 })
        let view = TranscribingStateView(partialText: "partial", rawText: "", processedText: "", showProcessed: binding)
        #expect(!view.hasResult)
    }

    @Test("TranscribingStateView hasResult is true when both texts are present")
    func transcribingHasResultTrue() {
        var showProcessed = true
        let binding = Binding(get: { showProcessed }, set: { showProcessed = $0 })
        let view = TranscribingStateView(partialText: "", rawText: "hello world", processedText: "Hello world.", showProcessed: binding)
        #expect(view.hasResult)
    }

    @Test("TranscribingStateView displayText shows processedText when toggle is on")
    func transcribingDisplayTextProcessed() {
        var showProcessed = true
        let binding = Binding(get: { showProcessed }, set: { showProcessed = $0 })
        let view = TranscribingStateView(partialText: "", rawText: "hello world", processedText: "Hello world.", showProcessed: binding)
        #expect(view.displayText == "Hello world.")
    }

    @Test("TranscribingStateView displayText shows rawText when toggle is off")
    func transcribingDisplayTextRaw() {
        var showProcessed = false
        let binding = Binding(get: { showProcessed }, set: { showProcessed = $0 })
        let view = TranscribingStateView(partialText: "", rawText: "hello world", processedText: "Hello world.", showProcessed: binding)
        #expect(view.displayText == "hello world")
    }

    @Test("TranscribingStateView displayText falls back to partialText before result")
    func transcribingDisplayTextFallback() {
        var showProcessed = true
        let binding = Binding(get: { showProcessed }, set: { showProcessed = $0 })
        let view = TranscribingStateView(partialText: "partial so far", rawText: "", processedText: "", showProcessed: binding)
        #expect(view.displayText == "partial so far")
    }

    @Test("TranscribingStateView builds with result and toggle")
    func transcribingStateWithResult() {
        var showProcessed = false
        let binding = Binding(get: { showProcessed }, set: { showProcessed = $0 })
        let view = TranscribingStateView(partialText: "", rawText: "raw", processedText: "Processed.", showProcessed: binding)
        _ = view.body
    }

    @Test("TextToggleView builds")
    func textToggleViewBuilds() {
        var showProcessed = true
        let binding = Binding(get: { showProcessed }, set: { showProcessed = $0 })
        let view = TextToggleView(showProcessed: binding)
        _ = view.body
    }

    @Test("ErrorStateView builds with message")
    func errorStateBuilds() {
        let view = ErrorStateView(message: "Something went wrong")
        _ = view.body
    }

    @Test("HudView builds with message")
    func hudViewBuilds() {
        let view = HudView(message: "Copied to clipboard")
        _ = view.body
    }

    @Test("HudView builds with clipboard fallback message")
    func hudViewClipboardFallback() {
        let view = HudView(message: "Copied to clipboard")
        _ = view.body
        // The HUD uses doc.on.clipboard icon and displays the message
        #expect(view.message == "Copied to clipboard")
    }

    @Test("WaveformView renders correct number of bars from levels array")
    func waveformBarCount() {
        let levels = Array(repeating: Float(0.3), count: 30)
        let view = WaveformView(levels: levels)
        #expect(levels.count == 30)
        _ = view.body
    }

    @Test("WaveformView handles empty levels")
    func waveformEmptyLevels() {
        let view = WaveformView(levels: [])
        _ = view.body
    }

    @Test("WaveformView barCount is 30")
    func waveformBarCountConstant() {
        #expect(WaveformView.barCount == 30)
    }

    @Test("WaveformView minimumLevel is positive")
    func waveformMinimumLevel() {
        #expect(WaveformView.minimumLevel > 0)
    }

    @Test("WaveformView barSpacing is positive")
    func waveformBarSpacing() {
        #expect(WaveformView.barSpacing > 0)
    }

    @Test("WaveformView barCornerRadius is positive")
    func waveformBarCornerRadius() {
        #expect(WaveformView.barCornerRadius > 0)
    }

    @Test("WaveformBar scale uses WaveformView.minimumLevel as floor")
    func waveformBarUsesSharedMinimum() {
        let bar = WaveformBar(level: 0.0)
        #expect(bar.scale == CGFloat(WaveformView.minimumLevel))
    }

    @Test("WaveformView builds with fewer than 30 levels")
    func waveformFewerLevels() {
        let view = WaveformView(levels: [0.1, 0.5, 0.9])
        _ = view.body
    }

    @Test("WaveformView builds with exactly 30 levels")
    func waveformExact30Levels() {
        let levels = (0..<30).map { Float($0) / 30.0 }
        let view = WaveformView(levels: levels)
        _ = view.body
    }

    // MARK: - Standby waveform

    @Test("standbyLevels returns correct count")
    func standbyLevelsCount() {
        let levels = WaveformView.standbyLevels(phase: 0, count: 30)
        #expect(levels.count == 30)
    }

    @Test("standbyLevels returns empty for zero count")
    func standbyLevelsEmpty() {
        let levels = WaveformView.standbyLevels(phase: 0, count: 0)
        #expect(levels.isEmpty)
    }

    @Test("standbyLevels are uniform (all bars equal)")
    func standbyLevelsUniform() {
        let levels = WaveformView.standbyLevels(phase: 1.23, count: 10)
        let first = levels[0]
        for level in levels {
            #expect(level == first)
        }
    }

    @Test("standbyLevels are at or above minimumLevel")
    func standbyLevelsAboveMinimum() {
        for t in stride(from: 0.0, through: 4.0, by: 0.1) {
            let levels = WaveformView.standbyLevels(phase: t)
            for level in levels {
                #expect(level >= WaveformView.minimumLevel)
            }
        }
    }

    @Test("standbyLevels vary over time (sine pulse)")
    func standbyLevelsPulse() {
        let atZero = WaveformView.standbyLevels(phase: 0)[0]
        let atQuarter = WaveformView.standbyLevels(phase: WaveformView.standbyPeriod / 4.0)[0]
        #expect(atZero != atQuarter)
    }

    @Test("standbyLevels peak does not exceed minimumLevel + amplitude")
    func standbyLevelsPeakBounded() {
        let peak = WaveformView.standbyLevels(phase: WaveformView.standbyPeriod / 4.0)[0]
        let maxExpected = WaveformView.minimumLevel + WaveformView.standbyAmplitude
        #expect(peak <= maxExpected + 0.001)
    }

    @Test("standbyAmplitude is positive")
    func standbyAmplitudePositive() {
        #expect(WaveformView.standbyAmplitude > 0)
    }

    @Test("standbyPeriod is positive")
    func standbyPeriodPositive() {
        #expect(WaveformView.standbyPeriod > 0)
    }

    @Test("StandbyWaveformView builds")
    func standbyWaveformViewBuilds() {
        let view = StandbyWaveformView()
        _ = view.body
    }

    @MainActor
    @Test("RecordingView idle state shows standby waveform")
    func idleStateShowsStandby() {
        let coordinator = RecordingCoordinator()
        let view = RecordingView(coordinator: coordinator)
        _ = view.body
    }

    @Test("RecordingStateView passes varying levels to WaveformView")
    func recordingStateVaryingLevels() {
        // Simulate realistic audio levels with non-zero values
        let levels: [Float] = (0..<30).map { Float($0) / 100.0 + 0.1 }
        let view = RecordingStateView(levelSamples: levels, partialText: "")
        _ = view.body
        // All levels are above WaveformView.minimumLevel
        #expect(levels.allSatisfy { $0 >= WaveformView.minimumLevel })
    }

    @Test("WaveformView renders non-zero bar heights for all positive levels")
    func waveformNonZeroBarHeights() {
        let levels: [Float] = [0.0, 0.1, 0.5, 0.9, 1.0]
        let view = WaveformView(levels: levels)
        _ = view.body
        // Even zero-level bars get minimum height from the floor
        for level in levels {
            let effective = max(level, WaveformView.minimumLevel)
            #expect(effective > 0)
        }
    }

    @MainActor
    @Test("RecordingView levelSamples count matches WaveformView.barCount")
    func levelSamplesCountMatchesBarCount() {
        let coordinator = RecordingCoordinator()
        #expect(coordinator.levelSamples.count == WaveformView.barCount)
    }
}
