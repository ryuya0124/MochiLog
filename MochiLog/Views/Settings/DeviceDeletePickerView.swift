import SwiftUI

/// デバイスごとのデータ削除用のデバイス選択ビュー
struct DeviceDeletePickerView: View {
  @Environment(\.dismiss) private var dismiss
  let availableDevices: [String]
  let onSelect: (String) -> Void

  @State private var searchText = ""

  private var filteredDevices: [String] {
    if searchText.isEmpty {
      return availableDevices
    } else {
      return availableDevices.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }
  }

  var body: some View {
    NavigationStack {
      List {
        ForEach(filteredDevices, id: \.self) { deviceName in
          Button(action: {
            onSelect(deviceName)
            dismiss()
          }) {
            HStack {
              Text(DeviceLibrary.localizedName(for: deviceName))
                .foregroundStyle(.primary)
              Spacer()
              Image(systemName: "trash")
                .foregroundStyle(.red)
            }
          }
        }
      }
      .searchable(
        text: $searchText,
        placement: .navigationBarDrawer(displayMode: .always),
        prompt: L10n.string("search_device", table: "Common")
      )
      .navigationTitle(L10n.string("select_device_to_delete", table: "Settings"))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(L10n.string("cancel", table: "Common")) {
            dismiss()
          }
        }
      }
    }
  }
}

#Preview {
  DeviceDeletePickerView(
    availableDevices: ["iPhone 15 Pro", "iPhone 14", "iPad Pro"],
    onSelect: { _ in }
  )
}
