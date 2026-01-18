import Foundation
import SwiftUI

// MARK: - チャート軸ヘルパー
/// チャートの横軸ラベル表示とデータポイント表示に関する共通ロジック
struct ChartAxisHelper {

  // MARK: - データポイント表示判定

  /// チャートにデータポイント（ドット）を表示するかどうかを判定
  /// - Parameters:
  ///   - recordCount: 表示するレコード数
  ///   - startDay: 表示開始日
  ///   - endDay: 表示終了日
  /// - Returns: データポイントを表示する場合はtrue
  static func shouldShowDataPoints(recordCount: Int, startDay: Date, endDay: Date) -> Bool {
    let calendar = Calendar.current
    let displayDays = calendar.dateComponents([.day], from: startDay, to: endDay).day ?? 0
    // 表示期間が60日未満、かつレコード数が15個以下の場合のみポイントを表示
    return recordCount <= 15 && displayDays < 60
  }

  // MARK: - 横軸ラベル間引き

  /// 横軸ラベルの間引きストライドとフォーマット指定を計算
  /// - Parameters:
  ///   - startDay: 表示開始日
  ///   - endDay: 表示終了日
  ///   - isCompact: コンパクト画面（iPhone）かどうか
  /// - Returns: (strideComponent, strideCount, labelFormat)
  static func calculateXAxisStride(
    startDay: Date, endDay: Date, isCompact: Bool
  ) -> (strideComponent: Calendar.Component, strideCount: Int, labelFormat: XAxisLabelFormat) {
    let calendar = Calendar.current
    let displayDays = calendar.dateComponents([.day], from: startDay, to: endDay).day ?? 0
    let displayMonths = calendar.dateComponents([.month], from: startDay, to: endDay).month ?? 0

    // 表示期間に応じて適切な単位とストライドを決定
    let (strideComponent, strideCount): (Calendar.Component, Int)
    let labelFormat: XAxisLabelFormat

    if displayDays <= 7 {
      // 1週間以下: 日単位、1日ごと
      strideComponent = .day
      strideCount = 1
      labelFormat = .monthDay
    } else if displayDays <= 14 {
      // 2週間以下: 日単位、コンパクトなら2日ごと、レギュラーなら1日ごと
      strideComponent = .day
      strideCount = isCompact ? 2 : 1
      labelFormat = .monthDay
    } else if displayDays <= 30 {
      // 1ヶ月以下: 日単位、コンパクトなら3日ごと、レギュラーなら2日ごと
      strideComponent = .day
      strideCount = isCompact ? 3 : 2
      labelFormat = .monthDay
    } else if displayDays <= 60 {
      // 2ヶ月以下: 週単位、1週間ごと
      strideComponent = .weekOfYear
      strideCount = 1
      labelFormat = .monthDay
    } else if displayMonths <= 3 {
      // 3ヶ月以下: 週単位、2週間ごと
      strideComponent = .weekOfYear
      strideCount = 2
      labelFormat = .monthDay
    } else if displayMonths <= 6 {
      // 6ヶ月以下: 月単位、1ヶ月ごと
      strideComponent = .month
      strideCount = 1
      labelFormat = .monthDay
    } else if displayMonths <= 12 {
      // 1年以下: 月単位、コンパクトなら3ヶ月ごと、レギュラーなら2ヶ月ごと
      strideComponent = .month
      strideCount = isCompact ? 3 : 2
      labelFormat = .monthOnly
    } else if displayMonths <= 24 {
      // 2年以下: 月単位、コンパクトなら6ヶ月ごと、レギュラーなら4ヶ月ごと
      strideComponent = .month
      strideCount = isCompact ? 6 : 4
      labelFormat = .monthOnly
    } else if displayMonths <= 36 {
      // 3年以下: 年単位、1年ごと
      strideComponent = .year
      strideCount = 1
      labelFormat = .yearOnly
    } else {
      // 3年超: 年単位、1年ごと
      strideComponent = .year
      strideCount = 1
      labelFormat = .yearOnly
    }

    return (strideComponent, strideCount, labelFormat)
  }

  /// 横軸ラベルのフォーマット指定
  enum XAxisLabelFormat {
    case monthDay  // 月/日形式（例: 1/15）
    case monthOnly  // 月のみ（例: 3月）
    case yearOnly  // 年のみ（例: 2024年）
  }
}
