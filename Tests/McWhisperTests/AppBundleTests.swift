import Foundation
import Testing

@Suite("Built App Bundle Verification")
struct AppBundleTests {
    let projectDir: String = {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // McWhisperTests/
            .deletingLastPathComponent() // Tests/
            .deletingLastPathComponent() // project root
        return url.path
    }()

    var appBundle: String { "\(projectDir)/McWhisper.app" }
    var contentsDir: String { "\(appBundle)/Contents" }
    var macosDir: String { "\(contentsDir)/MacOS" }

    @Test("App bundle directory exists after build")
    func appBundleExists() throws {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        #expect(fm.fileExists(atPath: appBundle, isDirectory: &isDir))
        #expect(isDir.boolValue)
    }

    @Test("Binary exists and is executable")
    func binaryExists() throws {
        let binaryPath = "\(macosDir)/McWhisper"
        let fm = FileManager.default
        #expect(fm.fileExists(atPath: binaryPath))
        #expect(fm.isExecutableFile(atPath: binaryPath))
    }

    @Test("Info.plist exists and contains required keys")
    func infoPlistValid() throws {
        let plistPath = "\(contentsDir)/Info.plist"
        let fm = FileManager.default
        #expect(fm.fileExists(atPath: plistPath))

        let data = try Data(contentsOf: URL(fileURLWithPath: plistPath))
        let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
        let dict = try #require(plist as? [String: Any])

        #expect(dict["CFBundleExecutable"] as? String == "McWhisper")
        #expect(dict["CFBundleIdentifier"] as? String == "com.mcwhisper.app")
        #expect(dict["LSUIElement"] as? Bool == true)
        #expect(dict["NSMicrophoneUsageDescription"] != nil)
        #expect(dict["LSMinimumSystemVersion"] as? String == "14.0")
    }
}
