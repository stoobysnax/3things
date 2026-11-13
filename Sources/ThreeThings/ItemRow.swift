import SwiftUI
import ThreeThingsCore

struct ItemRow: View {
    let item: Item
    let list: ListKind

    @EnvironmentObject private var store: BoardStore
    @Environment(\.theme) private var theme
    @State private var hovering = false
    @State private var editing = false
    @State private var draft = ""
    @State private var whenOpen = false
    @FocusState private var fieldFocused: Bool

    private var isDone: Bool { list == .done }

    var body: some View {
        HStack(spacing: 12) {
            Button(action: toggleDone) {
                Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 17, weight: .light))
                    .foregroundStyle(isDone ? theme.faint : (hovering ? theme.secondary : theme.faint))
                    .frame(width: 18)
            }
            .buttonStyle(.plain)
            .focusable(false)
            .help(isDone ? "Mark as not done" : "Mark as done")

            if editing {
                TextField("", text: $draft)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15))
                    .foregroundStyle(theme.text)
                    .focused($fieldFocused)
                    .onSubmit(commitEdit)
                    .onExitCommand { editing = false }
                    .onChange(of: fieldFocused) { focused in
                        if !focused { commitEdit() }
                    }
            } else {
                Text(item.title)
                    .font(.system(size: 15))
                    .strikethrough(isDone, color: theme.faint)
                    .foregroundStyle(isDone ? theme.secondary : theme.text)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2, perform: startEdit)
            }

            if !isDone {
                WhenButton(item: item, list: list, rowHovering: hovering, open: $whenOpen)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(hovering ? theme.fill : .clear)
        )
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .contextMenu {
            Button("Rename", action: startEdit)
            if !isDone {
                Button("Schedule…") { whenOpen = true }
            }
            Divider()
            if list != .three {
                Button("Move to 3 Today") { store.send(item.id, to: .three) }
            }
            if list != .next || item.day != nil {
                Button(list == .next ? "Unschedule" : "Move to Next") { store.moveToNext(item.id) }
            }
            if list != .done {
                Button("Move to Done") { store.send(item.id, to: .done) }
            }
            Divider()
            Button("Delete", role: .destructive) {
                store.update { $0.delete(item.id) }
            }
        }
    }

    private func toggleDone() {
        if isDone {
            store.update { $0.reopen(item.id) }
        } else {
            store.update { $0.complete(item.id) }
        }
    }

    private func startEdit() {
        draft = item.title
        editing = true
        DispatchQueue.main.async { fieldFocused = true }
    }

    private func commitEdit() {
        guard editing else { return }
        let title = draft
        store.update { $0.rename(item.id, to: title) }
        editing = false
    }
}

// MARK: - Missed

/// A task left unfinished when its day ended. Greyed, on a soft tint, until you decide:
/// one click asks "Keep in today" or "Move to Next".
struct MissedRow: View {
    let item: Item

    @EnvironmentObject private var store: BoardStore
    @Environment(\.theme) private var theme
    @State private var hovering = false
    @State private var open = false

    var body: some View {
        Button {
            open = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "circle")
                    .font(.system(size: 17, weight: .light))
                    .foregroundStyle(theme.faint)
                    .frame(width: 18)
                Text(item.title)
                    .font(.system(size: 15))
                    .foregroundStyle(theme.secondary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let day = item.missedOn {
                    Text(day.missedLabel(today: store.today))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(theme.missedLabel)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(theme.missedFill.opacity(hovering ? 1 : 0.75))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .padding(.vertical, 2)
        .onHover { hovering = $0 }
        .popover(isPresented: $open, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 12) {
                Text(item.title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(2)
                HStack(spacing: 8) {
                    Button("Keep in today") {
                        open = false
                        store.keepInToday(item.id)
                    }
                    .keyboardShortcut(.defaultAction)
                    Button("Move to Next") {
                        open = false
                        store.moveToNext(item.id)
                    }
                }
            }
            .padding(14)
        }
        .contextMenu {
            Button("Keep in today") { store.keepInToday(item.id) }
            Button("Move to Next") { store.moveToNext(item.id) }
            Divider()
            Button("Mark as done") { store.update { $0.complete(item.id) } }
            Button("Delete", role: .destructive) { store.update { $0.delete(item.id) } }
        }
    }
}

// MARK: - When

/// The one "when" button: pick a day (optional) and a time (optional), or type it.
/// Hidden until you hover the row, unless something is set.
struct WhenButton: View {
    let item: Item
    let list: ListKind
    let rowHovering: Bool
    @Binding var open: Bool

    @EnvironmentObject private var store: BoardStore
    @Environment(\.theme) private var theme

    private var label: String? { item.whenLabel(today: store.today, inToday: list == .three) }
    private var ringing: Bool { item.alarm != nil && list == .three }

    var body: some View {
        Button {
            open = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: item.alarm != nil ? (ringing ? "bell.fill" : "bell") : "calendar")
                if let label {
                    Text(label).monospacedDigit()
                }
            }
            .font(.system(size: 12))
            .foregroundStyle(ringing ? theme.text.opacity(0.85) : theme.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(label != nil ? theme.fill : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .opacity(label != nil || rowHovering || open ? 1 : 0)
        .help(label == nil ? "Schedule or set an alarm" : "Change when")
        .popover(isPresented: $open, arrowEdge: .bottom) {
            WhenEditor(item: item, list: list, close: { open = false })
                .environmentObject(store)
        }
    }
}

struct WhenEditor: View {
    let item: Item
    let list: ListKind
    let close: () -> Void

    @EnvironmentObject private var store: BoardStore
    @State private var typed = ""
    /// nil = no date (Unscheduled).
    @State private var day: Day?
    @State private var otherDate = Date()
    @State private var useTime = false
    @State private var time = Date()
    @State private var notificationsOff = false
    @FocusState private var typing: Bool

    private var parsed: AlarmParser.When? { AlarmParser.parseWhen(typed) }
    private var today: Day { store.today }

    /// The day and time that "Set" would use.
    private var result: (day: Day?, time: AlarmTime?) {
        let chosenTime = useTime ? AlarmTime(date: time) : nil
        guard let parsed else { return (day, chosenTime) }
        return (parsed.day ?? day, parsed.time ?? chosenTime)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("When")
                .font(.system(size: 13, weight: .semibold))

            VStack(alignment: .leading, spacing: 6) {
                TextField("tomorrow 9am, mon, 5 min, 9pm…", text: $typed)
                    .textFieldStyle(.roundedBorder)
                    .focused($typing)
                    .onSubmit(apply)
                if !typed.isEmpty {
                    Text(preview)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 6) {
                dayChip("Today", today)
                dayChip("Tomorrow", today.adding(days: 1))
                dayChip("No date", nil)
            }

            HStack(spacing: 8) {
                Text("Other day")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                DatePicker("Day", selection: $otherDate, in: Date()..., displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.field)
                    .onChange(of: otherDate) { day = Day($0) }
            }

            HStack(spacing: 8) {
                Toggle("Remind me at", isOn: $useTime)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 12))
                DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .datePickerStyle(.field)
                    .disabled(!useTime)
            }

            if notificationsOff {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Notifications are off for 3 Today, so alarms only ring while the app is running.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Turn on notifications") { Alarms.openNotificationSettings() }
                        .buttonStyle(.link)
                        .font(.system(size: 11))
                }
            }

            HStack {
                Spacer()
                Button("Set", action: apply)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!typed.isEmpty && parsed == nil)
            }
        }
        .padding(16)
        .frame(width: 290)
        .onAppear {
            day = list == .three ? today : item.day
            if let d = item.day { otherDate = d.date() }
            useTime = item.alarm != nil
            time = (item.alarm ?? .suggested).date
            DispatchQueue.main.async { typing = true }
            Alarms.checkNotificationsOff { notificationsOff = $0 }
        }
    }

    private var preview: String {
        guard parsed != nil else { return "Try \u{201C}tomorrow 9am\u{201D}, \u{201C}fri\u{201D}, \u{201C}20 min\u{201D} or \u{201C}9:30pm\u{201D}" }
        let r = result
        let dayText = r.day.map { $0 == today ? "Today" : $0.longLabel } ?? "No date"
        return r.time.map { "\(dayText) at \($0.label)" } ?? dayText
    }

    private func dayChip(_ title: String, _ value: Day?) -> some View {
        let selected = day == value
        return Button { day = value } label: {
            Text(title)
                .font(.system(size: 12, weight: selected ? .semibold : .regular))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.primary.opacity(selected ? 0.14 : 0.05)))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .focusable(false)
    }

    private func apply() {
        if !typed.isEmpty && parsed == nil { return }
        let r = result
        let id = item.id
        close()
        store.update { $0.setAlarm(r.time, for: id) }
        store.schedule(id, on: r.day)
    }
}
