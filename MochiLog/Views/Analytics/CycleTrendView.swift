import Charts
import SwiftUI

struct CycleTrendView: View {
  let allRecords: [BatteryRecord]  // フィルタ前の全レコード（期間計算用）
  let unit: AppSettings.ChartUnit
  @State private var animateChart: Bool = false
  var initialRange: RangePreset = .oneMonth  // 初期レンジ（サンプルモード用）

  // iPhone用：親から渡される期間情報（Bindingがある場合は親と同期）
  var sharedSelectedRange: Binding<RangePreset>?
  var sharedWindowEnd: Binding<Date>?
  var sharedCanMoveNext: Bool?
  var sharedCanMovePrevious: Bool?
  var sharedShiftWindow: ((Bool) -> Void)?

  // iPad用：独自の期間設定
  @State private var localSelectedRange: RangePreset = .oneMonth
  @State private var localWindowEnd: Date = Date()
  @State private var hasInitialized: Bool = false
  @State private var isUserInteracted: Bool = false

  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  // 使用する期間設定（親から渡されていれば親の値、なければローカル）
  private var selectedRange: RangePreset {
    sharedSelectedRange?.wrappedValue ?? localSelectedRange
  }

  private var windowEnd: Date {
    sharedWindowEnd?.wrappedValue ?? localWindowEnd
  }

  // 現在のウィンドウに含まれるレコードを計算
  private var visibleRecords: [BatteryRecord] {
    let calendar = Calendar.current
    let startDate = windowStart(for: effectiveEndDate, range: effectiveSelectedRange)
    let startDay = calendar.startOfDay(for: startDate)
    let endDay = calendar.startOfDay(for: effectiveEndDate)
    return allRecords.filter {
      let d = calendar.startOfDay(for: $0.logDate)
      return d >= startDay && d <= endDay
    }
  }

  private var startDay: Date {
    Calendar.current.startOfDay(
      for: windowStart(for: effectiveEndDate, range: effectiveSelectedRange))
  }

  private var endDay: Date {
    Calendar.current.startOfDay(for: effectiveEndDate)
  }

  // ウィンドウ計算ヘルパー
  private func windowStart(for endDate: Date, range: RangePreset) -> Date {
    ChartWindowNavigator.windowStart(for: endDate, range: range, allRecords: allRecords)
  }

  private var canMoveNext: Bool {
    sharedCanMoveNext
      ?? ChartWindowNavigator.canMoveNext(
        currentEnd: effectiveLocalWindowEnd, range: effectiveLocalRange, records: allRecords)
  }

  private var canMovePrevious: Bool {
    sharedCanMovePrevious
      ?? ChartWindowNavigator.canMovePrevious(
        currentEnd: effectiveLocalWindowEnd, range: effectiveLocalRange, records: allRecords)
  }

  private var effectiveLocalRange: RangePreset {
    guard localSelectedRange == .auto else { return localSelectedRange }
    let now = Date()
    let pastRecords = allRecords.filter { $0.logDate <= now }
    let sourceRecords = pastRecords.isEmpty ? allRecords : pastRecords
    return ChartWindowNavigator.autoRange(for: sourceRecords)
  }

  private var effectiveLocalWindowEnd: Date {
    guard localSelectedRange == .auto else { return localWindowEnd }
    let now = Date()
    if localWindowEnd <= now { return localWindowEnd }
    let pastRecords = allRecords.filter { $0.logDate <= now }
    if let latestPast = pastRecords.max(by: { $0.logDate < $1.logDate })?.logDate {
      return latestPast
    }
    return min(localWindowEnd, now)
  }

  private var effectiveSelectedRange: RangePreset {
    guard selectedRange == .auto else { return selectedRange }
    let now = Date()
    let pastRecords = allRecords.filter { $0.logDate <= now }
    let sourceRecords = pastRecords.isEmpty ? allRecords : pastRecords
    return ChartWindowNavigator.autoRange(for: sourceRecords)
  }

  private var effectiveEndDate: Date {
    guard selectedRange == .auto else { return windowEnd }
    let now = Date()
    if windowEnd <= now { return windowEnd }
    let pastRecords = allRecords.filter { $0.logDate <= now }
    if let latestPast = pastRecords.max(by: { $0.logDate < $1.logDate })?.logDate {
      return latestPast
    }
    return min(windowEnd, now)
  }

  private func shiftWindow(backward: Bool) {
    if let sharedShift = sharedShiftWindow {
      sharedShift(backward)
    } else {
      localWindowEnd = ChartWindowNavigator.shiftWindow(
        currentEnd: effectiveLocalWindowEnd,
        backward: backward,
        range: effectiveLocalRange,
        records: allRecords
      )
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .firstTextBaseline) {
        Text(String(localized: "cycle_trend", table: "Analytics"))
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
                  isUserInteracted = true
                  shiftWindow(backward: true)
                } label: {
                  Image(systemName: "chevron.left")
                }
                .disabled(!canMovePrevious)

                Picker(
                  "",
                  selection: Binding(
                    get: { localSelectedRange },
                    set: {
                      isUserInteracted = true
                      localSelectedRange = $0
                    }
                  )
                ) {
                  ForEach(RangePreset.manualCases) { preset in
                    Text(preset.localizedName).tag(preset)
                  }
                }
                .pickerStyle(.segmented)
                .accessibilityLabel(Text(String(localized: "chart_range", table: "Analytics")))

                Button {
                  isUserInteracted = true
                  shiftWindow(backward: false)
                } label: {
                  Image(systemName: "chevron.right")
                }
                .disabled(!canMoveNext)
              }
            }
          }
        }

        // データ点は期間に応じて間引き
        let pointRecords = ChartAxisHelper.downsampledRecords(
          visibleRecords, startDay: startDay, endDay: endDay)

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
            .interpolationMethod(.catmullRom)
            .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            .opacity(animateChart ? 1 : 0)

            if !pointRecords.isEmpty {
              ForEach(pointRecords) { pointRecord in
                PointMark(
                  x: .value(
                    String(localized: "date", table: "Common"),
                    Calendar.current.startOfDay(for: pointRecord.logDate),
                    unit: unit.calendarComponent),
                  y: .value(
                    String(localized: "cycle_count", table: "Analytics"),
                    pointRecord.cycleCount)
                )
                .foregroundStyle(
                  by: .value(
                    String(localized: "device_name", table: "Common"), pointRecord.deviceName)
                )
                .symbol(.circle)
                .symbolSize(40)
                .opacity(animateChart ? 1 : 0)
              }
            }
          }
        }
        .chartXAxis {
          // 共通の横軸ラベル間引き関数を使用
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
        // Y軸ドメインを設定（最大値に余白を追加してポイントが見切れないように）
        .chartYScale(domain: 0...(Double(visibleRecords.map { $0.cycleCount }.max() ?? 10) * 1.15))
        // X軸ドメインを設定（データ範囲ぴったりに表示）
        .chartXScale(
          domain: {
            let days = Calendar.current.dateComponents([.day], from: startDay, to: endDay).day ?? 0
            if days < 7 {
              // 最低1週間分の幅を確保
              return
                startDay...(Calendar.current.date(byAdding: .day, value: 7, to: startDay) ?? endDay)
            }
            // カレンダー境界に合わせて表示
            return startDay...endDay
          }()
        )
        .chartPlotStyle { plotArea in
          plotArea
            .clipped()  // まずプロット領域の境界でクリップ
            .padding(.trailing, 24)  // その後パディングを追加
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
      // 初期レンジを設定（一度だけ、親から渡されていない場合のみ）
      if !hasInitialized && sharedSelectedRange == nil {
        localSelectedRange = initialRange
        localWindowEnd = ChartWindowNavigator.initializeWindowEnd(
          for: allRecords, range: initialRange)
        hasInitialized = true
      }
      // アニメーション開始
      animateChart = false
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        withAnimation(.easeOut(duration: 0.6)) {
          animateChart = true
        }
      }
    }
    .onChange(of: selectedRange) {
      animateChart = false
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
        withAnimation(.easeOut(duration: 0.5)) { animateChart = true }
      }
    }
    .onChange(of: initialRange) {
      if !isUserInteracted && sharedSelectedRange == nil {
        localSelectedRange = initialRange
        localWindowEnd = ChartWindowNavigator.initializeWindowEnd(
          for: allRecords, range: initialRange)
      }
    }
  }
}

#Preview {
  CycleTrendView(
    allRecords: [],
    unit: .day
  )
}
