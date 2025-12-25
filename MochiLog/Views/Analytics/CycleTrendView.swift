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
        Chart {
          ForEach(visibleRecords) { record in
            LineMark(
              x: .value(String(localized: "date"), Calendar.current.startOfDay(for: record.logDate), unit: unit.calendarComponent),
              y: .value(String(localized: "cycle_count"), record.cycleCount)
            )
            .foregroundStyle(by: .value(String(localized: "device_name"), record.deviceName))
            .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            .opacity(animateChart ? 1 : 0)

            PointMark(
              x: .value(String(localized: "date"), Calendar.current.startOfDay(for: record.logDate), unit: unit.calendarComponent),
              y: .value(String(localized: "cycle_count"), record.cycleCount)
            )
            .foregroundStyle(by: .value(String(localized: "device_name"), record.deviceName))
            .symbol(.circle)
            .symbolSize(40)
            .opacity(animateChart ? 1 : 0)
          }
        }
        .chartXAxis {
          AxisMarks(values: .stride(by: unit.calendarComponent, count: 1)) { value in
            AxisGridLine()
              .foregroundStyle(.white.opacity(0.95))

            AxisValueLabel {
              if let date = value.as(Date.self) {
                switch unit {
                case .hour, .day:
                  Text(date.formatted(.dateTime.month(.defaultDigits).day()))
                case .week:
                  Text(date.formatted(.dateTime.month(.defaultDigits).day()))
                case .month:
                  Text(date.formatted(.dateTime.year().month()))
                }
              }
            }
          }
        }
        .chartXScale(domain: startDay...endDay)
        .chartPlotStyle { plotArea in
          plotArea
            .mask {
              GeometryReader { geo in
                Rectangle()
                  .frame(height: animateChart ? geo.size.height : 0, alignment: .bottom)
                  .frame(maxHeight: .infinity, alignment: .bottom)
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
