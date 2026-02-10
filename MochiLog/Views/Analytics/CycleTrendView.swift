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

  // iPhone用：windowEndの実値（SwiftUIのdiff検知用、Binding経由だと再描画がトリガーされない）
  var sharedWindowEndValue: Date?

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
    sharedWindowEndValue ?? localWindowEnd
  }

  // 現在のウィンドウに含まれるレコードを計算
  private var visibleRecords: [BatteryRecord] {
    let startDate = windowStart(for: effectiveEndDate, range: effectiveSelectedRange)
    return ChartWindowNavigator.visibleRecordsWithContext(
      in: allRecords,
      start: startDate,
      end: effectiveEndDate
    )
  }

  private var startDay: Date {
    Calendar.current.startOfDay(
      for: windowStart(for: effectiveEndDate, range: effectiveSelectedRange))
  }

  private var endDay: Date {
    Calendar.current.startOfDay(for: effectiveEndDate)
  }

  /// 全レコードのデバイス名（ソート済み）— 色の安定割り当て用
  private var sortedAllDeviceNames: [String] {
    Array(Set(allRecords.map { $0.deviceName })).sorted()
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
    // sharedSelectedRange がある場合は親の値を使う（iPhone 連動用）
    let rangeToUse = sharedSelectedRange != nil ? selectedRange : localSelectedRange
    guard rangeToUse == .auto else { return rangeToUse }
    let now = Date()
    let pastRecords = allRecords.filter { $0.logDate <= now }
    let sourceRecords = pastRecords.isEmpty ? allRecords : pastRecords
    return ChartWindowNavigator.autoRange(for: sourceRecords)
  }

  private var effectiveLocalWindowEnd: Date {
    // sharedWindowEndValue がある場合は親の値を使う（iPhone 連動用）
    let rangeToUse = sharedSelectedRange != nil ? selectedRange : localSelectedRange
    let windowEndToUse = sharedWindowEndValue ?? localWindowEnd
    guard rangeToUse == .auto else { return windowEndToUse }
    let now = Date()
    if windowEndToUse <= now { return windowEndToUse }
    let pastRecords = allRecords.filter { $0.logDate <= now }
    if let latestPast = pastRecords.max(by: { $0.logDate < $1.logDate })?.logDate {
      return latestPast
    }
    return min(windowEndToUse, now)
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
    let bodyStartTime = CFAbsoluteTimeGetCurrent()
    let _ = print(
      "[Performance] CycleTrendView.body構築開始 - allRecords: \(allRecords.count)件, visible: \(visibleRecords.count)件"
    )

    return VStack(alignment: .leading, spacing: 12) {
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
          ChartRangeSelector(
            selectedRange: Binding(
              get: { localSelectedRange },
              set: {
                isUserInteracted = true
                localSelectedRange = $0
              }
            ),
            canMoveNext: canMoveNext,
            canMovePrevious: canMovePrevious,
            shiftWindow: { backward in
              isUserInteracted = true
              shiftWindow(backward: backward)
            },
            startDay: startDay,
            endDay: endDay
          )
        }

        // データ点は期間に応じて間引き
        let downsampleStart = CFAbsoluteTimeGetCurrent()
        let pointRecords = ChartAxisHelper.downsampledRecords(
          visibleRecords, startDay: startDay, endDay: endDay)
        let downsampleElapsed = (CFAbsoluteTimeGetCurrent() - downsampleStart) * 1000
        let _ = print(
          "[Performance] CycleTrendView.downsample: \(String(format: "%.2f", downsampleElapsed))ms (\(visibleRecords.count) -> \(pointRecords.count)件)"
        )

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
          }

          // PointMarkはさらに間引く（デバイスごとに均等に間引く）
          if !pointRecords.isEmpty {
            // デバイスごとにグループ化
            let deviceGroups = Dictionary(grouping: pointRecords) { $0.deviceName }

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
        .chartForegroundStyleScale(
          domain: sortedAllDeviceNames,
          range: ChartAxisHelper.stableDeviceColors(for: sortedAllDeviceNames)
        )
        .chartXAxis {
          // 共通の横軸ラベル間引き関数を使用
          let axisStart = CFAbsoluteTimeGetCurrent()
          let (strideComponent, strideCount, labelFormat) =
            ChartAxisHelper.calculateXAxisStride(
              startDay: startDay, endDay: endDay, isCompact: horizontalSizeClass == .compact)
          let axisElapsed = (CFAbsoluteTimeGetCurrent() - axisStart) * 1000
          let _ = print(
            "[Performance] CycleTrendView.axisCalc: \(String(format: "%.2f", axisElapsed))ms")

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
      let elapsed = (CFAbsoluteTimeGetCurrent() - bodyStartTime) * 1000
      print("[Performance] CycleTrendView.body構築完了: \(String(format: "%.2f", elapsed))ms")

      // 初期レンジを設定（一度だけ、親から渡されていない場合のみ）
      if !hasInitialized && sharedSelectedRange == nil {
        localSelectedRange = initialRange
        localWindowEnd = ChartWindowNavigator.initializeWindowEnd(
          for: allRecords, range: initialRange)
        hasInitialized = true
      }
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
    .onChange(of: windowEnd) {
      // iPhone での連動：親の windowEnd が変わったらアニメーション実行
      // （戻る・進むボタンで期間移動した時）
      if sharedWindowEnd != nil {
        animateChart = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
          withAnimation(.easeOut(duration: 0.4)) {
            animateChart = true
          }
        }
      }
    }
    .onChange(of: initialRange) {
      // iPad独立モードで、ユーザー操作がまだない場合は initialRange の変更に追従
      // （サンプルモード開始時などに外部から3年レンジを設定できるようにする）
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
