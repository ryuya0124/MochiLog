import Foundation

/// Reset explanations once per installed release; keep user choices on later launches.
enum RecordInfoPreferences {
  static func prepareForLaunch(defaults: UserDefaults = .standard, release: String) {
    let releaseKey = "recordInfoDefaultsRelease"
    guard defaults.string(forKey: releaseKey) != release else { return }
    defaults.set(false, forKey: "showRecordInfoButtons")
    defaults.set(release, forKey: releaseKey)
  }
}
