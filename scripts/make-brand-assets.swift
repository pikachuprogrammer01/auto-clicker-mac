#!/usr/bin/env swift
// Generates the app icon, menu bar template icons and in-window brand mark from
// Auto_Clicker_Logo_PNG_Pack. Re-run after the design pack changes.
//
//   swift scripts/make-brand-assets.swift
//
// The colour app icon ships as a full-bleed presentation export (no alpha), so it
// is re-cut onto the macOS icon grid measured from a system app icon: the shape
// covers 80.5% of the canvas with a superellipse corner of radius 0.289 * shape.

import AppKit
import Foundation

let projectDirectory = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".", isDirectory: true)
let packDirectory = projectDirectory.appendingPathComponent("Auto_Clicker_Logo_PNG_Pack")
let resourcesDirectory = projectDirectory.appendingPathComponent("Support/Resources", isDirectory: true)

let iconCanvasRatio: CGFloat = 0.805
let iconCornerRatio: CGFloat = 0.289
let iconCornerExponent: CGFloat = 2.6

func fail(_ message: String) -> Never {
    FileHandle.standardError.write("make-brand-assets: \(message)\n".data(using: .utf8)!)
    exit(1)
}

func loadBitmap(_ url: URL) -> NSBitmapImageRep {
    guard let image = NSImage(contentsOf: url),
          let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff)
    else { fail("cannot decode \(url.path)") }
    return rep
}

func image(from rep: NSBitmapImageRep) -> NSImage {
    let result = NSImage(size: NSSize(width: rep.pixelsWide, height: rep.pixelsHigh))
    result.addRepresentation(rep)
    return result
}

func makeCanvas(_ pixelsWide: Int, _ pixelsHigh: Int) -> NSBitmapImageRep {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixelsWide,
        pixelsHigh: pixelsHigh,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else { fail("cannot allocate \(pixelsWide)x\(pixelsHigh) bitmap") }
    return rep
}

func draw(into rep: NSBitmapImageRep, _ body: (NSSize) -> Void) {
    let size = NSSize(width: rep.pixelsWide, height: rep.pixelsHigh)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.compositingOperation = .copy
    NSColor.clear.setFill()
    NSRect(origin: .zero, size: size).fill()
    NSGraphicsContext.current?.compositingOperation = .sourceOver
    body(size)
    NSGraphicsContext.restoreGraphicsState()
}

/// macOS icons use continuous corners; a superellipse reproduces the silhouette
/// measured on system app icons far better than a circular arc does. The path walks
/// the four corners in order, each one sweeping from tangent direction `u` to `v`.
func squirclePath(in rect: NSRect) -> NSBezierPath {
    let radius = min(rect.width, rect.height) * iconCornerRatio
    let exponent = 2 / iconCornerExponent
    let samplesPerCorner = 28
    let corners: [(center: NSPoint, u: NSPoint, v: NSPoint)] = [
        (NSPoint(x: rect.maxX - radius, y: rect.minY + radius), NSPoint(x: 1, y: 0), NSPoint(x: 0, y: -1)),
        (NSPoint(x: rect.minX + radius, y: rect.minY + radius), NSPoint(x: 0, y: -1), NSPoint(x: -1, y: 0)),
        (NSPoint(x: rect.minX + radius, y: rect.maxY - radius), NSPoint(x: -1, y: 0), NSPoint(x: 0, y: 1)),
        (NSPoint(x: rect.maxX - radius, y: rect.maxY - radius), NSPoint(x: 0, y: 1), NSPoint(x: 1, y: 0))
    ]

    let path = NSBezierPath()
    for (index, corner) in corners.enumerated() {
        for sample in 0...samplesPerCorner {
            let t = CGFloat(sample) / CGFloat(samplesPerCorner) * .pi / 2
            let weightU = pow(cos(t), exponent)
            let weightV = pow(sin(t), exponent)
            let point = NSPoint(
                x: corner.center.x + radius * (weightU * corner.u.x + weightV * corner.v.x),
                y: corner.center.y + radius * (weightU * corner.u.y + weightV * corner.v.y)
            )
            if index == 0 && sample == 0 { path.move(to: point) } else { path.line(to: point) }
        }
    }
    path.close()
    return path
}

func writePNG(_ rep: NSBitmapImageRep, to url: URL) {
    guard let data = rep.representation(using: .png, properties: [:]) else { fail("cannot encode \(url.path)") }
    do {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    } catch {
        fail("cannot write \(url.path): \(error)")
    }
    print("  wrote \(url.path(percentEncoded: false)) (\(rep.pixelsWide)x\(rep.pixelsHigh))")
}

func drawSource(
    _ source: NSImage,
    in rect: NSRect,
    operation: NSCompositingOperation = .copy
) {
    source.draw(
        in: rect,
        from: NSRect(origin: .zero, size: source.size),
        operation: operation,
        fraction: 1,
        respectFlipped: true,
        hints: [.interpolation: NSImageInterpolation.high.rawValue]
    )
}

func renderAppIcon(canvas: Int, source: NSImage) -> NSBitmapImageRep {
    let rep = makeCanvas(canvas, canvas)
    let side = floor(CGFloat(canvas) * iconCanvasRatio)
    let inset = (CGFloat(canvas) - side) / 2
    let rect = NSRect(x: inset, y: inset, width: side, height: side)
    draw(into: rep) { _ in
        NSGraphicsContext.current?.imageInterpolation = .high
        squirclePath(in: rect).addClip()
        drawSource(source, in: rect)
    }
    return rep
}

func renderMenuBarIcon(
    scale: CGFloat,
    glyph: NSImage,
    glyphSide: CGFloat,
    canvas: NSSize,
    withBadge: Bool
) -> NSBitmapImageRep {
    let pixelsWide = Int((canvas.width * scale).rounded())
    let pixelsHigh = Int((canvas.height * scale).rounded())
    let rep = makeCanvas(pixelsWide, pixelsHigh)
    let badgeCenter = NSPoint(x: canvas.width - glyphSide * 0.18, y: canvas.height - glyphSide * 0.19)
    let badgeRadius = glyphSide * 0.165
    let haloRadius = badgeRadius * 1.55

    draw(into: rep) { _ in
        NSGraphicsContext.current?.imageInterpolation = .high
        drawSource(glyph, in: NSRect(x: 0, y: canvas.height - glyphSide, width: glyphSide, height: glyphSide))

        guard withBadge else { return }

        // Knock a transparent gap around the badge so it stays legible where it
        // overlaps the arrow head of the mark.
        let context = NSGraphicsContext.current
        context?.compositingOperation = .destinationOut
        NSBezierPath(ovalIn: NSRect(
            x: badgeCenter.x - haloRadius,
            y: badgeCenter.y - haloRadius,
            width: haloRadius * 2,
            height: haloRadius * 2
        )).fill()

        context?.compositingOperation = .sourceOver
        NSColor.black.setFill()
        NSBezierPath(ovalIn: NSRect(
            x: badgeCenter.x - badgeRadius,
            y: badgeCenter.y - badgeRadius,
            width: badgeRadius * 2,
            height: badgeRadius * 2
        )).fill()
    }
    return rep
}

func renderBrandMark(canvas: Int, source: NSImage) -> NSBitmapImageRep {
    let rep = makeCanvas(canvas, canvas)
    draw(into: rep) { size in
        NSGraphicsContext.current?.imageInterpolation = .high
        drawSource(source, in: NSRect(origin: .zero, size: size))
    }
    return rep
}

/// The lockup's wordmark is near-black, so it disappears on GitHub's dark theme.
/// Sitting it on the brand's interface background keeps one asset readable in both.
func renderBrandPlate(source: NSImage, targetWidth: Int) -> NSBitmapImageRep {
    let padding = source.size.height * 0.10
    let plateWidth = source.size.width + padding * 2
    let scale = CGFloat(targetWidth) / plateWidth
    let canvas = NSSize(
        width: CGFloat(targetWidth),
        height: ((source.size.height + padding * 2) * scale).rounded()
    )
    let rep = makeCanvas(Int(canvas.width), Int(canvas.height))
    let radius = canvas.height * 0.12
    draw(into: rep) { size in
        NSGraphicsContext.current?.imageInterpolation = .high
        NSColor(srgbRed: 247.0 / 255.0, green: 245.0 / 255.0, blue: 242.0 / 255.0, alpha: 1).setFill()
        NSBezierPath(
            roundedRect: NSRect(origin: .zero, size: size),
            xRadius: radius,
            yRadius: radius
        ).fill()
        drawSource(
            source,
            in: NSRect(
                x: padding * scale,
                y: (size.height - source.size.height * scale) / 2,
                width: size.width - padding * scale * 2,
                height: source.size.height * scale
            ),
            operation: .sourceOver
        )
    }
    return rep
}

let appIconSource = image(from: loadBitmap(packDirectory.appendingPathComponent("01_app_icon_color_1024.png")))
let brandMarkSource = image(from: loadBitmap(packDirectory.appendingPathComponent("02_symbol_color_transparent_1024.png")))
// The pack ships the menu bar mark pre-rendered at each size; using those pixels
// 1:1 keeps the thin strokes crisper than downscaling the 64 px master.
let menuBarGlyph1x = image(from: loadBitmap(packDirectory.appendingPathComponent("menu-bar/auto-clicker-menu-black-16px.png")))
let menuBarGlyph2x = image(from: loadBitmap(packDirectory.appendingPathComponent("menu-bar/auto-clicker-menu-black-32px.png")))

print("App icon")
let iconsetDirectory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    .appendingPathComponent("AutoClickerIconset-\(ProcessInfo.processInfo.processIdentifier).iconset")
try? FileManager.default.removeItem(at: iconsetDirectory)
let iconsetSizes: [(name: String, pixels: Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024)
]
for entry in iconsetSizes {
    writePNG(
        renderAppIcon(canvas: entry.pixels, source: appIconSource),
        to: iconsetDirectory.appendingPathComponent("\(entry.name).png")
    )
}

let icnsURL = resourcesDirectory.appendingPathComponent("AppIcon.icns")
let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["--convert", "icns", "--output", icnsURL.path, iconsetDirectory.path]
do {
    try FileManager.default.createDirectory(at: resourcesDirectory, withIntermediateDirectories: true)
    try iconutil.run()
    iconutil.waitUntilExit()
} catch {
    fail("iconutil failed: \(error)")
}
guard iconutil.terminationStatus == 0 else { fail("iconutil exited with \(iconutil.terminationStatus)") }
try? FileManager.default.removeItem(at: iconsetDirectory)
print("  wrote \(icnsURL.path(percentEncoded: false))")

print("Menu bar icons")
// The glyph carries its own padding inside its canvas, so it is placed at the 16 pt
// size the menu bar slot uses; the running state widens the canvas for its badge.
let menuBarGlyphSide: CGFloat = 16
let menuBarCanvas = NSSize(width: menuBarGlyphSide, height: menuBarGlyphSide)
let badgeCanvas = NSSize(width: menuBarGlyphSide * 1.25, height: menuBarGlyphSide)
for (name, withBadge, canvas) in [
    ("menu-bar-idle", false, menuBarCanvas),
    ("menu-bar-running", true, badgeCanvas)
] {
    writePNG(
        renderMenuBarIcon(scale: 1, glyph: menuBarGlyph1x, glyphSide: menuBarGlyphSide, canvas: canvas, withBadge: withBadge),
        to: resourcesDirectory.appendingPathComponent("\(name).png")
    )
    writePNG(
        renderMenuBarIcon(scale: 2, glyph: menuBarGlyph2x, glyphSide: menuBarGlyphSide, canvas: canvas, withBadge: withBadge),
        to: resourcesDirectory.appendingPathComponent("\(name)@2x.png")
    )
}

print("Brand mark")
writePNG(renderBrandMark(canvas: 22, source: brandMarkSource), to: resourcesDirectory.appendingPathComponent("brand-mark.png"))
writePNG(renderBrandMark(canvas: 44, source: brandMarkSource), to: resourcesDirectory.appendingPathComponent("brand-mark@2x.png"))

print("README artwork")
let lockupSource = image(from: loadBitmap(packDirectory.appendingPathComponent("07_logo_lockup_transparent.png")))
writePNG(
    renderBrandPlate(source: lockupSource, targetWidth: 960),
    to: projectDirectory.appendingPathComponent("docs/images/brand-lockup.png")
)
