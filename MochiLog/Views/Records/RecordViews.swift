import Foundation
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
        Text(record.dynamicDiagnosticResult)
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
        RecordDetailView(record: sample)
          .previewDevice(PreviewDevice(rawValue: "iPad Air (5th generation)"))
          .previewDisplayName("iPad - Regular")

        RecordDetailView(record: sample)
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
              .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 2)
            Image(systemName: sys)
              .foregroundStyle(AppSettings.shared.accentColor.color)
              .font(.system(size: 18, weight: .semibold))
          }
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
    .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 3)
  }
}

struct RecordDetailView: View {
  let record: BatteryRecord
  @StateObject private var appSettings = AppSettings.shared
  @Environment(\.dismiss) private var dismiss

  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  var body: some View {
    NavigationStack {
      Group {
        // iPad / Regular width: bento-styleカードグリッド with polished header and summary panel
        if horizontalSizeClass == .regular {
          ScrollView {
            VStack(spacing: 18) {
              // Header with large circular health ring and summary info
              HStack(alignment: .center, spacing: 20) {
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

                ShareLink(item: generateShareText()) {
                  Label(
                    String(localized: "share", table: "Common"), systemImage: "square.and.arrow.up")
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
                  if let storage = record.storage, let formatted = formattedStorage(storage) {
                    LabeledContent(String(localized: "storage", table: "Records"), value: formatted)
                  }
                  if let ram = record.ram, let formattedRam = formattedRAM(ram) {
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
                    value: record.dynamicDiagnosticResult)
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
              if let storage = record.storage, let formatted = formattedStorage(storage) {
                LabeledContent(String(localized: "storage", table: "Records"), value: formatted)
              }
              if let ram = record.ram, let formattedRam = formattedRAM(ram) {
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
            ShareLink(item: generateShareText()) {
              Image(systemName: "square.and.arrow.up")
            }
          }
          ToolbarItem(placement: .confirmationAction) {
            Button(String(localized: "close", table: "Common")) { dismiss() }
          }
        }
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

    var text = """
      📱 \(record.deviceName)
      📅 \(dateFormatter.string(from: record.logDate))

      🔋 \(String(localized: "battery_health", table: "Records")): \(String(format: "%.1f", health))%
      🔄 \(String(localized: "cycle_count", table: "Analytics")): \(record.cycleCount)
      ⚡ \(String(localized: "nominal_capacity", table: "Analytics")): \(record.nominalCapacity) mAh
      """

    if record.designCapacity > 0 {
      text +=
        "\n📦 \(String(localized: "design_capacity", table: "Analytics")): \(record.designCapacity) mAh"
    }

    text += "\n\n— MochiLog"
    return text
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

  // Format storage strings: convert >= 1024 GB to TB (e.g. 1024GB -> 1 TB, 1536GB -> 1.5 TB)
  private func formattedStorage(_ raw: String?) -> String? {
    guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
      return nil
    }
    let s = raw.replacingOccurrences(of: " ", with: "")
    let lower = s.lowercased()
    if lower.contains("tb") { return s.replacingOccurrences(of: " ", with: " ") }

    do {
      let re = try NSRegularExpression(
        pattern: "([0-9]+(?:\\.[0-9]+)?)\\s*(gb|g)$", options: .caseInsensitive)
      let ns = s as NSString
      if let m = re.firstMatch(in: s, options: [], range: NSRange(location: 0, length: ns.length)) {
        let numStr = ns.substring(with: m.range(at: 1))
        if let val = Double(numStr) {
          if val >= 1024 {
            let tb = val / 1024.0
            if tb.truncatingRemainder(dividingBy: 1) == 0 {
              return String(format: "%.0f TB", tb)
            }
            return String(format: "%.1f TB", tb)
          }
          if val.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f GB", val)
          }
          return String(format: "%.1f GB", val)
        }
      }
    } catch {
      return raw
    }
    return raw
  }

  // Format RAM: round to nearest GB; special-case 15 -> 16
  private func formattedRAM(_ raw: String?) -> String? {
    guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
      return nil
    }
    do {
      let re = try NSRegularExpression(
        pattern: "([0-9]+(?:\\.[0-9]+)?)\\s*(gb|g)$", options: .caseInsensitive)
      let ns = raw as NSString
      if let m = re.firstMatch(in: raw, options: [], range: NSRange(location: 0, length: ns.length))
      {
        let numStr = ns.substring(with: m.range(at: 1))
        if let val = Double(numStr) {
          var rounded = Int(round(val))
          if rounded == 15 { rounded = 16 }
          return "\(rounded) GB"
        }
      }
    } catch {
      return raw
    }
    return raw
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
