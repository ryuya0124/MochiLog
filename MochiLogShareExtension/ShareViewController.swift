//
//  ShareViewController.swift
//  MochiLogShareExtension
//
//  Created by りゅうや on 2025/12/22.
//

import Social
import UIKit
import UniformTypeIdentifiers

// 変更点1: SLComposeServiceViewController ではなく UIViewController を継承
class ShareViewController: UIViewController {
  private var hasProcessed = false

  override func viewDidLoad() {
    super.viewDidLoad()
    // 変更点2: 背景を透明にして、ユーザーには「何も表示されていない」ように見せる
    view.backgroundColor = .clear
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    // 画面が表示された瞬間（実際には透明ですが）に処理を開始
    processContentIfNeeded()
  }

  // SLComposeServiceViewController 特有のメソッド（isContentValidなど）は全て削除

  private func processContentIfNeeded() {
    guard !hasProcessed else { return }
    hasProcessed = true

    let items = extensionContext?.inputItems as? [NSExtensionItem] ?? []
    let providers = items.flatMap { $0.attachments ?? [] }

    guard let provider = providers.first(where: { supportsText($0) }) else {
      completeAndClose()
      return
    }

    let typeIdentifier = preferredTextType(for: provider)

    provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { [weak self] item, error in
      guard let self = self else { return }

      if let error = error {
        NSLog("Share extension failed to load item: \(error.localizedDescription)")
        self.completeAndClose()
        return
      }

      guard let sharedText = self.extractText(from: item), !sharedText.isEmpty else {
        self.completeAndClose()
        return
      }

      self.saveSharedText(sharedText)
      self.completeAndClose()
    }
  }

  private func saveSharedText(_ text: String) {
    // 本体アプリとIDが一致しているか要確認
    let userDefaults = UserDefaults(suiteName: "group.net.ryuya-dev.MochiLog")
    userDefaults?.set(text, forKey: "sharedLogText")
    userDefaults?.synchronize()
  }

  private func supportsText(_ provider: NSItemProvider) -> Bool {
    provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier)
      || provider.hasItemConformingToTypeIdentifier(UTType.text.identifier)
      || provider.hasItemConformingToTypeIdentifier(UTType.utf8PlainText.identifier)
      || provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
  }

  private func preferredTextType(for provider: NSItemProvider) -> String {
    if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
      return UTType.plainText.identifier
    }
    if provider.hasItemConformingToTypeIdentifier(UTType.text.identifier) {
      return UTType.text.identifier
    }
    if provider.hasItemConformingToTypeIdentifier(UTType.utf8PlainText.identifier) {
      return UTType.utf8PlainText.identifier
    }
    return UTType.fileURL.identifier
  }

  private func extractText(from item: NSSecureCoding?) -> String? {
    if let text = item as? String {
      return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    if let data = item as? Data, let decoded = String(data: data, encoding: .utf8) {
      return decoded.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    if let url = item as? URL {
      // ファイルアクセスの権限処理
      let isSecurityScoped = url.startAccessingSecurityScopedResource()
      defer {
        if isSecurityScoped { url.stopAccessingSecurityScopedResource() }
      }

      if let content = try? String(contentsOf: url, encoding: .utf8) {
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
      }
    }
    return nil
  }

  private func completeAndClose() {
    DispatchQueue.main.async {
      // URLスキームを開く処理
      // UIが見えないため、遅延なしで即座に開くのがベスト
      if let url = URL(string: "mochilog://processSharedLog") {
        self.openMainApp(url: url)
      } else {
        self.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
      }
    }
  }

  // UIViewControllerでのURLオープンのためのヘルパー
  private func openMainApp(url: URL) {
    var responder: UIResponder? = self
    let selector = sel_registerName("openURL:")

    // Responder Chainをたどって openURL を実行できるものを探す
    while let r = responder {
      if r.responds(to: selector) {
        r.perform(selector, with: url)
        break
      }
      responder = r.next
    }

    self.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
  }
}
