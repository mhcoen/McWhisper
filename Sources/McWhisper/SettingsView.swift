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
    @State private var isRecordingHotkey = false
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            Section("Push-to-Talk Hotkey") {
                HStack {
                    Text("Hotkey:")
                    Spacer()
                    Button(action: { isRecordingHotkey.toggle() }) {
                        Text(isRecordingHotkey ? "Press a key..." : hotkeyDisplayString)
                            .frame(minWidth: 120)
                    }
                    .hotkeyRecorder(
                        isRecording: $isRecordingHotkey,
                        keyCode: $hotkeyKeyCode,
                        modifiers: $hotkeyModifiers
                    )
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

    var hotkeyDisplayString: String {
        HotkeyFormatter.displayString(keyCode: hotkeyKeyCode, modifiers: hotkeyModifiers)
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

// MARK: - Hotkey Recorder Modifier

struct HotkeyRecorderModifier: ViewModifier {
    @Binding var isRecording: Bool
    @Binding var keyCode: Int
    @Binding var modifiers: Int

    func body(content: Content) -> some View {
        content
            .background(
                HotkeyRecorderEventHandler(
                    isRecording: $isRecording,
                    keyCode: $keyCode,
                    modifiers: $modifiers
                )
                .frame(width: 0, height: 0)
            )
    }
}

extension View {
    func hotkeyRecorder(isRecording: Binding<Bool>, keyCode: Binding<Int>, modifiers: Binding<Int>) -> some View {
        modifier(HotkeyRecorderModifier(isRecording: isRecording, keyCode: keyCode, modifiers: modifiers))
    }
}

struct HotkeyRecorderEventHandler: NSViewRepresentable {
    @Binding var isRecording: Bool
    @Binding var keyCode: Int
    @Binding var modifiers: Int

    func makeNSView(context: Context) -> HotkeyRecorderNSView {
        let view = HotkeyRecorderNSView()
        view.onKeyEvent = { code, mods in
            keyCode = code
            modifiers = mods
            isRecording = false
        }
        return view
    }

    func updateNSView(_ nsView: HotkeyRecorderNSView, context: Context) {
        nsView.isRecordingHotkey = isRecording
        if isRecording {
            nsView.window?.makeFirstResponder(nsView)
        }
    }
}

final class HotkeyRecorderNSView: NSView {
    var isRecordingHotkey = false
    var onKeyEvent: ((Int, Int) -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        guard isRecordingHotkey else {
            super.keyDown(with: event)
            return
        }
        if event.keyCode == UInt16(kVK_Escape) {
            // Cancel recording on Escape
            isRecordingHotkey = false
            onKeyEvent = nil
            return
        }
        let relevantMask: NSEvent.ModifierFlags = [.shift, .control, .option, .command]
        let mods = Int(event.modifierFlags.intersection(relevantMask).rawValue)
        onKeyEvent?(Int(event.keyCode), mods)
    }
}

// MARK: - Models Tab

struct ModelsSettingsTab: View {
    @AppStorage(AppSettings.Keys.selectedModelID) private var selectedModelID: String = AppSettings.defaultModelID

    var body: some View {
        Form {
            Section("Active Model") {
                Picker("Model:", selection: $selectedModelID) {
                    ForEach(ModelCatalog.availableModels) { model in
                        Text("\(model.displayName) (\(model.sizeLabel))")
                            .tag(model.id)
                    }
                }
            }

            Section("Available Models") {
                ForEach(ModelCatalog.availableModels) { model in
                    ModelRow(model: model, isSelected: model.id == selectedModelID)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct ModelRow: View {
    let model: ModelInfo
    let isSelected: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
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
            }
            Spacer()
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.accentColor)
            }
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
