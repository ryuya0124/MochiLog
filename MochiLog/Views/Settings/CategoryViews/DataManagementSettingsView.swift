import SwiftData
import SwiftUI

// MARK: - データ管理設定ビュー
struct DataManagementSettingsView: View {
  @Binding var showingDeleteAllConfirmation: Bool
  @Binding var showingDeleteDeviceConfirmation: Bool
  @Binding var deletingDeviceId: String?
  @ObservedObject var appSettings: AppSettings
  let availableDevices: [String]  // 外部から受け取る

  var body: some View {
    VStack(spacing: 16) {
      deviceSelectionSection

      if deletingDeviceId != nil {
        deleteDeviceButtonSection
      }

      deleteAllSection
    }
    .padding(.horizontal)
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

          Text("特定デバイスの全データを削除します")
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

            Text("選択したデバイスのデータを完全に削除します")
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

            Text("すべてのバッテリーログを完全に削除します（復元不可）")
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
