// RecordViews.swift
// 一覧行ビューと詳細ビュー
import SwiftUI

struct RecordRowView: View {
  let record: BatteryRecord

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
        Text("\(String(format: "%.1f", record.healthPercent))%")
          .font(.title2)
          .bold()
          .foregroundStyle(healthColor(record.healthPercent))
        if let display = record.settingsDisplayPercent {
          Text("\(String(localized: "os_display")): \(display)%")
            .font(.caption2)
            .foregroundStyle(.gray)
        }
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
    return .green
  }
}

struct RecordDetailView: View {
  let record: BatteryRecord
  @Environment(\.dismiss) private var dismiss

  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  var body: some View {
    NavigationStack {
      Group {
        // iPad / Regular width: より広く2カラムで表示
        if horizontalSizeClass == .regular {
          ScrollView {
            HStack(alignment: .top, spacing: 20) {
              VStack(alignment: .leading, spacing: 16) {
                GroupBox(label: Text(String(localized: "device_info")).font(.headline)) {
                  VStack(alignment: .leading, spacing: 8) {
                    LabeledContent(String(localized: "device_name"), value: record.deviceName)
                    if let soc = record.soc {
                      LabeledContent(String(localized: "soc"), value: soc)
                    }
                    if let modelCode = record.deviceModelCode {
                      LabeledContent(String(localized: "model_code"), value: modelCode)
                    }
                    if let storage = record.storage {
                      LabeledContent(String(localized: "storage"), value: storage)
                    }
                    if let ram = record.ram {
                      LabeledContent(String(localized: "ram"), value: ram)
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

                GroupBox(label: Text(String(localized: "battery_capacity")).font(.headline)) {
                  VStack(alignment: .leading, spacing: 8) {
                    LabeledContent(
                      String(localized: "cycle_count"),
                      value: String(
                        format: String(localized: "cycle_count_format"), record.cycleCount))
                    LabeledContent(
                      String(localized: "design_capacity"), value: "\(record.designCapacity) mAh")
                    LabeledContent(
                      String(localized: "nominal_capacity"), value: "\(record.nominalCapacity) mAh")
                    LabeledContent(
                      String(localized: "raw_capacity"), value: "\(record.rawCapacity) mAh")
                    if let lowRate = record.lowRateCapacity {
                      LabeledContent(
                        String(localized: "low_rate_capacity"), value: "\(lowRate) mAh")
                    }
                  }
                  .padding(.vertical, 4)
                }
              }

              VStack(alignment: .leading, spacing: 16) {
                GroupBox(label: Text(String(localized: "battery_health")).font(.headline)) {
                  VStack(alignment: .leading, spacing: 8) {
                    LabeledContent(String(localized: "real_health")) {
                      Text("\(String(format: "%.1f", record.healthPercent))%")
                        .foregroundStyle(healthColor(record.healthPercent))
                        .bold()
                    }
                    if let display = record.settingsDisplayPercent {
                      LabeledContent(String(localized: "os_display"), value: "\(display)%")
                    }
                    if let deflator = record.deflator {
                      LabeledContent(
                        String(localized: "deflator"), value: String(format: "%.1f%%", deflator))
                    }
                    if let diag = record.diagnosticResult {
                      LabeledContent(String(localized: "diagnostic_result"), value: diag)
                    }
                  }
                  .padding(.vertical, 4)
                }

                if record.avgTemp != nil || record.maxTemp != nil || record.minTemp != nil {
                  GroupBox(label: Text(String(localized: "temperature_daily")).font(.headline)) {
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

                if record.maxVoltage != nil || record.minVoltage != nil {
                  GroupBox(label: Text(String(localized: "voltage")).font(.headline)) {
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

                if record.maxSoC != nil || record.minSoC != nil {
                  GroupBox(label: Text(String(localized: "charge_range_daily")).font(.headline)) {
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
            .padding()
          }
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
              if let storage = record.storage {
                LabeledContent(String(localized: "storage"), value: storage)
              }
              if let ram = record.ram {
                LabeledContent(String(localized: "ram"), value: ram)
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
                String(localized: "design_capacity"), value: "\(record.designCapacity) mAh")
              LabeledContent(
                String(localized: "nominal_capacity"), value: "\(record.nominalCapacity) mAh")
              LabeledContent(String(localized: "raw_capacity"), value: "\(record.rawCapacity) mAh")
              if let lowRate = record.lowRateCapacity {
                LabeledContent(String(localized: "low_rate_capacity"), value: "\(lowRate) mAh")
              }
            }

            Section(String(localized: "battery_health")) {
              LabeledContent(String(localized: "real_health")) {
                Text("\(String(format: "%.1f", record.healthPercent))%")
                  .foregroundStyle(healthColor(record.healthPercent))
                  .bold()
              }
              if let display = record.settingsDisplayPercent {
                LabeledContent(String(localized: "os_display"), value: "\(display)%")
              }
              if let deflator = record.deflator {
                LabeledContent(
                  String(localized: "deflator"), value: String(format: "%.1f%%", deflator))
              }
              if let diag = record.diagnosticResult {
                LabeledContent(String(localized: "diagnostic_result"), value: diag)
              }
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
        ToolbarItem(placement: .confirmationAction) {
          Button(String(localized: "close")) { dismiss() }
        }
      }
    }
  }

  private func healthColor(_ percent: Double) -> Color {
    if percent < 80 { return .red }
    if percent < 90 { return .orange }
    return .green
  }
}
