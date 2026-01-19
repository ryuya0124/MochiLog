import SwiftData
import SwiftUI

// MARK: - データ管理設定ビュー
struct DataManagementSettingsView: View {
  @Binding var showingDeleteConfirmation: Bool
  @Binding var showingNoDataToDeleteAlert: Bool
  @Binding var showingDeviceDeletePicker: Bool
  @Query private var records: [BatteryRecord]

  private var availableDevices: [String] {
    Array(Set(records.map { $0.deviceName })).sorted()
  }

  var body: some View {
    VStack(spacing: 16) {
      GroupBox {
        VStack(spacing: 12) {
          Button(role: .destructive) {
            if records.isEmpty {
              showingNoDataToDeleteAlert = true
            } else {
              showingDeleteConfirmation = true
            }
          } label: {
            Label(
              String(localized: "delete_all_data", table: "Settings"), systemImage: "trash.fill")
          }
          .buttonStyle(.borderless)

          Divider()

          Button(role: .destructive) {
            if availableDevices.isEmpty {
              showingNoDataToDeleteAlert = true
            } else {
              showingDeviceDeletePicker = true
            }
          } label: {
            Label(String(localized: "delete_device_data", table: "Settings"), systemImage: "trash")
          }
          .buttonStyle(.borderless)
        }
      }
    }
    .padding(.horizontal)
  }
}
