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
        Text(String(format: String(localized: "cycle_count_format"), record.cycleCount))
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Spacer()
      VStack(alignment: .trailing, spacing: 4) {
        Text("\(String(format: "%.1f", record.realHealthPercent))%")
          .font(.title2)
          .bold()
          .foregroundStyle(healthColor(record.realHealthPercent))
        if let diag = record.diagnosticResult {
          Text(diag)
            .font(.caption2)
        }
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
            Circle().fill(Color.accentColor.opacity(0.12)).frame(width: 36, height: 36)
            Image(systemName: sys)
              .foregroundStyle(Color.accentColor)
              .font(.system(size: 16, weight: .semibold))
          }
        }
        Text(title).font(.headline)
        Spacer()
      }
      content
    }
    .padding()
    .frame(minHeight: 120, maxHeight: .infinity, alignment: .top)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(uiColor: .separator).opacity(0.08)))
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
        // iPad / Regular width: bento-styleカードグリッド
        if horizontalSizeClass == .regular {
          ScrollView {
            HStack {
              VStack(alignment: .leading, spacing: 20) {
                // Device info spans full width on iPad
                DetailCard(title: String(localized: "device_info"), systemImage: "iphone") {
                  VStack(alignment: .leading, spacing: 8) {
                    LabeledContent(String(localized: "device_name"), value: record.deviceName)
                    if let soc = record.soc { LabeledContent(String(localized: "soc"), value: soc) }
                    if let modelCode = record.deviceModelCode {
                      LabeledContent(String(localized: "model_code"), value: modelCode)
                    }
                    if let storage = record.storage, let formatted = formattedStorage(storage) {
                      LabeledContent(String(localized: "storage"), value: formatted)
                    }
                    if let ram = record.ram, let formattedRam = formattedRAM(ram) {
                      LabeledContent(String(localized: "ram"), value: formattedRam)
                    }
                    LabeledContent(
                      String(localized: "log_date"), value: record.logDate,
                      format: .dateTime.year().month().day())
                    if let firstUse = record.firstUseDate {
                      LabeledContent(
                        String(localized: "first_use_date"), value: firstUse,
                        format: .dateTime.year().month().day())
                    }
                  }
                  .padding(.vertical, 4)
                }

                // Remaining cards in grid
                LazyVGrid(
                  columns: [GridItem(.adaptive(minimum: 220, maximum: 420), spacing: 20)],
                  alignment: .leading,
                  spacing: 20
                ) {
                  // Battery (capacity & health)
                  DetailCard(
                    title: String(localized: "battery_capacity"), systemImage: "battery.100"
                  ) {
                    VStack(alignment: .leading, spacing: 8) {
                      LabeledContent(
                        String(localized: "cycle_count"),
                        value: String(
                          format: String(localized: "cycle_count_format"), record.cycleCount))
                      LabeledContent(
                        String(localized: "design_capacity"),
                        value: "\(record.designCapacity) mAh (100%)")
                      LabeledContent(
                        String(localized: "nominal_capacity"),
                        value:
                          "\(record.nominalCapacity) mAh (\(String(format: "%.1f%%", record.designCapacity > 0 ? (Double(record.nominalCapacity) / Double(record.designCapacity)) * 100.0 : record.realHealthPercent)))"
                      )
                      LabeledContent(String(localized: "raw_capacity")) {
                        HStack(spacing: 8) {
                          Text("\(record.rawCapacity) mAh")
                          Text("(\(String(format: "%.1f%%", record.realHealthPercent)))")
                            .foregroundStyle(healthColorLocal(record.realHealthPercent))
                        }
                      }
                      if let lowRate = record.lowRateCapacity {
                        LabeledContent(
                          String(localized: "low_rate_capacity"),
                          value:
                            "\(lowRate) mAh (\(String(format: "%.1f%%", record.designCapacity > 0 ? (Double(lowRate) / Double(record.designCapacity)) * 100.0 : 0.0)))"
                        )
                      }
                      if let display = record.settingsDisplayPercent {
                        LabeledContent(
                          String(localized: "os_display"), value: "\(min(display, 100))%")
                      }

                      Divider().padding(.vertical, 6)

                      // Health info
                      LabeledContent(String(localized: "real_health")) {
                        Text("\(String(format: "%.1f", record.realHealthPercent))%")
                          .foregroundStyle(healthColor(record.realHealthPercent))
                          .bold()
                      }

                      if let deflator = record.deflator {
                        LabeledContent(
                          String(localized: "deflator"), value: String(format: "%.1f%%", deflator))
                      }
                      if let diag = record.diagnosticResult {
                        LabeledContent(String(localized: "diagnostic_result"), value: diag)
                      }
                      if let displayDiagnostic = settingsDisplayDiagnosticMessage(
                        record.settingsDisplayPercent)
                      {
                        LabeledContent(
                          String(localized: "settings_display_diagnostic"), value: displayDiagnostic
                        )
                      }
                      Text(String(localized: "not_official_note"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                  }

                  // Temperature (optional)
                  if record.avgTemp != nil || record.maxTemp != nil || record.minTemp != nil {
                    DetailCard(
                      title: String(localized: "temperature_daily"), systemImage: "thermometer"
                    ) {
                      VStack(alignment: .leading, spacing: 8) {
                        if let avg = record.avgTemp {
                          LabeledContent(
                            String(localized: "average"), value: String(format: "%.1f°C", avg))
                        }
                        if let max = record.maxTemp {
                          LabeledContent(
                            String(localized: "maximum"), value: String(format: "%.1f°C", max))
                        }
                        if let min = record.minTemp {
                          LabeledContent(
                            String(localized: "minimum"), value: String(format: "%.1f°C", min))
                        }
                      }
                      .padding(.vertical, 4)
                    }
                  }

                  // Voltage (optional)
                  if record.maxVoltage != nil || record.minVoltage != nil {
                    DetailCard(title: String(localized: "voltage"), systemImage: "bolt.fill") {
                      VStack(alignment: .leading, spacing: 8) {
                        if let max = record.maxVoltage {
                          LabeledContent(
                            String(localized: "maximum"), value: String(format: "%.0f mV", max))
                        }
                        if let min = record.minVoltage {
                          LabeledContent(
                            String(localized: "minimum"), value: String(format: "%.0f mV", min))
                        }
                      }
                      .padding(.vertical, 4)
                    }
                  }

                  // Charge range (optional)
                  if record.maxSoC != nil || record.minSoC != nil {
                    DetailCard(
                      title: String(localized: "charge_range_daily"), systemImage: "battery.75"
                    ) {
                      VStack(alignment: .leading, spacing: 8) {
                        if let max = record.maxSoC {
                          LabeledContent(String(localized: "max_soc"), value: "\(max)%")
                        }
                        if let min = record.minSoC {
                          LabeledContent(String(localized: "min_soc"), value: "\(min)%")
                        }
                      }
                      .padding(.vertical, 4)
                    }
                  }
                }
              }
              .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 18)
          }
          .scrollContentBackground(.hidden)
          .background(Color(uiColor: .systemGroupedBackground))
          .padding(.horizontal, 20)
          .padding(.vertical, 10)
        } else {
          // Compact width (iPhone): 既存の List ベース UI
          List {
            Section(String(localized: "device_info")) {
              LabeledContent(String(localized: "device_name"), value: record.deviceName)
              if let soc = record.soc {
                LabeledContent(String(localized: "soc"), value: soc)
              }
              if let modelCode = record.deviceModelCode {
                LabeledContent(String(localized: "model_code"), value: modelCode)
              }
              if let storage = record.storage, let formatted = formattedStorage(storage) {
                LabeledContent(String(localized: "storage"), value: formatted)
              }
              if let ram = record.ram, let formattedRam = formattedRAM(ram) {
                LabeledContent(String(localized: "ram"), value: formattedRam)
              }
              LabeledContent(
                String(localized: "log_date"), value: record.logDate,
                format: .dateTime.year().month().day())
              if let firstUse = record.firstUseDate {
                LabeledContent(
                  String(localized: "first_use_date"), value: firstUse,
                  format: .dateTime.year().month().day())
              }
            }

            Section(String(localized: "battery_capacity")) {
              LabeledContent(
                String(localized: "cycle_count"),
                value: String(format: String(localized: "cycle_count_format"), record.cycleCount))
              LabeledContent(
                String(localized: "design_capacity"), value: "\(record.designCapacity) mAh (100%)")
              LabeledContent(
                String(localized: "nominal_capacity"),
                value:
                  "\(record.nominalCapacity) mAh (\(String(format: "%.1f%%", record.designCapacity > 0 ? (Double(record.nominalCapacity) / Double(record.designCapacity)) * 100.0 : record.realHealthPercent)))"
              )
              LabeledContent(String(localized: "raw_capacity")) {
                HStack(spacing: 8) {
                  Text("\(record.rawCapacity) mAh")
                  Text("(\(String(format: "%.1f%%", record.realHealthPercent)))")
                    .foregroundStyle(healthColorLocal(record.realHealthPercent))
                }
              }
              if let lowRate = record.lowRateCapacity {
                LabeledContent(
                  String(localized: "low_rate_capacity"),
                  value:
                    "\(lowRate) mAh (\(String(format: "%.1f%%", record.designCapacity > 0 ? (Double(lowRate) / Double(record.designCapacity)) * 100.0 : 0.0)))"
                )
              }
              if let display = record.settingsDisplayPercent {
                LabeledContent(String(localized: "os_display"), value: "\(min(display, 100))%")
              }

              // Health info
              LabeledContent(String(localized: "real_health")) {
                Text("\(String(format: "%.1f", record.realHealthPercent))%")
                  .foregroundStyle(healthColor(record.realHealthPercent))
                  .bold()
              }

              if let deflator = record.deflator {
                LabeledContent(
                  String(localized: "deflator"), value: String(format: "%.1f%%", deflator))
              }
              if let diag = record.diagnosticResult {
                LabeledContent(String(localized: "diagnostic_result"), value: diag)
              }
              if let displayDiagnostic = settingsDisplayDiagnosticMessage(
                record.settingsDisplayPercent)
              {
                LabeledContent(
                  String(localized: "settings_display_diagnostic"), value: displayDiagnostic)
              }
              Text(String(localized: "not_official_note"))
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            if record.avgTemp != nil || record.maxTemp != nil || record.minTemp != nil {
              Section(String(localized: "temperature_daily")) {
                if let avg = record.avgTemp {
                  LabeledContent(String(localized: "average"), value: String(format: "%.1f°C", avg))
                }
                if let max = record.maxTemp {
                  LabeledContent(String(localized: "maximum"), value: String(format: "%.1f°C", max))
                }
                if let min = record.minTemp {
                  LabeledContent(String(localized: "minimum"), value: String(format: "%.1f°C", min))
                }
              }
            }

            if record.maxVoltage != nil || record.minVoltage != nil {
              Section(String(localized: "voltage")) {
                if let max = record.maxVoltage {
                  LabeledContent(
                    String(localized: "maximum"), value: String(format: "%.0f mV", max))
                }
                if let min = record.minVoltage {
                  LabeledContent(
                    String(localized: "minimum"), value: String(format: "%.0f mV", min))
                }
              }
            }

            if record.maxSoC != nil || record.minSoC != nil {
              Section(String(localized: "charge_range_daily")) {
                if let max = record.maxSoC {
                  LabeledContent(String(localized: "max_soc"), value: "\(max)%")
                }
                if let min = record.minSoC {
                  LabeledContent(String(localized: "min_soc"), value: "\(min)%")
                }
              }
            }
          }
        }
      }
      .navigationTitle(String(localized: "detail"))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        if horizontalSizeClass != .regular {
          ToolbarItem(placement: .confirmationAction) {
            Button(String(localized: "close")) { dismiss() }
          }
        }
      }
    }
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
    if p > 100 {
      return String(format: String(localized: "settings_display_diagnostic_high"), p)
    }
    if p >= 95 {
      return String(format: String(localized: "settings_display_diagnostic_normal"), p)
    }
    return String(format: String(localized: "settings_display_diagnostic_low"), p)
  }
}
