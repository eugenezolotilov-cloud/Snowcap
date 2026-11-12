import Foundation

/// The text for `key` from `locales/`, which build.sh ships as the app's `.lproj` tables.
func tr(_ key: String, fallback: String? = nil) -> String {
    Bundle.main.localizedString(forKey: key, value: fallback, table: nil)
}

var appDisplayName: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "Snowcap" }
