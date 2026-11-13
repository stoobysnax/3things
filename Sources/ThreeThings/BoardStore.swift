import Foundation
import ThreeThingsCore

/// Holds the board for the UI, saves every change, keeps alarms in step,
/// rolls the day over, and decides when to ask the user something.
@MainActor
final class BoardStore: ObservableObject {
    @Published private(set) var board: Board
    @Published private(set) var today: Day
    /// A question waiting for the user (3 Today full, a day full, or a task just bumped).
    @Published private(set) var prompt: Prompt?
    private let file: BoardFile

    enum Prompt: Equatable {
        /// Something is going into a full 3 Today: swap with one, schedule it for another day, or cancel.
        case todayFull(incoming: UUID)
        /// Something is being scheduled for a day that already has 3: swap with one, or cancel.
        case dayFull(incoming: UUID, day: Day)
        /// A task was just bumped to Unscheduled: schedule it for another day, or leave it.
        case bumped(UUID)
    }

    init(file: BoardFile = BoardFile()) {
        self.file = file
        self.board = file.load()
        self.today = Day.today()
        rollOverIfNeeded()
        Alarms.sync(board, today: today)
        AlarmRinger.shared.start(with: self)
    }

    /// Call often: when the date has changed, unfinished items become Missed and the new day's
    /// scheduled items move into 3 Today.
    func rollOverIfNeeded() {
        let now = Day.today()
        if now != today { today = now }
        update { $0.rollOver(to: now) }
    }

    // MARK: Moving

    /// Moves an item into a list, just before `before` (nil = the end). Asks first when it would
    /// overfill 3 Today, or a day in Next.
    func send(_ id: UUID, to list: ListKind, before: UUID? = nil) {
        guard let from = board.location(of: id) else { return }
        switch list {
        case .three:
            if from.list != .three, !board.hasRoomToday {
                prompt = .todayFull(incoming: id)
                return
            }
            update { $0.move(id, to: .three, before: before) }
        case .next:
            let day = before.flatMap { board.item($0)?.day }
            if let day, board.item(id)?.day != day, !board.hasRoom(on: day, ignoring: id) {
                prompt = .dayFull(incoming: id, day: day)
                return
            }
            update { $0.move(id, to: .next, before: before) }
        case .done:
            update { $0.move(id, to: .done, before: before) }
        case .missed:
            break
        }
    }

    /// Schedules an item for a day (nil = unscheduled). Today or earlier means 3 Today.
    func schedule(_ id: UUID, on day: Day?) {
        guard let loc = board.location(of: id) else { return }
        let current = board.item(id)?.day
        // Nothing to do if it's already there.
        if loc.list == .three, let day, day <= today { return }
        if loc.list == .next, current == day { return }

        guard let day else {
            update { $0.schedule(id, on: nil, today: today) }
            return
        }
        if day <= today {
            send(id, to: .three)
        } else if !board.hasRoom(on: day, ignoring: id) {
            prompt = .dayFull(incoming: id, day: day)
        } else {
            update { $0.schedule(id, on: day, today: today) }
        }
    }

    func keepInToday(_ id: UUID) { send(id, to: .three) }
    func moveToNext(_ id: UUID) { schedule(id, on: nil) }

    // MARK: Prompts

    /// Swaps the waiting item with `outgoing`, then asks what to do with the one bumped out.
    func swap(with outgoing: UUID) {
        let incoming: UUID
        switch prompt {
        case .todayFull(let id): incoming = id
        case .dayFull(let id, _): incoming = id
        default: return
        }
        prompt = nil
        update { $0.swap(incoming, with: outgoing) }
        prompt = .bumped(outgoing)
    }

    /// From a prompt: schedule the item in question for `day` instead.
    func scheduleInstead(on day: Day) {
        let id: UUID
        switch prompt {
        case .todayFull(let i): id = i
        case .dayFull(let i, _): id = i
        case .bumped(let i): id = i
        case nil: return
        }
        prompt = nil
        schedule(id, on: day)
    }

    func dismissPrompt() {
        prompt = nil
    }

    // MARK: Dropped text

    /// Handles something dropped on a list: one of our own items moves there;
    /// any other text (e.g. to-dos dragged from Things) becomes new items, one per line.
    func receive(_ text: String, to list: ListKind, before: UUID? = nil) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let id = UUID(uuidString: trimmed), board.location(of: id) != nil {
            send(id, to: list, before: before)
            return
        }
        var created: [UUID] = []
        update { board in
            for title in Self.titles(from: text) {
                if let item = board.add(title, to: .next) { created.append(item.id) }
            }
        }
        for id in created {
            if prompt != nil { break } // the rest wait in Unscheduled
            send(id, to: list, before: before)
        }
    }

    /// One title per line, skipping blank lines, links, and list markers like "- " or "[ ] ".
    static func titles(from text: String) -> [String] {
        text.components(separatedBy: .newlines).compactMap { line in
            var t = line.trimmingCharacters(in: .whitespaces)
            if t.isEmpty || t.contains("://") { return nil }
            for marker in ["- [ ] ", "- [x] ", "[ ] ", "[x] ", "- ", "* ", "• ", "☐ ", "◦ "] where t.hasPrefix(marker) {
                t = String(t.dropFirst(marker.count))
                break
            }
            t = t.trimmingCharacters(in: .whitespaces)
            return t.isEmpty ? nil : t
        }
    }

    // MARK: Saving

    func update(_ change: (inout Board) -> Void) {
        var changed = board
        change(&changed)
        guard changed != board else { return }
        board = changed
        do {
            try file.save(changed)
        } catch {
            NSLog("3 Today could not save: \(error.localizedDescription)")
        }
        Alarms.sync(changed, today: today)
    }
}
