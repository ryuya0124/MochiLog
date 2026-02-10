import SwiftUI

/// チャート用のレンジ選択コントロール（レスポンシブ対応）
/// 横幅に応じて segmented / menu スタイルを自動切り替え
struct ChartRangeSelector: View {
  @Binding var selectedRange: RangePreset
  let canMoveNext: Bool
  let canMovePrevious: Bool
  let shiftWindow: (Bool) -> Void
  let startDay: Date
  let endDay: Date

  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  /// 横幅の閾値（この値未満では menu スタイル）
  private let menuStyleThreshold: CGFloat = 600

  var body: some View {
    GeometryReader { geometry in
      let useMenuStyle = geometry.size.width < menuStyleThreshold

      if horizontalSizeClass == .compact {
        // iPhone: 常に menu スタイル
        compactLayout
      } else if useMenuStyle {
        // iPad 狭い幅: menu スタイル
        regularMenuLayout
      } else {
        // iPad 広い幅: segmented スタイル
        regularSegmentedLayout
      }
    }
    .frame(height: 60)
  }

  // MARK: - iPhone用レイアウト
  private var compactLayout: some View {
    HStack(spacing: 8) {
      VStack(alignment: .leading, spacing: 4) {
        Text(String(localized: "chart_range", table: "Analytics"))
          .font(.caption)
          .foregroundStyle(.secondary)
        HStack(spacing: 8) {
          navigationButtons

          Picker("", selection: $selectedRange) {
            rangeOptions
          }
          .pickerStyle(.menu)
          .accessibilityLabel(Text(String(localized: "chart_range", table: "Analytics")))

          yearLabel
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  // MARK: - iPad menu スタイル
  private var regularMenuLayout: some View {
    HStack(spacing: 12) {
      VStack(alignment: .leading, spacing: 6) {
        Text(String(localized: "chart_range", table: "Analytics"))
          .font(.caption)
          .foregroundStyle(.secondary)
        HStack(spacing: 12) {
          navigationButtons

          Picker("", selection: $selectedRange) {
            rangeOptions
          }
          .pickerStyle(.menu)
          .accessibilityLabel(Text(String(localized: "chart_range", table: "Analytics")))
        }
      }
    }
  }

  // MARK: - iPad segmented スタイル
  private var regularSegmentedLayout: some View {
    HStack(spacing: 12) {
      VStack(alignment: .leading, spacing: 6) {
        Text(String(localized: "chart_range", table: "Analytics"))
          .font(.caption)
          .foregroundStyle(.secondary)
        HStack(spacing: 12) {
          navigationButtons

          Picker("", selection: $selectedRange) {
            rangeOptions
          }
          .pickerStyle(.segmented)
          .accessibilityLabel(Text(String(localized: "chart_range", table: "Analytics")))
        }
      }
    }
  }

  // MARK: - 共通コンポーネント
  private var navigationButtons: some View {
    Group {
      Button {
        shiftWindow(true)
      } label: {
        Image(systemName: "chevron.left")
      }
      .disabled(!canMovePrevious)

      Button {
        shiftWindow(false)
      } label: {
        Image(systemName: "chevron.right")
      }
      .disabled(!canMoveNext)
    }
  }

  private var rangeOptions: some View {
    ForEach(RangePreset.manualCases) { preset in
      Text(preset.localizedName).tag(preset)
    }
  }

  @ViewBuilder
  private var yearLabel: some View {
    // iPhone のみ年を表示
    if horizontalSizeClass == .compact {
      let startYear = Calendar.current.component(.year, from: startDay)
      let endYear = Calendar.current.component(.year, from: endDay)
      if startYear != endYear {
        Text("\(String(startYear))年 ~ \(String(endYear))年")
          .font(.caption)
          .foregroundStyle(.secondary)
      } else {
        Text("\(String(endYear))年")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
  }
}
