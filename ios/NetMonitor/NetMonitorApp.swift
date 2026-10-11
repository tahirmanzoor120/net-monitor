import SwiftUI

@main
struct NetMonitorApp: App {
    @State private var monitor = TrafficMonitor()
    @Environment(\.scenePhase) private var phase

    var body: some Scene {
        WindowGroup {
            ContentView(monitor: monitor)
                .onChange(of: phase, initial: true) { _, new in
                    // iOS suspends apps in the background, so only sample while visible.
                    if new == .active { monitor.start() } else { monitor.stop() }
                }
        }
    }
}
