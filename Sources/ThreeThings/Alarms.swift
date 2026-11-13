import AppKit
import Foundation
import ThreeThingsCore
import UserNotifications

/// Keeps macOS notifications in step with the board, for when 3 Today isn't running:
/// a daily one for each 3 Today item with an alarm, and a one-off for each scheduled item with a
/// time, on its day. (While the app runs, AlarmRinger rings them itself.)
enum Alarms {
    private static let prefix = "thing-"

    /// Notifications need a real app bundle (not `swift run`).
    static var available: Bool { Bundle.main.bundleIdentifier != nil }

    static func sync(_ board: Board, today: Day) {
        guard available else { return }
        let center = UNUserNotificationCenter.current()

        func request(_ item: Item, _ when: DateComponents, repeats: Bool) -> UNNotificationRequest {
            let content = UNMutableNotificationContent()
            content.title = item.title
            content.body = "One of your 3 Today"
            content.sound = .default
            let trigger = UNCalendarNotificationTrigger(dateMatching: when, repeats: repeats)
            return UNNotificationRequest(identifier: prefix + item.id.uuidString, content: content, trigger: trigger)
        }

        var wanted: [UNNotificationRequest] = board.liveAlarms.compactMap { item in
            guard let alarm = item.alarm else { return nil }
            // Repeats: rings again tomorrow at the same time if it's still not done.
            return request(item, DateComponents(hour: alarm.hour, minute: alarm.minute), repeats: true)
        }
        wanted += board.scheduledAlarms.compactMap { item in
            guard let alarm = item.alarm, let day = item.day, day > today else { return nil }
            let when = DateComponents(year: day.year, month: day.month, day: day.day, hour: alarm.hour, minute: alarm.minute)
            return request(item, when, repeats: false)
        }
        let keep = Set(wanted.map(\.identifier))

        center.getPendingNotificationRequests { pending in
            let stale = pending.map(\.identifier).filter { $0.hasPrefix(prefix) && !keep.contains($0) }
            center.removePendingNotificationRequests(withIdentifiers: stale)
            guard !wanted.isEmpty else { return }
            center.requestAuthorization(options: [.alert, .sound]) { granted, error in
                if let error { NSLog("3 Today: notifications not allowed: \(error.localizedDescription)") }
                guard granted else { return }
                // Adding with the same identifier replaces the old one (e.g. after a rename).
                wanted.forEach { center.add($0) }
            }
        }
    }
}

extension Alarms {
    /// Calls back with true if the user has turned notifications off for 3 Today.
    static func checkNotificationsOff(_ done: @escaping (Bool) -> Void) {
        guard available else { done(false); return }
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let off = settings.authorizationStatus == .denied
            DispatchQueue.main.async { done(off) }
        }
    }

    static func openNotificationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }
}

extension AlarmTime {
    init(date: Date) {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        self.init(hour: parts.hour ?? 9, minute: parts.minute ?? 0)
    }

    /// Today at this time.
    var date: Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
    }

    var label: String { date.formatted(date: .omitted, time: .shortened) }

    /// The next full hour from now.
    static var suggested: AlarmTime {
        let hour = Calendar.current.component(.hour, from: Date())
        return AlarmTime(hour: (hour + 1) % 24, minute: 0)
    }
}
