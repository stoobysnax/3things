import SwiftUI
import UserNotifications

@main
struct ThreeThingsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = BoardStore()
    @AppStorage("darkMode") private var darkMode = false

    var body: some Scene {
        WindowGroup("3 Today", id: "main") {
            ContentView()
                .environmentObject(store)
                .environment(\.theme, darkMode ? .dark : .light)
                .preferredColorScheme(darkMode ? .dark : .light)
                .onAppear { applyAppearance() }
                .onChange(of: darkMode) { _ in applyAppearance() }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 720, height: 460)

        MenuBarExtra {
            MenuBarPanel()
                .environmentObject(store)
                .environment(\.theme, darkMode ? .dark : .light)
                .preferredColorScheme(darkMode ? .dark : .light)
        } label: {
            MenuBarLabel()
        }
        .menuBarExtraStyle(.window)
    }

    /// Keeps menus, popovers and text fields in the same look as the window.
    private func applyAppearance() {
        NSApp.appearance = NSAppearance(named: darkMode ? .darkAqua : .aqua)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    // Closing the window keeps 3 Today in the menu bar.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if Alarms.available {
            UNUserNotificationCenter.current().delegate = self
        }
    }

    // While the app is running it rings alarms itself (AlarmRinger), so the system
    // notification just goes quietly into Notification Center instead of doubling up.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.list])
    }
}
