import ApplicationServices
import Foundation

protocol MouseEventPosting {
    func post(type: CGEventType, button: CGMouseButton, at location: CGPoint)
}

struct SystemMouseEventPoster: MouseEventPosting {
    func post(type: CGEventType, button: CGMouseButton, at location: CGPoint) {
        guard let event = CGEvent(
            mouseEventSource: nil,
            mouseType: type,
            mouseCursorPosition: location,
            mouseButton: button
        ) else { return }
        event.post(tap: .cghidEventTap)
    }
}

final class MouseClickEngine: @unchecked Sendable {
    private let condition = NSCondition()
    private let workerQueue = DispatchQueue(label: "com.autoclicker.click-engine", qos: .userInteractive)
    private let poster: MouseEventPosting

    private var activeRunID: UUID?
    private var currentGroup: DispatchGroup?

    init(poster: MouseEventPosting = SystemMouseEventPoster()) {
        self.poster = poster
    }

    func start(
        runID: UUID,
        configuration: ClickConfiguration,
        location: CGPoint,
        onClick: @escaping (UUID, Int) -> Void,
        onFinished: @escaping (UUID) -> Void
    ) {
        stop()

        let group = DispatchGroup()
        group.enter()

        condition.lock()
        activeRunID = runID
        currentGroup = group
        condition.unlock()

        workerQueue.async { [weak self] in
            defer { group.leave() }
            self?.run(
                id: runID,
                configuration: configuration,
                location: location,
                onClick: onClick,
                onFinished: onFinished
            )
        }
    }

    func stop() {
        condition.lock()
        activeRunID = nil
        let group = currentGroup
        condition.broadcast()
        condition.unlock()

        group?.wait()

        condition.lock()
        if currentGroup === group {
            currentGroup = nil
        }
        condition.unlock()
    }

    private func run(
        id: UUID,
        configuration: ClickConfiguration,
        location: CGPoint,
        onClick: @escaping (UUID, Int) -> Void,
        onFinished: @escaping (UUID) -> Void
    ) {
        var count = 0
        var finishedNaturally = false

        while performClick(id: id, configuration: configuration, location: location) {
            count += 1
            onClick(id, count)

            if let limit = configuration.clickLimit, count >= limit {
                finishedNaturally = true
                break
            }

            guard wait(
                milliseconds: configuration.intervalMilliseconds,
                whileRunIsActive: id
            ) else { break }
        }

        condition.lock()
        if activeRunID == id {
            activeRunID = nil
        }
        condition.unlock()

        if finishedNaturally {
            onFinished(id)
        }
    }

    private func performClick(
        id: UUID,
        configuration: ClickConfiguration,
        location: CGPoint
    ) -> Bool {
        let button: CGMouseButton = configuration.mouseButton == .left ? .left : .right
        let downType: CGEventType = configuration.mouseButton == .left ? .leftMouseDown : .rightMouseDown
        let upType: CGEventType = configuration.mouseButton == .left ? .leftMouseUp : .rightMouseUp

        condition.lock()
        guard activeRunID == id else {
            condition.unlock()
            return false
        }

        poster.post(type: downType, button: button, at: location)

        if configuration.clickType == .single {
            poster.post(type: upType, button: button, at: location)
            condition.unlock()
            return true
        }
        condition.unlock()

        let completedHold = wait(
            milliseconds: configuration.longPressMilliseconds,
            whileRunIsActive: id
        )

        // A mouse-down must always have a matching mouse-up, including when stopping mid-hold.
        poster.post(type: upType, button: button, at: location)
        return completedHold
    }

    private func wait(milliseconds: Int, whileRunIsActive id: UUID) -> Bool {
        condition.lock()
        defer { condition.unlock() }

        guard activeRunID == id else { return false }
        let deadline = Date(timeIntervalSinceNow: Double(milliseconds) / 1_000)
        _ = condition.wait(until: deadline)
        return activeRunID == id
    }
}
