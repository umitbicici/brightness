import SwiftUI

// MARK: - Panel section

/// Built from stock SwiftUI controls only, so it follows the system's look
/// (Liquid Glass on macOS 26) and its accent color, accessibility and
/// keyboard handling.
struct BrightnessPanelSection: View {
    let model: BrightnessModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Displays")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                if model.isLoading {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Button("Rescan", systemImage: "arrow.clockwise") {
                        Task { await model.reload(refresh: true, skeleton: true) }
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .help("Rescan displays")
                }
            }
            .frame(height: 20)

            if model.showsSkeleton {
                ForEach(0..<max(model.displays.count, 2), id: \.self) { _ in
                    DisplayRow.placeholder
                }
                .transition(.opacity)
            } else if model.displays.isEmpty {
                ContentUnavailableView("No Displays Found", systemImage: "display.trianglebadge.exclamationmark")
            } else {
                ForEach(model.displays) { display in
                    DisplayRow(display: display, model: model)
                        .transition(.opacity)
                }
            }
        }
        .animation(.default, value: model.showsSkeleton)
    }
}

private struct DisplayRow: View {
    let display: DisplaySnapshot
    let model: BrightnessModel?

    /// Stand-in shown while displays are loading.
    static var placeholder: some View {
        DisplayRow(
            display: DisplaySnapshot(id: 0, name: "Display name", kind: .external, method: .ddc,
                                     brightness: 50, error: nil),
            model: nil
        )
        .redacted(reason: .placeholder)
        .disabled(true)
    }

    var body: some View {
        let value = model?.value(of: display) ?? display.brightness.map { Double($0) / 100 }
        GroupBox {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label(display.name, systemImage: display.kind == .builtin ? "laptopcomputer" : "display")
                        .lineLimit(1)
                    Spacer()
                    Group {
                        if let value {
                            Text(value, format: .percent.precision(.fractionLength(0)))
                        } else {
                            Text(verbatim: "—")
                        }
                    }
                    .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText(value: value ?? 0))
                }

                Slider(
                    value: Binding(
                        get: { value ?? 0 },
                        set: { newValue in model?.setValue(newValue, of: display) }
                    ),
                    in: 0...1
                ) {
                    Text("\(display.name) brightness")
                } minimumValueLabel: {
                    Image(systemName: "sun.min")
                } maximumValueLabel: {
                    Image(systemName: "sun.max")
                } onEditingChanged: { editing in
                    model?.setEditing(editing, display: display)
                }
                .labelsHidden()
                .disabled(value == nil)

                if let error = model?.error(of: display) {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .symbolRenderingMode(.multicolor)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(4)
        }
    }
}

// MARK: - Settings pane

struct BrightnessSettingsView: View {
    let model: BrightnessModel
    @AppStorage(Preferences.Key.showOSD) private var showOSD = true

    var body: some View {
        Form {
            Section {
                Toggle("Show on-screen indicator", isOn: $showOSD)
            } footer: {
                Text("When the brightness changes, an indicator appears in the top-right corner of the adjusted display.")
                    .foregroundStyle(.secondary)
            }

            Section {
                ForEach(model.displays) { display in
                    LabeledContent {
                        let working = display.brightness != nil
                        Text(working ? display.method.label : String(localized: "Not responding"))
                            .foregroundStyle(working ? .secondary : Color.orange)
                            .help(display.error ?? "")
                    } label: {
                        Label(display.name, systemImage: display.kind == .builtin ? "laptopcomputer" : "display")
                    }
                }
            } header: {
                HStack {
                    Text("Detected Displays")
                    Spacer()
                    Button("Rescan") {
                        Task { await model.reload(refresh: true) }
                    }
                    .controlSize(.small)
                }
            } footer: {
                Text("External monitors are controlled over DDC/CI, which must be turned on in the monitor's menu.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

private extension ControlMethod {
    var label: String {
        switch self {
        case .system: String(localized: "System")
        case .ddc: "DDC/CI"
        case .unsupported: String(localized: "Not supported")
        }
    }
}
