import Foundation

struct DeviceProfile: Codable, Equatable, Identifiable {
  var id: String
  var name: String
  var identifiers: [String]
  var capacity: Int
  var soc: String
  var boards: [String: String]

  enum Category: String, CaseIterable, Identifiable {
    case iphone = "iPhone", ipad = "iPad", watch = "Apple Watch", ipod = "iPod", other
    var id: String { rawValue }
    var icon: String {
      switch self {
      case .iphone: return "iphone"
      case .ipad: return "ipad"
      case .watch: return "applewatch"
      case .ipod: return "ipod"
      case .other: return "square.grid.2x2"
      }
    }
  }

  var category: Category {
    if identifiers.contains(where: { $0.hasPrefix("iPhone") }) { return .iphone }
    if identifiers.contains(where: { $0.hasPrefix("iPad") }) { return .ipad }
    if identifiers.contains(where: { $0.hasPrefix("Watch") }) { return .watch }
    if identifiers.contains(where: { $0.hasPrefix("iPod") }) { return .ipod }
    return .other
  }

  func matches(_ other: DeviceProfile) -> Bool {
    name.caseInsensitiveCompare(other.name) == .orderedSame
      || !Set(identifiers).isDisjoint(with: other.identifiers)
  }
}

struct DeviceProfileEntry: Codable, Equatable, Identifiable {
  var id: String { original.id }
  let original: DeviceProfile
  var current: DeviceProfile
  var acceptedBundled: [DeviceProfile]
  var previousNames: Set<String>
  var previousIdentifiers: Set<String>
}

/// Pure catalog operations also used by the regression tests.
enum DeviceProfileCatalog {
  static func conflicts(_ entry: DeviceProfileEntry, bundled: [DeviceProfile]) -> [DeviceProfile] {
    let matches = bundled.filter { entry.current.matches($0) || entry.original.matches($0) }
      .sorted { $0.id < $1.id }
    return matches == entry.acceptedBundled.sorted(by: { $0.id < $1.id }) ? [] : matches
  }

  static func merged(bundled: [DeviceProfile], entries: [DeviceProfileEntry]) -> [DeviceProfile] {
    let defaults = bundled.filter { profile in
      !entries.contains { $0.current.matches(profile) || $0.original.id == profile.id }
    }
    return (defaults + entries.map(\.current)).sorted {
      $0.name.localizedStandardCompare($1.name) == .orderedAscending
    }
  }

  static func validationError(_ profile: DeviceProfile, others: [DeviceProfile]) -> String? {
    if profile.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "profile_name_required" }
    if !(1...100000).contains(profile.capacity) { return "profile_capacity_invalid" }
    if profile.identifiers.contains(where: { $0.range(of: "^(iPhone|iPad|Watch|iPod)[0-9]+,[0-9]+$", options: .regularExpression) == nil })
      || Set(profile.identifiers).count != profile.identifiers.count { return "profile_identifiers_invalid" }
    if profile.boards.contains(where: { $0.key.isEmpty || !profile.identifiers.contains($0.value) }) {
      return "profile_boards_invalid"
    }
    if others.contains(where: { $0.id != profile.id && profile.matches($0) }) { return "profile_duplicate" }
    if others.contains(where: { other in
      other.id != profile.id && !Set(other.boards.keys).isDisjoint(with: profile.boards.keys)
    }) { return "profile_board_duplicate" }
    return nil
  }
}
