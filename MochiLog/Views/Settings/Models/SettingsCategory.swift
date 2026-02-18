import SwiftUI

// MARK: - 設定カテゴリ
enum SettingsCategory: String, CaseIterable, Identifiable {
  case general
  case deviceSelection
  case appleWatch
  case dataManagement
  case support
  case debug
  case advanced
  case about

  var id: String { rawValue }

  var icon: String {
    switch self {
    case .general: return "gearshape.fill"
    case .deviceSelection: return "iphone.gen3"
    case .appleWatch: return "applewatch"
    case .dataManagement: return "trash.fill"
    case .support: return "book.fill"
    case .about: return "info.circle"
    case .debug: return "envelope.fill"
    case .advanced: return "gearshape.2.fill"
    }
  }

  var title: String {
    switch self {
    case .general: return String(localized: "general", table: "Settings")
    case .deviceSelection: return String(localized: "device_selection_settings", table: "Settings")
    case .appleWatch: return String(localized: "apple_watch_settings", table: "Settings")
    case .dataManagement: return String(localized: "data_management", table: "Settings")
    case .support: return String(localized: "support", table: "Settings")
    case .about: return String(localized: "about_app", table: "Settings")
    case .debug: return String(localized: "debug", table: "Support")
    case .advanced: return String(localized: "advanced_settings", table: "Settings")
    }
  }
}
