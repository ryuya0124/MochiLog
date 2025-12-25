import Foundation

struct ErrorLogEntry: Codable, Identifiable, Hashable {
  let id: String  // filename / uuid
  let timestamp: Date
  let message: String
  let rawTextPreview: String?
}

final class ErrorLogStore {
  static let shared = ErrorLogStore()

  private let folderURL: URL
  private let fileManager = FileManager.default

  private init() {
    let appSupport: URL
    do {
      appSupport = try fileManager.url(
        for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    } catch {
      // Fallback to temp
      appSupport = fileManager.temporaryDirectory
    }
    let base = appSupport.appendingPathComponent("MochiLog", isDirectory: true)
    folderURL = base.appendingPathComponent("ErrorLogs", isDirectory: true)
    try? fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)
  }

  func listLogs() -> [ErrorLogEntry] {
    guard
      let files = try? fileManager.contentsOfDirectory(
        at: folderURL, includingPropertiesForKeys: [.creationDateKey], options: [.skipsHiddenFiles])
    else { return [] }
    var results: [ErrorLogEntry] = []
    for url in files where url.pathExtension == "json" {
      if let data = try? Data(contentsOf: url),
        let decoded = try? JSONDecoder().decode(ErrorLogEntry.self, from: data)
      {
        results.append(decoded)
      }
    }
    // sort by timestamp desc
    return results.sorted { $0.timestamp > $1.timestamp }
  }

  func readLog(id: String) -> ErrorLogEntry? {
    let url = folderURL.appendingPathComponent(id)
    guard let data = try? Data(contentsOf: url),
      let decoded = try? JSONDecoder().decode(ErrorLogEntry.self, from: data)
    else { return nil }
    return decoded
  }

  func saveLog(message: String, rawText: String?) {
    let id = "log_\(UUID().uuidString).json"
    let entry = ErrorLogEntry(
      id: id, timestamp: Date(), message: message, rawTextPreview: rawText?.prefix(500).description)
    let url = folderURL.appendingPathComponent(id)
    if let data = try? JSONEncoder().encode(entry) {
      try? data.write(to: url, options: [.atomic])
    }
    // also optionally save raw text as a .txt alongside for inspection
    if let raw = rawText {
      let rawURL = folderURL.appendingPathComponent(
        id.replacingOccurrences(of: ".json", with: ".txt"))
      try? raw.write(to: rawURL, atomically: true, encoding: .utf8)
    }
  }

  func deleteLog(id: String) {
    let url = folderURL.appendingPathComponent(id)
    try? fileManager.removeItem(at: url)
    // also delete txt file
    let rawURL = folderURL.appendingPathComponent(
      id.replacingOccurrences(of: ".json", with: ".txt"))
    try? fileManager.removeItem(at: rawURL)
  }

  func readRawText(id: String) -> String? {
    let rawURL = folderURL.appendingPathComponent(
      id.replacingOccurrences(of: ".json", with: ".txt"))
    return try? String(contentsOf: rawURL, encoding: .utf8)
  }

  func rawFileURL(id: String) -> URL? {
    let rawURL = folderURL.appendingPathComponent(
      id.replacingOccurrences(of: ".json", with: ".txt"))
    return fileManager.fileExists(atPath: rawURL.path) ? rawURL : nil
  }

  func clearAll() {
    guard
      let files = try? fileManager.contentsOfDirectory(
        at: folderURL, includingPropertiesForKeys: nil, options: [])
    else { return }
    for url in files { try? fileManager.removeItem(at: url) }
  }
}
