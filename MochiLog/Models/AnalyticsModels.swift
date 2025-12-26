import Foundation
import SwiftUI

// チャートのレンジプリセット（AnalyticsView とサブビューで共有）
enum RangePreset: String, CaseIterable, Identifiable {
  case oneWeek = "1w"
  case oneMonth = "1m"
  case threeMonths = "3m"
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
    case .all:
      return String(localized: "range_all")
    }
  }
}
