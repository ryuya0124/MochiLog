import SwiftUI

// MARK: - デバッグ設定ビュー
struct DebugSettingsView: View {
  @ObservedObject var appSettings: AppSettings

  var body: some View {
    VStack(spacing: 16) {
      GroupBox {
        VStack(alignment: .leading, spacing: 12) {
          Toggle(
            String(localized: "show_popup_on_load", table: "Support"),
            isOn: $appSettings.showPopupOnLoad)

          Divider()

          NavigationLink(destination: DebugLogsView()) {
            Label(
              String(localized: "view_error_logs", table: "Support"),
              systemImage: "exclamationmark.triangle")
          }
          .buttonStyle(.borderless)
        }
      }
    }
    .padding(.horizontal)
  }
}
