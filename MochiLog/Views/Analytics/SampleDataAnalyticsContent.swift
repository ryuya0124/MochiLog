import SwiftUI

// MARK: - サンプルデータ分析ビュー
/// データがない時にサンプルデータでグラフを表示するビュー
struct SampleDataAnalyticsContent: View {
  @Binding var showingSampleData: Bool
  @Binding var animateChart: Bool
  @Binding var selectedRange: RangePreset
  @StateObject private var appSettings = AppSettings.shared

  @State private var selectedDevice: String?

  private let sampleRecords = SampleDataProvider.generateSampleRecords()

  private var deviceNames: [String] {
    SampleDataProvider.sampleDeviceNames
  }

  private var filteredRecords: [BatteryRecord] {
    guard let device = selectedDevice else { return sampleRecords }
    return sampleRecords.filter { $0.deviceName == device }
  }

  /// データ期間に基づいて最適なレンジを決定
  private func autoRange(for records: [BatteryRecord]) -> RangePreset {
    guard let first = records.min(by: { $0.logDate < $1.logDate })?.logDate,
      let last = records.max(by: { $0.logDate < $1.logDate })?.logDate
    else { return .oneMonth }

    let days = Calendar.current.dateComponents([.day], from: first, to: last).day ?? 0

    if days <= 7 { return .oneWeek }
    if days <= 30 { return .oneMonth }
    if days <= 90 { return .threeMonths }
    return .all
  }

  var body: some View {
    VStack(spacing: 20) {
      // サンプルデータバナー（スクロールと一緒に動く）
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

      // 期間計算（データの全期間）
      let calendar = Calendar.current
      let startDate = filteredRecords.min(by: { $0.logDate < $1.logDate })?.logDate ?? Date()
      let endDate = filteredRecords.max(by: { $0.logDate < $1.logDate })?.logDate ?? Date()

      let startDay = calendar.startOfDay(for: startDate)
      let endDay = calendar.startOfDay(for: endDate)

      // 自動でunit決定
      let days = calendar.dateComponents([.day], from: startDay, to: endDay).day ?? 0
      let unit: AppSettings.ChartUnit = days > 120 ? .month : (days > 14 ? .week : .day)

      // ヘルス推移グラフ
      HealthTrendView(
        visibleRecords: filteredRecords,
        startDay: startDay,
        endDay: endDay,
        unit: unit,
        selectedRange: $selectedRange,
        canMoveNext: false,
        canMovePrevious: false,
        shiftWindow: { _ in },
        animateChart: $animateChart
      )

      // サイクル推移グラフ
      CycleTrendView(
        visibleRecords: filteredRecords,
        startDay: startDay,
        endDay: endDay,
        unit: unit,
        animateChart: $animateChart
      )

      // 統計情報
      StatisticsView(filteredRecords: filteredRecords)
    }
    .padding(.horizontal)
    .onAppear {
      // サンプルデータ表示時は自動で全期間に設定
      selectedRange = autoRange(for: filteredRecords)
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
