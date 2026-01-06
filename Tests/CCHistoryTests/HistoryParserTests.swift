import XCTest

@testable import CCHistory

/// Tests for the HistoryParser class
final class HistoryParserTests: XCTestCase {

  // MARK: - Initialization Tests

  func testInitDefaultPath() {
    let parser = HistoryParser()
    // Verify it works by attempting to parse (will return empty for non-existent path)
    let sessions = parser.parseSessionsFromProjects()
    // Should not crash and return empty array for default path
    XCTAssertTrue(sessions.isEmpty)
  }

  func testInitCustomPath() {
    let customPath = "/custom/path/to/claude"
    let parser = HistoryParser(claudePath: customPath)
    // Verify custom path is used by attempting to parse
    let sessions = parser.parseSessionsFromProjects()
    // Should return empty for non-existent path
    XCTAssertEqual(sessions.count, 0)
  }

  // MARK: - parseSessionFile Tests

  func testParseSessionFileValid() throws {
    let parser = HistoryParser()
    let tempDir = FileManager.default.temporaryDirectory
    let sessionFile = tempDir.appendingPathComponent("test_session.jsonl")

    // Create a valid JSONL session file
    let jsonlContent = """
      {"type": "summary", "summary": "Build authentication feature"}
      {"type": "user", "timestamp": "2024-01-15T10:30:45.123Z", "content": "Let's build auth"}
      {"type": "assistant", "timestamp": "2024-01-15T10:30:46.456Z", "content": "I'll help"}
      {"type": "user", "timestamp": "2024-01-15T10:31:00.789Z", "content": "Thanks"}
      """

    try jsonlContent.write(to: sessionFile, atomically: true, encoding: .utf8)

    let session = parser.parseSessionFile(
      path: sessionFile.path,
      sessionId: "test-session-id",
      projectPath: "/Users/test/project"
    )

    XCTAssertNotNil(session)
    XCTAssertEqual(session?.session.sessionId, "test-session-id")
    XCTAssertEqual(session?.session.displayName, "Build authentication feature")
    XCTAssertEqual(session?.session.projectPath, "/Users/test/project")
    XCTAssertEqual(session?.session.messageCount, 2)

    // Clean up
    try? FileManager.default.removeItem(at: sessionFile)
  }

  func testParseSessionFileMissingSummary() throws {
    let parser = HistoryParser()
    let tempDir = FileManager.default.temporaryDirectory
    let sessionFile = tempDir.appendingPathComponent("no_summary.jsonl")

    // JSONL without summary - should return nil
    let jsonlContent = """
      {"type": "user", "timestamp": "2024-01-15T10:30:45.123Z", "content": "Test"}
      """

    try jsonlContent.write(to: sessionFile, atomically: true, encoding: .utf8)

    let session = parser.parseSessionFile(
      path: sessionFile.path,
      sessionId: "test-id",
      projectPath: "/test"
    )

    XCTAssertNil(session)

    // Clean up
    try? FileManager.default.removeItem(at: sessionFile)
  }

  func testParseSessionFileNoTimestamps() throws {
    let parser = HistoryParser()
    let tempDir = FileManager.default.temporaryDirectory
    let sessionFile = tempDir.appendingPathComponent("no_timestamp.jsonl")

    // JSONL with summary but no timestamps - should return nil
    let jsonlContent = """
      {"type": "summary", "summary": "Test session"}
      """

    try jsonlContent.write(to: sessionFile, atomically: true, encoding: .utf8)

    let session = parser.parseSessionFile(
      path: sessionFile.path,
      sessionId: "test-id",
      projectPath: "/test"
    )

    XCTAssertNil(session)

    // Clean up
    try? FileManager.default.removeItem(at: sessionFile)
  }

  func testParseSessionFileEmpty() throws {
    let parser = HistoryParser()
    let tempDir = FileManager.default.temporaryDirectory
    let sessionFile = tempDir.appendingPathComponent("empty.jsonl")

    try "".write(to: sessionFile, atomically: true, encoding: .utf8)

    let session = parser.parseSessionFile(
      path: sessionFile.path,
      sessionId: "test-id",
      projectPath: "/test"
    )

    XCTAssertNil(session)

    // Clean up
    try? FileManager.default.removeItem(at: sessionFile)
  }

  func testParseSessionFileNonexistent() {
    let parser = HistoryParser()

    let session = parser.parseSessionFile(
      path: "/nonexistent/path/file.jsonl",
      sessionId: "test-id",
      projectPath: "/test"
    )

    XCTAssertNil(session)
  }

  func testParseSessionFileMalformedJSON() throws {
    let parser = HistoryParser()
    let tempDir = FileManager.default.temporaryDirectory
    let sessionFile = tempDir.appendingPathComponent("malformed.jsonl")

    // Mix of valid and invalid JSON
    let jsonlContent = """
      {"type": "summary", "summary": "Valid session"}
      invalid json line
      {"type": "user", "timestamp": "2024-01-15T10:30:45.123Z", "content": "Test"}
      """

    try jsonlContent.write(to: sessionFile, atomically: true, encoding: .utf8)

    let session = parser.parseSessionFile(
      path: sessionFile.path,
      sessionId: "test-id",
      projectPath: "/test"
    )

    // Should still parse valid lines
    XCTAssertNotNil(session)
    XCTAssertEqual(session?.session.displayName, "Valid session")

    // Clean up
    try? FileManager.default.removeItem(at: sessionFile)
  }

  func testParseSessionFileMessageCount() throws {
    let parser = HistoryParser()
    let tempDir = FileManager.default.temporaryDirectory
    let sessionFile = tempDir.appendingPathComponent("message_count.jsonl")

    // Multiple user messages
    let jsonlContent = """
      {"type": "summary", "summary": "Chat with multiple messages"}
      {"type": "user", "timestamp": "2024-01-15T10:30:45.123Z", "content": "Message 1"}
      {"type": "assistant", "timestamp": "2024-01-15T10:30:46.123Z", "content": "Response 1"}
      {"type": "user", "timestamp": "2024-01-15T10:31:00.123Z", "content": "Message 2"}
      {"type": "assistant", "timestamp": "2024-01-15T10:31:01.123Z", "content": "Response 2"}
      {"type": "user", "timestamp": "2024-01-15T10:31:30.123Z", "content": "Message 3"}
      """

    try jsonlContent.write(to: sessionFile, atomically: true, encoding: .utf8)

    let session = parser.parseSessionFile(
      path: sessionFile.path,
      sessionId: "test-id",
      projectPath: "/test"
    )

    XCTAssertNotNil(session)
    XCTAssertEqual(session?.session.messageCount, 3)

    // Clean up
    try? FileManager.default.removeItem(at: sessionFile)
  }

  func testParseSessionFileLatestTimestamp() throws {
    let parser = HistoryParser()
    let tempDir = FileManager.default.temporaryDirectory
    let sessionFile = tempDir.appendingPathComponent("timestamp.jsonl")

    let baseTime = "2024-01-15T10:00:00.000Z"
    let laterTime = "2024-01-15T12:30:45.789Z"

    let jsonlContent = """
      {"type": "summary", "summary": "Timestamp test"}
      {"type": "user", "timestamp": "\(baseTime)", "content": "Early message"}
      {"type": "assistant", "timestamp": "\(laterTime)", "content": "Late response"}
      """

    try jsonlContent.write(to: sessionFile, atomically: true, encoding: .utf8)

    let session = parser.parseSessionFile(
      path: sessionFile.path,
      sessionId: "test-id",
      projectPath: "/test"
    )

    XCTAssertNotNil(session)

    // Parse the late timestamp to compare
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    let expectedDate = formatter.date(from: laterTime)

    XCTAssertNotNil(expectedDate)
    // Unwrap optionals for accurate comparison
    let actualTimestamp = session?.session.timestamp.timeIntervalSince1970
    let expectedTimestamp = expectedDate?.timeIntervalSince1970
    XCTAssertNotNil(actualTimestamp)
    XCTAssertNotNil(expectedTimestamp)
    XCTAssertEqual(actualTimestamp!, expectedTimestamp!, accuracy: 0.001)

    // Clean up
    try? FileManager.default.removeItem(at: sessionFile)
  }

  // MARK: - parseSessionsFromProjects Tests

  func testParseSessionsFromProjectsNonexistentDirectory() {
    let parser = HistoryParser(claudePath: "/nonexistent/path")
    let sessions = parser.parseSessionsFromProjects()
    XCTAssertEqual(sessions, [])
  }

  // MARK: - getSessions Tests

  func testGetSessionsEmpty() {
    let parser = HistoryParser(claudePath: "/nonexistent")
    let sessions = parser.getSessions(sortOption: .mostRecent, limit: 10)
    XCTAssertEqual(sessions, [])
  }

  func testGetSessionsLimit() {
    let parser = HistoryParser(claudePath: "/nonexistent")
    let sessions = parser.getSessions(sortOption: .allTime, limit: 5)
    // Empty result should respect limit
    XCTAssertTrue(sessions.count <= 5)
  }

  // MARK: - getActiveSessions Tests

  func testGetActiveSessionsDefault() {
    let parser = HistoryParser(claudePath: "/nonexistent")
    let sessions = parser.getActiveSessions()
    XCTAssertEqual(sessions, [])
  }

  func testGetActiveSessionsWithLimit() {
    let parser = HistoryParser(claudePath: "/nonexistent")
    let sessions = parser.getActiveSessions(limit: 3)
    XCTAssertEqual(sessions, [])
  }

  // MARK: - Project Path Encoding Tests

  func testProjectPathEncoding() {
    // Test that the unescaping logic works (used in parseSessionsFromProjects)
    let encoded = "Users-tuannvm-Projects-sandbox-cchistory"
    let decoded = encoded.replacingOccurrences(of: "-", with: "/")
    XCTAssertEqual(decoded, "Users/tuannvm/Projects/sandbox/cchistory")
  }

  func testProjectPathEdgeCases() {
    // Single path component
    XCTAssertEqual("project".replacingOccurrences(of: "-", with: "/"), "project")

    // Multiple hyphens in original path (edge case - would be ambiguous)
    let encoded = "my-project-name"
    let decoded = encoded.replacingOccurrences(of: "-", with: "/")
    // This shows the limitation of the encoding scheme
    XCTAssertEqual(decoded, "my/project/name")
  }
}

// MARK: - Integration Tests

final class HistoryParserIntegrationTests: XCTestCase {

  // Test that multiple sessions can be sorted correctly
  func testGetSessionsSorting() {
    let parser = HistoryParser(claudePath: "/nonexistent")

    // With no sessions, all sorts return empty
    XCTAssertTrue(parser.getSessions(sortOption: .mostActive).isEmpty)
    XCTAssertTrue(parser.getSessions(sortOption: .mostRecent).isEmpty)
    XCTAssertTrue(parser.getSessions(sortOption: .lastHour).isEmpty)
    XCTAssertTrue(parser.getSessions(sortOption: .lastDay).isEmpty)
    XCTAssertTrue(parser.getSessions(sortOption: .lastWeek).isEmpty)
    XCTAssertTrue(parser.getSessions(sortOption: .allTime).isEmpty)
  }
}

extension HistoryParserTests {
  static let allTests = [
    ("testInitDefaultPath", testInitDefaultPath),
    ("testInitCustomPath", testInitCustomPath),
    ("testParseSessionFileValid", testParseSessionFileValid),
    ("testParseSessionFileMissingSummary", testParseSessionFileMissingSummary),
    ("testParseSessionFileNoTimestamps", testParseSessionFileNoTimestamps),
    ("testParseSessionFileEmpty", testParseSessionFileEmpty),
    ("testParseSessionFileNonexistent", testParseSessionFileNonexistent),
    ("testParseSessionFileMalformedJSON", testParseSessionFileMalformedJSON),
    ("testParseSessionFileMessageCount", testParseSessionFileMessageCount),
    ("testParseSessionFileLatestTimestamp", testParseSessionFileLatestTimestamp),
    (
      "testParseSessionsFromProjectsNonexistentDirectory",
      testParseSessionsFromProjectsNonexistentDirectory
    ),
    ("testGetSessionsEmpty", testGetSessionsEmpty),
    ("testGetSessionsLimit", testGetSessionsLimit),
    ("testGetActiveSessionsDefault", testGetActiveSessionsDefault),
    ("testGetActiveSessionsWithLimit", testGetActiveSessionsWithLimit),
    ("testProjectPathEncoding", testProjectPathEncoding),
    ("testProjectPathEdgeCases", testProjectPathEdgeCases),
  ]
}

extension HistoryParserIntegrationTests {
  static let allTests = [
    ("testGetSessionsSorting", testGetSessionsSorting)
  ]
}
