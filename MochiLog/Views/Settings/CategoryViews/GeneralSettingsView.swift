import SwiftUI

// MARK: - 一般設定ビュー
struct GeneralSettingsView: View {
  @ObservedObject var appSettings: AppSettings

  var body: some View {
    VStack(spacing: 16) {
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

      // iCloud同期設定（iPad用）
      if #available(iOS 17, *) {
        VStack(alignment: .leading, spacing: 8) {
          Text(String(localized: "icloud_sync_settings", defaultValue: "iCloud同期設定", table: "Settings"))
            .font(.headline)
            .padding(.horizontal, 4)
            .padding(.top, 8)
          
          ICloudSettingsContentView(appSettings: appSettings)
        }
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
              .foregroundStyle(appSettings.accentColor.color)
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
