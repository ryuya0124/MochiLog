// HomeView+Import.swift
// HomeViewのファイルインポート処理・フォルダ/ZIPヘルパー実装（ロジック用途）

import SwiftUI
import UniformTypeIdentifiers
import ZIPFoundation

// HomeView 拡張として各種インポート・ヘルパー
extension HomeView {
  /// ファイルインポート処理（複数・フォルダ・ZIP対応）
  func handleFileImport(result: Result<[URL], Error>) async {
    switch result {
    case .success(let urls):
      if urls.isEmpty { return }
      await MainActor.run { isProcessing = true }
      defer { Task { await MainActor.run { isProcessing = false } } }

      // URLとセキュリティスコープアクセス状態のペアを保持
      var scopedURLs: [(url: URL, needsRelease: Bool)] = []
      var allFileURLs: [URL] = []

      for url in urls {
        let needsRelease = url.startAccessingSecurityScopedResource()
        if !needsRelease && !url.isFileURL {
          await MainActor.run {
            errorMessage = String(localized: "file_access_denied", table: "Home")
            showingErrorAlert = true
          }
          continue
        }

        // フォルダかZIPか、通常ファイルか判定して展開
        if url.hasDirectoryPath {
          if let folderContents = try? await ImportHelper.recursiveContentsOfFolder(url: url) {
            allFileURLs.append(contentsOf: folderContents)
          }
          // フォルダの場合はここでスコープ解放
          if needsRelease {
            url.stopAccessingSecurityScopedResource()
          }
        } else if url.pathExtension.lowercased() == "zip" {
          if let extracted = try? await ImportHelper.extractZipContents(zipURL: url) {
            allFileURLs.append(contentsOf: extracted)
          } else {
            await MainActor.run {
              errorMessage =
                "\(String(localized: "file_read_error", table: "Home")): \(url.lastPathComponent) \(String(localized: "zip_extract_failed", table: "Home"))"
              showingErrorAlert = true
            }
          }
          // ZIPの場合もここでスコープ解放
          if needsRelease {
            url.stopAccessingSecurityScopedResource()
          }
        } else {
          // 通常ファイルはスコープ情報と一緒に保持
          allFileURLs.append(url)
          scopedURLs.append((url: url, needsRelease: needsRelease))
        }
      }

      // フィルター: 対応ファイルのみ（zip, txt, .ips, .ips.ca.synced を受け付ける）
      let supportedTypes: [UTType] = [.plainText]
      allFileURLs = ImportHelper.filterSupportedFiles(allFileURLs, supportedTypes: supportedTypes)

      // フィルター後に不要なスコープを解放
      for scoped in scopedURLs {
        if !allFileURLs.contains(scoped.url) && scoped.needsRelease {
          scoped.url.stopAccessingSecurityScopedResource()
        }
      }

      // フィルター後のscopedURLsを更新
      scopedURLs = scopedURLs.filter { allFileURLs.contains($0.url) }

      if allFileURLs.isEmpty {
        await MainActor.run {
          errorMessage = String(localized: "no_supported_files", table: "Home")
          showingErrorAlert = true
        }
        return
      }

      // 並列で全ファイルからテキスト読み込み＆パース実行
      var parseResults: [LogParser.ParseResult] = []
      var errors: [String] = []
      // AppSettings へのアクセスはここでキャプチャしておく（TaskGroup内での同期アクセス回避）
      let enableValidation = AppSettings.shared.enableCapacityValidation
      let threshold = AppSettings.shared.capacityValidationThreshold

      await withTaskGroup(of: (LogParser.ParseResult?, String?).self) { group in
        for fileURL in allFileURLs {
          group.addTask {
            do {
              let text = try String(contentsOf: fileURL, encoding: .utf8)
              let result = await LogParser.parse(
                text: text,
                enableValidation: enableValidation,
                validationThreshold: threshold
              )
              return (result, nil)
            } catch {
              return (nil, "\(fileURL.lastPathComponent): \(error.localizedDescription)")
            }
          }
        }
        for await (result, error) in group {
          if let result = result {
            parseResults.append(result)
          }
          if let error = error {
            errors.append(error)
          }
        }
      }

      // すべてのファイル読み込みが完了したらスコープを解放
      for scoped in scopedURLs {
        if scoped.needsRelease {
          scoped.url.stopAccessingSecurityScopedResource()
        }
      }
      // 重複排除（logDate+osVersion）、日付昇順ソート
      var dict: [String: LogParser.ParseResult] = [:]
      for r in parseResults {
        guard let date = r.logDate else { continue }
        let osVer = r.osVersion ?? ""
        let key = "\(date.timeIntervalSince1970)_\(osVer)"
        if dict[key] == nil {
          dict[key] = r
        }
      }
      let uniqueResults = dict.values.sorted { ($0.logDate ?? Date()) < ($1.logDate ?? Date()) }
      // 追加処理
      var addedAny = false
      await MainActor.run {
        for result in uniqueResults {
          if let newRecord = addRecordFromParseResult(result) {
            showRecordDetail(newRecord)
            addedAny = true
          }
          // nilを返すケースは重複やWatch選択待ちなど正常な処理フローのためエラーとして扱わない
        }
      }
      // ファイル読み込みエラーがあったらまとめて通知
      if !errors.isEmpty {
        await MainActor.run {
          errorMessage = errors.joined(separator: "\n")
          showingErrorAlert = true
        }
      }
      if !addedAny, let first = uniqueResults.first {
        await MainActor.run {
          if let newRecord = addRecordFromParseResult(first) {
            showRecordDetail(newRecord)
          }
        }
      }
    case .failure(let error):
      await MainActor.run {
        errorMessage =
          "\(String(localized: "file_select_error", table: "Home")): \(error.localizedDescription)"
        showingErrorAlert = true
      }
    }
  }
}

// 汎用インポートヘルパー（フォルダ再帰、ZIP展開、ファイルタイプフィルター）
struct ImportHelper {
  /// フォルダ内を再帰してファイルURL一覧を返す（非同期・投げる）
  static func recursiveContentsOfFolder(url: URL) async throws -> [URL] {
    var results: [URL] = []
    let fm = FileManager.default
    guard
      let enumerator = fm.enumerator(
        at: url, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles])
    else {
      return results
    }
    while let item = enumerator.nextObject() {
      guard let fileURL = item as? URL else { continue }
      if let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey]),
        values.isRegularFile == true
      {
        results.append(fileURL)
      }
    }
    return results
  }

  /// ZIPを一時ディレクトリに展開して中のファイルURL一覧を返す
  static func extractZipContents(zipURL: URL) async throws -> [URL] {
    let fm = FileManager.default
    let tempDir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)

    let archive = try ZIPFoundation.Archive(url: zipURL, accessMode: .read)

    var extracted: [URL] = []
    for entry in archive {
      let destinationURL = tempDir.appendingPathComponent(entry.path)
      let destDir = destinationURL.deletingLastPathComponent()
      try fm.createDirectory(at: destDir, withIntermediateDirectories: true)
      _ = try archive.extract(entry, to: destinationURL)
      extracted.append(destinationURL)
    }
    return extracted
  }

  /// 対応するUTTypeのみを残す
  static func filterSupportedFiles(_ urls: [URL], supportedTypes: [UTType]) -> [URL] {
    return urls.filter { url in
      let filename = url.lastPathComponent.lowercased()
      // Accept multi-part suffix first (e.g. .ips.ca.synced)
      if filename.hasSuffix(".ips.ca.synced") { return true }

      // Accept simple extensions (include last-extension 'synced' for .ips.ca.synced)
      let ext = url.pathExtension.lowercased()
      let allowedExtensions: Set<String> = ["txt", "ips", "zip", "synced"]
      if allowedExtensions.contains(ext) { return true }

      // UTType-based check (plain text / archive / data fallback)
      if let type = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType {
        if supportedTypes.contains(where: { type.conforms(to: $0) }) { return true }
        if type.conforms(to: .archive) || type == UTType.zip || type.conforms(to: .data) {
          return true
        }
      }

      return false
    }
  }
}
