import AppKit
import SwiftUI

/// Tracks the `MenuBarExtra` window: which screen it is open on, and when it
/// opens (features refresh their state then).
final class PanelWindow {
    var onOpen: () -> Void = {}

    private weak var window: NSWindow?
    private var observer: NSObjectProtocol?

    /// The screen the panel is open on, if it is open.
    var visibleScreen: NSScreen? {
        guard let window, window.isVisible else { return nil }
        return window.screen
    }

    fileprivate func attach(_ window: NSWindow) {
        guard window !== self.window else { return }
        self.window = window
        if let observer { NotificationCenter.default.removeObserver(observer) }
        observer = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification, object: window, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.onOpen() }
        }
    }
}

extension View {
    /// Lets `panel` find the window this view is hosted in.
    func trackingPanelWindow(_ panel: PanelWindow) -> some View {
        background(WindowReader { panel.attach($0) })
    }
}

private struct WindowReader: NSViewRepresentable {
    let onWindow: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView { WindowReaderView(onWindow: onWindow) }
    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class WindowReaderView: NSView {
        let onWindow: (NSWindow) -> Void

        init(onWindow: @escaping (NSWindow) -> Void) {
            self.onWindow = onWindow
            super.init(frame: .zero)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let window { onWindow(window) }
        }
    }
}
