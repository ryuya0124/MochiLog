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
      Text(String(localized: "health_trend"))
        .font(.headline)

      if visibleRecords.isEmpty {
        Text(String(localized: "no_records_for_device"))
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .center)
          .padding()
      } else {
        // チャートコントロール：範囲のみ（表示単位は親が決定）
        if horizontalSizeClass == .compact {
          HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
              Text(String(localized: "chart_range"))
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
                .accessibilityLabel(Text(String(localized: "chart_range")))

                Button {
                  shiftWindow(false)
                } label: {
                  Image(systemName: "chevron.right")
                }
                .disabled(!canMoveNext)
              }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
          }
        } else {
          HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
              Text(String(localized: "chart_range"))
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
                .accessibilityLabel(Text(String(localized: "chart_range")))

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
                String(localized: "date"), Calendar.current.startOfDay(for: record.logDate),
                unit: unit.calendarComponent),
              y: .value(
                String(localized: "real_capacity"),
                appSettings.analysisDataSource == .nominal
                  ? record.nominalHealthPercent : record.healthPercent)
            )
            .foregroundStyle(by: .value(String(localized: "device_name"), record.deviceName))
            .interpolationMethod(.catmullRom)
            .opacity(animateChart ? 1 : 0)

            if showPoints {
              PointMark(
                x: .value(
                  String(localized: "date"), Calendar.current.startOfDay(for: record.logDate),
                  unit: unit.calendarComponent),
                y: .value(
                  String(localized: "real_capacity"),
                  appSettings.analysisDataSource == .nominal
                    ? record.nominalHealthPercent : record.healthPercent)
              )
              .foregroundStyle(by: .value(String(localized: "device_name"), record.deviceName))
              .symbol(.circle)
              .opacity(animateChart ? 1 : 0)
            }
          }

        }
        .chartYScale(domain: 70...105)
        .chartXAxis {
          // 期間に応じてラベル間隔を調整
          let strideCount: Int = {
            switch unit {
            case .hour, .day:
              return 1
            case .week:
              return 1
            case .month:
              // 6ヶ月以上の場合は3ヶ月ごとにラベル表示
              let months =
                Calendar.current.dateComponents([.month], from: startDay, to: endDay).month ?? 0
              return months > 12 ? 6 : (months > 6 ? 3 : 1)
            }
          }()

          AxisMarks(values: .stride(by: unit.calendarComponent, count: strideCount)) { value in
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
                  // 長期間の場合は年と月を短く表示
                  let months =
                    Calendar.current.dateComponents([.month], from: startDay, to: endDay).month ?? 0
                  if months > 12 {
                    Text(date.formatted(.dateTime.year(.twoDigits).month(.abbreviated)))
                      .font(.caption2)
                  } else {
                    Text(date.formatted(.dateTime.year(.twoDigits).month(.defaultDigits)))
                  }
                }
              }
            }
          }
        }
        .chartXScale(domain: startDay...endDay)
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
            .mask {
              GeometryReader { geo in
                Rectangle()
                  .frame(height: animateChart ? geo.size.height : 0, alignment: .bottom)
                  .frame(maxHeight: .infinity, alignment: .bottom)
                  .animation(.easeOut(duration: 0.6), value: animateChart)
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
