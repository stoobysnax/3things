import SwiftUI
import UserNotifications

@main
struct ThreeThingsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = BoardStore()
    @AppStorage("darkMode") private var darkMode = false

    var body: some Scene {
        WindowGroup("3 Things") {
            ContentView()
                .environmentObject(store)
                .environment(\.theme, darkMode ? .dark : .light)
                .preferredColorScheme(darkMode ? .dark : .light)
                .onAppear { applyAppearance() }
                .onChange(of: darkMode) { _ in applyAppearance() }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 720, height: 460)
    }

    /// Keeps menus, popovers and text fields in the same look as the window.
    private func applyAppearance() {
        NSApp.appearance = NSAppearance(named: darkMode ? .darkAqua : .aqua)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        if Alarms.available {
            UNUserNotificationCenter.current().delegate = self
        }
    }

    // Show the alarm even when 3 Things is the app in front.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .list])
    }
}
