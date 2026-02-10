import SwiftUI

// MARK: - 高度な設定ビュー
struct AdvancedSettingsView: View {
  @ObservedObject var appSettings: AppSettings

  var body: some View {
    VStack(spacing: 16) {
      // 分析データの計算基準
      analysisSourceSection

      // 共有インポート設定
      shareImportSection

      // 容量検証設定
      capacityValidationSection

      // 重複ログ設定
      duplicateRecordsSection

      // iCloudストレージ設定
      iCloudStorageSection
    }
    .padding(.horizontal)
  }

  // MARK: - 分析データの計算基準
  private var analysisSourceSection: some View {
    GroupBox {
      HStack(spacing: 20) {
        Image(systemName: "chart.bar.fill")
          .font(.system(size: 36))
          .foregroundStyle(.blue)
          .frame(width: 60)

        VStack(alignment: .leading, spacing: 8) {
          Text(String(localized: "analysis_source", table: "Settings"))
            .font(.headline)

          Picker("", selection: $appSettings.analysisDataSource) {
            ForEach(AppSettings.AnalysisDataSource.allCases) { source in
              Text(source.localizedName).tag(source)
            }
          }
          .pickerStyle(.segmented)

          Text(String(localized: "analysis_source_description", table: "Settings"))
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
      }
      .padding(.vertical, 8)
    }
  }

  // MARK: - 共有インポート設定
  private var shareImportSection: some View {
    GroupBox {
      HStack(spacing: 20) {
        Image(systemName: "square.and.arrow.down.fill")
          .font(.system(size: 36))
          .foregroundStyle(.green)
          .frame(width: 60)

        VStack(alignment: .leading, spacing: 8) {
          Toggle(
            String(localized: "open_app_after_share_import", table: "Settings"),
            isOn: $appSettings.openAppAfterShareImport
          )
          .font(.headline)

          Text(String(localized: "open_app_after_share_import_description", table: "Settings"))
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
      }
      .padding(.vertical, 8)
    }
  }

  // MARK: - 容量検証設定
  private var capacityValidationSection: some View {
    GroupBox {
      VStack(alignment: .leading, spacing: 12) {
        HStack(spacing: 20) {
          Image(systemName: "checkmark.shield.fill")
            .font(.system(size: 36))
            .foregroundStyle(.orange)
            .frame(width: 60)

          VStack(alignment: .leading, spacing: 8) {
            Toggle(
              String(localized: "enable_capacity_validation", table: "Settings"),
              isOn: $appSettings.enableCapacityValidation
            )
            .font(.headline)

            Text(String(localized: "validation_threshold_description", table: "Settings"))
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }
        }

        if appSettings.enableCapacityValidation {
          Divider()

          VStack(alignment: .leading, spacing: 12) {
            HStack {
              Text(String(localized: "validation_threshold", table: "Settings"))
                .font(.subheadline)
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
            .pickerStyle(.menu)
          }
          .padding(.leading, 80)
        }
      }
      .padding(.vertical, 8)
    }
  }

  // MARK: - 重複ログ設定
  private var duplicateRecordsSection: some View {
    GroupBox {
      HStack(spacing: 20) {
        Image(systemName: "doc.on.doc.fill")
          .font(.system(size: 36))
          .foregroundStyle(.purple)
          .frame(width: 60)

        VStack(alignment: .leading, spacing: 8) {
          Toggle(
            String(localized: "allow_duplicate_records", table: "Settings"),
            isOn: $appSettings.allowDuplicateRecords
          )
          .font(.headline)

          Text(String(localized: "allow_duplicate_records_description", table: "Settings"))
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
      }
      .padding(.vertical, 8)
    }
  }

  // MARK: - iCloudストレージ設定
  private var iCloudStorageSection: some View {
    GroupBox {
      HStack(spacing: 20) {
        Image(systemName: "icloud.fill")
          .font(.system(size: 36))
          .foregroundStyle(.cyan)
          .frame(width: 60)

        VStack(alignment: .leading, spacing: 12) {
          Text(String(localized: "icloud_storage_threshold", table: "Settings"))
            .font(.headline)

          HStack {
            Text(String(localized: "threshold_label", table: "Settings"))
              .font(.subheadline)
            Spacer()
            Text(String(format: "%.0f MB", appSettings.iCloudStorageThresholdMB))
              .foregroundStyle(.secondary)
          }

          Slider(value: $appSettings.iCloudStorageThresholdMB, in: 10...1024, step: 10)

          if let blocked = appSettings.iCloudSyncBlockedReason {
            Label(blocked, systemImage: "exclamationmark.triangle.fill")
              .font(.caption)
              .foregroundColor(.red)
          }

          Text(String(localized: "icloud_storage_description", table: "Settings"))
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
      }
      .padding(.vertical, 8)
    }
  }
}
