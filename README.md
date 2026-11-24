# Muninn

A free, open-source clipboard manager for macOS that lives in your menu bar. Muninn keeps a searchable history of everything you copy and lets you save frequently used snippets for quick access.

Everything stays on your Mac: Muninn is sandboxed, has no network access at all, and collects nothing. See [Privacy and security](#privacy-and-security).

## Install

Requires macOS 14.0 (Sonoma) or later.

Download the latest notarized build from the [GitHub Releases](../../releases), unzip it, move `Muninn.app` to Applications and open it. Look for the icon in the menu bar. Releases don't update themselves: download a newer one to update. Or build it yourself (see [Building](#building)). The GitHub build and the Mac App Store build are the same app (same bundle ID, same data), so install only one of them.

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

A floating panel for quickly searching and copying snippets without opening the main popover. Trigger it with a configurable global hotkey (set in Settings > Shortcuts).

- **Search** — type to filter snippets by name or content
- **Cmd+1–9** — copy one of the first nine results, then press Cmd+V
- **Arrow keys + Enter** — navigate and copy the item, then press Cmd+V
- **Escape** — dismiss

The selected snippet is copied to your clipboard and focus returns to the previous app; press Cmd+V to paste it.

### Sensitive Content Handling

Muninn detects sensitive clipboard content from password managers and other apps that use the `org.nspasteboard.ConcealedType` convention. Configure how these entries are handled in Settings > General > "Sensitive clipboard content":

- **Skip** (default) — ignore entirely, nothing is recorded
- **Mask** — record that a sensitive copy happened, as a "Sensitive content" placeholder. The value itself is never saved, so a masked item can't be pasted, searched, exported or read by Shortcuts
- **Allow** — capture normally, no special treatment

Copies marked transient (`org.nspasteboard.TransientType`) are never recorded in any mode.

### Search and Filtering

- **Search bar** — filter both snippets and history by keyword
- **Content type chips** — quickly filter snippets and history by type (Text, Images, PDFs, Files, Colors)
- **Source app chips** — filter history to items from a specific app; each chip shows the app icon and name
- **Color search** — search color history items by hex value (e.g. `#FF0000`) or by type name (e.g. `color`)

### Text Transformations

Right-click any text history item or text snippet to access transformations:

- **UPPERCASE**
- **lowercase**
- **Capitalize Words**
- **Trim Whitespace**
- **Remove Blank Lines**

Selecting a transform copies the transformed text to your clipboard; press Cmd+V to paste it. A **Copy** option is also available to copy the original text unchanged.

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
- **Enter** — copy the selected item, then press Cmd+V in the previous app
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

- **Get Clipboard History** — returns the N most recent text items (default: 10, at most 100)
- **Search Clipboard History** — search history items by text query
- **Copy Snippet by Name** — find a snippet by name and copy it to your clipboard
- **Get Latest Clipboard Item** — returns the most recent text item; if no text items exist, returns the newest item's preview (OCR text or a file name)
- **Transform Text** — apply a text transformation (uppercase, lowercase, capitalize, trim whitespace, remove blank lines)

All actions appear in Shortcuts.app with suggested phrases for Siri. Sensitive items are never returned. Note that any shortcut you run can read your history through these actions.

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

A four-page walkthrough window opens automatically on first launch, covering clipboard history, pasting, snippets, and power features. Closing the window in any way (Get Started, the close button or Cmd+W) marks it as seen, so it won't appear again. You can reopen it any time from Settings > About > **Show Welcome Tour**.

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
- **About** — app version, credits, welcome tour

### Import / Export

Back up or migrate all your data via Settings > Data:

- **Export Data** — saves history (without sensitive items), snippets, settings, excluded apps, excluded types, and all binary blobs (images, PDFs, rich text) to a single `.muninn` file. The file is **not encrypted**: keep it somewhere you trust
- **Import Data** — reads a `.muninn` file with a choice to **merge** (add new items, keep existing data) or **replace** all current data

The export file is JSON with base64-encoded blobs, so no external dependencies or archive tools are needed. Import treats the file as untrusted: blob names that could point outside Muninn's folder are rejected, out-of-range settings are ignored, and a file can't switch sensitive handling to "Allow".

## Data Storage

All data is stored locally in `~/Library/Application Support/Muninn/` (inside the app's sandbox container), in a folder only your user can read and that is left out of Time Machine backups:

| File | Contents |
|------|----------|
| `history.json` | Clipboard history items |
| `clips.json` | Saved snippets |
| `excluded_apps.json` | Excluded app bundle IDs |
| `excluded_types.json` | Excluded content types |
| `stats.json` | Clipboard activity statistics |
| `blobs/` | Binary data for images, PDFs, and rich text |

Settings (launch at login, history limit, plain text mode, sensitive content handling, rich previews, capture sound, screenshot capture, OCR, QR detection, PDF text extraction, popover height, popover width) are stored in `UserDefaults`.

The files are **not encrypted**. Anything you copy and let Muninn record is stored as plain text or as the original file, readable by any process running as you. When you copy a file in Finder, Muninn keeps a copy of its contents only if it is 25 MB or smaller. Use Skip for sensitive content, exclude apps you don't want recorded, and pause monitoring when you need to.

## Privacy and security

- **No network.** The app is sandboxed with incoming and outgoing connections off, uses no analytics or crash reporting, and has one dependency ([KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts), pinned).
- **No special permissions.** Muninn never asks for Accessibility, Input Monitoring or Automation. It puts the item on the clipboard and returns focus to your previous app, and you press Cmd+V.
- **On-device only.** OCR, barcode and PDF text extraction use Apple's Vision and PDFKit frameworks on your Mac.
- **Screenshots** are found by letting you pick the screenshot folder once; Muninn keeps a security-scoped bookmark to that folder and nothing else.
- See [SECURITY.md](SECURITY.md) to report a vulnerability and for the details above, and [the privacy policy](docs/privacy-policy.html).

## Building

Requires Xcode 26 and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`). The Xcode project is generated from `project.yml` and not checked in.

```sh
make menu       # pick a target (or `make` to list them)
make run        # build and launch
make test       # run the unit tests
make install    # build a Release app and copy it to /Applications
```

Without any setup, builds are ad-hoc signed, which is fine to run and test on your own Mac. To sign a copy under your own Apple developer team and bundle ID (so, for example, it keeps its permissions across rebuilds), copy `make/local.mk.example` to `make/local.mk` and set `TEAM` and `BUNDLE_ID`, or pass them: `make run TEAM=ABCDE12345 BUNDLE_ID=com.example.Muninn`. If you open the project in Xcode instead, set the signing team on the Muninn target yourself.

Notarized release builds are made with `make github-release`; see [DISTRIBUTION.md](DISTRIBUTION.md). There is no CI: run `make test` before you push.

## Project layout

| Path | What's there |
|---|---|
| `Muninn/` | The app, flat, one file per type and named `<Feature><Role>.swift`: stores, monitors, services, views |
| `MuninnTests/` | Unit tests (Swift Testing) for models, stores, services, import/export and view helpers |
| `project.yml` | XcodeGen spec; `Muninn.xcodeproj` is generated |
| `design/` | Icon concept art |
| `listing/` | App Store listing metadata and its checks (`make test-listing` and `make listing-check` need [Deno](https://deno.com)) |
| `make/` | Makefile fragments for release and App Store tasks (`make menu` needs [fzf](https://github.com/junegunn/fzf)) |
| `scripts/` | Release and App Store Connect scripts (Deno/TypeScript) |
| `docs/` | The privacy policy |
| `SPEC.md` | The product spec |
| `docs/ARCHITECTURE.md` | How it is built: architecture, file tables, storage and gotchas |

## Contributing

Issues are welcome; outside code contributions aren't accepted. See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

Copyright (C) 2026 Blue Luci.

The code is licensed under the GNU General Public License, version 3 only. See `LICENSE`.

Muninn uses [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) by Sindre Sorhus, licensed under the MIT License (Copyright (c) Sindre Sorhus <sindresorhus@gmail.com> (https://sindresorhus.com)). The full licence text is in [THIRD_PARTY_LICENSES.md](THIRD_PARTY_LICENSES.md).

The Muninn name, the Blue Luci name and logo, and the app icon artwork are not covered by the GPL; all rights are reserved. If you fork the project, please use your own name and icon.
