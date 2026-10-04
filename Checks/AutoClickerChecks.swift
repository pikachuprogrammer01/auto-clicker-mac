import AppKit
import ApplicationServices
import Foundation

@main
struct AutoClickerChecks {
    static func main() throws {
        try validateSettings()
        try validateCursorFollowingRun()
        try validateLongPressStop()
        try validateLocationFailureStopsRun()
        try validateBrandAssets()
        print("All Auto Clicker checks passed.")
    }

    private static func validateSettings() throws {
        let configuration = try SettingsValidator.configuration(
            input: SettingsInput(interval: "100", clickCount: "25", longPressDuration: "500"),
            mouseButton: .right,
            clickType: .longPress,
            countMode: .specified
        )
        try require(configuration.clickLimit == 25, "specified click count was not preserved")
        try require(configuration.longPressMilliseconds == 500, "long-press duration was not preserved")

        do {
            _ = try SettingsValidator.configuration(
                input: SettingsInput(interval: "0", clickCount: "1", longPressDuration: "500"),
                mouseButton: .left,
                clickType: .single,
                countMode: .unlimited
            )
            throw CheckFailure("an invalid interval was accepted")
        } catch SettingsValidationError.invalidInterval {
            // Expected.
        }

        do {
            _ = try SettingsValidator.configuration(
                input: SettingsInput(interval: "100", clickCount: "abc", longPressDuration: "500"),
                mouseButton: .left,
                clickType: .single,
                countMode: .specified
            )
            throw CheckFailure("a non-numeric click count was accepted")
        } catch SettingsValidationError.invalidClickCount {
            // Expected.
        }
    }

    private static func validateCursorFollowingRun() throws {
        let poster = RecordingMouseEventPoster()
        let locations = [
            CGPoint(x: 100, y: 200),
            CGPoint(x: 300, y: 400),
            CGPoint(x: 500, y: 600)
        ]
        let locationProvider = SequenceMouseLocationProvider(locations)
        let engine = MouseClickEngine(poster: poster, locationProvider: locationProvider)
        let finished = DispatchSemaphore(value: 0)
        var finishResult: MouseClickEngineResult?

        engine.start(
            runID: UUID(),
            configuration: ClickConfiguration(
                mouseButton: .left,
                clickType: .single,
                intervalMilliseconds: 10,
                clickLimit: 3,
                longPressMilliseconds: 500
            ),
            onClick: { _, _ in },
            onFinished: { _, result in
                finishResult = result
                finished.signal()
            }
        )

        try require(finished.wait(timeout: .now() + 1) == .success, "finite run did not finish")
        engine.stop()

        let events = poster.events
        try require(finishResult == .completed, "finite run returned an unexpected result")
        try require(events.count == 6, "finite run posted \(events.count) events instead of 6")
        try require(
            events.map(\.type) == [
                .leftMouseDown, .leftMouseUp,
                .leftMouseDown, .leftMouseUp,
                .leftMouseDown, .leftMouseUp
            ],
            "finite run posted mouse events in the wrong order"
        )
        try require(
            events.map(\.location) == locations.flatMap { [$0, $0] },
            "clicks did not follow the current mouse position"
        )
    }

    private static func validateLongPressStop() throws {
        let poster = RecordingMouseEventPoster()
        let pressLocation = CGPoint(x: 10, y: 20)
        let releaseLocation = CGPoint(x: 30, y: 40)
        let locationProvider = SequenceMouseLocationProvider([pressLocation, releaseLocation])
        let engine = MouseClickEngine(poster: poster, locationProvider: locationProvider)
        let mouseDown = DispatchSemaphore(value: 0)
        poster.onPost = { event in
            if event.type == .rightMouseDown { mouseDown.signal() }
        }

        engine.start(
            runID: UUID(),
            configuration: ClickConfiguration(
                mouseButton: .right,
                clickType: .longPress,
                intervalMilliseconds: 1_000,
                clickLimit: nil,
                longPressMilliseconds: 60_000
            ),
            onClick: { _, _ in },
            onFinished: { _, _ in }
        )

        try require(mouseDown.wait(timeout: .now() + 1) == .success, "long press did not start")
        let start = Date()
        engine.stop()

        try require(Date().timeIntervalSince(start) < 0.25, "stop did not wake the long press promptly")
        try require(
            poster.events.map(\.type) == [.rightMouseDown, .rightMouseUp],
            "stopping a long press did not release the mouse"
        )
        try require(
            poster.events.map(\.location) == [pressLocation, releaseLocation],
            "long press release did not follow the current mouse position"
        )
    }

    private static func validateLocationFailureStopsRun() throws {
        let poster = RecordingMouseEventPoster()
        let engine = MouseClickEngine(
            poster: poster,
            locationProvider: SequenceMouseLocationProvider([])
        )
        let finished = DispatchSemaphore(value: 0)
        var finishResult: MouseClickEngineResult?

        engine.start(
            runID: UUID(),
            configuration: ClickConfiguration(
                mouseButton: .left,
                clickType: .single,
                intervalMilliseconds: 100,
                clickLimit: nil,
                longPressMilliseconds: 500
            ),
            onClick: { _, _ in },
            onFinished: { _, result in
                finishResult = result
                finished.signal()
            }
        )

        try require(finished.wait(timeout: .now() + 1) == .success, "location failure did not stop the run")
        engine.stop()
        try require(finishResult == .locationUnavailable, "location failure returned an unexpected result")
        try require(poster.events.isEmpty, "location failure posted a mouse event")
    }

    /// The app icon and menu bar marks are generated into `Support/Resources` and copied
    /// into the bundle at build time, so a missing or stale file silently degrades to the
    /// system placeholder icon.
    private static func validateBrandAssets() throws {
        let resourcesDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Support/Resources", isDirectory: true)

        let expectedSizes: [String: (width: Int, height: Int)] = [
            "menu-bar-idle.png": (16, 16),
            "menu-bar-idle@2x.png": (32, 32),
            "menu-bar-running.png": (20, 16),
            "menu-bar-running@2x.png": (40, 32),
            "brand-mark.png": (22, 22),
            "brand-mark@2x.png": (44, 44)
        ]

        for name in ["AppIcon.icns"] + expectedSizes.keys.sorted() {
            let url = resourcesDirectory.appendingPathComponent(name)
            guard let data = try? Data(contentsOf: url) else {
                throw CheckFailure("missing brand asset Support/Resources/\(name); run `swift scripts/make-brand-assets.swift`")
            }
            try require(!data.isEmpty, "brand asset Support/Resources/\(name) is empty")
            guard let expected = expectedSizes[name] else { continue }
            guard let bitmap = NSBitmapImageRep(data: data) else {
                throw CheckFailure("brand asset Support/Resources/\(name) cannot be decoded")
            }
            try require(
                bitmap.pixelsWide == expected.width && bitmap.pixelsHigh == expected.height,
                "brand asset Support/Resources/\(name) is \(bitmap.pixelsWide)x\(bitmap.pixelsHigh), expected \(expected.width)x\(expected.height)"
            )
        }
    }

    private static func require(
        _ condition: @autoclosure () -> Bool,
        _ message: @autoclosure () -> String
    ) throws {
        guard condition() else { throw CheckFailure(message()) }
    }
}

private final class SequenceMouseLocationProvider: MouseLocationProviding {
    private let lock = NSLock()
    private var locations: [CGPoint]

    init(_ locations: [CGPoint]) {
        self.locations = locations
    }

    func currentLocation() -> CGPoint? {
        lock.lock()
        defer { lock.unlock() }
        guard !locations.isEmpty else { return nil }
        return locations.removeFirst()
    }
}

private struct CheckFailure: LocalizedError {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var errorDescription: String? { message }
}

private final class RecordingMouseEventPoster: MouseEventPosting {
    struct Event {
        let type: CGEventType
        let button: CGMouseButton
        let location: CGPoint
    }

    private let lock = NSLock()
    private var storedEvents: [Event] = []
    var onPost: ((Event) -> Void)?

    var events: [Event] {
        lock.lock()
        defer { lock.unlock() }
        return storedEvents
    }

    func post(type: CGEventType, button: CGMouseButton, at location: CGPoint) {
        let event = Event(type: type, button: button, location: location)
        lock.lock()
        storedEvents.append(event)
        let callback = onPost
        lock.unlock()
        callback?(event)
    }
}
