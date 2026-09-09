import Foundation

enum LogDateParser {
  private static let lock = NSLock()
  private static let fractional: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
  }()
  private static let standard: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter
  }()
  private static let legacy: [DateFormatter] = {
    ["yyyy-MM-dd HH:mm:ss.SS Z", "yyyy-MM-dd HH:mm:ss.S Z", "yyyy-MM-dd HH:mm:ss Z"].map { format in
      let formatter = DateFormatter()
      formatter.locale = Locale(identifier: "en_US_POSIX")
      formatter.timeZone = TimeZone(secondsFromGMT: 0)
      formatter.isLenient = false
      formatter.dateFormat = format
      return formatter
    }
  }()

  /// Reuse configured formatters. The lock protects concurrent batch imports.
  nonisolated static func parse(_ value: String) -> Date? {
    lock.lock()
    defer { lock.unlock() }
    if let date = fractional.date(from: value) { return date }
    if let date = standard.date(from: value) { return date }
    for formatter in legacy {
      if let date = formatter.date(from: value) { return date }
    }
    return nil
  }
}
