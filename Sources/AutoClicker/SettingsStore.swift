import Foundation

@MainActor
final class SettingsStore: ObservableObject {
    @Published var mouseButton: MouseButton { didSet { save(mouseButton.rawValue, for: .mouseButton) } }
    @Published var clickType: ClickType { didSet { save(clickType.rawValue, for: .clickType) } }
    @Published var countMode: ClickCountMode { didSet { save(countMode.rawValue, for: .countMode) } }
    @Published var intervalMilliseconds: Int { didSet { save(intervalMilliseconds, for: .interval) } }
    @Published var specifiedClickCount: Int { didSet { save(specifiedClickCount, for: .clickCount) } }
    @Published var longPressMilliseconds: Int { didSet { save(longPressMilliseconds, for: .longPressDuration) } }
    @Published var hotKey: HotKey { didSet { saveHotKey(hotKey) } }

    private let defaults: UserDefaults

    private enum Key: String {
        case mouseButton
        case clickType
        case countMode
        case interval
        case clickCount
        case longPressDuration
        case hotKey
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        mouseButton = MouseButton(rawValue: defaults.string(forKey: Key.mouseButton.rawValue) ?? "") ?? .left
        clickType = ClickType(rawValue: defaults.string(forKey: Key.clickType.rawValue) ?? "") ?? .single
        countMode = ClickCountMode(rawValue: defaults.string(forKey: Key.countMode.rawValue) ?? "") ?? .unlimited

        let savedInterval = defaults.integer(forKey: Key.interval.rawValue)
        intervalMilliseconds = savedInterval == 0 ? 100 : savedInterval

        let savedCount = defaults.integer(forKey: Key.clickCount.rawValue)
        specifiedClickCount = savedCount == 0 ? 1_000 : savedCount

        let savedDuration = defaults.integer(forKey: Key.longPressDuration.rawValue)
        longPressMilliseconds = savedDuration == 0 ? 500 : savedDuration

        if let data = defaults.data(forKey: Key.hotKey.rawValue),
           let decoded = try? JSONDecoder().decode(HotKey.self, from: data) {
            hotKey = decoded
        } else {
            hotKey = HotKey.defaultValue
        }
    }

    private func save(_ value: Any, for key: Key) {
        defaults.set(value, forKey: key.rawValue)
    }

    private func saveHotKey(_ hotKey: HotKey) {
        guard let data = try? JSONEncoder().encode(hotKey) else { return }
        defaults.set(data, forKey: Key.hotKey.rawValue)
    }
}
