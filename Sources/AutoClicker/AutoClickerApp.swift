import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    var onTerminate: (() -> Void)?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    func applicationWillTerminate(_ notification: Notification) {
        onTerminate?()
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        if !flag {
            sender.windows
                .first(where: { $0.title == "Auto Clicker" })?
                .makeKeyAndOrderFront(nil)
        }
        sender.activate(ignoringOtherApps: true)
        return true
    }
}

@main
struct AutoClickerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel()

    var body: some Scene {
        Window("Auto Clicker", id: "control-panel") {
            controlPanel
        }
        .windowResizability(.contentSize)

        MenuBarExtra {
            controlPanel
        } label: {
            Label("Auto Clicker", systemImage: model.state.isRunning ? "cursorarrow.click.2" : "cursorarrow")
        }
        .menuBarExtraStyle(.window)
    }

    private var controlPanel: some View {
        ContentView(model: model)
            .onAppear {
                appDelegate.onTerminate = model.terminate
                NSApplication.shared.activate(ignoringOtherApps: true)
            }
    }
}
