import SwiftUI

struct HelpView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                helpSection("Pasting") {
                    helpRow("Click an item", detail: "Copies it and returns to your previous app; press Cmd+V to paste")
                    helpRow("Option-click", detail: "Toggle between plain text and rich text (or reverse if plain text is your default)")
                    helpRow("Drag an item out", detail: "Drop into any other app")
                }

                helpSection("Keyboard Navigation") {
                    helpRow("↑ / ↓", detail: "Move selection up and down")
                    helpRow("Return", detail: "Copy the selected item; press Cmd+V to paste")
                    helpRow("Escape", detail: "Clear selection, or close the popover")
                    helpRow("Delete / Backspace", detail: "Delete selected items (with undo)")
                }

                helpSection("Multi-Select") {
                    helpRow("Cmd+click", detail: "Toggle an item in or out of the selection")
                    helpRow("Shift+click", detail: "Range-select from the last toggled item")
                    helpRow("Shift+↑ / Shift+↓", detail: "Extend the keyboard selection")
                }

                helpSection("Search & Filtering") {
                    helpRow("Type to search", detail: "Filters both snippets and history by keyword")
                    helpRow("Filter chips", detail: "Narrow results to a specific content type")
                    helpRow("Color search", detail: "Search colors by hex value, e.g. #FF0000")
                    helpRow("OCR / PDF text", detail: "Images and PDFs are searchable by their extracted text (enable in Settings)")
                }

                helpSection("Snippets") {
                    helpRow("Pin icon (on hover)", detail: "Save any history item as a named snippet")
                    helpRow("Snippet picker", detail: "Open a floating picker with the global hotkey (set in Settings > Shortcut)")
                    helpRow("Cmd+1–9", detail: "Copy one of the first nine results in the snippet picker, then press Cmd+V")
                }

                helpSection("Text Transforms") {
                    helpRow("Right-click a text item", detail: "Access UPPERCASE, lowercase, Capitalize Words, Trim Whitespace, Remove Blank Lines")
                }

                helpSection("Monitoring") {
                    helpRow("Pause icon (footer)", detail: "Temporarily pause clipboard capture for 1 min, 5 min, or longer")
                    helpRow("Sensitive content", detail: "Control how password manager entries are handled in Settings > General")
                }
            }
            .padding(20)
        }
        .frame(width: 440)
    }

    private func helpSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            Divider()
            content()
        }
    }

    private func helpRow(_ label: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 0) {
            Text(label)
                .fontWeight(.medium)
                .frame(width: 160, alignment: .leading)
            Text(detail)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.callout)
        .padding(.vertical, 2)
    }
}
