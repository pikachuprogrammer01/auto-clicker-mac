import Foundation

enum MouseButton: String, CaseIterable, Identifiable {
    case left
    case right

    var id: Self { self }

    var title: String {
        switch self {
        case .left: "左键"
        case .right: "右键"
        }
    }
}

enum ClickType: String, CaseIterable, Identifiable {
    case single
    case longPress

    var id: Self { self }

    var title: String {
        switch self {
        case .single: "单击"
        case .longPress: "长按"
        }
    }
}

enum ClickCountMode: String, CaseIterable, Identifiable {
    case unlimited
    case specified

    var id: Self { self }

    var title: String {
        switch self {
        case .unlimited: "无限"
        case .specified: "指定次数"
        }
    }
}

struct ClickConfiguration: Equatable {
    let mouseButton: MouseButton
    let clickType: ClickType
    let intervalMilliseconds: Int
    let clickLimit: Int?
    let longPressMilliseconds: Int
}

struct HotKey: Codable, Equatable {
    let keyCode: UInt32
    let modifiers: UInt32
    let keyLabel: String
}

enum ClickerState: Equatable {
    case stopped
    case starting
    case running
    case stopping

    var isRunning: Bool {
        self == .starting || self == .running || self == .stopping
    }
}
