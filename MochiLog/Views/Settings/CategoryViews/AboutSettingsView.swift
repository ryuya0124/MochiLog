import SwiftUI

// MARK: - アプリについて（iPad用）
struct AboutSettingsView: View {
  @State private var showingPrivacyPolicy = false
  @State private var showingTermsOfUse = false
  @State private var showingLicenses = false

  private var appVersion: String {
    let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    return "Version \(version) (Build \(build))"
  }

  var body: some View {
    VStack(spacing: 16) {
      // アプリ情報
      GroupBox {
        HStack(spacing: 20) {
          Image(systemName: "info.circle.fill")
            .font(.system(size: 32))
            .foregroundStyle(.blue)
            .frame(width: 60)

          VStack(alignment: .leading, spacing: 4) {
            Text(String(localized: "app_version", table: "Settings"))
              .font(.headline)

            Text(appVersion)
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }

          Spacer()
        }
        .padding(.vertical, 8)
      }

      // 利用規約
      GroupBox {
        Button(action: { showingTermsOfUse = true }) {
          HStack(spacing: 20) {
            Image(systemName: "doc.plaintext")
              .font(.system(size: 32))
              .foregroundStyle(.purple)
              .frame(width: 60)

            VStack(alignment: .leading, spacing: 4) {
              Text(String(localized: "terms_of_use", table: "Legal"))
                .font(.headline)
                .foregroundStyle(.primary)

              Text("利用規約を確認できます")
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

      // プライバシーポリシー
      GroupBox {
        Button(action: { showingPrivacyPolicy = true }) {
          HStack(spacing: 20) {
            Image(systemName: "hand.raised.fill")
              .font(.system(size: 32))
              .foregroundStyle(.orange)
              .frame(width: 60)

            VStack(alignment: .leading, spacing: 4) {
              Text(String(localized: "privacy_policy", table: "Legal"))
                .font(.headline)
                .foregroundStyle(.primary)

              Text("プライバシーに関する内容を確認")
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

      // ライセンス
      GroupBox {
        Button(action: { showingLicenses = true }) {
          HStack(spacing: 20) {
            Image(systemName: "doc.text")
              .font(.system(size: 32))
              .foregroundStyle(.teal)
              .frame(width: 60)

            VStack(alignment: .leading, spacing: 4) {
              Text(String(localized: "licenses", table: "Settings"))
                .font(.headline)
                .foregroundStyle(.primary)

              Text("利用しているライブラリの情報")
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

      // リンク
      GroupBox {
        Link(destination: URL(string: "https://github.com/ryuya0124/MochiLog")!) {
          HStack(spacing: 20) {
            Image(systemName: "link")
              .font(.system(size: 32))
              .foregroundStyle(.blue)
              .frame(width: 60)

            VStack(alignment: .leading, spacing: 4) {
              Text(String(localized: "view_on_github", table: "Support"))
                .font(.headline)
                .foregroundStyle(.primary)

              Text("GitHubでソースを見る")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "arrow.up.right")
              .foregroundStyle(.secondary)
          }
        }
        .tint(.primary)
        .padding(.vertical, 8)
      }
    }
    .padding(.horizontal)
    .sheet(isPresented: $showingPrivacyPolicy) {
      PrivacyPolicyView()
    }
    .sheet(isPresented: $showingTermsOfUse) {
      TermsOfUseView()
    }
    .sheet(isPresented: $showingLicenses) {
      LicenseView()
    }
  }
}

#Preview {
  AboutSettingsView()
}
