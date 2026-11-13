import Foundation

/// Turns what people type in the alarm box into a time of day.
///
/// Understands:
/// - how long from now: "5 min", "in 20 minutes", "4 hours", "1h 30m", "1.5h", "half an hour", "45"
///   (a bare number means minutes)
/// - a clock time: "9pm", "9:30 pm", "21:00", "9:30" (the next 9:30 to come), "noon", "midnight"
/// `parseWhen` also reads a day: "tomorrow", "mon", "fri 3pm", "in 3 days".
public enum AlarmParser {
    public static func parse(_ input: String, now: Date = Date(), calendar: Calendar = .current) -> AlarmTime? {
        let text = normalize(input)
        guard !text.isEmpty else { return nil }

        switch text {
        case "noon", "midday": return AlarmTime(hour: 12, minute: 0)
        case "midnight": return AlarmTime(hour: 0, minute: 0)
        default: break
        }

        if let minutes = minutesFromNow(text) {
            let date = now.addingTimeInterval(minutes * 60)
            let parts = calendar.dateComponents([.hour, .minute], from: date)
            return AlarmTime(hour: parts.hour ?? 0, minute: parts.minute ?? 0)
        }
        return clockTime(text, now: now, calendar: calendar)
    }

    /// A day and/or a time, as typed in the "when" box.
    public struct When: Equatable, Sendable {
        /// nil when no day was typed (keep whatever day is chosen).
        public var day: Day?
        /// nil when no time was typed.
        public var time: AlarmTime?

        public init(day: Day?, time: AlarmTime?) {
            self.day = day
            self.time = time
        }
    }

    /// Reads a day, a time, or both: "tomorrow", "mon", "fri 3pm", "tomorrow at 9", "in 3 days",
    /// "next week", plus everything `parse` takes ("5 min" is today, or tomorrow if it passes midnight).
    public static func parseWhen(_ input: String, now: Date = Date(), calendar: Calendar = .current) -> When? {
        var text = input.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        let today = Day(now, calendar: calendar)
        var day: Day?

        if let leading = leadingDate(text, today: today, calendar: calendar) {
            day = leading.0
            text = leading.1
        } else {
            var words = text.split(separator: " ").map(String.init)
            if words.first == "next", words.count > 1, weekday(words[1]) != nil { words.removeFirst() }
            if let first = words.first, let d = dayWord(first, today: today, calendar: calendar) {
                day = d
                words.removeFirst()
            } else if words.count > 1, let last = words.last, let d = dayWord(last, today: today, calendar: calendar) {
                day = d
                words.removeLast()
            } else if words.count > 1, let tail = trailingDate(words, today: today, calendar: calendar) {
                // "3pm nov 25"
                day = tail.day
                words = tail.rest
            }
            text = words.joined(separator: " ")
        }

        let rest = normalize(text)
        if rest.isEmpty { return day.map { When(day: $0, time: nil) } }

        // With a day, a bare number is an hour: "tomorrow 9" is 9 AM, "fri 3" is 3 PM.
        if day != nil, let hour = Int(rest), (1...23).contains(hour) {
            let h = hour <= 6 ? hour + 12 : hour
            return When(day: day, time: AlarmTime(hour: h, minute: 0))
        }

        if let minutes = minutesFromNow(rest) {
            guard day == nil else { return nil } // "mon 5 min" doesn't mean anything
            let date = now.addingTimeInterval(minutes * 60)
            return When(day: Day(date, calendar: calendar), time: AlarmTime(date: date, calendar: calendar))
        }
        guard let time = parse(rest, now: now, calendar: calendar) else { return nil }
        return When(day: day, time: time)
    }

    // MARK: - Days

    private static let months = "(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\\.?"
    private static let numberWords = ["a": 1, "an": 1, "one": 1, "two": 2, "three": 3, "four": 4, "five": 5,
                                      "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10]

    private static let isoPattern = try! NSRegularExpression(pattern: #"^(\d{4})-(\d{1,2})-(\d{1,2})\b(.*)$"#)
    private static let slashPattern = try! NSRegularExpression(pattern: #"^(\d{1,2})/(\d{1,2})(?:/(\d{2,4}))?\b(.*)$"#)
    private static let monthDayPattern = try! NSRegularExpression(pattern:
        "^" + months + #"\s+(\d{1,2})(?:st|nd|rd|th)?(?:,?\s+(\d{4}))?\b(.*)$"#)
    private static let dayMonthPattern = try! NSRegularExpression(pattern:
        #"^(?:the\s+)?(\d{1,2})(?:st|nd|rd|th)?\s+(?:of\s+)?"# + months + #"(?:,?\s+(\d{4}))?\b(.*)$"#)
    private static let ordinalPattern = try! NSRegularExpression(pattern: #"^(?:the\s+)?(\d{1,2})(?:st|nd|rd|th)\b(.*)$"#)
    private static let relativePattern = try! NSRegularExpression(pattern:
        #"^(?:in\s+)?(\d+|a|an|one|two|three|four|five|six|seven|eight|nine|ten)\s*(days?|d|weeks?|wks?|w|months?)\b(.*)$"#)

    /// A date at the start of the text, and what's left after it.
    /// "nov 25", "25 november", "11/25", "2026-11-25", "the 25th", "1 week", "in 10 days",
    /// "next week", "next month", "this weekend".
    private static func leadingDate(_ text: String, today: Day, calendar: Calendar) -> (Day, String)? {
        let monthNames = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"]
        func month(_ s: String?) -> Int? { s.flatMap { m in monthNames.firstIndex(of: String(m.prefix(3))) }.map { $0 + 1 } }
        func done(_ day: Day?, _ rest: String?) -> (Day, String)? { day.map { ($0, rest ?? "") } }

        if let g = captures(isoPattern, text) {
            return done(makeDay(Int(g[0]!), Int(g[1]!), Int(g[2]!), today: today, calendar: calendar), g[3])
        }
        if let g = captures(slashPattern, text) {
            return done(makeDay(g[2].flatMap(Int.init), Int(g[0]!), Int(g[1]!), today: today, calendar: calendar), g[3])
        }
        if let g = captures(monthDayPattern, text), let m = month(g[0]) {
            return done(makeDay(g[2].flatMap(Int.init), m, Int(g[1]!), today: today, calendar: calendar), g[3])
        }
        if let g = captures(dayMonthPattern, text), let m = month(g[1]) {
            return done(makeDay(g[2].flatMap(Int.init), m, Int(g[0]!), today: today, calendar: calendar), g[3])
        }
        if let g = captures(ordinalPattern, text), let d = Int(g[0]!) {
            // "the 25th": this month if it hasn't passed, otherwise next month.
            var found = makeDay(today.year, today.month, d, today: today, calendar: calendar, rollYear: false)
            if found.map({ $0 < today }) ?? true {
                let nextMonth = today.month == 12 ? (today.year + 1, 1) : (today.year, today.month + 1)
                found = makeDay(nextMonth.0, nextMonth.1, d, today: today, calendar: calendar, rollYear: false)
            }
            return done(found, g[1])
        }
        if let g = captures(relativePattern, text), let unit = g[1] {
            let n = Int(g[0]!) ?? numberWords[g[0]!] ?? 1
            let date = today.date(calendar: calendar)
            let target: Date?
            if unit.hasPrefix("m") {
                target = calendar.date(byAdding: .month, value: n, to: date)
            } else if unit.hasPrefix("w") {
                target = calendar.date(byAdding: .day, value: 7 * n, to: date)
            } else {
                target = calendar.date(byAdding: .day, value: n, to: date)
            }
            return done(target.map { Day($0, calendar: calendar) }, g[2])
        }
        for (phrase, make) in [
            ("next week", { upcoming(weekday: 2, after: today, calendar: calendar) }),
            ("next month", { today.adding(months: 1, calendar: calendar) }),
            ("this weekend", { upcoming(weekday: 7, after: today, calendar: calendar) }),
            ("weekend", { upcoming(weekday: 7, after: today, calendar: calendar) }),
        ] as [(String, () -> Day)] where text.hasPrefix(phrase) {
            return (make(), String(text.dropFirst(phrase.count)))
        }
        return nil
    }

    /// A date written at the end instead: "3pm nov 25", "9am 11/25".
    private static func trailingDate(_ words: [String], today: Day, calendar: Calendar) -> (day: Day, rest: [String])? {
        for split in 1..<words.count {
            let tail = words[split...].joined(separator: " ")
            if let found = leadingDate(tail, today: today, calendar: calendar),
               found.1.trimmingCharacters(in: .whitespaces).isEmpty {
                return (found.0, Array(words[..<split]))
            }
        }
        return nil
    }

    /// A real calendar day, or nil ("feb 30"). With no year, a date that has passed means next year.
    private static func makeDay(_ year: Int?, _ month: Int?, _ day: Int?, today: Day, calendar: Calendar,
                                rollYear: Bool = true) -> Day? {
        guard let month, let day, (1...12).contains(month), (1...31).contains(day) else { return nil }
        var y = year ?? today.year
        if y < 100 { y += 2000 }
        func valid(_ y: Int) -> Day? {
            let d = Day(year: y, month: month, day: day)
            return Day(d.date(calendar: calendar), calendar: calendar) == d ? d : nil
        }
        guard var found = valid(y) else { return nil }
        if year == nil, rollYear, found < today, let next = valid(y + 1) { found = next }
        return found
    }

    private static func dayWord(_ word: String, today: Day, calendar: Calendar) -> Day? {
        switch word {
        case "today", "tonight", "tod": return today
        case "tomorrow", "tmrw", "tmr", "tom", "tomorow": return today.adding(days: 1, calendar: calendar)
        default:
            return weekday(word).map { upcoming(weekday: $0, after: today, calendar: calendar) }
        }
    }

    /// Calendar weekday number (1 = Sunday) for a name like "mon" or "thursday".
    private static func weekday(_ word: String) -> Int? {
        let names = [["sun", "sunday"], ["mon", "monday"], ["tue", "tues", "tuesday"],
                     ["wed", "weds", "wednesday"], ["thu", "thur", "thurs", "thursday"],
                     ["fri", "friday"], ["sat", "saturday"]]
        return names.firstIndex { $0.contains(word) }.map { $0 + 1 }
    }

    /// The next day with that weekday, 1 to 7 days after `today`.
    private static func upcoming(weekday: Int, after today: Day, calendar: Calendar) -> Day {
        let current = calendar.component(.weekday, from: today.date(calendar: calendar))
        var ahead = (weekday - current + 7) % 7
        if ahead == 0 { ahead = 7 }
        return today.adding(days: ahead, calendar: calendar)
    }

    private static func normalize(_ input: String) -> String {
        var text = input.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        for word in ["in ", "at "] where text.hasPrefix(word) {
            text = String(text.dropFirst(word.count))
        }
        let replacements = [
            ("half an hour", "30 min"), ("half hour", "30 min"),
            ("an hour", "1 hour"), ("a hour", "1 hour"),
            ("a.m.", "am"), ("p.m.", "pm"),
        ]
        for (from, to) in replacements {
            text = text.replacingOccurrences(of: from, with: to)
        }
        return text.trimmingCharacters(in: .whitespaces)
    }

    // MARK: - "5 min", "1h 30m", "45"

    private static let durationPattern = try! NSRegularExpression(pattern:
        #"^(?:(\d+(?:\.\d+)?)\s*(?:h|hr|hrs|hour|hours))?\s*(?:and\s*)?(?:(\d+(?:\.\d+)?)\s*(?:m|min|mins|minute|minutes))?$"#)
    private static let bareNumber = try! NSRegularExpression(pattern: #"^\d+$"#)

    private static func minutesFromNow(_ text: String) -> Double? {
        if matches(bareNumber, text) {
            guard let n = Double(text), n > 0 else { return nil }
            return n
        }
        guard let groups = captures(durationPattern, text) else { return nil }
        let hours = groups[0].flatMap(Double.init)
        let minutes = groups[1].flatMap(Double.init)
        guard hours != nil || minutes != nil else { return nil }
        let total = (hours ?? 0) * 60 + (minutes ?? 0)
        return total > 0 ? total : nil
    }

    // MARK: - "9pm", "9:30", "21:00"

    private static let clockPattern = try! NSRegularExpression(pattern:
        #"^(\d{1,2})(?:[:.](\d{2}))?\s*(am|pm|a|p)?$"#)

    private static func clockTime(_ text: String, now: Date, calendar: Calendar) -> AlarmTime? {
        guard let groups = captures(clockPattern, text),
              let hourText = groups[0], var hour = Int(hourText) else { return nil }
        let minute = groups[1].flatMap(Int.init) ?? 0
        guard minute < 60 else { return nil }

        if let suffix = groups[2] {
            guard (1...12).contains(hour) else { return nil }
            let pm = suffix.hasPrefix("p")
            if hour == 12 { hour = pm ? 12 : 0 } else if pm { hour += 12 }
            return AlarmTime(hour: hour, minute: minute)
        }

        // No am/pm. "9" alone is handled as minutes above, so this needs a colon: "9:30" or "21:00".
        guard groups[1] != nil, hour < 24 else { return nil }
        if hour == 0 || hour > 12 { return AlarmTime(hour: hour, minute: minute) }

        // 1–12 with no am/pm: whichever of the two comes next.
        let morning = hour == 12 ? 12 : hour
        let evening = hour == 12 ? 0 : hour + 12
        let nowParts = calendar.dateComponents([.hour, .minute], from: now)
        let nowMinutes = (nowParts.hour ?? 0) * 60 + (nowParts.minute ?? 0)
        func minutesUntil(_ h: Int) -> Int { ((h * 60 + minute) - nowMinutes + 24 * 60) % (24 * 60) }
        let pick = minutesUntil(morning) <= minutesUntil(evening) ? morning : evening
        return AlarmTime(hour: pick, minute: minute)
    }

    // MARK: - Regex helpers

    private static func matches(_ regex: NSRegularExpression, _ text: String) -> Bool {
        regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
    }

    private static func captures(_ regex: NSRegularExpression, _ text: String) -> [String?]? {
        guard let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else { return nil }
        return (1..<match.numberOfRanges).map { i in
            Range(match.range(at: i), in: text).map { String(text[$0]) }
        }
    }
}

extension AlarmTime {
    public init(date: Date, calendar: Calendar) {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        self.init(hour: parts.hour ?? 0, minute: parts.minute ?? 0)
    }
}
