# Muninn

A lightweight clipboard manager for macOS that lives in your menu bar. Muninn keeps a searchable history of everything you copy and lets you save frequently used snippets for quick access.

Requires macOS 14.0 or later.

## Features

### Clipboard History

Muninn monitors your clipboard in the background and records everything you copy. Monitoring starts immediately at launch — no interaction required. Supported content types:

- **Text** — plain text, with optional RTF and HTML formatting preserved
- **Images** — PNG and TIFF
- **PDFs**
- **Files** — file URL references
- **Colors** — `NSColor` values with full RGBA components

History items show the source app icon, a content preview, and a relative timestamp. Duplicate text entries are automatically deduplicated — recopying the same text moves it to the top instead of creating a new entry. Hover over any item to reveal pin and delete buttons, or clear all history at once from the footer toolbar. Deleting an item or clearing history shows an **Undo** toast for 30 seconds — click it to restore everything, including any images or binary data.

### Snippets

Save frequently used clips as named snippets for instant access. Snippets appear in their own section above history and support the same content types. You can:

- **Pin from history** — hover over any history item and click the pin icon to save it as a snippet
- **Create manually** — open the clip editor to add, rename, reorder, or delete snippets

### Snippet Picker

A floating panel for quickly searching and pasting snippets without opening the main popover. Trigger it with a configurable global hotkey (set in Settings > Shortcuts).

- **Search** — type to filter snippets by name or content
- **Cmd+1–9** — quick-select the first nine results
- **Arrow keys + Enter** — navigate and paste
- **Escape** — dismiss

The selected snippet is copied to your clipboard and focus returns to the previous app.

### Sensitive Content Handling

Muninn detects sensitive clipboard content from password managers and other apps that use the `org.nspasteboard.ConcealedType` convention. Configure how these entries are handled in Settings > General > "Sensitive clipboard content":

- **Allow** — capture normally, no special treatment
- **Skip** — ignore entirely, nothing is recorded
- **Mask** — record the value but hide the preview behind a "Sensitive content" label

### Search and Filtering

- **Search bar** — filter both snippets and history by keyword
- **Content type chips** — quickly filter snippets and history by type (Text, Images, PDFs, Files, Colors)
- **Source app chips** — filter history to items from a specific app; each chip shows the app icon and name
- **Color search** — search color history items by hex value (e.g. `#FF0000`)

### Text Transformations

Right-click any text history item or text snippet to access transformations:

- **UPPERCASE**
- **lowercase**
- **Capitalize Words**
- **Trim Whitespace**
- **Remove Blank Lines**

Selecting a transform copies the transformed text to your clipboard and pastes it. A **Copy** option is also available to copy without pasting.

### Multi-Select

Select multiple history items for bulk deletion:

- **Cmd+click** — toggle individual items in or out of the selection
- **Shift+click** — range-select from the last-toggled item to the clicked item
- **Shift+↑/↓** — extend the keyboard selection up or down
- **Delete/Backspace** — delete all selected items (with undo)
- **Escape** — clear the selection (press again to close the popover)

A floating action bar appears when two or more items are selected.

### Keyboard Navigation

- **Arrow keys** — move selection up and down through items
- **Enter** — paste the selected item
- **Escape** — clear multi-selection, or close the popover if nothing is selected
- **Global hotkey** — configurable shortcut to toggle Muninn from anywhere
- **Snippet picker hotkey** — configurable shortcut to open the floating snippet picker

### Drag and Drop

Drag any history item or snippet out of the popover and drop it into another app. Text is provided as a string, images as temporary files, PDFs as raw data, files as URLs, and colors as hex strings.

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

### Excluded Types

Prevent specific content types from being captured. Toggle off any combination of Text, Images, PDFs, Files, or Colors in Settings. When a clipboard entry matches an excluded type, the entire copy is skipped — it won't fall through and appear as a different type.

### Siri Shortcuts

Muninn exposes actions to the macOS Shortcuts app via AppIntents:

- **Get Clipboard History** — returns the N most recent text items (default: 10)
- **Search Clipboard History** — search history items by text query
- **Copy Snippet by Name** — find a snippet by name and copy it to your clipboard
- **Get Latest Clipboard Item** — returns the most recent text item; returns a content description (e.g. "Image", "Color") if no text items exist
- **Transform Text** — apply a text transformation (uppercase, lowercase, capitalize, trim whitespace, remove blank lines)

All actions appear in Shortcuts.app with suggested phrases for Siri.

### Rich Previews

When enabled, hovering over history items reveals expanded previews:

- **Images** — thumbnail grows from 32pt to 120pt on hover, shows filename
- **Colors** — displays hex code alongside the color swatch
- **Files** — image file thumbnails expand on hover

Toggle in Settings > General > "Show rich previews."

### Screenshot Capture

Automatically captures macOS screenshots (Cmd+Shift+3/4/5) into clipboard history without needing to manually copy them. Uses macOS metadata queries to detect new screenshots as they're saved.

Toggle in Settings > General > "Auto-capture screenshots to clipboard."

### OCR Text Extraction

Extracts readable text from images using Apple's Vision framework:

- Text is extracted automatically as images are captured
- Enabling the feature retroactively scans existing image history
- Extracted text appears below the image preview on hover
- Right-click an image to **Copy Text**
- OCR text is searchable via the search bar

Toggle in Settings > General > "Extract text from images (OCR)."

### QR Code and Barcode Detection

Detects QR codes and barcodes in images and extracts their content:

- Supports QR, EAN-13, EAN-8, Code 128, Code 39, and UPC-E
- Enabling the feature retroactively scans existing image history
- Detected codes appear below the image preview with a link or barcode icon
- Right-click to **Copy Link** / **Copy Code**, or **Open in Browser** for URLs
- Detected codes are searchable via the search bar

Toggle in Settings > General > "Detect QR codes and barcodes in images."

### PDF Text Extraction

Extracts text from PDFs so they're searchable and their content is copyable:

- Works for PDFs copied directly to the clipboard (e.g., from Preview) and PDF files copied from Finder
- Text is extracted automatically as PDFs are captured
- Enabling the feature retroactively scans existing PDF history
- Extracted text appears below the PDF label on hover
- Right-click a PDF to **Copy Text**
- Extracted text is searchable via the search bar
- Only works for PDFs with embedded text (not scanned/image-only PDFs)

Toggle in Settings > General > "Extract text from PDFs."

### Capture Sounds

Play a system sound each time content is captured to the clipboard. Choose from 12 built-in macOS sounds (Tink, Pop, Glass, Bottle, Frog, Funk, Ping, Purr, Submarine, Wobble, Basso, Blow) or disable. A preview button lets you hear the sound before selecting it.

Configure in Settings > General > "Capture sound."

### Clipboard Stats

A statistics dashboard tracking your clipboard activity:

- **Overview** — total copies, content type breakdown, source app count
- **Type chart** — bar chart of copies by content type
- **Top source apps** — most-used apps with icons and counts
- **Activity heatmap** — 13-week calendar showing daily copy intensity

Access via Settings > Stats. Statistics can be reset at any time.

### Onboarding

A four-page walkthrough window opens automatically on first launch, covering clipboard history, pasting, snippets, and power features. It won't appear again after you click "Get Started." You can reopen it any time from Settings > Data > **Show Welcome Tour**.

### Help

Click the **?** button in the popover footer to open a help reference window with a quick guide to keyboard shortcuts, paste modes, snippets, search, and more.

### Resizable Popover

Drag the corner grip at the bottom-right of the popover to resize it. Dragging changes both height (200–800pt) and width (280–600pt) simultaneously. The size is remembered across sessions.

### Settings

- **Launch at login** — automatically start Muninn when you log in
- **History limit** — 25, 50, 100, 200, or 500 items
- **Paste as plain text** — strip formatting by default
- **Global shortcut** — set a keyboard shortcut to toggle Muninn
- **Snippet picker shortcut** — set a keyboard shortcut for the floating snippet picker
- **Sensitive content** — choose how password manager entries are handled (allow, skip, or mask)
- **Excluded apps** — choose which apps to ignore
- **Excluded types** — choose which content types to ignore
- **Rich previews** — expanded previews on hover
- **Screenshot capture** — auto-capture macOS screenshots
- **OCR** — extract text from images
- **QR/barcode detection** — detect codes in images
- **PDF text extraction** — extract and search text in PDFs
- **Capture sound** — audio feedback on clipboard capture
- **Stats** — clipboard activity dashboard

### Import / Export

Back up or migrate all your data via Settings > Data:

- **Export Data** — saves history, snippets, settings, excluded apps, excluded types, and all binary blobs (images, PDFs, rich text) to a single `.muninn` file
- **Import Data** — reads a `.muninn` file with a choice to **merge** (add new items, keep existing data) or **replace** all current data

The export file is JSON with base64-encoded blobs, so no external dependencies or archive tools are needed.

## Data Storage

All data is stored locally in `~/Library/Application Support/Muninn/`:

| File | Contents |
|------|----------|
| `history.json` | Clipboard history items |
| `clips.json` | Saved snippets |
| `excluded_apps.json` | Excluded app bundle IDs |
| `excluded_types.json` | Excluded content types |
| `stats.json` | Clipboard activity statistics |
| `blobs/` | Binary data for images, PDFs, and rich text |

Settings (launch at login, history limit, plain text mode, sensitive content handling, rich previews, capture sound, screenshot capture, OCR, QR detection, PDF text extraction, popover height, popover width) are stored in `UserDefaults`.

## Building

Open `Muninn.xcodeproj` in Xcode and build the `Muninn` scheme. The project uses [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) as its only external dependency, managed via Swift Package Manager.
