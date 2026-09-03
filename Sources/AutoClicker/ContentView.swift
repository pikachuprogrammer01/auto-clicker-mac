import SwiftUI

struct ContentView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var settings: SettingsStore

    init(model: AppModel) {
        self.model = model
        settings = model.settings
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            statusSection
            Divider()

            if model.state.isRunning {
                runningSection
            } else {
                configurationSection
            }

            if let error = model.errorMessage {
                Divider()
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
            }

            Divider()
            actionSection
        }
        .frame(width: 360)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear { model.activate() }
    }

    private var header: some View {
        HStack(spacing: 9) {
            Image(systemName: "cursorarrow.click.2")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.tint)

            Text("Auto Clicker")
                .font(.headline)

            Spacer()

            Button {
                model.terminate()
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "power")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("退出 Auto Clicker")
            .accessibilityLabel("退出 Auto Clicker")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    private var statusSection: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(model.state.isRunning ? Color.green : Color.secondary.opacity(0.7))
                .frame(width: 8, height: 8)

            Text(statusText)
                .font(.subheadline.weight(.medium))

            Spacer()

            permissionStatus
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.55))
    }

    @ViewBuilder
    private var permissionStatus: some View {
        if model.hasAccessibilityPermission {
            Label("权限已开启", systemImage: "checkmark.shield.fill")
                .font(.caption)
                .foregroundStyle(.green)
        } else {
            Button("需要辅助功能权限") {
                model.openAccessibilitySettings()
            }
            .font(.caption)
            .buttonStyle(.link)
        }
    }

    private var configurationSection: some View {
        VStack(spacing: 14) {
            settingRow("鼠标按键") {
                Picker("鼠标按键", selection: $settings.mouseButton) {
                    ForEach(MouseButton.allCases) { button in
                        Text(button.title).tag(button)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 168)
            }

            settingRow("点击类型") {
                Picker("点击类型", selection: $settings.clickType) {
                    ForEach(ClickType.allCases) { type in
                        Text(type.title).tag(type)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 168)
            }

            if settings.clickType == .longPress {
                numericFieldRow("长按时间", text: $model.longPressText, suffix: "ms")
            }

            numericFieldRow("点击间隔", text: $model.intervalText, suffix: "ms")

            settingRow("点击次数") {
                Picker("点击次数", selection: $settings.countMode) {
                    ForEach(ClickCountMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 168)
            }

            if settings.countMode == .specified {
                numericFieldRow("指定次数", text: $model.clickCountText, suffix: "次")
            }

            settingRow("开始 / 停止快捷键") {
                Button(model.isRecordingHotKey ? "请按新组合键" : settings.hotKey.displayText) {
                    if model.isRecordingHotKey {
                        model.cancelHotKeyRecording()
                    } else {
                        model.beginHotKeyRecording()
                    }
                }
                .buttonStyle(.bordered)
                .frame(width: 168)
                .overlay {
                    HotKeyRecorder(
                        isRecording: model.isRecordingHotKey,
                        onHotKey: model.acceptHotKey,
                        onCancel: model.cancelHotKeyRecording
                    )
                    .frame(width: 1, height: 1)
                    .opacity(0.01)
                }
            }
        }
        .padding(16)
    }

    private var runningSection: some View {
        VStack(spacing: 14) {
            summaryRow("点击次数", value: model.completedClicks.formatted())
            summaryRow("点击位置", value: "已锁定")
            summaryRow("鼠标操作", value: "\(settings.mouseButton.title) · \(settings.clickType.title)")
            summaryRow("快捷键", value: settings.hotKey.displayText)
        }
        .padding(16)
    }

    private var actionSection: some View {
        VStack(spacing: 10) {
            if !model.hasAccessibilityPermission {
                Button {
                    model.openAccessibilitySettings()
                } label: {
                    Label("前往系统设置", systemImage: "gearshape")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }

            Button {
                model.toggleClicking()
            } label: {
                Label(
                    model.state.isRunning ? "停止点击" : "开始点击",
                    systemImage: model.state.isRunning ? "stop.fill" : "play.fill"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(model.state.isRunning ? .red : .accentColor)
            .controlSize(.large)
            .disabled(model.state == .starting || model.state == .stopping || !model.hasAccessibilityPermission)
            .keyboardShortcut(.return, modifiers: [])
        }
        .padding(16)
    }

    private var statusText: String {
        switch model.state {
        case .stopped: "已停止"
        case .starting: "正在启动"
        case .running: "正在点击"
        case .stopping: "正在停止"
        }
    }

    private func settingRow<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            content()
        }
    }

    private func numericFieldRow(_ title: String, text: Binding<String>, suffix: String) -> some View {
        settingRow(title) {
            HStack(spacing: 7) {
                TextField(title, text: text)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 116)
                Text(suffix)
                    .foregroundStyle(.secondary)
                    .frame(width: 36, alignment: .leading)
            }
            .frame(width: 168, alignment: .trailing)
        }
    }

    private func summaryRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}
