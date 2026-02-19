import SwiftUI
import UniformTypeIdentifiers

// MARK: - データ管理設定ビュー
struct DataManagementSettingsView: View {
  @Binding var showingDeleteAllConfirmation: Bool
  @Binding var showingDeleteDeviceConfirmation: Bool
  @Binding var deletingDeviceId: String?
  @ObservedObject var appSettings: AppSettings
  let availableDevices: [String]  // 外部から受け取る
  let records: [BatteryRecord]  // エクスポート用
  let dataStore: DataStore  // インポート用

  @Binding var showingExportSheet: Bool
  @Binding var showingImportSheet: Bool
  @Binding var showingImportAlert: Bool
  @Binding var importResultMessage: String
  @Binding var showingExportError: Bool
  @Binding var exportErrorMessage: String

  var body: some View {
    VStack(spacing: 16) {
      exportSection
      importSection

      deviceSelectionSection

      if deletingDeviceId != nil {
        deleteDeviceButtonSection
      }

      deleteAllSection
    }
    .padding(.horizontal)
  }

  // MARK: - エクスポートセクション
  private var exportSection: some View {
    GroupBox {
      Button {
        print("[DataManagementSettingsView] Export button tapped")
        showingExportSheet = true
        print("[DataManagementSettingsView] showingExportSheet set to: \(showingExportSheet)")
      } label: {
        HStack(spacing: 20) {
          Image(systemName: "square.and.arrow.up.fill")
            .font(.system(size: 36))
            .foregroundStyle(.blue)
            .frame(width: 60)

          VStack(alignment: .leading, spacing: 4) {
            Text(String(localized: "export_data", table: "Settings"))
              .font(.headline)
              .foregroundStyle(.primary)

            Text(String(localized: "export_data_description", table: "Settings"))
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }

          Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .padding(.vertical, 8)
      }
      .buttonStyle(.plain)
    }
  }

  // MARK: - インポートセクション
  private var importSection: some View {
    GroupBox {
      Button {
        print("[DataManagementSettingsView] Import button tapped")
        showingImportSheet = true
        print("[DataManagementSettingsView] showingImportSheet set to: \(showingImportSheet)")
      } label: {
        HStack(spacing: 20) {
          Image(systemName: "square.and.arrow.down.fill")
            .font(.system(size: 36))
            .foregroundStyle(.green)
            .frame(width: 60)

          VStack(alignment: .leading, spacing: 4) {
            Text(String(localized: "import_data", table: "Settings"))
              .font(.headline)
              .foregroundStyle(.primary)

            Text(String(localized: "import_data_description", table: "Settings"))
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }

          Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .padding(.vertical, 8)
      }
      .buttonStyle(.plain)
    }
  }

  // MARK: - デバイス選択セクション
  private var deviceSelectionSection: some View {
    GroupBox {
      HStack(spacing: 20) {
        Image(systemName: "externaldrive.fill")
          .font(.system(size: 36))
          .foregroundStyle(.orange)
          .frame(width: 60)

        VStack(alignment: .leading, spacing: 8) {
          HStack {
            Text(String(localized: "delete_device_data", table: "Settings"))
              .font(.headline)
            Spacer()
            Picker(
              "",
              selection: Binding(
                get: { deletingDeviceId ?? "" },
                set: { deletingDeviceId = $0.isEmpty ? nil : $0 }
              )
            ) {
              Text(String(localized: "select_device", table: "Settings"))
                .tag("")
              ForEach(availableDevices, id: \.self) { device in
                Text(device)
                  .tag(device)
              }
            }
            .pickerStyle(.menu)
          }

          Text(String(localized: "delete_device_data_description", table: "Settings"))
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
      }
      .padding(.vertical, 8)
    }
  }

  // MARK: - デバイス削除ボタンセクション
  private var deleteDeviceButtonSection: some View {
    GroupBox {
      Button(role: .destructive) {
        showingDeleteDeviceConfirmation = true
      } label: {
        HStack(spacing: 16) {
          Image(systemName: "trash.fill")
            .font(.system(size: 28))
            .frame(width: 50)
            .foregroundStyle(.red)

          VStack(alignment: .leading, spacing: 4) {
            Text(String(localized: "delete_selected_device_data", table: "Settings"))
              .font(.headline)
              .foregroundStyle(.red)

            Text(String(localized: "delete_selected_device_description", table: "Settings"))
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }

          Spacer()
        }
        .padding(.vertical, 8)
      }
      .buttonStyle(.plain)
      .tint(.red)
    }
  }

  // MARK: - 全削除セクション
  private var deleteAllSection: some View {
    GroupBox {
      Button(role: .destructive) {
        showingDeleteAllConfirmation = true
      } label: {
        HStack(spacing: 20) {
          Image(systemName: "exclamationmark.triangle.fill")
            .font(.system(size: 36))
            .foregroundStyle(.red)
            .frame(width: 60)

          VStack(alignment: .leading, spacing: 4) {
            Text(String(localized: "delete_all_data", table: "Settings"))
              .font(.headline)
              .foregroundStyle(.red)

            Text(String(localized: "delete_all_data_description", table: "Settings"))
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }

          Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .padding(.vertical, 8)
      }
      .buttonStyle(.plain)
    }
  }
}
