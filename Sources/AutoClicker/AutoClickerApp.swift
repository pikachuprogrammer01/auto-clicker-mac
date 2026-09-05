import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    var onTerminate: (() -> Void)?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Keep the app visible in Command+Tab while retaining the menu bar entry.
        NSApplication.shared.setActivationPolicy(.regular)
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
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        Window("Auto Clicker", id: "control-panel") {
            controlPanel
        }
        .windowResizability(.contentSize)

        MenuBarExtra {
            Button(model.state.isRunning ? "停止点击" : "开始点击") {
                model.toggleClicking()
            }
            .disabled(!model.hasAccessibilityPermission)
            Divider()
            Button("打开控制面板") {
                NSApplication.shared.activate(ignoringOtherApps: true)
                openWindow(id: "control-panel")
            }
            Button("退出 Auto Clicker") {
                model.terminate()
                NSApplication.shared.terminate(nil)
            }
        } label: {
            Label("Auto Clicker", systemImage: model.state.isRunning ? "cursorarrow.click.2" : "cursorarrow")
        }
        .menuBarExtraStyle(.menu)
    }

    private var controlPanel: some View {
        ContentView(model: model)
            .onAppear {
                appDelegate.onTerminate = model.terminate
                NSApplication.shared.activate(ignoringOtherApps: true)
            }
    }
}
