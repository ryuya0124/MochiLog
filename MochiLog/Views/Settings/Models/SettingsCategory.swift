import SwiftUI

// MARK: - 設定カテゴリ
enum SettingsCategory: String, CaseIterable, Identifiable {
  case general
  case appleWatch
  case dataManagement
  case support
  case debug
  case advanced

  var id: String { rawValue }

  var icon: String {
    switch self {
    case .general: return "gearshape.fill"
    case .appleWatch: return "applewatch"
    case .dataManagement: return "trash.fill"
    case .support: return "book.fill"
    case .debug: return "envelope.fill"
    case .advanced: return "gearshape.2.fill"
    }
  }

  var title: String {
    switch self {
    case .general: return String(localized: "general", table: "Settings")
    case .appleWatch: return String(localized: "apple_watch_settings", table: "Settings")
    case .dataManagement: return String(localized: "data_management", table: "Settings")
    case .support: return String(localized: "support", table: "Settings")
    case .debug: return String(localized: "debug", table: "Support")
    case .advanced: return String(localized: "advanced_settings", table: "Settings")
    }
  }
}
