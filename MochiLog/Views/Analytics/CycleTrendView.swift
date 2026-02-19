import Charts
import SwiftUI

struct CycleTrendView: View {
  let allRecords: [BatteryRecord]  // フィルタ前の全レコード（期間計算用）
  let unit: AppSettings.ChartUnit
  @State private var animateChart: Bool = false
  @State private var isChartReady: Bool = false  // 遅延レンダリング用
  var initialRange: RangePreset = .oneMonth  // 初期レンジ（サンプルモード用）
  var allDeviceNames: [String]?  // 全デバイス名（色固定用、nilの場合はallRecordsから計算）

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
    allDeviceNames ?? Array(Set(allRecords.map { $0.deviceName })).sorted()
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

        // 描画用データは期間に応じて間引き（負荷軽減）
        let downsampleStart = CFAbsoluteTimeGetCurrent()
        let chartRecords = ChartAxisHelper.downsampledRecords(
          visibleRecords, startDay: startDay, endDay: endDay)
        let downsampleElapsed = (CFAbsoluteTimeGetCurrent() - downsampleStart) * 1000
        let _ = print(
          "[Performance] CycleTrendView.downsample: \(String(format: "%.2f", downsampleElapsed))ms (\(visibleRecords.count) -> \(chartRecords.count)件)"
        )

        // 遅延レンダリング: タブ切り替え時はプレースホルダーを表示し、次フレームでChart描画
        if isChartReady {
          // 表示されているデバイス名とその色のマッピングを計算
          let visibleDeviceNames = Array(Set(chartRecords.map { $0.deviceName })).sorted()
          let visibleDeviceColors = visibleDeviceNames.map { deviceName -> Color in
            if let index = sortedAllDeviceNames.firstIndex(of: deviceName) {
              return ChartAxisHelper.deviceColorPalette[
                index % ChartAxisHelper.deviceColorPalette.count]
            }
            // フォールバック: sortedAllDeviceNamesにない場合はデバイス名のハッシュから色を選択
            print(
              "[Warning] Device '\(deviceName)' not found in sortedAllDeviceNames, using fallback color"
            )
            let fallbackIndex = abs(deviceName.hashValue) % ChartAxisHelper.deviceColorPalette.count
            return ChartAxisHelper.deviceColorPalette[fallbackIndex]
          }

          cycleChartView(
            chartRecords: chartRecords, visibleDeviceNames: visibleDeviceNames,
            visibleDeviceColors: visibleDeviceColors
          )
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
      // 初期レンジを設定（一度だけ、親から渡されていない場合のみ）
      if !hasInitialized && sharedSelectedRange == nil {
        localSelectedRange = initialRange
        localWindowEnd = ChartWindowNavigator.initializeWindowEnd(
          for: allRecords, range: initialRange)
        hasInitialized = true
      }
      // 次のランループでChart描画を開始（タブ切り替えアニメーションをブロックしない）
      if !isChartReady {
        DispatchQueue.main.async {
          isChartReady = true
        }
      }
      animateChart = true
    }
    .onDisappear {
      // タブ切り替え時にリセット → 次回表示時に遅延レンダリングが再度有効になる
      isChartReady = false
    }
    .onChange(of: selectedRange) { _ in
      // レンジ変更時のみアニメーション実行
      animateChart = false
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
        withAnimation(.easeOut(duration: 0.4)) {
          animateChart = true
        }
      }
    }
    .onChange(of: windowEnd) { _ in
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
    .onChange(of: initialRange) { _ in
      // iPad独立モードで、ユーザー操作がまだない場合は initialRange の変更に追従
      // （サンプルモード開始時などに外部から3年レンジを設定できるようにする）
      if !isUserInteracted && sharedSelectedRange == nil {
        localSelectedRange = initialRange
        localWindowEnd = ChartWindowNavigator.initializeWindowEnd(
          for: allRecords, range: initialRange)
      }
    }
  }

  // MARK: - チャートビュー（bodyから分離してコンパイラの型チェック負荷を軽減）
  @ViewBuilder
  private func cycleChartView(
    chartRecords: [BatteryRecord], visibleDeviceNames: [String], visibleDeviceColors: [Color]
  ) -> some View {
    Chart {
      ForEach(chartRecords) { record in
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
                String(localized: "cycle_count", table: "Analytics"),
                pointRecord.cycleCount)
            )
            .foregroundStyle(
              by: .value(
                String(localized: "device_name", table: "Common"), pointRecord.deviceName)
            )
            .symbol(.circle)
            .symbolSize(40)
          }
        }
      }
    }
    .chartForegroundStyleScale(
      domain: visibleDeviceNames,
      range: visibleDeviceColors
    )
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
    .chartYScale(
      domain: 0...(Double(visibleRecords.map { $0.cycleCount }.max() ?? 10) * 1.15)
    )
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
  CycleTrendView(
    allRecords: [],
    unit: .day
  )
}
