import Foundation

/// Menu bar widths the app offers. The raw value is the stored point width.
enum LyricsWidth: Double, CaseIterable, Sendable {
    case compact = 200
    case narrow = 240
    case medium = 360
    case wide = 600

    static let `default` = LyricsWidth.compact

    var points: CGFloat { CGFloat(rawValue) }

    var name: String {
        switch self {
        case .compact: "Compact"
        case .narrow: "Narrow"
        case .medium: "Medium"
        case .wide: "Wide"
        }
    }

    var menuTitle: String { "\(name) · \(Int(rawValue))pt" }
    var controlTitle: String { "Width \(Int(rawValue))pt" }
}

/// The one place that knows the UserDefaults keys. Keys are unchanged from earlier releases.
struct Preferences {
    private enum Key {
        static let connectOnLaunch = "connectOnLaunch"
        static let lyricsWidth = "lyricsWidth"
        static let shrinkWhenCrowded = "shrinkWhenCrowded"
        static let floatingLyricsBar = "floatingLyricsBar"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var connectOnLaunch: Bool {
        get { defaults.bool(forKey: Key.connectOnLaunch) }
        nonmutating set { defaults.set(newValue, forKey: Key.connectOnLaunch) }
    }

    var lyricsWidth: LyricsWidth {
        get { LyricsWidth(rawValue: defaults.double(forKey: Key.lyricsWidth)) ?? .default }
        nonmutating set { defaults.set(newValue.rawValue, forKey: Key.lyricsWidth) }
    }

    /// Step the menu bar item down to its icon when macOS pushes it out of the menu bar. On by default.
    var shrinkWhenCrowded: Bool {
        get { defaults.object(forKey: Key.shrinkWhenCrowded) as? Bool ?? true }
        nonmutating set { defaults.set(newValue, forKey: Key.shrinkWhenCrowded) }
    }

    /// Draw lyrics in a click-through strip under the menu bar instead of the menu bar item.
    var floatingLyricsBar: Bool {
        get { defaults.bool(forKey: Key.floatingLyricsBar) }
        nonmutating set { defaults.set(newValue, forKey: Key.floatingLyricsBar) }
    }
}
