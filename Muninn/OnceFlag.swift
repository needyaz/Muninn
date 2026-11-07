import Foundation

/// Thread-safe "first caller wins" flag, used so an asynchronous completion fires exactly once.
final class OnceFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var claimed = false

    /// Returns true for the first call only.
    func claim() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if claimed { return false }
        claimed = true
        return true
    }
}
