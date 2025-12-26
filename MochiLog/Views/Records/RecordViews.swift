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
        let health =
          appSettings.analysisDataSource == .nominal
          ? record.nominalHealthPercent : record.healthPercent
        Text("\(String(format: "%.1f", health))%")
          .font(.title2)
          .bold()
          .foregroundStyle(healthColor(health))
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
                    Text(String(localized: "health"))
                      .font(.caption)
                      .foregroundStyle(.secondary)
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
                      String(format: String(localized: "cycle_count_format"), record.cycleCount),
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

                VStack(spacing: 8) {
                  Button {
                    // TODO: implement share action
                  } label: {
                    Label(String(localized: "share"), systemImage: "square.and.arrow.up")
                  }
                  .buttonStyle(.borderedProminent)

                  Button {
                    // TODO: implement export action
                  } label: {
                    Label(String(localized: "export"), systemImage: "doc")
                  }
                  .buttonStyle(.bordered)
                }
                .frame(minWidth: 120)
              }
              .padding()
              .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))

              HStack(alignment: .top, spacing: 20) {
                // Left column: the existing cards (device info + grid)
                VStack(alignment: .leading, spacing: 20) {
                  // Device info spans full width on iPad
                  DetailCard(title: String(localized: "device_info"), systemImage: "iphone") {
                    VStack(alignment: .leading, spacing: 8) {
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
                        if record.designCapacity > 0 {
                          LabeledContent(
                            String(localized: "design_capacity"),
                            value: "\(record.designCapacity) mAh (100%)")
                        } else {
                          LabeledContent(
                            String(localized: "design_capacity"),
                            value: String(localized: "unknown"))
                        }
                        LabeledContent(
                          String(localized: "nominal_capacity"),
                          value:
                            "\(record.nominalCapacity) mAh (\(String(format: "%.1f%%", record.designCapacity > 0 ? (Double(record.nominalCapacity) / Double(record.designCapacity)) * 100.0 : record.realHealthPercent)))"
                        )
                        LabeledContent(String(localized: "raw_capacity")) {
                          HStack(spacing: 8) {
                            Text("\(record.rawCapacity) mAh")
                            Text("(\(String(format: "%.1f%%", record.healthPercent)))")
                              .foregroundStyle(healthColorLocal(record.healthPercent))
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

                        if let deflator = record.deflator {
                          LabeledContent(
                            String(localized: "deflator"), value: String(format: "%.1f%%", deflator)
                          )
                        }
                        if let diag = record.diagnosticResult {
                          LabeledContent(String(localized: "diagnostic_result"), value: diag)
                        }
                        if let displayDiagnostic = settingsDisplayDiagnosticMessage(
                          record.settingsDisplayPercent)
                        {
                          LabeledContent(
                            String(localized: "settings_display_diagnostic"),
                            value: displayDiagnostic
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

                // Right column: summary / quick actions
                VStack(alignment: .leading, spacing: 16) {
                  DetailCard(title: String(localized: "summary"), systemImage: "chart.bar") {
                    VStack(alignment: .leading, spacing: 8) {
                      HStack(alignment: .firstTextBaseline, spacing: 8) {
                        let health =
                          appSettings.analysisDataSource == .nominal
                          ? record.nominalHealthPercent : record.healthPercent
                        Text("\(String(format: "%.1f", health))%")
                          .font(.largeTitle)
                          .bold()
                        VStack(alignment: .leading) {
                          Text(String(localized: "real_health"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                          Text(String(localized: "nominal_capacity"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        }
                      }

                      Divider()

                      HStack {
                        Button {
                          // TODO: implement share
                        } label: {
                          Label(String(localized: "share"), systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.bordered)

                        Button {
                          // TODO: implement export
                        } label: {
                          Label(String(localized: "export"), systemImage: "doc")
                        }
                        .buttonStyle(.bordered)
                      }
                    }
                    .padding(.vertical, 4)
                  }

                  // Add a place for future summary widgets / charts
                  DetailCard(title: String(localized: "quick_actions"), systemImage: "bolt.fill") {
                    VStack(alignment: .leading, spacing: 8) {
                      Text(String(localized: "actions_hint"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                  }
                }
                .frame(width: 320)
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
              if record.designCapacity > 0 {
                LabeledContent(
                  String(localized: "design_capacity"), value: "\(record.designCapacity) mAh (100%)"
                )
              } else {
                LabeledContent(
                  String(localized: "design_capacity"), value: String(localized: "unknown"))
              }
              LabeledContent(
                String(localized: "nominal_capacity"),
                value:
                  "\(record.nominalCapacity) mAh (\(String(format: "%.1f%%", record.designCapacity > 0 ? (Double(record.nominalCapacity) / Double(record.designCapacity)) * 100.0 : record.realHealthPercent)))"
              )
              LabeledContent(String(localized: "raw_capacity")) {
                HStack(spacing: 8) {
                  Text("\(record.rawCapacity) mAh")
                  Text("(\(String(format: "%.1f%%", record.healthPercent)))")
                    .foregroundStyle(healthColorLocal(record.healthPercent))
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
