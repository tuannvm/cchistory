import Foundation

/// Parses Claude Code sessions from ~/.claude/projects/
final class HistoryParser {

  private let claudePath: String
  private let fileManager = FileManager.default

  init(claudePath: String? = nil) {
    // Use provided path or default to ~/.claude
    if let providedPath = claudePath {
      // Validate custom path for security
      let dangerousCharacters = CharacterSet(charactersIn: "$`;\\;&|()\n\r\t")
      if providedPath.rangeOfCharacter(from: dangerousCharacters) != nil {
        // Fall back to default path if invalid characters detected
        self.claudePath = "\(NSHomeDirectory())/.claude"
      } else {
        // Resolve path to prevent traversal attacks
        let standardizedPath = (providedPath as NSString).standardizingPath
        self.claudePath = standardizedPath
      }
    } else {
      self.claudePath = "\(NSHomeDirectory())/.claude"
    }
  }

  /// Parse result containing sessions and search index
  struct ParseResult: Sendable {
    var sessions: [Session]
    var searchIndex: SearchIndex
  }

  /// Parse sessions from project directories
  func parseSessionsFromProjects() -> [Session] {
    return parseSessionsWithIndex().sessions
  }

  /// Parse sessions from project directories with search index
  func parseSessionsWithIndex() -> ParseResult {
    let projectsPath = "\(claudePath)/projects"
    guard let projectDirs = try? fileManager.contentsOfDirectory(atPath: projectsPath) else {
      print("Failed to list projects directory")
      return ParseResult(sessions: [], searchIndex: SearchIndex())
    }

    var parsedSessions: [ParsedSession] = []
    var searchIndex = SearchIndex()

    for projectDir in projectDirs {
      // Skip hidden files
      if projectDir.hasPrefix(".") { continue }

      let projectSessionDir = "\(projectsPath)/\(projectDir)"
      guard let sessionFiles = try? fileManager.contentsOfDirectory(atPath: projectSessionDir)
      else {
        continue
      }

      // Extract project path from directory name (unescape)
      // Encoding: "-" replaces "/" in paths
      // Hidden directories (like .config) lose their leading dot, creating "//" when decoded
      // We fix this specific pattern by restoring dots after double slashes
      // Note: This doesn't fix hyphens in directory names - that requires knowing the actual encoding scheme
      let projectPath = projectDir
        .replacingOccurrences(of: "-", with: "/")
        .replacingOccurrences(of: "//", with: "/.")

      for sessionFile in sessionFiles {
        // Only process .jsonl session files
        guard sessionFile.hasSuffix(".jsonl") else { continue }

        let sessionFilePath = "\(projectSessionDir)/\(sessionFile)"

        // Extract session ID from filename (remove .jsonl extension)
        let sessionId = String(sessionFile.dropLast(6))

        // Parse session file to get summary, timestamp, and messages
        if let parsedSession = parseSessionFile(
          path: sessionFilePath, sessionId: sessionId, projectPath: projectPath)
        {
          parsedSessions.append(parsedSession)
        }
      }
    }

    // Build sessions array and search index
    var sessions: [Session] = []
    for parsedSession in parsedSessions {
      sessions.append(parsedSession.session)
      searchIndex.indexSession(parsedSession.session, messages: parsedSession.messages)
    }

    return ParseResult(sessions: sessions, searchIndex: searchIndex)
  }

  /// Parse result containing session and searchable messages
  struct ParsedSession: Sendable {
    let session: Session
    let messages: [String]
  }

  /// Parse a single session file to extract summary and metadata
  func parseSessionFile(path: String, sessionId: String, projectPath: String) -> ParsedSession? {
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
      let content = String(data: data, encoding: .utf8)
    else {
      return nil
    }

    var summary: String?
    var latestTimestamp: TimeInterval = 0
    var messageCount = 0
    var messages: [String] = []
    var hasCapturedSummary = false

    // Custom date formatter for ISO8601 with fractional seconds
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
    formatter.timeZone = TimeZone(secondsFromGMT: 0)

    let lines = content.components(separatedBy: .newlines)
    for line in lines where !line.isEmpty {
      guard let lineData = line.data(using: .utf8),
        let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any]
      else {
        continue
      }

      // Extract summary from "summary" entries
      if let type = json["type"] as? String, type == "summary",
        let summaryText = json["summary"] as? String
      {
        if !hasCapturedSummary {
          summary = summaryText
          hasCapturedSummary = true
        }
      }

      // Extract message content for search index
      if let type = json["type"] as? String {
        var messageContent: String?

        switch type {
        case "user":
          if let content = json["content"] as? String {
            messageContent = content
          }
          // Also check for timestamp from user messages
          if let timestampStr = json["timestamp"] as? String {
            if let date = formatter.date(from: timestampStr) {
              let timestamp = date.timeIntervalSince1970
              if timestamp > latestTimestamp {
                latestTimestamp = timestamp
              }
            }
            messageCount += 1
          }
        case "assistant":

          if let content = json["content"] as? [String: Any],
            let text = content["text"] as? String
          {
            messageContent = text
          }

          // Check timestamp from assistant messages
          if let timestampStr = json["timestamp"] as? String {
            if let date = formatter.date(from: timestampStr) {
              let timestamp = date.timeIntervalSince1970
              if timestamp > latestTimestamp {
                latestTimestamp = timestamp
              }
            }
          }
        default:
          break
        }

        // Store message content for search indexing
        if let msg = messageContent {
          messages.append(msg)
        }
      }
    }

    // If we have a summary or timestamp, create a session
    guard let summary = summary, latestTimestamp > 0 else {
      return nil
    }

    let session = Session(
      id: UUID().uuidString,
      sessionId: sessionId,
      displayName: summary,
      timestamp: Date(timeIntervalSince1970: latestTimestamp),
      projectPath: projectPath,
      messageCount: max(1, messageCount)
    )

    return ParsedSession(session: session, messages: messages)
  }

  /// Get sessions with specified sorting and filtering
  func getSessions(sortOption: SessionSortOption, limit: Int = 10) -> [Session] {
    var allSessions = parseSessionsFromProjects()

    // Apply time filter if applicable
    let timeFilter: TimeFilter
    switch sortOption {
    case .mostActive, .mostRecent, .allTime:
      timeFilter = .allTime
    case .lastHour:
      timeFilter = .lastHour
    case .lastDay:
      timeFilter = .lastDay
    case .lastWeek:
      timeFilter = .lastWeek
    }

    // Extract git info for each session
    for index in allSessions.indices {
      if !allSessions[index].projectPath.isEmpty {
        if let gitInfo = extractGitInfo(from: allSessions[index].projectPath) {
          allSessions[index].gitBranch = gitInfo.branch
          allSessions[index].gitRepoName = gitInfo.repoName
        }
      }
    }

    // Apply time filter
    if timeFilter != .allTime {
      allSessions = allSessions.filter { $0.matchesTimeFilter(timeFilter) }
    }

    // Sort based on option
    switch sortOption {
    case .mostActive:
      allSessions.sort { first, second in
        if first.messageCount != second.messageCount {
          return first.messageCount > second.messageCount
        }
        return first.timestamp > second.timestamp
      }
    case .mostRecent, .lastHour, .lastDay, .lastWeek, .allTime:
      allSessions.sort { $0.timestamp > $1.timestamp }
    }

    return Array(allSessions.prefix(limit))
  }

  /// Get sessions with specified sorting and filtering, including search index
  func getSessionsWithIndex(sortOption: SessionSortOption, limit: Int = 10) -> ParseResult {
    var parseResult = parseSessionsWithIndex()
    var allSessions = parseResult.sessions

    // Apply time filter if applicable
    let timeFilter: TimeFilter
    switch sortOption {
    case .mostActive, .mostRecent, .allTime:
      timeFilter = .allTime
    case .lastHour:
      timeFilter = .lastHour
    case .lastDay:
      timeFilter = .lastDay
    case .lastWeek:
      timeFilter = .lastWeek
    }

    // Extract git info for each session
    for index in allSessions.indices {
      if !allSessions[index].projectPath.isEmpty {
        if let gitInfo = extractGitInfo(from: allSessions[index].projectPath) {
          allSessions[index].gitBranch = gitInfo.branch
          allSessions[index].gitRepoName = gitInfo.repoName
        }
      }
    }

    // Apply time filter
    if timeFilter != .allTime {
      allSessions = allSessions.filter { $0.matchesTimeFilter(timeFilter) }
    }

    // Sort based on option
    switch sortOption {
    case .mostActive:
      allSessions.sort { first, second in
        if first.messageCount != second.messageCount {
          return first.messageCount > second.messageCount
        }
        return first.timestamp > second.timestamp
      }
    case .mostRecent, .lastHour, .lastDay, .lastWeek, .allTime:
      allSessions.sort { $0.timestamp > $1.timestamp }
    }

    parseResult.sessions = Array(allSessions.prefix(limit))
    return parseResult
  }

  /// Get sessions sorted by most messages (original behavior)
  func getActiveSessions(limit: Int = 10) -> [Session] {
    return getSessions(sortOption: .mostActive, limit: limit)
  }

  private func getHistoryPath() -> String? {
    let path = "\(claudePath)/history.jsonl"
    if fileManager.fileExists(atPath: path) {
      return path
    }

    // Try standard home directory path
    let homePath = ("\(NSHomeDirectory())/.claude/history.jsonl" as NSString).expandingTildeInPath
    if fileManager.fileExists(atPath: homePath) {
      return homePath
    }

    return nil
  }

  /// Extract git repository name and current branch
  private func extractGitInfo(from path: String) -> (repoName: String, branch: String?)? {
    // Validate path doesn't contain shell metacharacters
    let dangerousCharacters = CharacterSet(charactersIn: "$`;\\;&|()\n\r\t")
    if path.rangeOfCharacter(from: dangerousCharacters) != nil {
      return nil
    }

    // Verify path exists and is a directory
    var isDir: ObjCBool = false
    guard fileManager.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else {
      return nil
    }

    // Use git commands directly via Process instead of shell script
    // Check if it's a git repo
    let gitCheck = Process()
    gitCheck.executableURL = URL(fileURLWithPath: "/usr/bin/git")
    gitCheck.arguments = ["-C", path, "rev-parse", "--git-dir"]
    gitCheck.standardError = Pipe()

    do {
      try gitCheck.run()
      gitCheck.waitUntilExit()
      guard gitCheck.terminationStatus == 0 else {
        return nil
      }
    } catch {
      return nil
    }

    // Get remote URL
    let remoteProcess = Process()
    remoteProcess.executableURL = URL(fileURLWithPath: "/usr/bin/git")
    remoteProcess.arguments = ["-C", path, "remote", "get-url", "origin"]
    let remotePipe = Pipe()
    remoteProcess.standardOutput = remotePipe
    remoteProcess.standardError = Pipe()

    var remoteURL = ""
    do {
      try remoteProcess.run()
      remoteProcess.waitUntilExit()

      let data = remotePipe.fileHandleForReading.readDataToEndOfFile()
      if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(
        in: .whitespacesAndNewlines),
        !output.isEmpty
      {
        remoteURL = output
      }
    } catch {
      // Continue without remote
    }

    // Extract repo name from remote or use current directory
    let repoName: String
    if !remoteURL.isEmpty {
      // Handle both .git and non-.git URLs
      let name = (remoteURL as NSString).lastPathComponent
      repoName = name.hasSuffix(".git") ? String(name.dropLast(4)) : name
    } else {
      repoName = (path as NSString).lastPathComponent
    }

    // Get current branch
    let branchProcess = Process()
    branchProcess.executableURL = URL(fileURLWithPath: "/usr/bin/git")
    branchProcess.arguments = ["-C", path, "rev-parse", "--abbrev-ref", "HEAD"]
    let branchPipe = Pipe()
    branchProcess.standardOutput = branchPipe
    branchProcess.standardError = Pipe()

    var branch: String?
    do {
      try branchProcess.run()
      branchProcess.waitUntilExit()

      let data = branchPipe.fileHandleForReading.readDataToEndOfFile()
      if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(
        in: .whitespacesAndNewlines),
        !output.isEmpty, output != "HEAD"
      {
        branch = output
      }
    } catch {
      // Continue without branch
    }

    return (repoName, branch)
  }
}

/// Codable struct for history.jsonl entries (no longer used, kept for reference)
private struct HistoryEntry: Codable {
  let display: String?
  let timestamp: TimeInterval
  let project: String?
}
