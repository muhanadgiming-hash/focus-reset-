import EventKit
import Flutter
import UIKit
import UserNotifications

/// Native bridge for Focus Reset.
///
/// Channel: "focus_reset/native"
///  - getTimeZone                       -> String (IANA, e.g. "Asia/Riyadh")
///  - openSettings                      -> Bool
///  - notificationStatus                -> String
///  - requestNotifications              -> Bool
///  - replaceNotifications {prefix, items}  removes pending with prefix, adds items
///  - addNotifications {items}
///  - cancelNotifications {ids}
///  - calendarStatus                    -> String
///  - requestCalendar                   -> Bool
///  - calendars                         -> [{id, title, color, source}]
///  - events {from, to, calendarIds?}   -> [{id, title, start, end, allDay, calendarId}]
///
/// The calendar is only ever read; Focus Reset never writes to it.
public class FocusNativePlugin: NSObject, FlutterPlugin {
  private let eventStore = EKEventStore()

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "focus_reset/native", binaryMessenger: registrar.messenger())
    let instance = FocusNativePlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
    UNUserNotificationCenter.current().delegate = instance
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "getTimeZone":
      result(TimeZone.current.identifier)

    case "openSettings":
      guard let url = URL(string: UIApplication.openSettingsURLString) else {
        result(false)
        return
      }
      UIApplication.shared.open(url, options: [:]) { ok in result(ok) }

    case "notificationStatus":
      UNUserNotificationCenter.current().getNotificationSettings { settings in
        let value: String
        switch settings.authorizationStatus {
        case .authorized: value = "authorized"
        case .denied: value = "denied"
        case .notDetermined: value = "notDetermined"
        case .provisional: value = "authorized"
        @unknown default: value = "unknown"
        }
        DispatchQueue.main.async { result(value) }
      }

    case "requestNotifications":
      UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
        DispatchQueue.main.async { result(granted) }
      }

    case "replaceNotifications":
      let prefix = args["prefix"] as? String ?? "fr."
      let items = args["items"] as? [[String: Any]] ?? []
      let center = UNUserNotificationCenter.current()
      center.getPendingNotificationRequests { pending in
        let old = pending.map { $0.identifier }.filter { $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: old)
        center.removeDeliveredNotifications(withIdentifiers: old)
        var added = 0
        for item in items {
          if let request = FocusNativePlugin.makeRequest(item) {
            center.add(request, withCompletionHandler: nil)
            added += 1
          }
        }
        DispatchQueue.main.async { result(added) }
      }

    case "addNotifications":
      let items = args["items"] as? [[String: Any]] ?? []
      let center = UNUserNotificationCenter.current()
      var added = 0
      for item in items {
        if let request = FocusNativePlugin.makeRequest(item) {
          center.add(request, withCompletionHandler: nil)
          added += 1
        }
      }
      result(added)

    case "cancelNotifications":
      let ids = args["ids"] as? [String] ?? []
      let center = UNUserNotificationCenter.current()
      center.removePendingNotificationRequests(withIdentifiers: ids)
      center.removeDeliveredNotifications(withIdentifiers: ids)
      result(true)

    case "calendarStatus":
      result(FocusNativePlugin.calendarStatus())

    case "requestCalendar":
      if #available(iOS 17.0, *) {
        eventStore.requestFullAccessToEvents { granted, _ in
          DispatchQueue.main.async { result(granted) }
        }
      } else {
        eventStore.requestAccess(to: .event) { granted, _ in
          DispatchQueue.main.async { result(granted) }
        }
      }

    case "calendars":
      guard FocusNativePlugin.calendarStatus() == "authorized" else {
        result([])
        return
      }
      let calendars = eventStore.calendars(for: .event).map { c -> [String: Any] in
        [
          "id": c.calendarIdentifier,
          "title": c.title,
          "color": FocusNativePlugin.hex(c.cgColor),
          "source": c.source?.title ?? "",
        ]
      }
      result(calendars)

    case "events":
      guard FocusNativePlugin.calendarStatus() == "authorized" else {
        result([])
        return
      }
      let fromMs = (args["from"] as? NSNumber)?.doubleValue ?? Date().timeIntervalSince1970 * 1000
      let toMs = (args["to"] as? NSNumber)?.doubleValue ?? fromMs + 8 * 86_400_000
      var calendars: [EKCalendar]? = nil
      if let ids = args["calendarIds"] as? [String], !ids.isEmpty {
        let chosen = eventStore.calendars(for: .event).filter { ids.contains($0.calendarIdentifier) }
        if chosen.isEmpty {
          result([])
          return
        }
        calendars = chosen
      }
      let predicate = eventStore.predicateForEvents(
        withStart: Date(timeIntervalSince1970: fromMs / 1000),
        end: Date(timeIntervalSince1970: toMs / 1000),
        calendars: calendars
      )
      let events = eventStore.events(matching: predicate).map { e -> [String: Any] in
        [
          "id": e.eventIdentifier ?? UUID().uuidString,
          "title": e.title ?? "",
          "start": e.startDate.timeIntervalSince1970 * 1000,
          "end": e.endDate.timeIntervalSince1970 * 1000,
          "allDay": e.isAllDay,
          "calendarId": e.calendar?.calendarIdentifier ?? "",
        ]
      }
      result(events)

    default:
      if !FocusBlocking.handle(call.method, args, result) {
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private static func makeRequest(_ item: [String: Any]) -> UNNotificationRequest? {
    guard let id = item["id"] as? String, let title = item["title"] as? String else { return nil }
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = item["body"] as? String ?? ""
    content.sound = .default
    content.threadIdentifier = item["thread"] as? String ?? "focus-reset"

    let trigger: UNNotificationTrigger
    switch item["type"] as? String {
    case "date":
      guard let ms = (item["at"] as? NSNumber)?.doubleValue else { return nil }
      let interval = Date(timeIntervalSince1970: ms / 1000).timeIntervalSinceNow
      if interval < 1 { return nil }
      trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
    case "repeat":
      var components = DateComponents()
      components.hour = (item["hour"] as? NSNumber)?.intValue
      components.minute = (item["minute"] as? NSNumber)?.intValue
      if let weekday = (item["weekday"] as? NSNumber)?.intValue {
        components.weekday = weekday
      }
      trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
    default:
      return nil
    }
    return UNNotificationRequest(identifier: id, content: content, trigger: trigger)
  }

  private static func calendarStatus() -> String {
    let status = EKEventStore.authorizationStatus(for: .event)
    if #available(iOS 17.0, *) {
      switch status {
      case .fullAccess: return "authorized"
      case .writeOnly: return "writeOnly"
      case .denied: return "denied"
      case .restricted: return "restricted"
      case .notDetermined: return "notDetermined"
      default: return "unknown"
      }
    }
    switch status {
    case .denied: return "denied"
    case .restricted: return "restricted"
    case .notDetermined: return "notDetermined"
    default:
      // `.authorized` on iOS 16 and earlier.
      return status.rawValue == 3 ? "authorized" : "unknown"
    }
  }

  private static func hex(_ color: CGColor?) -> String {
    guard
      let color = color,
      let space = CGColorSpace(name: CGColorSpace.sRGB),
      let converted = color.converted(to: space, intent: .defaultIntent, options: nil),
      let c = converted.components, c.count >= 3
    else { return "#8E8E93" }
    return String(format: "#%02X%02X%02X", Int(c[0] * 255), Int(c[1] * 255), Int(c[2] * 255))
  }
}

extension FocusNativePlugin: UNUserNotificationCenterDelegate {
  /// Show reminders as banners even while the app is open.
  public func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    if #available(iOS 14.0, *) {
      completionHandler([.banner, .list, .sound])
    } else {
      completionHandler([.alert, .sound])
    }
  }
}
