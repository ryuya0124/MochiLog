import SwiftUI

// MARK: - 登録済みデバイス一覧カード（iPad/iPhone 共通）
struct RegisteredDevicesBlockView: View {
  @ObservedObject var appSettings: AppSettings
  let onAddDevice: () -> Void

  @State private var showingRemoveConfirmation = false
  @State private var deviceToRemove: String?
  @State private var showingRemoveAllConfirmation = false

  var body: some View {
    VStack(spacing: 0) {
      if appSettings.registeredDevices.isEmpty {
        row {
          HStack {
            Label(
              L10n.string("registered_devices", table: "Settings"),
              systemImage: "iphone.gen3"
            )
            Spacer()
            Text(L10n.string("not_registered", table: "Settings"))
              .foregroundStyle(.secondary)
          }
        }
      } else {
        ForEach(appSettings.registeredDevices, id: \.self) { deviceName in
          let icon = deviceName.contains("iPad") ? "ipad.gen2" : "iphone.gen3"
          row {
            HStack(spacing: 12) {
              Label(DeviceLibrary.localizedName(for: deviceName), systemImage: icon)
              Spacer()
              Button {
                deviceToRemove = deviceName
                showingRemoveConfirmation = true
              } label: {
                Image(systemName: "minus.circle.fill")
                  .foregroundStyle(.red)
              }
              .buttonStyle(.plain)
            }
          }

          if deviceName != appSettings.registeredDevices.last {
            Divider()
              .padding(.leading, 16)
          }
        }
      }

      Divider()

      row {
        Button(action: onAddDevice) {
          Label(
            L10n.string("add_device", table: "Settings"),
            systemImage: "plus.circle"
          )
        }
        .buttonStyle(.plain)
      }

      if appSettings.registeredDevices.count > 1 {
        Divider()

        row {
          Button(action: { showingRemoveAllConfirmation = true }) {
            Label(
              L10n.string("remove_all_devices", table: "Settings"),
              systemImage: "trash"
            )
            .foregroundStyle(.red)
          }
          .buttonStyle(.plain)
        }
      }
    }
    .background(Color(.secondarySystemGroupedBackground))
    .clipShape(RoundedRectangle(cornerRadius: 10))
    .overlay(
      RoundedRectangle(cornerRadius: 10)
        .stroke(Color(uiColor: .separator).opacity(0.3), lineWidth: 0.5)
    )
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
        appSettings.registeredDevices.forEach { appSettings.removeDevice(name: $0) }
      }
    } message: {
      Text(L10n.string("remove_all_devices_confirm", table: "Settings"))
    }
  }

  @ViewBuilder
  private func row<Content: View>(@ViewBuilder content: () -> Content) -> some View {
    content()
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 16)
      .padding(.vertical, 11)
  }
}
