import SwiftUI

// MARK: - 一般設定ビュー
struct GeneralSettingsView: View {
  @Binding var localICloudToggle: Bool
  @Binding var showingICloudErrorAlert: Bool
  @Binding var iCloudErrorMessage: String
  @ObservedObject var appSettings: AppSettings

  var body: some View {
    VStack(spacing: 16) {
      GroupBox {
        VStack(alignment: .leading, spacing: 12) {
          Toggle(
            String(localized: "enable_icloud_sync", table: "Settings"),
            isOn: Binding(
              get: {
                localICloudToggle
              },
              set: { newValue in
                localICloudToggle = newValue
                Task {
                  let result = await appSettings.attemptSetICloudSyncAsync(newValue)
                  await MainActor.run {
                    switch result {
                    case .success:
                      break
                    case .failure(let err):
                      localICloudToggle = appSettings.iCloudSyncEnabled
                      iCloudErrorMessage =
                        err.errorDescription
                        ?? String(localized: "icloud_sync_failed", table: "Settings")
                      showingICloudErrorAlert = true
                    }
                  }
                }
              }))

          if let blocked = appSettings.iCloudSyncBlockedReason {
            Text(blocked)
              .font(.caption)
              .foregroundColor(.red)
          }
        }
      }

      GroupBox {
        VStack(alignment: .leading, spacing: 12) {
          HStack {
            Text(String(localized: "accent_color", table: "Settings"))
            Spacer()
            Picker("", selection: $appSettings.accentColor) {
              ForEach(AppSettings.ThemeColor.allCases) { theme in
                HStack(spacing: 12) {
                  RoundedRectangle(cornerRadius: 4)
                    .fill(theme.color)
                    .frame(width: 18, height: 18)
                  Text(theme.localizedName)
                }
                .tag(theme)
              }
            }
            .pickerStyle(.menu)
          }
        }
      }

      GroupBox {
        Button {
          appSettings.showingSampleData = true
          appSettings.selectedTabIndex = 0
        } label: {
          Label(String(localized: "view_sample_data", table: "Home"), systemImage: "eye")
        }
        .buttonStyle(.borderless)
      }
    }
    .padding(.horizontal)
  }
}
