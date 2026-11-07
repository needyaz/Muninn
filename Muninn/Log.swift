import Foundation
import os

/// One logger for the app. Interpolated values are private by default, so errors that quote data stay out of shared logs.
enum Log {
    static let storage = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Muninn", category: "storage")
}
