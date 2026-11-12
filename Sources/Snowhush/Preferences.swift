import AppKit

enum Preferences {
    private static let defaults = UserDefaults.standard
    private static let intensityKey = "intensity"
    /// Before the slider, the intensity was one of Off, Light, Steady, Heavy and Variable.
    private static let snowfallKey = "snowfall"
    private static let behindWindowsKey = "behindWindows"
    private static let showOverFullScreenKey = "showOverFullScreen"
    private static let meltSnowKey = "meltSnow"
    private static let accumulateKey = "accumulate"
    private static let snowOnWindowsKey = "snowOnWindows"
    private static let welcomedKey = "welcomed"
    private static let installedAtKey = "installedAt"
    private static let showInScreenshotsKey = "showInScreenshots"
    private static let deepInteractionKey = "deepInteraction"
    private static let performanceKey = "performance"
    private static let fallingOpacityKey = "fallingOpacity"
    private static let snowDirectionKey = "snowDirection"

    static func registerDefaults() {
        // Migrate before registering the fallback, which would mask an absent intensity.
        if defaults.object(forKey: intensityKey) == nil, let stop = defaults.object(forKey: snowfallKey) as? Int {
            defaults.set([0, 0.25, 0.5, 0.75, 0.5][min(max(stop, 0), 4)], forKey: intensityKey)
        }
        defaults.register(defaults: [
            intensityKey: defaultIntensity,
            behindWindowsKey: false,
            showOverFullScreenKey: false,
            meltSnowKey: true,
            accumulateKey: true,
            snowOnWindowsKey: true,
            showInScreenshotsKey: false,
            deepInteractionKey: false,
            fallingOpacityKey: 1.0,
            "snowballEnabled": true,
            "snowballSensitivity": 1.0,
        ])
        if defaults.object(forKey: SnowControl.melting.key) == nil {
            setSnowValue(defaults.bool(forKey: meltSnowKey) ? SnowControl.melting.standard : 0, for: .melting)
        }
        if defaults.object(forKey: installedAtKey) == nil {
            defaults.set(defaults.bool(forKey: welcomedKey) ? 0 : Date().timeIntervalSince1970, forKey: installedAtKey)
        }
    }

    static var snowballEnabled: Bool {
        get { defaults.bool(forKey: "snowballEnabled") }
        set { defaults.set(newValue, forKey: "snowballEnabled") }
    }

    static var snowDirection: Int {
        get { min(max(defaults.integer(forKey: snowDirectionKey), -SnowTuning.directionLimit), SnowTuning.directionLimit) }
        set { defaults.set(newValue, forKey: snowDirectionKey) }
    }

    static var snowfallPaused: Bool {
        get { defaults.bool(forKey: "snowfallPaused") }
        set { defaults.set(newValue, forKey: "snowfallPaused") }
    }

    static var snowfallStopped: Bool { snowfallPaused || intensity <= 0 }

    static var snowballModifier: SnowballModifier {
        get { SnowballModifier(rawValue: defaults.integer(forKey: "snowballModifier")) ?? .control }
        set { defaults.set(newValue.rawValue, forKey: "snowballModifier") }
    }

    static var snowballSensitivity: Double {
        get {
            let value = defaults.double(forKey: "snowballSensitivity")
            return value.isFinite ? min(max(value, 0), 2) : 1
        }
        set { defaults.set(newValue, forKey: "snowballSensitivity") }
    }

    static var defaultIntensity: Double {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0.25 : 0.5
    }

    static func snowValue(for control: SnowControl) -> Double {
        if control == .intensity { return intensity }
        if control == .opacity { return fallingOpacity }
        let value = defaults.object(forKey: control.key) as? Double ?? control.standard
        return value.isFinite ? min(max(value, control.range.lowerBound), control.range.upperBound) : control.standard
    }

    static func setSnowValue(_ value: Double, for control: SnowControl) {
        switch control {
        case .intensity: intensity = value
        case .opacity: fallingOpacity = value
        default: defaults.set(value, forKey: control.key)
        }
    }

    static var snowTuning: SnowTuning {
        SnowTuning(speed: Float(snowValue(for: .speed)), accumulation: Float(snowValue(for: .accumulation)),
                   physics: Float(snowValue(for: .physics)), maximumDepth: Float(snowValue(for: .depth)),
                   meltingSpeed: Float(snowValue(for: .melting)), directionDegrees: snowDirection)
    }

    /// When this install was first run, or nil for an install older than the stamp.
    static var installedAt: Date? {
        let stamp = defaults.double(forKey: installedAtKey)
        return stamp > 0 ? Date(timeIntervalSince1970: stamp) : nil
    }

    /// How much falls, from 0 to 1.
    static var intensity: Double {
        get {
            let value = defaults.double(forKey: intensityKey)
            return value.isFinite ? min(max(value, 0), 1) : defaultIntensity
        }
        set { defaults.set(newValue, forKey: intensityKey) }
    }

    static var snowOnWindows: Bool {
        get { defaults.bool(forKey: snowOnWindowsKey) }
        set { defaults.set(newValue, forKey: snowOnWindowsKey) }
    }

    static var accumulate: Bool {
        get { defaults.bool(forKey: accumulateKey) }
        set { defaults.set(newValue, forKey: accumulateKey) }
    }

    static var welcomed: Bool {
        get { defaults.bool(forKey: welcomedKey) }
        set { defaults.set(newValue, forKey: welcomedKey) }
    }

    static var behindWindows: Bool {
        get { defaults.bool(forKey: behindWindowsKey) }
        set { defaults.set(newValue, forKey: behindWindowsKey) }
    }

    static var showOverFullScreen: Bool {
        get { defaults.bool(forKey: showOverFullScreenKey) }
        set { defaults.set(newValue, forKey: showOverFullScreenKey) }
    }

    static var showInScreenshots: Bool {
        get { defaults.bool(forKey: showInScreenshotsKey) }
        set { defaults.set(newValue, forKey: showInScreenshotsKey) }
    }

    /// The snow also settles on what the desktop draws without a window of its own: a selection dragged across it.
    static var deepInteraction: Bool {
        get { defaults.bool(forKey: deepInteractionKey) }
        set { defaults.set(newValue, forKey: deepInteractionKey) }
    }

    /// How opaque the snow is while it falls.
    static var fallingOpacity: Double {
        get {
            let value = defaults.double(forKey: fallingOpacityKey)
            let range = SnowControl.opacity.range
            return value.isFinite ? min(max(value, range.lowerBound), range.upperBound) : SnowControl.opacity.standard
        }
        set { defaults.set(newValue, forKey: fallingOpacityKey) }
    }

    /// Drawn at the display's highest rate all the time, instead of only while something is pushed around.
    static var maxPerformance: Bool {
        get { defaults.integer(forKey: performanceKey) == 1 }
        set { defaults.set(newValue ? 1 : 0, forKey: performanceKey) }
    }
}

enum SnowControl: String, CaseIterable {
    case intensity, opacity, speed, accumulation, physics, depth, melting

    var key: String { "snow.control.\(rawValue)" }

    var title: String {
        let fallback: String = switch self {
        case .intensity: "Intensity"
        case .opacity: "Opacity"
        case .speed: "Snowfall Speed"
        case .accumulation: "Accumulation Rate"
        case .physics: "Snow Physics"
        case .depth: "Maximum Snow Depth"
        case .melting: "Melting Speed"
        }
        let titleKey = self == .intensity || self == .opacity ? rawValue : key
        return tr(titleKey, fallback: fallback)
    }

    var range: ClosedRange<Double> {
        switch self {
        case .intensity: 0...1
        case .opacity, .accumulation: 0...2
        case .speed: 0.35...1.75
        case .physics: 0...1.75
        case .depth: 5...80
        case .melting: 0...3
        }
    }

    var standard: Double {
        let tuning = SnowTuning.standard
        return switch self {
        case .intensity: Preferences.defaultIntensity
        case .opacity: 1
        case .speed: Double(tuning.speed)
        case .accumulation: Double(tuning.accumulation)
        case .physics: Double(tuning.physics)
        case .depth: Double(tuning.maximumDepth)
        case .melting: Double(tuning.meltingSpeed)
        }
    }

    /// Each half spans the corresponding side of the existing setting's range.
    func percentage(for value: Double) -> Double {
        let middle = standard
        let span = value < middle ? middle - range.lowerBound : range.upperBound - middle
        return 100 + 100 * (value - middle) / span
    }

    func value(for percentage: Double) -> Double {
        let middle = standard
        let span = percentage < 100 ? middle - range.lowerBound : range.upperBound - middle
        return middle + (percentage - 100) / 100 * span
    }
}

enum SnowballModifier: Int, CaseIterable {
    case control, option, shift

    var flag: CGEventFlags {
        switch self {
        case .control: .maskControl
        case .option: .maskAlternate
        case .shift: .maskShift
        }
    }

    var title: String {
        switch self {
        case .control: "Control ⌃"
        case .option: "Option ⌥"
        case .shift: "Shift ⇧"
        }
    }
}
