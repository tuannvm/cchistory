import Foundation

/// Shared cache for session data, accessible by both menu bar UI and web server.
/// Uses @MainActor to ensure thread-safe access from the main thread.
@MainActor
final class SessionCache {
  /// Singleton instance for app-wide access
  static let shared = SessionCache()

  /// Cached sessions from the most recent parse
  private var cachedSessions: [Session] = []

  /// Cached search index for fast lookups
  private var cachedSearchIndex: SearchIndex?

  /// Cached message details by session ID
  private var cachedMessageDetails: [String: [SessionMessage]] = [:]

  /// Private initializer for singleton pattern
  private init() {}

  /// Update the cache with new session data and search index
  /// - Parameters:
  ///   - sessions: The parsed sessions to cache
  ///   - searchIndex: The search index built from the sessions
  func update(_ sessions: [Session], searchIndex: SearchIndex) {
    cachedSessions = sessions
    cachedSearchIndex = searchIndex
  }

  /// Update message details for sessions
  /// - Parameter messageDetails: Dictionary keyed by session ID
  func updateMessageDetails(_ messageDetails: [String: [SessionMessage]]) {
    cachedMessageDetails = messageDetails
  }

  /// Get all cached sessions
  /// - Returns: Array of all sessions
  func getAllSessions() -> [Session] {
    return cachedSessions
  }

  /// Get a specific session by ID
  /// - Parameter id: The session's unique identifier
  /// - Returns: The session if found, nil otherwise
  func getSession(id: String) -> Session? {
    return cachedSessions.first { $0.id == id }
  }

  /// Search sessions using the cached search index
  /// - Parameter query: The search query string
  /// - Returns: Array of sessions matching the query
  func searchSessions(_ query: String) -> [Session] {
    guard let searchIndex = cachedSearchIndex else { return [] }
    let matchingIds = searchIndex.search(query)
    return cachedSessions.filter { matchingIds.contains($0.id) }
  }

  /// Get message details for a specific session ID
  /// - Parameter id: The session's unique identifier
  /// - Returns: Messages if found, empty array otherwise
  func getMessages(id: String) -> [SessionMessage] {
    return cachedMessageDetails[id] ?? []
  }

  /// Clear all cached data
  func clear() {
    cachedSessions = []
    cachedSearchIndex = nil
    cachedMessageDetails = [:]
  }
}
