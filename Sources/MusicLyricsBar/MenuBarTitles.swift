import AppKit
import ApplicationServices

/// Where the frontmost app's menu titles end, read through the Accessibility API so the
/// floating lyrics bar can start just right of them. Accessibility access is optional and
/// only asked for when the floating bar is turned on; without it the caller falls back to a
/// conservative guess.
@MainActor
enum MenuBarTitles {
    static var isTrusted: Bool { AXIsProcessTrusted() }

    /// Shows the system prompt that sends the user to Privacy & Security › Accessibility.
    static func promptForAccess() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    /// The screen x where the last menu title of `app` ends, or nil when it cannot be read
    /// (no access, no menu bar, or the app did not answer within the timeout).
    static func titlesRightEdge(of app: NSRunningApplication) -> CGFloat? {
        guard isTrusted, app.activationPolicy == .regular else { return nil }
        let application = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(application, 0.25)
        guard let menuBar = element(of: application, attribute: kAXMenuBarAttribute),
              let children = copyValue(of: menuBar, attribute: kAXChildrenAttribute) as? [AnyObject] else { return nil }
        // Titles are laid out left to right; the rightmost edge among them is what matters.
        var rightEdge: CGFloat?
        for child in children {
            guard CFGetTypeID(child) == AXUIElementGetTypeID() else { continue }
            let title = unsafeDowncast(child, to: AXUIElement.self)
            guard let origin: CGPoint = value(of: title, attribute: kAXPositionAttribute, type: .cgPoint),
                  let size: CGSize = value(of: title, attribute: kAXSizeAttribute, type: .cgSize),
                  size.width > 0 else { continue }
            rightEdge = max(rightEdge ?? -.infinity, origin.x + size.width)
        }
        return rightEdge
    }

    private static func copyValue(of element: AXUIElement, attribute: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value
    }

    private static func element(of element: AXUIElement, attribute: String) -> AXUIElement? {
        guard let value = copyValue(of: element, attribute: attribute),
              CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return unsafeDowncast(value, to: AXUIElement.self)
    }

    private static func value<T>(of element: AXUIElement, attribute: String, type: AXValueType) -> T? {
        guard let raw = copyValue(of: element, attribute: attribute), CFGetTypeID(raw) == AXValueGetTypeID() else { return nil }
        let axValue = unsafeDowncast(raw, to: AXValue.self)
        guard AXValueGetType(axValue) == type else { return nil }
        var result: T?
        switch type {
        case .cgPoint:
            var point = CGPoint.zero
            if AXValueGetValue(axValue, type, &point) { result = point as? T }
        case .cgSize:
            var size = CGSize.zero
            if AXValueGetValue(axValue, type, &size) { result = size as? T }
        default:
            break
        }
        return result
    }
}
