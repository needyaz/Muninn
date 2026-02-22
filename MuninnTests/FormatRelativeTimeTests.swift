import Testing
import Foundation
@testable import Muninn

@Suite("formatRelativeTime")
struct FormatRelativeTimeTests {

    private let now = Date(timeIntervalSinceReferenceDate: 700_000_000)

    @Test("just now (0 seconds)")
    func justNow() {
        #expect(PopoverContentView.formatRelativeTime(now, now: now) == "now")
    }

    @Test("30 seconds ago shows now")
    func thirtySeconds() {
        let date = now.addingTimeInterval(-30)
        #expect(PopoverContentView.formatRelativeTime(date, now: now) == "now")
    }

    @Test("59 seconds ago shows now")
    func fiftyNineSeconds() {
        let date = now.addingTimeInterval(-59)
        #expect(PopoverContentView.formatRelativeTime(date, now: now) == "now")
    }

    @Test("1 minute ago")
    func oneMinute() {
        let date = now.addingTimeInterval(-60)
        #expect(PopoverContentView.formatRelativeTime(date, now: now) == "1m")
    }

    @Test("45 minutes ago")
    func fortyFiveMinutes() {
        let date = now.addingTimeInterval(-45 * 60)
        #expect(PopoverContentView.formatRelativeTime(date, now: now) == "45m")
    }

    @Test("59 minutes ago")
    func fiftyNineMinutes() {
        let date = now.addingTimeInterval(-59 * 60)
        #expect(PopoverContentView.formatRelativeTime(date, now: now) == "59m")
    }

    @Test("1 hour ago")
    func oneHour() {
        let date = now.addingTimeInterval(-60 * 60)
        #expect(PopoverContentView.formatRelativeTime(date, now: now) == "1h")
    }

    @Test("23 hours ago")
    func twentyThreeHours() {
        let date = now.addingTimeInterval(-23 * 60 * 60)
        #expect(PopoverContentView.formatRelativeTime(date, now: now) == "23h")
    }

    @Test("1 day ago")
    func oneDay() {
        let date = now.addingTimeInterval(-24 * 60 * 60)
        #expect(PopoverContentView.formatRelativeTime(date, now: now) == "1d")
    }

    @Test("7 days ago")
    func sevenDays() {
        let date = now.addingTimeInterval(-7 * 24 * 60 * 60)
        #expect(PopoverContentView.formatRelativeTime(date, now: now) == "7d")
    }
}
