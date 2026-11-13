import Foundation

/// Turns what people type in the alarm box into a time of day.
///
/// Understands:
/// - how long from now: "5 min", "in 20 minutes", "4 hours", "1h 30m", "1.5h", "half an hour", "45"
///   (a bare number means minutes)
/// - a clock time: "9pm", "9:30 pm", "21:00", "9:30" (the next 9:30 to come), "noon", "midnight"
public enum AlarmParser {
    public static func parse(_ input: String, now: Date = Date(), calendar: Calendar = .current) -> AlarmTime? {
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
        text = text.trimmingCharacters(in: .whitespaces)
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
