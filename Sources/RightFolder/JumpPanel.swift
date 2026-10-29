import AppKit
import FolderCore
import SwiftUI

/// The panel beside a dialog: the folders it can go to, a click each.
struct JumpView: View {
    @Bindable var model: FolderModel
    var jump: @MainActor (String) -> Void = { _ in }
    var pin: @MainActor (String) -> Void = { _ in }
    var unpin: @MainActor (String) -> Void = { _ in }
    var turnOffHere: @MainActor () -> Void = {}
    var openWindow: @MainActor () -> Void = {}
    /// Your accent color in the app; a fixed blue in the screenshots.
    var tint = Color.accentColor

    static let width: CGFloat = 268

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if model.list.isEmpty {
                empty
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        section(.finder, model.list.finder)
                        section(.favorite, model.list.favorites)
                        section(.recent, model.list.recents)
                    }
                    .padding(.horizontal, 6)
                    .padding(.bottom, 6)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            if let message = model.message {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .symbolRenderingMode(.multicolor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Divider()
            footer
        }
        .frame(width: Self.width)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.separator, lineWidth: 0.5))
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "arrowshape.turn.up.right")
                .foregroundStyle(.secondary)
            Text(model.dialog?.kind == .save ? "Save to…" : "Open from…")
                .font(.headline)
            Spacer()
            Menu {
                Button("Open Right Folder…", action: openWindow)
                if let app = model.dialog?.appName {
                    Button("Turn Off in \(Describe.safe(app, limit: 30))", action: turnOffHere)
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .accessibilityLabel("More")
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }

    private var empty: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("No folders yet")
                .font(.callout.weight(.medium))
            Text("Open a folder in Finder, or pin one from Right Folder's menu, and it shows up here.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
    }

    @ViewBuilder
    private func section(_ source: FolderEntry.Source, _ entries: [FolderEntry]) -> some View {
        if !entries.isEmpty {
            Text(Describe.section(source))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.top, 6)
                .padding(.bottom, 1)
            ForEach(entries) { entry in
                row(entry)
            }
        }
    }

    private func row(_ entry: FolderEntry) -> some View {
        let enabled = entry.availability.canJump && model.jumping == nil
        return HStack(spacing: 8) {
            Button {
                jump(entry.path)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: Self.symbol(entry.info.place))
                        .font(.system(size: 15))
                        .foregroundStyle(entry.availability.canJump ? tint : Color.secondary)
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(Describe.safe(entry.info.name, limit: 40))
                            .font(.callout)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        // A network folder's icon already says so; its server's name says more.
                        Text(entry.availability == .network ? Describe.safe(entry.info.location, limit: 60) : Describe.availability(entry.availability) ?? Describe.safe(entry.info.location, limit: 60))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.head)
                    }
                    Spacer(minLength: 0)
                    if model.jumping == entry.path {
                        ProgressView().controlSize(.small)
                    } else if entry.isOpenInFinder {
                        Image(systemName: "macwindow")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .help("Open in Finder")
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!enabled)
            .help(Describe.safe(Paths.abbreviate(entry.path, home: NSHomeDirectory()), limit: 300))

            Button {
                entry.source == .favorite ? unpin(entry.path) : pin(entry.path)
            } label: {
                Image(systemName: entry.source == .favorite ? "pin.fill" : "pin")
                    .font(.caption)
                    .foregroundStyle(entry.source == .favorite ? tint : Color.secondary)
            }
            .buttonStyle(.plain)
            .help(entry.source == .favorite ? "Remove from Favorites" : "Add to Favorites")
            .accessibilityLabel(entry.source == .favorite ? "Unpin \(Describe.safe(entry.info.name))" : "Pin \(Describe.safe(entry.info.name))")
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .opacity(entry.availability.canJump ? 1 : 0.55)
    }

    private var footer: some View {
        HStack(spacing: 4) {
            Text(Describe.shortcut).font(.caption.monospaced().weight(.medium))
            Text("next").font(.caption)
            Text("·").font(.caption)
            Text("add ⇧ to go back").font(.caption)
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
    }

    static func symbol(_ place: FolderInfo.Place) -> String {
        switch place {
        case .home: "house"
        case .desktop: "menubar.dock.rectangle"
        case .documents: "doc"
        case .downloads: "arrow.down.circle"
        case .iCloud: "icloud"
        case .volume: "externaldrive"
        case .network: "network"
        case .folder: "folder"
        }
    }
}

/// A panel that never takes focus, so the dialog keeps the keyboard and clicking a folder doesn't
/// bring Right Folder to the front.
final class JumpWindow: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Takes clicks without needing to be focused first.
final class ClickThroughHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

@MainActor
final class JumpPanelController {
    private let panel: JumpWindow
    private let host: ClickThroughHostingView<JumpView>

    static let maxHeight: CGFloat = 520

    init(view: JumpView) {
        host = ClickThroughHostingView(rootView: view)
        panel = JumpWindow(contentRect: NSRect(x: 0, y: 0, width: JumpView.width, height: 200), styleMask: [.nonactivatingPanel, .borderless], backing: .buffered, defer: true)
        panel.isFloatingPanel = true
        // Above dialogs, which sit at the modal panel level, and below menus.
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.modalPanel.rawValue + 1)
        panel.collectionBehavior = [.fullScreenAuxiliary, .transient, .ignoresCycle, .moveToActiveSpace]
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isReleasedWhenClosed = false
        panel.contentView = host
    }

    var isVisible: Bool { panel.isVisible }

    /// Shows the panel beside a dialog whose frame is in Accessibility's coordinates.
    func show(beside dialog: CGRect?) {
        host.layoutSubtreeIfNeeded()
        let size = CGSize(width: JumpView.width, height: min(host.fittingSize.height, Self.maxHeight))
        guard let main = NSScreen.screens.first else { return }
        let mainHeight = main.frame.height
        let screens = NSScreen.screens.map { Placement.flip($0.visibleFrame, mainHeight: mainHeight) }
        let anchor = dialog ?? Placement.flip(main.visibleFrame, mainHeight: mainHeight).insetBy(dx: 200, dy: 120)
        let frame = Placement.flip(Placement.frame(beside: anchor, size: size, screens: screens), mainHeight: mainHeight)
        panel.setFrame(frame, display: true)
        if !panel.isVisible { panel.orderFrontRegardless() }
    }

    func hide() {
        panel.orderOut(nil)
    }
}
