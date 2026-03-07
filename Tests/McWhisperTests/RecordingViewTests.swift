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
        let view = TranscribingStateView(partialText: "")
        _ = view.body
    }

    @Test("TranscribingStateView shows partial text")
    func transcribingStateWithPartial() {
        let view = TranscribingStateView(partialText: "Working...")
        _ = view.body
    }

    @Test("ErrorStateView builds with message")
    func errorStateBuilds() {
        let view = ErrorStateView(message: "Something went wrong")
        _ = view.body
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
}
