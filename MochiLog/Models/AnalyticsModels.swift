import Foundation
import SwiftUI

// チャートのレンジプリセット（AnalyticsView とサブビューで共有）
enum RangePreset: String, CaseIterable, Identifiable {
  case oneWeek = "1w"
  case oneMonth = "1m"
  case threeMonths = "3m"
  case sixMonths = "6m"
  case oneYear = "1y"
  case twoYears = "2y"
  case all = "all"

  var id: String { self.rawValue }

  /// ローカライズされた表示名
  var localizedName: String {
    switch self {
    case .oneWeek:
      return String(localized: "range_1w")
    case .oneMonth:
      return String(localized: "range_1m")
    case .threeMonths:
      return String(localized: "range_3m")
    case .sixMonths:
      return String(localized: "range_6m")
    case .oneYear:
      return String(localized: "range_1y")
    case .twoYears:
      return String(localized: "range_2y")
    case .all:
      return String(localized: "range_all")
    }
  }
}
