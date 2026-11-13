import SwiftUI
import ThreeThingsCore

/// The menu bar icon: a circled number showing how many of today's 3 Things are left.
struct MenuBarLabel: View {
    @EnvironmentObject private var store: BoardStore

    var body: some View {
        Image(systemName: "\(min(store.board.three.count, Board.limit)).circle")
    }
}

/// The small panel that drops down from the menu bar: today's 3 Things, check them off in one click.
struct MenuBarPanel: View {
    @EnvironmentObject private var store: BoardStore
    @Environment(\.theme) private var theme
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("3 Things")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(theme.text)
                Spacer()
                Text(Date().formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                    .font(.system(size: 12))
                    .foregroundStyle(theme.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 8)

            VStack(spacing: 2) {
                ForEach(store.board.three) { item in
                    MenuBarRow(item: item)
                }
                if store.board.three.count < Board.limit {
                    AddRow(list: .three, placeholder: "Add a thing")
                }
            }
            .padding(.horizontal, 6)

            Rectangle()
                .fill(theme.hairline)
                .frame(height: 1)
                .padding(.top, 8)

            HStack {
                Button("Open 3 Things") {
                    openWindow(id: "main")
                    NSApp.activate(ignoringOtherApps: true)
                }
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
            }
            .buttonStyle(.plain)
            .font(.system(size: 12))
            .foregroundStyle(theme.secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .frame(width: 300)
        .background(theme.background)
    }
}

struct MenuBarRow: View {
    let item: Item
    @EnvironmentObject private var store: BoardStore
    @Environment(\.theme) private var theme
    @State private var hovering = false

    var body: some View {
        Button {
            store.update { $0.complete(item.id) }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: hovering ? "checkmark.circle" : "circle")
                    .font(.system(size: 15, weight: .light))
                    .foregroundStyle(hovering ? theme.secondary : theme.faint)
                    .frame(width: 18)
                Text(item.title)
                    .font(.system(size: 14))
                    .foregroundStyle(theme.text)
                    .lineLimit(1)
                Spacer(minLength: 8)
                if let alarm = item.alarm {
                    HStack(spacing: 3) {
                        Image(systemName: "bell.fill")
                        Text(alarm.label).monospacedDigit()
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(theme.secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(hovering ? theme.fill : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help("Mark as done")
    }
}
