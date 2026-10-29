import AppKit
import ApplicationServices
import FolderCore

/// Small helpers for reading Accessibility attributes. Right Folder only reads roles, subroles,
/// identifiers, frames, which window is focused and the folder a Finder window shows. It never
/// reads a window's title or text, except the Go to Folder field it fills in itself.
enum AX {
    /// How long to wait for an app to answer. An app that's hung can't hold Right Folder up longer.
    static let timeout: Float = 0.3

    static func app(_ pid: pid_t) -> AXUIElement {
        let element = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(element, timeout)
        return element
    }

    /// Set when an app didn't answer in time, so a chain of requests can stop at the first one
    /// instead of waiting out each in turn. Only touched on the main thread.
    nonisolated(unsafe) static var timedOut = false

    static func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        // Elements read from an app don't share its timeout, so each gets its own.
        AXUIElementSetMessagingTimeout(element, timeout)
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, name as CFString, &value)
        if error == .cannotComplete { timedOut = true }
        guard error == .success else { return nil }
        return value
    }

    static func string(_ element: AXUIElement, _ name: String) -> String? {
        attribute(element, name) as? String
    }

    static func element(_ element: AXUIElement, _ name: String) -> AXUIElement? {
        guard let value = attribute(element, name), CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }

    static func children(_ element: AXUIElement) -> [AXUIElement] {
        (attribute(element, kAXChildrenAttribute) as? [AXUIElement]) ?? []
    }

    static func role(_ element: AXUIElement) -> String? { string(element, kAXRoleAttribute) }
    static func subrole(_ element: AXUIElement) -> String? { string(element, kAXSubroleAttribute) }

    /// A window or sheet's frame, in Accessibility's coordinates: from the top left of the main display.
    static func frame(_ element: AXUIElement) -> CGRect? {
        guard let position = attribute(element, kAXPositionAttribute), let size = attribute(element, kAXSizeAttribute),
              CFGetTypeID(position) == AXValueGetTypeID(), CFGetTypeID(size) == AXValueGetTypeID() else { return nil }
        var point = CGPoint.zero
        var extent = CGSize.zero
        guard AXValueGetValue(position as! AXValue, .cgPoint, &point), AXValueGetValue(size as! AXValue, .cgSize, &extent) else { return nil }
        return CGRect(origin: point, size: extent)
    }

    /// A window or sheet with the sheets on it, as read, alongside its snapshot.
    struct Node {
        var element: AXUIElement
        var children: [Node]
    }

    /// What Right Folder needs to tell a dialog from other windows: the window's role, subrole and
    /// identifier, and the same for the sheets on it, a few levels down. Stops early if the app
    /// stops answering.
    static func snapshot(_ window: AXUIElement, depth: Int = 3) -> (element: Element, node: Node) {
        var snapshots: [Element] = []
        var nodes: [Node] = []
        if depth > 0 {
            for child in children(window) {
                guard !timedOut else { break }
                if role(child) == "AXSheet" {
                    let inner = snapshot(child, depth: depth - 1)
                    snapshots.append(inner.element)
                    nodes.append(inner.node)
                } else {
                    // Only sheets are looked into. Anything else is kept as a placeholder so the
                    // indexes still line up.
                    snapshots.append(Element(role: nil))
                    nodes.append(Node(element: child, children: []))
                }
            }
        }
        let element = Element(role: role(window), subrole: subrole(window), identifier: string(window, kAXIdentifierAttribute), children: snapshots)
        return (element, Node(element: window, children: nodes))
    }

    /// Follows a match's child indexes through the same elements the snapshot was made from, so
    /// the dialog found is the one that matched, even if the window changed since.
    static func follow(_ path: [Int], in node: Node) -> AXUIElement? {
        var node = node
        for index in path {
            guard node.children.indices.contains(index) else { return nil }
            node = node.children[index]
        }
        return node.element
    }

    /// Whether an element is still there. One that was closed stops answering.
    static func exists(_ element: AXUIElement) -> Bool {
        role(element) != nil
    }
}
