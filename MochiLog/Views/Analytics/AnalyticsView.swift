import Charts
import SwiftData
import SwiftUI

// MARK: - 分析ビュー
struct AnalyticsView: View {
  @Query(sort: \BatteryRecord.logDate, order: .forward) private var records: [BatteryRecord]
  @State private var selectedDevice: String?
  @StateObject private var appSettings = AppSettings.shared

  // チャート単位/範囲用
  enum RangePreset: String, CaseIterable, Identifiable {
    case oneWeek = "1w"
    case oneMonth = "1m"
    case threeMonths = "3m"
    case all = "all"

    var id: String { self.rawValue }

    /// ローカライズされた表示名
    var localizedName: String {
      switch self {
      case .oneWeek:
        return String(localized: "range_1w")
      case .oneMonth:
        return String(localized: "range_1m")
      case .threeMonths:
        return String(localized: "range_3m")
      case .all:
        return String(localized: "range_all")
      }
    }
  }

  @State private var selectedRange: RangePreset = .oneMonth
  // 表示ウィンドウの終了日時（endDate）。範囲を前後に移動すると変更される。デフォルトは現在時刻。
  @State private var windowEnd: Date = Date()

  // デバイス選択用のシート制御と検索クエリ
  @State private var isShowingDevicePicker: Bool = false
  @State private var deviceSearchQuery: String = ""

  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @State private var animateChart: Bool = false

  private var deviceNames: [String] {
    Array(Set(records.map { $0.deviceName })).sorted()
  }

  private var filteredRecords: [BatteryRecord] {
    guard let device = selectedDevice else { return records }
    return records.filter { $0.deviceName == device }
  }

  /// データの分布に基づいて初期レンジを決定する（短い期間しかなければ小さいレンジを選ぶ）
  private func autoRange(for records: [BatteryRecord]) -> RangePreset {
    guard let first = records.min(by: { $0.logDate < $1.logDate })?.logDate,
      let last = records.max(by: { $0.logDate < $1.logDate })?.logDate
    else { return .oneMonth }

    let days = Calendar.current.dateComponents([.day], from: first, to: last).day ?? 0

    if days <= 7 { return .oneWeek }
    if days <= 30 { return .oneMonth }
    if days <= 90 { return .threeMonths }
    return .all
  }

  /// レコードに応じて表示単位（Hour/Day/Week/Month）を自動決定する
  private func autoUnit(for records: [BatteryRecord], range: RangePreset) -> AppSettings.ChartUnit {
    guard !records.isEmpty else { return .day }

    let first = records.min(by: { $0.logDate < $1.logDate })!.logDate
    let last = records.max(by: { $0.logDate < $1.logDate })!.logDate
    let days = Calendar.current.dateComponents([.day], from: first, to: last).day ?? 0
    let count = records.count

    // 短い期間で多数のサンプルがある場合は hour
    if days <= 2 && count > 24 { return .hour }
    // 2週間以下は day が見やすい
    if days <= 14 { return .day }
    // 4ヶ月以下は週次表示
    if days <= 120 { return .week }
    // それ以上は月次表示
    return .month
  }

  // MARK: - ウィンドウ（前後移動）ヘルパー
  private func periodComponent(for preset: RangePreset) -> DateComponents? {
    switch preset {
    case .oneWeek:
      return DateComponents(day: 7)
    case .oneMonth:
      return DateComponents(month: 1)
    case .threeMonths:
      return DateComponents(month: 3)
    case .all:
      return nil
    }
  }

  private func windowStart(for endDate: Date, range: RangePreset) -> Date {
    let calendar = Calendar.current
    switch range {
    case .oneWeek:
      return calendar.date(byAdding: .day, value: -7, to: endDate) ?? endDate
    case .oneMonth:
      return calendar.date(byAdding: .month, value: -1, to: endDate) ?? endDate
    case .threeMonths:
      return calendar.date(byAdding: .month, value: -3, to: endDate) ?? endDate
    case .all:
      return (filteredRecords.min(by: { $0.logDate < $1.logDate })?.logDate) ?? endDate
    }
  }

  private func windowContainsData(start: Date, end: Date, in records: [BatteryRecord]) -> Bool {
    return records.contains { $0.logDate >= start && $0.logDate <= end }
  }

  /// 初期化時・レンジ変更時に、現在時点や最終記録を考慮して表示ウィンドウの終了日時を決める
  private func initializeWindowEndIfNeeded() {
    guard !filteredRecords.isEmpty else {
      windowEnd = Date()
      return
    }

    // all のときは最新記録までを表示
    if selectedRange == .all {
      windowEnd = filteredRecords.max(by: { $0.logDate < $1.logDate })?.logDate ?? Date()
      return
    }

    // 通常は現在時刻を優先して、ウィンドウ内にデータが含まれるか確認
    let now = Date()
    let startNow = windowStart(for: now, range: selectedRange)
    if windowContainsData(start: startNow, end: now, in: filteredRecords) {
      windowEnd = now
      return
    }

    // そうでなければ最後の記録日時をウィンドウ終了にする
    if let last = filteredRecords.max(by: { $0.logDate < $1.logDate })?.logDate {
      windowEnd = last
    } else {
      windowEnd = now
    }
  }

  /// 前方に移動できるウィンドウ（endDate）を探す（返り値は新しい endDate）
  private func findNextWindowEnd() -> Date? {
    guard let comp = periodComponent(for: selectedRange) else { return nil }
    var candidateEnd = windowEnd
    let now = Date()

    // 移動先は現在より未来にならないようにする
    while true {
      guard let nextEnd = Calendar.current.date(byAdding: comp, to: candidateEnd) else { break }
      // 次のウィンドウが現在時刻を超える場合、終了日時は現在時刻に合わせる
      let endLimited = min(nextEnd, now)
      // すでに前と同じ位置なら進めない
      if endLimited <= candidateEnd { break }

      let start = windowStart(for: endLimited, range: selectedRange)
      if windowContainsData(start: start, end: endLimited, in: filteredRecords) {
        return endLimited
      }
      // 進めてもデータが見つからない場合は次へ
      if endLimited >= now { break }
      candidateEnd = endLimited
    }
    return nil
  }

  /// 後方に移動できるウィンドウ（endDate）を探す
  private func findPreviousWindowEnd() -> Date? {
    guard let comp = periodComponent(for: selectedRange) else { return nil }
    var candidateEnd = windowEnd

    while true {
      // comp を負数で加算するヘルパーを使って後退
      guard let prevEnd = dateByAdding(comp, multiplier: -1, to: candidateEnd) else { break }
      let prevStart = windowStart(for: prevEnd, range: selectedRange)
      if windowContainsData(start: prevStart, end: prevEnd, in: filteredRecords) {
        return prevEnd
      }
      // 到達点: prevEnd が最古の記録より前なら打ち切り
      if let earliest = filteredRecords.min(by: { $0.logDate < $1.logDate })?.logDate,
        prevEnd <= earliest
      {
        break
      }
      candidateEnd = prevEnd
    }
    return nil
  }

  private func shiftWindow(backward: Bool) {
    if backward {
      if let prev = findPreviousWindowEnd() {
        windowEnd = prev
      }
    } else {
      if let next = findNextWindowEnd() {
        windowEnd = next
      }
    }
  }

  // MARK: - 前後移動の可否
  private var canMoveNext: Bool { selectedRange != .all && findNextWindowEnd() != nil }
  private var canMovePrevious: Bool { selectedRange != .all && findPreviousWindowEnd() != nil }

  /// comp を multiplier 倍して date に加算して返す（DateComponents を簡単に +/- で使えるようにする）
  private func dateByAdding(_ comp: DateComponents, multiplier: Int, to date: Date) -> Date? {
    var c = DateComponents()
    if let d = comp.day { c.day = d * multiplier }
    if let m = comp.month { c.month = m * multiplier }
    if let h = comp.hour { c.hour = h * multiplier }
    return Calendar.current.date(byAdding: c, to: date)
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 20) {
          if records.isEmpty {
            ContentUnavailableView(
              String(localized: "no_data"),
              systemImage: "chart.line.uptrend.xyaxis",
              description: Text(String(localized: "no_data_description"))
            )
            .frame(maxHeight: .infinity)
          } else {
            // デバイス選択ピッカー
            devicePickerSection

            // ヘルス推移グラフ
            healthTrendSection

            // サイクル推移グラフ
            cycleTrendSection

            // 統計情報
            if !filteredRecords.isEmpty {
              statisticsSection
            }
          }
        }
        .padding()
      }
      .onAppear {
        // 起動セッション内で一度だけ、現在の（フィルタ済み）データに合わせてレンジを自動設定（ユーザー選択は上書きしない）
        if !appSettings.hasAutoInitializedChartRange {
          selectedRange = autoRange(for: filteredRecords)
          initializeWindowEndIfNeeded()
          appSettings.hasAutoInitializedChartRange = true
        } else {
          // 既にセッション内で初期化済みなら、現在のウィンドウがデータを含むか確認し、必要なら調整
          initializeWindowEndIfNeeded()
        }
      }
      .onChange(of: records) { _ in
        // records 更新時に、まだセッション内で自動初期化が済んでいなければ適用
        if !appSettings.hasAutoInitializedChartRange {
          selectedRange = autoRange(for: filteredRecords)
          initializeWindowEndIfNeeded()
          appSettings.hasAutoInitializedChartRange = true
        } else {
          // 変更により現在ウィンドウにデータがなくなった場合はウィンドウを調整
          let start = windowStart(for: windowEnd, range: selectedRange)
          if !windowContainsData(start: start, end: windowEnd, in: filteredRecords) {
            initializeWindowEndIfNeeded()
          }
        }
      }
      .onChange(of: selectedDevice) { _ in
        // デバイス切替時もセッション内の初回のみ適用（既に初期化済みならユーザー選択を尊重）
        if !appSettings.hasAutoInitializedChartRange {
          selectedRange = autoRange(for: filteredRecords)
          initializeWindowEndIfNeeded()
          appSettings.hasAutoInitializedChartRange = true
        } else {
          let start = windowStart(for: windowEnd, range: selectedRange)
          if !windowContainsData(start: start, end: windowEnd, in: filteredRecords) {
            initializeWindowEndIfNeeded()
          }
        }
      }
      .navigationTitle(String(localized: "analytics"))
      .background(Color(.systemGroupedBackground))
    }
  }

  // MARK: - デバイス選択
  private var devicePickerSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .center) {
        VStack(alignment: .leading, spacing: 4) {
          Text(String(localized: "select_a_device"))
            .font(.headline)
            .foregroundStyle(.secondary)

          Text(String(localized: "select_a_device_description"))
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(2)
        }

        Spacer()

        // 検索対応のデバイス選択シートを開くボタン（右端）
        Button {
          deviceSearchQuery = ""
          isShowingDevicePicker = true
        } label: {
          HStack(spacing: 8) {
            Text(selectedDevice ?? String(localized: "all_devices"))
              .foregroundStyle(.primary)
            Image(systemName: "chevron.down")
              .foregroundStyle(.secondary)
          }
          .padding(.vertical, 8)
          .padding(.horizontal, 12)
          .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
        }
        .accessibilityLabel(Text(String(localized: "select_a_device")))
        .frame(minWidth: 140)
        .sheet(isPresented: $isShowingDevicePicker) {
          NavigationStack {
            List {
              Button {
                selectedDevice = nil
                isShowingDevicePicker = false
              } label: {
                HStack {
                  Text(String(localized: "all_devices"))
                    .foregroundStyle(.primary)
                  Spacer()
                  if selectedDevice == nil {
                    Image(systemName: "checkmark")
                  }
                }
              }

              ForEach(
                deviceNames.filter {
                  deviceSearchQuery.isEmpty
                    ? true : $0.localizedCaseInsensitiveContains(deviceSearchQuery)
                }, id: \.self
              ) { device in
                Button {
                  selectedDevice = device
                  isShowingDevicePicker = false
                } label: {
                  HStack {
                    Text(device)
                      .foregroundStyle(.primary)
                    Spacer()
                    if selectedDevice == device {
                      Image(systemName: "checkmark")
                    }
                  }
                }
              }
            }
            .searchable(text: $deviceSearchQuery)
            .navigationTitle(Text(String(localized: "select_a_device")))
            .toolbar {
              ToolbarItem(placement: .cancellationAction) {
                Button(String(localized: "cancel")) { isShowingDevicePicker = false }
              }
            }
          }
        }
      }
    }
  }

  // MARK: - ヘルス推移グラフ
  private var healthTrendSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(String(localized: "health_trend"))
        .font(.headline)

      if filteredRecords.isEmpty {
        Text(String(localized: "no_records_for_device"))
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .center)
          .padding()
      } else {
        // チャートコントロール：範囲のみ（表示単位は自動決定）
        if horizontalSizeClass == .compact {
          HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
              Text(String(localized: "chart_range"))
                .font(.caption)
                .foregroundStyle(.secondary)
              HStack(spacing: 8) {
                Button {
                  // 前のウィンドウへ
                  shiftWindow(backward: true)
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
                  // 次のウィンドウへ
                  shiftWindow(backward: false)
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
                  shiftWindow(backward: true)
                } label: {
                  Image(systemName: "chevron.left")
                }
                .disabled(selectedRange == .all || findPreviousWindowEnd() == nil)

                Picker("", selection: $selectedRange) {
                  ForEach(RangePreset.allCases) { preset in
                    Text(preset.localizedName).tag(preset)
                  }
                }
                .pickerStyle(.segmented)
                .accessibilityLabel(Text(String(localized: "chart_range")))

                Button {
                  shiftWindow(backward: false)
                } label: {
                  Image(systemName: "chevron.right")
                }
                .disabled(!canMoveNext)
              }

              // 現在表示中の期間ラベル
              HStack {
                let end = windowEnd
                let start = windowStart(for: end, range: selectedRange)
                Text(start.formatted(.dateTime.month().day()))
                  .font(.caption2)
                  .foregroundStyle(.secondary)
                Text("–")
                  .font(.caption2)
                  .foregroundStyle(.secondary)
                Text(end.formatted(.dateTime.month().day()))
                  .font(.caption2)
                  .foregroundStyle(.secondary)
              }
            }
          }
        }

        let end = windowEnd
        let calendar = Calendar.current
        let startDate: Date = {
          switch selectedRange {
          case .oneWeek:
            return calendar.date(byAdding: .day, value: -7, to: end) ?? end
          case .oneMonth:
            return calendar.date(byAdding: .month, value: -1, to: end) ?? end
          case .threeMonths:
            return calendar.date(byAdding: .month, value: -3, to: end) ?? end
          case .all:
            return (filteredRecords.min(by: { $0.logDate < $1.logDate })?.logDate) ?? end
          }
        }()

        let visibleRecords = filteredRecords.filter {
          $0.logDate >= startDate && $0.logDate <= end
        }

        let unit = autoUnit(for: visibleRecords, range: selectedRange)

        Chart {
          ForEach(visibleRecords) { record in
            LineMark(
              x: .value(
                String(localized: "date"), record.logDate,
                unit: unit.calendarComponent),
              y: .value(String(localized: "real_capacity"), record.healthPercent)
            )
            .foregroundStyle(by: .value(String(localized: "device_name"), record.deviceName))
            .interpolationMethod(.catmullRom)
            .opacity(animateChart ? 1 : 0)

            PointMark(
              x: .value(
                String(localized: "date"), record.logDate,
                unit: unit.calendarComponent),
              y: .value(String(localized: "real_capacity"), record.healthPercent)
            )
            .foregroundStyle(by: .value(String(localized: "device_name"), record.deviceName))
            .symbol(.circle)
            .opacity(animateChart ? 1 : 0)
          }

          // 80%ラインを表示
          RuleMark(y: .value("Threshold", 80))
            .foregroundStyle(.red.opacity(0.5))
            .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
            .annotation(position: .trailing, alignment: .leading) {
              Text("80%")
                .font(.caption2)
                .foregroundStyle(.red)
            }
        }
        .chartYScale(domain: 70...105)
        .chartXAxis {
          // X 軸を月/日の短い形式で表示（ex. 12/1）
          AxisMarks(values: .automatic(desiredCount: 5)) { value in
            // 日付区切りに薄い縦線を表示
            AxisGridLine()
              .foregroundStyle(.secondary.opacity(0.25))

            AxisValueLabel {
              if let date = value.as(Date.self) {
                Text(date.formatted(.dateTime.month(.defaultDigits).day()))
              }
            }
          }
        }
        .chartXScale(domain: startDate...end)
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
        // プロットエリアだけをマスクして、軸を静的に保つ（データだけ下から伸びる）
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
        // 伸びるアニメーション（下から上にスケール）

        .onAppear {
          // 初回フェードインと伸びるアニメーション
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(.easeOut(duration: 0.6)) { animateChart = true }
          }
        }
        .onChange(of: selectedRange) {
          // 範囲が変わったら一旦リセットして再アニメーション（軸はアニメーションしない）
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

  // MARK: - サイクル推移グラフ
  private var cycleTrendSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(String(localized: "cycle_trend"))
        .font(.headline)

      if filteredRecords.isEmpty {
        Text(String(localized: "no_records_for_device"))
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .center)
          .padding()
      } else {
        // 同じ範囲フィルタを再利用
        let end = windowEnd
        let calendar = Calendar.current
        let startDate: Date = {
          switch selectedRange {
          case .oneWeek:
            return calendar.date(byAdding: .day, value: -7, to: end) ?? end
          case .oneMonth:
            return calendar.date(byAdding: .month, value: -1, to: end) ?? end
          case .threeMonths:
            return calendar.date(byAdding: .month, value: -3, to: end) ?? end
          case .all:
            return (filteredRecords.min(by: { $0.logDate < $1.logDate })?.logDate) ?? end
          }
        }()

        let visibleRecords = filteredRecords.filter {
          $0.logDate >= startDate && $0.logDate <= end
        }

        let unit = autoUnit(for: visibleRecords, range: selectedRange)

        Chart {
          ForEach(visibleRecords) { record in
            LineMark(
              x: .value(
                String(localized: "date"), record.logDate,
                unit: unit.calendarComponent),
              y: .value(String(localized: "cycle_count"), record.cycleCount)
            )
            .foregroundStyle(by: .value(String(localized: "device_name"), record.deviceName))
            .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            .opacity(animateChart ? 1 : 0)

            PointMark(
              x: .value(
                String(localized: "date"), record.logDate,
                unit: unit.calendarComponent),
              y: .value(String(localized: "cycle_count"), record.cycleCount)
            )
            .foregroundStyle(by: .value(String(localized: "device_name"), record.deviceName))
            .symbol(.circle)
            .symbolSize(40)
            .opacity(animateChart ? 1 : 0)
          }
        }
        .chartXAxis {
          AxisMarks(values: .automatic(desiredCount: 5)) { value in
            // 日付区切りに薄い縦線を表示
            AxisGridLine()
              .foregroundStyle(.secondary.opacity(0.25))

            AxisValueLabel {
              if let date = value.as(Date.self) {
                Text(date.formatted(.dateTime.month(.defaultDigits).day()))
              }
            }
          }
        }
        .chartXScale(domain: startDate...end)
        // プロットエリアだけをマスクしてデータ部のみアニメーション（軸は動かさない）
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

  // MARK: - 統計情報
  private var statisticsSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(String(localized: "statistics"))
        .font(.headline)

      LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
        StatCard(
          title: String(localized: "record_count"),
          value: "\(filteredRecords.count)",
          icon: "doc.text.fill",
          color: .blue
        )

        StatCard(
          title: String(localized: "average_health"),
          value: String(format: "%.1f%%", averageHealth),
          icon: "heart.fill",
          color: healthColor(averageHealth)
        )

        if let latest = filteredRecords.last {
          StatCard(
            title: String(localized: "cycle_count"),
            value: "\(latest.cycleCount)",
            icon: "arrow.triangle.2.circlepath",
            color: .purple
          )

          StatCard(
            title: String(localized: "latest_health"),
            value: String(format: "%.1f%%", latest.healthPercent),
            icon: "battery.100",
            color: healthColor(latest.healthPercent)
          )
        }
      }
    }
    .padding()
    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
  }

  private var averageHealth: Double {
    guard !filteredRecords.isEmpty else { return 0 }
    let total = filteredRecords.reduce(0) { $0 + $1.healthPercent }
    return total / Double(filteredRecords.count)
  }

  private func healthColor(_ percent: Double) -> Color {
    if percent < 80 { return .red }
    if percent < 90 { return .orange }
    return .green
  }
}

// MARK: - デバイスチップ
struct DeviceChip: View {
  let name: String
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Text(name)
        .font(.subheadline)
        .fontWeight(isSelected ? .semibold : .regular)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
          isSelected
            ? Color.green.opacity(0.2)
            : Color(.systemGray5)
        )
        .foregroundStyle(isSelected ? .green : .primary)
        .clipShape(Capsule())
        .overlay(
          Capsule()
            .stroke(isSelected ? Color.green : Color.clear, lineWidth: 1.5)
        )
    }
    .buttonStyle(.plain)
  }
}

// MARK: - 統計カード
struct StatCard: View {
  let title: String
  let value: String
  let icon: String
  let color: Color

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Image(systemName: icon)
          .foregroundStyle(color)
        Text(title)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Text(value)
        .font(.title2)
        .fontWeight(.bold)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding()
    .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
  }
}

#Preview {
  AnalyticsView()
    .modelContainer(for: BatteryRecord.self, inMemory: true)
}
