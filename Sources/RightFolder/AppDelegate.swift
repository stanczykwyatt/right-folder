import AppKit
import FolderCore
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, StatusMenuActions {
    private let preferences = Preferences()
    private let menu = NSMenu()
    private var statusItem: NSStatusItem!
    private let watcher = DialogWatcher()
    private let hotkey = Hotkey()
    private var trustTimer: Timer?
    private var lastDialog: OpenDialog?
    private var dialogCount = 0
    private lazy var model = FolderModel(preferences: preferences, isTrusted: { Accessibility.isTrusted })
    private lazy var statusMenu = StatusMenu(model: model, actions: self)
    private lazy var panel = JumpPanelController(view: JumpView(
        model: model,
        jump: { [unowned self] path in
            Task {
                await self.model.jump(to: path)
                // The list may have changed, so the panel's height may too.
                self.updatePanel()
            }
        },
        pin: { [unowned self] in model.pin($0); updatePanel() },
        unpin: { [unowned self] in model.unpin($0); updatePanel() },
        turnOffHere: { [unowned self] in turnOffInCurrentApp() },
        openWindow: { [unowned self] in openWindow() }
    ))
    private lazy var window = FolderWindowController { [unowned self] in
        FolderWindowView(model: model, allow: { [unowned self] in allowAccessibility() }, addFavorite: { [unowned self] in pinFolder() }, appName: LiveFolderSystem.appName)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        menu.delegate = self
        statusItem.menu = menu

        model.jumper = { [unowned self] path in
            guard let dialog = watcher.dialog else { return .failed(.dialogGone) }
            return await Jumper.jump(to: path, home: NSHomeDirectory(), typing: preferences.typesPaths, with: LiveDialog(dialog))
        }
        watcher.onChange = { [weak self] dialog in self?.dialogChanged(dialog) }
        hotkey.onPress = { [weak self] backwards in
            guard let self else { return }
            Task {
                await self.model.step(backwards: backwards)
                self.updatePanel()
            }
        }
        window.onClose = { [weak self] in
            self?.stopWatchingTrust()
            // Gives the keyboard back to the app you were using.
            NSApp.hide(nil)
        }
        window.onActivate = { [weak self] in self?.trustChanged() }
        Accessibility.observe { [weak self] in self?.trustChanged() }

        watcher.start()
        updateStatusItem()

        // The first time, open at login like most menu bar utilities, and show the window so it's
        // clear what the app does and that it needs Accessibility. Turn off login in the menu.
        if !preferences.launchedBefore {
            preferences.launchedBefore = true
            try? SMAppService.mainApp.register()
            openWindow()
        } else if !Accessibility.isTrusted {
            openWindow()
        }
    }

    // MARK: Dialogs

    private func dialogChanged(_ dialog: OpenDialog?) {
        if let dialog {
            if !dialog.isSame(as: lastDialog) { dialogCount += 1 }
            model.dialogOpened(FolderModel.Dialog(kind: dialog.kind, appName: dialog.appName, bundleID: dialog.bundleID, id: dialogCount))
        } else {
            model.dialogClosed()
        }
        lastDialog = dialog
        updatePanel()
    }

    private func updatePanel() {
        if model.showsPanel, let dialog = watcher.dialog {
            panel.show(beside: dialog.frame)
            hotkey.register()
        } else {
            panel.hide()
            hotkey.unregister()
        }
    }

    private func turnOffInCurrentApp() {
        guard let id = model.dialog?.bundleID else { return }
        model.setExcluded(id, true)
        updatePanel()
    }

    // MARK: Accessibility

    private func trustChanged() {
        let was = model.trusted
        model.refresh()
        updateStatusItem()
        if model.trusted != was {
            // Start watching dialogs now that it's allowed, or stop now that it isn't.
            watcher.stop()
            watcher.start()
        }
        if model.trusted { stopWatchingTrust() }
    }

    /// While the window is open waiting for Accessibility, looks every couple of seconds, since
    /// macOS doesn't always say when it's turned on.
    private func watchTrust() {
        guard trustTimer == nil, !model.trusted else { return }
        let timer = Timer(timeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.trustChanged() }
        }
        RunLoop.main.add(timer, forMode: .common)
        trustTimer = timer
    }

    private func stopWatchingTrust() {
        trustTimer?.invalidate()
        trustTimer = nil
    }

    private func updateStatusItem() {
        guard let button = statusItem?.button else { return }
        button.image = StatusIcon.image(alert: !model.trusted, paused: model.paused)
        button.toolTip = "Right Folder\n" + Describe.headline(model.status)
    }

    // MARK: Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        model.refresh()
        updateStatusItem()
        statusMenu.build(into: menu)
    }

    // MARK: StatusMenuActions

    func allowAccessibility() {
        Accessibility.ask()
        Accessibility.openSettings()
        openWindow()
    }

    func pinFolder() {
        // Right Folder's own folder picker, which it never offers its panel for.
        let picker = NSOpenPanel()
        picker.canChooseDirectories = true
        picker.canChooseFiles = false
        picker.allowsMultipleSelection = true
        picker.prompt = "Pin"
        picker.message = "Choose folders to add to your favorites."
        NSApp.activate()
        guard picker.runModal() == .OK else { return }
        for url in picker.urls { model.pin(url.path(percentEncoded: false)) }
    }

    func pinFinderFolder(_ path: String) {
        model.pin(path)
    }

    func togglePaused() {
        model.setPaused(!model.paused)
        updateStatusItem()
        updatePanel()
    }

    func toggleRemembersRecents() {
        model.setRemembersRecents(!model.remembersRecents)
    }

    func clearRecents() {
        model.clearRecents()
    }

    func openWindow() {
        model.refresh()
        window.show()
        watchTrust()
    }

    func toggleOpenAtLogin() {
        if SMAppService.mainApp.status == .enabled {
            try? SMAppService.mainApp.unregister()
        } else {
            try? SMAppService.mainApp.register()
        }
    }

    func showAbout() {
        NSApp.activate()
        NSApp.orderFrontStandardAboutPanel(options: [
            .credits: NSAttributedString(
                string: "Free and open source. No internet access.\ngithub.com/stanczykwyatt/right-folder",
                attributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.secondaryLabelColor]
            ),
        ])
    }
}
