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
            .opacity(animateChart ? 1 : 0)
          }

          // PointMarkはさらに間引く（デバイスごとに均等に間引く）
          if !chartRecords.isEmpty {
            // デバイスごとにグループ化
            let deviceGroups = Dictionary(grouping: chartRecords) { $0.deviceName }

            ForEach(Array(deviceGroups.keys.sorted()), id: \.self) { deviceName in
              let deviceRecords = deviceGroups[deviceName] ?? []
              let thinningFactor = max(1, deviceRecords.count / 15)  // デバイスごとに最大15件

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
                .opacity(animateChart ? 1 : 0)
              }
            }
          }
        }
        .chartForegroundStyleScale(
          domain: allDeviceNames,
          range: ChartAxisHelper.stableDeviceColors(for: allDeviceNames)
        )
        .chartYScale(domain: 68...107)  // 上下に余白を確保
        .chartXAxis {
          // 共通の横軸ラベル間引き関数を使用
          let axisStart = CFAbsoluteTimeGetCurrent()
          let (strideComponent, strideCount, labelFormat) =
            ChartAxisHelper.calculateXAxisStride(
              startDay: startDay, endDay: endDay, isCompact: horizontalSizeClass == .compact)
          let axisElapsed = (CFAbsoluteTimeGetCurrent() - axisStart) * 1000
          let _ = print(
            "[Performance] HealthTrendView.axisCalc: \(String(format: "%.2f", axisElapsed))ms")

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
        // X軸ドメインを設定（選択レンジに固定、コンテキストレコードからの補間線はドメイン通過部分のみ描画）
        .chartXScale(
          domain: {
            let cal = Calendar.current
            let days = cal.dateComponents([.day], from: startDay, to: endDay).day ?? 0
            if days < 7 {
              // 最低1週間分の幅を確保
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
            .clipped()  // まずプロット領域の境界でクリップ
            .padding(.trailing, 24)  // その後パディングを追加
            .mask {
              GeometryReader { geo in
                Rectangle()
                  .frame(width: animateChart ? geo.size.width : 0)
                  .frame(maxWidth: .infinity, alignment: .leading)
              }
            }
        }
        .frame(height: horizontalSizeClass == .regular ? 280 : 200)
        .onAppear {
          let elapsed = (CFAbsoluteTimeGetCurrent() - bodyStartTime) * 1000
          print("[Performance] HealthTrendView.body構築完了: \(String(format: "%.2f", elapsed))ms")

          // 初回表示時はアニメーションなしで即座に表示（高速化）
          animateChart = true
        }
        .onChange(of: selectedRange) {
          // レンジ変更時のみアニメーション実行
          animateChart = false
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
            withAnimation(.easeOut(duration: 0.4)) {
              animateChart = true
            }
          }
        }
      }
    }
    .frame(height: horizontalSizeClass == .regular ? 480 : nil, alignment: .top)
    .padding()
    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    .onReceive(appSettings.$analysisDataSource.removeDuplicates()) { newValue in
      if analysisDataSource != newValue {
        analysisDataSource = newValue
      }
    }
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
