import AppKit
@preconcurrency import Carbon

extension HotKey {
    static let defaultValue = HotKey(
        keyCode: UInt32(kVK_ANSI_C),
        modifiers: UInt32(optionKey | cmdKey),
        keyLabel: "C"
    )

    var displayText: String {
        var text = ""
        if modifiers & UInt32(controlKey) != 0 { text += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { text += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { text += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { text += "⌘" }
        return text + keyLabel
    }

    init?(event: NSEvent) {
        let relevantFlags = event.modifierFlags.intersection([.control, .option, .shift, .command])
        var carbonModifiers: UInt32 = 0
        if relevantFlags.contains(.control) { carbonModifiers |= UInt32(controlKey) }
        if relevantFlags.contains(.option) { carbonModifiers |= UInt32(optionKey) }
        if relevantFlags.contains(.shift) { carbonModifiers |= UInt32(shiftKey) }
        if relevantFlags.contains(.command) { carbonModifiers |= UInt32(cmdKey) }

        let label = Self.label(for: event)
        guard !label.isEmpty else { return nil }
        self.init(keyCode: UInt32(event.keyCode), modifiers: carbonModifiers, keyLabel: label)
    }

    private static func label(for event: NSEvent) -> String {
        switch Int(event.keyCode) {
        case kVK_Return: return "↩"
        case kVK_Tab: return "⇥"
        case kVK_Space: return "Space"
        case kVK_Delete: return "⌫"
        case kVK_ForwardDelete: return "⌦"
        case kVK_Home: return "Home"
        case kVK_End: return "End"
        case kVK_PageUp: return "Page Up"
        case kVK_PageDown: return "Page Down"
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_DownArrow: return "↓"
        case kVK_UpArrow: return "↑"
        default:
            return functionKeyLabel(for: Int(event.keyCode))
                ?? event.charactersIgnoringModifiers?.uppercased()
                ?? ""
        }
    }

    private static func functionKeyLabel(for keyCode: Int) -> String? {
        let mapping = [
            kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4",
            kVK_F5: "F5", kVK_F6: "F6", kVK_F7: "F7", kVK_F8: "F8",
            kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
            kVK_F13: "F13", kVK_F14: "F14", kVK_F15: "F15", kVK_F16: "F16",
            kVK_F17: "F17", kVK_F18: "F18", kVK_F19: "F19", kVK_F20: "F20"
        ]
        return mapping[keyCode]
    }
}

@MainActor
final class HotKeyManager {
    private static let signature: OSType = 0x4155_434C // AUCL

    private var eventHandler: EventHandlerRef?
    private var hotKeyRef: EventHotKeyRef?
    private var action: (() -> Void)?

    init(action: @escaping () -> Void) {
        self.action = action

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData in
                guard let userData else { return noErr }
                let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
                MainActor.assumeIsolated {
                    manager.action?()
                }
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )
    }

    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let eventHandler { RemoveEventHandler(eventHandler) }
    }

    @discardableResult
    func register(_ hotKey: HotKey) -> Bool {
        unregister()

        let identifier = EventHotKeyID(signature: Self.signature, id: 1)
        let status = RegisterEventHotKey(
            hotKey.keyCode,
            hotKey.modifiers,
            identifier,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        if status != noErr {
            hotKeyRef = nil
            return false
        }
        return true
    }

    func unregister() {
        guard let hotKeyRef else { return }
        UnregisterEventHotKey(hotKeyRef)
        self.hotKeyRef = nil
    }

    static func isValid(_ hotKey: HotKey) -> Bool {
        let primaryModifiers = UInt32(cmdKey | optionKey | controlKey)
        guard hotKey.modifiers & primaryModifiers != 0 else { return false }

        let commandOnly = hotKey.modifiers == UInt32(cmdKey)
        if commandOnly && (hotKey.keyCode == UInt32(kVK_ANSI_Q) || hotKey.keyCode == UInt32(kVK_ANSI_W)) {
            return false
        }
        return true
    }
}
