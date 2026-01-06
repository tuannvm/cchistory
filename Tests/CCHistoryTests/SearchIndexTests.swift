import XCTest

@testable import CCHistory

/// Tests for the SearchIndex struct
final class SearchIndexTests: XCTestCase {

  // MARK: - Initialization Tests

  func testInitDefault() {
    let index = SearchIndex()
    XCTAssertEqual(index.count, 0)
  }

  func testInitCustomMaxMessages() {
    let index = SearchIndex(maxMessagesToIndex: 5)
    XCTAssertEqual(index.count, 0)
  }

  // MARK: - indexSession Tests

  func testIndexSessionBasic() {
    var index = SearchIndex()
    let session = Session(
      id: "session-1",
      sessionId: "test-session-1",
      displayName: "Build authentication feature",
      timestamp: Date(),
      projectPath: "/Users/test/my-app",
      messageCount: 10
    )

    index.indexSession(session, messages: ["Implement login", "Add OAuth"])

    XCTAssertEqual(index.count, 1)
  }

  func testIndexSessionWithMultipleMessages() {
    var index = SearchIndex(maxMessagesToIndex: 3)
    let session = Session(
      id: "session-1",
      sessionId: "test-session-1",
      displayName: "API Development",
      timestamp: Date(),
      projectPath: "/Users/test/api",
      messageCount: 10
    )

    let messages = ["Message 1", "Message 2", "Message 3", "Message 4", "Message 5"]
    index.indexSession(session, messages: messages)

    XCTAssertEqual(index.count, 1)
    // Should only index first 3 messages
  }

  func testIndexSessionWithGitInfo() {
    var index = SearchIndex()
    let session = Session(
      id: "session-1",
      sessionId: "test-session-1",
      displayName: "Feature work",
      timestamp: Date(),
      projectPath: "/Users/test/project",
      messageCount: 5,
      gitBranch: "feature/auth",
      gitRepoName: "my-repo"
    )

    index.indexSession(session, messages: ["Add login"])

    XCTAssertEqual(index.count, 1)
  }

  func testIndexSessionMultiple() {
    var index = SearchIndex()
    let session1 = Session(
      id: "session-1",
      sessionId: "test-1",
      displayName: "Auth feature",
      timestamp: Date(),
      projectPath: "/Users/test/app",
      messageCount: 5
    )
    let session2 = Session(
      id: "session-2",
      sessionId: "test-2",
      displayName: "API endpoint",
      timestamp: Date(),
      projectPath: "/Users/test/api",
      messageCount: 3
    )

    index.indexSession(session1, messages: ["Login"])
    index.indexSession(session2, messages: ["GET /users"])

    XCTAssertEqual(index.count, 2)
  }

  // MARK: - search Tests

  func testSearchEmptyQuery() {
    var index = SearchIndex()
    let session = Session(
      id: "session-1",
      sessionId: "test-1",
      displayName: "Test",
      timestamp: Date(),
      projectPath: "/test"
    )
    index.indexSession(session, messages: ["Hello"])

    let results = index.search("")
    XCTAssertTrue(results.isEmpty)
  }

  func testSearchByDisplayName() {
    var index = SearchIndex()
    let session = Session(
      id: "session-1",
      sessionId: "test-1",
      displayName: "Build authentication feature",
      timestamp: Date(),
      projectPath: "/test"
    )
    index.indexSession(session, messages: ["Add login"])

    let results = index.search("authentication")
    XCTAssertEqual(results.count, 1)
    XCTAssertTrue(results.contains("session-1"))
  }

  func testSearchByProjectPath() {
    var index = SearchIndex()
    let session = Session(
      id: "session-1",
      sessionId: "test-1",
      displayName: "Feature",
      timestamp: Date(),
      projectPath: "/Users/test/my-app"
    )
    index.indexSession(session, messages: ["Work"])

    let results = index.search("my-app")
    XCTAssertEqual(results.count, 1)
    XCTAssertTrue(results.contains("session-1"))
  }

  func testSearchByRepoName() {
    var index = SearchIndex()
    let session = Session(
      id: "session-1",
      sessionId: "test-1",
      displayName: "Feature",
      timestamp: Date(),
      projectPath: "/test",
      gitRepoName: "awesome-project"
    )
    index.indexSession(session, messages: ["Work"])

    let results = index.search("awesome-project")
    XCTAssertEqual(results.count, 1)
    XCTAssertTrue(results.contains("session-1"))
  }

  func testSearchByBranch() {
    var index = SearchIndex()
    let session = Session(
      id: "session-1",
      sessionId: "test-1",
      displayName: "Feature",
      timestamp: Date(),
      projectPath: "/test",
      gitBranch: "feature/auth"
    )
    index.indexSession(session, messages: ["Work"])

    let results = index.search("auth")
    XCTAssertEqual(results.count, 1)
    XCTAssertTrue(results.contains("session-1"))
  }

  func testSearchByMessageContent() {
    var index = SearchIndex()
    let session = Session(
      id: "session-1",
      sessionId: "test-1",
      displayName: "API",
      timestamp: Date(),
      projectPath: "/test"
    )
    index.indexSession(session, messages: ["Implement OAuth2 login with Google"])

    let results = index.search("OAuth2")
    XCTAssertEqual(results.count, 1)
    XCTAssertTrue(results.contains("session-1"))
  }

  func testSearchCaseInsensitive() {
    var index = SearchIndex()
    let session = Session(
      id: "session-1",
      sessionId: "test-1",
      displayName: "Build Authentication Feature",
      timestamp: Date(),
      projectPath: "/Users/TEST/My-App"
    )
    index.indexSession(session, messages: ["Implement OAuth"])

    // All should find the session
    XCTAssertTrue(index.search("authentication").contains("session-1"))
    XCTAssertTrue(index.search("AUTHENTICATION").contains("session-1"))
    XCTAssertTrue(index.search("test").contains("session-1"))
    XCTAssertTrue(index.search("oauth").contains("session-1"))
    XCTAssertTrue(index.search("OAUTH").contains("session-1"))
  }

  func testSearchMultipleResults() {
    var index = SearchIndex()
    let session1 = Session(
      id: "session-1",
      sessionId: "test-1",
      displayName: "Authentication feature",
      timestamp: Date(),
      projectPath: "/test/app1"
    )
    let session2 = Session(
      id: "session-2",
      sessionId: "test-2",
      displayName: "API authentication",
      timestamp: Date(),
      projectPath: "/test/app2"
    )
    let session3 = Session(
      id: "session-3",
      sessionId: "test-3",
      displayName: "Database schema",
      timestamp: Date(),
      projectPath: "/test/app3"
    )

    index.indexSession(session1, messages: ["Add login"])
    index.indexSession(session2, messages: ["Add OAuth"])
    index.indexSession(session3, messages: ["Create table"])

    let results = index.search("authentication")
    XCTAssertEqual(results.count, 2)
    XCTAssertTrue(results.contains("session-1"))
    XCTAssertTrue(results.contains("session-2"))
    XCTAssertFalse(results.contains("session-3"))
  }

  func testSearchNoMatch() {
    var index = SearchIndex()
    let session = Session(
      id: "session-1",
      sessionId: "test-1",
      displayName: "Authentication",
      timestamp: Date(),
      projectPath: "/test"
    )
    index.indexSession(session, messages: ["Add login"])

    let results = index.search("database")
    XCTAssertTrue(results.isEmpty)
  }

  func testSearchPartialMatch() {
    var index = SearchIndex()
    let session = Session(
      id: "session-1",
      sessionId: "test-1",
      displayName: "Authentication feature",
      timestamp: Date(),
      projectPath: "/test"
    )
    index.indexSession(session, messages: ["Implement"])

    let results = index.search("auth")
    XCTAssertEqual(results.count, 1)
  }

  // MARK: - clear Tests

  func testClear() {
    var index = SearchIndex()
    let session = Session(
      id: "session-1",
      sessionId: "test-1",
      displayName: "Test",
      timestamp: Date(),
      projectPath: "/test"
    )

    index.indexSession(session, messages: ["Message"])
    XCTAssertEqual(index.count, 1)

    index.clear()
    XCTAssertEqual(index.count, 0)

    let results = index.search("test")
    XCTAssertTrue(results.isEmpty)
  }

  // MARK: - count Tests

  func testCount() {
    var index = SearchIndex()
    XCTAssertEqual(index.count, 0)

    let session1 = Session(
      id: "session-1",
      sessionId: "test-1",
      displayName: "Test 1",
      timestamp: Date(),
      projectPath: "/test"
    )
    let session2 = Session(
      id: "session-2",
      sessionId: "test-2",
      displayName: "Test 2",
      timestamp: Date(),
      projectPath: "/test"
    )

    index.indexSession(session1, messages: ["A"])
    XCTAssertEqual(index.count, 1)

    index.indexSession(session2, messages: ["B"])
    XCTAssertEqual(index.count, 2)
  }

  // MARK: - Sendable Conformance Tests

  func testSearchIndexIsSendable() {
    // This test verifies SearchIndex conforms to Sendable
    // If it compiles, the conformance is valid
    let index = SearchIndex()
    let session = Session(
      id: "session-1",
      sessionId: "test-1",
      displayName: "Test",
      timestamp: Date(),
      projectPath: "/test"
    )
    index.indexSession(session, messages: ["Test"])

    // Test passing across concurrency boundary
    Task.detached {
      _ = index
      _ = index.search("test")
    }
  }
}

extension SearchIndexTests {
  static let allTests = [
    ("testInitDefault", testInitDefault),
    ("testInitCustomMaxMessages", testInitCustomMaxMessages),
    ("testIndexSessionBasic", testIndexSessionBasic),
    ("testIndexSessionWithMultipleMessages", testIndexSessionWithMultipleMessages),
    ("testIndexSessionWithGitInfo", testIndexSessionWithGitInfo),
    ("testIndexSessionMultiple", testIndexSessionMultiple),
    ("testSearchEmptyQuery", testSearchEmptyQuery),
    ("testSearchByDisplayName", testSearchByDisplayName),
    ("testSearchByProjectPath", testSearchByProjectPath),
    ("testSearchByRepoName", testSearchByRepoName),
    ("testSearchByBranch", testSearchByBranch),
    ("testSearchByMessageContent", testSearchByMessageContent),
    ("testSearchCaseInsensitive", testSearchCaseInsensitive),
    ("testSearchMultipleResults", testSearchMultipleResults),
    ("testSearchNoMatch", testSearchNoMatch),
    ("testSearchPartialMatch", testSearchPartialMatch),
    ("testClear", testClear),
    ("testCount", testCount),
    ("testSearchIndexIsSendable", testSearchIndexIsSendable),
  ]
}
