import AppKit
import SwiftUI

// MARK: - Tooltip

private class TooltipView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

struct Tooltip: NSViewRepresentable {
    let text: String

    func makeNSView(context: Context) -> NSView {
        let view = TooltipView()
        view.toolTip = text
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        nsView.toolTip = text
    }
}

extension View {
    func tooltip(_ text: String) -> some View {
        overlay(Tooltip(text: text))
    }

    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
