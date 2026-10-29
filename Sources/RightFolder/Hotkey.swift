import Carbon.HIToolbox
import FolderCore

/// The ⌃⌥J shortcut, and ⌃⌥⇧J to go back. It's registered only while a dialog is open, so the
/// keys stay free for other apps the rest of the time. A registered shortcut only tells Right
/// Folder it was pressed; it never sees any other key.
@MainActor
final class Hotkey {
    var onPress: ((_ backwards: Bool) -> Void)?

    private var refs: [EventHotKeyRef] = []
    private var handler: EventHandlerRef?
    static let signature: OSType = 0x5246_4A4D // "RFJM"

    var isRegistered: Bool { !refs.isEmpty }

    func register() {
        guard refs.isEmpty else { return }
        installHandler()
        let key = UInt32(KeyLayout.keyCode(for: "j", in: Keyboard.table()) ?? UInt16(kVK_ANSI_J))
        let modifiers = UInt32(controlKey | optionKey)
        for (id, extra) in [(UInt32(1), UInt32(0)), (UInt32(2), UInt32(shiftKey))] {
            var ref: EventHotKeyRef?
            let hotKeyID = EventHotKeyID(signature: Self.signature, id: id)
            if RegisterEventHotKey(key, modifiers | extra, hotKeyID, GetApplicationEventTarget(), 0, &ref) == noErr, let ref {
                refs.append(ref)
            }
        }
    }

    func unregister() {
        for ref in refs { UnregisterEventHotKey(ref) }
        refs = []
    }

    private func installHandler() {
        guard handler == nil else { return }
        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, event, refcon in
            guard let event, let refcon else { return OSStatus(eventNotHandledErr) }
            var id = EventHotKeyID()
            let status = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
            guard status == noErr, id.signature == Hotkey.signature else { return OSStatus(eventNotHandledErr) }
            let hotkey = Unmanaged<Hotkey>.fromOpaque(refcon).takeUnretainedValue()
            MainActor.assumeIsolated { hotkey.onPress?(id.id == 2) }
            return noErr
        }, 1, &type, refcon, &handler)
    }
}
