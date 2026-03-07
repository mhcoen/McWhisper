import AVFoundation

enum MicrophonePermission {
    /// Current authorization status for audio capture.
    static var status: AVAuthorizationStatus {
        AVCaptureDevice.authorizationStatus(for: .audio)
    }

    /// Request microphone access. Returns `true` if granted.
    /// Safe to call repeatedly — the system prompt only appears once.
    @MainActor
    static func request() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .audio)
    }
}
