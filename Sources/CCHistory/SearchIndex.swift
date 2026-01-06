import Foundation

/// Search index for fast session lookup
struct SearchIndex: Sendable {
  /// Indexed content for a single session
  struct IndexedSession: Sendable {
    let sessionId: String
    let searchableText: String
  }

  private var indexedSessions: [IndexedSession]

  /// Maximum number of messages per session to index
  private let maxMessagesToIndex: Int

  init(maxMessagesToIndex: Int = 15) {
    self.indexedSessions = []
    self.maxMessagesToIndex = maxMessagesToIndex
  }

  /// Add a session to the search index
  mutating func indexSession(_ session: Session, messages: [String]) {
    var searchableParts: [String] = []

    // Index session name (summary)
    searchableParts.append(session.displayName.lowercased())

    // Index project path
    if !session.projectPath.isEmpty {
      searchableParts.append(session.projectPath.lowercased())
    }

    // Index git repo name if available
    if let repoName = session.gitRepoName {
      searchableParts.append(repoName.lowercased())
    }

    // Index git branch if available
    if let branch = session.gitBranch {
      searchableParts.append(branch.lowercased())
    }

    // Index last N messages (configurable)
    let messagesToIndex = messages.prefix(maxMessagesToIndex)
    for message in messagesToIndex {
      searchableParts.append(message.lowercased())
    }

    let indexedSession = IndexedSession(
      sessionId: session.id,
      searchableText: searchableParts.joined(separator: " ")
    )

    indexedSessions.append(indexedSession)
  }

  /// Search for sessions matching the query (case-insensitive substring search)
  func search(_ query: String) -> Set<String> {
    guard !query.isEmpty else { return [] }

    let lowercasedQuery = query.lowercased()
    var matchingIds: Set<String> = []

    for indexedSession in indexedSessions {
      if indexedSession.searchableText.contains(lowercasedQuery) {
        matchingIds.insert(indexedSession.sessionId)
      }
    }

    return matchingIds
  }

  /// Clear all indexed sessions
  mutating func clear() {
    indexedSessions.removeAll()
  }

  /// Get count of indexed sessions
  var count: Int {
    indexedSessions.count
  }
}
