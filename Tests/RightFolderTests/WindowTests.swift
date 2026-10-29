import AppKit
import Foundation
import SwiftUI
import Testing
@testable import FolderCore
@testable import RightFolder

/// A made-up app's Save dialog, drawn for the screenshots: Inkpad saving a note, the way a Save
/// sheet looks. Not any real app's dialog.
struct MockSaveDialog: View {
    var body: some View {
        VStack(spacing: 0) {
            // The document window's title bar, with the sheet hanging from it.
            HStack(spacing: 7) {
                ForEach([Color.red, .yellow, .green], id: \.self) { color in
                    Circle().fill(color.opacity(0.85)).frame(width: 11, height: 11)
                }
                Spacer()
                Text("Untitled — Inkpad").font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
                Spacer()
                Color.clear.frame(width: 47, height: 1)
            }
            .padding(.horizontal, 12)
            .frame(height: 30)
            VStack(alignment: .leading, spacing: 12) {
                field("Save As:", "Field notes, week 6")
                field("Tags:", "")
                HStack {
                    Text("Where:").frame(width: 70, alignment: .trailing)
                    HStack {
                        Image(systemName: "folder.fill").foregroundStyle(WindowTests.blue)
                        Text("Documents")
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down").font(.caption2)
                    }
                    .padding(.horizontal, 8)
                    .frame(width: 220, height: 24)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.07)))
                }
                .font(.system(size: 13))
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.primary.opacity(0.04))
                    .overlay(alignment: .topLeading) {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(["Lab Notes", "Thesis", "Reading list.md", "Week 5 field notes.md"], id: \.self) { name in
                                Label(name, systemImage: name.hasSuffix(".md") ? "doc.text" : "folder.fill")
                                    .font(.system(size: 12.5))
                                    .foregroundStyle(name.hasSuffix(".md") ? .secondary : .primary)
                            }
                        }
                        .padding(12)
                    }
                    .frame(height: 150)
                HStack {
                    Spacer()
                    Text("Cancel").padding(.horizontal, 14).frame(height: 24)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.08)))
                    Text("Save").foregroundStyle(.white).padding(.horizontal, 18).frame(height: 24)
                        .background(RoundedRectangle(cornerRadius: 6).fill(WindowTests.blue))
                }
                .font(.system(size: 13))
            }
            .padding(18)
            .background(Color(nsColor: .windowBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .shadow(color: .black.opacity(0.25), radius: 14, y: 6)
            .padding(.horizontal, 26)
            .padding(.bottom, 26)
        }
        .frame(width: 520)
        .background(Color(nsColor: .underPageBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.separator, lineWidth: 0.5))
    }

    private func field(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).frame(width: 70, alignment: .trailing)
            Text(value)
                .padding(.horizontal, 6)
                .frame(width: 300, height: 22, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 5).strokeBorder(WindowTests.blue.opacity(value.isEmpty ? 0.0 : 0.7), lineWidth: 2.5))
                .background(RoundedRectangle(cornerRadius: 5).fill(Color(nsColor: .textBackgroundColor)))
        }
        .font(.system(size: 13))
    }
}

/// The README's picture: Inkpad's Save dialog, with Right Folder's panel beside it.
struct DialogScene: View {
    let model: FolderModel

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            MockSaveDialog()
            JumpView(model: model, tint: WindowTests.blue)
                .fixedSize(horizontal: false, vertical: true)
                .shadow(color: .black.opacity(0.2), radius: 12, y: 5)
        }
        .padding(28)
        .frame(width: WindowTests.sceneSize.width, height: WindowTests.sceneSize.height, alignment: .topLeading)
        .background(
            LinearGradient(colors: [Color(red: 0.80, green: 0.86, blue: 0.94), Color(red: 0.55, green: 0.64, blue: 0.78)], startPoint: .top, endPoint: .bottom)
        )
    }
}

/// Renders views into bitmaps from windows that are never shown, so nothing appears on screen or
/// takes focus. Set SCREENSHOT_DIR to also save the renders as the README screenshots:
///
///   SCREENSHOT_DIR=docs swift test --filter "WindowTests"
@MainActor
@Suite("Window")
struct WindowTests {
    static let sceneSize = NSSize(width: 880, height: 520)
    static let windowSize = NSSize(width: 760, height: 520)
    static let blue = Color(red: 0.24, green: 0.47, blue: 0.86)

    @Test func rendersThePanelBesideADialog() {
        let image = render(DialogScene(model: Gallery.model()), name: "screenshot-light", dark: false, size: Self.sceneSize)
        #expect(image.pixelsWide >= Int(Self.sceneSize.width))
        #expect(colors(in: image) > 30)
    }

    @Test func rendersInDarkMode() {
        #expect(colors(in: render(DialogScene(model: Gallery.model()), name: "screenshot-dark", dark: true, size: Self.sceneSize)) > 20)
    }

    @Test func rendersTheWindow() {
        let model = Gallery.model(dialog: nil)
        model.setExcluded("com.example.sketchbook", true)
        let view = FolderWindowView(model: model, appName: { _ in "Sketchbook" }, tint: Self.blue)
        #expect(colors(in: render(view, name: "screenshot-window", dark: false, size: Self.windowSize)) > 20)
    }

    @Test func rendersTheAccessibilityRequest() {
        let view = FolderWindowView(model: Gallery.model(trusted: false, finder: [], favorites: [], recents: [], dialog: nil), tint: Self.blue)
        #expect(colors(in: render(view, name: "screenshot-access", dark: false, size: NSSize(width: 760, height: 460))) > 8)
    }

    @Test func rendersTheOtherStates() async {
        // Nothing to list yet, a jump that failed and an unplugged drive.
        let empty = Gallery.model(finder: [], favorites: [], recents: [])
        #expect(colors(in: render(JumpView(model: empty), name: nil, dark: true, size: NSSize(width: 268, height: 160))) > 4)
        let jumps = RecordedJumps()
        jumps.result = .failed(.noField)
        let failed = Gallery.model(favorites: ["/Volumes/Old Drive/Photos"], jumps: jumps)
        await failed.jump(to: Gallery.finder[0])
        #expect(failed.message != nil)
        #expect(colors(in: render(JumpView(model: failed), name: nil, dark: false, size: NSSize(width: 268, height: 420))) > 8)
    }

    @Test func thePanelFitsItsList() {
        // The panel's height follows how many folders it lists, up to its limit.
        let host = NSHostingView(rootView: JumpView(model: Gallery.model()))
        let short = NSHostingView(rootView: JumpView(model: Gallery.model(finder: [], favorites: [], recents: [Gallery.home + "/Desktop"])))
        #expect(host.fittingSize.width == JumpView.width)
        #expect(host.fittingSize.height > short.fittingSize.height)
        #expect(short.fittingSize.height > 60)
    }

    @Test func everySymbolExists() {
        var names = ["arrowshape.turn.up.right", "folder", "ellipsis.circle", "pin", "pin.fill", "macwindow", "exclamationmark.triangle.fill",
                     "hand.raised.fill", "plus", "chevron.up", "chevron.down", "xmark", "folder.fill", "doc.text", "chevron.up.chevron.down"]
        names += [FolderInfo.Place.home, .desktop, .documents, .downloads, .iCloud, .volume, .network, .folder].map(JumpView.symbol)
        for symbol in names {
            #expect(NSImage(systemSymbolName: symbol, accessibilityDescription: nil) != nil, "Missing symbol \(symbol)")
        }
    }

    @Test func theMenuBarIconIsATemplate() {
        for (alert, paused) in [(false, false), (true, false), (false, true)] {
            let image = StatusIcon.image(alert: alert, paused: paused)
            #expect(image.isTemplate && image.size == NSSize(width: 18, height: 18))
            #expect(image.cgImage(forProposedRect: nil, context: nil, hints: nil) != nil)
            #expect(image.accessibilityDescription?.hasPrefix("Right Folder") == true)
        }
    }

    // MARK: Rendering

    private func render(_ view: some View, name: String?, dark: Bool, size: NSSize) -> NSBitmapImageRep {
        let host = NSHostingView(rootView: view.frame(width: size.width, height: size.height))
        host.frame = NSRect(origin: .zero, size: size)
        host.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        // Never ordered front: it only gives the view a backing to draw into.
        let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.4))
        host.layoutSubtreeIfNeeded()
        let image = host.bitmapImageRepForCachingDisplay(in: host.bounds)!
        host.cacheDisplay(in: host.bounds, to: image)
        if let name, let folder = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"] {
            let url = URL(fileURLWithPath: folder).appendingPathComponent("\(name).png")
            try? image.representation(using: .png, properties: [:])?.write(to: url)
        }
        return image
    }

    /// Distinct colors in a coarse grid: a blank or broken render has only a few.
    private func colors(in image: NSBitmapImageRep) -> Int {
        var seen = Set<UInt32>()
        for x in stride(from: 0, to: image.pixelsWide, by: 7) {
            for y in stride(from: 0, to: image.pixelsHigh, by: 7) {
                guard let color = image.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else { continue }
                let r = UInt32(color.redComponent * 31), g = UInt32(color.greenComponent * 31), b = UInt32(color.blueComponent * 31)
                seen.insert(r << 10 | g << 5 | b)
            }
        }
        return seen.count
    }
}
