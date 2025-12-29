import MessageUI
import SwiftUI

// MARK: - 問い合わせの種類
enum InquiryType: String, CaseIterable, Identifiable {
  case bug = "inquiry_bug"
  case feature = "inquiry_feature"
  case question = "inquiry_question"
  case other = "inquiry_other"

  var id: String { rawValue }

  var localizedName: String {
    String(localized: String.LocalizationValue(rawValue))
  }
}

// MARK: - サポートフォームビュー
struct SupportFormView: View {
  @Environment(\.dismiss) private var dismiss
  @StateObject private var appSettings = AppSettings.shared

  @State private var name = ""
  @State private var email = ""
  @State private var inquiryType: InquiryType = .question
  @State private var message = ""
  @State private var showingMailError = false
  @State private var showingValidationError = false
  @State private var isShowingMailCompose = false

  private var isFormValid: Bool {
    !name.trimmingCharacters(in: .whitespaces).isEmpty
      && !email.trimmingCharacters(in: .whitespaces).isEmpty
      && !message.trimmingCharacters(in: .whitespaces).isEmpty
  }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          TextField(String(localized: "your_name", table: "Support"), text: $name)
            .textContentType(.name)

          TextField(String(localized: "email_address", table: "Support"), text: $email)
            .textContentType(.emailAddress)
            .keyboardType(.emailAddress)
            .autocapitalization(.none)
        }

        Section(String(localized: "inquiry_type", table: "Support")) {
          Picker(String(localized: "inquiry_type", table: "Support"), selection: $inquiryType) {
            ForEach(InquiryType.allCases) { type in
              Text(type.localizedName).tag(type)
            }
          }
          .pickerStyle(.menu)
        }

        Section {
          TextEditor(text: $message)
            .frame(minHeight: 150)
        } header: {
          Text(String(localized: "message", table: "Support"))
        } footer: {
          Text(String(localized: "device_info_included", table: "Common"))
            .foregroundStyle(.secondary)
        }
      }
      .navigationTitle(String(localized: "contact_form", table: "Support"))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(String(localized: "cancel", table: "Common")) { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button(String(localized: "send", table: "Common")) {
            sendEmail()
          }
          .disabled(!isFormValid)
        }
      }
      .alert(String(localized: "mail_not_configured", table: "Support"), isPresented: $showingMailError) {
        Button(String(localized: "ok", table: "Common"), role: .cancel) {}
      } message: {
        Text(String(localized: "mail_not_configured_message", table: "Support"))
      }
      .alert(String(localized: "error", table: "Common"), isPresented: $showingValidationError) {
        Button(String(localized: "ok", table: "Common"), role: .cancel) {}
      } message: {
        Text(String(localized: "required_fields_empty", table: "Support"))
      }
      .sheet(isPresented: $isShowingMailCompose) {
        MailComposeView(
          recipients: ["support@mochilog.ryuya-dev.net"],
          subject: "[MochiLog] \(inquiryType.localizedName)",
          body: composeEmailBody()
        ) { result in
          if result == .sent {
            dismiss()
          }
        }
      }
    }
  }

  private func sendEmail() {
    guard isFormValid else {
      showingValidationError = true
      return
    }

    if MFMailComposeViewController.canSendMail() {
      isShowingMailCompose = true
    } else {
      // メールアプリが使えない場合はmailto URLを試す
      let subject = "[MochiLog] \(inquiryType.localizedName)"
      let body = composeEmailBody()

      if let encoded = "mailto:support@mochilog.ryuya-dev.net?subject=\(subject)&body=\(body)"
        .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
        let url = URL(string: encoded)
      {
        UIApplication.shared.open(url) { success in
          if success {
            dismiss()
          } else {
            showingMailError = true
          }
        }
      } else {
        showingMailError = true
      }
    }
  }

  private func composeEmailBody() -> String {
    """
    名前 / Name: \(name)
    メール / Email: \(email)
    種別 / Type: \(inquiryType.localizedName)

    メッセージ / Message:
    \(message)

    \(appSettings.getDeviceInfo())
    """
  }
}

// MARK: - メール作成ビュー
struct MailComposeView: UIViewControllerRepresentable {
  let recipients: [String]
  let subject: String
  let body: String
  let onComplete: (MFMailComposeResult) -> Void

  func makeUIViewController(context: Context) -> MFMailComposeViewController {
    let composer = MFMailComposeViewController()
    composer.mailComposeDelegate = context.coordinator
    composer.setToRecipients(recipients)
    composer.setSubject(subject)
    composer.setMessageBody(body, isHTML: false)
    return composer
  }

  func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

  func makeCoordinator() -> Coordinator {
    Coordinator(onComplete: onComplete)
  }

  class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
    let onComplete: (MFMailComposeResult) -> Void

    init(onComplete: @escaping (MFMailComposeResult) -> Void) {
      self.onComplete = onComplete
    }

    func mailComposeController(
      _ controller: MFMailComposeViewController,
      didFinishWith result: MFMailComposeResult,
      error: Error?
    ) {
      controller.dismiss(animated: true)
      onComplete(result)
    }
  }
}

#Preview {
  SupportFormView()
}
