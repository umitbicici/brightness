import AppKit
import SwiftUI

/// On-screen display: mimics the system brightness HUD (a Control Center–style
/// module at the top right of the screen being adjusted). Click-through and
/// never takes focus.
final class OSDController {
    private static let size = NSSize(width: 300, height: 66)
    private static let margin: CGFloat = 10
    private static let visibleDuration: TimeInterval = 1.3

    private let model = OSDModel()
    private var hideTask: Task<Void, Never>?

    /// Created on first use, once the app has finished launching.
    private lazy var panel: HUDWindow = {
        let hosting = NSHostingView(rootView: OSDView(model: model))
        hosting.sizingOptions = []
        return HUDWindow(content: hosting, cornerRadius: 20)
    }()

    func show(title: String, percent: Int, on screen: NSScreen) {
        model.title = title
        model.percent = percent

        let visible = screen.visibleFrame
        let origin = NSPoint(x: visible.maxX - Self.size.width - Self.margin,
                             y: visible.maxY - Self.size.height - Self.margin)
        panel.setFrame(NSRect(origin: origin, size: Self.size), display: true)

        if !panel.isVisible || panel.alphaValue < 1 {
            if !panel.isVisible { panel.alphaValue = 0 }
            panel.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.15
                panel.animator().alphaValue = 1
            }
        }

        hideTask?.cancel()
        hideTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.visibleDuration))
            guard !Task.isCancelled, let self else { return }
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.25
                self.panel.animator().alphaValue = 0
            } completionHandler: {
                MainActor.assumeIsolated {
                    if self.panel.alphaValue == 0 { self.panel.orderOut(nil) }
                }
            }
        }
    }
}

@Observable
private final class OSDModel {
    var title = ""
    var percent = 0
}

private struct OSDView: View {
    let model: OSDModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(model.title, systemImage: "sun.max.fill")
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Text(Double(model.percent) / 100, format: .percent.precision(.fractionLength(0)))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText(value: Double(model.percent)))
            }
            ProgressView(value: Double(model.percent), total: 100)
        }
        .animation(.default, value: model.percent)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
