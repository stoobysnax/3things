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
