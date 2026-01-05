import XCTest
@testable import CCHistory

/// Tests for the Session model
final class SessionTests: XCTestCase {

    // MARK: - Initialization Tests

    func testSessionInitialization() {
        let session = Session(
            id: "test-id",
            sessionId: "session-123",
            displayName: "Test Session",
            timestamp: Date(),
            projectPath: "/Users/test/project",
            messageCount: 10,
            gitBranch: "main",
            gitRepoName: "test-repo"
        )

        XCTAssertEqual(session.id, "test-id")
        XCTAssertEqual(session.sessionId, "session-123")
        XCTAssertEqual(session.displayName, "Test Session")
        XCTAssertEqual(session.projectPath, "/Users/test/project")
        XCTAssertEqual(session.messageCount, 10)
        XCTAssertEqual(session.gitBranch, "main")
        XCTAssertEqual(session.gitRepoName, "test-repo")
    }

    // MARK: - formattedDate Tests

    func testFormattedDate() {
        let fixedDate = Date(timeIntervalSince1970: 1704067200) // 2024-01-01 00:00:00 UTC
        let session = Session(
            id: "test-id",
            sessionId: "session-123",
            displayName: "Test",
            timestamp: fixedDate,
            projectPath: "/test"
        )

        let formatted = session.formattedDate
        XCTAssertFalse(formatted.isEmpty)
        // Format varies by locale, just check it's not empty
    }

    // MARK: - formattedRelativeDate Tests

    func testFormattedRelativeDateJustNow() {
        let session = Session(
            id: "test-id",
            sessionId: "session-123",
            displayName: "Test",
            timestamp: Date(),
            projectPath: "/test"
        )

        XCTAssertTrue(session.formattedRelativeDate == "just now" || session.formattedRelativeDate.contains("m ago"))
    }

    func testFormattedRelativeDateMinutesAgo() {
        let session = Session(
            id: "test-id",
            sessionId: "session-123",
            displayName: "Test",
            timestamp: Date().addingTimeInterval(-300), // 5 minutes ago
            projectPath: "/test"
        )

        XCTAssertTrue(session.formattedRelativeDate.contains("m ago"))
    }

    func testFormattedRelativeDateHoursAgo() {
        let session = Session(
            id: "test-id",
            sessionId: "session-123",
            displayName: "Test",
            timestamp: Date().addingTimeInterval(-7200), // 2 hours ago
            projectPath: "/test"
        )

        XCTAssertTrue(session.formattedRelativeDate.contains("h ago"))
    }

    func testFormattedRelativeDateDaysAgo() {
        let session = Session(
            id: "test-id",
            sessionId: "session-123",
            displayName: "Test",
            timestamp: Date().addingTimeInterval(-172800), // 2 days ago
            projectPath: "/test"
        )

        XCTAssertTrue(session.formattedRelativeDate.contains("d ago"))
    }

    func testFormattedRelativeDateOldDate() {
        let oldDate = Date().addingTimeInterval(-10_000_000) // Very old
        let session = Session(
            id: "test-id",
            sessionId: "session-123",
            displayName: "Test",
            timestamp: oldDate,
            projectPath: "/test"
        )

        // Old dates show formatted date
        XCTAssertFalse(session.formattedRelativeDate.contains("ago"))
    }

    // MARK: - repoName Tests

    func testRepoNameWithGitRepoName() {
        let session = Session(
            id: "test-id",
            sessionId: "session-123",
            displayName: "Test",
            timestamp: Date(),
            projectPath: "/Users/test/project",
            gitRepoName: "my-repo"
        )

        XCTAssertEqual(session.repoName, "my-repo")
    }

    func testRepoNameWithoutGitRepoName() {
        let session = Session(
            id: "test-id",
            sessionId: "session-123",
            displayName: "Test",
            timestamp: Date(),
            projectPath: "/Users/test/my-project"
        )

        XCTAssertEqual(session.repoName, "my-project")
    }

    func testRepoNameEmptyPath() {
        let session = Session(
            id: "test-id",
            sessionId: "session-123",
            displayName: "Test",
            timestamp: Date(),
            projectPath: ""
        )

        XCTAssertEqual(session.repoName, "")
    }

    // MARK: - cleanedDisplayName Tests

    func testCleanedDisplayNameNormal() {
        let session = Session(
            id: "test-id",
            sessionId: "session-123",
            displayName: "Build API endpoint",
            timestamp: Date(),
            projectPath: "/test"
        )

        XCTAssertEqual(session.cleanedDisplayName, "Build API endpoint")
    }

    func testCleanedDisplayNameCommand() {
        let commands = ["/model", "/help", "/clear", "[command]"]
        for command in commands {
            let session = Session(
                id: "test-id",
                sessionId: "session-123",
                displayName: command,
                timestamp: Date(),
                projectPath: "/test"
            )

            XCTAssertEqual(session.cleanedDisplayName, "Unnamed Session")
        }
    }

    func testCleanedDisplayNameEmpty() {
        let session = Session(
            id: "test-id",
            sessionId: "session-123",
            displayName: "",
            timestamp: Date(),
            projectPath: "/test"
        )

        XCTAssertEqual(session.cleanedDisplayName, "Unnamed Session")
    }

    func testCleanedDisplayNameUntitled() {
        let session = Session(
            id: "test-id",
            sessionId: "session-123",
            displayName: "Untitled Session",
            timestamp: Date(),
            projectPath: "/test"
        )

        XCTAssertEqual(session.cleanedDisplayName, "Unnamed Session")
    }

    func testCleanedDisplayNameTruncation() {
        let longName = String(repeating: "a", count: 100)
        let session = Session(
            id: "test-id",
            sessionId: "session-123",
            displayName: longName,
            timestamp: Date(),
            projectPath: "/test"
        )

        XCTAssertTrue(session.cleanedDisplayName.count <= 50)
        XCTAssertTrue(session.cleanedDisplayName.hasSuffix("..."))
    }

    func testCleanedDisplayNameWhitespace() {
        let session = Session(
            id: "test-id",
            sessionId: "session-123",
            displayName: "  Test Session  ",
            timestamp: Date(),
            projectPath: "/test"
        )

        XCTAssertEqual(session.cleanedDisplayName, "Test Session")
    }

    // MARK: - matchesTimeFilter Tests

    func testMatchesTimeFilterAllTime() {
        let oldSession = Session(
            id: "test-id",
            sessionId: "session-123",
            displayName: "Test",
            timestamp: Date().addingTimeInterval(-10_000_000),
            projectPath: "/test"
        )

        XCTAssertTrue(oldSession.matchesTimeFilter(.allTime))
    }

    func testMatchesTimeFilterLastHour() {
        let recentSession = Session(
            id: "test-id",
            sessionId: "session-123",
            displayName: "Test",
            timestamp: Date().addingTimeInterval(-1800), // 30 minutes ago
            projectPath: "/test"
        )

        XCTAssertTrue(recentSession.matchesTimeFilter(.lastHour))

        let oldSession = Session(
            id: "test-id",
            sessionId: "session-123",
            displayName: "Test",
            timestamp: Date().addingTimeInterval(-7200), // 2 hours ago
            projectPath: "/test"
        )

        XCTAssertFalse(oldSession.matchesTimeFilter(.lastHour))
    }

    func testMatchesTimeFilterLastDay() {
        let recentSession = Session(
            id: "test-id",
            sessionId: "session-123",
            displayName: "Test",
            timestamp: Date().addingTimeInterval(-36000), // 10 hours ago
            projectPath: "/test"
        )

        XCTAssertTrue(recentSession.matchesTimeFilter(.lastDay))

        let oldSession = Session(
            id: "test-id",
            sessionId: "session-123",
            displayName: "Test",
            timestamp: Date().addingTimeInterval(-100000), // > 24 hours ago
            projectPath: "/test"
        )

        XCTAssertFalse(oldSession.matchesTimeFilter(.lastDay))
    }

    func testMatchesTimeFilterLastWeek() {
        let recentSession = Session(
            id: "test-id",
            sessionId: "session-123",
            displayName: "Test",
            timestamp: Date().addingTimeInterval(-100000), // ~27 hours ago
            projectPath: "/test"
        )

        XCTAssertTrue(recentSession.matchesTimeFilter(.lastWeek))

        let oldSession = Session(
            id: "test-id",
            sessionId: "session-123",
            displayName: "Test",
            timestamp: Date().addingTimeInterval(-1_000_000), // > 1 week ago
            projectPath: "/test"
        )

        XCTAssertFalse(oldSession.matchesTimeFilter(.lastWeek))
    }

    // MARK: - Codable Tests

    func testSessionEncodingDecoding() {
        let session = Session(
            id: "test-id",
            sessionId: "session-123",
            displayName: "Test Session",
            timestamp: Date(timeIntervalSince1970: 1704067200),
            projectPath: "/Users/test/project",
            messageCount: 10,
            gitBranch: "main",
            gitRepoName: "test-repo"
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        do {
            let data = try encoder.encode(session)
            let decoded = try decoder.decode(Session.self, from: data)

            XCTAssertEqual(decoded.id, session.id)
            XCTAssertEqual(decoded.sessionId, session.sessionId)
            XCTAssertEqual(decoded.displayName, session.displayName)
            XCTAssertEqual(decoded.projectPath, session.projectPath)
            XCTAssertEqual(decoded.messageCount, session.messageCount)
            XCTAssertEqual(decoded.gitBranch, session.gitBranch)
            XCTAssertEqual(decoded.gitRepoName, session.gitRepoName)
        } catch {
            XCTFail("Encoding/decoding failed: \(error)")
        }
    }
}

extension SessionTests {
    static let allTests = [
        ("testSessionInitialization", testSessionInitialization),
        ("testFormattedDate", testFormattedDate),
        ("testFormattedRelativeDateJustNow", testFormattedRelativeDateJustNow),
        ("testFormattedRelativeDateMinutesAgo", testFormattedRelativeDateMinutesAgo),
        ("testFormattedRelativeDateHoursAgo", testFormattedRelativeDateHoursAgo),
        ("testFormattedRelativeDateDaysAgo", testFormattedRelativeDateDaysAgo),
        ("testFormattedRelativeDateOldDate", testFormattedRelativeDateOldDate),
        ("testRepoNameWithGitRepoName", testRepoNameWithGitRepoName),
        ("testRepoNameWithoutGitRepoName", testRepoNameWithoutGitRepoName),
        ("testRepoNameEmptyPath", testRepoNameEmptyPath),
        ("testCleanedDisplayNameNormal", testCleanedDisplayNameNormal),
        ("testCleanedDisplayNameCommand", testCleanedDisplayNameCommand),
        ("testCleanedDisplayNameEmpty", testCleanedDisplayNameEmpty),
        ("testCleanedDisplayNameUntitled", testCleanedDisplayNameUntitled),
        ("testCleanedDisplayNameTruncation", testCleanedDisplayNameTruncation),
        ("testCleanedDisplayNameWhitespace", testCleanedDisplayNameWhitespace),
        ("testMatchesTimeFilterAllTime", testMatchesTimeFilterAllTime),
        ("testMatchesTimeFilterLastHour", testMatchesTimeFilterLastHour),
        ("testMatchesTimeFilterLastDay", testMatchesTimeFilterLastDay),
        ("testMatchesTimeFilterLastWeek", testMatchesTimeFilterLastWeek),
        ("testSessionEncodingDecoding", testSessionEncodingDecoding),
    ]
}

// MARK: - SessionSortOption Tests

final class SessionSortOptionTests: XCTestCase {

    func testAllCasesExist() {
        let allCases = SessionSortOption.allCases
        XCTAssertEqual(allCases.count, 6)
    }

    func testRawValues() {
        XCTAssertEqual(SessionSortOption.mostActive.rawValue, "Most Active")
        XCTAssertEqual(SessionSortOption.mostRecent.rawValue, "Most Recent")
        XCTAssertEqual(SessionSortOption.lastHour.rawValue, "Last Hour")
        XCTAssertEqual(SessionSortOption.lastDay.rawValue, "Last 24 Hours")
        XCTAssertEqual(SessionSortOption.lastWeek.rawValue, "Last Week")
        XCTAssertEqual(SessionSortOption.allTime.rawValue, "All Time")
    }

    func testKeyEquivalents() {
        XCTAssertEqual(SessionSortOption.mostActive.keyEquivalent, "1")
        XCTAssertEqual(SessionSortOption.mostRecent.keyEquivalent, "2")
        XCTAssertEqual(SessionSortOption.lastHour.keyEquivalent, "3")
        XCTAssertEqual(SessionSortOption.lastDay.keyEquivalent, "4")
        XCTAssertEqual(SessionSortOption.lastWeek.keyEquivalent, "5")
        XCTAssertEqual(SessionSortOption.allTime.keyEquivalent, "6")
    }
}

extension SessionSortOptionTests {
    static let allTests = [
        ("testAllCasesExist", testAllCasesExist),
        ("testRawValues", testRawValues),
        ("testKeyEquivalents", testKeyEquivalents),
    ]
}

// MARK: - TimeFilter Tests

final class TimeFilterTests: XCTestCase {

    func testRawValues() {
        XCTAssertEqual(TimeFilter.lastHour.rawValue, 3600)
        XCTAssertEqual(TimeFilter.lastDay.rawValue, 86400)
        XCTAssertEqual(TimeFilter.lastWeek.rawValue, 604800)
        XCTAssertEqual(TimeFilter.allTime.rawValue, 0)
    }

    func testDisplayNames() {
        XCTAssertEqual(TimeFilter.lastHour.displayName, "Last Hour")
        XCTAssertEqual(TimeFilter.lastDay.displayName, "Last 24 Hours")
        XCTAssertEqual(TimeFilter.lastWeek.displayName, "Last Week")
        XCTAssertEqual(TimeFilter.allTime.displayName, "All Time")
    }
}

extension TimeFilterTests {
    static let allTests = [
        ("testRawValues", testRawValues),
        ("testDisplayNames", testDisplayNames),
    ]
}
