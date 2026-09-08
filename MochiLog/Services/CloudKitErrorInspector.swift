import CloudKit
import Foundation

/// Core Data can wrap CloudKit errors in several underlying/partial-error layers.
enum CloudKitErrorInspector {
  nonisolated static func cloudKitError(in error: Error) -> CKError? {
    var pending = [error as NSError]
    var visited = Set<ObjectIdentifier>()
    var firstCloudError: CKError?
    var index = 0
    while index < pending.count && index < 64 {
      let current = pending[index]
      index += 1
      guard visited.insert(ObjectIdentifier(current)).inserted else { continue }
      if current.domain == CKErrorDomain {
        let cloudError = CKError(_nsError: current)
        // Authentication failure is actionable even inside a partial failure.
        if cloudError.code == .notAuthenticated { return cloudError }
        if firstCloudError == nil { firstCloudError = cloudError }
      }
      if let underlying = current.userInfo[NSUnderlyingErrorKey] as? NSError {
        pending.append(underlying)
      }
      if let underlying = current.userInfo["NSUnderlyingErrorsKey"] as? [NSError] {
        pending.append(contentsOf: underlying.prefix(64))
      }
      if let partial = current.userInfo[CKPartialErrorsByItemIDKey] as? [AnyHashable: NSError] {
        pending.append(contentsOf: partial.values.prefix(64))
      }
    }
    return firstCloudError
  }
}
