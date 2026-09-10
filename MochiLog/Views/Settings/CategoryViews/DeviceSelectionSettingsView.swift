import SwiftUI

// MARK: - デバイス選択設定ビュー
struct DeviceSelectionSettingsView: View {
  @Binding var showingDevicePicker: Bool
  @ObservedObject var appSettings: AppSettings

  // 削除確認用の状態
  @State private var showingRemoveConfirmation = false
  @State private var deviceToRemove: String?
  @State private var showingRemoveAllConfirmation = false

  var body: some View {
    deviceSelectionList
      .alert(
        L10n.string("remove_device", table: "Settings"),
        isPresented: $showingRemoveConfirmation
      ) {
        Button(L10n.string("cancel", table: "Common"), role: .cancel) {}
        Button(L10n.string("remove", table: "Common"), role: .destructive) {
          if let device = deviceToRemove {
            appSettings.removeDevice(name: device)
          }
        }
      } message: {
        if let device = deviceToRemove {
          Text(
            String(
              format: L10n.string("remove_device_confirm_specific", table: "Settings"),
              device))
        }
      }
      .alert(
        L10n.string("remove_all_devices", table: "Settings"),
        isPresented: $showingRemoveAllConfirmation
      ) {
        Button(L10n.string("cancel", table: "Common"), role: .cancel) {}
        Button(L10n.string("remove", table: "Common"), role: .destructive) {
          appSettings.unregisterAllDevices()
        }
      } message: {
        Text(L10n.string("remove_all_devices_confirm", table: "Settings"))
      }
  }

  private var deviceSelectionList: some View {
    List {
      // MARK: - モード選択セクション
      Section {
        ForEach(AppSettings.DeviceSelectionMode.allCases) { mode in
          Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
              appSettings.deviceSelectionMode = mode
            }
          } label: {
            HStack(spacing: 12) {
              Image(systemName: mode.iconName)
                .font(.title3)
                .foregroundStyle(
                  appSettings.deviceSelectionMode == mode
                    ? appSettings.accentColor.color : .secondary
                )
                .frame(width: 28)

              VStack(alignment: .leading, spacing: 2) {
                Text(mode.localizedName)
                  .foregroundStyle(.primary)
                  .fontWeight(appSettings.deviceSelectionMode == mode ? .semibold : .regular)
                Text(mode.description)
                  .font(.caption)
                  .foregroundStyle(.secondary)
                  .lineLimit(2)
              }

              Spacer()

              if appSettings.deviceSelectionMode == mode {
                Image(systemName: "checkmark.circle.fill")
                  .foregroundStyle(appSettings.accentColor.color)
                  .font(.title3)
              }
            }
            .padding(.vertical, 4)
          }
          .buttonStyle(.plain)
        }
      } header: {
        Text(L10n.string("device_selection_mode", table: "Settings"))
      } footer: {
        Text(L10n.string("device_selection_mode_footer", table: "Settings"))
      }

      // MARK: - 登録済みデバイスセクション（preRegisteredモードの場合のみ表示）
      if appSettings.deviceSelectionMode == .preRegistered {
        Section {
          if appSettings.registeredDevices.isEmpty {
            HStack {
              Label(
                L10n.string("registered_device", table: "Settings"),
                systemImage: "iphone.gen3"
              )
              Spacer()
              Text(L10n.string("not_registered", table: "Settings"))
                .foregroundStyle(.secondary)
            }
          } else {
            ForEach(appSettings.registeredDevices, id: \.self) { deviceName in
              deviceRow(for: deviceName)
            }
          }

          Button(action: { showingDevicePicker = true }) {
            Label(
              L10n.string("add_device", table: "Settings"),
              systemImage: "plus.circle"
            )
          }

          if appSettings.registeredDevices.count > 1 {
            Button(action: { showingRemoveAllConfirmation = true }) {
              Label(
                L10n.string("remove_all_devices", table: "Settings"),
                systemImage: "trash"
              )
              .foregroundStyle(.red)
            }
          }
        } header: {
          Text(L10n.string("registered_devices", table: "Settings"))
        } footer: {
          Text(
            appSettings.registeredDevices.isEmpty
              ? L10n.string("registered_devices_empty_footer", table: "Settings")
              : String(
                format: L10n.string("registered_devices_footer", table: "Settings"),
                appSettings.registeredDevices.count)
          )
        }
      }
    }
    .listStyle(.insetGrouped)
    .scrollContentBackground(.hidden)
  }

  private func deviceRow(for deviceName: String) -> some View {
    HStack(spacing: 12) {
      let icon = deviceName.contains("iPad") ? "ipad.gen2" : "iphone.gen3"
      Label(DeviceLibrary.localizedName(for: deviceName), systemImage: icon)
      Spacer()
    }
    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
      Button(role: .destructive) {
        deviceToRemove = deviceName
        showingRemoveConfirmation = true
      } label: {
        Label(L10n.string("remove", table: "Common"), systemImage: "trash")
      }
      .tint(.red)
    }
  }
}
