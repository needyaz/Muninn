import Foundation

enum TextTransform: String, CaseIterable {
    case uppercase = "UPPERCASE"
    case lowercase = "lowercase"
    case capitalize = "Capitalize Words"
    case trimWhitespace = "Trim Whitespace"
    case removeBlankLines = "Remove Blank Lines"

    var displayName: String {
        switch self {
        case .uppercase: return String(localized: "UPPERCASE")
        case .lowercase: return String(localized: "lowercase")
        case .capitalize: return String(localized: "Capitalize Words")
        case .trimWhitespace: return String(localized: "Trim Whitespace")
        case .removeBlankLines: return String(localized: "Remove Blank Lines")
        }
    }
}

func applyTransform(_ text: String, _ transform: TextTransform) -> String {
    switch transform {
    case .uppercase:
        return text.uppercased()
    case .lowercase:
        return text.lowercased()
    case .capitalize:
        return text.capitalized
    case .trimWhitespace:
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    case .removeBlankLines:
        return text.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .joined(separator: "\n")
    }
}
