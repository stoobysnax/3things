import AppKit
import SwiftUI
import ThreeThingsCore

/// Rings alarms from inside the app: plays a sound and shows a small window on top of everything,
/// so an alarm can't be missed even if macOS notifications are off or the banner slips by.
/// System notifications (Alarms) still cover the times 3 Things isn't running.
@MainActor
final class AlarmRinger: ObservableObject {
    static let shared = AlarmRinger()

    /// Items whose alarm is going off right now.
    @Published private(set) var ringing: [UUID] = []

    private weak var store: BoardStore?
    private var timer: Timer?
    private var lastCheck = Date()
    private var panel: NSPanel?
    private var activity: NSObjectProtocol?

    func start(with store: BoardStore) {
        guard timer == nil else { return }
        self.store = store
        lastCheck = Date()
        // Keep macOS from napping the app, so alarms ring on the minute.
        activity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiatedAllowingIdleSystemSleep],
            reason: "3 Things alarms ring on time"
        )
        let timer = Timer(timeInterval: 10, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.check() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    /// Rings every 3 Things alarm whose time passed since the last check
    /// (so one due while the Mac was asleep rings when it wakes, the same day).
    func check(now: Date = Date()) {
        guard let store else { return }
        defer { lastCheck = now }
        let calendar = Calendar.current
        var newlyDue = false

        for item in store.board.liveAlarms {
            guard let alarm = item.alarm,
                  let due = calendar.date(bySettingHour: alarm.hour, minute: alarm.minute, second: 0, of: now)
            else { continue }
            if due > lastCheck, due <= now, !ringing.contains(item.id) {
                ringing.append(item.id)
                newlyDue = true
            }
        }

        // Anything finished or moved out of 3 Things stops ringing.
        let before = ringing.count
        ringing.removeAll { id in !store.board.three.contains { $0.id == id } }

        if newlyDue {
            NSSound(named: "Glass")?.play()
            showPanel()
        } else if ringing.count != before {
            ringing.isEmpty ? closePanel() : showPanel()
        }
    }

    func markDone(_ id: UUID) {
        store?.update { $0.complete(id) }
        dismiss(id)
    }

    func dismiss(_ id: UUID) {
        ringing.removeAll { $0 == id }
        ringing.isEmpty ? closePanel() : showPanel()
    }

    func dismissAll() {
        ringing.removeAll()
        closePanel()
    }

    // MARK: - Window

    private func showPanel() {
        guard let store else { return }
        closePanel()
        let hosting = NSHostingView(rootView: RingingView(ringer: self, store: store))
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: hosting.fittingSize),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = hosting
        panel.setContentSize(hosting.fittingSize)
        panel.center()
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        self.panel = panel
    }

    private func closePanel() {
        panel?.orderOut(nil)
        panel = nil
    }
}

/// The alarm window: what's due, with Done and Dismiss.
struct RingingView: View {
    @ObservedObject var ringer: AlarmRinger
    @ObservedObject var store: BoardStore
    @AppStorage("darkMode") private var darkMode = false

    var body: some View {
        let theme = darkMode ? Theme.dark : Theme.light
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: "bell.fill")
                Text("3 Things")
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(theme.secondary)

            ForEach(ringer.ringing, id: \.self) { id in
                if let item = store.board.item(id) {
                    HStack(spacing: 12) {
                        Text(item.title)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(theme.text)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 8)
                        Button("Done") { ringer.markDone(id) }
                            .controlSize(.large)
                    }
                }
            }

            HStack {
                Spacer()
                Button("Dismiss") { ringer.dismissAll() }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(20)
        .padding(.top, 8)
        .frame(width: 360)
        .background(theme.card)
        .preferredColorScheme(darkMode ? .dark : .light)
    }
}
