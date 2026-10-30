import AppKit

/// Click-through, non-activating window with the system material behind its
/// content (Liquid Glass on macOS 26+, HUD vibrancy before). Used by the OSD,
/// which has no stock SwiftUI scene.
final class HUDWindow: NSPanel {
    init(content: NSView, cornerRadius: CGFloat) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 100, height: 100),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )
        isFloatingPanel = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        ignoresMouseEvents = true
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        animationBehavior = .none
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]

        // Clip everything to the rounded shape so the window has no square
        // outline or shadow behind the material.
        let container = NSView()
        container.wantsLayer = true
        container.layer?.cornerRadius = cornerRadius
        container.layer?.cornerCurve = .continuous
        container.layer?.masksToBounds = true
        let material = Self.materialView(containing: content, cornerRadius: cornerRadius)
        material.frame = container.bounds
        material.autoresizingMask = [.width, .height]
        container.addSubview(material)
        contentView = container
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    override func orderFrontRegardless() {
        super.orderFrontRegardless()
        // The shadow follows the drawn content; recompute it once drawn.
        invalidateShadow()
        DispatchQueue.main.async { [weak self] in self?.invalidateShadow() }
    }

    private static func materialView(containing content: NSView, cornerRadius: CGFloat) -> NSView {
        if #available(macOS 26.0, *) {
            let glass = NSGlassEffectView()
            glass.cornerRadius = cornerRadius
            glass.contentView = content
            return glass
        }
        let effect = NSVisualEffectView()
        effect.material = .hudWindow
        effect.blendingMode = .behindWindow
        effect.state = .active
        content.frame = effect.bounds
        content.autoresizingMask = [.width, .height]
        effect.addSubview(content)
        return effect
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }
}
