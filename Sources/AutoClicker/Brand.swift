import AppKit
import SwiftUI

enum Brand {
    static let accent = Color(.sRGB, red: 1.0, green: 90.0 / 255.0, blue: 54.0 / 255.0)

    static func menuBarIcon(running: Bool) -> NSImage {
        let image = bundledImage(
            running ? "menu-bar-running" : "menu-bar-idle",
            symbol: running ? "cursorarrow.click.2" : "cursorarrow"
        )
        image.isTemplate = true
        image.accessibilityDescription = "Auto Clicker"
        return image
    }

    static func controlPanelMark() -> NSImage {
        bundledImage("brand-mark", symbol: "cursorarrow.click.2")
    }

    /// Falls back to the system symbol when the app runs unpackaged, where bundle
    /// resources are not present.
    private static func bundledImage(_ name: String, symbol: String) -> NSImage {
        if let image = NSImage(named: NSImage.Name(name)) {
            return image
        }
        return NSImage(systemSymbolName: symbol, accessibilityDescription: name) ?? NSImage()
    }
}
