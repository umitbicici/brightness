import SwiftUI

struct GeneralSettingsView: View {
    @Bindable var launchAtLogin: LaunchAtLogin
    @Bindable var updater: Updater

    var body: some View {
        Form {
            Section {
                Toggle("Launch at login", isOn: Binding(
                    get: { launchAtLogin.isEnabled },
                    set: { launchAtLogin.setEnabled($0) }
                ))
                if let error = launchAtLogin.lastError {
                    Text(error)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            } footer: {
                Text("\(Bundle.main.displayName) starts automatically in the menu bar when you log in.")
                    .foregroundStyle(.secondary)
            }

            Section("Updates") {
                Toggle("Automatically check for updates", isOn: $updater.automaticallyChecksForUpdates)
                LabeledContent("Version \(Bundle.main.version)") {
                    Button("Check Now…", action: updater.checkForUpdates)
                        .disabled(!updater.canCheckForUpdates)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear(perform: launchAtLogin.refresh)
    }
}
