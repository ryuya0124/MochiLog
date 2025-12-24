// ZipArchiveHelper.swift
// ZIPFoundationユーティリティ拡張
import ZIPFoundation

extension ZIPFoundation.Archive {
  static func makeArchive(url: URL, accessMode: AccessMode) -> ZIPFoundation.Archive? {
    try? ZIPFoundation.Archive(url: url, accessMode: accessMode)
  }
}
