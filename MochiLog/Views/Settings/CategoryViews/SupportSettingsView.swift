import SwiftUI

// MARK: - サポート設定ビュー
struct SupportSettingsView: View {
  @State private var showingSupportForm = false

  var body: some View {
    VStack(spacing: 16) {
      // バージョン情報
      GroupBox {
        VStack(alignment: .leading, spacing: 12) {
          HStack(spacing: 20) {
            Image(systemName: "info.circle.fill")
              .font(.system(size: 36))
              .foregroundStyle(.blue)
              .frame(width: 60)

            VStack(alignment: .leading, spacing: 8) {
              Text(String(localized: "app_version", table: "Settings"))
                .font(.headline)

              if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
              {
                Text("Version \(version) (Build \(build))")
                  .font(.subheadline)
                  .foregroundStyle(.secondary)
              }
            }

            Spacer()
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
      }

      // フィードバック
      GroupBox {
        Button {
          showingSupportForm = true
        } label: {
          HStack(spacing: 20) {
            Image(systemName: "envelope.fill")
              .font(.system(size: 32))
              .foregroundStyle(.green)
              .frame(width: 60)

            VStack(alignment: .leading, spacing: 4) {
              Text(String(localized: "contact_support", table: "Support"))
                .font(.headline)
                .foregroundStyle(.primary)

              Text("バグ報告や機能リクエストをお寄せください")
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
    .sheet(isPresented: $showingSupportForm) {
      SupportFormView()
    }
  }
}
