import AppKit
import FolderCore
import SwiftUI

/// The main window: whether it's ready, your favorites to reorder and remove, recent folders, and
/// the apps you've turned it off in.
struct FolderWindowView: View {
    @Bindable var model: FolderModel
    var allow: @MainActor () -> Void = {}
    var addFavorite: @MainActor () -> Void = {}
    var appName: @MainActor (String) -> String = { $0 }
    /// Your accent color in the app; a fixed blue in the screenshots.
    var tint = Color.accentColor

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if !model.trusted {
                permission
                Divider()
            }
            HStack(alignment: .top, spacing: 0) {
                favorites
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                Divider()
                VStack(alignment: .leading, spacing: 18) {
                    recents
                    apps
                }
                .padding(16)
                .frame(width: 300)
                .frame(maxHeight: .infinity, alignment: .top)
            }
            Divider()
            footer
        }
        .frame(minWidth: 640, minHeight: 420)
        // The window draws this anyway; drawing it here too keeps off-screen renders right in dark mode.
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "folder.fill")
                .font(.system(size: 26))
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(Describe.headline(model.status))
                    .font(.title2.weight(.semibold))
                Text(Describe.detail(model.status))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(16)
    }

    private var permission: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "hand.raised.fill")
                .font(.title2)
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 6) {
                Text("Right Folder needs Accessibility")
                    .font(.headline)
                Text("It uses it to notice Open and Save dialogs, read which folder each Finder window shows, and press ⇧⌘G in a dialog when you pick a folder. It never reads what you type or what's in your windows, and it has no internet access.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Already in the list after an update? Select Right Folder, click –, then click Allow Accessibility again.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Allow Accessibility…", action: allow)
                    .controlSize(.large)
                    .padding(.top, 2)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.08))
    }

    // MARK: Favorites

    private var favorites: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Favorites").font(.headline)
                Spacer()
                Button("Add Folder…", systemImage: "plus", action: addFavorite)
            }
            if model.list.favorites.isEmpty {
                Text("Pin the folders you save to most. Click the pin beside any folder in the panel, or Add Folder.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
            } else {
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(Array(model.list.favorites.enumerated()), id: \.element.id) { index, entry in
                            favoriteRow(entry, index: index, count: model.list.favorites.count)
                        }
                    }
                }
            }
        }
        .padding(16)
    }

    private func favoriteRow(_ entry: FolderEntry, index: Int, count: Int) -> some View {
        HStack(spacing: 10) {
            Image(systemName: JumpView.symbol(entry.info.place))
                .foregroundStyle(entry.availability.canJump ? tint : Color.secondary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text(Describe.safe(entry.info.name, limit: 60)).lineLimit(1)
                // iCloud's real folders have long hidden names, so those are named the way Finder does.
                Text(Describe.safe(entry.info.place == .iCloud ? entry.info.location + " › " + entry.info.name : Paths.abbreviate(entry.path, home: model.system.context().home), limit: 300))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            if let note = Describe.availability(entry.availability), entry.availability != .network {
                Text(note).font(.caption).foregroundStyle(.secondary)
            }
            Button { model.move(entry.path, by: -1) } label: { Image(systemName: "chevron.up") }
                .disabled(index == 0)
                .accessibilityLabel("Move \(Describe.safe(entry.info.name)) up")
            Button { model.move(entry.path, by: 1) } label: { Image(systemName: "chevron.down") }
                .disabled(index == count - 1)
                .accessibilityLabel("Move \(Describe.safe(entry.info.name)) down")
            Button { model.unpin(entry.path) } label: { Image(systemName: "xmark") }
                .accessibilityLabel("Remove \(Describe.safe(entry.info.name))")
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(index.isMultiple(of: 2) ? 0.04 : 0)))
    }

    // MARK: Recents and apps

    private var recents: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Recent").font(.headline)
                Spacer()
                Button("Clear") { model.clearRecents() }
                    .disabled(model.recents.paths.isEmpty)
            }
            Toggle("Remember recent folders", isOn: Binding(get: { model.remembersRecents }, set: { model.setRemembersRecents($0) }))
                .toggleStyle(.checkbox)
            if model.recents.paths.isEmpty {
                Text("Folders you jump to, and the one open in Finder when a dialog appears, are listed here.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(model.recents.paths.prefix(6), id: \.self) { path in
                    HStack {
                        Text(Describe.safe(Paths.abbreviate(path, home: model.system.context().home), limit: 300))
                            .font(.callout)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Button { model.forget(path) } label: { Image(systemName: "xmark") }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Forget \(Describe.safe(path, limit: 300))")
                    }
                }
            }
        }
    }

    private var apps: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Turned off in").font(.headline)
            if model.excludedApps.isEmpty {
                Text("None. To turn it off in an app, open a dialog there and choose Turn Off from the panel's ··· menu.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(model.excludedApps.sorted(), id: \.self) { id in
                    HStack {
                        Text(Describe.safe(appName(id), limit: 40)).font(.callout)
                        Spacer()
                        Button("Turn On") { model.setExcluded(id, false) }
                    }
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            Text("When an Open or Save dialog appears, its folders show up beside it. Click one, or press \(Describe.shortcut).")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text("No internet access").font(.caption).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

@MainActor
final class FolderWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let makeView: () -> FolderWindowView
    /// Called when you close the window.
    var onClose: (() -> Void)?
    /// Called when the window comes to the front.
    var onActivate: (() -> Void)?

    init(makeView: @escaping () -> FolderWindowView) {
        self.makeView = makeView
    }

    var isVisible: Bool { window?.isVisible == true }

    func show() {
        let window = self.window ?? makeWindow()
        self.window = window
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        onClose?()
    }

    func windowDidBecomeKey(_ notification: Notification) {
        onActivate?()
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(contentViewController: NSHostingController(rootView: makeView()))
        window.title = "Right Folder"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.setContentSize(NSSize(width: 760, height: 520))
        if !window.setFrameUsingName("FolderWindow") {
            window.center()
        }
        window.setFrameAutosaveName("FolderWindow")
        return window
    }
}
