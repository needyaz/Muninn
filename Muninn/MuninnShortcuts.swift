import AppIntents

struct MuninnShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: GetClipboardHistory(),
            phrases: [
                "Get clipboard history from \(.applicationName)",
                "Show recent clips in \(.applicationName)",
            ],
            shortTitle: "Get Clipboard History",
            systemImageName: "clipboard"
        )
        AppShortcut(
            intent: SearchClipboardHistory(),
            phrases: [
                "Search clipboard history in \(.applicationName)",
                "Find in \(.applicationName) history",
            ],
            shortTitle: "Search History",
            systemImageName: "magnifyingglass"
        )
        AppShortcut(
            intent: CopySnippetByName(),
            phrases: [
                "Copy snippet from \(.applicationName)",
                "Paste snippet from \(.applicationName)",
            ],
            shortTitle: "Copy Snippet",
            systemImageName: "doc.on.clipboard"
        )
        AppShortcut(
            intent: GetLatestClipboardItem(),
            phrases: [
                "Get latest clipboard item from \(.applicationName)",
                "What did I last copy in \(.applicationName)",
            ],
            shortTitle: "Get Latest Item",
            systemImageName: "arrow.uturn.backward"
        )
        AppShortcut(
            intent: TransformText(),
            phrases: [
                "Transform text with \(.applicationName)",
                "Convert text using \(.applicationName)",
            ],
            shortTitle: "Transform Text",
            systemImageName: "textformat"
        )
    }
}
