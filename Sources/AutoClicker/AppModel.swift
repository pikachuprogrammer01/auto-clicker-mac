import AppKit
import Combine

@MainActor
final class AppModel: ObservableObject {
    let settings: SettingsStore

    @Published private(set) var state: ClickerState = .stopped
    @Published private(set) var completedClicks = 0
    @Published private(set) var hasAccessibilityPermission = false
    @Published private(set) var isRecordingHotKey = false
    @Published var errorMessage: String?

    @Published var intervalText: String {
        didSet {
            if let value = Int(intervalText), SettingsValidator.millisecondRange.contains(value) {
                settings.intervalMilliseconds = value
            }
        }
    }

    @Published var clickCountText: String {
        didSet {
            if let value = Int(clickCountText), value > 0 {
                settings.specifiedClickCount = value
            }
        }
    }

    @Published var longPressText: String {
        didSet {
            if let value = Int(longPressText), SettingsValidator.millisecondRange.contains(value) {
                settings.longPressMilliseconds = value
            }
        }
    }

    private let clickEngine: MouseClickEngine
    private var activeRunID: UUID?
    private var permissionTimer: Timer?
    private var hasActivated = false

    private lazy var hotKeyManager = HotKeyManager { [weak self] in
        self?.toggleClicking()
    }

    init(
        settings: SettingsStore? = nil,
        clickEngine: MouseClickEngine = MouseClickEngine()
    ) {
        let resolvedSettings = settings ?? SettingsStore()
        self.settings = resolvedSettings
        self.clickEngine = clickEngine
        intervalText = String(resolvedSettings.intervalMilliseconds)
        clickCountText = String(resolvedSettings.specifiedClickCount)
        longPressText = String(resolvedSettings.longPressMilliseconds)
    }

    deinit {
        permissionTimer?.invalidate()
        clickEngine.stop()
    }

    func activate() {
        guard !hasActivated else { return }
        hasActivated = true

        hasAccessibilityPermission = AccessibilityPermission.isGranted(prompt: true)
        if !hotKeyManager.register(settings.hotKey) {
            errorMessage = "当前快捷键无法使用，请重新设置。"
        }

        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshPermission()
            }
        }
    }

    func refreshPermission() {
        hasAccessibilityPermission = AccessibilityPermission.isGranted()
    }

    func openAccessibilitySettings() {
        AccessibilityPermission.openSystemSettings()
    }

    func toggleClicking() {
        state.isRunning ? stopClicking() : startClicking()
    }

    func startClicking() {
        guard state == .stopped else { return }
        errorMessage = nil
        refreshPermission()

        guard hasAccessibilityPermission else {
            errorMessage = "请先开启辅助功能权限。"
            return
        }

        let configuration: ClickConfiguration
        do {
            configuration = try SettingsValidator.configuration(
                input: SettingsInput(
                    interval: intervalText,
                    clickCount: clickCountText,
                    longPressDuration: longPressText
                ),
                mouseButton: settings.mouseButton,
                clickType: settings.clickType,
                countMode: settings.countMode
            )
        } catch {
            errorMessage = error.localizedDescription
            return
        }

        settings.intervalMilliseconds = configuration.intervalMilliseconds
        if let clickLimit = configuration.clickLimit {
            settings.specifiedClickCount = clickLimit
        }
        if configuration.clickType == .longPress {
            settings.longPressMilliseconds = configuration.longPressMilliseconds
        }

        let runID = UUID()
        activeRunID = runID
        completedClicks = 0
        state = .starting

        clickEngine.start(
            runID: runID,
            configuration: configuration,
            onClick: { [weak self] id, count in
                DispatchQueue.main.async {
                    guard self?.activeRunID == id else { return }
                    self?.completedClicks = count
                }
            },
            onFinished: { [weak self] id, result in
                DispatchQueue.main.async {
                    guard self?.activeRunID == id else { return }
                    self?.activeRunID = nil
                    self?.state = .stopped
                    if result == .locationUnavailable {
                        self?.errorMessage = "无法读取当前鼠标位置，任务已停止。"
                    }
                }
            }
        )
        state = .running
    }

    func stopClicking() {
        guard state.isRunning else { return }
        state = .stopping
        activeRunID = nil
        clickEngine.stop()
        state = .stopped
    }

    func beginHotKeyRecording() {
        guard !state.isRunning else { return }
        errorMessage = nil
        hotKeyManager.unregister()
        isRecordingHotKey = true
    }

    func acceptHotKey(_ hotKey: HotKey) {
        guard HotKeyManager.isValid(hotKey) else {
            errorMessage = "快捷键需包含 ⌘、⌥ 或 ⌃，请重新输入。"
            return
        }

        if hotKeyManager.register(hotKey) {
            settings.hotKey = hotKey
            isRecordingHotKey = false
            errorMessage = nil
        } else {
            _ = hotKeyManager.register(settings.hotKey)
            isRecordingHotKey = false
            errorMessage = "当前快捷键无法使用，请重新设置。"
        }
    }

    func cancelHotKeyRecording() {
        _ = hotKeyManager.register(settings.hotKey)
        isRecordingHotKey = false
    }

    func terminate() {
        activeRunID = nil
        clickEngine.stop()
    }
}
