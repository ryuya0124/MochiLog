import Foundation
import SwiftUI

// チャートのレンジプリセット（AnalyticsView とサブビューで共有）
enum RangePreset: String, CaseIterable, Identifiable {
  case auto = "auto"
  case oneWeek = "1w"
  case twoWeeks = "2w"  // 自動レンジ判定専用（手動選択には表示しない）
  case oneMonth = "1m"
  case threeMonths = "3m"
  case sixMonths = "6m"
  case oneYear = "1y"
  case twoYears = "2y"
  case threeYears = "3y"

  var id: String { self.rawValue }

  /// 手動選択用のケースリスト
  static var manualCases: [RangePreset] {
    [
      .auto, .oneWeek, .twoWeeks, .oneMonth, .threeMonths, .sixMonths, .oneYear, .twoYears,
      .threeYears,
    ]
  }

  /// ローカライズされた表示名
  var localizedName: String {
    switch self {
    case .auto:
      return L10n.string("range_auto", table: "Analytics")
    case .oneWeek:
      return L10n.string("range_1w", table: "Analytics")
    case .twoWeeks:
      return L10n.string("range_2w", table: "Analytics")
    case .oneMonth:
      return L10n.string("range_1m", table: "Analytics")
    case .threeMonths:
      return L10n.string("range_3m", table: "Analytics")
    case .sixMonths:
      return L10n.string("range_6m", table: "Analytics")
    case .oneYear:
      return L10n.string("range_1y", table: "Analytics")
    case .twoYears:
      return L10n.string("range_2y", table: "Analytics")
    case .threeYears:
      return L10n.string("range_3y", table: "Analytics")
    }
  }
}
