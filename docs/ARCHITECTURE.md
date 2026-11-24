# Muninn architecture

A macOS 14+ menu bar clipboard manager built with SwiftUI and the Observation framework. See [SPEC.md](../SPEC.md) for the product spec and the [README](../README.md) for build steps.

## Project Structure

All source files are flat in `Muninn/` — no subdirectories. Files follow a `<Feature><Role>.swift` naming convention.

### Models
| File | Purpose |
|------|---------|
| `Clip.swift` | Saved snippet: id, name, value, contentType, blobFile, fileURLs, colorComponents |
| `HistoryItem.swift` | Captured clipboard item: adds timestamp, sourceAppBundleID, ocrText, detectedBarcode, isSensitive |
| `ClipboardContentType.swift` | Enum (text, image, pdf, fileURL, color) with displayName + systemImage |

### Stores (all `@Observable`)
| File | Purpose |
|------|---------|
| `ClipStore.swift` | User-saved snippets → `clips.json` |
| `HistoryStore.swift` | Clipboard history → `history.json`; deduplicates text, auto-trims, evicts blobs; undo buffer for delete/clearAll/deleteMultiple |
| `SettingsStore.swift` | UserDefaults-backed settings; all properties use `didSet` to sync |
| `ExcludedAppsStore.swift` | `Set<String>` of excluded bundle IDs → `excluded_apps.json` |
| `ExcludedTypesStore.swift` | `Set<ClipboardContentType>` of excluded types → `excluded_types.json` |
| `StatsStore.swift` | Clipboard usage stats; 90-day rolling daily counts → `stats.json` |

### Monitors
| File | Purpose |
|------|---------|
| `ClipboardMonitor.swift` | Polls `NSPasteboard.general` every 0.5s; detects changes via `changeCount` |
| `ScreenshotMonitor.swift` | `NSMetadataQuery` watching for `kMDItemIsScreenCapture == 1`; auto-copies to pasteboard |

### Services
| File | Purpose |
|------|---------|
| `OCRService.swift` | Vision `VNRecognizeTextRequest` (.accurate) on background queue |
| `QRService.swift` | Vision `VNDetectBarcodesRequest` (QR, EAN, Code128, etc.) on background queue |
| `PDFTextService.swift` | PDFKit `PDFDocument` text extraction on background queue |

### Storage
| File | Purpose |
|------|---------|
| `BlobStorage.swift` | Static enum; saves/loads/restores binary files as `{UUID}.{ext}` in `blobs/` |
| `StoragePaths.swift` | Centralized paths (owner-only, excluded from backups) + the one-time ClipBar → Muninn rename migration |
| `DataPorter.swift` | JSON export/import with base64 blobs; `ExportEnvelope` v1 format |

### Views
| File | Purpose |
|------|---------|
| `MuninnApp.swift` | `@main`; `MenuBarExtra` (.window style) + editor, onboarding, help Windows + Settings scene |
| `PopoverContentView.swift` | Main popover UI: search, clips/history list, content type + source app filter chips, keyboard nav, multi-select, drag-and-drop, text transforms, undo toast |
| `ClipEditorView.swift` | Edit saved clips; drag-to-reorder, inline text editing |
| `OnboardingView.swift` | First-launch 4-page walkthrough window; sets `hasSeenOnboarding` when the window closes in any way (Get Started, close button, Cmd+W) |
| `HelpView.swift` | Scrollable help reference window: keyboard shortcuts, paste modes, snippets, search |
| `SettingsView.swift` | Tabbed settings: General, Excluded Apps, Excluded Types, Stats, Shortcut, Data, About |
| `ExcludedAppsView.swift` | Scans /Applications for bundles; searchable list with toggles |
| `SnippetPickerPanel.swift` | Singleton floating `NSPanel` (non-activating, transparent titlebar) |
| `SnippetPickerView.swift` | Snippet picker content: search, Cmd+1-9 quick select, keyboard nav |
| `StatsView.swift` | Stats dashboard: type breakdown, top apps, GitHub-style activity heatmap |

### Helpers
| File | Purpose |
|------|---------|
| `TextTransform.swift` | Enum: uppercase, lowercase, capitalize, trimWhitespace, removeBlankLines |
| `HistoryRow.swift` | One history row: preview, hover actions, context menu, drag |
| `PopoverComponents.swift` | FilterChip, AppFilterChip, BulkActionBar, UndoToast, HoverBackground, ResizeDragState |
| `ViewModifiers.swift` | `.tooltip()` and `.if(_:transform:)` |
| `AppIconCache.swift` | Source-app icon and name lookup (also used by StatsView) |
| `PasteboardWriter.swift` | The one way to put a string on the pasteboard (registers a self-copy) |
| `Log.swift` | The `os.Logger` used for storage errors |
| `OnceFlag.swift` | "First caller wins" flag so OCR/QR completions fire once |
| `ViewHelpers.swift` | Pure free functions shared by views: `filterClips`, `filterHistoryItems`, `hexColorString` |
| `MuninnIntents.swift` | App Intents for Siri Shortcuts (search history, copy snippet, transform text, etc.) |
| `MuninnShortcuts.swift` | `AppShortcutsProvider` with 5 shortcuts and voice phrases |

## Architecture

### SwiftUI + Observation
- Stores use `@Observable` (not `ObservableObject`); views use `@Environment(StoreType.self)` (not `@EnvironmentObject`)
- In `MuninnApp.swift`, stores are held with `@State` — this works because `@Observable` tracks access granularly; `@StateObject` is not used
- AppKit bridging where SwiftUI falls short: `NSPanel`, `NSEvent` monitors, `NSPasteboard`, `NSStatusBarButton`, `NSWorkspace`, `NSSound`
- No `NSApplicationDelegate` — app lifecycle is entirely SwiftUI scenes

### Clipboard Capture Pipeline

```
ScreenshotMonitor (NSMetadataQuery)
  → copies screenshot file to pasteboard
  → sets static ClipboardMonitor.lastScreenshotChangeCount + lastScreenshotFilename

ClipboardMonitor (timer, 0.5s)
  → detects NSPasteboard.changeCount change
  → skips if changeCount == selfCopyChangeCount (own paste) or isPaused
  → attributes source: if changeCount == lastScreenshotChangeCount → "com.apple.Screenshot"
                        else → NSWorkspace.shared.frontmostApplication
  → type detection order: fileURLs → image → pdf → color → text
  → saves blobs, extracts metadata, checks sensitive flags
  → calls HistoryStore.add()
  → triggers OCR/QR async if settings allow
  → triggers PDF text extraction async for .pdf items AND .fileURL items pointing to a .pdf file
  → records stats, plays sound
```

Content type detection is ordered — the first match wins. `fileURLs` take priority over everything.

### Sensitive Content
- Detected via `NSPasteboard` type identifiers: `org.nspasteboard.ConcealedType`, `org.nspasteboard.AutoGeneratedType` and `com.agilebits.onepassword`
- Three handling modes (SettingsStore.sensitiveHandling): **skip** (default; don't capture), **mask** (record a placeholder item with `isSensitive = true` and **no value**), **allow** (normal). `org.nspasteboard.TransientType` is never captured. Sensitive items are excluded from exports and from Shortcuts, and older stored values are scrubbed on load
- `HistoryItem.preview` returns `"Sensitive content"` when `isSensitive == true`

### Persistence
- Stores: `load()`/`save()` with `JSONEncoder`/`JSONDecoder`, `.atomic` writes to `~/Library/Application Support/Muninn/`
- Blobs: binary files in `blobs/` subdirectory, named `{UUID}.{ext}`
- Settings: `UserDefaults` with `didSet` observers (no explicit save call needed)
- Backward compat: models use `decodeIfPresent` with fallback defaults; old exports without `excludedTypes` are gracefully handled

### Export/Import (`DataPorter`)
- Envelope v1: `{ version, exportDate, settings, history, clips, excludedApps, excludedTypes, blobs: {filename: base64} }`
- **Merge**: unions excludedApps/excludedTypes, deduplicates items by UUID
- **Replace**: staged — a failure part-way leaves the existing data in place
- `fileURL` items get restored to `{base}/files/` directory on import

### Error Handling
- `try?` throughout — file I/O failures don't crash the app; store errors are logged via `Log.storage` (never `print`)
- Only `DataPorter` throws — user-facing import errors need feedback
- Corrupt/missing JSON → fallback to example clips (ClipStore, which first copies the bad file to `clips.json.bak`) or empty state (others)

### Concurrency
- Mostly main-thread (SwiftUI requirement)
- OCR, QR, and PDF text extraction use `DispatchQueue.global(qos: .userInitiated)` with main-thread callbacks
- No `async`/`await` or `Task` in app code — callback-based pattern used throughout (only the App Intents `perform()` methods are `async`, as the protocol requires)
- ScreenshotMonitor uses retry loop (up to 5×, linear backoff of 0.5 s × attempt) for file availability

## Test Isolation

Two-level override system:
1. **`baseURL` parameter** — stores accept an optional base URL for JSON file paths
2. **Static overrides** — `BlobStorage.blobDirOverride` and `StoragePaths.baseOverride` redirect file I/O

Tests use `makeTempDir()` / `defer { removeTempDir() }` pattern from `TestHelpers.swift`. State-dependent test suites use `.serialized` trait.

## Key Conventions

- Flat file organization — no subdirectories, files grouped by name prefix
- `// MARK: -` for sectioning in longer files 
- `try?` for file I/O; errors propagated only in `DataPorter`
- Models use `decodeIfPresent` with fallback defaults for schema evolution
- View helpers (`tooltip()`, `.if(_:transform:)`) live in `ViewModifiers.swift`; shared components in `PopoverComponents.swift`
- Bundle ID: `blue.luci.Muninn` by default (`MUNINN_BUNDLE_ID` in `project.yml`)
- Deployment target: macOS 14.0, Swift 5.0

## Gotchas & Non-Obvious Decisions

**Hotkey popover toggle** (the file-private `toggleMenuBarPopover()` in `MuninnApp.swift`): Uses multiple fallback strategies to find the `NSStatusBarButton` — fragile AppKit bridging. If the popover fails to open, this is likely the culprit.

**Screenshot attribution timing**: `ScreenshotMonitor` notifies `ClipboardMonitor` via an `onCopied` callback (wired in `MuninnApp`). The 0.5s poll interval means there is a small window where a clipboard change could be detected before the callback fires, causing the screenshot to be attributed to the frontmost app instead of `com.apple.Screenshot`.

**`MuninnIntents`** loads data directly from `StoragePaths.base` — not injected via stores. This is intentional: Shortcuts can launch the app to run an intent before any store exists. It filters out sensitive items.

**Self-copy detection**: write to `NSPasteboard` through `PasteboardWriter.copy(_:)`, or call `ClipboardMonitor.noteSelfCopy()` right after writing, so the next poll doesn't re-capture Muninn's own content.

**Text deduplication only**: `HistoryStore.add()` deduplicates text items by value, but images, files, and colors are always added even if identical.

**`TextTransformType` mirror**: `MuninnIntents.swift` defines a mirror `TextTransformType` enum to satisfy `AppIntents` constraints; an exhaustive `switch` maps it to `TextTransform`, so adding a case to one fails to compile until the other is updated.

**`PopoverContentView` size**: ~830 lines — still the largest file. Its pieces live in `HistoryRow.swift`, `PopoverComponents.swift`, `ViewModifiers.swift` and `AppIconCache.swift`.

**Import is untrusted input**: `BlobStorage.isValidFilename` guards every path built from a stored or imported filename; `DataPorter` caps the file size, validates settings (history limit range, `sensitiveHandling` never "allow") and stages Replace imports so a failure doesn't wipe data.

**Hotkeys and observers** are registered in `MuninnApp.init()` (not on first popover appearance) so they work from launch.

**Undo buffer**: `HistoryStore.pendingUndo: UndoableOperation?` holds a single-depth undo for the most recent delete/clearAll. Blob data is read into memory before disk deletion (capped at 50 MB). The 30-second `Timer` calls `commitPendingUndo()` on expiry. A new destructive operation always commits the previous pending undo first.

**Multi-select state**: `selectedIDs: Set<UUID>` + `lastToggledID: UUID?` in `PopoverContentView`. Multi-select only applies to history items (not clips). `selectedIndex: Int?` remains for single-item keyboard highlight. Cmd+click toggles; Shift+click range-selects via `shiftSelect(to:in:)`; Delete key calls `deleteSelected()` which feeds into `historyStore.deleteMultiple()`.

**PDF text extraction for fileURL items**: When a PDF file is copied from Finder, it is captured as a `.fileURL` item (not `.pdf`). `ClipboardMonitor` detects when a single-file fileURL has a `.pdf` extension and triggers `PDFTextService` on it, storing extracted text in `ocrText`. `HistoryStore.scanForPDFText()` also covers these items. The "Copy Text" context menu and extracted text preview apply to both `.pdf` and `.fileURL` PDF items.

**First-launch onboarding**: `settingsStore.hasSeenOnboarding` (UserDefaults, default `false`) gates the onboarding window. The check and `openWindow(id: "onboarding")` call live in `PopoverContentView.onAppear` (not `MuninnApp.body`) because `@Environment(\.openWindow)` is a view-only environment value, not available in `App.body`. "Show Welcome Tour" button lives in Settings > About tab.

**`Divider()` in SwiftUI `Picker` on macOS**: Do not use `Divider()` inside a `Picker`. On macOS, it causes `NSPopUpButton` to misidentify the selected item when the selection is an empty string (`""`), writing the wrong value back to the binding on first render. Use a flat list of tagged items instead.

## Dependencies

One external dependency via Swift Package Manager (managed through Xcode):

- **[KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts)** pinned to exactly `2.4.0` — global hotkey registration
