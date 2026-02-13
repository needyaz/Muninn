# ClipBar

A lightweight clipboard manager for macOS that lives in your menu bar. ClipBar keeps a searchable history of everything you copy and lets you save frequently used snippets for quick access.

Requires macOS 14.0 or later.

## Features

### Clipboard History

ClipBar monitors your clipboard in the background and records everything you copy. Supported content types:

- **Text** — plain text, with optional RTF and HTML formatting preserved
- **Images** — PNG and TIFF
- **PDFs**
- **Files** — file URL references
- **Colors** — `NSColor` values with full RGBA components

History items show the source app icon, a content preview, and a relative timestamp. Duplicate text entries are automatically deduplicated — recopying the same text moves it to the top instead of creating a new entry.

### Snippets

Save frequently used clips as named snippets for instant access. Snippets appear in their own section above history and support the same content types. You can:

- **Pin from history** — hover over any history item and click the pin icon to save it as a snippet
- **Create manually** — open the clip editor to add, rename, reorder, or delete snippets

### Search and Filtering

- **Search bar** — filter both snippets and history by keyword
- **Content type chips** — quickly filter history by type (Text, Images, PDFs, Files, Colors)

### Text Transformations

Right-click any text history item or text snippet to access transformations:

- **UPPERCASE**
- **lowercase**
- **Capitalize Words**
- **Trim Whitespace**
- **Remove Blank Lines**

Selecting a transform copies the transformed text to your clipboard and pastes it. A **Copy** option is also available to copy without pasting.

### Keyboard Navigation

- **Arrow keys** — move selection up and down through items
- **Enter** — paste the selected item
- **Escape** — close the popover
- **Global hotkey** — configurable shortcut to toggle ClipBar from anywhere

### Drag and Drop

Drag any history item or snippet out of the popover and drop it into another app. Text is provided as a string, images as `NSImage`, files as URLs, and colors as hex strings.

### Paste Options

- **Regular click** — copies the item to your clipboard, closes the popover, and returns focus to the previous app so you can Cmd+V
- **Option-click** — toggles between plain text and rich text paste mode
- **Paste as plain text by default** — configurable in Settings; Option-click then restores rich text

### Pause Monitoring

Temporarily stop clipboard monitoring when you need privacy:

- 1 minute, 5 minutes, 10 minutes, 30 minutes, 1 hour
- Until manually resumed

The menu bar icon changes to a pause indicator while paused.

### Excluded Apps

Prevent specific apps from being recorded in clipboard history. The Settings panel lists all installed apps with toggles to exclude them.

### Siri Shortcuts

ClipBar exposes actions to the macOS Shortcuts app via AppIntents:

- **Get Clipboard History** — returns the N most recent text items (default: 10)
- **Search Clipboard History** — search history items by text query
- **Copy Snippet by Name** — find a snippet by name and copy it to your clipboard
- **Get Latest Clipboard Item** — returns the most recent text item
- **Transform Text** — apply a text transformation (uppercase, lowercase, capitalize, trim whitespace, remove blank lines)

All actions appear in Shortcuts.app with suggested phrases for Siri.

### Settings

- **History limit** — 25, 50, 100, 200, or 500 items
- **Paste as plain text** — strip formatting by default
- **Global shortcut** — set a keyboard shortcut to toggle ClipBar
- **Excluded apps** — choose which apps to ignore

### Import / Export

Back up or migrate all your data via Settings > Data:

- **Export Data** — saves history, snippets, settings, excluded apps, and all binary blobs (images, PDFs, rich text) to a single `.clipbar` file
- **Import Data** — reads a `.clipbar` file and replaces all current data (with confirmation)

The export file is JSON with base64-encoded blobs, so no external dependencies or archive tools are needed.

## Data Storage

All data is stored locally in `~/Library/Application Support/ClipBar/`:

| File | Contents |
|------|----------|
| `history.json` | Clipboard history items |
| `clips.json` | Saved snippets |
| `excluded_apps.json` | Excluded app bundle IDs |
| `blobs/` | Binary data for images, PDFs, and rich text |

Settings (history limit, plain text mode) are stored in `UserDefaults`.

## Building

Open `ClipBar.xcodeproj` in Xcode and build the `ClipBar` scheme. The project uses [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) as its only external dependency, managed via Swift Package Manager.
