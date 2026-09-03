import Foundation

struct SettingsInput {
    let interval: String
    let clickCount: String
    let longPressDuration: String
}

enum SettingsValidationError: LocalizedError, Equatable {
    case invalidInterval
    case invalidClickCount
    case invalidLongPressDuration

    var errorDescription: String? {
        switch self {
        case .invalidInterval:
            "点击间隔必须为 10～60000 ms。"
        case .invalidClickCount:
            "点击次数必须为大于 0 的整数。"
        case .invalidLongPressDuration:
            "长按时间必须为 10～60000 ms。"
        }
    }
}

enum SettingsValidator {
    static let millisecondRange = 10...60_000

    static func configuration(
        input: SettingsInput,
        mouseButton: MouseButton,
        clickType: ClickType,
        countMode: ClickCountMode
    ) throws -> ClickConfiguration {
        guard let interval = parseInteger(input.interval), millisecondRange.contains(interval) else {
            throw SettingsValidationError.invalidInterval
        }

        var clickLimit: Int?
        if countMode == .specified {
            guard let count = parseInteger(input.clickCount), count > 0 else {
                throw SettingsValidationError.invalidClickCount
            }
            clickLimit = count
        }

        var longPressDuration = 500
        if clickType == .longPress {
            guard let duration = parseInteger(input.longPressDuration), millisecondRange.contains(duration) else {
                throw SettingsValidationError.invalidLongPressDuration
            }
            longPressDuration = duration
        }

        return ClickConfiguration(
            mouseButton: mouseButton,
            clickType: clickType,
            intervalMilliseconds: interval,
            clickLimit: clickLimit,
            longPressMilliseconds: longPressDuration
        )
    }

    private static func parseInteger(_ value: String) -> Int? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.allSatisfy(\.isNumber) else { return nil }
        return Int(trimmed)
    }
}
