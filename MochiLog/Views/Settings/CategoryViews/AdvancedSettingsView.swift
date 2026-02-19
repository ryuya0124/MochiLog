import SwiftUI

// MARK: - 高度な設定ビュー
struct AdvancedSettingsView: View {
  @ObservedObject var appSettings: AppSettings

  @State private var showingDevicePickerForRegistration = false
  @State private var showingRemoveConfirmation = false
  @State private var deviceToRemove: String?
  @State private var showingRemoveAllConfirmation = false

  var body: some View {
    List {
      // MARK: - デバイス選択モード
      Section {
        ForEach(AppSettings.DeviceSelectionMode.allCases) { mode in
          Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
              appSettings.deviceSelectionMode = mode
            }
          } label: {
            HStack(spacing: 12) {
              Label {
                VStack(alignment: .leading, spacing: 2) {
                  Text(mode.localizedName)
                    .foregroundStyle(.primary)
                  Text(mode.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
              } icon: {
                Image(systemName: mode.iconName)
                  .foregroundStyle(appSettings.accentColor.color)
              }
              Spacer()
              if appSettings.deviceSelectionMode == mode {
                Image(systemName: "checkmark")
                  .foregroundStyle(appSettings.accentColor.color)
                  .fontWeight(.semibold)
              }
            }
          }
          .foregroundStyle(.primary)
        }
      } header: {
        Text(String(localized: "device_selection_settings", table: "Settings"))
      }

      if appSettings.deviceSelectionMode == .preRegistered {
        Section {
          if appSettings.registeredDevices.isEmpty {
            HStack {
              Label(
                String(localized: "registered_devices", table: "Settings"),
                systemImage: "iphone.gen3"
              )
              Spacer()
              Text(String(localized: "not_registered", table: "Settings"))
                .foregroundStyle(.secondary)
            }
          } else {
            ForEach(appSettings.registeredDevices, id: \.self) { deviceName in
              let icon = deviceName.contains("iPad") ? "ipad.gen2" : "iphone.gen3"
              Label(deviceName, systemImage: icon)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                  Button(role: .destructive) {
                    deviceToRemove = deviceName
                    showingRemoveConfirmation = true
                  } label: {
                    Label(String(localized: "remove", table: "Common"), systemImage: "trash")
                  }
                  .tint(.red)
                }
            }
          }

          Button(action: { showingDevicePickerForRegistration = true }) {
            Label(
              String(localized: "add_device", table: "Settings"),
              systemImage: "plus.circle"
            )
          }

          if appSettings.registeredDevices.count > 1 {
            Button(action: { showingRemoveAllConfirmation = true }) {
              Label(
                String(localized: "remove_all_devices", table: "Settings"),
                systemImage: "trash"
              )
              .foregroundStyle(.red)
            }
          }
        } header: {
          Text(String(localized: "registered_devices", table: "Settings"))
        } footer: {
          Text(
            appSettings.registeredDevices.isEmpty
              ? String(localized: "registered_devices_empty_footer", table: "Settings")
              : String(localized: "registered_devices_footer", table: "Settings")
          )
        }
      }

      // MARK: - 分析データの計算基準
      Section {
        analysisSourceCard
          .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
          .listRowBackground(Color.clear)
      } header: {
        Text(String(localized: "analysis_source", table: "Settings"))
      }

      // MARK: - 共有インポート設定
      Section {
        shareImportCard
          .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
          .listRowBackground(Color.clear)
      }

      // MARK: - 容量検証設定
      Section {
        capacityValidationCard
          .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
          .listRowBackground(Color.clear)
      }

      // MARK: - 重複ログ設定
      Section {
        duplicateRecordsCard
          .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
          .listRowBackground(Color.clear)
      }

      // MARK: - iCloudストレージ設定
      Section {
        iCloudStorageCard
          .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
          .listRowBackground(Color.clear)
      }
    }
    .listStyle(.insetGrouped)
    .scrollContentBackground(.hidden)
    .sheet(isPresented: $showingDevicePickerForRegistration) {
      HierarchicalDevicePickerView(allowedCategories: [.iphone, .ipad]) { name, _ in
        appSettings.registerDevice(name: name)
      }
    }
    .alert(
      String(localized: "remove_device", table: "Settings"),
      isPresented: $showingRemoveConfirmation
    ) {
      Button(String(localized: "cancel", table: "Common"), role: .cancel) {}
      Button(String(localized: "remove", table: "Common"), role: .destructive) {
        if let device = deviceToRemove {
          appSettings.removeDevice(name: device)
        }
      }
    } message: {
      if let device = deviceToRemove {
        Text(
          String(
            format: String(localized: "remove_device_confirm_specific", table: "Settings"),
            device
          ))
      }
    }
    .alert(
      String(localized: "remove_all_devices", table: "Settings"),
      isPresented: $showingRemoveAllConfirmation
    ) {
      Button(String(localized: "cancel", table: "Common"), role: .cancel) {}
      Button(String(localized: "remove", table: "Common"), role: .destructive) {
        appSettings.registeredDevices.forEach { appSettings.removeDevice(name: $0) }
      }
    } message: {
      Text(String(localized: "remove_all_devices_confirm", table: "Settings"))
    }
  }

  // MARK: - 分析データの計算基準カード
  private var analysisSourceCard: some View {
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

  // MARK: - 共有インポートカード
  private var shareImportCard: some View {
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

  // MARK: - 容量検証カード
  private var capacityValidationCard: some View {
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

  // MARK: - 重複ログカード
  private var duplicateRecordsCard: some View {
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

  // MARK: - iCloudストレージカード
  private var iCloudStorageCard: some View {
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
