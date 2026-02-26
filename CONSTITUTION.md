# Muninn Constitution

Architectural decisions, patterns, and conventions to enforce in all future work. When in doubt, follow what's here. When adding something new, follow the nearest existing pattern.

---

## 1. State Management

**Use `@Observable`, never `ObservableObject`.**

All stores are `@Observable` classes. Views receive them via `@Environment(StoreType.self)`. Never use `@ObservableObject`, `@EnvironmentObject`, `@Published`, or `ObservableObject` conformance.

```swift
// ✅ Correct
@Observable
class FooStore {
    var items: [Foo] = []
}

// In views:
@Environment(FooStore.self) private var fooStore

// ❌ Wrong
class FooStore: ObservableObject {
    @Published var items: [Foo] = []
}
```

**Stores are injected at the app root and flow down via `.environment()`.**

`MuninnApp` creates all stores and passes them with `.environment(store)` on the root view. No store should be instantiated inside a view.

**`MuninnApp` holds stores with `@State`.**

This is correct for `@Observable` — `@State` gives SwiftUI ownership and lifecycle. Do not use `@StateObject` (that's for `ObservableObject`).

---

## 2. Store Design

Every persistent store follows the same contract:

```swift
@Observable
class XyzStore {
    var items: [Item] = []
    private let baseURL: URL

    init(baseURL: URL = StoragePaths.base) {
        self.baseURL = baseURL
        load()
    }

    func load() { /* try? JSONDecoder */ }
    func save() { /* try? JSONEncoder + .atomic write */ }
}
```

**Rules:**
- Accept a `baseURL` parameter with a default of `StoragePaths.base`. This is mandatory for test isolation.
- Call `load()` in `init`.
- Call `save()` after every mutation.
- Use `.atomic` write option on every save.
- Use `try?` for file I/O — do not propagate or log errors to the user.
- Only `DataPorter` is allowed to throw; it's the only user-facing I/O operation.

**`SettingsStore` is the exception.** It uses `UserDefaults` with `didSet` observers instead of `load()`/`save()`. All other stores use JSON files.

---

## 3. File Organization

**All source files are flat in `Muninn/`. No subdirectories.**

Never create subdirectories (no `Models/`, `Views/`, `Stores/`). The flat layout is intentional and works well at this scale.

**Naming convention: `<Feature><Role>.swift`**

| Role | Examples |
|------|---------|
| Model | `Clip.swift`, `HistoryItem.swift` |
| Store | `ClipStore.swift`, `HistoryStore.swift` |
| Monitor | `ClipboardMonitor.swift`, `ScreenshotMonitor.swift` |
| Service | `OCRService.swift`, `QRService.swift` |
| View | `PopoverContentView.swift`, `SettingsView.swift` |
| Panel | `SnippetPickerPanel.swift` |

Do not invent new role suffixes. Fit new files into the existing taxonomy.

**Use `// MARK: -` to section files longer than ~100 lines.** Do not split a large file into multiple files just because it's long — `PopoverContentView.swift` is intentionally large and groups related nested types together.

---

## 4. Models

All models are value types (`struct`) conforming to `Identifiable`, `Codable`, and `Hashable`.

**Always write a custom `init(from:)` decoder using `decodeIfPresent` with fallback defaults.** This is the backward-compatibility contract — new fields must never break existing stored data.

```swift
init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    id = try c.decode(UUID.self, forKey: .id)
    value = try c.decodeIfPresent(String.self, forKey: .value)
    contentType = try c.decodeIfPresent(ClipboardContentType.self, forKey: .contentType) ?? .text
    // new fields always use decodeIfPresent with a sensible default
}
```

Never add a required `decode()` call for a field that didn't exist in v1. Use `decodeIfPresent` + default unconditionally when adding new fields.

---

## 5. Blob Storage

**Large binary data (images, PDFs, rich text, file contents) always goes in blobs, never in JSON.**

Use `BlobStorage` for all binary file operations. Blobs are named `{UUID}.{ext}` and live in `StoragePaths.blobs`.

```swift
let filename = BlobStorage.save(data, id: uuid, ext: "png")  // saves, returns "uuid.png"
let data = BlobStorage.load("uuid.png")                      // returns Data?
BlobStorage.delete("uuid.png")
BlobStorage.copy("uuid.png", newID: uuid)                    // returns new filename?
BlobStorage.restore(data, filename: "uuid.png")              // restores data to exact filename (used by undo)
```

When a store evicts an item (e.g., history trimmed to limit), it is responsible for calling `BlobStorage.delete()` on any associated blob files.

---

## 6. Storage Paths & Test Isolation

**Always go through `StoragePaths` for app data paths.** Never hardcode `~/Library/Application Support/Muninn/` inline.

**Test isolation uses a two-level override system:**
1. Pass a temp `baseURL` to stores — all JSON files write there instead.
2. Set `BlobStorage.blobDirOverride` and `StoragePaths.baseOverride` for blob/path redirection.

Every test that touches the filesystem must:
```swift
let dir = makeTempDir()
defer { removeTempDir(dir) }
BlobStorage.blobDirOverride = dir.appendingPathComponent("blobs")
```

Never let tests write to the real app support directory.

---

## 7. Error Handling

**Two tiers:**

| Tier | Who | How |
|------|-----|-----|
| Internal I/O | Stores, monitors, blob storage | `try?` — silent failure, app stays functional |
| User-facing I/O | `DataPorter` only | `throws` — surface errors via alert dialogs |

Do not add `do/catch` logging to store save/load operations. The app is designed to degrade gracefully. Do not add `throws` to store methods — callers shouldn't need to handle persistence errors.

When introducing a new user-facing operation that reads/writes files (e.g., a new export format), follow DataPorter's pattern: `throws`, called from the UI with a `do/catch` that presents an `NSAlert`.

---

## 8. Concurrency

**Main thread for all store mutations and UI updates. Background queues for compute-heavy services.**

`OCRService`, `QRService`, and `PDFTextService` use `DispatchQueue.global(qos: .userInitiated)` with a `DispatchQueue.main.async` callback. Follow this pattern for any new service that does non-trivial computation.

```swift
func process(_ data: Data, completion: @escaping (String?) -> Void) {
    DispatchQueue.global(qos: .userInitiated).async {
        let result = /* ... heavy work ... */
        DispatchQueue.main.async { completion(result) }
    }
}
```

Do not introduce `async`/`await` or `Task` unless the entire call chain can be converted — mixing callback and structured concurrency creates confusion. The codebase is callback-based; keep it consistent.

---

## 9. AppKit Bridging

**Prefer SwiftUI. Use AppKit only where SwiftUI has no equivalent API.**

Current legitimate AppKit usage: `NSPanel` (non-activating floating window), `NSEvent` global monitors (keyboard/mouse), `NSPasteboard` (clipboard access), `NSWorkspace` (frontmost app, app icons), `NSStatusBarButton` (menu bar icon), `NSSound` (system sounds), `NSAlert` (modal confirmation).

Do not use `NSApplicationDelegate`. The app uses SwiftUI's `MenuBarExtra`, `Window`, and `Settings` scenes for lifecycle management.

When bridging AppKit into SwiftUI, prefer `ViewRepresentable` or direct calls within a `.onAppear`/`.task` block. Do not subclass SwiftUI views.

---

## 10. UI Patterns

**View helpers live in `PopoverContentView.swift` as extensions**, not in separate utility files. This includes `.tooltip()`, `.if(_:transform:)`, `HoverBackground`, etc. Only extract to a separate file if a helper is used across 3+ distinct view files.

**Nested view types** (row components, chips, sub-views specific to one parent) are defined inside the parent file as separate structs, not in separate files.

**Settings** are passed to views via `@Environment`. Do not pass `SettingsStore` as a constructor argument to views.

**Keyboard event handling** uses `NSEvent` monitors installed in `.onAppear` and removed in `.onDisappear`. Key codes must be defined as named constants, not inline magic numbers:

```swift
// ✅
private enum KeyCode {
    static let returnKey: UInt16 = 36
    static let escape: UInt16 = 53
    static let downArrow: UInt16 = 125
    static let upArrow: UInt16 = 126
}

// ❌
if event.keyCode == 125 { ... }
```

---

## 11. Localization

**Use `String(localized:)` for all user-visible strings.** Do not use bare string literals in views or models.

The app uses a String Catalog (`Localizable.xcstrings`). New strings are picked up automatically by Xcode. Do not manually edit the catalog.

---

## 12. Content Types

**`ClipboardContentType` is the canonical enum for all content discrimination.** Do not use string comparisons or `UTType` checks outside of `ClipboardMonitor`. Once a type is detected during capture, it flows through the system as `ClipboardContentType`.

**Detection order in `ClipboardMonitor` is: `fileURLs` → `image` → `pdf` → `color` → `text`.** This order is load-bearing — do not change it without understanding the implications (e.g., a PDF file dragged in could match as both `fileURL` and `pdf`).

**PDF text extraction is an intentional cross-type concern.** A `.fileURL` item whose single file has a `.pdf` extension also triggers `PDFTextService` in `ClipboardMonitor`, despite being captured as a `fileURL` type. This is the expected behaviour — copying a PDF from Finder goes through the `fileURL` branch, but the content is still text-searchable. `HistoryStore.scanForPDFText()` covers both `.pdf` items and `.fileURL` items with `.pdf` blobs.

---

## 13. App Intents

**Intents load data directly from disk** (via `StoragePaths.base`), not from live store instances. This is intentional — intents run in an extension context where the app may not be running.

When adding a new intent:
- Add the intent class to `MuninnIntents.swift`
- Add a shortcut phrase to `MuninnShortcuts.swift`
- If the intent needs a custom enum type for parameters, define it in `MuninnIntents.swift` (see `TextTransformType`)
- Keep the intent's load logic read-only; never mutate stores from an intent

---

## 14. Dependencies

**One external dependency: [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts).** Do not add new Swift Package Manager dependencies without strong justification. The project intentionally uses system frameworks (Vision, AppKit, SwiftUI, Charts, AppIntents) to minimize surface area and keep the app self-contained.

If a new capability is genuinely needed and a system API exists, use the system API even if it's more verbose.

---

## 15. Testing

**Use Swift Testing** (`@Test`, `#expect`, `@Suite`). Do not use XCTest for new tests.

**Every new store must have tests covering:**
- Add/mutate + persistence round-trip
- Load from corrupt or missing JSON (graceful fallback)
- Test isolation via `baseURL`

**Every new model must have tests covering:**
- `preview` computed property
- Backward-compatible decoding (a JSON payload missing new fields decodes with defaults)

**Services** (`OCRService`, `QRService`, and any new ones) must have tests for valid input, invalid input, and empty input.

**Pure view-logic helpers** (free functions in `ViewHelpers.swift` like `filterClips`, `filterHistoryItems`, `hexColorString`) must be tested. Extract testable logic out of views into `ViewHelpers.swift` before writing tests.

**SwiftUI/AppKit-coupled view code** is not unit-tested. UI composition and layout in `View` body implementations are acceptable to leave untested.

---

## 16. Project Metadata

| Property | Value |
|----------|-------|
| Bundle ID | `com.nate.Muninn` |
| Deployment target | macOS 14.0 |
| Swift version | 5.0 |
| Data directory | `~/Library/Application Support/Muninn/` |
| Export format version | 1 |
