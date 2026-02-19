import SwiftUI

// MARK: - 高度な設定ビュー
struct AdvancedSettingsView: View {
  @ObservedObject var appSettings: AppSettings

  @State private var showingDevicePickerForRegistration = false

  var body: some View {
    VStack(spacing: 16) {
      // デバイス選択設定
      deviceSelectionSection

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
    .sheet(isPresented: $showingDevicePickerForRegistration) {
      HierarchicalDevicePickerView(allowedCategories: [.iphone, .ipad]) { name, _ in
        appSettings.registerDevice(name: name)
      }
    }
  }

  // MARK: - デバイス選択設定
  private var deviceSelectionSection: some View {
    GroupBox {
      VStack(alignment: .leading, spacing: 12) {
        Label(
          String(localized: "device_selection_settings", table: "Settings"),
          systemImage: "iphone.gen3"
        )
        .font(.headline)

        VStack(spacing: 6) {
          ForEach(AppSettings.DeviceSelectionMode.allCases) { mode in
            modeSelectionCard(mode)
          }
        }

        if appSettings.deviceSelectionMode == .preRegistered {
          Divider()
          registeredDevicesBlock
        }
      }
      .padding(.vertical, 4)
    }
  }

  @ViewBuilder
  private func modeSelectionCard(_ mode: AppSettings.DeviceSelectionMode) -> some View {
    let isSelected = appSettings.deviceSelectionMode == mode
    Button {
      withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
        appSettings.deviceSelectionMode = mode
      }
    } label: {
      HStack(spacing: 12) {
        Image(systemName: mode.iconName)
          .font(.title3)
          .foregroundStyle(isSelected ? appSettings.accentColor.color : .secondary)
          .frame(width: 26)

        VStack(alignment: .leading, spacing: 2) {
          Text(mode.localizedName)
            .fontWeight(isSelected ? .semibold : .regular)
            .foregroundStyle(.primary)
          Text(mode.description)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(2)
        }

        Spacer()

        if isSelected {
          Image(systemName: "checkmark.circle.fill")
            .foregroundStyle(appSettings.accentColor.color)
        }
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 10)
      .background(
        isSelected
          ? appSettings.accentColor.color.opacity(0.12)
          : Color.primary.opacity(0.05)
      )
      .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    .buttonStyle(.plain)
  }

  private var registeredDevicesBlock: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(String(localized: "registered_devices", table: "Settings"))
        .font(.subheadline)
        .fontWeight(.medium)
        .foregroundStyle(.secondary)

      RegisteredDevicesBlockView(
        appSettings: appSettings,
        onAddDevice: { showingDevicePickerForRegistration = true }
      )

      Text(
        appSettings.registeredDevices.isEmpty
          ? String(localized: "registered_devices_empty_footer", table: "Settings")
          : String(localized: "registered_devices_footer", table: "Settings")
      )
      .font(.caption)
      .foregroundStyle(.secondary)
    }
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
