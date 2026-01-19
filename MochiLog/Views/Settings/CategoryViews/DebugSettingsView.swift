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

            Text("アプリ起動時にデバッグポップアップを表示")
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }
        }
        .padding(.vertical, 8)
      }

      // エラーログ
      GroupBox {
        NavigationLink(destination: DebugLogsView()) {
          HStack(spacing: 16) {
            Image(systemName: "doc.text.fill")
              .font(.system(size: 32))
              .foregroundStyle(.orange)
              .frame(width: 50)

            VStack(alignment: .leading, spacing: 4) {
              Text(String(localized: "view_error_logs", table: "Support"))
                .font(.headline)
                .foregroundStyle(.primary)

              Text("アプリのエラーログを確認します")
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
