import Charts
import SwiftUI

struct CycleTrendView: View {
  let visibleRecords: [BatteryRecord]
  let startDay: Date
  let endDay: Date
  let unit: AppSettings.ChartUnit
  @Binding var animateChart: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(String(localized: "cycle_trend"))
        .font(.headline)

      if visibleRecords.isEmpty {
        Text(String(localized: "no_records_for_device"))
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .center)
          .padding()
      } else {
        // データ点が多い場合はPointMarkを非表示
        let showPoints = visibleRecords.count <= 15

        Chart {
          ForEach(visibleRecords) { record in
            LineMark(
              x: .value(
                String(localized: "date"), Calendar.current.startOfDay(for: record.logDate),
                unit: unit.calendarComponent),
              y: .value(String(localized: "cycle_count"), record.cycleCount)
            )
            .foregroundStyle(by: .value(String(localized: "device_name"), record.deviceName))
            .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            .opacity(animateChart ? 1 : 0)

            if showPoints {
              PointMark(
                x: .value(
                  String(localized: "date"), Calendar.current.startOfDay(for: record.logDate),
                  unit: unit.calendarComponent),
                y: .value(String(localized: "cycle_count"), record.cycleCount)
              )
              .foregroundStyle(by: .value(String(localized: "device_name"), record.deviceName))
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
        .frame(height: 180)
      }
    }
    .padding()
    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
  }
}

#Preview {
  CycleTrendView(
    visibleRecords: [],
    startDay: Date(),
    endDay: Date(),
    unit: .day,
    animateChart: .constant(true)
  )
}
