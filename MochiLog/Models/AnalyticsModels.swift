import Foundation
import SwiftUI

// チャートのレンジプリセット（AnalyticsView とサブビューで共有）
enum RangePreset: String, CaseIterable, Identifiable {
  case auto = "auto"
  case oneWeek = "1w"
  case oneMonth = "1m"
  case threeMonths = "3m"
  case sixMonths = "6m"
  case oneYear = "1y"
  case twoYears = "2y"
  case threeYears = "3y"

  var id: String { self.rawValue }

  /// ローカライズされた表示名
  var localizedName: String {
    switch self {
    case .auto:
      return String(localized: "range_auto", table: "Analytics")
    case .oneWeek:
      return String(localized: "range_1w", table: "Analytics")
    case .oneMonth:
      return String(localized: "range_1m", table: "Analytics")
    case .threeMonths:
      return String(localized: "range_3m", table: "Analytics")
    case .sixMonths:
      return String(localized: "range_6m", table: "Analytics")
    case .oneYear:
      return String(localized: "range_1y", table: "Analytics")
    case .twoYears:
      return String(localized: "range_2y", table: "Analytics")
    case .threeYears:
      return String(localized: "range_3y", table: "Analytics")
    }
  }
}
