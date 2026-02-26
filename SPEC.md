# Muninn — Product Specification

## Overview

Muninn is a macOS 14+ menu bar clipboard manager. It captures everything you copy — text, images, PDFs, colors, and file URLs — and lets you search, re-paste, organize, and analyze your clipboard history. It also manages saved "snippets" (reusable clips) accessible via a global hotkey and a floating picker panel.

Named for Odin's raven of memory.

---

## What It Does

### Core Loop
1. **Capture** — Monitors `NSPasteboard` every 0.5s. On change, records the item (with content type, source app, timestamp) and optionally runs OCR or barcode detection.
2. **Browse** — Menu bar popover shows clipboard history and saved snippets. Searchable, filterable by content type, keyboard-navigable.
3. **Paste** — Click or press Return to copy an item back to the pasteboard and paste into the previously-focused app.
4. **Organize** — Save frequently-used items as named snippets. Access them via the snippet picker panel (floating window, Cmd+1–9 shortcuts).

---

## Built Features

### Clipboard Capture

| Feature | Status |
|---------|--------|
| Text (plain + RTF/HTML preservation) | ✅ Done |
| Images (PNG/TIFF) | ✅ Done |
| PDFs | ✅ Done |
| File URLs (single + multi) | ✅ Done |
| Colors (RGBA) | ✅ Done |
| Source app tracking | ✅ Done |
| Screenshot attribution (via `ScreenshotMonitor`) | ✅ Done |
| Sensitive content detection (password managers) | ✅ Done — three modes: skip, mask, allow |
| Deduplication (text only) | ✅ Done |
| Self-copy suppression (own pastes not re-captured) | ✅ Done |
| Configurable history limit (25–500) | ✅ Done |
| Auto-trim with blob cleanup on eviction | ✅ Done |

### OCR & Barcode Detection

| Feature | Status |
|---------|--------|
| OCR on captured images (Vision, `.accurate`) | ✅ Done — async, retroactive scan when enabled |
| Barcode/QR detection (QR, EAN, Code128, etc.) | ✅ Done — async, retroactive scan when enabled |
| Search history by OCR text | ✅ Done |
| Display detected barcode value in history row | ✅ Done |

### History Browser (Popover)

| Feature | Status |
|---------|--------|
| Text search across all history | ✅ Done |
| Filter chips by content type | ✅ Done |
| App icon + source app shown per item | ✅ Done |
| Rich image previews on hover | ✅ Done |
| Color swatches with hex values | ✅ Done |
| OCR text shown under image previews | ✅ Done |
| Paste as plain text (Option-click toggle) | ✅ Done — inverted by `pasteAsPlainText` setting |
| Text transform context menu (uppercase, lowercase, capitalize, trim, remove blank lines) | ✅ Done |
| Drag items out of popover | ✅ Done — `NSItemProvider` for each type |
| Delete individual items | ✅ Done |
| Clear all history (with confirmation) | ✅ Done |
| Resizable popover height (drag handle, 200–800px, persisted) | ✅ Done |
| Resizable popover width (corner drag handle, 280–600px, persisted) | ✅ Done |
| Keyboard navigation (↑↓, Return, Escape) | ✅ Done |
| Multi-select (Cmd+click, Shift+click, Shift+arrow) with bulk delete | ✅ Done |
| Undo for delete / bulk delete / clear-all (5-second window, blob-aware) | ✅ Done |
| Pause/resume capture (with duration: 1m, 5m, 30m, or indefinite) | ✅ Done |

### Snippets (Saved Clips)

| Feature | Status |
|---------|--------|
| Save item as snippet from history | ✅ Done |
| Named snippets with CRUD (add, edit, delete, reorder) | ✅ Done |
| Dedicated editor window | ✅ Done |
| Snippet picker floating panel (NSPanel, non-activating) | ✅ Done |
| Global hotkey to open snippet picker | ✅ Done |
| Search in snippet picker | ✅ Done |
| Cmd+1–9 quick-select in picker | ✅ Done |
| Snippet paste restores RTF/HTML if available | ✅ Done |
| Example snippets on first launch | ✅ Done |

### Settings

| Setting | Status |
|---------|--------|
| History limit (25–500) | ✅ Done |
| Paste as plain text by default | ✅ Done |
| Enable rich previews | ✅ Done |
| Enable stats tracking | ✅ Done |
| Capture screenshots | ✅ Done |
| Enable OCR | ✅ Done |
| Enable QR/barcode detection | ✅ Done |
| Sensitive content handling (skip/mask/allow) | ✅ Done — fully wired (capture + UI masking) |
| Capture sound (picker + preview) | ✅ Done |
| Launch at login (SMAppService) | ✅ Done |
| Excluded apps (searchable list of installed apps) | ✅ Done |
| Excluded content types (per-type toggles) | ✅ Done |
| Global keyboard shortcuts (via KeyboardShortcuts library) | ✅ Done |

### Statistics

| Feature | Status |
|---------|--------|
| Total copies tracked | ✅ Done |
| Per-type counts | ✅ Done |
| Per-source-app counts | ✅ Done |
| 90-day rolling daily counts | ✅ Done |
| Overview stat boxes (total, types, apps) | ✅ Done |
| Content type bar chart (SwiftUI Charts) | ✅ Done |
| Top 8 source apps list | ✅ Done |
| 13-week activity heatmap | ✅ Done |
| Reset stats (with confirmation) | ✅ Done |
| Stats entirely disabled when setting is off | ✅ Done |

### Data Portability

| Feature | Status |
|---------|--------|
| Export to JSON (v1 envelope with base64 blobs) | ✅ Done |
| Import with Replace mode (full overwrite) | ✅ Done |
| Import with Merge mode (union, deduplicates by ID) | ✅ Done |
| Blob round-trip (images, PDFs, rich text, files) | ✅ Done |
| Settings included in export, restored on Replace | ✅ Done |
| File URL items restored to `~/Library/…/Muninn/files/` | ✅ Done |
| Migration from ClipBar app name (old path) | ✅ Done |
| Migration from `~/.config/clipbar` (legacy path) | ✅ Done |

### Siri Shortcuts / App Intents

| Intent | Status |
|--------|--------|
| Get Clipboard History (last N items) | ✅ Done |
| Search Clipboard History (by query) | ✅ Done |
| Copy Snippet By Name | ✅ Done |
| Get Latest Clipboard Item | ✅ Done |
| Transform Text (case, trim, etc.) | ✅ Done |

---

## Gaps & Known Issues

### Bugs

None known.

### Missing User Feedback

- **Silent I/O failures** — Store save/load errors are intentionally silent per the app's graceful-degradation design (see CONSTITUTION §7). Only DataPorter surfaces errors to the user.

### Search Gaps

| Content type | Searchable? |
|--------------|------------|
| Text | ✅ By value |
| Image | ✅ By OCR text (if enabled) |
| File URL | ✅ By filename |
| PDF | ✅ By extracted text (if enabled) |
| Color | ❌ Not searchable |

### UX Gaps

- **No pin/favorite for history items** — The existing save-as-snippet (pin button) effectively covers this use case.

### Technical Debt

None known.

---

## Potential Future Features

These are not planned but represent natural extensions based on the existing architecture:

- **iCloud sync** — The `~/Library/Application Support/Muninn/` data model is portable; CloudKit or iCloud Drive sync could extend history across Macs.
- **Color search** — Search by hex value or color name.
- **Group by source app** — Alternative history view grouped by application.
- **Menu bar icon state** — Reflect paused/active/sensitive state in the menu bar icon.
- **Configurable polling interval** — Currently hardcoded at 0.5s.
- **Regex search** — Power-user search in history.
- **Expiring history** — Auto-delete items older than N days regardless of count limit.
