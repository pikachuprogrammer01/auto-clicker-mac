import ApplicationServices
import Foundation

@main
struct AutoClickerChecks {
    static func main() throws {
        try validateSettings()
        try validateFiniteClickRun()
        try validateLongPressStop()
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

    private static func validateFiniteClickRun() throws {
        let poster = RecordingMouseEventPoster()
        let engine = MouseClickEngine(poster: poster)
        let finished = DispatchSemaphore(value: 0)
        let location = CGPoint(x: 321, y: 654)

        engine.start(
            runID: UUID(),
            configuration: ClickConfiguration(
                mouseButton: .left,
                clickType: .single,
                intervalMilliseconds: 10,
                clickLimit: 3,
                longPressMilliseconds: 500
            ),
            location: location,
            onClick: { _, _ in },
            onFinished: { _ in finished.signal() }
        )

        try require(finished.wait(timeout: .now() + 1) == .success, "finite run did not finish")
        engine.stop()

        let events = poster.events
        try require(events.count == 6, "finite run posted \(events.count) events instead of 6")
        try require(
            events.map(\.type) == [
                .leftMouseDown, .leftMouseUp,
                .leftMouseDown, .leftMouseUp,
                .leftMouseDown, .leftMouseUp
            ],
            "finite run posted mouse events in the wrong order"
        )
        try require(events.allSatisfy { $0.location == location }, "click position changed during a run")
    }

    private static func validateLongPressStop() throws {
        let poster = RecordingMouseEventPoster()
        let engine = MouseClickEngine(poster: poster)
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
            location: CGPoint(x: 10, y: 20),
            onClick: { _, _ in },
            onFinished: { _ in }
        )

        try require(mouseDown.wait(timeout: .now() + 1) == .success, "long press did not start")
        let start = Date()
        engine.stop()

        try require(Date().timeIntervalSince(start) < 0.25, "stop did not wake the long press promptly")
        try require(
            poster.events.map(\.type) == [.rightMouseDown, .rightMouseUp],
            "stopping a long press did not release the mouse"
        )
    }

    private static func require(
        _ condition: @autoclosure () -> Bool,
        _ message: @autoclosure () -> String
    ) throws {
        guard condition() else { throw CheckFailure(message()) }
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
