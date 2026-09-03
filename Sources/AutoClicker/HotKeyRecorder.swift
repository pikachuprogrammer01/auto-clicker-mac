import AppKit
import SwiftUI

struct HotKeyRecorder: NSViewRepresentable {
    let isRecording: Bool
    let onHotKey: (HotKey) -> Void
    let onCancel: () -> Void

    func makeNSView(context: Context) -> KeyCaptureView {
        let view = KeyCaptureView()
        view.onHotKey = onHotKey
        view.onCancel = onCancel
        return view
    }

    func updateNSView(_ view: KeyCaptureView, context: Context) {
        view.onHotKey = onHotKey
        view.onCancel = onCancel
        view.isRecording = isRecording
    }
}

final class KeyCaptureView: NSView {
    var onHotKey: ((HotKey) -> Void)?
    var onCancel: (() -> Void)?

    var isRecording = false {
        didSet {
            guard isRecording, !oldValue else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self, self.isRecording else { return }
                self.window?.makeFirstResponder(self)
            }
        }
    }

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }

        if event.keyCode == 53 {
            onCancel?()
            return
        }

        if let hotKey = HotKey(event: event) {
            onHotKey?(hotKey)
        }
    }
}
