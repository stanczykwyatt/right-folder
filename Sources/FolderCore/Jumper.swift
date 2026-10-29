import Foundation

/// The steps of a jump, as the app carries them out on a real dialog, so the order and every way
/// it can stop are tested with made-up dialogs.
@MainActor
public protocol DialogDriver: AnyObject {
    associatedtype Field
    /// Whether the dialog is still open and its app still in front.
    func dialogIsFront() -> Bool
    /// The text field holding the keyboard in the dialog's app, with its role and subrole.
    func focusedField() -> (field: Field, role: String?, subrole: String?)?
    func same(_ a: Field, _ b: Field) -> Bool
    /// Whether a field is part of the dialog, not some other window of the same app.
    func isInDialog(_ field: Field) -> Bool
    /// Presses ⇧⌘G in the dialog's app.
    func pressGoToFolder() -> Bool
    /// Puts text in a field directly, without typing it.
    func setValue(_ text: String, in field: Field) -> Bool
    /// What a field holds, or nil if it won't say.
    func value(of field: Field) -> String?
    /// Types text into the dialog's app, for a field that can't be set directly.
    func type(_ text: String) -> Bool
    func pressReturn() -> Bool
    func wait(_ seconds: TimeInterval) async
    /// A clock, in seconds, for the time limit.
    func now() -> TimeInterval
}

public enum JumpResult: Equatable, Sendable {
    case done
    case failed(GoTo.Failure)
}

@MainActor
public enum Jumper {
    /// Sends the dialog to `path`. With `typing`, the path is always typed into the field rather
    /// than set in it, for dialogs that only notice typed text.
    ///
    /// The Go to Folder field must be found for certain: a text field inside the dialog that took
    /// the keyboard after ⇧⌘G. Anything less and it stops having sent only ⇧⌘G, since Return in
    /// the wrong field of a Save dialog would save the file.
    public static func jump<Driver: DialogDriver>(to path: String, home: String, typing: Bool = false, with driver: Driver) async -> JumpResult {
        guard driver.dialogIsFront() else { return .failed(.dialogGone) }
        // Without knowing what had the keyboard before, a newly focused field can't be told
        // apart from the dialog's own name field.
        guard let before = driver.focusedField() else { return .failed(.noField) }
        guard driver.pressGoToFolder() else { return .failed(.notAllowed) }

        // Wait for the Go to Folder field to take the keyboard.
        var field: Driver.Field?
        let deadline = driver.now() + GoTo.fieldTimeout
        while driver.now() < deadline {
            await driver.wait(GoTo.pollInterval)
            guard driver.dialogIsFront() else { return .failed(.dialogGone) }
            if let focused = driver.focusedField(),
               GoTo.isGoToField(role: focused.role, subrole: focused.subrole, wasFocusedBefore: driver.same(before.field, focused.field)),
               driver.isInDialog(focused.field) {
                field = focused.field
                break
            }
        }
        guard let field else { return .failed(.noField) }

        /// Whether the Go to Folder field still has the keyboard, in the dialog that's still in front.
        func stillThere() -> Bool {
            guard driver.dialogIsFront(), let focused = driver.focusedField() else { return false }
            return driver.same(focused.field, field) && driver.isInDialog(field)
        }

        // Set the path in the field. If the field won't take it that way, type it, but only if it's
        // still the field holding the keyboard, so the keys can't land anywhere else.
        let text = GoTo.text(for: path)
        guard stillThere() else { return .failed(.dialogGone) }
        if typing || !(driver.setValue(text, in: field) && GoTo.fieldHolds(driver.value(of: field), path: path, home: home)) {
            guard stillThere() else { return .failed(.dialogGone) }
            // Empty the field first, so the path isn't added to whatever it held.
            _ = driver.setValue("", in: field)
            guard driver.type(text) else { return .failed(.notAllowed) }
        }
        // Give the field a moment to show its match for the path, then go.
        await driver.wait(0.1)
        // A field that says what it holds must hold the path. One that won't say is trusted,
        // since Return there can only go to a folder.
        if let value = driver.value(of: field), !GoTo.fieldHolds(value, path: path, home: home) {
            return .failed(.pathRejected)
        }
        // Return only ever goes to the Go to Folder field. Pressed anywhere else in a Save dialog,
        // it would click Save.
        guard stillThere() else { return .failed(.dialogGone) }
        guard driver.pressReturn() else { return .failed(.notAllowed) }
        return .done
    }
}
