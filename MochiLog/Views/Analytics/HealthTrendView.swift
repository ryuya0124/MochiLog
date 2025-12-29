import Charts
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
  @Binding var animateChart: Bool

  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @StateObject private var appSettings = AppSettings.shared

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(
        String(
          localized: appSettings.analysisDataSource == .nominal
            ? "health_trend_nominal" : "health_trend_actual",
          table: "Analytics")
      )
      .font(.headline)

      if visibleRecords.isEmpty {
        Text(String(localized: "no_records_for_device", table: "Analytics"))
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .center)
          .padding()
      } else {
        // チャートコントロール：範囲のみ（表示単位は親が決定）
        if horizontalSizeClass == .compact {
          HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
              Text(String(localized: "chart_range", table: "Analytics"))
                .font(.caption)
                .foregroundStyle(.secondary)
              HStack(spacing: 8) {
                Button {
                  shiftWindow(true)
                } label: {
                  Image(systemName: "chevron.left")
                }
                .disabled(!canMovePrevious)

                Picker("", selection: $selectedRange) {
                  ForEach(RangePreset.allCases) { preset in
                    Text(preset.localizedName).tag(preset)
                  }
                }
                .pickerStyle(.menu)
                .accessibilityLabel(Text(String(localized: "chart_range", table: "Analytics")))

                Button {
                  shiftWindow(false)
                } label: {
                  Image(systemName: "chevron.right")
                }
                .disabled(!canMoveNext)

                // 年を表示（2年以上の場合はレンジ表示）
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
            .frame(maxWidth: .infinity, alignment: .leading)
          }
        } else {
          HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
              Text(String(localized: "chart_range", table: "Analytics"))
                .font(.caption)
                .foregroundStyle(.secondary)
              HStack(spacing: 12) {
                Button {
                  shiftWindow(true)
                } label: {
                  Image(systemName: "chevron.left")
                }
                .disabled(selectedRange == .all || !canMovePrevious)

                Picker("", selection: $selectedRange) {
                  ForEach(RangePreset.allCases) { preset in
                    Text(preset.localizedName).tag(preset)
                  }
                }
                .pickerStyle(.segmented)
                .accessibilityLabel(Text(String(localized: "chart_range", table: "Analytics")))

                Button {
                  shiftWindow(false)
                } label: {
                  Image(systemName: "chevron.right")
                }
                .disabled(!canMoveNext)
              }

              HStack {
                Text(startDay.formatted(.dateTime.month().day()))
                  .font(.caption2)
                  .foregroundStyle(.secondary)
                Text("–")
                  .font(.caption2)
                  .foregroundStyle(.secondary)
                Text(endDay.formatted(.dateTime.month().day()))
                  .font(.caption2)
                  .foregroundStyle(.secondary)
              }
            }
          }
        }

        // データ点が多い場合はPointMarkを非表示（すっきり見せる）
        let showPoints = visibleRecords.count <= 15

        Chart {
          ForEach(visibleRecords) { record in
            LineMark(
              x: .value(
                String(localized: "date", table: "Common"),
                Calendar.current.startOfDay(for: record.logDate),
                unit: unit.calendarComponent),
              y: .value(
                String(localized: "real_capacity", table: "Analytics"),
                appSettings.analysisDataSource == .nominal
                  ? record.nominalHealthPercent : record.healthPercent)
            )
            .foregroundStyle(
              by: .value(String(localized: "device_name", table: "Common"), record.deviceName)
            )
            .interpolationMethod(.catmullRom)
            .opacity(animateChart ? 1 : 0)

            if showPoints {
              PointMark(
                x: .value(
                  String(localized: "date", table: "Common"),
                  Calendar.current.startOfDay(for: record.logDate),
                  unit: unit.calendarComponent),
                y: .value(
                  String(localized: "real_capacity", table: "Analytics"),
                  appSettings.analysisDataSource == .nominal
                    ? record.nominalHealthPercent : record.healthPercent)
              )
              .foregroundStyle(
                by: .value(String(localized: "device_name", table: "Common"), record.deviceName)
              )
              .symbol(.circle)
              .opacity(animateChart ? 1 : 0)
            }
          }

        }
        .chartYScale(domain: 68...107)  // 上下に余白を確保
        .chartXAxis {
          // 表示期間の日数に基づいてグリッド線の間隔を計算
          let displayDays =
            Calendar.current.dateComponents([.day], from: startDay, to: endDay).day ?? 0
          let displayMonths =
            Calendar.current.dateComponents([.month], from: startDay, to: endDay).month ?? 0

          // 表示期間に応じて適切な単位とストライドを決定
          let (strideComponent, strideCount): (Calendar.Component, Int) = {
            if displayDays <= 14 {
              // 2週間以下: 日単位、1日ごと
              return (.day, 1)
            } else if displayDays <= 60 {
              // 2ヶ月以下: 週単位、1週間ごと
              return (.weekOfYear, 1)
            } else if displayMonths <= 3 {
              // 3ヶ月以下: 週単位、2週間ごと
              return (.weekOfYear, 2)
            } else if displayMonths <= 6 {
              // 6ヶ月以下: 月単位、1ヶ月ごと
              return (.month, 1)
            } else if displayMonths <= 12 {
              // 1年以下: 月単位、3ヶ月ごと
              return (.month, 3)
            } else {
              // 1年超: 月単位、6ヶ月ごと
              return (.month, 6)
            }
          }()

          AxisMarks(values: .stride(by: strideComponent, count: strideCount)) { value in
            AxisGridLine()
              .foregroundStyle(.white.opacity(0.95))

            AxisValueLabel {
              if let date = value.as(Date.self) {
                if displayMonths > 6 {
                  // 6ヶ月超: 月のみ表示（年は期間セレクターの横に表示）
                  Text(date.formatted(.dateTime.month(.defaultDigits)))
                } else {
                  // 6ヶ月以下: 月/日形式
                  Text(date.formatted(.dateTime.month(.defaultDigits).day()))
                }
              }
            }
          }
        }
        // X軸ドメインを設定（期間に応じて右側に余白を追加）
        .chartXScale(
          domain: {
            let months =
              Calendar.current.dateComponents([.month], from: startDay, to: endDay).month ?? 0
            let years = months / 12
            if years >= 1 {
              // 年数に応じて余白を追加（1年=1ヶ月、2年=2ヶ月...）
              return
                startDay...(Calendar.current.date(byAdding: .month, value: years, to: endDay)
                ?? endDay)
            } else if months >= 6 {
              // 6ヶ月: 14日の余白
              return
                startDay...(Calendar.current.date(byAdding: .day, value: 14, to: endDay) ?? endDay)
            } else if months >= 3 {
              // 3ヶ月: 7日の余白
              return
                startDay...(Calendar.current.date(byAdding: .day, value: 7, to: endDay) ?? endDay)
            } else {
              // 3ヶ月未満: 余白なし
              return startDay...endDay
            }
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
            .padding(.trailing, 24)  // グラフ右端とY軸ラベルの間に余白
            .mask {
              GeometryReader { geo in
                Rectangle()
                  .frame(width: animateChart ? geo.size.width : 0)
                  .frame(maxWidth: .infinity, alignment: .leading)
              }
            }
        }
        .frame(height: 220)
        .onAppear {
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(.easeOut(duration: 0.6)) { animateChart = true }
          }
        }
        .onChange(of: selectedRange) {
          animateChart = false
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
            withAnimation(.easeOut(duration: 0.5)) { animateChart = true }
          }
        }

      }
    }
    .padding()
    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
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
    animateChart: .constant(true)
  )
}
