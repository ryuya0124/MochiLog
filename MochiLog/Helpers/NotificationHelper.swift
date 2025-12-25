import Foundation
import UserNotifications

struct NotificationHelper {
  static func scheduleImportResultNotification(title: String, body: String) {
    let center = UNUserNotificationCenter.current()
    // Helper to schedule the notification
    func scheduleNow() {
      let content = UNMutableNotificationContent()
      content.title = title
      content.body = body
      content.sound = .default

      let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
      let req = UNNotificationRequest(
        identifier: UUID().uuidString, content: content, trigger: trigger)
      center.add(req) { error in
        if let error = error {
          print("Failed to schedule notification: \(error)")
        }
      }
    }

    center.getNotificationSettings { settings in
      switch settings.authorizationStatus {
      case .authorized, .provisional:
        scheduleNow()
      case .notDetermined:
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
          if granted {
            scheduleNow()
          } else if let err = error {
            print("Notification auth denied: \(err)")
          }
        }
      default:
        // denied / ephemeral - cannot schedule
        break
      }
    }
  }
}
