import Charts
import SwiftUI

struct CycleTrendView: View {
  let allRecords: [BatteryRecord]  // フィルタ前の全レコード（期間計算用）
  let unit: AppSettings.ChartUnit
  @Binding var animateChart: Bool
  var initialRange: RangePreset = .oneMonth  // 初期レンジ（サンプルモード用）

  // iPad用：独自の期間設定
  @State private var selectedRange: RangePreset = .oneMonth
  @State private var windowEnd: Date = Date()
  @State private var hasInitialized: Bool = false

  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  // 現在のウィンドウに含まれるレコードを計算
  private var visibleRecords: [BatteryRecord] {
    let calendar = Calendar.current
    let startDate = windowStart(for: windowEnd, range: selectedRange)
    let startDay = calendar.startOfDay(for: startDate)
    let endDay = calendar.startOfDay(for: windowEnd)
    return allRecords.filter {
      let d = calendar.startOfDay(for: $0.logDate)
      return d >= startDay && d <= endDay
    }
  }

  private var startDay: Date {
    Calendar.current.startOfDay(for: windowStart(for: windowEnd, range: selectedRange))
  }

  private var endDay: Date {
    Calendar.current.startOfDay(for: windowEnd)
  }

  // ウィンドウ計算ヘルパー
  private func windowStart(for endDate: Date, range: RangePreset) -> Date {
    ChartWindowNavigator.windowStart(for: endDate, range: range, allRecords: allRecords)
  }

  private var canMoveNext: Bool {
    ChartWindowNavigator.canMoveNext(
      currentEnd: windowEnd, range: selectedRange, records: allRecords)
  }

  private var canMovePrevious: Bool {
    ChartWindowNavigator.canMovePrevious(
      currentEnd: windowEnd, range: selectedRange, records: allRecords)
  }

  private func shiftWindow(backward: Bool) {
    windowEnd = ChartWindowNavigator.shiftWindow(
      currentEnd: windowEnd,
      backward: backward,
      range: selectedRange,
      records: allRecords
    )
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(String(localized: "cycle_trend", table: "Analytics"))
        .font(.headline)

      if allRecords.isEmpty {
        Text(String(localized: "no_records_for_device", table: "Analytics"))
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .center)
          .padding()
      } else {
        // iPad向け期間セレクター
        if horizontalSizeClass == .regular {
          HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
              Text(String(localized: "chart_range", table: "Analytics"))
                .font(.caption)
                .foregroundStyle(.secondary)
              HStack(spacing: 12) {
                Button {
                  shiftWindow(backward: true)
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
                  shiftWindow(backward: false)
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

        // データ点が多い場合はPointMarkを非表示
        let showPoints = visibleRecords.count <= 15

        Chart {
          ForEach(visibleRecords) { record in
            LineMark(
              x: .value(
                String(localized: "date", table: "Common"),
                Calendar.current.startOfDay(for: record.logDate),
                unit: unit.calendarComponent),
              y: .value(String(localized: "cycle_count", table: "Analytics"), record.cycleCount)
            )
            .foregroundStyle(
              by: .value(String(localized: "device_name", table: "Common"), record.deviceName)
            )
            .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            .opacity(animateChart ? 1 : 0)

            if showPoints {
              PointMark(
                x: .value(
                  String(localized: "date", table: "Common"),
                  Calendar.current.startOfDay(for: record.logDate),
                  unit: unit.calendarComponent),
                y: .value(String(localized: "cycle_count", table: "Analytics"), record.cycleCount)
              )
              .foregroundStyle(
                by: .value(String(localized: "device_name", table: "Common"), record.deviceName)
              )
              .symbol(.circle)
              .symbolSize(40)
              .opacity(animateChart ? 1 : 0)
            }
          }
        }
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
        // Y軸ドメインを設定（最大値に余白を追加してポイントが見切れないように）
        .chartYScale(domain: 0...(Double(visibleRecords.map { $0.cycleCount }.max() ?? 10) * 1.15))
        // X軸ドメインを設定（期間に応じて右側に余白を追加）
        .chartXScale(
          domain: {
            let days = Calendar.current.dateComponents([.day], from: startDay, to: endDay).day ?? 0
            if days < 7 {
              // 最低1週間分の幅を確保
              return
                startDay...(Calendar.current.date(byAdding: .day, value: 7, to: startDay) ?? endDay)
            }

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
        .chartPlotStyle { plotArea in
          plotArea
            .padding(.trailing, 24)  // グラフ右端とY軸ラベルの間に余白
            .mask {
              GeometryReader { geo in
                Rectangle()
                  .frame(width: animateChart ? geo.size.width : 0)
                  .frame(maxWidth: .infinity, alignment: .leading)
                  .animation(.easeOut(duration: 0.6), value: animateChart)
              }
            }
        }
        .frame(height: horizontalSizeClass == .regular ? 280 : 200)
      }
    }
    .frame(height: horizontalSizeClass == .regular ? 480 : nil, alignment: .top)
    .padding()
    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    .onAppear {
      // 初期レンジを設定（一度だけ）
      if !hasInitialized {
        selectedRange = initialRange
        windowEnd = ChartWindowNavigator.initializeWindowEnd(for: allRecords, range: initialRange)
        hasInitialized = true
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

#Preview {
  CycleTrendView(
    allRecords: [],
    unit: .day,
    animateChart: .constant(true)
  )
}
