import Foundation

enum LogDateParser {
  /// Both modern ISO timestamps and older Analytics headers occur in shared logs.
  /// Formatters are local so concurrent parses never share mutable formatter state.
  nonisolated static func parse(_ value: String) -> Date? {
    let iso = ISO8601DateFormatter()
    iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = iso.date(from: value) { return date }
    iso.formatOptions = [.withInternetDateTime]
    if let date = iso.date(from: value) { return date }
    let legacy = DateFormatter()
    legacy.locale = Locale(identifier: "en_US_POSIX")
    legacy.timeZone = TimeZone(secondsFromGMT: 0)
    legacy.isLenient = false
    for format in ["yyyy-MM-dd HH:mm:ss.SS Z", "yyyy-MM-dd HH:mm:ss.S Z", "yyyy-MM-dd HH:mm:ss Z"] {
      legacy.dateFormat = format
      if let date = legacy.date(from: value) { return date }
    }
    return nil
  }
}
