import Foundation
import Testing

@Suite("App Bundle Structure")
struct BundleTests {
    let projectDir: String = {
        // Tests run from the package root
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // McWhisperTests/
            .deletingLastPathComponent() // Tests/
            .deletingLastPathComponent() // project root
        return url.path
    }()

    @Test("run.sh exists and is executable")
    func runScriptExists() throws {
        let path = "\(projectDir)/run.sh"
        let fm = FileManager.default
        #expect(fm.fileExists(atPath: path))
        #expect(fm.isExecutableFile(atPath: path))
    }

    @Test("run.sh contains required build flags")
    func runScriptContents() throws {
        let path = "\(projectDir)/run.sh"
        let contents = try String(contentsOfFile: path, encoding: .utf8)
        #expect(contents.contains("swift build -c release --disable-sandbox"))
        #expect(contents.contains("codesign --deep"))
        #expect(contents.contains("LSUIElement"))
        #expect(contents.contains("NSMicrophoneUsageDescription"))
        #expect(contents.contains("com.mcwhisper.app"))
    }

    @Test("run.sh sets errexit")
    func runScriptSafety() throws {
        let path = "\(projectDir)/run.sh"
        let contents = try String(contentsOfFile: path, encoding: .utf8)
        #expect(contents.contains("set -e"))
    }

    @Test("run.sh checks for app with pgrep and exits non-zero on failure")
    func runScriptPgrepCheck() throws {
        let path = "\(projectDir)/run.sh"
        let contents = try String(contentsOfFile: path, encoding: .utf8)
        #expect(contents.contains("pgrep"))
        #expect(contents.contains("McWhisper"))
        #expect(contents.contains("exit 1"))
    }

    @Test("run.sh forwards arguments to the app")
    func runScriptForwardsArguments() throws {
        let path = "\(projectDir)/run.sh"
        let contents = try String(contentsOfFile: path, encoding: .utf8)
        #expect(contents.contains("\"$@\""))
    }
}
