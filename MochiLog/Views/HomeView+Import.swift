// HomeView+Import.swift
// インポート処理・フォルダ/ZIPヘルパーを分離
import SwiftUI
import UniformTypeIdentifiers
import ZIPFoundation

extension HomeView {
  /// ファイルインポート処理（複数・フォルダ・ZIP対応）
  func handleFileImport(result: Result<[URL], Error>) async {
    switch result {
    case .success(let urls):
      var allFiles: [URL] = []
      for url in urls {
        let resourceValues = try? url.resourceValues(forKeys: [.isDirectoryKey, .typeIdentifierKey])
        if let isDirectory = resourceValues?.isDirectory, isDirectory {
          // フォルダの場合、再帰的にファイル列挙
          do {
            let folderFiles = try await recursiveContentsOfFolder(url: url)
            allFiles.append(contentsOf: folderFiles)
          } catch {
            print("フォルダ内ファイル列挙失敗: \(error)")
          }
        } else if let uti = resourceValues?.typeIdentifier {
          if UTType(uti)?.conforms(to: .zipArchive) ?? false {
            // ZIPファイルの場合、展開して中のファイルを取得
            do {
              let extractedFiles = try await extractZipContents(zipURL: url)
              allFiles.append(contentsOf: extractedFiles)
            } catch {
              print("ZIP展開失敗: \(error)")
            }
          } else {
            allFiles.append(url)
          }
        } else {
          allFiles.append(url)
        }
      }
      // ここで allFiles に集まったファイルURLを利用して処理を続ける
      // 例: viewModel にファイルを追加など
      await MainActor.run {
        for file in allFiles {
          viewModel.addFile(url: file)
        }
      }
    case .failure(let error):
      print("ファイルインポート失敗: \(error)")
    }
  }

  /// 指定フォルダ内のファイルを再帰的に列挙し、全てのファイルURLを返す
  func recursiveContentsOfFolder(url: URL) async throws -> [URL] {
    var files: [URL] = []
    let keys: [URLResourceKey] = [.isDirectoryKey, .typeIdentifierKey]
    let fileManager = FileManager.default
    let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles])!

    for case let fileURL as URL in enumerator {
      let resourceValues = try fileURL.resourceValues(forKeys: Set(keys))
      if resourceValues.isDirectory == true {
        continue
      }
      if let uti = resourceValues.typeIdentifier {
        if UTType(uti)?.conforms(to: .zipArchive) ?? false {
          // ZIPファイルなら展開してファイルを追加
          let extractedFiles = try await extractZipContents(zipURL: fileURL)
          files.append(contentsOf: extractedFiles)
        } else {
          files.append(fileURL)
        }
      } else {
        files.append(fileURL)
      }
    }
    return files
  }

  /// ZIPファイルを展開し、中のファイルURL群を一時フォルダに展開して返す
  func extractZipContents(zipURL: URL) async throws -> [URL] {
    let fileManager = FileManager.default
    let tempDirURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try fileManager.createDirectory(at: tempDirURL, withIntermediateDirectories: true)
    try fileManager.unzipItem(at: zipURL, to: tempDirURL)

    // 展開先のファイル一覧を取得（再帰的に）
    let keys: [URLResourceKey] = [.isDirectoryKey]
    var extractedFiles: [URL] = []
    let enumerator = fileManager.enumerator(at: tempDirURL, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles])!

    for case let fileURL as URL in enumerator {
      let resourceValues = try fileURL.resourceValues(forKeys: Set(keys))
      if resourceValues.isDirectory == false {
        extractedFiles.append(fileURL)
      }
    }
    return extractedFiles
  }
}
