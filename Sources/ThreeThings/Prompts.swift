import SwiftUI
import ThreeThingsCore

/// The questions 3 Today asks, shown over the window.
struct PromptOverlay: View {
    let prompt: BoardStore.Prompt
    @EnvironmentObject private var store: BoardStore
    @Environment(\.theme) private var theme

    var body: some View {
        ZStack {
            Color.black.opacity(theme.isDark ? 0.45 : 0.18)
                .ignoresSafeArea()
                .onTapGesture { store.dismissPrompt() }

            VStack(alignment: .leading, spacing: 16) {
                content
            }
            .padding(20)
            .frame(width: 380)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(theme.card)
                    .shadow(color: .black.opacity(theme.isDark ? 0.5 : 0.15), radius: 24, y: 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(theme.hairline)
            )
        }
    }

    @ViewBuilder
    private var content: some View {
        switch prompt {
        case .todayFull(let id):
            title("3 Today is full", detail: "Swap \(quoted(id)) with one of these, or schedule it for another day.")
            choices(store.board.three)
            DayPicker(label: "Schedule for", excludeToday: true) { store.scheduleInstead(on: $0) }
            footer(cancel: "Cancel")

        case .dayFull(let id, let day):
            title("You\u{2019}ve already scheduled 3 items for \(day.longLabel)",
                  detail: "Click one to swap it out for \(quoted(id)).")
            choices(store.board.scheduled(on: day))
            footer(cancel: "Cancel")

        case .bumped(let id):
            title("\(quoted(id)) was bumped", detail: "It\u{2019}s in Unscheduled now. Schedule it for another day?")
            DayPicker(label: "Schedule for", excludeToday: true) { store.scheduleInstead(on: $0) }
            footer(cancel: "Nah, leave it unscheduled")
        }
    }

    private func quoted(_ id: UUID) -> String {
        "\u{201C}\(store.board.item(id)?.title ?? "This")\u{201D}"
    }

    private func title(_ text: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(text)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(theme.text)
                .fixedSize(horizontal: false, vertical: true)
            Text(detail)
                .font(.system(size: 13))
                .foregroundStyle(theme.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func choices(_ items: [Item]) -> some View {
        VStack(spacing: 6) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                SwapChoice(position: index + 1, item: item) {
                    store.swap(with: item.id)
                }
            }
        }
    }

    private func footer(cancel: String) -> some View {
        HStack {
            Spacer()
            Button(cancel) { store.dismissPrompt() }
                .buttonStyle(.plain)
                .focusable(false)
                .font(.system(size: 13))
                .foregroundStyle(theme.secondary)
                .keyboardShortcut(.cancelAction)
        }
    }
}

/// Quick day choices: Tomorrow, the next few weekdays, or any date.
struct DayPicker: View {
    let label: String
    var excludeToday = false
    let pick: (Day) -> Void

    @EnvironmentObject private var store: BoardStore
    @Environment(\.theme) private var theme
    @State private var other = Date().addingTimeInterval(86_400 * 7)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(theme.faint)
            HStack(spacing: 6) {
                ForEach(1...5, id: \.self) { ahead in
                    let day = store.today.adding(days: ahead)
                    chip(ahead == 1 ? "Tomorrow" : day.shortLabel(today: store.today)) { pick(day) }
                }
            }
            HStack(spacing: 8) {
                DatePicker("Day", selection: $other, in: Date().addingTimeInterval(86_400)..., displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.field)
                chip("Schedule") { pick(Day(other)) }
            }
        }
    }

    private func chip(_ title: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(theme.text)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(theme.fill))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .focusable(false)
    }
}

struct SwapChoice: View {
    let position: Int
    let item: Item
    let choose: () -> Void

    @Environment(\.theme) private var theme
    @State private var hovering = false

    var body: some View {
        Button(action: choose) {
            HStack(spacing: 12) {
                Text("\(position)")
                    .font(.system(size: 13))
                    .monospacedDigit()
                    .foregroundStyle(theme.faint)
                    .frame(width: 14)
                Text(item.title)
                    .font(.system(size: 14))
                    .foregroundStyle(theme.text)
                    .lineLimit(1)
                Spacer()
                Text("Swap")
                    .font(.system(size: 11))
                    .foregroundStyle(theme.secondary)
                    .opacity(hovering ? 1 : 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(hovering ? theme.fillStrong : theme.fill)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .onHover { hovering = $0 }
    }
}
