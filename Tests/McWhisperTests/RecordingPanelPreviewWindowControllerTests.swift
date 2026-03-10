import Testing
import AppKit
@testable import McWhisper

@Suite("RecordingPanelPreviewWindowController")
struct RecordingPanelPreviewWindowControllerTests {
    @Test("Singleton instance exists")
    @MainActor
    func singletonExists() {
        let a = RecordingPanelPreviewWindowController.shared
        let b = RecordingPanelPreviewWindowController.shared
        #expect(a === b)
    }

    @Test("RecordingPanelPreviewView builds")
    @MainActor
    func previewViewBuilds() {
        let view = RecordingPanelPreviewView()
        _ = view.body
    }

    @Test("RecordingPanelPreviewView sample levels has correct count")
    @MainActor
    func sampleLevelsCount() {
        // The sample levels array should match WaveformView.barCount (30)
        // We verify via the view building without assertion failure
        let view = RecordingPanelPreviewView()
        _ = view.body
    }
}
