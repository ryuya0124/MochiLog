import SwiftUI

// MARK: - サポート設定ビュー
struct SupportSettingsView: View {
  @Binding var showingTutorial: Bool
  @Binding var showingSupportForm: Bool
  @Binding var showingDonation: Bool

  var body: some View {
    VStack(spacing: 16) {
      GroupBox {
        VStack(spacing: 12) {
          Button(action: { showingTutorial = true }) {
            Label(String(localized: "view_tutorial", table: "Home"), systemImage: "book.fill")
          }
          .buttonStyle(.borderless)

          Divider()

          Button(action: { showingSupportForm = true }) {
            Label(
              String(localized: "contact_support", table: "Support"), systemImage: "envelope.fill")
          }
          .buttonStyle(.borderless)

          Divider()

          Button(action: { showingDonation = true }) {
            Label(String(localized: "donation_title", table: "Settings"), systemImage: "heart.fill")
          }
          .buttonStyle(.borderless)
        }
      }
    }
    .padding(.horizontal)
  }
}
