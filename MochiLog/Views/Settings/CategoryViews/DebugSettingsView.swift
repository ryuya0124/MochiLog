import SwiftUI

// MARK: - デバッグ設定ビュー
struct DebugSettingsView: View {
  @ObservedObject var appSettings: AppSettings

  var body: some View {
    VStack(spacing: 16) {
      // デバッグログ
      GroupBox {
        HStack(spacing: 20) {
          Image(systemName: "ant.fill")
            .font(.system(size: 36))
            .foregroundStyle(.purple)
            .frame(width: 60)

          VStack(alignment: .leading, spacing: 8) {
            Toggle(
              String(localized: "show_popup_on_load", table: "Support"),
              isOn: $appSettings.showPopupOnLoad
            )
            .font(.headline)

            Text(String(localized: "debug_popup_description", table: "Settings"))
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }
        }
        .padding(.vertical, 8)
      }

      // エラーログ
      GroupBox {
        NavigationLink(destination: DebugLogsView()) {
          HStack(spacing: 20) {
            Image(systemName: "doc.text.fill")
              .font(.system(size: 32))
              .foregroundStyle(.orange)
              .frame(width: 60)

            VStack(alignment: .leading, spacing: 4) {
              Text(String(localized: "view_error_logs", table: "Support"))
                .font(.headline)
                .foregroundStyle(.primary)

              Text(String(localized: "error_logs_description", table: "Settings"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
              .foregroundStyle(.secondary)
          }
          .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
      }
    }
    .padding(.horizontal)
  }
}
