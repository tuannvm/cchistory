import Foundation

/// Sorting options for sessions
enum SessionSortOption: String, CaseIterable, Sendable {
  case mostActive = "Most Active"
  case mostRecent = "Most Recent"
  case lastHour = "Last Hour"
  case lastDay = "Last 24 Hours"
  case lastWeek = "Last Week"
  case allTime = "All Time"

  var keyEquivalent: String {
    switch self {
    case .mostActive: return "1"
    case .mostRecent: return "2"
    case .lastHour: return "3"
    case .lastDay: return "4"
    case .lastWeek: return "5"
    case .allTime: return "6"
    }
  }
}

/// Time filter for sessions
enum TimeFilter: TimeInterval, Sendable {
  case lastHour = 3600  // 1 hour
  case lastDay = 86400  // 24 hours
  case lastWeek = 604800  // 7 days
  case allTime = 0  // No filter

  var displayName: String {
    switch self {
    case .lastHour: return "Last Hour"
    case .lastDay: return "Last 24 Hours"
    case .lastWeek: return "Last Week"
    case .allTime: return "All Time"
    }
  }
}

/// Represents a single Claude Code session
struct Session: Identifiable, Codable, Sendable, Equatable {
  let id: String
  let sessionId: String  // Claude Code session ID for resuming
  let displayName: String
  var timestamp: Date
  let projectPath: String
  var messageCount: Int = 0
  var gitBranch: String?
  var gitRepoName: String?

  var formattedDate: String {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .short
    return formatter.string(from: timestamp)
  }

  var formattedRelativeDate: String {
    let now = Date()
    let interval = now.timeIntervalSince(timestamp)

    if interval < 60 {
      return "just now"
    } else if interval < 3600 {
      let minutes = Int(interval / 60)
      return "\(minutes)m ago"
    } else if interval < 86400 {
      let hours = Int(interval / 3600)
      return "\(hours)h ago"
    } else if interval < 604800 {
      let days = Int(interval / 86400)
      return "\(days)d ago"
    } else {
      let formatter = DateFormatter()
      formatter.dateStyle = .short
      return formatter.string(from: timestamp)
    }
  }

  var repoName: String {
    if let gitRepoName = gitRepoName {
      return gitRepoName
    }
    return (projectPath as NSString).lastPathComponent
  }

  /// Returns a cleaned display name for the session
  var cleanedDisplayName: String {
    let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)

    // Check if it's a placeholder or command-like name
    let isCommand =
      name.hasPrefix("/") || name.hasPrefix("[") || name.isEmpty || name == "Untitled Session"

    if isCommand {
      return "Unnamed Session"
    }

    // Truncate very long names
    if name.count > 50 {
      return String(name.prefix(47)) + "..."
    }

    return name
  }

  /// Check if session falls within a time filter
  func matchesTimeFilter(_ filter: TimeFilter) -> Bool {
    guard filter != .allTime else { return true }

    let now = Date()
    let cutoff = now.addingTimeInterval(-filter.rawValue)
    return timestamp >= cutoff
  }
}
