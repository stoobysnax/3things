import AppKit
import SwiftUI

/// While typing a new task, ⌘S adds it and opens its scheduler.
struct CommitAndScheduleKey: FocusedValueKey {
    typealias Value = () -> Void
}

extension FocusedValues {
    var commitAndSchedule: (() -> Void)? {
        get { self[CommitAndScheduleKey.self] }
        set { self[CommitAndScheduleKey.self] = newValue }
    }
}

/// ⌘Z / ⇧⌘Z undo and redo anything; ⌘N starts a new task; ⌘S schedules.
struct AppCommands: Commands {
    let store: BoardStore
    @FocusedValue(\.commitAndSchedule) private var commitAndSchedule

    var body: some Commands {
        CommandGroup(replacing: .undoRedo) {
            Button("Undo") {
                // While typing, undo the typing first, as usual.
                if let undo = textUndoManager, undo.canUndo { undo.undo() } else { store.undo() }
            }
            .keyboardShortcut("z")

            Button("Redo") {
                if let undo = textUndoManager, undo.canRedo { undo.redo() } else { store.redo() }
            }
            .keyboardShortcut("z", modifiers: [.command, .shift])
        }

        CommandGroup(replacing: .newItem) {
            Button("New Task") { store.focusNewTask = true }
                .keyboardShortcut("n")
        }

        CommandGroup(replacing: .saveItem) {
            Button("Schedule…") {
                if let commitAndSchedule { commitAndSchedule() } else { store.requestSchedule() }
            }
            .keyboardShortcut("s")
        }
    }

    /// The undo history of the text box being typed in, but only while it has text in it.
    /// (An empty box, e.g. right after adding a task, leaves ⌘Z for undoing your last change.)
    private var textUndoManager: UndoManager? {
        guard let editor = NSApp.keyWindow?.firstResponder as? NSTextView, editor.isEditable,
              !editor.string.isEmpty else { return nil }
        return editor.undoManager
    }
}
