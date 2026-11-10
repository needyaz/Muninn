#if DEBUG
import AppKit
import SwiftUI

/// One Mac App Store screenshot: a file name, a caption and the SwiftUI view to render at `ScreenshotMode.pointSize`.
struct ScreenshotScene: Identifiable {
    let id: String
    let fileName: String
    let caption: String
    let subtitle: String
    /// The real UI for this scene, without the caption (added by `view(stores:)`).
    let content: @MainActor (ScreenshotStores) -> AnyView

    /// The full screenshot: the caption on the luci.blue cream-to-blue background, with the real UI beside it.
    @MainActor
    func view(stores: ScreenshotStores) -> AnyView {
        AnyView(ShotLayout(caption: caption, subtitle: subtitle) { content(stores) })
    }

    /// The scenes in render order: popover with history, search with filters, snippets, settings or privacy.
    static var all: [ScreenshotScene] {
        [
            ScreenshotScene(
                id: "history", fileName: "01_history.png",
                caption: "Everything you copy, remembered.",
                subtitle: "Text, images, colors, files and PDFs, one click away in your menu bar.",
                content: { stores in
                    AnyView(MenuBarPanel { PopoverContentView().shotEnvironment(stores) })
                }
            ),
            ScreenshotScene(
                id: "search", fileName: "02_search.png",
                caption: "Find it in a flash.",
                subtitle: "Search everything, then filter by content type or the app it came from.",
                content: { stores in
                    AnyView(MenuBarPanel { PopoverContentView(initialContentTypeFilter: .text).shotEnvironment(stores) })
                }
            ),
            ScreenshotScene(
                id: "snippets", fileName: "03_snippets.png",
                caption: "Your best text, ready to paste.",
                subtitle: "Save snippets and pick one from a floating panel with Cmd+1 to 9.",
                content: { stores in
                    AnyView(
                        SnippetPickerView(clipStore: stores.clips, settingsStore: stores.settings, monitor: nil, previousApp: nil, onDismiss: {})
                            .frame(width: 360, height: 420)
                            .background(Color(nsColor: .windowBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(.black.opacity(0.14), lineWidth: 0.5))
                            .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
                    )
                }
            ),
            ScreenshotScene(
                id: "privacy", fileName: "04_privacy.png",
                caption: "Private by design.",
                subtitle: "Skip or mask sensitive copies, exclude apps, and keep everything on your Mac.",
                content: { stores in
                    AnyView(MacWindow(title: "Muninn Settings") { SettingsView().shotEnvironment(stores) }.fixedSize())
                }
            ),
        ]
    }
}

// MARK: - Layout

private extension Color {
    init(shotHex hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
}

private extension View {
    /// The real views read these stores from the environment. There is deliberately no clipboard monitor.
    func shotEnvironment(_ stores: ScreenshotStores) -> some View {
        environment(stores.settings)
            .environment(stores.clips)
            .environment(stores.history)
            .environment(stores.excludedApps)
            .environment(stores.excludedTypes)
            .environment(stores.stats)
    }
}

/// Caption on the left, the real UI on the right, over the site's cream-to-blue background.
private struct ShotLayout<Content: View>: View {
    let caption: String
    let subtitle: String
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(shotHex: 0xFAF7F2), Color(shotHex: 0xD3E0FA)], startPoint: .top, endPoint: .bottom)
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 14) {
                    Text(caption)
                        .font(.system(size: 50, weight: .semibold, design: .serif))
                        .foregroundStyle(Color(shotHex: 0x1A3A8F))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(subtitle)
                        .font(.system(size: 20))
                        .foregroundStyle(Color(shotHex: 0x4A5A7A))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.leading, 64)
                .padding(.trailing, 24)
                .frame(width: 470, alignment: .leading)
                content.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

// MARK: - Mac chrome

/// A window with a title bar and traffic lights around real content. The real window frame can't be captured
/// off-screen, so this draws a faithful one.
private struct MacWindow<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    ForEach([0xFF5F57, 0xFEBC2E, 0x28C840] as [UInt32], id: \.self) { Circle().fill(Color(shotHex: $0)).frame(width: 12, height: 12) }
                    Spacer()
                }
                .padding(.leading, 14)
            }
            .frame(height: 28)
            content
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 11))
        .overlay(RoundedRectangle(cornerRadius: 11).stroke(.black.opacity(0.18), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.28), radius: 22, y: 12)
    }
}

/// A wallpaper with a menu bar and the real popover under Muninn's item.
private struct MenuBarPanel<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ZStack(alignment: .topTrailing) {
            LinearGradient(colors: [Color(shotHex: 0x2F3E9E), Color(shotHex: 0x7A5BB0), Color(shotHex: 0xE59BB8)], startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack(spacing: 0) {
                HStack(spacing: 14) {
                    Spacer()
                    Image(systemName: "doc.on.clipboard")
                    Image(systemName: "wifi")
                    Image(systemName: "battery.100")
                    Text("Tue 9:48 AM")
                }
                .font(.system(size: 13))
                .foregroundStyle(.black.opacity(0.85))
                .padding(.horizontal, 14)
                .frame(height: 26)
                .background(.white.opacity(0.62))
                content
                    .background(Color(nsColor: .windowBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(.black.opacity(0.14), lineWidth: 0.5))
                    .shadow(color: .black.opacity(0.35), radius: 18, y: 8)
                    .padding(.top, 8)
                    .padding(.trailing, 90)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .frame(width: 640, height: 800)
        .clipped()
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
}
#endif
