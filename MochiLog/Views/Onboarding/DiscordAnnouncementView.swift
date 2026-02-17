import SwiftUI

/// Discord\u30b5\u30fc\u30d0\u30fc\u306e\u304a\u77e5\u3089\u305b\u3092\u8868\u793a\u3059\u308b\u30d3\u30e5\u30fc\uff08\u30a2\u30c3\u30d7\u30c7\u30fc\u30c8\u5f8c\u306b1\u56de\u306e\u307f\uff09
struct DiscordAnnouncementView: View {
  @Environment(\.dismiss) private var dismiss
  @StateObject private var appSettings = AppSettings.shared

  var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
        // \u30b3\u30f3\u30c6\u30f3\u30c4\u30a8\u30ea\u30a2
        ScrollView {
          VStack(spacing: 24) {
            // \u30a2\u30a4\u30b3\u30f3
            Image(systemName: "bubble.left.and.bubble.right.fill")
              .font(.system(size: 56))
              .foregroundStyle(.blue.gradient)
              .padding(.top, 40)

            // \u30bf\u30a4\u30c8\u30eb\u3068\u8aac\u660e
            VStack(spacing: 12) {
              Text(String(localized: "discord_announcement_title", table: "Onboarding"))
                .font(.title2.bold())

              Text(String(localized: "discord_announcement_description", table: "Onboarding"))
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 32)

            // Discord\u30ab\u30fc\u30c9
            VStack(alignment: .leading, spacing: 16) {
              HStack(spacing: 12) {
                Image(systemName: "bubble.left.and.text.bubble.right.fill")
                  .font(.title3)
                  .foregroundStyle(.blue)

                VStack(alignment: .leading, spacing: 4) {
                  Text(String(localized: "discord_announcement_card_title", table: "Onboarding"))
                    .font(.headline)

                  Text(String(localized: "discord_announcement_card_subtitle", table: "Onboarding"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }

                Spacer()
              }

              Divider()

              // \u30e1\u30ea\u30c3\u30c8\u30ea\u30b9\u30c8
              VStack(alignment: .leading, spacing: 12) {
                FeatureRow(
                  icon: "bolt.fill",
                  text: String(localized: "discord_announcement_feature_fast", table: "Onboarding"),
                  color: .orange
                )

                FeatureRow(

                  icon: "lightbulb.fill",
                  text: String(
                    localized: "discord_announcement_feature_ideas", table: "Onboarding"),
                  color: .yellow
                )
              }
            }
            .padding(20)
            .background {
              RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
            }
            .overlay {
              RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.quaternary, lineWidth: 1)
            }
            .padding(.horizontal, 20)

            // Discord\u3078\u306e\u30ea\u30f3\u30af\u30dc\u30bf\u30f3
            Button(action: {
              if let url = URL(string: AppSettings.discordURL) {
                UIApplication.shared.open(url)
              }
            }) {
              Label(
                String(localized: "discord_announcement_join_button", table: "Onboarding"),
                systemImage: "arrow.up.forward.app"
              )
              .font(.headline)
              .frame(maxWidth: .infinity)
              .padding(.vertical, 14)
              .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                  .fill(.blue.gradient)
              }
              .foregroundStyle(.white)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            // \u6ce8\u610f\u66f8\u304d
            Text(String(localized: "discord_announcement_note", table: "Onboarding"))
              .font(.caption)
              .foregroundStyle(.tertiary)
              .multilineTextAlignment(.center)
              .padding(.horizontal, 32)
              .padding(.bottom, 20)
          }
        }

        // \u30dc\u30c8\u30e0\u30a8\u30ea\u30a2\uff08\u9589\u3058\u308b\u30dc\u30bf\u30f3\uff09
        VStack(spacing: 0) {
          Divider()

          Button(action: {
            dismiss()
          }) {
            Text(String(localized: "discord_announcement_close_button", table: "Onboarding"))
              .font(.headline)
              .frame(maxWidth: .infinity)
              .padding(.vertical, 18)
          }
          .buttonStyle(.plain)
          .foregroundStyle(appSettings.accentColor.color)
          .padding(.horizontal, 20)
          .padding(.vertical, 8)
        }
        .background(.ultraThinMaterial)
      }
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .principal) {
          // \u30bf\u30a4\u30c8\u30eb\u3092\u5c0f\u3055\u304f\u8868\u793a
          Text(String(localized: "discord_announcement_nav_title", table: "Onboarding"))
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.secondary)
        }
      }
    }
  }
}

// MARK: - Feature Row Component
private struct FeatureRow: View {
  let icon: String
  let text: String
  let color: Color

  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: icon)
        .font(.body)
        .foregroundStyle(color)
        .frame(width: 24)

      Text(text)
        .font(.subheadline)
        .foregroundStyle(.primary)

      Spacer()
    }
  }
}

#Preview {
  DiscordAnnouncementView()
}
