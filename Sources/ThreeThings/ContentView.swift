import SwiftUI
import ThreeThingsCore
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var store: BoardStore
    @Environment(\.theme) private var theme
    @State private var selection: ListKind = .three

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                Sidebar(selection: $selection)
                    .frame(width: 180)
                    .frame(maxHeight: .infinity)
                    .background(theme.sidebar.ignoresSafeArea())
                Rectangle()
                    .fill(theme.hairline)
                    .frame(width: 1)
                    .ignoresSafeArea()
                ListPane(list: selection)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            if let prompt = store.prompt {
                PromptOverlay(prompt: prompt)
            }
        }
        .frame(minWidth: 600, minHeight: 420)
        .background(theme.background.ignoresSafeArea())
        .background(shortcuts)
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            store.rollOverIfNeeded()
        }
    }

    /// ⌘1 3 Today, ⌘2 Next, ⌘3 Done.
    private var shortcuts: some View {
        ZStack {
            ForEach(Array(ListKind.sidebar.enumerated()), id: \.element) { index, list in
                Button("") { selection = list }
                    .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
            }
        }
        .opacity(0)
        .allowsHitTesting(false)
    }
}

// MARK: - Drag and drop

/// Items are dragged as their id in plain text.
func dragProvider(for item: Item) -> NSItemProvider {
    NSItemProvider(object: item.id.uuidString as NSString)
}

/// Reads dropped text: one of our own items (its id), or text from another app
/// such as to-dos dragged out of Things. Hands it over on the main thread.
func loadDroppedText(_ providers: [NSItemProvider], _ handle: @escaping (String) -> Void) -> Bool {
    let readable = providers.filter { $0.canLoadObject(ofClass: NSString.self) }
    guard !readable.isEmpty else { return false }
    for provider in readable {
        _ = provider.loadObject(ofClass: NSString.self) { object, _ in
            guard let text = object as? NSString else { return }
            DispatchQueue.main.async { handle(text as String) }
        }
    }
    return true
}

/// Drop target that inserts before this view, with a thin line showing where.
struct InsertDropTarget: ViewModifier {
    let onDrop: (String) -> Void
    @Environment(\.theme) private var theme
    @State private var targeted = false

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                Capsule()
                    .fill(theme.text.opacity(0.55))
                    .frame(height: 2)
                    .padding(.horizontal, 8)
                    .offset(y: -1)
                    .opacity(targeted ? 1 : 0)
                    .allowsHitTesting(false)
            }
            .onDrop(of: [UTType.plainText], isTargeted: $targeted) { loadDroppedText($0, onDrop) }
    }
}

// MARK: - Sidebar

struct Sidebar: View {
    @Binding var selection: ListKind
    @EnvironmentObject private var store: BoardStore
    @Environment(\.theme) private var theme
    @AppStorage("darkMode") private var darkMode = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(ListKind.sidebar) { list in
                SidebarRow(
                    list: list,
                    count: countLabel(list),
                    needsAction: list == .three && !store.board.missed.isEmpty,
                    isSelected: selection == list
                ) {
                    selection = list
                }
            }
            Spacer()
            Button {
                darkMode.toggle()
            } label: {
                Image(systemName: darkMode ? "sun.max" : "moon")
                    .font(.system(size: 14))
                    .foregroundStyle(theme.secondary)
                    .frame(width: 30, height: 30)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .focusable(false)
            .help(darkMode ? "Light mode" : "Dark mode")
            .padding(.leading, 4)
            .padding(.bottom, 12)
        }
        .padding(.top, 44)
        .padding(.horizontal, 10)
    }

    private func countLabel(_ list: ListKind) -> String {
        let n = store.board.items(in: list).count
        if list == .three { return "\(n)/\(Board.limit)" }
        return n == 0 ? "" : "\(n)"
    }
}

/// A sidebar entry. Drop an item on it to move it to that list.
/// Hold a dragged item over it for a moment to open that list and drop at an exact spot.
struct SidebarRow: View {
    let list: ListKind
    let count: String
    /// Missed tasks are waiting: a small dot.
    let needsAction: Bool
    let isSelected: Bool
    let select: () -> Void

    @EnvironmentObject private var store: BoardStore
    @Environment(\.theme) private var theme
    @State private var isTargeted = false
    @State private var hovering = false

    var body: some View {
        Button(action: select) {
            HStack(spacing: 6) {
                Text(list.title)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? theme.text : theme.secondary)
                if needsAction {
                    Circle()
                        .fill(theme.missedLabel)
                        .frame(width: 5, height: 5)
                        .help("Missed tasks need a decision")
                }
                Spacer()
                Text(count)
                    .font(.system(size: 12))
                    .monospacedDigit()
                    .foregroundStyle(theme.faint)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isTargeted ? theme.fillStrong : (isSelected || hovering ? theme.fill : .clear))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .onHover { hovering = $0 }
        .onDrop(of: [UTType.plainText], isTargeted: $isTargeted) { providers in
            loadDroppedText(providers) { store.receive($0, to: list) }
        }
        .onChange(of: isTargeted) { targeted in
            guard targeted, !isSelected else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                if isTargeted { select() }
            }
        }
    }
}

// MARK: - Lists

struct ListPane: View {
    let list: ListKind
    @EnvironmentObject private var store: BoardStore
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 32)
                .padding(.top, 40)
                .padding(.bottom, 14)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    switch list {
                    case .three: todayList
                    case .next: nextList
                    default: doneList
                    }

                    // The space below the list also takes drops (to the end).
                    Color.clear
                        .frame(maxWidth: .infinity, minHeight: 120)
                        .contentShape(Rectangle())
                        .modifier(InsertDropTarget { store.receive($0, to: list == .missed ? .next : list) })
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
    }

    // 3 Today: three slots, then anything missed.
    @ViewBuilder
    private var todayList: some View {
        let items = store.board.three
        rows(items, in: .three)
        ForEach(Array(min(items.count, Board.limit)..<Board.limit), id: \.self) { slot in
            Group {
                if slot == items.count {
                    AddRow(list: .three, placeholder: "Add a thing")
                } else {
                    EmptySlotRow()
                }
            }
            .modifier(InsertDropTarget { store.receive($0, to: .three) })
        }
        missedSection
    }

    // Next: missed first, then this week, later, unscheduled.
    @ViewBuilder
    private var nextList: some View {
        let sections = store.board.sections(today: store.today)
        missedSection
        if !sections.thisWeek.isEmpty {
            SectionHeader(title: "This week")
            rows(sections.thisWeek, in: .next)
        }
        if !sections.later.isEmpty {
            SectionHeader(title: "Later")
            rows(sections.later, in: .next)
        }
        SectionHeader(title: "Unscheduled")
        rows(sections.unscheduled, in: .next)
        AddRow(list: .next, placeholder: "Add to Next")
            .modifier(InsertDropTarget { store.receive($0, to: .next) })
    }

    @ViewBuilder
    private var doneList: some View {
        let items = store.board.done
        if items.isEmpty {
            Text("Nothing finished yet.")
                .font(.system(size: 14))
                .foregroundStyle(theme.faint)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
        }
        rows(items, in: .done)
    }

    @ViewBuilder
    private var missedSection: some View {
        let missed = store.board.missed
        if !missed.isEmpty {
            SectionHeader(title: "Missed", color: theme.missedLabel)
            ForEach(missed) { item in
                MissedRow(item: item)
                    .onDrag { dragProvider(for: item) }
            }
        }
    }

    private func rows(_ items: [Item], in list: ListKind) -> some View {
        ForEach(items) { item in
            ItemRow(item: item, list: list)
                .onDrag { dragProvider(for: item) }
                .modifier(InsertDropTarget { store.receive($0, to: list, before: item.id) })
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(list.title)
                    .font(.system(size: 28, weight: .semibold))
                    .tracking(-0.4)
                    .foregroundStyle(theme.text)
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(theme.secondary)
            }
            Spacer()
            if list == .done && !store.board.done.isEmpty {
                Button("Clear") { store.update { $0.clearDone() } }
                    .buttonStyle(.plain)
                    .focusable(false)
                    .font(.system(size: 13))
                    .foregroundStyle(theme.secondary)
            }
        }
    }

    private var subtitle: String {
        switch list {
        case .three: return store.today.date().formatted(.dateTime.weekday(.wide).month(.wide).day())
        case .next: return "Scheduled days move into 3 Today when they arrive."
        default: return "Finished."
        }
    }
}

struct SectionHeader: View {
    let title: String
    var color: Color?
    @Environment(\.theme) private var theme

    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .tracking(0.8)
            .foregroundStyle(color ?? theme.faint)
            .padding(.horizontal, 12)
            .padding(.top, 22)
            .padding(.bottom, 6)
    }
}

struct AddRow: View {
    let list: ListKind
    let placeholder: String

    @EnvironmentObject private var store: BoardStore
    @Environment(\.theme) private var theme
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "plus")
                .font(.system(size: 13))
                .foregroundStyle(theme.faint)
                .frame(width: 18)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .foregroundStyle(theme.text)
                .focused($focused)
                .onSubmit {
                    let title = text
                    store.update { _ = $0.add(title, to: list) }
                    text = ""
                    focused = true
                }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

struct EmptySlotRow: View {
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .strokeBorder(theme.faint.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [2, 3]))
                .frame(width: 16, height: 16)
                .frame(width: 18)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}
