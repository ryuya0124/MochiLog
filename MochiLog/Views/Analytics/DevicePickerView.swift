import SwiftUI

struct DevicePickerView: View {
  let deviceNames: [String]
  @Binding var selectedDevice: String?

  @State private var isShowingDevicePicker: Bool = false
  @State private var deviceSearchQuery: String = ""
  @StateObject private var appSettings = AppSettings.shared

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .center) {
        VStack(alignment: .leading, spacing: 4) {
          Text(String(localized: "select_a_device", table: "Analytics"))
            .font(.headline)
            .foregroundStyle(.secondary)

          Text(String(localized: "select_a_device_description", table: "Analytics"))
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(2)
        }

        Spacer()

        Button {
          deviceSearchQuery = ""
          isShowingDevicePicker = true
        } label: {
          HStack(spacing: 8) {
            Text(selectedDevice ?? String(localized: "all_devices", table: "Common"))
              .foregroundStyle(.primary)
            Image(systemName: "chevron.down")
              .foregroundStyle(.secondary)
          }
          .padding(.vertical, 8)
          .padding(.horizontal, 12)
          .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
        }
        .accessibilityLabel(Text(String(localized: "select_a_device", table: "Analytics")))
        .frame(minWidth: 140)
        .sheet(isPresented: $isShowingDevicePicker) {
          NavigationStack {
            List {
              Button {
                selectedDevice = nil
                isShowingDevicePicker = false
              } label: {
                HStack {
                  Text(String(localized: "all_devices", table: "Common"))
                    .foregroundStyle(appSettings.accentColor.color)
                  Spacer()
                  if selectedDevice == nil {
                    Image(systemName: "checkmark")
                      .foregroundStyle(appSettings.accentColor.color)
                  }
                }
              }

              ForEach(
                deviceNames.filter {
                  deviceSearchQuery.isEmpty
                    ? true : $0.localizedCaseInsensitiveContains(deviceSearchQuery)
                }, id: \.self
              ) { device in
                Button {
                  selectedDevice = device
                  isShowingDevicePicker = false
                } label: {
                  HStack {
                    Text(device)
                    Spacer()
                    if selectedDevice == device {
                      Image(systemName: "checkmark")
                        .foregroundStyle(appSettings.accentColor.color)
                    }
                  }
                }
                .foregroundStyle(.primary)
              }
            }
            .searchable(text: $deviceSearchQuery)
            .navigationTitle(Text(String(localized: "select_a_device", table: "Analytics")))
            .toolbar {
              ToolbarItem(placement: .cancellationAction) {
                Button(String(localized: "cancel", table: "Common")) {
                  isShowingDevicePicker = false
                }
                .tint(.primary)
              }
            }
          }
        }
      }
    }
  }
}

// MARK: - デバイスチップ
struct DeviceChip: View {
  let name: String
  let isSelected: Bool
  let action: () -> Void
  @StateObject private var appSettings = AppSettings.shared

  var body: some View {
    Button(action: action) {
      Text(name)
        .font(.subheadline)
        .fontWeight(isSelected ? .semibold : .regular)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
          isSelected
            ? appSettings.accentColor.color.opacity(0.2)
            : Color(.systemGray5)
        )
        .foregroundStyle(isSelected ? appSettings.accentColor.color : .primary)
        .clipShape(Capsule())
        .overlay(
          Capsule()
            .stroke(isSelected ? appSettings.accentColor.color : Color.clear, lineWidth: 1.5)
        )
    }
    .buttonStyle(.plain)
  }
}

#Preview {
  DevicePickerView(deviceNames: ["iPhone A", "iPad B"], selectedDevice: .constant(nil))
}
