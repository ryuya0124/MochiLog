// ZipArchiveHelper.swift
// ZIPFoundationユーティリティ拡張
import Foundation
import ZIPFoundation

extension ZIPFoundation.Archive {
  @discardableResult
  static func makeArchive(url: URL, accessMode: AccessMode) -> ZIPFoundation.Archive? {
    do {
      return try ZIPFoundation.Archive(url: url, accessMode: accessMode)
    } catch {
      return nil
    }
  }
}
