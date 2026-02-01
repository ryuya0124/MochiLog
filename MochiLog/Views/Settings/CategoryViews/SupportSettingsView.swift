import SwiftUI

// MARK: - サポート設定ビュー
struct SupportSettingsView: View {
  @State private var showingSupportForm = false
  @State private var showingTutorial = false
  @State private var showingDonation = false

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

              Text("基本操作や設定の流れを確認できます")
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

              Text("開発を応援していただけると嬉しいです")
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
    .sheet(isPresented: $showingTutorial) {
      TutorialView()
    }
    .sheet(isPresented: $showingDonation) {
      DonationView()
    }
  }
}
