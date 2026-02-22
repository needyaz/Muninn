import Testing
@testable import Muninn

@Suite("TextTransform")
struct TextTransformTests {

    @Test("uppercase")
    func uppercase() {
        #expect(applyTransform("hello World", .uppercase) == "HELLO WORLD")
    }

    @Test("lowercase")
    func lowercase() {
        #expect(applyTransform("Hello WORLD", .lowercase) == "hello world")
    }

    @Test("capitalize")
    func capitalize() {
        #expect(applyTransform("hello world", .capitalize) == "Hello World")
    }

    @Test("trim whitespace")
    func trimWhitespace() {
        #expect(applyTransform("  hello  \n", .trimWhitespace) == "hello")
    }

    @Test("remove blank lines")
    func removeBlankLines() {
        let input = "line1\n\nline2\n  \nline3"
        #expect(applyTransform(input, .removeBlankLines) == "line1\nline2\nline3")
    }

    @Test("empty string")
    func emptyString() {
        #expect(applyTransform("", .uppercase) == "")
        #expect(applyTransform("", .trimWhitespace) == "")
        #expect(applyTransform("", .removeBlankLines) == "")
    }

    @Test("allCases has 5 transforms")
    func allCasesCount() {
        #expect(TextTransform.allCases.count == 5)
    }

    @Test("rawValues match display strings")
    func rawValues() {
        #expect(TextTransform.uppercase.rawValue == "UPPERCASE")
        #expect(TextTransform.lowercase.rawValue == "lowercase")
        #expect(TextTransform.capitalize.rawValue == "Capitalize Words")
        #expect(TextTransform.trimWhitespace.rawValue == "Trim Whitespace")
        #expect(TextTransform.removeBlankLines.rawValue == "Remove Blank Lines")
    }
}
