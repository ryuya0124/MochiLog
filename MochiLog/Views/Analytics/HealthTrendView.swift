import Charts
import Combine
import SwiftUI

struct HealthTrendView: View {
  let visibleRecords: [BatteryRecord]
  let startDay: Date
  let endDay: Date
  let unit: AppSettings.ChartUnit
  @Binding var selectedRange: RangePreset
  let canMoveNext: Bool
  let canMovePrevious: Bool
  let shiftWindow: (Bool) -> Void
  let allDeviceNames: [String]  // 色の安定割り当て用（全デバイス名ソート済み）
  @State private var animateChart: Bool = false
  @State private var isChartReady: Bool = false  // 遅延レンダリング用

  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  private let appSettings = AppSettings.shared
  @State private var analysisDataSource = AppSettings.shared.analysisDataSource

  var body: some View {
    let bodyStartTime = CFAbsoluteTimeGetCurrent()
    let _ = print(
      "[Performance] HealthTrendView.body構築開始 - visibleRecords: \(visibleRecords.count)件")

    return VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .firstTextBaseline) {
        Text(
          String(
            localized: analysisDataSource == .nominal
              ? "health_trend_nominal" : "health_trend_actual",
            table: "Analytics")
        )
        .font(.headline)

        if horizontalSizeClass == .regular {
          Spacer()
          // 年・期間を表示（右寄せ）
          HStack(spacing: 12) {
            // 年
            let startYear = Calendar.current.component(.year, from: startDay)
            let endYear = Calendar.current.component(.year, from: endDay)
            if startYear != endYear {
              Text("\(String(startYear))年 ~ \(String(endYear))年")
            } else {
              Text("\(String(endYear))年")
            }

            // 日付
            Text(
              "\(startDay.formatted(.dateTime.month().day())) – \(endDay.formatted(.dateTime.month().day()))"
            )
          }
          .font(.headline)
          .foregroundStyle(.secondary)
        }
      }

      if visibleRecords.isEmpty {
        Text(String(localized: "no_records_for_device", table: "Analytics"))
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .center)
          .padding()
      } else {
        // チャートコントロール：範囲のみ（表示単位は親が決定）
        ChartRangeSelector(
          selectedRange: $selectedRange,
          canMoveNext: canMoveNext,
          canMovePrevious: canMovePrevious,
          shiftWindow: shiftWindow,
          startDay: startDay,
          endDay: endDay
        )

        // 描画用データは期間に応じて間引き（負荷軽減）
        let downsampleStart = CFAbsoluteTimeGetCurrent()
        let chartRecords = ChartAxisHelper.downsampledRecords(
          visibleRecords, startDay: startDay, endDay: endDay)
        let downsampleElapsed = (CFAbsoluteTimeGetCurrent() - downsampleStart) * 1000
        let _ = print(
          "[Performance] HealthTrendView.downsample: \(String(format: "%.2f", downsampleElapsed))ms (\(visibleRecords.count) -> \(chartRecords.count)件)"
        )

        // 遅延レンダリング: タブ切り替え時はプレースホルダーを表示し、次フレームでChart描画
        if isChartReady {
          healthChartView(chartRecords: chartRecords)
            .transition(.opacity.animation(.easeOut(duration: 0.3)))
        }
        // チャート領域の高さを常に確保（プレースホルダー兼用）
        Color.clear
          .frame(height: isChartReady ? 0 : (horizontalSizeClass == .regular ? 280 : 200))

      }
    }
    .frame(height: horizontalSizeClass == .regular ? 480 : nil, alignment: .top)
    .padding()
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    .onAppear {
      // 次のランループでChart描画を開始（タブ切り替えアニメーションをブロックしない）
      if !isChartReady {
        DispatchQueue.main.async {
          isChartReady = true
        }
      }
    }
    .onDisappear {
      // タブ切り替え時にリセット → 次回表示時に遅延レンダリングが再度有効になる
      isChartReady = false
    }
    .onReceive(appSettings.$analysisDataSource.removeDuplicates()) { newValue in
      if analysisDataSource != newValue {
        analysisDataSource = newValue
      }
    }
  }

  // MARK: - チャートビュー（bodyから分離してコンパイラの型チェック負荷を軽減）
  @ViewBuilder
  private func healthChartView(chartRecords: [BatteryRecord]) -> some View {
    Chart {
      ForEach(chartRecords) { record in
        LineMark(
          x: .value(
            String(localized: "date", table: "Common"),
            Calendar.current.startOfDay(for: record.logDate),
            unit: unit.calendarComponent),
          y: .value(
            String(localized: "real_capacity", table: "Analytics"),
            analysisDataSource == .nominal
              ? record.nominalHealthPercent : record.healthPercent)
        )
        .foregroundStyle(
          by: .value(String(localized: "device_name", table: "Common"), record.deviceName)
        )
        .interpolationMethod(.catmullRom)
      }

      if !chartRecords.isEmpty {
        let deviceGroups = Dictionary(grouping: chartRecords) { $0.deviceName }

        ForEach(Array(deviceGroups.keys.sorted()), id: \.self) { deviceName in
          let deviceRecords = deviceGroups[deviceName] ?? []
          let thinningFactor = max(1, deviceRecords.count / 10)

          ForEach(
            Array(deviceRecords.enumerated().filter { $0.offset % thinningFactor == 0 }),
            id: \.element.id
          ) { _, pointRecord in
            PointMark(
              x: .value(
                String(localized: "date", table: "Common"),
                Calendar.current.startOfDay(for: pointRecord.logDate),
                unit: unit.calendarComponent),
              y: .value(
                String(localized: "real_capacity", table: "Analytics"),
                analysisDataSource == .nominal
                  ? pointRecord.nominalHealthPercent : pointRecord.healthPercent)
            )
            .foregroundStyle(
              by: .value(
                String(localized: "device_name", table: "Common"), pointRecord.deviceName)
            )
            .symbol(.circle)
          }
        }
      }
    }
    .chartForegroundStyleScale(
      domain: allDeviceNames,
      range: ChartAxisHelper.stableDeviceColors(for: allDeviceNames)
    )
    .chartYScale(domain: 68...107)
    .chartXAxis {
      let (strideComponent, strideCount, labelFormat) =
        ChartAxisHelper.calculateXAxisStride(
          startDay: startDay, endDay: endDay, isCompact: horizontalSizeClass == .compact)

      AxisMarks(values: .stride(by: strideComponent, count: strideCount)) { value in
        AxisGridLine()
          .foregroundStyle(.white.opacity(0.95))

        AxisValueLabel {
          if let date = value.as(Date.self) {
            switch labelFormat {
            case .monthDay:
              Text(date.formatted(.dateTime.month(.defaultDigits).day()))
            case .monthOnly:
              Text(date.formatted(.dateTime.month(.defaultDigits)))
            case .yearOnly:
              Text(date.formatted(.dateTime.year()))
            }
          }
        }
      }
    }
    .chartXScale(
      domain: {
        let cal = Calendar.current
        let days = cal.dateComponents([.day], from: startDay, to: endDay).day ?? 0
        if days < 7 {
          return startDay...(cal.date(byAdding: .day, value: 7, to: startDay) ?? endDay)
        }
        return startDay...endDay
      }()
    )
    .chartYAxis {
      AxisMarks(values: [70, 80, 90, 100]) { value in
        AxisGridLine()
        AxisValueLabel {
          if let intValue = value.as(Int.self) {
            Text("\(intValue)%")
          }
        }
      }
    }
    .chartPlotStyle { plotArea in
      plotArea
        .clipped()
        .padding(.trailing, 24)
    }
    .drawingGroup()
    .frame(height: horizontalSizeClass == .regular ? 280 : 200)
  }
}

#Preview {
  HealthTrendView(
    visibleRecords: [],
    startDay: Date(),
    endDay: Date(),
    unit: .day,
    selectedRange: .constant(.oneMonth),
    canMoveNext: false,
    canMovePrevious: false,
    shiftWindow: { _ in },
    allDeviceNames: []
  )
}
