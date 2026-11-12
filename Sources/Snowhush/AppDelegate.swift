import AppKit
import MetalKit
import ServiceManagement
import Sparkle

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, SPUStandardUserDriverDelegate {
    private var device: MTLDevice!
    private var screens: [ScreenSnow] = []
    private let displays = Displays()
    private var accumulates = true
    private var snowOnWindows = true
    private var behindWindows = false
    private var snowfallHeld = false
    private var statusItem: NSStatusItem!
    private var snowSliders: [SnowControl: MenuSlider] = [:]
    private var snowDirection: MenuSnowDirection!
    private var pauseItem: NSMenuItem!
    private var settingsWindow: SnowcapSettingsWindow?
    private var observers: [NSObjectProtocol] = []
    private var screensAsleep = false
    private let screenshots = ScreenshotWatch()
    private var screenLocked = false
    private var sessionInactive = false
    private var updater: SPUStandardUpdaterController?
    private var welcome: WelcomeController?
    private let power = PowerMonitor()

    func applicationDidFinishLaunching(_ notification: Notification) {
        if AppMover.moveIfNeeded() {
            NSApp.terminate(nil)
            return
        }
        Preferences.registerDefaults()
        displays.snowballEnabled = Preferences.snowballEnabled
        displays.snowballModifier = Preferences.snowballModifier
        guard let device = Self.lowPowerDevice() ?? MTLCreateSystemDefaultDevice() else {
            NSApp.terminate(nil)
            return
        }
        self.device = device
        accumulates = Preferences.accumulate
        snowOnWindows = Preferences.snowOnWindows
        behindWindows = Preferences.behindWindows
        snowfallHeld = !Preferences.welcomed
        syncScreens()
        guard !screens.isEmpty else {
            NSApp.terminate(nil)
            return
        }

        if Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") != nil {
            updater = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: self)
        }
        statusItem = makeStatusItem()
        updateStatusIcon()
        observeSystem()
        Marquee.enabled = Preferences.deepInteraction
        screenshots.stepAside = { [weak self] aside in self?.screens.forEach { $0.stepAside(aside) } }
        screenshots.start()
        if snowfallHeld {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in self?.showWelcome() }
        }
    }

    // A menu bar app has no Dock icon to badge, so update reminders are left to Sparkle's own gentle alerts.
    var supportsGentleScheduledUpdateReminders: Bool { true }

    // MARK: - Displays

    /// One overlay per display: new displays get snow, removed ones lose theirs, the rest follow resolution changes.
    private func syncScreens() {
        displays.cancelSnowballs()
        let current = NSScreen.screens
        displays.update(screens: current)
        let ids = Set(current.compactMap(\.displayID))
        for gone in screens where !ids.contains(gone.displayID) { gone.close() }
        screens.removeAll { !ids.contains($0.displayID) }

        for screen in current {
            if let existing = screens.first(where: { $0.displayID == screen.displayID }) {
                existing.fit(to: screen)
            } else if let snow = ScreenSnow(screen: screen, device: device, displays: displays, snowOnWindows: { [unowned self] in snowOnWindows }) {
                snow.simulation.snowfallHeld = snowfallHeld
                snow.simulation.snowfallReleased = { [weak self] in self?.releaseSnowfall() }
                snow.maxFrameRate = Preferences.maxPerformance
                snow.activityChanged = { [weak self] in self?.updateActivity() }
                snow.apply(power.budget)
                screens.append(snow)
            }
        }
        displays.snows = screens
        updateActivity()
    }

    private func releaseSnowfall() {
        snowfallHeld = false
        for snow in screens { snow.simulation.snowfallHeld = false }
    }

    private func showWelcome() {
        let welcome = WelcomeController()
        welcome.scatter = { [weak self] pieces in
            guard let self, let first = pieces.first else { return }
            let point = CGPoint(x: CGFloat(first.position.x), y: CGFloat(first.position.y))
            guard let snow = screens.first(where: { $0.window.frame.contains(point) }) ?? screens.first else { return }
            let origin = SIMD2(Float(snow.window.frame.minX), Float(snow.window.frame.minY))
            snow.simulation.scatter(pieces.map { piece in
                var local = piece
                local.position -= origin
                return local
            })
        }
        welcome.skipped = { [weak self] in self?.releaseSnowfall() }
        welcome.finished = { [weak self] in
            Preferences.welcomed = true
            self?.welcome = nil
        }
        self.welcome = welcome
        welcome.show()
    }

    // MARK: - Menu

    private func makeStatusItem() -> NSStatusItem {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false

        for control in [SnowControl.intensity, .speed] {
            addSlider(control, to: menu)
        }
        menu.addItem(.separator())
        pauseItem = add(snowfallActionTitle, #selector(toggleSnowfall), to: menu)
        let directionTitle = tr("snow.direction", fallback: "Snowfall Direction")
        let directionMenu = NSMenu(title: directionTitle)
        let directionItem = NSMenuItem()
        snowDirection = MenuSnowDirection(label: directionTitle)
        snowDirection.angle = Preferences.snowDirection
        snowDirection.changed = { [unowned self] angle in handle(.direction(angle)) }
        directionItem.view = snowDirection
        directionMenu.addItem(directionItem)
        menu.addItem(withTitle: directionTitle, action: nil, keyEquivalent: "").submenu = directionMenu
        menu.addItem(.separator())
        add(tr("settings.advanced", fallback: "Advanced Settings"), #selector(showAdvancedSettings), to: menu)

        item.menu = menu
        return item
    }

    private func addSlider(_ control: SnowControl, to menu: NSMenu) {
        let slider = addSlider(titled: control.title, to: menu)
        slider.value = control.percentage(for: Preferences.snowValue(for: control))
        slider.changed = { [unowned self] percentage in handle(.slider(control, percentage)) }
        snowSliders[control] = slider
    }

    private func addSlider(titled title: String, to menu: NSMenu) -> MenuSlider {
        menu.addItem(.sectionHeader(title: title))
        let slider = MenuSlider(label: title)
        let item = NSMenuItem()
        item.view = slider
        menu.addItem(item)
        return slider
    }

    @discardableResult
    private func add(_ title: String, _ action: Selector, to menu: NSMenu) -> NSMenuItem {
        let item = menu.addItem(withTitle: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        snowDirection.angle = Preferences.snowDirection
        for (control, slider) in snowSliders {
            slider.value = control.percentage(for: Preferences.snowValue(for: control))
        }
        pauseItem.title = snowfallActionTitle
    }

    @objc private func showAdvancedSettings() {
        if settingsWindow == nil {
            settingsWindow = SnowcapSettingsWindow(hasUpdater: updater != nil) { [weak self] action in
                self?.handle(action)
            }
        }
        settingsWindow?.present()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        if settingsWindow?.window?.isVisible == true { showAdvancedSettings() }
        return true
    }

    @objc private func toggleSnowfall() { handle(.toggleSnowfall) }

    private func handle(_ action: SettingsAction) {
        switch action {
        case let .slider(control, percentage):
            Preferences.setSnowValue(control.value(for: percentage), for: control)
            applySnowSettings()
            if control == .intensity { updateStatusIcon() }
        case let .direction(angle):
            Preferences.snowDirection = angle
            applySnowSettings()
        case let .sensitivity(percentage):
            Preferences.snowballSensitivity = percentage / 100
            screens.forEach { $0.simulation.snowballSensitivity = Float(percentage / 100) }
        case let .modifier(modifier):
            displays.snowballModifier = modifier
            Preferences.snowballModifier = modifier
            displays.cancelSnowballs()
        case .toggleSnowfall:
            let resume = Preferences.snowfallStopped
            if resume, Preferences.intensity <= 0 { Preferences.intensity = Preferences.defaultIntensity }
            Preferences.snowfallPaused = !resume
            applySnowSettings()
            updateStatusIcon()
        case .toggle(let setting):
            switch setting {
            case .accumulate: toggleAccumulate()
            case .windowSnow: toggleSnowOnWindows()
            case .deepInteraction: toggleDeepInteraction()
            case .snowballs: toggleSnowballs()
            case .behindWindows: toggleBehindWindows()
            case .fullScreen: toggleFullScreen()
            case .screenshots: toggleScreenshots()
            case .maxPerformance: toggleMaxPerformance()
            case .login: toggleOpenAtLogin()
            }
        case .clear: clearSnow()
        case .reset: resetSnowSettings()
        case .updates: updater?.checkForUpdates(nil)
        case .quit: NSApp.terminate(nil)
        }
        settingsWindow?.refresh()
    }

    private func applySnowSettings() {
        let intensity = Float(Preferences.intensity)
        if intensity == 0 { displays.cancelSnowballs() }
        let opacity = Float(Preferences.fallingOpacity)
        let tuning = Preferences.snowTuning
        for snow in screens {
            let simulation = snow.simulation
            if simulation.intensity != intensity { simulation.intensity = intensity }
            simulation.fallingOpacity = opacity
            simulation.fallingPaused = Preferences.snowfallPaused
            simulation.tuning = tuning
        }
    }

    @objc private func resetSnowSettings() {
        for control in SnowControl.allCases {
            Preferences.setSnowValue(control.standard, for: control)
        }
        Preferences.snowballSensitivity = 1
        Preferences.snowDirection = 0
        Preferences.snowfallPaused = false
        screens.forEach { $0.simulation.snowballSensitivity = 1 }
        if !accumulates { toggleAccumulate() }
        applySnowSettings()
        updateStatusIcon()
    }

    @objc private func toggleAccumulate() {
        accumulates.toggle()
        Preferences.accumulate = accumulates
        for snow in screens { snow.simulation.accumulates = accumulates }
    }

    @objc private func toggleSnowOnWindows() {
        snowOnWindows.toggle()
        Preferences.snowOnWindows = snowOnWindows
        if !snowOnWindows {
            displays.cancelSnowballs()
            screens.forEach { $0.dropWindowSnow() }
        }
    }

    @objc private func toggleDeepInteraction() {
        Preferences.deepInteraction.toggle()
        Marquee.enabled = Preferences.deepInteraction
    }

    @objc private func toggleSnowballs() {
        displays.snowballEnabled.toggle()
        Preferences.snowballEnabled = displays.snowballEnabled
        displays.cancelSnowballs()
    }

    @objc private func clearSnow() {
        displays.cancelSnowballs()
        let direction = screens.first?.simulation.breezeDirection ?? -1
        let calm = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        for snow in screens { snow.simulation.blowAway(direction: direction, calm: calm) }
    }

    @objc private func toggleBehindWindows() {
        behindWindows.toggle()
        Preferences.behindWindows = behindWindows
        for snow in screens { snow.window.behindWindows = behindWindows }
    }

    @objc private func toggleFullScreen() {
        Preferences.showOverFullScreen.toggle()
        for snow in screens { snow.overFullScreen = Preferences.showOverFullScreen }
    }

    @objc private func toggleScreenshots() {
        Preferences.showInScreenshots.toggle()
        for snow in screens {
            snow.window.showsInScreenshots = Preferences.showInScreenshots
            snow.dock.window.showsInScreenshots = Preferences.showInScreenshots
        }
    }

    @objc private func toggleOpenAtLogin() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
            } else {
                try service.register()
            }
        } catch {
            NSLog("Snowhush: login item change failed: \(error)")
        }
    }

    @objc private func toggleMaxPerformance() {
        Preferences.maxPerformance.toggle()
        for snow in screens { snow.maxFrameRate = Preferences.maxPerformance }
    }

    private func updateStatusIcon() {
        statusItem.button?.image = Self.icon(dimmed: Preferences.snowfallStopped)
    }

    /// The integrated GPU on a Mac with two: asking for the default device would wake the discrete one and hold it
    /// awake for as long as the snow falls. The devices left unused are let go before the discrete GPU powers up.
    private static func lowPowerDevice() -> MTLDevice? {
        autoreleasepool { MTLCopyAllDevices().first { $0.isLowPower } }
    }

    private static func icon(dimmed: Bool) -> NSImage? {
        guard let symbol = NSImage(systemSymbolName: "snowflake", accessibilityDescription: appDisplayName) else { return nil }
        let image = symbol.withSymbolConfiguration(.init(pointSize: 17, weight: .regular)) ?? symbol
        guard dimmed else { return image }
        // Dimmed by hand: the button's appearsDisabled also disables the slider in its menu, so Off could not be left.
        let faded = NSImage(size: image.size, flipped: false) { rect in
            image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 0.4)
            return true
        }
        faded.isTemplate = image.isTemplate
        faded.accessibilityDescription = image.accessibilityDescription
        return faded
    }

    // MARK: - System

    private func observeSystem() {
        power.changed = { [unowned self] in screens.forEach { $0.apply(power.budget) } }
        let workspace = NSWorkspace.shared.notificationCenter
        let distributed = DistributedNotificationCenter.default()

        observe(workspace, NSWorkspace.screensDidSleepNotification) { $0.screensAsleep = true }
        observe(workspace, NSWorkspace.screensDidWakeNotification) { $0.screensAsleep = false }
        observe(workspace, NSWorkspace.sessionDidResignActiveNotification) { $0.sessionInactive = true }
        observe(workspace, NSWorkspace.sessionDidBecomeActiveNotification) { $0.sessionInactive = false }
        observe(distributed, Notification.Name("com.apple.screenIsLocked")) { $0.screenLocked = true }
        observe(distributed, Notification.Name("com.apple.screenIsUnlocked")) { $0.screenLocked = false }
        observe(.default, NSWindow.didChangeOcclusionStateNotification) { _ in }
        observe(.default, NSApplication.didChangeScreenParametersNotification) { $0.syncScreens() }
        observe(workspace, NSWorkspace.activeSpaceDidChangeNotification) {
            $0.displays.cancelSnowballs()
            $0.screens.forEach { $0.spaceChanged() }
        }
        observe(workspace, NSWorkspace.didActivateApplicationNotification) {
            $0.displays.cancelSnowballs()
            $0.screens.forEach { $0.watchWindows() }
        }
    }

    private func observe(
        _ center: NotificationCenter,
        _ name: Notification.Name,
        object: AnyObject? = nil,
        _ change: @escaping (AppDelegate) -> Void
    ) {
        observers.append(center.addObserver(forName: name, object: object, queue: .main) { [weak self] _ in
            guard let self else { return }
            change(self)
            self.updateActivity()
        })
    }

    private func updateActivity() {
        let awake = !screensAsleep && !screenLocked && !sessionInactive
        for snow in screens {
            snow.occlusionChanged()
            snow.setActive(awake && !snow.givesWay && (snow.window.occlusionState.contains(.visible) || snow.fading), asleep: !awake)
        }
    }
}
