//
//  ShareViewController.swift
//  MochiLogShareExtension
//
//  Created by りゅうや on 2025/12/22.
//

import OSLog
import Social
import UIKit
import UniformTypeIdentifiers

// 変更点1: SLComposeServiceViewController ではなく UIViewController を継承
class ShareViewController: UIViewController {
  private var hasProcessed = false
  private let logger = Logger(subsystem: "net.ryuya-dev.MochiLog", category: "ShareExtension")

  private func openMainApp(candidateURLs: [URL], context: NSExtensionContext) {
    let uniqueURLs = Array(NSOrderedSet(array: candidateURLs)) as? [URL] ?? candidateURLs
    guard !uniqueURLs.isEmpty else {
      logger.notice("openMainApp: no candidate URLs")
      context.completeRequest(returningItems: nil, completionHandler: nil)
      return
    }

    func attempt(_ index: Int) {
      if index >= uniqueURLs.count {
        logger.notice("openMainApp: all candidates failed -> presenting alert")
        DispatchQueue.main.async {
          self.presentOpenAlert(url: uniqueURLs[0])
        }
        return
      }

      let url = uniqueURLs[index]
      NSLog("ShareExtension: attempting extensionContext.open URL=\(url.absoluteString)")
      logger.notice("attempting extensionContext.open URL=\(url.absoluteString, privacy: .public)")
      // Ensure open is invoked on main thread; completion may arrive on background.
      DispatchQueue.main.async {
        context.open(url) { [weak self] success in
          guard let self = self else { return }
          NSLog("ShareExtension: extensionContext.open completion success=\(success)")
          self.logger.notice("extensionContext.open completion success=\(success)")

          DispatchQueue.main.async {
            if success {
              DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.logger.notice("open success -> completeRequest")
                context.completeRequest(returningItems: nil, completionHandler: nil)
              }
            } else {
              attempt(index + 1)
            }
          }
        }
      }
    }

    attempt(0)
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    // 変更点2: 背景を透明にして、ユーザーには「何も表示されていない」ように見せる
    view.backgroundColor = .clear
  }

  // 失敗時フォールバック: ユーザーに「開く」を提示
  private func presentOpenAlert(url: URL) {
    NSLog("ShareExtension: presentOpenAlert called")
    logger.notice("presentOpenAlert called")

    let alert = UIAlertController(title: nil, message: "MochiLogで開きますか？", preferredStyle: .alert)
    alert.addAction(
      UIAlertAction(
        title: "開く",
        style: .default,
        handler: { [weak self] _ in
          guard let self = self else { return }
          guard let context = self.extensionContext else {
            self.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
            return
          }

          context.open(url) { success in
            NSLog("ShareExtension: retry open completion success=\(success)")
            self.logger.notice("retry open completion success=\(success)")
            if success {
              DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.logger.notice("retry open success -> completeRequest")
                context.completeRequest(returningItems: nil, completionHandler: nil)
              }
            } else {
              DispatchQueue.main.async {
                let fail = UIAlertController(
                  title: nil,
                  message: "MochiLogを開けませんでした。ホーム画面からMochiLogを開いてください。",
                  preferredStyle: .alert)
                fail.addAction(
                  UIAlertAction(
                    title: "OK",
                    style: .default,
                    handler: { _ in
                      self.logger.notice("retry open failed -> completeRequest")
                      context.completeRequest(returningItems: nil, completionHandler: nil)
                    }))
                self.present(fail, animated: true, completion: nil)
              }
            }
          }
        }))
    alert.addAction(
      UIAlertAction(
        title: "キャンセル",
        style: .cancel,
        handler: { [weak self] _ in
          self?.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
        }))

    if presentedViewController == nil {
      self.present(alert, animated: true, completion: nil)
    } else {
      self.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    // Ensure the host UI remains visually transparent.
    view.window?.backgroundColor = .clear
    // Slight delay to let the host settle, then start processing.
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
      self.processContentIfNeeded()
    }
  }

  // SLComposeServiceViewController 特有のメソッド（isContentValidなど）は全て削除

  private func processContentIfNeeded() {
    guard !hasProcessed else { return }
    hasProcessed = true
    NSLog("ShareExtension: processContentIfNeeded start")
    logger.notice("processContentIfNeeded start")

    let items = extensionContext?.inputItems as? [NSExtensionItem] ?? []
    let providers = items.flatMap { $0.attachments ?? [] }

    NSLog("ShareExtension: found providers count=\(providers.count)")
    guard let provider = providers.first(where: { supportsText($0) }) else {
      NSLog("ShareExtension: no provider with text found")
      logger.notice("no provider with text found")
      completeAndClose()
      return
    }
    NSLog("ShareExtension: provider selected: \(provider)")

    // Always prefer loadObject(NSString) when available.
    // This usually avoids the internal "expectedValueClass nil" warning that can appear with loadItem-based paths.
    if provider.canLoadObject(ofClass: NSString.self) {
      provider.loadObject(ofClass: NSString.self) { [weak self] object, error in
        guard let self = self else { return }

        if let error = error {
          NSLog("ShareExtension: failed to load NSString object: \(error.localizedDescription)")
          self.logger.notice(
            "failed to load NSString object: \(error.localizedDescription, privacy: .public)")
          self.completeAndClose()
          return
        }

        let str = object as? NSString
        NSLog("ShareExtension: loadObject(NSString) returned length=\(str?.length ?? 0)")
        self.logger.notice("loadObject(NSString) returned length=\(str?.length ?? 0)")

        guard let sharedText = self.extractText(from: str), !sharedText.isEmpty else {
          NSLog("ShareExtension: extracted text empty or nil")
          self.logger.notice("extracted text empty or nil")
          self.completeAndClose()
          return
        }

        NSLog("ShareExtension: extracted text length=\(sharedText.count)")
        self.saveSharedText(sharedText)
        NSLog("ShareExtension: saved shared text to app group")
        self.completeAndClose()
      }
      return
    }

    // Next: file URL
    if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
      if provider.canLoadObject(ofClass: URL.self) {
        _ = provider.loadObject(ofClass: URL.self) { [weak self] object, error in
          guard let self = self else { return }

          if let error = error {
            NSLog("ShareExtension: failed to load URL object: \(error.localizedDescription)")
            self.logger.notice(
              "failed to load URL object: \(error.localizedDescription, privacy: .public)")
            self.completeAndClose()
            return
          }

          let url = object
          NSLog("ShareExtension: loadObject(URL) returned url=\(String(describing: url))")

          guard let sharedText = self.extractText(from: url as NSSecureCoding?), !sharedText.isEmpty
          else {
            NSLog("ShareExtension: extracted text empty or nil")
            self.completeAndClose()
            return
          }

          self.saveSharedText(sharedText)
          NSLog("ShareExtension: saved shared text to app group")
          self.completeAndClose()
        }
        return
      }

      provider.loadFileRepresentation(forTypeIdentifier: UTType.fileURL.identifier) {
        [weak self] url, error in
        guard let self = self else { return }

        if let error = error {
          NSLog("ShareExtension: failed to load file representation: \(error.localizedDescription)")
          self.completeAndClose()
          return
        }

        guard let url = url else {
          NSLog("ShareExtension: file representation url nil")
          self.completeAndClose()
          return
        }

        NSLog("ShareExtension: loadFileRepresentation returned url=\(url.absoluteString)")
        guard let sharedText = self.extractText(from: url as NSSecureCoding?), !sharedText.isEmpty
        else {
          NSLog("ShareExtension: extracted text empty or nil")
          self.completeAndClose()
          return
        }

        self.saveSharedText(sharedText)
        NSLog("ShareExtension: saved shared text to app group")
        self.completeAndClose()
      }
      return
    }

    // Last resort: data representation (try multiple candidate types)
    let typeIdentifier = preferredTextType(for: provider)
    provider.loadDataRepresentation(forTypeIdentifier: typeIdentifier) { [weak self] data, error in
      guard let self = self else { return }

      if let error = error {
        NSLog("ShareExtension: failed to load data representation: \(error.localizedDescription)")
        self.completeAndClose()
        return
      }

      guard let data = data else {
        NSLog("ShareExtension: data representation nil")
        self.completeAndClose()
        return
      }

      let decoded = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .utf16)
      guard let sharedText = decoded?.trimmingCharacters(in: .whitespacesAndNewlines),
        !sharedText.isEmpty
      else {
        NSLog("ShareExtension: extracted text empty or nil")
        self.completeAndClose()
        return
      }

      NSLog("ShareExtension: extracted text length=\(sharedText.count)")
      self.saveSharedText(sharedText)
      NSLog("ShareExtension: saved shared text to app group")
      self.completeAndClose()
    }
    return
  }

  private func completeAndClose() {
    NSLog("ShareExtension: completeAndClose -> openMainApp")
    logger.notice("completeAndClose -> openMainApp")

    guard let context = extensionContext else { return }

    let candidates: [URL] = [
      URL(string: "mochilog://processSharedLog"),
      URL(string: "mochilog:///processSharedLog"),
      URL(string: "mochilog://"),
    ].compactMap { $0 }

    openMainApp(candidateURLs: candidates, context: context)
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
      || provider.hasItemConformingToTypeIdentifier(UTType.url.identifier)
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
    if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
      return UTType.url.identifier
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
      if !url.isFileURL {
        return url.absoluteString.trimmingCharacters(in: .whitespacesAndNewlines)
      }
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

  // UIViewControllerでのURLオープンのためのヘルパー
  private func openMainApp(url: URL) {
    NSLog("ShareExtension: attempting extensionContext.open URL=\(url.absoluteString)")
    logger.notice("attempting extensionContext.open URL=\(url.absoluteString, privacy: .public)")

    guard let context = extensionContext else {
      NSLog("ShareExtension: extensionContext nil; completing")
      logger.notice("extensionContext nil; completing")
      self.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
      return
    }

    context.open(url) { success in
      NSLog("ShareExtension: extensionContext.open completion success=\(success)")
      self.logger.notice("extensionContext.open completion success=\(success)")

      if success {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
          self.logger.notice("open success -> completeRequest")
          context.completeRequest(returningItems: nil, completionHandler: nil)
        }
        return
      }

      // 失敗時はユーザー操作で再試行できるようにする
      DispatchQueue.main.async {
        self.logger.notice("open failed -> presenting alert")
        self.presentOpenAlert(url: url)
      }
    }
  }
}
