import SwiftUI

/// Content of the menu bar panel: a header and one section per feature.
struct PanelView: View {
    let environment: AppEnvironment
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            ForEach(environment.features, id: \.id) { feature in
                feature.panelSection()
            }
        }
        .padding(12)
        .frame(width: 320)
        .trackingPanelWindow(environment.panel)
    }

    private var header: some View {
        HStack {
            Text(Bundle.main.displayName)
                .font(.headline)
            Spacer()
            Menu {
                Button("Settings…") {
                    AppActivation.bringToFront()
                    openSettings()
                }
                .keyboardShortcut(",")
                Button("Check for Updates…", action: environment.updater.checkForUpdates)
                Divider()
                Button("About \(Bundle.main.displayName)") {
                    AppActivation.bringToFront()
                    NSApp.orderFrontStandardAboutPanel(nil)
                }
                Divider()
                Button("Quit") { NSApp.terminate(nil) }
                    .keyboardShortcut("q")
            } label: {
                Label("More", systemImage: "ellipsis.circle")
                    .labelStyle(.iconOnly)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("More")
        }
    }
}

extension Bundle {
    var displayName: String {
        object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "Brightness"
    }

    var version: String {
        object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }
}
