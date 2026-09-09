import Foundation
import Combine

enum L10n { static func string(_ value: String.LocalizationValue, table: String) -> String { "validation" } }
enum DeviceLibrary {
  static let deviceNamesJa = ["iPhone99,1": "iPhone Test"]
  static let designCapacities = ["iPhone Test": 4000]
  static let socInfo = ["iPhone Test": "A99"]
  static let boardToIdentifier = ["TESTAP": "iPhone99,1"]
}

@main
struct DeviceProfileTests {
  static func main() throws {
    let baseline = DeviceProfile(id: "standard", name: "iPhone Future", identifiers: ["iPhone100,1"], capacity: 4000, soc: "A100", boards: [:])
    precondition(baseline.category == .iphone)
    var accessory = baseline; accessory.identifiers = []; accessory.name = "iPhone Air MagSafe"
    precondition(accessory.category == .other)
    for (identifier, category) in [("iPad99,1", DeviceProfile.Category.ipad), ("Watch99,1", .watch), ("iPod99,1", .ipod)] {
      var item = baseline; item.identifiers = [identifier]
      precondition(item.category == category)
    }
    var custom = baseline
    custom.id = "custom"
    custom.capacity = 4300
    let entry = DeviceProfileEntry(original: custom, current: custom, acceptedBundled: [], previousNames: [custom.name], previousIdentifiers: Set(custom.identifiers))
    precondition(DeviceProfileCatalog.conflicts(entry, bundled: []).isEmpty)
    precondition(DeviceProfileCatalog.conflicts(entry, bundled: [baseline]) == [baseline])
    precondition(DeviceProfileCatalog.merged(bundled: [baseline], entries: [entry]) == [custom])
    var accepted = entry
    accepted.acceptedBundled = [baseline]
    precondition(DeviceProfileCatalog.conflicts(accepted, bundled: [baseline]).isEmpty)
    var update = baseline
    update.capacity = 4400
    precondition(DeviceProfileCatalog.conflicts(accepted, bundled: [update]) == [update])
    precondition(DeviceProfileCatalog.validationError(custom, others: [baseline]) != nil)
    var invalid = custom; invalid.capacity = -1
    precondition(DeviceProfileCatalog.validationError(invalid, others: []) != nil)
    invalid = custom; invalid.boards = ["X": "missing"]
    precondition(DeviceProfileCatalog.validationError(invalid, others: []) != nil)

    let suite = "MochiLog.DeviceProfileTests." + UUID().uuidString
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let store = DeviceProfileStore(defaults: defaults)
    var standard = store.profiles[0]
    let original = standard
    standard.capacity = 4500
    try store.save(standard)
    precondition(store.capacity(standard.name) == 4500)
    precondition(store.entry(for: standard.id)?.original == original)
    let reopened = DeviceProfileStore(defaults: defaults)
    precondition(reopened.capacity(standard.name) == 4500)
    try reopened.restore(standard.id)
    precondition(reopened.capacity(standard.name) == 4000)
    precondition(DeviceProfileStore(defaults: defaults).capacity(standard.name) == 4000)
    try reopened.save(custom)
    var edited = custom; edited.capacity = 4700; edited.name = "iPhone Future Renamed"
    try reopened.save(edited)
    try reopened.restore(custom.id)
    precondition(reopened.entry(for: custom.id)?.current == custom)
    precondition(reopened.entry(for: custom.id)?.previousNames.contains(edited.name) == true)
    var priorManual = original
    priorManual.id = "pre-update-manual"
    priorManual.capacity = 4800
    let priorEntry = DeviceProfileEntry(original: priorManual, current: priorManual,
      acceptedBundled: [], previousNames: [priorManual.name], previousIdentifiers: Set(priorManual.identifiers))
    defaults.set(try JSONEncoder().encode([priorEntry]), forKey: "deviceProfileOverrides.v1")
    let upgraded = DeviceProfileStore(defaults: defaults)
    precondition(upgraded.conflicts.count == 1)
    try upgraded.resolve(priorManual.id, useBundled: true)
    precondition(upgraded.capacity(original.name) == original.capacity)
    precondition(upgraded.entry(for: priorManual.id)?.original == priorManual)
    precondition(DeviceProfileStore(defaults: defaults).conflicts.isEmpty)
    try upgraded.restore(priorManual.id)
    precondition(upgraded.capacity(original.name) == 4800)
    print("PASS: defaults retained, persistence, restore, custom creation, aliases, conflicts on update, duplicate and input validation")
  }
}
