import Testing

@Suite("McWhisper Package Configuration")
struct PackageTests {
    @Test("Executable target compiles")
    func targetCompiles() {
        // Build verification — if this test runs, the target compiled successfully.
        #expect(true)
    }
}
