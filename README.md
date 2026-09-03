# Auto Clicker for macOS

Auto Clicker 是一款原生 SwiftUI 菜单栏连点工具。它在任务开始时锁定当前鼠标位置，并按照配置持续发送鼠标事件，不需要坐标输入、脚本、账号或网络服务。

## 功能

- 左键或右键
- 单击或长按
- `10～60000 ms` 点击间隔
- 无限点击或指定点击次数
- 启动时锁定鼠标位置
- 全局快捷键开始/停止，默认 `⌥⌘C`
- 辅助功能权限检测与系统设置入口
- 本地保存配置
- 控制窗口与菜单栏 Popover
- 停止或退出时可靠终止任务

产品范围及验收标准见 [Auto_Clicker_PRD_v1.0.md](Auto_Clicker_PRD_v1.0.md)。

## 系统要求

- macOS 13 Ventura 或更高版本
- Apple Silicon 或 Intel Mac；构建结果使用当前 Mac 的处理器架构
- 开发时需要 Xcode，或与本机 macOS SDK 匹配的 Swift Command Line Tools

项目没有第三方依赖，也不会访问网络。

## 快速开始

在项目目录执行：

```sh
./scripts/build-app.sh
open "dist/Auto Clicker.app"
```

首次启动时，在“系统设置 → 隐私与安全性 → 辅助功能”中允许 Auto Clicker。授权后：

1. 选择鼠标按键、点击类型、间隔和次数。
2. 将鼠标移动到目标位置。
3. 点击“开始点击”或按 `⌥⌘C`。
4. 再次按快捷键或点击“停止点击”结束任务。

双击 App 会显示紧凑控制窗口。关闭窗口不会退出应用，仍可从菜单栏指针图标打开控制面板；面板右上角电源按钮用于完全退出。

## 开发

直接运行 Swift Package：

```sh
swift run AutoClicker
```

生成可双击的 `.app`：

```sh
./scripts/build-app.sh
```

产物位于 `dist/Auto Clicker.app`。脚本执行 Release 构建、组装 Bundle，并使用 ad-hoc 签名供本机开发测试。

运行核心检查：

```sh
./scripts/run-checks.sh
```

检查覆盖：

- 输入范围与非法值
- 指定次数的事件数量和顺序
- 一次任务中点击位置保持不变
- 长按中途停止时立即唤醒并补发 `mouseUp`

## 项目结构

```text
Sources/AutoClicker/        应用、UI、快捷键、权限、配置与点击引擎
Checks/                     不发送真实鼠标事件的核心检查
Support/Info.plist          App Bundle 元数据
scripts/build-app.sh        Release 构建及 Bundle 组装
scripts/run-checks.sh       核心逻辑检查入口
docs/ARCHITECTURE.md        架构与线程模型
docs/RELEASE.md             签名、公证与发布流程
Auto_Clicker_PRD_v1.0.md    产品需求与验收标准
LICENSE                     MIT 许可证与免责声明
```

## 权限与隐私

辅助功能权限仅用于通过 `CGEvent` 发送鼠标事件。应用不包含网络请求、统计 SDK、账号系统或数据库；偏好配置保存在 macOS `UserDefaults` 中。

如果授权后仍显示“需要辅助功能权限”，请退出应用，在辅助功能列表中移除旧条目，重新打开当前构建的 App 后再次授权。开发阶段重新构建 ad-hoc 签名版本时，macOS 可能要求重新确认权限。

## 文档

- [架构说明](docs/ARCHITECTURE.md)
- [构建与发布](docs/RELEASE.md)
- [产品需求](Auto_Clicker_PRD_v1.0.md)

## 当前边界

MVP 不提供固定坐标、多位置、轨迹录制、键盘宏、脚本、定时任务、OCR、云同步或服务端能力。

## 许可证与免责声明

本项目使用 [MIT License](LICENSE)。软件按“现状”提供，不附带任何明示或默示保证；在适用法律允许的最大范围内，作者或版权持有人不对因软件或软件使用产生的任何索赔、损害或其他责任负责。完整且具有约束力的条款以 `LICENSE` 英文原文为准。
