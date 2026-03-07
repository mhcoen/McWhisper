import Testing
import AVFoundation
@testable import McWhisper

@Suite("MicrophonePermission")
struct MicrophonePermissionTests {

    @Test("status returns a valid AVAuthorizationStatus")
    func statusReturnsValid() {
        let status = MicrophonePermission.status
        // In a test/CI environment the status is typically .notDetermined or .denied.
        // We just verify it's one of the known cases.
        let validStatuses: [AVAuthorizationStatus] = [
            .notDetermined, .restricted, .denied, .authorized
        ]
        #expect(validStatuses.contains(status))
    }
}
