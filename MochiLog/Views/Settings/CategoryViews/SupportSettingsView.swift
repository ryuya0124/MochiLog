import SwiftUI

// MARK: - サポート設定ビュー
struct SupportSettingsView: View {
  @StateObject private var appSettings = AppSettings.shared
  @State private var showingSupportForm = false
  @State private var showingTutorial = false
  @State private var showingDonation = false
  @State private var showingShortcutSetupPrompt = false

  var body: some View {
    VStack(spacing: 16) {
      // チュートリアル
      GroupBox {
        Button {
          showingTutorial = true
        } label: {
          HStack(spacing: 20) {
            Image(systemName: "lightbulb.fill")
              .font(.system(size: 32))
              .foregroundStyle(.yellow)
              .frame(width: 60)

            VStack(alignment: .leading, spacing: 4) {
              Text(String(localized: "tutorial", table: "Onboarding"))
                .font(.headline)
                .foregroundStyle(.primary)

              Text(String(localized: "tutorial_description", table: "Settings"))
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

      // ショートカットをセットアップ（未インストール時のみ表示）
      if !appSettings.isShortcutInstalled {
        GroupBox {
          Button(
            action: { SettingsRedirectHelper.openShortcutSetup() },
            label: {
              HStack(spacing: 20) {
                Image(systemName: "arrow.down.circle")
                  .font(.system(size: 32))
                  .foregroundStyle(.blue)
                  .frame(width: 60)

                VStack(alignment: .leading, spacing: 4) {
                  Text(String(localized: "setup_shortcut", table: "Settings"))
                    .font(.headline)
                    .foregroundStyle(.primary)

                  Text(String(localized: "setup_shortcut_description", table: "Settings"))
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
          )
          .buttonStyle(.plain)
        }
      }

      // 解析データページへ移動
      GroupBox {
        Button {
          SettingsRedirectHelper.openAnalyticsViaShortcut()
        } label: {
          HStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
              .font(.system(size: 32))
              .foregroundStyle(.blue)
              .frame(width: 60)

            VStack(alignment: .leading, spacing: 4) {
              Text(String(localized: "view_analytics_data", table: "Settings"))
                .font(.headline)
                .foregroundStyle(.primary)

              Text(String(localized: "view_analytics_data_description", table: "Settings"))
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

              Text(String(localized: "contact_support_description", table: "Settings"))
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

      // 支援
      GroupBox {
        Button {
          showingDonation = true
        } label: {
          HStack(spacing: 20) {
            Image(systemName: "heart.fill")
              .font(.system(size: 32))
              .foregroundStyle(.pink)
              .frame(width: 60)

            VStack(alignment: .leading, spacing: 4) {
              Text(String(localized: "donation_title", table: "Settings"))
                .font(.headline)
                .foregroundStyle(.primary)

              Text(String(localized: "donation_description_short", table: "Settings"))
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
    .onAppear {
      setupShortcutNotification()
    }
    .sheet(isPresented: $showingSupportForm) {
      SupportFormView()
    }
    .sheet(isPresented: $showingTutorial) {
      TutorialView()
    }
    .sheet(isPresented: $showingDonation) {
      DonationView()
    }
    .alert(
      String(localized: "shortcut_required_title", table: "Settings"),
      isPresented: $showingShortcutSetupPrompt
    ) {
      Button(String(localized: "setup_now", table: "Settings"), role: .none) {
        SettingsRedirectHelper.openShortcutSetup()
      }
      Button(String(localized: "cancel", table: "Common"), role: .cancel) {}
    } message: {
      Text(String(localized: "shortcut_required_message", table: "Settings"))
    }
  }

  private func setupShortcutNotification() {
    NotificationCenter.default.addObserver(
      forName: NSNotification.Name("ShortcutNotFound"),
      object: nil,
      queue: .main
    ) { _ in
      // ショートカットが見つからない場合はセットアップ誘導アラートを表示
      showingShortcutSetupPrompt = true
    }
  }
}
