import Foundation
import ThreeThingsCore

/// Holds the board for the UI, saves every change, and keeps alarms in step.
@MainActor
final class BoardStore: ObservableObject {
    @Published private(set) var board: Board
    /// Set when an item is sent to a full 3 Things: the UI asks which task to swap with.
    @Published private(set) var swapIncoming: UUID?
    private let file: BoardFile

    init(file: BoardFile = BoardFile()) {
        self.file = file
        self.board = file.load()
        Alarms.sync(board)
    }

    /// Moves an item to a list. `index` nil means the end (top for Done).
    /// Sending an item from another list into a full 3 Things asks which task to swap with instead.
    func send(_ id: UUID, to list: ListKind, at index: Int? = nil) {
        guard let from = board.location(of: id) else { return }
        if list == .three, from.list != .three, board.three.count >= Board.limit {
            swapIncoming = id
            return
        }
        update { $0.move(id, to: list, at: index ?? (list == .done ? 0 : nil)) }
    }

    /// Handles something dropped on a list: one of our own items moves there;
    /// any other text (e.g. to-dos dragged from Things) becomes new items, one per line.
    func receive(_ text: String, to list: ListKind, at index: Int? = nil) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let id = UUID(uuidString: trimmed), board.location(of: id) != nil {
            send(id, to: list, at: index)
            return
        }
        let titles = Self.titles(from: text)
        guard !titles.isEmpty else { return }

        var overflow: [UUID] = []
        update { board in
            for (offset, title) in titles.enumerated() {
                guard let item = board.add(title, to: .next) else { continue }
                let at = index.map { $0 + offset }
                switch list {
                case .next:
                    board.move(item.id, to: .next, at: at)
                case .done:
                    board.move(item.id, to: .done, at: at ?? offset)
                case .three:
                    if board.three.count < Board.limit {
                        board.move(item.id, to: .three, at: at)
                    } else {
                        // No room: wait at the top of Next, and ask about a swap below.
                        board.move(item.id, to: .next, at: overflow.count)
                        overflow.append(item.id)
                    }
                }
            }
        }
        if let first = overflow.first { swapIncoming = first }
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

    func swap(with outgoing: UUID) {
        guard let incoming = swapIncoming else { return }
        swapIncoming = nil
        update { $0.swap(incoming, with: outgoing) }
    }

    func cancelSwap() {
        swapIncoming = nil
    }

    func update(_ change: (inout Board) -> Void) {
        var changed = board
        change(&changed)
        guard changed != board else { return }
        board = changed
        do {
            try file.save(changed)
        } catch {
            NSLog("3 Things could not save: \(error.localizedDescription)")
        }
        Alarms.sync(changed)
    }
}
