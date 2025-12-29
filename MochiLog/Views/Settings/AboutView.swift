import SwiftUI

// MARK: - アプリについて画面
struct AboutView: View {
  @State private var showingPrivacyPolicy = false
  @State private var showingTermsOfUse = false
  @State private var showingLicenses = false

  private var appVersion: String {
    let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    return "\(version) (\(build))"
  }

  var body: some View {
    List {
      // MARK: - 法的情報
      Section {
        Button(action: { showingTermsOfUse = true }) {
          Label(String(localized: "terms_of_use", table: "Legal"), systemImage: "doc.plaintext")
        }

        Button(action: { showingPrivacyPolicy = true }) {
          Label(
            String(localized: "privacy_policy", table: "Legal"), systemImage: "hand.raised.fill")
        }

        Button(action: { showingLicenses = true }) {
          Label(String(localized: "licenses", table: "Settings"), systemImage: "doc.text")
        }
      }

      // MARK: - アプリ情報
      Section {
        Link(destination: URL(string: "https://github.com/ryuya0124/MochiLog")!) {
          Label(String(localized: "view_on_github", table: "Support"), systemImage: "link")
        }

        LabeledContent(String(localized: "app_version", table: "Settings"), value: appVersion)
      }
    }
    .navigationTitle(String(localized: "about_app", table: "Settings"))
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
  NavigationStack {
    AboutView()
  }
}
