# 架构说明

## 技术栈

- Swift 5.9 Package
- SwiftUI：控制窗口和菜单栏 Popover
- AppKit：应用生命周期、快捷键录入和系统设置跳转
- Core Graphics / ApplicationServices：鼠标位置和鼠标事件
- Carbon Hot Key API：跨 App 全局快捷键
- UserDefaults：本地配置持久化

最低部署目标为 macOS 13。

## 组件职责

| 组件 | 职责 |
|---|---|
| `AutoClickerApp` | 创建控制窗口和 `MenuBarExtra`，接入应用退出流程 |
| `ContentView` | 展示参数、权限、运行状态和点击计数 |
| `AppModel` | 协调 UI、校验、权限、快捷键和点击任务状态 |
| `SettingsStore` | 读取并保存用户偏好 |
| `SettingsValidator` | 将文本输入转换为不可变的任务配置 |
| `HotKeyManager` | 注册、注销和处理 Carbon 全局快捷键 |
| `HotKeyRecorder` | 捕获用户在控制窗口输入的新组合键 |
| `AccessibilityPermission` | 检查辅助功能权限并打开对应系统设置 |
| `MouseClickEngine` | 在独立串行队列发送点击，提供可中断等待和同步停止 |

## 启动链路

```text
App 启动
  → 创建 AppModel
  → 检查辅助功能权限
  → 注册已保存的全局快捷键
  → 显示控制窗口并创建菜单栏入口
```

启动点击任务时，`AppModel` 先完成全部输入校验和权限检查，再将不可变配置交给 `MouseClickEngine`。引擎通过 `MouseLocationProviding` 在每次操作前读取当前 `CGEvent.location`，因此后续点击会跟随鼠标移动。

## 状态与线程模型

UI 状态由主线程上的 `AppModel` 管理：

```text
stopped → starting → running → stopping → stopped
```

真实鼠标事件在 `com.autoclicker.click-engine` 串行队列执行。引擎使用 `NSCondition` 保存当前任务标识并实现可唤醒等待：

- 停止请求将当前任务标识置空并广播条件变量。
- 等待点击间隔或长按时间的工作线程会立即被唤醒。
- `stop()` 等待当前工作项收尾后才返回。
- 单击的 `mouseDown` 与 `mouseUp` 在同一个临界区发送。
- 长按释放时再次读取鼠标位置；即使被中止，也会为已经发送的 `mouseDown` 补发 `mouseUp`。
- 如果无法读取鼠标位置，引擎不会发送事件，并自动结束任务。

这些约束保证 `stop()` 返回后不会再产生新的点击，并避免鼠标停留在按下状态。

## 全局快捷键

默认快捷键为 `⌥⌘C`。录制新快捷键时先注销旧快捷键，只有新组合成功注册后才写入配置；如果注册失败，则恢复旧快捷键并向用户显示错误。

快捷键必须至少包含 `⌘`、`⌥` 或 `⌃`。仅使用 `⌘Q` 或 `⌘W` 会因应用内部命令冲突被拒绝。

## 数据与隐私

应用只持久化以下设置：

- 鼠标按键
- 点击类型
- 点击间隔
- 次数模式及指定次数
- 长按时间
- 快捷键键码、修饰键和显示文本

运行中的点击位置和点击计数不会写入磁盘。项目没有网络层、遥测、服务端和数据库。

## 测试边界

`Checks/AutoClickerChecks.swift` 通过注入 `MouseEventPosting` 和 `MouseLocationProviding` 测试引擎，不会向桌面发送真实鼠标事件。检查覆盖逐次位置跟随、长按移动后释放、位置读取失败和同步停止。辅助功能授权、系统快捷键占用和真实目标应用中的点击行为仍需要在 macOS 上进行人工验收。
