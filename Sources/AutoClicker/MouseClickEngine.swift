import ApplicationServices
import Foundation

protocol MouseEventPosting {
    func post(type: CGEventType, button: CGMouseButton, at location: CGPoint)
}

protocol MouseLocationProviding {
    func currentLocation() -> CGPoint?
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

struct SystemMouseLocationProvider: MouseLocationProviding {
    func currentLocation() -> CGPoint? {
        CGEvent(source: nil)?.location
    }
}

enum MouseClickEngineResult: Equatable {
    case completed
    case locationUnavailable
}

final class MouseClickEngine: @unchecked Sendable {
    private let condition = NSCondition()
    private let workerQueue = DispatchQueue(label: "com.autoclicker.click-engine", qos: .userInteractive)
    private let poster: MouseEventPosting
    private let locationProvider: MouseLocationProviding

    private var activeRunID: UUID?
    private var currentGroup: DispatchGroup?

    init(
        poster: MouseEventPosting = SystemMouseEventPoster(),
        locationProvider: MouseLocationProviding = SystemMouseLocationProvider()
    ) {
        self.poster = poster
        self.locationProvider = locationProvider
    }

    func start(
        runID: UUID,
        configuration: ClickConfiguration,
        onClick: @escaping (UUID, Int) -> Void,
        onFinished: @escaping (UUID, MouseClickEngineResult) -> Void
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
        onClick: @escaping (UUID, Int) -> Void,
        onFinished: @escaping (UUID, MouseClickEngineResult) -> Void
    ) {
        var count = 0
        var result: MouseClickEngineResult?

        clickLoop: while true {
            switch performClick(id: id, configuration: configuration) {
            case .posted:
                break
            case .stopped:
                break clickLoop
            case .locationUnavailable:
                result = .locationUnavailable
                break clickLoop
            }

            count += 1
            onClick(id, count)

            if let limit = configuration.clickLimit, count >= limit {
                result = .completed
                break clickLoop
            }

            guard wait(
                milliseconds: configuration.intervalMilliseconds,
                whileRunIsActive: id
            ) else { break clickLoop }
        }

        condition.lock()
        if activeRunID == id {
            activeRunID = nil
        }
        condition.unlock()

        if let result {
            onFinished(id, result)
        }
    }

    private enum ClickAttempt {
        case posted
        case stopped
        case locationUnavailable
    }

    private func performClick(
        id: UUID,
        configuration: ClickConfiguration
    ) -> ClickAttempt {
        let button: CGMouseButton = configuration.mouseButton == .left ? .left : .right
        let downType: CGEventType = configuration.mouseButton == .left ? .leftMouseDown : .rightMouseDown
        let upType: CGEventType = configuration.mouseButton == .left ? .leftMouseUp : .rightMouseUp

        guard let location = locationProvider.currentLocation() else {
            condition.lock()
            let isActive = activeRunID == id
            condition.unlock()
            return isActive ? .locationUnavailable : .stopped
        }

        condition.lock()
        guard activeRunID == id else {
            condition.unlock()
            return .stopped
        }

        poster.post(type: downType, button: button, at: location)

        if configuration.clickType == .single {
            poster.post(type: upType, button: button, at: location)
            condition.unlock()
            return .posted
        }
        condition.unlock()

        let completedHold = wait(
            milliseconds: configuration.longPressMilliseconds,
            whileRunIsActive: id
        )

        // A mouse-down must always have a matching mouse-up, including when stopping mid-hold.
        let releaseLocation = locationProvider.currentLocation() ?? location
        poster.post(type: upType, button: button, at: releaseLocation)
        return completedHold ? .posted : .stopped
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
