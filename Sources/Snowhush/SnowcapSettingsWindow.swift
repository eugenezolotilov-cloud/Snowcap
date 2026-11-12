import AppKit
import Combine
import ServiceManagement
import SwiftUI

enum SettingsToggle {
    case accumulate, windowSnow, deepInteraction, snowballs, behindWindows, fullScreen, screenshots, maxPerformance, login
}

enum SettingsAction {
    case slider(SnowControl, Double)
    case direction(Int)
    case sensitivity(Double)
    case modifier(SnowballModifier)
    case toggle(SettingsToggle)
    case toggleSnowfall, clear, reset, updates, quit
}

var snowfallActionTitle: String {
    Preferences.snowfallStopped
        ? tr("snow.resume", fallback: "Resume Snowfall")
        : tr("snow.pause", fallback: "Pause Snowfall")
}

final class SnowcapSettingsWindow: NSWindowController, NSWindowDelegate {
    private let model: Model

    init(hasUpdater: Bool, perform: @escaping (SettingsAction) -> Void) {
        let model = Model(hasUpdater: hasUpdater, perform: perform)
        self.model = model
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 770, height: 530),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable],
                              backing: .buffered, defer: false)
        super.init(window: window)
        window.title = "\(appDisplayName) — \(tr("settings", fallback: "Settings"))"
        window.isReleasedWhenClosed = false
        window.contentMinSize = NSSize(width: 690, height: 420)
        let host = NSHostingController(rootView: SettingsView(model: model))
        host.sizingOptions = []
        window.contentViewController = host
        window.delegate = self
        window.center()
    }

    required init?(coder: NSCoder) { nil }

    func present() {
        refresh()
        if NSApp.mainMenu == nil { NSApp.mainMenu = makeMainMenu() }
        NSApp.setActivationPolicy(.regular)
        showWindow(nil)
        window?.deminiaturize(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    func refresh() { model.objectWillChange.send() }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    private func makeMainMenu() -> NSMenu {
        let menu = NSMenu()
        let application = NSMenu(title: appDisplayName)
        application.addItem(withTitle: tr("quit", fallback: "Quit"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let appItem = NSMenuItem()
        appItem.submenu = application
        menu.addItem(appItem)
        let windowMenu = NSMenu(title: tr("settings.window", fallback: "Window"))
        windowMenu.addItem(withTitle: tr("settings.close", fallback: "Close Window"), action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        let windowItem = NSMenuItem()
        windowItem.submenu = windowMenu
        menu.addItem(windowItem)
        return menu
    }

    private final class Model: ObservableObject {
        let objectWillChange = ObservableObjectPublisher()
        var selection = Page.snowfall {
            willSet { objectWillChange.send() }
        }
        let hasUpdater: Bool
        let perform: (SettingsAction) -> Void

        init(hasUpdater: Bool, perform: @escaping (SettingsAction) -> Void) {
            self.hasUpdater = hasUpdater
            self.perform = perform
        }
    }

    private enum Page: String, CaseIterable, Identifiable {
        case snowfall, accumulation, interaction, display, general
        var id: Self { self }

        var title: String {
            switch self {
            case .snowfall: tr("settings.snowfall", fallback: "Snowfall")
            case .accumulation: tr("settings.accumulation", fallback: "Accumulation")
            case .interaction: tr("settings.interaction", fallback: "Interaction")
            case .display: tr("display", fallback: "Display")
            case .general: tr("general", fallback: "General")
            }
        }

        var icon: String {
            switch self {
            case .snowfall: "snowflake"
            case .accumulation: "square.3.layers.3d"
            case .interaction: "cursorarrow.rays"
            case .display: "display"
            case .general: "gearshape"
            }
        }
    }

    private struct SettingsView: View {
        @ObservedObject var model: Model
        private var selection: Page { model.selection }

        var body: some View {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(Page.allCases) { page in
                        Button { model.selection = page } label: {
                            Label(page.title, systemImage: page.icon)
                                .font(.system(size: 14, weight: selection == page ? .semibold : .regular))
                                .foregroundStyle(selection == page ? Color.accentColor : Color.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                                .background(selection == page ? Color.accentColor.opacity(0.13) : .clear,
                                            in: RoundedRectangle(cornerRadius: 8))
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(selection == page ? .isSelected : [])
                    }
                    Spacer()
                }
                .padding(12)
                .frame(width: 186)
                .background(.regularMaterial)
                Divider()
                VStack(alignment: .leading, spacing: 0) {
                    Text(selection.title)
                        .font(.title2.weight(.semibold))
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
                        .padding(.bottom, 8)
                    Form { content }
                        .formStyle(.grouped)
                        .id(selection)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }

        @ViewBuilder private var content: some View {
            switch selection {
            case .snowfall:
                Section {
                    slider(.intensity)
                    slider(.speed)
                    slider(.opacity)
                }
                Section(tr("snow.direction", fallback: "Snowfall Direction")) {
                    DirectionPad(angle: Preferences.snowDirection) { model.perform(.direction($0)) }
                        .frame(width: 200, height: 144)
                        .frame(maxWidth: .infinity)
                }
                Section {
                    Button(snowfallActionTitle) { model.perform(.toggleSnowfall) }
                    Button(tr("clear.snow", fallback: "Clear Snow")) { model.perform(.clear) }
                }
            case .accumulation:
                Section {
                    toggle("accumulate", "Accumulate", .accumulate) { Preferences.accumulate }
                    toggle("windows.snow", "Snow on Windows", .windowSnow) { Preferences.snowOnWindows }
                }
                Section {
                    slider(.accumulation)
                    slider(.depth)
                    slider(.melting)
                }
            case .interaction:
                Section {
                    slider(.physics)
                    toggle("deep", "Deep Interaction", .deepInteraction) { Preferences.deepInteraction }
                        .disabled(!Preferences.snowOnWindows)
                }
                Section(tr("settings.snowballs", fallback: "Snowballs")) {
                    toggle("snowball.enabled", "Snowball Interaction", .snowballs) { Preferences.snowballEnabled }
                    Picker(tr("snowball.modifier", fallback: "Snowball Modifier"),
                           selection: Binding(get: { Preferences.snowballModifier }, set: { model.perform(.modifier($0)) })) {
                        ForEach(SnowballModifier.allCases, id: \.self) { modifier in
                            Text(modifier.title).tag(modifier)
                        }
                    }
                    .disabled(!Preferences.snowballEnabled)
                    scale(tr("snowball.sensitivity", fallback: "Snowball Sensitivity"),
                          value: Binding(get: { Preferences.snowballSensitivity * 100 },
                                         set: { model.perform(.sensitivity($0)) }))
                        .disabled(!Preferences.snowballEnabled)
                }
            case .display:
                Section {
                    toggle("behind", "Behind Windows", .behindWindows) { Preferences.behindWindows }
                    toggle("full_screen", "Show over Full Screen", .fullScreen) { Preferences.showOverFullScreen }
                        .disabled(Preferences.behindWindows)
                    toggle("screenshots", "Show in Screenshots", .screenshots) { Preferences.showInScreenshots }
                    toggle("performance", "Max Performance", .maxPerformance) { Preferences.maxPerformance }
                }
            case .general:
                Section {
                    toggle("login", "Open at Login", .login) { SMAppService.mainApp.status == .enabled }
                    if model.hasUpdater {
                        Button(tr("updates", fallback: "Check for Updates")) { model.perform(.updates) }
                    }
                }
                Section {
                    Button(tr("snow.control.reset", fallback: "Restore Snowfall Defaults")) { model.perform(.reset) }
                    Button(tr("quit", fallback: "Quit")) { model.perform(.quit) }
                }
            }
        }

        private func slider(_ control: SnowControl) -> some View {
            scale(control.title,
                  value: Binding(get: { control.percentage(for: Preferences.snowValue(for: control)) },
                                 set: { model.perform(.slider(control, $0)) }))
        }

        private func scale(_ title: String, value: Binding<Double>) -> some View {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(title)
                    Spacer()
                    Text("\(Int(value.wrappedValue.rounded()))%")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Slider(value: value, in: 0...200, step: 1) { Text(title) }
                    .labelsHidden()
                HStack {
                    Text("0%")
                    Spacer()
                    Text("100%")
                    Spacer()
                    Text("200%")
                }
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            }
            .padding(.vertical, 3)
        }

        private func toggle(_ key: String, _ fallback: String, _ setting: SettingsToggle,
                            get: @escaping () -> Bool) -> some View {
            Toggle(tr(key, fallback: fallback), isOn: Binding(get: get, set: { value in
                if value != get() { model.perform(.toggle(setting)) }
            }))
            .toggleStyle(.switch)
        }
    }

    private struct DirectionPad: NSViewRepresentable {
        let angle: Int
        let change: (Int) -> Void

        func makeNSView(context: Context) -> MenuSnowDirection {
            MenuSnowDirection(label: tr("snow.direction", fallback: "Snowfall Direction"))
        }

        func updateNSView(_ view: MenuSnowDirection, context: Context) {
            view.angle = angle
            view.changed = change
        }
    }
}
