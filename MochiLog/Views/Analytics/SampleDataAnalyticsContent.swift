import SwiftUI

// MARK: - サンプルデータ分析ビュー
/// データがない時にサンプルデータでグラフを表示するビュー
/// 共通のグラフ表示コンポーネントを使用してコード重複を排除
struct SampleDataAnalyticsContent: View {
  @Binding var showingSampleData: Bool
  @Binding var animateChart: Bool
  @Binding var selectedRange: RangePreset
  @StateObject private var appSettings = AppSettings.shared
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  @State private var selectedDevice: String?
  @State private var windowEnd: Date = Date()

  private let sampleRecords = SampleDataProvider.generateSampleRecords()

  private var deviceNames: [String] {
    SampleDataProvider.sampleDeviceNames
  }

  private var filteredRecords: [BatteryRecord] {
    guard let device = selectedDevice else { return sampleRecords }
    return sampleRecords.filter { $0.deviceName == device }
  }

  // MARK: - 共通ユーティリティを使用したプロパティ

  private var canMoveNext: Bool {
    ChartWindowNavigator.canMoveNext(
      currentEnd: windowEnd, range: selectedRange, records: filteredRecords)
  }

  private var canMovePrevious: Bool {
    ChartWindowNavigator.canMovePrevious(
      currentEnd: windowEnd, range: selectedRange, records: filteredRecords)
  }

  private func shiftWindow(backward: Bool) {
    windowEnd = ChartWindowNavigator.shiftWindow(
      currentEnd: windowEnd,
      backward: backward,
      range: selectedRange,
      records: filteredRecords
    )
  }

  var body: some View {
    VStack(spacing: 20) {
      // サンプルデータバナー
      SampleDataBanner(
        onClose: {
          withAnimation {
            showingSampleData = false
          }
        },
        onAddData: {}
      )

      // デバイス選択ピッカー
      DevicePickerView(deviceNames: deviceNames, selectedDevice: $selectedDevice)

      // 期間計算
      let calendar = Calendar.current
      let startDate = ChartWindowNavigator.windowStart(
        for: windowEnd, range: selectedRange, allRecords: filteredRecords)
      let startDay = calendar.startOfDay(for: startDate)
      let endDay = calendar.startOfDay(for: windowEnd)

      let visibleRecords = filteredRecords.filter {
        let d = calendar.startOfDay(for: $0.logDate)
        return d >= startDay && d <= endDay
      }

      let unit = ChartWindowNavigator.autoUnit(
        for: visibleRecords, startDay: startDay, endDay: endDay)

      // iPad: 2列レイアウト、iPhone: 1列レイアウト
      if horizontalSizeClass == .regular {
        // iPad向け2列グリッド
        LazyVGrid(
          columns: [GridItem(.flexible()), GridItem(.flexible())],
          spacing: 20
        ) {
          // ヘルス推移グラフ
          HealthTrendView(
            visibleRecords: visibleRecords,
            startDay: startDay,
            endDay: endDay,
            unit: unit,
            selectedRange: $selectedRange,
            canMoveNext: canMoveNext,
            canMovePrevious: canMovePrevious,
            shiftWindow: shiftWindow,
            animateChart: $animateChart
          )

          // サイクル推移グラフ
          CycleTrendView(
            visibleRecords: visibleRecords,
            startDay: startDay,
            endDay: endDay,
            unit: unit,
            animateChart: $animateChart
          )
        }
        .frame(maxWidth: 1200)
      } else {
        // iPhone向け1列レイアウト
        // ヘルス推移グラフ
        HealthTrendView(
          visibleRecords: visibleRecords,
          startDay: startDay,
          endDay: endDay,
          unit: unit,
          selectedRange: $selectedRange,
          canMoveNext: canMoveNext,
          canMovePrevious: canMovePrevious,
          shiftWindow: shiftWindow,
          animateChart: $animateChart
        )

        // サイクル推移グラフ
        CycleTrendView(
          visibleRecords: visibleRecords,
          startDay: startDay,
          endDay: endDay,
          unit: unit,
          animateChart: $animateChart
        )
      }

      // 統計情報
      StatisticsView(filteredRecords: visibleRecords)
    }
    .padding(.horizontal)
    .onAppear {
      // ウィンドウ終了日を初期化
      windowEnd = ChartWindowNavigator.initializeWindowEnd(
        for: filteredRecords, range: selectedRange)
      // 自動でレンジを設定
      selectedRange = ChartWindowNavigator.autoRange(for: filteredRecords)

      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        withAnimation(.easeOut(duration: 0.6)) {
          animateChart = true
        }
      }
    }
  }
}

#Preview {
  SampleDataAnalyticsContent(
    showingSampleData: .constant(true),
    animateChart: .constant(true),
    selectedRange: .constant(.all)
  )
}
