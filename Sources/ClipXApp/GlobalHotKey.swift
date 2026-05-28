import AppKit
import Carbon
import Foundation

struct ClipXShortcut: Equatable {
    static let defaultHistory = ClipXShortcut(keyCode: 9, modifiers: UInt32(cmdKey | shiftKey))

    let keyCode: UInt32
    let modifiers: UInt32

    var displayText: String {
        let key = Self.keyName(for: keyCode)
        guard !modifierText.isEmpty else { return key }
        return "\(modifierText) \(key)"
    }

    static func loadHistoryShortcut() -> ClipXShortcut {
        guard UserDefaults.standard.object(forKey: "historyHotKeyKeyCode") != nil else {
            return .defaultHistory
        }
        let keyCode = UInt32(UserDefaults.standard.integer(forKey: "historyHotKeyKeyCode"))
        let modifiers = UInt32(UserDefaults.standard.integer(forKey: "historyHotKeyModifiers"))
        guard modifiers > 0 else {
            return .defaultHistory
        }
        return ClipXShortcut(keyCode: keyCode, modifiers: modifiers)
    }

    func saveHistoryShortcut() {
        UserDefaults.standard.set(Int(keyCode), forKey: "historyHotKeyKeyCode")
        UserDefaults.standard.set(Int(modifiers), forKey: "historyHotKeyModifiers")
        NotificationCenter.default.post(name: .clipXShortcutChanged, object: nil)
    }

    static func from(event: NSEvent) -> ClipXShortcut? {
        let modifiers = carbonModifiers(from: event.modifierFlags)
        guard modifiers > 0 else { return nil }
        guard keyName(for: UInt32(event.keyCode), event: event).isEmpty == false else { return nil }
        return ClipXShortcut(keyCode: UInt32(event.keyCode), modifiers: modifiers)
    }

    private var modifierText: String {
        var parts: [String] = []
        if modifiers & UInt32(controlKey) != 0 { parts.append("⌃") }
        if modifiers & UInt32(optionKey) != 0 { parts.append("⌥") }
        if modifiers & UInt32(shiftKey) != 0 { parts.append("⇧") }
        if modifiers & UInt32(cmdKey) != 0 { parts.append("⌘") }
        return parts.joined(separator: " ")
    }

    private static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var value: UInt32 = 0
        if flags.contains(.command) { value |= UInt32(cmdKey) }
        if flags.contains(.shift) { value |= UInt32(shiftKey) }
        if flags.contains(.option) { value |= UInt32(optionKey) }
        if flags.contains(.control) { value |= UInt32(controlKey) }
        return value
    }

    private static func keyName(for keyCode: UInt32, event: NSEvent? = nil) -> String {
        if let text = event?.charactersIgnoringModifiers,
           let first = text.unicodeScalars.first,
           CharacterSet.alphanumerics.contains(first) {
            return String(text.prefix(1)).uppercased()
        }
        switch keyCode {
        case 0: return "A"
        case 1: return "S"
        case 2: return "D"
        case 3: return "F"
        case 4: return "H"
        case 5: return "G"
        case 6: return "Z"
        case 7: return "X"
        case 8: return "C"
        case 9: return "V"
        case 11: return "B"
        case 12: return "Q"
        case 13: return "W"
        case 14: return "E"
        case 15: return "R"
        case 16: return "Y"
        case 17: return "T"
        case 18: return "1"
        case 19: return "2"
        case 20: return "3"
        case 21: return "4"
        case 22: return "6"
        case 23: return "5"
        case 24: return "="
        case 25: return "9"
        case 26: return "7"
        case 27: return "-"
        case 28: return "8"
        case 29: return "0"
        case 30: return "]"
        case 31: return "O"
        case 32: return "U"
        case 33: return "["
        case 34: return "I"
        case 35: return "P"
        case 37: return "L"
        case 38: return "J"
        case 39: return "'"
        case 40: return "K"
        case 41: return ";"
        case 42: return "\\"
        case 43: return ","
        case 44: return "/"
        case 45: return "N"
        case 46: return "M"
        case 47: return "."
        case 49: return "Space"
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        default: return ""
        }
    }
}

final class GlobalHotKey {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private let handler: () -> Void

    init(keyCode: UInt32, modifiers: UInt32, handler: @escaping () -> Void) {
        self.handler = handler
        var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData in
                guard let userData else { return noErr }
                let hotKey = Unmanaged<GlobalHotKey>.fromOpaque(userData).takeUnretainedValue()
                hotKey.handler()
                return noErr
            },
            1,
            &eventSpec,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )

        let hotKeyID = EventHotKeyID(signature: 0x434C5058, id: 1)
        RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    convenience init(shortcut: ClipXShortcut, handler: @escaping () -> Void) {
        self.init(keyCode: shortcut.keyCode, modifiers: shortcut.modifiers, handler: handler)
    }

    deinit {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        if let eventHandler {
            RemoveEventHandler(eventHandler)
        }
    }
}

extension GlobalHotKey {
    static func commandShiftV(handler: @escaping () -> Void) -> GlobalHotKey {
        GlobalHotKey(shortcut: ClipXShortcut.loadHistoryShortcut(), handler: handler)
    }
}
