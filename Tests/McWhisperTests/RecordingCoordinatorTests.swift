import Testing
import Foundation
@testable import McWhisper

@Suite("RecordingCoordinator")
struct RecordingCoordinatorTests {

    @MainActor
    @Test("Initial state is idle")
    func initialState() {
        let coordinator = RecordingCoordinator()
        #expect(coordinator.state == .idle)
    }

    @MainActor
    @Test("Initial partialText is empty")
    func initialPartialText() {
        let coordinator = RecordingCoordinator()
        #expect(coordinator.partialText.isEmpty)
    }

    @MainActor
    @Test("Initial levelSamples has correct size and is zeroed")
    func initialLevelSamples() {
        let coordinator = RecordingCoordinator()
        #expect(coordinator.levelSamples.count == RecordingCoordinator.levelBufferSize)
        #expect(coordinator.levelSamples.allSatisfy { $0 == 0 })
    }

    @MainActor
    @Test("Conforms to ObservableObject")
    func observableConformance() {
        let coordinator = RecordingCoordinator()
        _ = coordinator.objectWillChange
    }

    @MainActor
    @Test("State enum equality")
    func stateEquality() {
        #expect(RecordingCoordinator.State.idle == .idle)
        #expect(RecordingCoordinator.State.recording == .recording)
        #expect(RecordingCoordinator.State.transcribing == .transcribing)
        #expect(RecordingCoordinator.State.error("a") == .error("a"))
        #expect(RecordingCoordinator.State.error("a") != .error("b"))
        #expect(RecordingCoordinator.State.idle != .recording)
        #expect(RecordingCoordinator.State.idle != .transcribing)
        #expect(RecordingCoordinator.State.idle != .error("x"))
    }

    @MainActor
    @Test("Owns sub-components")
    func ownsSubComponents() {
        let coordinator = RecordingCoordinator()
        _ = coordinator.hotkeyManager
        _ = coordinator.audioEngine
        _ = coordinator.whisperEngine
        _ = coordinator.historyStore
        _ = coordinator.windowController
        _ = coordinator.pasteManager
    }

    @MainActor
    @Test("stop() is safe to call without start()")
    func stopWithoutStart() {
        let coordinator = RecordingCoordinator()
        coordinator.stop()
        #expect(coordinator.state == .idle)
    }

    @MainActor
    @Test("Initial rawText is empty")
    func initialRawText() {
        let coordinator = RecordingCoordinator()
        #expect(coordinator.rawText.isEmpty)
    }

    @MainActor
    @Test("Initial processedText is empty")
    func initialProcessedText() {
        let coordinator = RecordingCoordinator()
        #expect(coordinator.processedText.isEmpty)
    }

    @MainActor
    @Test("Initial hudMessage is empty")
    func initialHudMessage() {
        let coordinator = RecordingCoordinator()
        #expect(coordinator.hudMessage.isEmpty)
    }

    @MainActor
    @Test("hudDisplayDuration is positive")
    func hudDisplayDurationPositive() {
        #expect(RecordingCoordinator.hudDisplayDuration > 0)
    }
}
