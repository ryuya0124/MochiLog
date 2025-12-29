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
              Text(deviceName)
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
        prompt: String(localized: "search_device")
      )
      .navigationTitle(String(localized: "select_device_to_delete"))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(String(localized: "cancel")) {
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
