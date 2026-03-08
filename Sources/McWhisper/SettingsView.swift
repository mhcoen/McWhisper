import SwiftUI
import ServiceManagement
import Carbon.HIToolbox

// MARK: - Main Settings View

struct SettingsView: View {
    @State private var selectedTab: SettingsTab = .general

    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsTab()
                .tabItem { Label("General", systemImage: "gear") }
                .tag(SettingsTab.general)

            ModelsSettingsTab()
                .tabItem { Label("Models", systemImage: "cpu") }
                .tag(SettingsTab.models)

            ModesSettingsTab()
                .tabItem { Label("Modes", systemImage: "text.bubble") }
                .tag(SettingsTab.modes)
        }
        .frame(minWidth: 480, minHeight: 360)
    }
}

enum SettingsTab: Hashable {
    case general
    case models
    case modes
}

// MARK: - General Tab

struct GeneralSettingsTab: View {
    @AppStorage(AppSettings.Keys.hotkeyKeyCode) private var hotkeyKeyCode: Int = Int(AppSettings.defaultHotkeyKeyCode)
    @AppStorage(AppSettings.Keys.hotkeyModifiers) private var hotkeyModifiers: Int = Int(AppSettings.defaultHotkeyModifiers)
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            Section("Push-to-Talk Hotkey") {
                HStack {
                    Text("Hotkey:")
                    Spacer()
                    HotkeyRecorderView(
                        keyCode: $hotkeyKeyCode,
                        modifiers: $hotkeyModifiers
                    )
                    .frame(width: HotkeyRecorderNSView.viewWidth, height: HotkeyRecorderNSView.viewHeight)
                }
            }

            Section("Startup") {
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        setLaunchAtLogin(newValue)
                    }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}

// MARK: - Hotkey Formatter

enum HotkeyFormatter {
    static func displayString(keyCode: Int, modifiers: Int) -> String {
        var parts: [String] = []
        let mods = UInt(modifiers)
        if mods & UInt(NSEvent.ModifierFlags.control.rawValue) != 0 { parts.append("\u{2303}") }
        if mods & UInt(NSEvent.ModifierFlags.option.rawValue) != 0 { parts.append("\u{2325}") }
        if mods & UInt(NSEvent.ModifierFlags.shift.rawValue) != 0 { parts.append("\u{21E7}") }
        if mods & UInt(NSEvent.ModifierFlags.command.rawValue) != 0 { parts.append("\u{2318}") }
        parts.append(keyName(for: keyCode))
        return parts.joined()
    }

    static func keyName(for keyCode: Int) -> String {
        switch keyCode {
        // Modifier-only keys
        case kVK_RightCommand: return "Right \u{2318}"
        case kVK_Command: return "Left \u{2318}"
        case kVK_Shift: return "Left \u{21E7}"
        case kVK_RightShift: return "Right \u{21E7}"
        case kVK_Option: return "Left \u{2325}"
        case kVK_RightOption: return "Right \u{2325}"
        case kVK_Control: return "Left \u{2303}"
        case kVK_RightControl: return "Right \u{2303}"
        case kVK_CapsLock: return "\u{21EA}"
        case kVK_Function: return "Fn"
        // Regular keys
        case kVK_Space: return "Space"
        case kVK_Return: return "Return"
        case kVK_Tab: return "Tab"
        case kVK_Escape: return "Esc"
        case kVK_Delete: return "Delete"
        case kVK_ForwardDelete: return "Fwd Delete"
        case kVK_UpArrow: return "\u{2191}"
        case kVK_DownArrow: return "\u{2193}"
        case kVK_LeftArrow: return "\u{2190}"
        case kVK_RightArrow: return "\u{2192}"
        case kVK_F1: return "F1"
        case kVK_F2: return "F2"
        case kVK_F3: return "F3"
        case kVK_F4: return "F4"
        case kVK_F5: return "F5"
        case kVK_F6: return "F6"
        case kVK_F7: return "F7"
        case kVK_F8: return "F8"
        case kVK_F9: return "F9"
        case kVK_F10: return "F10"
        case kVK_F11: return "F11"
        case kVK_F12: return "F12"
        default:
            if let scalar = keyCodeToCharacter(keyCode) {
                return String(scalar).uppercased()
            }
            return "Key\(keyCode)"
        }
    }

    private static func keyCodeToCharacter(_ keyCode: Int) -> Unicode.Scalar? {
        let source = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        guard let layoutDataPtr = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else {
            return nil
        }
        let layoutData = unsafeBitCast(layoutDataPtr, to: CFData.self)
        let layout = unsafeBitCast(CFDataGetBytePtr(layoutData), to: UnsafePointer<UCKeyboardLayout>.self)

        var deadKeyState: UInt32 = 0
        var length: Int = 0
        var chars = [UniChar](repeating: 0, count: 4)

        let status = UCKeyTranslate(
            layout,
            UInt16(keyCode),
            UInt16(kUCKeyActionDisplay),
            0,
            UInt32(LMGetKbdType()),
            UInt32(kUCKeyTranslateNoDeadKeysBit),
            &deadKeyState,
            4,
            &length,
            &chars
        )

        guard status == noErr, length > 0 else { return nil }
        return Unicode.Scalar(chars[0])
    }
}

// MARK: - Hotkey Recorder View

struct HotkeyRecorderView: NSViewRepresentable {
    @Binding var keyCode: Int
    @Binding var modifiers: Int

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> HotkeyRecorderNSView {
        let view = HotkeyRecorderNSView()
        view.displayText = HotkeyFormatter.displayString(keyCode: keyCode, modifiers: modifiers)
        view.onKeyEvent = { code, mods in
            self.keyCode = code
            self.modifiers = mods
        }
        return view
    }

    func updateNSView(_ nsView: HotkeyRecorderNSView, context: Context) {
        if !nsView.isRecordingHotkey {
            nsView.displayText = HotkeyFormatter.displayString(keyCode: keyCode, modifiers: modifiers)
        }
        nsView.needsDisplay = true
    }

    final class Coordinator {}
}

final class HotkeyRecorderNSView: NSView {
    var isRecordingHotkey = false
    var displayText = ""
    var onKeyEvent: ((Int, Int) -> Void)?

    static let viewHeight: CGFloat = 24
    static let viewWidth: CGFloat = 140

    override var acceptsFirstResponder: Bool { true }

    override var intrinsicContentSize: NSSize {
        NSSize(width: Self.viewWidth, height: Self.viewHeight)
    }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 5, yRadius: 5)

        if isRecordingHotkey {
            NSColor.controlAccentColor.withAlphaComponent(0.15).setFill()
        } else {
            NSColor.controlBackgroundColor.setFill()
        }
        path.fill()

        if window?.firstResponder == self {
            NSColor.controlAccentColor.setStroke()
        } else {
            NSColor.separatorColor.setStroke()
        }
        path.lineWidth = 1
        path.stroke()

        let text = isRecordingHotkey ? "Press a key…" : displayText
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: isRecordingHotkey ? NSColor.secondaryLabelColor : NSColor.labelColor
        ]
        let attrStr = NSAttributedString(string: text, attributes: attrs)
        let size = attrStr.size()
        let point = NSPoint(
            x: (bounds.width - size.width) / 2,
            y: (bounds.height - size.height) / 2
        )
        attrStr.draw(at: point)
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        isRecordingHotkey = true
        needsDisplay = true
    }

    override func becomeFirstResponder() -> Bool {
        needsDisplay = true
        return true
    }

    override func resignFirstResponder() -> Bool {
        isRecordingHotkey = false
        needsDisplay = true
        return true
    }

    override func keyDown(with event: NSEvent) {
        guard isRecordingHotkey else {
            super.keyDown(with: event)
            return
        }
        if event.keyCode == UInt16(kVK_Escape) {
            isRecordingHotkey = false
            window?.makeFirstResponder(nil)
            return
        }
        let relevantMask: NSEvent.ModifierFlags = [.shift, .control, .option, .command]
        let mods = Int(event.modifierFlags.intersection(relevantMask).rawValue)
        onKeyEvent?(Int(event.keyCode), mods)
        isRecordingHotkey = false
        displayText = HotkeyFormatter.displayString(keyCode: Int(event.keyCode), modifiers: mods)
        window?.makeFirstResponder(nil)
    }

    /// Modifier key codes that can be used as standalone hotkeys.
    private static let modifierKeyCodes: Set<UInt16> = [54, 55, 56, 57, 58, 59, 60, 61, 62, 63]

    override func flagsChanged(with event: NSEvent) {
        guard isRecordingHotkey else {
            super.flagsChanged(with: event)
            return
        }
        // Only capture modifier-only keys (press, not release).
        guard Self.modifierKeyCodes.contains(event.keyCode) else { return }
        // Check if the modifier flag is now set (key pressed, not released).
        let relevantMask: NSEvent.ModifierFlags = [.shift, .control, .option, .command]
        let currentMods = event.modifierFlags.intersection(relevantMask)
        guard !currentMods.isEmpty else { return }

        let code = Int(event.keyCode)
        onKeyEvent?(code, 0)
        isRecordingHotkey = false
        displayText = HotkeyFormatter.displayString(keyCode: code, modifiers: 0)
        window?.makeFirstResponder(nil)
    }
}

// MARK: - Models Tab

struct ModelsSettingsTab: View {
    @AppStorage(AppSettings.Keys.selectedModelID) private var selectedModelID: String = AppSettings.defaultModelID
    @StateObject private var downloader = ModelDownloader()
    @State private var downloadTasks: [String: Task<Void, Error>] = [:]
    @State private var previousModelID: String = AppSettings.selectedModelID

    var body: some View {
        Form {
            Section("Active Model") {
                Picker("Model:", selection: $selectedModelID) {
                    ForEach(ModelCatalog.availableModels) { model in
                        let isAvailable = model.isBundled || downloader.state(for: model.id) == .downloaded
                        Text("\(model.displayName) (\(model.sizeLabel))")
                            .tag(model.id)
                            .foregroundStyle(isAvailable ? .primary : .secondary)
                    }
                }
                .onChange(of: selectedModelID) { _, newValue in
                    // Revert to previous model if the selected one isn't downloaded
                    if let model = ModelCatalog.model(for: newValue),
                       !model.isBundled,
                       downloader.state(for: newValue) != .downloaded {
                        selectedModelID = previousModelID
                    } else {
                        previousModelID = newValue
                    }
                }
            }

            Section("Available Models") {
                ForEach(ModelCatalog.availableModels) { model in
                    ModelRow(
                        model: model,
                        isSelected: model.id == selectedModelID,
                        downloadState: downloader.state(for: model.id),
                        onDownload: { startDownload(model.id) },
                        onCancel: { cancelDownload(model.id) },
                        onDelete: { deleteModel(model.id) }
                    )
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func startDownload(_ modelID: String) {
        let task = Task {
            try await downloader.downloadModel(modelID)
        }
        downloadTasks[modelID] = task
    }

    private func cancelDownload(_ modelID: String) {
        downloadTasks[modelID]?.cancel()
        downloadTasks[modelID] = nil
    }

    private func deleteModel(_ modelID: String) {
        try? downloader.deleteModel(modelID)
    }
}

struct ModelRow: View {
    let model: ModelInfo
    let isSelected: Bool
    var downloadState: ModelDownloadState = .notDownloaded
    var onDownload: (() -> Void)?
    var onCancel: (() -> Void)?
    var onDelete: (() -> Void)?

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(model.displayName)
                        .fontWeight(isSelected ? .semibold : .regular)
                    if model.isBundled {
                        Text("Bundled")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.secondary.opacity(0.2))
                            .clipShape(Capsule())
                    }
                }
                Text(model.sizeLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if case .downloading(let progress) = downloadState {
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                    Text("\(Int(progress * 100))%")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                if case .failed(let message) = downloadState {
                    Text(message)
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
            }
            Spacer()
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.accentColor)
            }
            if !model.isBundled {
                modelActionButton
            }
        }
    }

    @ViewBuilder
    private var modelActionButton: some View {
        switch downloadState {
        case .notDownloaded, .failed:
            Button { onDownload?() } label: {
                Image(systemName: "arrow.down.circle")
            }
            .buttonStyle(.borderless)
            .help("Download model")
        case .downloading:
            Button { onCancel?() } label: {
                Image(systemName: "xmark.circle")
            }
            .buttonStyle(.borderless)
            .help("Cancel download")
        case .downloaded:
            Button { onDelete?() } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Delete model")
        }
    }
}

// MARK: - Modes Tab

struct ModesSettingsTab: View {
    @AppStorage(AppSettings.Keys.selectedMode) private var selectedMode: String = AppSettings.defaultMode
    @State private var customModes: [TranscriptionMode] = TranscriptionMode.loadCustomModes()
    @State private var isEditSheetPresented = false
    @State private var editingMode: TranscriptionMode?
    @State private var editName = ""
    @State private var editPrompt = ""

    var allModes: [TranscriptionMode] {
        TranscriptionMode.builtIn + customModes
    }

    var body: some View {
        Form {
            Section("Built-in Modes") {
                ForEach(TranscriptionMode.builtIn, id: \.id) { mode in
                    ModeRow(mode: mode, isSelected: mode.id == selectedMode) {
                        selectedMode = mode.id
                    }
                }
            }

            Section("Custom Modes") {
                if customModes.isEmpty {
                    Text("No custom modes yet.")
                        .foregroundStyle(.secondary)
                }
                ForEach(customModes, id: \.id) { mode in
                    ModeRow(mode: mode, isSelected: mode.id == selectedMode) {
                        selectedMode = mode.id
                    }
                    .contextMenu {
                        Button("Edit") { beginEditing(mode) }
                        Button("Delete", role: .destructive) { deleteMode(mode) }
                    }
                }

                Button("Add Custom Mode...") {
                    editingMode = nil
                    editName = ""
                    editPrompt = ""
                    isEditSheetPresented = true
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .sheet(isPresented: $isEditSheetPresented) {
            ModeEditSheet(
                name: $editName,
                prompt: $editPrompt,
                isEditing: editingMode != nil,
                onSave: saveMode,
                onCancel: { isEditSheetPresented = false }
            )
        }
    }

    private func beginEditing(_ mode: TranscriptionMode) {
        if case .custom(let name, let prompt) = mode {
            editingMode = mode
            editName = name
            editPrompt = prompt
            isEditSheetPresented = true
        }
    }

    private func deleteMode(_ mode: TranscriptionMode) {
        customModes.removeAll { $0.id == mode.id }
        if selectedMode == mode.id {
            selectedMode = AppSettings.defaultMode
        }
        TranscriptionMode.saveCustomModes(customModes)
    }

    private func saveMode() {
        let newMode = TranscriptionMode.custom(name: editName, prompt: editPrompt)
        if let editing = editingMode {
            if let index = customModes.firstIndex(of: editing) {
                customModes[index] = newMode
            }
        } else {
            customModes.append(newMode)
        }
        TranscriptionMode.saveCustomModes(customModes)
        isEditSheetPresented = false
    }
}

struct ModeRow: View {
    let mode: TranscriptionMode
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                Text(mode.displayName)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.accentColor)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct ModeEditSheet: View {
    @Binding var name: String
    @Binding var prompt: String
    let isEditing: Bool
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text(isEditing ? "Edit Mode" : "New Custom Mode")
                .font(.headline)

            TextField("Name", text: $name)
                .textFieldStyle(.roundedBorder)

            VStack(alignment: .leading) {
                Text("Prompt")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TextEditor(text: $prompt)
                    .frame(minHeight: 100)
                    .border(Color.secondary.opacity(0.3))
            }

            HStack {
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(isEditing ? "Save" : "Add", action: onSave)
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding()
        .frame(minWidth: 360, minHeight: 260)
    }
}
