import SwiftUI

struct OnboardingView: View {
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(\.dismiss) private var dismiss

    @State private var page = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            symbol: "doc.on.clipboard",
            title: "Welcome to Muninn",
            bullets: [
                "Everything you copy is automatically saved to your clipboard history",
                "Muninn lives in your menu bar — click the raven icon to open it",
                "Your history is stored locally and never leaves your Mac",
            ]
        ),
        OnboardingPage(
            symbol: "hand.tap",
            title: "Browsing & Pasting",
            bullets: [
                "Click any item to copy it, then press Cmd+V in your previous app",
                "Option-click to toggle between plain text and rich text",
                "Right-click a text item for transforms: uppercase, lowercase, trim, and more",
                "Drag items directly out of the window into other apps",
            ]
        ),
        OnboardingPage(
            symbol: "pin",
            title: "Snippets",
            bullets: [
                "Hover over any history item and click the pin icon to save it as a snippet",
                "Snippets appear at the top of the list, always ready",
                "Open the snippet picker with a global hotkey (set in Settings > Shortcut)",
                "In the picker, use Cmd+1–9 to copy one of the first nine results, then press Cmd+V",
            ]
        ),
        OnboardingPage(
            symbol: "bolt",
            title: "Power Features",
            bullets: [
                "Cmd+click to select multiple items, then Delete to remove them all at once",
                "Use ↑↓ to navigate and Return to copy the selected item, then press Cmd+V",
                "Search by keyword, or use the filter chips to browse by content type",
                "Color items are searchable by hex value, e.g. #FF0000",
            ]
        ),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Page content
            ZStack {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, pg in
                    if index == page {
                        pageView(pg)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    }
                }
            }
            .frame(height: 300)
            .clipped()

            Divider()

            // Navigation footer
            HStack {
                // Dot indicators
                HStack(spacing: 6) {
                    ForEach(0..<pages.count, id: \.self) { i in
                        Circle()
                            .fill(i == page ? Color.accentColor : Color.secondary.opacity(0.35))
                            .frame(width: 6, height: 6)
                            .animation(.easeInOut, value: page)
                    }
                }

                Spacer()

                if page > 0 {
                    Button("Back") {
                        withAnimation { page -= 1 }
                    }
                }

                if page < pages.count - 1 {
                    Button("Next") {
                        withAnimation { page += 1 }
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Get Started") {
                        settingsStore.markOnboardingSeen()
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.return, modifiers: [])
                }
            }
            .padding(16)
        }
        .onDisappear { settingsStore.markOnboardingSeen() }
        .background(WindowCloseObserver { settingsStore.markOnboardingSeen() })
    }

    private func pageView(_ pg: OnboardingPage) -> some View {
        VStack(spacing: 16) {
            Image(systemName: pg.symbol)
                .font(.system(size: 48))
                .foregroundStyle(Color.accentColor)
                .padding(.top, 28)

            Text(pg.title)
                .font(.title2)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(pg.bullets, id: \.self) { bullet in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .foregroundStyle(.secondary)
                        Text(bullet)
                            .foregroundStyle(.primary)
                    }
                }
            }
            .frame(maxWidth: 360, alignment: .leading)

            Spacer()
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity)
    }
}

private struct OnboardingPage {
    let symbol: String
    let title: String
    let bullets: [String]
}

/// Calls `onClose` when the hosting window closes (close button, Cmd+W, File > Close).
struct WindowCloseObserver: NSViewRepresentable {
    let onClose: () -> Void

    final class Coordinator {
        var token: NSObjectProtocol?
        deinit { if let token { NotificationCenter.default.removeObserver(token) } }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { attach(view, context.coordinator) }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        if context.coordinator.token == nil { attach(view, context.coordinator) }
    }

    private func attach(_ view: NSView, _ coordinator: Coordinator) {
        guard coordinator.token == nil, let window = view.window else { return }
        coordinator.token = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification, object: window, queue: .main
        ) { _ in onClose() }
    }
}
