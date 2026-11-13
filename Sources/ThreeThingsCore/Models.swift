import Foundation

/// Where an item lives.
/// - `three`: today's 3 ("3 Today"), in order of importance.
/// - `missed`: left unfinished when a day ended; waits for "Keep in today" or "Move to Next".
/// - `next`: everything for later: scheduled for a day, or unscheduled.
/// - `done`: finished.
public enum ListKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case three, missed, next, done

    public var id: String { rawValue }

    /// The lists shown in the sidebar (missed items show inside 3 Today and Next).
    public static let sidebar: [ListKind] = [.three, .next, .done]

    public var title: String {
        switch self {
        case .three: return "3 Today"
        case .missed: return "Missed"
        case .next: return "Next"
        case .done: return "Done"
        }
    }
}

/// A calendar day, with no time.
public struct Day: Codable, Hashable, Comparable, Sendable, CustomStringConvertible {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    public init(_ date: Date, calendar: Calendar = .current) {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: parts.year ?? 2000, month: parts.month ?? 1, day: parts.day ?? 1)
    }

    public static func today(calendar: Calendar = .current) -> Day { Day(Date(), calendar: calendar) }

    /// Midnight at the start of this day.
    public func date(calendar: Calendar = .current) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? Date()
    }

    public func adding(days: Int, calendar: Calendar = .current) -> Day {
        Day(calendar.date(byAdding: .day, value: days, to: date(calendar: calendar)) ?? Date(), calendar: calendar)
    }

    /// Whole days from this day to `other` (negative if `other` is earlier).
    public func days(until other: Day, calendar: Calendar = .current) -> Int {
        calendar.dateComponents([.day], from: date(calendar: calendar), to: other.date(calendar: calendar)).day ?? 0
    }

    public static func < (a: Day, b: Day) -> Bool {
        (a.year, a.month, a.day) < (b.year, b.month, b.day)
    }

    public var description: String { String(format: "%04d-%02d-%02d", year, month, day) }
}

/// A time of day, with no date. An alarm rings at this time on the day the item is in 3 Today
/// (and again the next day if it's still there, unfinished).
public struct AlarmTime: Codable, Hashable, Sendable {
    public var hour: Int
    public var minute: Int

    public init(hour: Int, minute: Int) {
        self.hour = min(max(hour, 0), 23)
        self.minute = min(max(minute, 0), 59)
    }
}

public struct Item: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var title: String
    public var alarm: AlarmTime?
    public var completedAt: Date?
    /// The day it's scheduled for. Only used while the item is in Next; nil there means unscheduled.
    public var day: Day?
    /// For a missed item: the day it was missed.
    public var missedOn: Day?

    public init(id: UUID = UUID(), title: String, alarm: AlarmTime? = nil, completedAt: Date? = nil,
                day: Day? = nil, missedOn: Day? = nil) {
        self.id = id
        self.title = title
        self.alarm = alarm
        self.completedAt = completedAt
        self.day = day
        self.missedOn = missedOn
    }
}
