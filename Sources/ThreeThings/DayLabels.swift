import Foundation
import ThreeThingsCore

/// How days read in the app: "Today", "Tomorrow", "Mon", "Nov 24".
extension Day {
    func shortLabel(today: Day) -> String {
        let ahead = today.days(until: self)
        switch ahead {
        case 0: return "Today"
        case 1: return "Tomorrow"
        case -1: return "Yesterday"
        case 2...6: return date().formatted(.dateTime.weekday(.abbreviated))
        default: return date().formatted(.dateTime.month(.abbreviated).day())
        }
    }

    /// "Monday, Nov 16"
    var longLabel: String {
        date().formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }

    /// "Missed yesterday", "Missed Thu"
    func missedLabel(today: Day) -> String {
        let ago = days(until: today)
        if ago == 1 { return "Missed yesterday" }
        if (2...6).contains(ago) { return "Missed " + date().formatted(.dateTime.weekday(.abbreviated)) }
        return "Missed " + date().formatted(.dateTime.month(.abbreviated).day())
    }
}

extension Item {
    /// What the "when" button shows: "Mon", "Mon 9:00 AM", "9:00 AM".
    func whenLabel(today: Day, inToday: Bool) -> String? {
        let dayText = inToday ? nil : day?.shortLabel(today: today)
        let timeText = alarm?.label
        switch (dayText, timeText) {
        case let (d?, t?): return "\(d) \(t)"
        case let (d?, nil): return d
        case let (nil, t?): return t
        default: return nil
        }
    }
}
