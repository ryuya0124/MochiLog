import SwiftUI

/// ログ記録時に登録済みiPhone/iPadデバイスから選択するシート
struct RegisteredDeviceSelectSheet: View {
  @Environment(\.dismiss) private var dismiss
  @ObservedObject var appSettings = AppSettings.shared

  let onSelect: (String) -> Void

  var body: some View {
    NavigationStack {
      List {
        Section {
          ForEach(appSettings.registeredDevices, id: \.self) { deviceName in
            HStack {
              Label {
                Text(deviceName)
              } icon: {
                let icon = deviceName.contains("iPad") ? "ipad.gen2" : "iphone.gen3"
                Image(systemName: icon)
                  .foregroundStyle(appSettings.accentColor.color)
              }
              Spacer()
              Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
            .onTapGesture {
              let selected = deviceName
              dismiss()
              DispatchQueue.main.async {
                onSelect(selected)
              }
            }
          }
        } header: {
          Text(L10n.string("select_registered_device", table: "Settings"))
        }
      }
      .navigationTitle(L10n.string("select_device", table: "Common"))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(L10n.string("cancel", table: "Common")) {
            dismiss()
          }
        }
      }
    }
    .tint(appSettings.accentColor.color)
  }
}
