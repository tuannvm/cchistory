import Foundation
import CryptoKit

/// Parses Claude Code sessions from ~/.claude/projects/
final class HistoryParser {

  private let claudePath: String
  private let fileManager = FileManager.default

  /// The Claude base path (read-only accessor)
  var path: String { claudePath }

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
    var parsedSessions: [ParsedSession]
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
      return ParseResult(sessions: [], searchIndex: SearchIndex(), parsedSessions: [])
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

      // Extract project path from directory name (fallback only)
      // Note: The actual path is read from the session file's "cwd" field.
      // This decoding is only used as a fallback if cwd is not available.
      let projectPath = projectDir.replacingOccurrences(of: "-", with: "/")

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

    return ParseResult(sessions: sessions, searchIndex: searchIndex, parsedSessions: parsedSessions)
  }

  /// Parse result containing session and searchable messages
  struct ParsedSession: Sendable {
    let session: Session
    let messages: [String]
    let messageDetails: [SessionMessage]
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
    var messageDetails: [SessionMessage] = []
    var hasCapturedSummary = false
    var actualProjectPath: String?

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

      // Extract actual project path from "cwd" field in user messages
      if actualProjectPath == nil, let cwd = json["cwd"] as? String, !cwd.isEmpty {
        actualProjectPath = cwd
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
        var messageTimestamp: Date?

        switch type {
        case "user":
          // Handle both old format (content directly) and new format (nested in message object)
          if let content = json["content"] as? String {
            messageContent = content
          } else if let message = json["message"] as? [String: Any],
                    let content = message["content"] as? String {
            messageContent = content
          }
          // Also check for timestamp from user messages
          if let timestampStr = json["timestamp"] as? String {
            if let date = formatter.date(from: timestampStr) {
              messageTimestamp = date
              let timestamp = date.timeIntervalSince1970
              if timestamp > latestTimestamp {
                latestTimestamp = timestamp
              }
            }
            messageCount += 1
          }
        case "assistant":
          // Handle both old format (content with text) and new format (nested in message object)
          if let content = json["content"] as? [String: Any],
             let text = content["text"] as? String {
            messageContent = text
          } else if let message = json["message"] as? [String: Any],
                    let content = message["content"] {
            // New format: content is an array of content blocks
            if let contentArray = content as? [[String: Any]] {
              // Extract text from content blocks
              var texts: [String] = []
              for block in contentArray {
                if let text = block["text"] as? String {
                  texts.append(text)
                } else if let type = block["type"] as? String, type == "thinking",
                          let thinking = block["thinking"] as? String {
                  texts.append("[Thinking: \(thinking)]")
                }
              }
              if !texts.isEmpty {
                messageContent = texts.joined(separator: "\n")
              }
            } else if let text = content as? String {
              // Fallback for string content
              messageContent = text
            }
          }

          // Check timestamp from assistant messages
          if let timestampStr = json["timestamp"] as? String {
            if let date = formatter.date(from: timestampStr) {
              messageTimestamp = date
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
          messageDetails.append(
            SessionMessage(
              role: type,
              content: msg,
              timestamp: messageTimestamp
            )
          )
        }
      }
    }

    // If we have a summary or timestamp, create a session
    guard let summary = summary, latestTimestamp > 0 else {
      return nil
    }

    // Use actual path from session file if available, otherwise fall back to decoded path
    let finalProjectPath = actualProjectPath ?? projectPath

    // Create a stable ID from the session file path so it remains consistent across parses
    // This ensures the SessionCache can reliably look up messages by session ID
    let stableId = path.data(using: .utf8).map { data in
      let hash = SHA256.hash(data: data)
      return String(Data(hash).base64EncodedString()
        .replacingOccurrences(of: "/", with: "-")
        .replacingOccurrences(of: "+", with: "_")
        .prefix(32))
    } ?? UUID().uuidString

    let session = Session(
      id: stableId,
      sessionId: sessionId,
      displayName: summary,
      timestamp: Date(timeIntervalSince1970: latestTimestamp),
      projectPath: finalProjectPath,
      messageCount: max(1, messageCount)
    )

    return ParsedSession(session: session, messages: messages, messageDetails: messageDetails)
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

    let limitedSessions = Array(allSessions.prefix(limit))
    let limitedIds = Set(limitedSessions.map { $0.id })
    parseResult.sessions = limitedSessions
    parseResult.parsedSessions = parseResult.parsedSessions.filter { limitedIds.contains($0.session.id) }
    return parseResult
  }

  /// Get sessions sorted by most messages (original behavior)
  func getActiveSessions(limit: Int = 10) -> [Session] {
    return getSessions(sortOption: .mostActive, limit: limit)
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
