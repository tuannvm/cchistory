import AppKit
import SwiftUI
@preconcurrency import UserNotifications

@main
struct CCHistory: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

  var body: some Scene {
    Settings {
      EmptyView()
    }
  }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSSearchFieldDelegate {
  var statusItem: NSStatusItem?
  var historyParser = HistoryParser()
  var sessions: [Session] = []
  var currentSortOption: SessionSortOption = .mostActive
  private var settingsWindow: SettingsWindow?

  // Async loading state
  private var cachedSessions: [Session] = []
  private var cachedSearchIndex: SearchIndex?
  private var isLoading = false
  private var cacheInvalidated = true

  // Search state
  private var currentSearchQuery: String = "" {
    didSet {
      if oldValue != currentSearchQuery {
        buildMenu()
      }
    }
  }

  // Copy feedback state
  private var copiedSessionId: String?
  private var copyFeedbackTimer: Timer?

  func applicationDidFinishLaunching(_ notification: Notification) {
    // Initialize HistoryParser with saved custom path
    let claudePathKey = "claudeProjectsPath"
    let customPath = UserDefaults.standard.string(forKey: claudePathKey)
    historyParser = HistoryParser(claudePath: customPath)

    // Create menu bar status item
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

    if let button = statusItem?.button {
      button.image = NSImage.cchistoryLogo
    }

    // Trigger initial async load
    loadSessionsAsync()

    // Refresh menu every 30 seconds
    Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
      Task { @MainActor in
        self?.refreshMenu()
      }
    }
  }

  func applicationDidBecomeActive(_ notification: Notification) {
    // Invalidate cache when app becomes active (user may have new sessions)
    cacheInvalidated = true
  }

  private func loadSessionsAsync() {
    guard !isLoading else { return }

    isLoading = true

    let sortOption = currentSortOption

    // Get custom path from settings to respect user configuration
    let claudePathKey = "claudeProjectsPath"
    let customPath = UserDefaults.standard.string(forKey: claudePathKey)

    Task(priority: .userInitiated) {
      // Run parsing off the main actor
      // Note: We fetch more sessions for search index (200) but display fewer
      let parseResult = await Task.detached {
        let parser = HistoryParser(claudePath: customPath)
        return parser.getSessionsWithIndex(sortOption: sortOption, limit: 200)
      }.value

      // Update UI on main actor
      await MainActor.run { [weak self] in
        guard let self = self else { return }
        self.cachedSessions = parseResult.sessions
        self.cachedSearchIndex = parseResult.searchIndex
        self.sessions = parseResult.sessions
        self.isLoading = false
        self.cacheInvalidated = false
        self.buildMenu()
      }
    }
  }

  func buildMenu() {
    guard let statusItem = statusItem else { return }

    let menu = NSMenu()

    // Add search field at the top
    let searchField = NSSearchField(frame: NSRect(x: 0, y: 0, width: 250, height: 24))
    searchField.placeholderString = "Search sessions..."
    searchField.stringValue = currentSearchQuery
    searchField.delegate = self
    searchField.target = self

    let searchViewItem = NSMenuItem()
    searchViewItem.view = searchField
    menu.addItem(searchViewItem)

    menu.addItem(NSMenuItem.separator())

    // Header with current sort option
    let headerTitle = "Claude Code History [\(currentSortOption.rawValue)]"
    let headerItem = NSMenuItem(title: headerTitle, action: nil, keyEquivalent: "")
    headerItem.attributedTitle = NSAttributedString(
      string: headerTitle,
      attributes: [.font: NSFont.boldSystemFont(ofSize: 13)]
    )
    menu.addItem(headerItem)
    menu.addItem(NSMenuItem.separator())

    // Sort options submenu
    let sortMenuItem = NSMenuItem(title: "Sort By...", action: nil, keyEquivalent: "")
    let sortMenu = NSMenu()

    for option in SessionSortOption.allCases {
      let item = NSMenuItem(
        title: option.rawValue,
        action: #selector(changeSortOption(_:)),
        keyEquivalent: option.keyEquivalent
      )
      item.target = self
      item.tag = SessionSortOption.allCases.firstIndex(of: option) ?? 0

      // Mark current selection
      if option == currentSortOption {
        item.state = .on
      }

      sortMenu.addItem(item)
    }

    sortMenuItem.submenu = sortMenu
    menu.addItem(sortMenuItem)
    menu.addItem(NSMenuItem.separator())

    // Filter sessions based on search query
    let sessionsToDisplay: [Session]
    if isLoading && cachedSessions.isEmpty {
      // Show loading indicator
      let loadingItem = NSMenuItem(title: "Loading...", action: nil, keyEquivalent: "")
      loadingItem.isEnabled = false
      menu.addItem(loadingItem)
      sessionsToDisplay = []
    } else if cacheInvalidated && !isLoading {
      // Cache invalidated but not loading, trigger load and use stale cache
      sessionsToDisplay = cachedSessions.isEmpty ? [] : cachedSessions
      loadSessionsAsync()
    } else {
      // Apply search filter
      if currentSearchQuery.isEmpty {
        sessionsToDisplay = cachedSessions
      } else if let searchIndex = cachedSearchIndex {
        let matchingIds = searchIndex.search(currentSearchQuery)
        sessionsToDisplay = cachedSessions.filter { matchingIds.contains($0.id) }
      } else {
        sessionsToDisplay = []
      }
    }

    if sessionsToDisplay.isEmpty && !isLoading {
      let noSessionsItem: NSMenuItem
      if currentSearchQuery.isEmpty {
        noSessionsItem = NSMenuItem(title: "No sessions found", action: nil, keyEquivalent: "")
      } else {
        noSessionsItem = NSMenuItem(title: "No matching sessions", action: nil, keyEquivalent: "")
      }
      noSessionsItem.isEnabled = false
      menu.addItem(noSessionsItem)
    } else {
      // Add each session
      for (index, session) in sessionsToDisplay.enumerated() {
        let isCopied = (copiedSessionId == session.id)
        let menuItem = SessionMenuItem(session: session, isCopied: isCopied)
        menuItem.tag = index
        menuItem.action = #selector(sessionClicked(_:))
        menuItem.target = self
        menu.addItem(menuItem)
      }
    }

    menu.addItem(NSMenuItem.separator())

    // Settings button
    let settingsItem = NSMenuItem(
      title: "Settings...",
      action: #selector(openSettings),
      keyEquivalent: ","
    )
    settingsItem.target = self
    menu.addItem(settingsItem)

    menu.addItem(NSMenuItem.separator())

    // About button
    let aboutItem = NSMenuItem(
      title: "About CCHistory",
      action: #selector(showAboutDialog),
      keyEquivalent: ""
    )
    aboutItem.target = self
    menu.addItem(aboutItem)

    menu.addItem(NSMenuItem.separator())

    // LLM Naming info item
    let llmInfoItem = NSMenuItem(
      title: "💡 Tip: Rename unnamed sessions via LLM",
      action: #selector(showLLMNamingHelp),
      keyEquivalent: "?"
    )
    llmInfoItem.target = self
    menu.addItem(llmInfoItem)

    menu.addItem(NSMenuItem.separator())

    // Refresh button
    let refreshItem = NSMenuItem(
      title: "Refresh", action: #selector(refreshMenu), keyEquivalent: "r")
    refreshItem.target = self
    menu.addItem(refreshItem)

    // Quit button
    let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
    quitItem.target = self
    menu.addItem(quitItem)

    statusItem.menu = menu
  }

  @objc func changeSortOption(_ sender: NSMenuItem) {
    if let index = SessionSortOption.allCases.firstIndex(where: { $0.rawValue == sender.title }),
      let newOption = SessionSortOption.allCases.element(at: index)
    {
      currentSortOption = newOption
      // Invalidate cache and reload with new sort option
      cacheInvalidated = true
      loadSessionsAsync()
      buildMenu()
    }
  }

  @objc func showLLMNamingHelp() {
    let alert = NSAlert()
    alert.messageText = "About Session Naming"
    alert.informativeText = """
      Sessions are named automatically from your Claude Code history.

      • If a session has a clear name from your prompts, it will be displayed
      • Command-like entries (/model, /help, etc.) show as "Unnamed Session"
      • Very long names are truncated to 50 characters

      Future Enhancement:
      We plan to add optional LLM-based naming (using local Ollama) to generate
      descriptive names for unnamed sessions based on their conversation content.

      For now, you can identify sessions by their project, branch, and timestamp.
      """
    alert.alertStyle = .informational
    alert.addButton(withTitle: "Got it")
    alert.runModal()
  }

  @objc func showAboutDialog() {
    let alert = NSAlert()
    alert.messageText = "CCHistory"
    alert.informativeText = """
      Claude Code Conversation History Menu Bar App

      Version: 1.0.0
      Website: github.com/tuannvm/cchistory

      CCHistory provides quick access to your Claude Code conversation
      history directly from the menu bar. Click any session to copy its
      resume command to the clipboard.

      Features:
      • Search across session names and message content
      • Sort by activity, recency, or time period
      • Copy resume commands with one click
      • Async loading for optimal performance
      • Custom Claude projects directory support

      © 2024
      """
    alert.alertStyle = .informational
    alert.addButton(withTitle: "OK")

    alert.runModal()
  }

  @objc func openSettings() {
    if settingsWindow == nil {
      settingsWindow = SettingsWindow()
      settingsWindow?.onPathChanged = { [weak self] newPath in
        self?.handlePathChanged(newPath)
      }
    }

    settingsWindow?.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
  }

  private func handlePathChanged(_ newPath: String) {
    // Recreate HistoryParser with new path
    let defaultPath = "\(NSHomeDirectory())/.claude"
    let pathToUse = newPath.isEmpty ? defaultPath : newPath
    historyParser = HistoryParser(claudePath: pathToUse)

    // Invalidate cache and reload
    cacheInvalidated = true
    loadSessionsAsync()
  }

  @objc func refreshMenu() {
    // Invalidate cache and reload
    cacheInvalidated = true
    loadSessionsAsync()
    buildMenu()
  }

  @objc func sessionClicked(_ sender: NSMenuItem) {
    guard let sessionItem = sender as? SessionMenuItem,
      let session = sessionItem.session
    else {
      return
    }

    // Get session from cache to ensure we have the latest data
    let sessionToCopy: Session
    if let cachedSession = cachedSessions.first(where: { $0.id == session.id }) {
      sessionToCopy = cachedSession
    } else {
      sessionToCopy = session
    }

    copyResumeCommand(for: sessionToCopy)

    // Show improved copy feedback
    showCopyFeedback(for: sessionToCopy)

    // Still show notification as fallback (less intrusive)
    // showNotification(for: sessionToCopy)
  }

  private func showCopyFeedback(for session: Session) {
    // Store the copied session ID and rebuild menu to show feedback
    copiedSessionId = session.id

    // Cancel any existing timer
    copyFeedbackTimer?.invalidate()

    // Rebuild menu to show checkmark feedback
    buildMenu()

    // Reset feedback after 1.5 seconds
    copyFeedbackTimer = Timer.scheduledTimer(
      withTimeInterval: 1.5,
      repeats: false
    ) { [weak self] _ in
      Task { @MainActor in
        self?.copiedSessionId = nil
        self?.buildMenu()
      }
    }
  }

  private func copyResumeCommand(for session: Session) {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(session.resumeCommand, forType: .string)
  }

  private func showNotification(for session: Session) {
    let center = UNUserNotificationCenter.current()
    center.requestAuthorization(options: [.alert, .sound]) { granted, error in
      if granted {
        let content = UNMutableNotificationContent()
        content.title = "Resume Command Copied"
        content.body = "Paste in terminal to resume: \(session.cleanedDisplayName)"
        content.sound = .default

        let request = UNNotificationRequest(
          identifier: UUID().uuidString,
          content: content,
          trigger: nil
        )
        center.add(request)
      }
    }
  }

  @objc func quit() {
    NSApplication.shared.terminate(nil)
  }

  // MARK: - NSSearchFieldDelegate

  func controlTextDidChange(_ obj: Notification) {
    guard let searchField = obj.object as? NSSearchField else { return }
    currentSearchQuery = searchField.stringValue
  }
}

/// Custom NSMenuItem that stores session data
final class SessionMenuItem: NSMenuItem {
  let session: Session?

  init(session: Session, isCopied: Bool = false) {
    self.session = session

    let repoName = session.repoName
    let branch = session.gitBranch.map { " [\($0)]" } ?? ""
    let count = session.messageCount
    let timeAgo = session.formattedRelativeDate
    let displayName = session.cleanedDisplayName

    let title: String
    if isCopied {
      title = "✓ Copied: \(repoName): \(displayName)"
    } else {
      title = "\(repoName): \(displayName)\(branch) • \(timeAgo) (\(count) msgs)"
    }

    super.init(title: title, action: nil, keyEquivalent: "")

    let tooltip = """
      Project: \(session.projectPath.isEmpty ? "None" : session.projectPath)
      Session: \(displayName)
      Time: \(session.formattedDate)
      Messages: \(count)
      Branch: \(session.gitBranch ?? "N/A")

      Click to copy resume command
      """
    self.toolTip = tooltip

    // Add visual feedback for copied state
    if isCopied {
      self.attributedTitle = NSAttributedString(
        string: title,
        attributes: [
          .foregroundColor: NSColor.systemGreen,
          .font: NSFont.boldSystemFont(ofSize: 13),
        ]
      )
    }
  }

  required init(coder decoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

extension Session {
  var resumeCommand: String {
    // Use the correct resume format with session ID
    let resumeCmd = "claude --resume \(sessionId)"

    // If project path exists, prepend cd command
    if !projectPath.isEmpty {
      let escapedPath =
        projectPath
        .replacingOccurrences(of: "\"", with: "\\\"")
      return "cd \"\(escapedPath)\" && \(resumeCmd)"
    }

    return resumeCmd
  }
}

// Helper for Array safe element access
extension Array {
  func element(at index: Int) -> Element? {
    return indices.contains(index) ? self[index] : nil
  }
}
