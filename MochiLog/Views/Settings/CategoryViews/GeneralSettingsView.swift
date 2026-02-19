import SwiftUI

// MARK: - 一般設定ビュー
struct GeneralSettingsView: View {
  @Binding var localICloudToggle: Bool
  @Binding var showingICloudErrorAlert: Bool
  @Binding var iCloudErrorMessage: String
  @ObservedObject var appSettings: AppSettings

  var body: some View {
    VStack(spacing: 16) {
      // iCloud同期（iPad向けレイアウト）- iOS 17以降のみ表示
      if #available(iOS 17, *) {
        GroupBox {
          HStack(spacing: 20) {
            // アイコン
            Image(systemName: "icloud.fill")
              .font(.system(size: 40))
              .foregroundStyle(
                LinearGradient(
                  colors: [.blue, .cyan],
                  startPoint: .topLeading,
                  endPoint: .bottomTrailing
                )
              )
              .frame(width: 60, height: 60)

            VStack(alignment: .leading, spacing: 8) {
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
                  })
              )
              .font(.headline)

              Text(String(localized: "icloud_sync_description", table: "Settings"))
                .font(.subheadline)
                .foregroundStyle(.secondary)

              if let blocked = appSettings.iCloudSyncBlockedReason {
                Label(blocked, systemImage: "exclamationmark.triangle.fill")
                  .font(.caption)
                  .foregroundColor(.red)
              }
            }
          }
          .padding(.vertical, 8)
        }
      }

      // アクセントカラー
      GroupBox {
        HStack(spacing: 20) {
          // カラーパレットアイコン
          Image(systemName: "paintpalette.fill")
            .font(.system(size: 36))
            .foregroundStyle(appSettings.accentColor.color)
            .frame(width: 60, height: 60)

          VStack(alignment: .leading, spacing: 8) {
            HStack {
              Text(String(localized: "accent_color", table: "Settings"))
                .font(.headline)
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

            Text(String(localized: "accent_color_description", table: "Settings"))
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }
        }
        .padding(.vertical, 8)
      }

      // サンプルデータ表示
      GroupBox {
        Button {
          appSettings.showingSampleData = true
          appSettings.selectedTabIndex = 0
        } label: {
          HStack(spacing: 20) {
            Image(systemName: "eye.fill")
              .font(.system(size: 32))
              .foregroundStyle(.blue)
              .frame(width: 60)

            VStack(alignment: .leading, spacing: 4) {
              Text(String(localized: "view_sample_data", table: "Home"))
                .font(.headline)
                .foregroundStyle(.primary)

              Text(String(localized: "sample_data_description", table: "Settings"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
              .foregroundStyle(.secondary)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .contentShape(Rectangle())
          .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
      }
    }
    .padding(.horizontal)
  }
}
