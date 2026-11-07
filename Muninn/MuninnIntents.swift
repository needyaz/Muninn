import AppIntents
import AppKit

// MARK: - Errors

enum MuninnIntentError: Error, CustomLocalizedStringResourceConvertible {
    case snippetNotFound

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .snippetNotFound:
            return "No snippet found with that name."
        }
    }
}

// MARK: - Shared helpers

private func loadHistory() -> [HistoryItem] {
    let url = StoragePaths.base.appendingPathComponent("history.json")
    guard let data = try? Data(contentsOf: url) else { return [] }
    // Sensitive items are never handed to Shortcuts.
    return ((try? JSONDecoder().decode([HistoryItem].self, from: data)) ?? []).filter { $0.isSensitive != true }
}

private func loadClips() -> [Clip] {
    let url = StoragePaths.base.appendingPathComponent("clips.json")
    guard let data = try? Data(contentsOf: url) else { return [] }
    return (try? JSONDecoder().decode([Clip].self, from: data)) ?? []
}

// MARK: - Transform enum for Shortcuts

enum TextTransformType: String, AppEnum {
    case uppercase
    case lowercase
    case capitalize
    case trim
    case removeBlankLines

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        "Text Transformation"
    }

    static var caseDisplayRepresentations: [TextTransformType: DisplayRepresentation] {
        [
            .uppercase: "UPPERCASE",
            .lowercase: "lowercase",
            .capitalize: "Capitalize Words",
            .trim: "Trim Whitespace",
            .removeBlankLines: "Remove Blank Lines",
        ]
    }

    /// Maps to the corresponding TextTransform case. Exhaustive switch enforces
    /// that both enums stay in sync — a missing case here is a compile error.
    var asTextTransform: TextTransform {
        switch self {
        case .uppercase: return .uppercase
        case .lowercase: return .lowercase
        case .capitalize: return .capitalize
        case .trim: return .trimWhitespace
        case .removeBlankLines: return .removeBlankLines
        }
    }
}

// MARK: - GetClipboardHistory

struct GetClipboardHistory: AppIntent {
    static var title: LocalizedStringResource = "Get Clipboard History"
    static var description: IntentDescription = "Returns the most recent text items from Muninn history (up to 100). Sensitive items are never included."

    @Parameter(title: "Count", default: 10)
    var count: Int

    func perform() async throws -> some IntentResult & ReturnsValue<[String]> {
        let items = loadHistory()
            .filter { $0.contentType == .text }
            .prefix(min(max(count, 0), 100))
            .compactMap(\.value)
        return .result(value: Array(items))
    }
}

// MARK: - SearchClipboardHistory

struct SearchClipboardHistory: AppIntent {
    static var title: LocalizedStringResource = "Search Clipboard History"
    static var description: IntentDescription = "Search Muninn history for items matching a query."

    @Parameter(title: "Query")
    var query: String

    func perform() async throws -> some IntentResult & ReturnsValue<[String]> {
        let q = query.lowercased()
        let items = loadHistory()
            .filter { $0.contentType == .text }
            .compactMap(\.value)
            .filter { $0.lowercased().contains(q) }
        return .result(value: items)
    }
}

// MARK: - CopySnippetByName

struct CopySnippetByName: AppIntent {
    static var title: LocalizedStringResource = "Copy Snippet by Name"
    static var description: IntentDescription = "Find a Muninn snippet by name and copy it to the clipboard."

    @Parameter(title: "Name")
    var name: String

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let clips = loadClips()
        guard let clip = clips.first(where: { $0.name.lowercased() == name.lowercased() }),
              let value = clip.value else {
            throw MuninnIntentError.snippetNotFound
        }
        PasteboardWriter.copy(value)
        return .result(value: value)
    }
}

// MARK: - GetLatestClipboardItem

struct GetLatestClipboardItem: AppIntent {
    static var title: LocalizedStringResource = "Get Latest Clipboard Item"
    static var description: IntentDescription = "Returns the most recent text item from Muninn history."

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let items = loadHistory()
        if let first = items.first(where: { $0.contentType == .text }), let value = first.value {
            return .result(value: value)
        }
        return .result(value: items.first?.preview ?? "")
    }
}

// MARK: - TransformText

struct TransformText: AppIntent {
    static var title: LocalizedStringResource = "Transform Text"
    static var description: IntentDescription = "Apply a text transformation such as uppercase, lowercase, or trim."

    @Parameter(title: "Text")
    var text: String

    @Parameter(title: "Transformation")
    var transformation: TextTransformType

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        return .result(value: applyTransform(text, transformation.asTextTransform))
    }
}
