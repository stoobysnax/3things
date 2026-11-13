import Foundation

/// All of the user's items, and the rules for moving them around.
///
/// Rules:
/// - 3 Today never holds more than 3 items, in order of importance.
/// - A day can't have more than 3 items scheduled for it.
/// - When a 3 Today item is done (or deleted), the top Unscheduled item in Next moves up.
/// - When the day ends, unfinished 3 Today items become Missed, and items scheduled for the
///   new day move into 3 Today. Scheduled items whose day passed without them (the Mac was off)
///   also become Missed.
/// - Only 3 Today items have live, daily alarms (`liveAlarms`). Scheduled items with a time ring on
///   their day (`scheduledAlarms`).
public struct Board: Codable, Equatable, Sendable {
    public static let limit = 3

    public private(set) var three: [Item]
    public private(set) var missed: [Item]
    /// Scheduled and unscheduled items. Display groups them with `sections(today:)`;
    /// within a group, this array's order is kept.
    public private(set) var next: [Item]
    /// Most recently finished first.
    public private(set) var done: [Item]
    /// The day 3 Today refers to. The board rolls over when the real date passes it.
    public private(set) var currentDay: Day?

    public init(three: [Item] = [], missed: [Item] = [], next: [Item] = [], done: [Item] = [], currentDay: Day? = nil) {
        self.three = three
        self.missed = missed
        self.next = next
        self.done = done
        self.currentDay = currentDay
        while self.three.count > Self.limit { self.next.insert(self.three.removeLast(), at: 0) }
    }

    // Older saves have no `missed` or `currentDay`.
    private enum CodingKeys: String, CodingKey { case three, missed, next, done, currentDay }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            three: try c.decodeIfPresent([Item].self, forKey: .three) ?? [],
            missed: try c.decodeIfPresent([Item].self, forKey: .missed) ?? [],
            next: try c.decodeIfPresent([Item].self, forKey: .next) ?? [],
            done: try c.decodeIfPresent([Item].self, forKey: .done) ?? [],
            currentDay: try c.decodeIfPresent(Day.self, forKey: .currentDay)
        )
    }

    // MARK: Reading

    public func items(in list: ListKind) -> [Item] {
        switch list {
        case .three: return three
        case .missed: return missed
        case .next: return next
        case .done: return done
        }
    }

    public func location(of id: UUID) -> (list: ListKind, index: Int)? {
        for list in ListKind.allCases {
            if let index = items(in: list).firstIndex(where: { $0.id == id }) { return (list, index) }
        }
        return nil
    }

    public func item(_ id: UUID) -> Item? {
        guard let loc = location(of: id) else { return nil }
        return items(in: loc.list)[loc.index]
    }

    public var hasRoomToday: Bool { three.count < Self.limit }

    /// Items scheduled for `day`, in order.
    public func scheduled(on day: Day) -> [Item] { next.filter { $0.day == day } }

    public func hasRoom(on day: Day, ignoring id: UUID? = nil) -> Bool {
        scheduled(on: day).filter { $0.id != id }.count < Self.limit
    }

    public struct NextSections: Equatable, Sendable {
        /// Scheduled within the next 6 days, soonest first.
        public var thisWeek: [Item]
        /// Scheduled 7 or more days away, soonest first.
        public var later: [Item]
        public var unscheduled: [Item]
    }

    public func sections(today: Day, calendar: Calendar = .current) -> NextSections {
        var result = NextSections(thisWeek: [], later: [], unscheduled: [])
        let scheduled = next.enumerated()
            .filter { $0.element.day != nil }
            .sorted { a, b in
                a.element.day! == b.element.day! ? a.offset < b.offset : a.element.day! < b.element.day!
            }
            .map(\.element)
        for item in scheduled {
            if today.days(until: item.day!, calendar: calendar) >= 7 {
                result.later.append(item)
            } else {
                result.thisWeek.append(item)
            }
        }
        result.unscheduled = next.filter { $0.day == nil }
        return result
    }

    /// Items whose alarm should ring every day while they stay: those in 3 Today.
    public var liveAlarms: [Item] { three.filter { $0.alarm != nil } }

    /// Scheduled items with a time: they ring once, on their day.
    public var scheduledAlarms: [Item] { next.filter { $0.day != nil && $0.alarm != nil } }

    // MARK: Adding

    /// Adds a new item. Adding to a full 3 Today puts it at the end of Unscheduled instead.
    @discardableResult
    public mutating func add(_ title: String, to list: ListKind = .three, day: Day? = nil, now: Date = Date()) -> Item? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        var item = Item(title: trimmed)
        switch list {
        case .three where three.count < Self.limit:
            three.append(item)
        case .done:
            item.completedAt = now
            done.insert(item, at: 0)
        case .missed:
            item.missedOn = currentDay
            missed.append(item)
        default:
            item.day = day
            next.append(item)
        }
        return item
    }

    // MARK: Moving

    public mutating func complete(_ id: UUID, now: Date = Date()) {
        guard let loc = location(of: id), loc.list != .done else { return }
        move(id, to: .done, now: now)
    }

    /// Un-finishes an item: back into 3 Today if there's room, otherwise to the top of Unscheduled.
    public mutating func reopen(_ id: UUID) {
        guard location(of: id)?.list == .done else { return }
        if hasRoomToday {
            move(id, to: .three)
        } else {
            move(id, to: .next, before: next.first?.id)
            update(id) { $0.day = nil }
        }
    }

    /// Moves an item into `target`, just before the item `before` (nil = the end; the top for Done).
    /// In Next it takes the scheduled day of the item it's dropped before (nil = unscheduled).
    /// Moving into a full 3 Today bumps the last one to the top of Unscheduled (the app asks first).
    public mutating func move(_ id: UUID, to target: ListKind, before: UUID? = nil, now: Date = Date()) {
        guard let from = location(of: id), before != id else { return }
        let beforeDay = before.flatMap { self.item($0)?.day }
        var moving = withList(from.list) { $0.remove(at: from.index) }

        moving.completedAt = target == .done ? (moving.completedAt ?? now) : nil
        moving.missedOn = target == .missed ? (moving.missedOn ?? currentDay) : nil
        moving.day = target == .next ? beforeDay : nil

        func index(in list: [Item], fallback: Int) -> Int {
            before.flatMap { b in list.firstIndex { $0.id == b } } ?? fallback
        }

        switch target {
        case .three:
            let slot = max(0, min(index(in: three, fallback: three.count), three.count, Self.limit - 1))
            three.insert(moving, at: slot)
            while three.count > Self.limit {
                var bumped = three.removeLast()
                bumped.day = nil
                next.insert(bumped, at: 0)
            }
        case .missed:
            missed.insert(moving, at: index(in: missed, fallback: missed.count))
        case .next:
            next.insert(moving, at: index(in: next, fallback: next.count))
        case .done:
            done.insert(moving, at: index(in: done, fallback: 0))
        }

        if from.list == .three && target != .three { refillIfDone(from: target) }
    }

    /// Schedules an item for `day` (nil = unscheduled, at the top). A day up to today means 3 Today.
    /// The app checks for room first (`hasRoomToday`, `hasRoom(on:)`).
    public mutating func schedule(_ id: UUID, on day: Day?, today: Day) {
        guard let from = location(of: id) else { return }
        guard let day else {
            move(id, to: .next, before: next.first?.id)
            update(id) { $0.day = nil }
            return
        }
        if day <= today {
            if from.list != .three { move(id, to: .three) }
            return
        }
        var item = withList(from.list) { $0.remove(at: from.index) }
        item.day = day
        item.completedAt = nil
        item.missedOn = nil
        next.append(item)
        if from.list == .three { refillIfDone(from: .next) }
    }

    /// `incoming` takes `outgoing`'s exact place (its slot in 3 Today, or its scheduled day);
    /// `outgoing` goes to the top of Unscheduled, and the app asks whether to schedule it.
    public mutating func swap(_ incoming: UUID, with outgoing: UUID) {
        guard incoming != outgoing, location(of: incoming) != nil, location(of: outgoing) != nil else { return }
        let inLoc = location(of: incoming)!
        var a = withList(inLoc.list) { $0.remove(at: inLoc.index) }
        let outLoc = location(of: outgoing)!
        var b = items(in: outLoc.list)[outLoc.index]

        a.day = outLoc.list == .next ? b.day : nil
        a.completedAt = outLoc.list == .done ? (a.completedAt ?? Date()) : nil
        a.missedOn = outLoc.list == .missed ? b.missedOn : nil
        withList(outLoc.list) { $0[outLoc.index] = a }

        b.day = nil
        b.completedAt = nil
        b.missedOn = nil
        next.insert(b, at: 0)
    }

    public mutating func rename(_ id: UUID, to title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        update(id) { $0.title = trimmed }
    }

    public mutating func setAlarm(_ alarm: AlarmTime?, for id: UUID) {
        update(id) { $0.alarm = alarm }
    }

    public mutating func delete(_ id: UUID) {
        guard let loc = location(of: id) else { return }
        withList(loc.list) { _ = $0.remove(at: loc.index) }
        if loc.list == .three { refill() }
    }

    public mutating func clearDone() {
        done.removeAll()
    }

    /// Fills open 3 Today slots from the top of Unscheduled.
    public mutating func refill() {
        while three.count < Self.limit, let i = next.firstIndex(where: { $0.day == nil }) {
            three.append(next.remove(at: i))
        }
    }

    // MARK: The day changing

    /// Call with the real date whenever it might have changed. On a new day: unfinished 3 Today
    /// items become Missed, and items scheduled for the new day move into 3 Today.
    public mutating func rollOver(to today: Day) {
        guard let current = currentDay else {
            currentDay = today
            return
        }
        guard current < today else { return }

        for var item in three {
            item.missedOn = current
            missed.append(item)
        }
        three.removeAll()

        let due = next.enumerated()
            .filter { $0.element.day.map { $0 <= today } ?? false }
            .sorted { a, b in
                a.element.day! == b.element.day! ? a.offset < b.offset : a.element.day! < b.element.day!
            }
            .map(\.element)
        let dueIDs = Set(due.map(\.id))
        next.removeAll { dueIDs.contains($0.id) }

        for var item in due {
            let itsDay = item.day!
            item.day = nil
            if itsDay == today && three.count < Self.limit {
                three.append(item)
            } else {
                item.missedOn = itsDay
                missed.append(item)
            }
        }
        currentDay = today
    }

    // MARK: Helpers

    /// When a 3 Today item is finished, the top Unscheduled item moves up.
    private mutating func refillIfDone(from target: ListKind) {
        if target == .done { refill() }
    }

    private mutating func update(_ id: UUID, _ change: (inout Item) -> Void) {
        guard let loc = location(of: id) else { return }
        withList(loc.list) { change(&$0[loc.index]) }
    }

    private mutating func withList<T>(_ list: ListKind, _ body: (inout [Item]) -> T) -> T {
        switch list {
        case .three: return body(&three)
        case .missed: return body(&missed)
        case .next: return body(&next)
        case .done: return body(&done)
        }
    }
}
