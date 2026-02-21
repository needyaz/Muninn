import Foundation

enum TextTransform: String, CaseIterable {
    case uppercase = "UPPERCASE"
    case lowercase = "lowercase"
    case capitalize = "Capitalize Words"
    case trimWhitespace = "Trim Whitespace"
    case removeBlankLines = "Remove Blank Lines"
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
