import Charts
import Foundation
import SwiftData
// RecordViews.swift
// 一覧行ビューと詳細ビュー
import SwiftUI

struct RecordRowView: View {
  let record: BatteryRecord
  @StateObject private var appSettings = AppSettings.shared

  var body: some View {
    HStack {
      VStack(alignment: .leading, spacing: 4) {
        Text(record.deviceName)
          .font(.headline)
        Text(record.logDate, style: .date)
          .font(.caption)
          .foregroundStyle(.secondary)
        Text(
          String(
            format: String(localized: "cycle_count_format", table: "Analytics"), record.cycleCount)
        )
        .font(.caption)
        .foregroundStyle(.secondary)
      }
      Spacer()
      VStack(alignment: .trailing, spacing: 4) {
        let health =
          appSettings.analysisDataSource == .nominal
          ? record.nominalHealthPercent : record.healthPercent
        Text("\(String(format: "%.1f", health))%")
          .font(.title2)
          .bold()
          .foregroundStyle(healthColor(health))
        // 動的に計算した診断結果を表示（分析基準に応じて切り替え）
        Text(record.cachedDiagnostic)
          .font(.caption2)
      }
    }
    .padding(.vertical, 4)
  }

  private func healthColor(_ percent: Double) -> Color {
    if percent < 80 { return .red }
    if percent < 90 { return .orange }
    return appSettings.accentColor.color
  }
}
// MARK: - Previews ✅
#if DEBUG
  struct RecordViews_Previews: PreviewProvider {
    static var previews: some View {
      let sample = BatteryRecord(
        date: Date(), cycleCount: 420, maxCapacityPercent: 90, realCapacitymAh: 3200,
        designCapacitymAh: 3500, deviceName: "iPhone 15 Pro")

      Group {
        NavigationStack {
          RecordDetailView(record: sample)
        }
        .previewDevice(PreviewDevice(rawValue: "iPad Air (5th generation)"))
        .previewDisplayName("iPad - Regular")

        NavigationStack {
          RecordDetailView(record: sample)
        }
        .previewDevice(PreviewDevice(rawValue: "iPhone 14"))
        .previewDisplayName("iPhone - Compact")
      }
    }
  }
#endif
// Small card component for iPad detail layout
struct DetailCard<Content: View>: View {
  let title: String
  let systemImage: String?
  let content: Content

  init(title: String, systemImage: String? = nil, @ViewBuilder content: () -> Content) {
    self.title = title
    self.systemImage = systemImage
    self.content = content()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .center, spacing: 12) {
        if let sys = systemImage {
          CachedView(id: sys + title) {
            ZStack {
              Circle()
                .fill(
                  LinearGradient(
                    gradient: Gradient(colors: [
                      AppSettings.shared.accentColor.color.opacity(0.16),
                      Color(uiColor: .systemBackground).opacity(0.06),
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                  )
                )
                .frame(width: 44, height: 44)
                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)  // Reduced shadow
              Image(systemName: sys)
                .foregroundStyle(AppSettings.shared.accentColor.color)
                .font(.system(size: 18, weight: .semibold))
            }
            .drawingGroup()  // Offload shadow/gradient rendering to GPU
          }
          .frame(width: 44, height: 44)
        }
        Text(title).font(.headline)
        Spacer()
      }
      content
    }
    .padding()
    .frame(minHeight: 120, maxHeight: .infinity, alignment: .top)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
    .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color(uiColor: .separator).opacity(0.08)))
    .shadow(color: Color.black.opacity(0.02), radius: 2, x: 0, y: 1)  // Reduced shadow
  }
}

struct RecordDetailView: View {
  let record: BatteryRecord
  @StateObject private var appSettings = AppSettings.shared
  @Environment(\.dismiss) private var dismiss
  @Environment(\.displayScale) private var displayScale

  @Environment(\.modelContext) private var modelContext
  @State private var shareImage: Image?
  @State private var isShowingSharingSheet = false
  @State private var shareItems: [Any] = []

  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  var body: some View {

    Group {
      // iPad / Regular width: bento-styleカードグリッド with polished header and summary panel
      if horizontalSizeClass == .regular {
        ScrollView {
          VStack(spacing: 18) {
            // Header with large circular health ring and summary info
            HStack(alignment: .center, spacing: 20) {
              CachedView(id: record.logDate.timeIntervalSinceReferenceDate) {
                ZStack {
                  Circle()
                    .stroke(Color(uiColor: .systemGray5), lineWidth: 12)
                    .frame(width: 120, height: 120)
                  Circle()
                    .trim(
                      from: 0,
                      to: CGFloat(
                        min(
                          max(
                            appSettings.analysisDataSource == .nominal
                              ? record.nominalHealthPercent : record.healthPercent, 0), 100))
                        / 100.0
                    )
                    .stroke(
                      AngularGradient(
                        gradient: Gradient(colors: [
                          AppSettings.shared.accentColor.color, Color.green,
                        ]), center: .center),
                      style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 120, height: 120)
                  VStack {
                    let health =
                      appSettings.analysisDataSource == .nominal
                      ? record.nominalHealthPercent : record.healthPercent
                    Text("\(String(format: "%.0f", health))%")
                      .font(.title)
                      .bold()
                  }
                }
                .padding(10)  // Prevent stroke clipping
                .drawingGroup()
              }
              .frame(width: 120, height: 120)

              VStack(alignment: .leading, spacing: 6) {
                Text(record.deviceName).font(.title2).bold()
                if let code = record.deviceModelCode {
                  Text(code).font(.subheadline).foregroundStyle(.secondary)
                }
                Text(record.logDate, style: .date).font(.subheadline).foregroundStyle(.secondary)

                HStack(spacing: 12) {
                  Label(
                    String(
                      format: String(localized: "cycle_count_format", table: "Analytics"),
                      record.cycleCount),
                    systemImage: "gauge"
                  )
                  .font(.caption)
                  .foregroundStyle(.secondary)
                  Label("\(record.nominalCapacity) mAh", systemImage: "battery.25")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
              }

              Spacer()

              Button {
                if let image = generateChartImage() {
                  shareContent(text: generateShareText(), image: image)
                } else {
                  shareContent(text: generateShareText(), image: nil)
                }
              } label: {
                Label(
                  String(localized: "share", table: "Common"),
                  systemImage: "square.and.arrow.up")
              }
              .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))

            // Device info spans full width on iPad
            DetailCard(
              title: String(localized: "device_info", table: "Records"), systemImage: "iphone"
            ) {
              VStack(alignment: .leading, spacing: 8) {
                LabeledContent(
                  String(localized: "device_name", table: "Common"), value: record.deviceName)
                if let soc = record.soc {
                  LabeledContent(String(localized: "soc", table: "Records"), value: soc)
                }
                if let modelCode = record.deviceModelCode {
                  LabeledContent(
                    String(localized: "model_code", table: "Records"), value: modelCode)
                }
                if let storage = record.storage, let formatted = record.formattedStorage {
                  LabeledContent(String(localized: "storage", table: "Records"), value: formatted)
                }
                if let ram = record.ram, let formattedRam = record.formattedRAM {
                  LabeledContent(String(localized: "ram", table: "Records"), value: formattedRam)
                }
                LabeledContent(
                  String(localized: "log_date", table: "Records"), value: record.logDate,
                  format: .dateTime.year().month().day())
                if let firstUse = record.firstUseDate {
                  LabeledContent(
                    String(localized: "first_use_date", table: "Records"), value: firstUse,
                    format: .dateTime.year().month().day())
                }
              }
              .padding(.vertical, 4)
            }

            // Battery capacity spans full width to avoid cut-off
            DetailCard(
              title: String(localized: "battery_capacity", table: "Analytics"),
              systemImage: "battery.100"
            ) {
              VStack(alignment: .leading, spacing: 8) {
                LabeledContent(
                  String(localized: "cycle_count", table: "Analytics"),
                  value: String(
                    format: String(localized: "cycle_count_format", table: "Analytics"),
                    record.cycleCount))
                if record.designCapacity > 0 {
                  LabeledContent(
                    String(localized: "design_capacity", table: "Analytics"),
                    value: "\(record.designCapacity) mAh (100%)")
                } else {
                  LabeledContent(
                    String(localized: "design_capacity", table: "Analytics"),
                    value: String(localized: "unknown", table: "Common"))
                }
                LabeledContent(
                  String(localized: "nominal_capacity", table: "Analytics"),
                  value:
                    "\(record.nominalCapacity) mAh (\(String(format: "%.1f%%", record.designCapacity > 0 ? (Double(record.nominalCapacity) / Double(record.designCapacity)) * 100.0 : record.realHealthPercent)))"
                )
                LabeledContent(String(localized: "raw_capacity", table: "Analytics")) {
                  HStack(spacing: 8) {
                    Text("\(record.rawCapacity) mAh")
                    // 分析基準に応じたヘルス値で色付け
                    let health =
                      appSettings.analysisDataSource == .nominal
                      ? record.nominalHealthPercent : record.healthPercent
                    Text("(\(String(format: "%.1f%%", record.healthPercent)))")
                      .foregroundStyle(healthColorLocal(health))
                  }
                }
                if let lowRate = record.lowRateCapacity {
                  LabeledContent(
                    String(localized: "low_rate_capacity", table: "Records"),
                    value:
                      "\(lowRate) mAh (\(String(format: "%.1f%%", record.designCapacity > 0 ? (Double(lowRate) / Double(record.designCapacity)) * 100.0 : 0.0)))"
                  )
                }
                if let display = record.settingsDisplayPercent {
                  LabeledContent(
                    String(localized: "os_display", table: "Records"),
                    value: "\(min(display, 100))%")
                }

                Divider().padding(.vertical, 6)

                if let deflator = record.deflator {
                  LabeledContent(
                    String(localized: "deflator", table: "Records"),
                    value: String(format: "%.1f%%", deflator)
                  )
                }
                // 動的に計算した診断結果を表示（分析基準に応じて切り替え）
                LabeledContent(
                  String(localized: "diagnostic_result", table: "Records"),
                  value: record.cachedDiagnostic)
                if let displayDiagnostic = settingsDisplayDiagnosticMessage(
                  record.settingsDisplayPercent)
                {
                  LabeledContent(
                    String(localized: "settings_display_diagnostic", table: "Records"),
                    value: displayDiagnostic
                  )
                }
                Text(String(localized: "not_official_note", table: "Records"))
                  .font(.caption2)
                  .foregroundStyle(.secondary)
              }
              .padding(.vertical, 4)
            }

            // Remaining cards in grid
            LazyVGrid(
              columns: [GridItem(.adaptive(minimum: 280, maximum: 500), spacing: 20)],
              alignment: .leading,
              spacing: 20
            ) {
              // Temperature (optional)
              if record.avgTemp != nil || record.maxTemp != nil || record.minTemp != nil {
                DetailCard(
                  title: String(localized: "temperature_daily", table: "Records"),
                  systemImage: "thermometer"
                ) {
                  VStack(alignment: .leading, spacing: 8) {
                    if let avg = record.avgTemp {
                      LabeledContent(
                        String(localized: "average", table: "Analytics"),
                        value: String(format: "%.1f°C", avg))
                    }
                    if let max = record.maxTemp {
                      LabeledContent(
                        String(localized: "maximum", table: "Analytics"),
                        value: String(format: "%.1f°C", max))
                    }
                    if let min = record.minTemp {
                      LabeledContent(
                        String(localized: "minimum", table: "Analytics"),
                        value: String(format: "%.1f°C", min))
                    }
                  }
                  .padding(.vertical, 4)
                }
              }

              // Voltage (optional)
              if record.maxVoltage != nil || record.minVoltage != nil {
                DetailCard(
                  title: String(localized: "voltage", table: "Records"), systemImage: "bolt.fill"
                ) {
                  VStack(alignment: .leading, spacing: 8) {
                    if let max = record.maxVoltage {
                      LabeledContent(
                        String(localized: "maximum", table: "Analytics"),
                        value: String(format: "%.0f mV", max))
                    }
                    if let min = record.minVoltage {
                      LabeledContent(
                        String(localized: "minimum", table: "Analytics"),
                        value: String(format: "%.0f mV", min))
                    }
                  }
                  .padding(.vertical, 4)
                }
              }

              // Charge range (optional)
              if record.maxSoC != nil || record.minSoC != nil {
                DetailCard(
                  title: String(localized: "charge_range_daily", table: "Records"),
                  systemImage: "battery.75"
                ) {
                  VStack(alignment: .leading, spacing: 8) {
                    if let max = record.maxSoC {
                      LabeledContent(
                        String(localized: "max_soc", table: "Records"), value: "\(max)%")
                    }
                    if let min = record.minSoC {
                      LabeledContent(
                        String(localized: "min_soc", table: "Records"), value: "\(min)%")
                    }
                  }
                  .padding(.vertical, 4)
                }
              }
            }
            .padding(.vertical, 18)
          }
        }
        .scrollContentBackground(.hidden)
        .background(Color(uiColor: .systemGroupedBackground))
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
      } else {
        // Compact width (iPhone): 既存の List ベース UI
        List {
          Section(String(localized: "device_info", table: "Records")) {
            LabeledContent(
              String(localized: "device_name", table: "Common"), value: record.deviceName)
            if let soc = record.soc {
              LabeledContent(String(localized: "soc", table: "Records"), value: soc)
            }
            if let modelCode = record.deviceModelCode {
              LabeledContent(String(localized: "model_code", table: "Records"), value: modelCode)
            }
            if let storage = record.storage, let formatted = record.formattedStorage {
              LabeledContent(String(localized: "storage", table: "Records"), value: formatted)
            }
            if let ram = record.ram, let formattedRam = record.formattedRAM {
              LabeledContent(String(localized: "ram", table: "Records"), value: formattedRam)
            }
            LabeledContent(
              String(localized: "log_date", table: "Records"), value: record.logDate,
              format: .dateTime.year().month().day())
            if let firstUse = record.firstUseDate {
              LabeledContent(
                String(localized: "first_use_date", table: "Records"), value: firstUse,
                format: .dateTime.year().month().day())
            }
          }

          Section(String(localized: "battery_capacity", table: "Analytics")) {
            LabeledContent(
              String(localized: "cycle_count", table: "Analytics"),
              value: String(
                format: String(localized: "cycle_count_format", table: "Analytics"),
                record.cycleCount))
            if record.designCapacity > 0 {
              LabeledContent(
                String(localized: "design_capacity", table: "Analytics"),
                value: "\(record.designCapacity) mAh (100%)"
              )
            } else {
              LabeledContent(
                String(localized: "design_capacity", table: "Analytics"),
                value: String(localized: "unknown", table: "Common"))
            }
            LabeledContent(
              String(localized: "nominal_capacity", table: "Analytics"),
              value:
                "\(record.nominalCapacity) mAh (\(String(format: "%.1f%%", record.designCapacity > 0 ? (Double(record.nominalCapacity) / Double(record.designCapacity)) * 100.0 : record.realHealthPercent)))"
            )
            LabeledContent(String(localized: "raw_capacity", table: "Analytics")) {
              HStack(spacing: 8) {
                Text("\(record.rawCapacity) mAh")
                // 分析基準に応じたヘルス値で色付け
                let health =
                  appSettings.analysisDataSource == .nominal
                  ? record.nominalHealthPercent : record.healthPercent
                Text("(\(String(format: "%.1f%%", record.healthPercent)))")
                  .foregroundStyle(healthColorLocal(health))
              }
            }
            if let lowRate = record.lowRateCapacity {
              LabeledContent(
                String(localized: "low_rate_capacity", table: "Records"),
                value:
                  "\(lowRate) mAh (\(String(format: "%.1f%%", record.designCapacity > 0 ? (Double(lowRate) / Double(record.designCapacity)) * 100.0 : 0.0)))"
              )
            }
            if let display = record.settingsDisplayPercent {
              LabeledContent(
                String(localized: "os_display", table: "Records"), value: "\(min(display, 100))%")
            }

            if let deflator = record.deflator {
              LabeledContent(
                String(localized: "deflator", table: "Records"),
                value: String(format: "%.1f%%", deflator))
            }
            // 動的に計算した診断結果を表示（分析基準に応じて切り替え）
            LabeledContent(
              String(localized: "diagnostic_result", table: "Records"),
              value: record.dynamicDiagnosticResult)
            if let displayDiagnostic = settingsDisplayDiagnosticMessage(
              record.settingsDisplayPercent)
            {
              LabeledContent(
                String(localized: "settings_display_diagnostic", table: "Records"),
                value: displayDiagnostic)
            }
            Text(String(localized: "not_official_note", table: "Records"))
              .font(.caption2)
              .foregroundStyle(.secondary)
          }

          if record.avgTemp != nil || record.maxTemp != nil || record.minTemp != nil {
            Section(String(localized: "temperature_daily", table: "Records")) {
              if let avg = record.avgTemp {
                LabeledContent(
                  String(localized: "average", table: "Analytics"),
                  value: String(format: "%.1f°C", avg))
              }
              if let max = record.maxTemp {
                LabeledContent(
                  String(localized: "maximum", table: "Analytics"),
                  value: String(format: "%.1f°C", max))
              }
              if let min = record.minTemp {
                LabeledContent(
                  String(localized: "minimum", table: "Analytics"),
                  value: String(format: "%.1f°C", min))
              }
            }
          }

          if record.maxVoltage != nil || record.minVoltage != nil {
            Section(String(localized: "voltage", table: "Records")) {
              if let max = record.maxVoltage {
                LabeledContent(
                  String(localized: "maximum", table: "Analytics"),
                  value: String(format: "%.0f mV", max))
              }
              if let min = record.minVoltage {
                LabeledContent(
                  String(localized: "minimum", table: "Analytics"),
                  value: String(format: "%.0f mV", min))
              }
            }
          }

          if record.maxSoC != nil || record.minSoC != nil {
            Section(String(localized: "charge_range_daily", table: "Records")) {
              if let max = record.maxSoC {
                LabeledContent(String(localized: "max_soc", table: "Records"), value: "\(max)%")
              }
              if let min = record.minSoC {
                LabeledContent(String(localized: "min_soc", table: "Records"), value: "\(min)%")
              }
            }
          }
        }
      }
    }
    .navigationTitle(String(localized: "detail", table: "Records"))
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      if horizontalSizeClass != .regular {
        ToolbarItem(placement: .cancellationAction) {
          Button {
            if let image = generateChartImage() {
              shareContent(text: generateShareText(), image: image)
            } else {
              shareContent(text: generateShareText(), image: nil)
            }
          } label: {
            Image(systemName: "square.and.arrow.up")
          }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button(String(localized: "close", table: "Common")) {
            dismiss()
          }
        }
      }
    }
    .sheet(isPresented: $isShowingSharingSheet) {
      if !shareItems.isEmpty {
        ActivityViewController(activityItems: shareItems)
      }
    }

  }

  // Generate share text for the record
  private func generateShareText() -> String {
    let health =
      appSettings.analysisDataSource == .nominal
      ? record.nominalHealthPercent : record.healthPercent
    let dateFormatter = DateFormatter()
    dateFormatter.dateStyle = .medium
    dateFormatter.locale = Locale.current

    // タイトル
    var text = String(localized: "share_title", table: "Records")
    text += "\n\n"

    // デバイス名（モデルコードは表示しない）
    text += "\(record.deviceName)\n"

    // 記録日付
    text += "\(dateFormatter.string(from: record.logDate))\n\n"

    // バッテリー最大容量
    text +=
      "\(String(localized: "battery_health", table: "Records")): \(String(format: "%.1f", health))%\n"
    text += "\(record.cachedDiagnostic)\n\n"

    // 使用期間（初使用日がある場合）
    if let firstUse = record.firstUseDate {
      let calendar = Calendar.current
      let components = calendar.dateComponents([.day], from: firstUse, to: record.logDate)
      if let days = components.day {
        text += "\(String(localized: "share_usage_period", table: "Records")): "

        if days >= 365 {
          let years = days / 365
          let remainingDays = days % 365
          text += String(
            format: String(localized: "share_years_days", table: "Records"),
            years, remainingDays
          )
        } else {
          text += String(
            format: String(localized: "share_days", table: "Records"),
            days
          )
        }
        text += "\n"
      }
    }

    // サイクルカウント
    text += String(
      format:
        "\(String(localized: "cycle_count", table: "Analytics")): \(String(localized: "cycle_count_format", table: "Analytics"))",
      record.cycleCount
    )
    text += "\n"

    // 実測容量
    text +=
      "\(String(localized: "raw_capacity", table: "Analytics")): \(record.rawCapacity) mAh"
    text += "\n"

    // 公称容量
    text +=
      "\(String(localized: "nominal_capacity", table: "Analytics")): \(record.nominalCapacity) mAh"
    text += "\n"

    // 設計容量（ある場合）
    if record.designCapacity > 0 {
      text +=
        "\(String(localized: "design_capacity", table: "Analytics")): \(record.designCapacity) mAh"
      text += "\n"
    }

    // フッター（アプリ名とハッシュタグ）
    text += String(localized: "share_footer", table: "Records")

    return text
  }

  // グラフ画像を生成
  @MainActor
  private func generateChartImage() -> UIImage? {
    let deviceName = record.deviceName
    let descriptor = FetchDescriptor<BatteryRecord>(
      predicate: #Predicate { $0.deviceName == deviceName },
      sortBy: [SortDescriptor(\.logDate)]
    )
    let deviceRecords = (try? modelContext.fetch(descriptor)) ?? []

    guard !deviceRecords.isEmpty else { return nil }

    let calendar = Calendar.current
    let now = Date()

    // 分析タブと同じレンジを使用（AppSettingsから取得）
    let range: RangePreset
    if let savedRangeString = appSettings.selectedChartRange,
      let savedRange = RangePreset(rawValue: savedRangeString)
    {
      range = savedRange
    } else {
      // 自動レンジ: データ期間に基づいて計算
      let pastRecords = deviceRecords.filter { $0.logDate <= now }
      guard let first = pastRecords.min(by: { $0.logDate < $1.logDate })?.logDate,
        let last = pastRecords.max(by: { $0.logDate < $1.logDate })?.logDate
      else { return nil }

      let days = calendar.dateComponents([.day], from: first, to: last).day ?? 0
      if days <= 7 {
        range = .oneWeek
      } else if days <= 14 {
        range = .twoWeeks
      } else if days <= 30 {
        range = .oneMonth
      } else if days <= 90 {
        range = .threeMonths
      } else if days <= 180 {
        range = .sixMonths
      } else if days <= 365 {
        range = .oneYear
      } else if days <= 730 {
        range = .twoYears
      } else {
        range = .threeYears
      }
    }

    // 最新のレコード日付を終了日として使用
    guard let windowEnd = deviceRecords.max(by: { $0.logDate < $1.logDate })?.logDate else {
      return nil
    }

    let startDate = ChartWindowNavigator.windowStart(
      for: windowEnd, range: range, allRecords: deviceRecords)
    let startDay = calendar.startOfDay(for: startDate)
    let endDay = calendar.startOfDay(for: windowEnd)

    let visibleRecords = deviceRecords.filter { record in
      let d = calendar.startOfDay(for: record.logDate)
      return d >= startDay && d <= endDay
    }

    // 表示単位を決定するために日数を計算
    let days = calendar.dateComponents([.day], from: startDay, to: endDay).day ?? 0
    let unit: AppSettings.ChartUnit = days <= 14 ? .day : (days <= 120 ? .week : .month)

    // グラフチャート部分のみをレンダリング（ヘッダーやコントロールなし）
    let chartView = Chart {
      ForEach(visibleRecords, id: \.logDate) { record in
        let capacity =
          appSettings.analysisDataSource == .nominal
          ? record.nominalCapacity
          : record.rawCapacity

        LineMark(
          x: .value("Date", record.logDate),
          y: .value("Capacity", capacity)
        )
        .foregroundStyle(appSettings.accentColor.color)
        .lineStyle(StrokeStyle(lineWidth: 3))
        .interpolationMethod(.catmullRom)

        PointMark(
          x: .value("Date", record.logDate),
          y: .value("Capacity", capacity)
        )
        .foregroundStyle(appSettings.accentColor.color)
        .symbolSize(60)
      }
    }
    .chartYScale(domain: .automatic(includesZero: false))
    .chartYAxis {
      AxisMarks(position: .leading, values: .automatic) { value in
        AxisGridLine()
          .foregroundStyle(Color.gray.opacity(0.3))
        AxisValueLabel {
          if let intValue = value.as(Int.self) {
            Text("\(intValue)mAh")
              .foregroundStyle(.primary)
              .font(.system(size: 14, weight: .medium))
          }
        }
      }
    }
    .chartXScale(domain: startDay...endDay)
    .chartXAxis {
      AxisMarks(values: .automatic) { value in
        AxisGridLine()
          .foregroundStyle(Color.gray.opacity(0.3))
        AxisValueLabel(format: .dateTime.month().day())
          .foregroundStyle(.primary)
          .font(.system(size: 14, weight: .medium))
      }
    }
    .frame(width: 800, height: 480)
    .padding(24)
    .background(Color.white)

    return ViewRenderer.snapshot(view: chartView, scale: displayScale)
  }

  // 共有処理
  private func shareContent(text: String, image: UIImage?) {
    var items: [Any] = []
    if let image = image {
      items.append(image)
    }
    items.append(text)

    shareItems = items
    isShowingSharingSheet = true
  }

  // Local helper that uses accent color for 'good' state when available
  private func healthColorLocal(_ percent: Double) -> Color {
    if percent < 80 { return .red }
    if percent < 90 { return .orange }
    return AppSettings.shared.accentColor.color
  }

  private func healthColor(_ percent: Double) -> Color {
    if percent < 80 { return .red }
    if percent < 90 { return .orange }
    return AppSettings.shared.accentColor.color
  }

  private func settingsDisplayDiagnosticMessage(_ percent: Int?) -> String? {
    guard let p = percent else { return nil }
    if p >= 100 {
      // 100%以上：正常（良好）
      return String(
        format: String(localized: "settings_display_diagnostic_high", table: "Records"), p)
    }
    if p >= 90 {
      // 90%以上100%未満：やや劣化
      return String(
        format: String(localized: "settings_display_diagnostic_slight", table: "Records"), p)
    }
    if p >= 80 {
      // 80%以上90%未満：中間（劣化傾向）
      return String(
        format: String(localized: "settings_display_diagnostic_normal", table: "Records"), p)
    }
    // 80%未満：交換を検討
    return String(format: String(localized: "settings_display_diagnostic_low", table: "Records"), p)
  }
}
