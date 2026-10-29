import AppKit
import ApplicationServices
import Carbon.HIToolbox
import FolderCore

/// Carries out a jump on a real dialog. This is the only place Right Folder sends keys or changes
/// anything in another app, and every key goes to the dialog's app alone, never to whatever happens
/// to be in front.
@MainActor
final class LiveDialog: DialogDriver {
    typealias Field = AXUIElement

    let dialog: OpenDialog
    private let app: AXUIElement
    private let source = CGEventSource(stateID: .privateState)

    init(_ dialog: OpenDialog) {
        self.dialog = dialog
        app = AX.app(dialog.pid)
    }

    func dialogIsFront() -> Bool {
        NSWorkspace.shared.frontmostApplication?.processIdentifier == dialog.pid && AX.exists(dialog.element)
    }

    func focusedField() -> (field: AXUIElement, role: String?, subrole: String?)? {
        guard let focused = AX.element(app, kAXFocusedUIElementAttribute) else { return nil }
        return (focused, AX.role(focused), AX.subrole(focused))
    }

    func same(_ a: AXUIElement, _ b: AXUIElement) -> Bool {
        CFEqual(a, b)
    }

    /// Whether the field is inside the dialog: the dialog itself is one of the elements above it.
    /// A field in any other window, even another Open or Save panel, doesn't count.
    func isInDialog(_ field: AXUIElement) -> Bool {
        var element = field
        for _ in 0..<16 {
            guard let parent = AX.element(element, kAXParentAttribute) else { return false }
            if CFEqual(parent, dialog.element) { return true }
            if AX.role(parent) == "AXApplication" { return false }
            element = parent
        }
        return false
    }

    func now() -> TimeInterval {
        ProcessInfo.processInfo.systemUptime
    }

    func pressGoToFolder() -> Bool {
        // ⌘ shortcuts go by what the key types with ⌘ held, which on some layouts, like
        // "Dvorak – QWERTY ⌘", is a different key from the one that types g.
        let g = KeyLayout.keyCode(for: "g", in: Keyboard.table(command: true)) ?? 5
        return press(g, flags: [.maskCommand, .maskShift], text: "g")
    }

    func setValue(_ text: String, in field: AXUIElement) -> Bool {
        AXUIElementSetAttributeValue(field, kAXValueAttribute as CFString, text as CFString) == .success
    }

    /// Read back only from the Go to Folder field, to check the path went in.
    func value(of field: AXUIElement) -> String? {
        AX.string(field, kAXValueAttribute)
    }

    func type(_ text: String) -> Bool {
        guard AXIsProcessTrusted() else { return false }
        // Typed as text, a few whole characters per key event, so it doesn't depend on the
        // keyboard layout and no character is split in two.
        for piece in GoTo.chunks(text) {
            let chunk = Array(piece.utf16)
            for down in [true, false] {
                guard let event = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: down) else { return false }
                event.flags = []
                chunk.withUnsafeBufferPointer { event.keyboardSetUnicodeString(stringLength: chunk.count, unicodeString: $0.baseAddress) }
                event.postToPid(dialog.pid)
            }
        }
        return true
    }

    func pressReturn() -> Bool {
        press(KeyLayout.returnKey, flags: [], text: "\r")
    }

    func wait(_ seconds: TimeInterval) async {
        try? await Task.sleep(for: .seconds(seconds))
    }

    private func press(_ key: UInt16, flags: CGEventFlags, text: String) -> Bool {
        guard AXIsProcessTrusted() else { return false }
        let units = Array(text.utf16)
        for down in [true, false] {
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: down) else { return false }
            event.flags = flags
            units.withUnsafeBufferPointer { event.keyboardSetUnicodeString(stringLength: units.count, unicodeString: $0.baseAddress) }
            event.postToPid(dialog.pid)
        }
        return true
    }
}

/// What each key types on the keyboard layout you're using, so ⇧⌘G and the shortcut use the right
/// keys on Dvorak, AZERTY and the rest.
enum Keyboard {
    /// What each key types with no modifiers, or with ⌘ held.
    static func table(command: Bool = false) -> [UInt16: String] {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue() ?? TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue(),
              let pointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else { return [:] }
        let data = Unmanaged<CFData>.fromOpaque(pointer).takeUnretainedValue() as Data
        var table: [UInt16: String] = [:]
        data.withUnsafeBytes { raw in
            guard let layout = raw.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else { return }
            for code in UInt16(0)..<128 {
                var deadKeys: UInt32 = 0
                var length = 0
                var chars = [UniChar](repeating: 0, count: 4)
                let modifiers = command ? UInt32(cmdKey >> 8) & 0xFF : 0
                let status = UCKeyTranslate(layout, code, UInt16(kUCKeyActionDisplay), modifiers, UInt32(LMGetKbdType()), OptionBits(1 << kUCKeyTranslateNoDeadKeysBit), &deadKeys, chars.count, &length, &chars)
                if status == noErr, length > 0 {
                    table[code] = String(utf16CodeUnits: chars, count: length)
                }
            }
        }
        return table
    }
}
