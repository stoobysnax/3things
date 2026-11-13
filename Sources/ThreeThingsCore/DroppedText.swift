import Foundation

/// Reads text dropped in from other apps into new tasks.
///
/// - Plain text (Notes, Mail, a web page): each line is a task. List markers like "- " or "[ ] "
///   and lines that are just links are dropped.
/// - To-dos dragged out of Things: the title comes with detail lines such as "When: 2026-11-15",
///   "Deadline: …", "Tags: …" or notes. Those aren't tasks: "When" becomes the task's day, and the
///   rest (including notes) is left out.
public enum DroppedText {
    public struct Task: Equatable, Sendable {
        public var title: String
        /// From a Things "When:" line. nil = no date given.
        public var day: Day?

        public init(title: String, day: Day? = nil) {
            self.title = title
            self.day = day
        }
    }

    /// Detail lines Things adds after a to-do's title.
    private static let detailKeys: Set<String> = [
        "when", "deadline", "tags", "tag", "notes", "note", "list", "project", "area", "heading",
        "reminder", "checklist", "created", "modified", "completed", "canceled", "cancelled",
        "start", "start date", "due", "repeat", "repeats",
    ]

    public static func tasks(from text: String, today: Day, calendar: Calendar = .current) -> [Task] {
        let lines = text.components(separatedBy: .newlines)
        let hasDetails = lines.contains { detail(in: $0) != nil }
        var tasks: [Task] = []
        // With Things details, only the first line of each block (blank-line separated) is a title;
        // anything else in the block is notes or checklist.
        var expectingTitle = true

        for raw in lines {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty {
                expectingTitle = true
                continue
            }
            if let found = detail(in: line) {
                let (key, value) = found
                if key == "when", !tasks.isEmpty, tasks[tasks.count - 1].day == nil {
                    tasks[tasks.count - 1].day = day(from: value, today: today, calendar: calendar)
                }
                continue
            }
            if hasDetails && !expectingTitle { continue }
            if let title = title(from: line) {
                tasks.append(Task(title: title))
                if hasDetails { expectingTitle = false }
            }
        }
        return tasks
    }

    /// "When: 2026-11-15" → ("when", "2026-11-15"), for the keys Things uses.
    private static func detail(in line: String) -> (String, String)? {
        guard let colon = line.firstIndex(of: ":") else { return nil }
        let key = line[..<colon].trimmingCharacters(in: .whitespaces).lowercased()
        guard detailKeys.contains(key) else { return nil }
        let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
        return (key, value)
    }

    private static func title(from line: String) -> String? {
        var t = line
        if t.contains("://") { return nil }
        for marker in ["- [ ] ", "- [x] ", "[ ] ", "[x] ", "- ", "* ", "• ", "☐ ", "◦ "] where t.hasPrefix(marker) {
            t = String(t.dropFirst(marker.count))
            break
        }
        t = t.trimmingCharacters(in: .whitespaces)
        return t.isEmpty ? nil : t
    }

    private static let isoDate = try! NSRegularExpression(pattern: #"(\d{4})-(\d{1,2})-(\d{1,2})"#)

    /// Things writes a date ("2026-11-15") or a word ("Today", "This Evening", "Tomorrow", "Someday").
    private static func day(from value: String, today: Day, calendar: Calendar) -> Day? {
        let v = value.lowercased()
        if let m = isoDate.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)) {
            let n = (1...3).compactMap { Range(m.range(at: $0), in: value).flatMap { Int(value[$0]) } }
            if n.count == 3 { return Day(year: n[0], month: n[1], day: n[2]) }
        }
        if v.hasPrefix("today") || v.contains("evening") || v.contains("tonight") { return today }
        if v.hasPrefix("tomorrow") { return today.adding(days: 1, calendar: calendar) }
        return nil // "Someday", "Anytime", or something we don't know
    }
}
