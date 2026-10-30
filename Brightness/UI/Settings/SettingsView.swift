import SwiftUI

/// The Settings window (⌘,), laid out like System Settings: a sidebar with
/// General plus one entry per feature, and the selected pane on the right.
struct SettingsView: View {
    let environment: AppEnvironment
    @State private var selection: String? = Pane.generalID

    private struct Pane: Identifiable {
        static let generalID = "general"
        let id: String
        let title: String
        let systemImage: String
        let content: () -> AnyView
    }

    private var panes: [Pane] {
        let general = Pane(id: Pane.generalID, title: String(localized: "General"), systemImage: "gearshape") { [environment] in
            AnyView(GeneralSettingsView(launchAtLogin: environment.launchAtLogin, updater: environment.updater))
        }
        return [general] + environment.features.map { feature in
            Pane(id: feature.id, title: feature.title, systemImage: feature.systemImage) {
                feature.settingsView()
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            List(panes, selection: $selection) { pane in
                Label(pane.title, systemImage: pane.systemImage)
            }
            .navigationSplitViewColumnWidth(200)
            .toolbar(removing: .sidebarToggle)
        } detail: {
            if let pane = panes.first(where: { $0.id == selection }) {
                pane.content()
                    .navigationTitle(pane.title)
            }
        }
        .frame(width: 700, height: 460)
    }
}
