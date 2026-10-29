import AppKit
import ApplicationServices
import FolderCore

/// An Open or Save dialog that's open right now, in the app in front.
struct OpenDialog {
    var pid: pid_t
    var appName: String
    var bundleID: String?
    var kind: DialogKind
    var element: AXUIElement
    var frame: CGRect?

    func isSame(as other: OpenDialog?) -> Bool {
        guard let other else { return false }
        return pid == other.pid && CFEqual(element, other.element)
    }
}

/// Watches the app in front for an Open or Save dialog, with Accessibility notifications from
/// that one app: a window or sheet appearing, focus moving, the dialog moving or closing. Nothing
/// is watched in other apps, nothing is read from inside windows, and no keys are seen.
@MainActor
final class DialogWatcher {
    var onChange: ((OpenDialog?) -> Void)?
    private(set) var dialog: OpenDialog?

    private var observer: AXObserver?
    private var watchedPID: pid_t?
    private var watchedDialog: AXUIElement?
    private var pending = false
    private var timer: Timer?
    private var activation: NSObjectProtocol?
    /// Apps that stopped answering, left alone until the time given, so a hung app can't hold
    /// Right Folder up again and again.
    private var backoff: [pid_t: Date] = [:]
    static let backoffTime: TimeInterval = 3

    static let appNotifications = [
        kAXFocusedWindowChangedNotification, kAXWindowCreatedNotification, kAXSheetCreatedNotification,
        kAXFocusedUIElementChangedNotification, kAXMainWindowChangedNotification,
    ]
    static let dialogNotifications = [kAXMovedNotification, kAXResizedNotification, kAXUIElementDestroyedNotification]

    func start() {
        guard activation == nil else { return }
        activation = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.watchFrontApp() }
        }
        watchFrontApp()
    }

    func stop() {
        if let activation { NSWorkspace.shared.notificationCenter.removeObserver(activation) }
        activation = nil
        unwatch()
        update(nil)
    }

    /// Looks again soon, gathering a burst of notifications into one look.
    func scheduleCheck() {
        guard !pending else { return }
        pending = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            MainActor.assumeIsolated {
                self?.pending = false
                self?.check()
            }
        }
    }

    private func watchFrontApp() {
        guard let app = NSWorkspace.shared.frontmostApplication else {
            unwatch()
            update(nil)
            return
        }
        if app.processIdentifier != watchedPID {
            unwatch()
            watch(app.processIdentifier)
        }
        check()
    }

    private func watch(_ pid: pid_t) {
        guard pid != getpid(), AXIsProcessTrusted() else { return }
        var created: AXObserver?
        guard AXObserverCreate(pid, { _, element, notification, refcon in
            guard let refcon else { return }
            let watcher = Unmanaged<DialogWatcher>.fromOpaque(refcon).takeUnretainedValue()
            MainActor.assumeIsolated { watcher.scheduleCheck() }
            _ = element
            _ = notification
        }, &created) == .success, let created else { return }
        let app = AX.app(pid)
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        for name in Self.appNotifications {
            AXObserverAddNotification(created, app, name as CFString, refcon)
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(created), .defaultMode)
        observer = created
        watchedPID = pid
    }

    private func unwatch() {
        if let observer {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
        }
        observer = nil
        watchedPID = nil
        watchedDialog = nil
    }

    /// Finds the dialog in the front app's focused window, if there is one.
    func check() {
        guard AXIsProcessTrusted(), let app = NSWorkspace.shared.frontmostApplication, app.processIdentifier != getpid() else {
            update(nil)
            return
        }
        let pid = app.processIdentifier
        if let until = backoff[pid], until > Date() { return }
        backoff[pid] = nil
        if observer == nil || watchedPID != pid {
            unwatch()
            watch(pid)
        }
        AX.timedOut = false
        let appElement = AX.app(pid)
        let window = AX.element(appElement, kAXFocusedWindowAttribute)
        let snapshot = window.map { AX.snapshot($0) }
        if AX.timedOut {
            // The app is busy, which isn't the same as the dialog closing. Keep what's showing and
            // look again in a few seconds.
            backoff[pid] = Date().addingTimeInterval(Self.backoffTime)
            return
        }
        guard let snapshot else {
            // No focused window to read. If the dialog is still there, this is a hiccup, not a close.
            if let dialog, dialog.pid == pid, AX.exists(dialog.element), !AX.timedOut { return }
            update(nil)
            return
        }
        guard let match = Dialogs.find(in: snapshot.element), let element = AX.follow(match.path, in: snapshot.node) else {
            update(nil)
            return
        }
        update(OpenDialog(
            pid: pid, appName: app.localizedName ?? "this app", bundleID: app.bundleIdentifier,
            kind: match.kind, element: element, frame: AX.frame(element)
        ))
    }

    private func update(_ new: OpenDialog?) {
        let changed = !(new?.isSame(as: dialog) ?? (dialog == nil)) || new?.frame != dialog?.frame || new?.kind != dialog?.kind
        dialog = new
        watchDialog(new?.element)
        // While a dialog is up, look again now and then, in case it moved without saying so.
        if new != nil, timer == nil {
            let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.check() }
            }
            timer.tolerance = 0.3
            RunLoop.main.add(timer, forMode: .common)
            self.timer = timer
        } else if new == nil {
            timer?.invalidate()
            timer = nil
        }
        if changed { onChange?(new) }
    }

    private func watchDialog(_ element: AXUIElement?) {
        guard let observer else { return }
        if let watchedDialog, let element, CFEqual(watchedDialog, element) { return }
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        if let watchedDialog {
            for name in Self.dialogNotifications { AXObserverRemoveNotification(observer, watchedDialog, name as CFString) }
        }
        watchedDialog = element
        if let element {
            for name in Self.dialogNotifications { AXObserverAddNotification(observer, element, name as CFString, refcon) }
        }
    }
}
