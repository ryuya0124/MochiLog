import SwiftUI

// MARK: - 高度な設定ビュー
struct AdvancedSettingsView: View {
  @ObservedObject var appSettings: AppSettings

  var body: some View {
    VStack(spacing: 16) {
      GroupBox {
        VStack(alignment: .leading, spacing: 16) {
          // 分析データの計算基準
          VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "analysis_source", table: "Settings"))
              .font(.subheadline)
              .foregroundStyle(.secondary)

            Picker("", selection: $appSettings.analysisDataSource) {
              ForEach(AppSettings.AnalysisDataSource.allCases) { source in
                Text(source.localizedName).tag(source)
              }
            }
            .pickerStyle(.segmented)
          }

          Divider()

          // 共有インポート時にアプリを開くかどうか
          VStack(alignment: .leading, spacing: 8) {
            Toggle(
              String(localized: "open_app_after_share_import", table: "Settings"),
              isOn: $appSettings.openAppAfterShareImport
            )

            Text(String(localized: "open_app_after_share_import_description", table: "Settings"))
              .font(.caption)
              .foregroundStyle(.secondary)
          }

          Divider()

          // 容量検証
          Toggle(
            String(localized: "enable_capacity_validation", table: "Settings"),
            isOn: $appSettings.enableCapacityValidation
          )

          if appSettings.enableCapacityValidation {
            VStack(alignment: .leading, spacing: 8) {
              HStack {
                Text(String(localized: "validation_threshold", table: "Settings"))
                Spacer()
                Text(String(format: "%.1f x", appSettings.capacityValidationThreshold))
                  .monospacedDigit()
                  .foregroundStyle(.secondary)
              }
              Slider(value: $appSettings.capacityValidationThreshold, in: 2...20, step: 0.5)

              Picker(
                String(localized: "mismatch_behavior", table: "Settings"),
                selection: $appSettings.mismatchBehavior
              ) {
                ForEach(AppSettings.MismatchBehavior.allCases) { behavior in
                  Text(behavior.localizedName).tag(behavior)
                }
              }
            }
          }

          Text(String(localized: "validation_threshold_description", table: "Settings"))
            .font(.caption)
            .foregroundStyle(.secondary)

          Divider()

          // 重複したログの記録を許可
          VStack(alignment: .leading, spacing: 8) {
            Toggle(
              String(localized: "allow_duplicate_records", table: "Settings"),
              isOn: $appSettings.allowDuplicateRecords
            )

            Text(String(localized: "allow_duplicate_records_description", table: "Settings"))
              .font(.caption)
              .foregroundStyle(.secondary)
          }

          Divider()

          // iCloudストレージしきい値
          VStack(alignment: .leading, spacing: 8) {
            HStack {
              Text(String(localized: "icloud_storage_threshold", table: "Settings"))
              Spacer()
              Text(String(format: "%.0f MB", appSettings.iCloudStorageThresholdMB))
                .foregroundStyle(.secondary)
            }
            Slider(value: $appSettings.iCloudStorageThresholdMB, in: 10...1024, step: 10)

            if let blocked = appSettings.iCloudSyncBlockedReason {
              Text(blocked)
                .font(.caption)
                .foregroundColor(.red)
            }
          }
        }
      }
    }
    .padding(.horizontal)
  }
}
