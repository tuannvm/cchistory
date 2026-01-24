import AppKit
import SwiftUI

@main
struct CCHistory: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

  var body: some Scene {
    // Empty - no SwiftUI scenes needed, all UI is in AppDelegate
  }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSSearchFieldDelegate {
  // MARK: - Configuration

  /// Maximum number of sessions to display in the menu at once
  private static let maxSessionsToDisplay = 10
  /// Maximum number of search results to show when filtering
  private static let maxSearchResults = 10
  /// Number of sessions to load for the search index (should be > maxSessionsToDisplay for good search coverage)
  private static let sessionsForSearchIndex = 200

  // MARK: - Properties

  var statusItem: NSStatusItem?
  var historyParser = HistoryParser()
  var sessions: [Session] = []
  var currentSortOption: SessionSortOption = .mostRecent
  private var settingsWindow: SettingsWindow?

  // Web server and file monitoring
  private var webServer: WebServer?
  private var fileMonitor: FileMonitor?

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

  // MARK: - NSApplicationDelegate

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

    // Register web server defaults
    UserDefaults.standard.register(defaults: [
      "webServerPort": 8000,
      "webServerEnabled": false,
    ])

    // Initialize web server
    webServer = WebServer()

    // Start server only if enabled in settings
    if UserDefaults.standard.bool(forKey: "webServerEnabled") {
      Task {
        await self.startWebServer()
      }
    }

    // Setup file monitoring for session changes
    setupFileMonitoring()

    // Trigger initial async load
    loadSessionsAsync()
    // Build menu immediately to show loading indicator
    buildMenu()

    // Refresh menu every 30 seconds
    Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
      Task { @MainActor in
        self?.refreshMenu()
      }
    }
  }

  // MARK: - File Monitoring

  private func setupFileMonitoring() {
    let projectsPath = "\(historyParser.path)/projects"
    fileMonitor = FileMonitor(path: projectsPath) { [weak self] in
      guard let self = self else { return }

      // Invalidate cache and reload
      self.cacheInvalidated = true
      self.loadSessionsAsync()

      // Broadcast to web clients if server is running
      if self.webServer?.isRunning == true {
        self.webServer?.broadcastSessionChange()
      }
    }
  }

  private func refreshFileMonitoring() {
    fileMonitor?.stopMonitoring()
    fileMonitor = nil
    setupFileMonitoring()
  }

  func applicationDidBecomeActive(_ notification: Notification) {
    // Invalidate cache when app becomes active (user may have new sessions)
    cacheInvalidated = true
  }

  // MARK: - Private Methods

  private func loadSessionsAsync() {
    guard !isLoading else { return }

    isLoading = true

    let sortOption = currentSortOption
    let searchIndexLimit = Self.sessionsForSearchIndex

    // Get custom path from settings to respect user configuration
    let claudePathKey = "claudeProjectsPath"
    let customPath = UserDefaults.standard.string(forKey: claudePathKey)

    Task(priority: .userInitiated) {
      // Run parsing off the main actor
      // Note: We fetch more sessions for search index (sessionsForSearchIndex) but display fewer (maxSessionsToDisplay)
      let parseResult = await Task.detached {
        let parser = HistoryParser(claudePath: customPath)
        return parser.getSessionsWithIndex(sortOption: sortOption, limit: searchIndexLimit)
      }.value

      // Update UI on main actor
      await MainActor.run { [weak self] in
        guard let self = self else { return }
        self.cachedSessions = parseResult.sessions
        self.cachedSearchIndex = parseResult.searchIndex
        self.sessions = parseResult.sessions
        self.isLoading = false
        self.cacheInvalidated = false

        // Update shared cache for web server
        SessionCache.shared.update(parseResult.sessions, searchIndex: parseResult.searchIndex)

        var messageDetailsBySessionId: [String: [SessionMessage]] = [:]
        for parsedSession in parseResult.parsedSessions {
          messageDetailsBySessionId[parsedSession.session.id] = parsedSession.messageDetails
        }
        SessionCache.shared.updateMessageDetails(messageDetailsBySessionId)

        self.buildMenu()
      }
    }
  }

  func buildMenu() {
    guard let statusItem = statusItem else { return }

    let menu = NSMenu()

    // Add search field at the top
    let searchField = NSSearchField(frame: NSRect(x: 0, y: 0, width: 250, height: 24))
    searchField.placeholderString = "Search..."
    searchField.stringValue = currentSearchQuery
    searchField.delegate = self
    searchField.target = self
    searchField.action = #selector(searchFieldAction(_:))

    let searchViewItem = NSMenuItem()
    searchViewItem.view = searchField
    menu.addItem(searchViewItem)

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

    // Filter sessions based on search query - max 10 results
    let sessionsToDisplay: [Session]
    if isLoading && cachedSessions.isEmpty {
      // Show loading indicator
      let loadingItem = NSMenuItem(title: "Loading...", action: nil, keyEquivalent: "")
      loadingItem.isEnabled = false
      menu.addItem(loadingItem)
      sessionsToDisplay = []
    } else if cacheInvalidated && !isLoading {
      // Cache invalidated but not loading, trigger load and use stale cache
      sessionsToDisplay = Array(cachedSessions.prefix(Self.maxSessionsToDisplay))
      loadSessionsAsync()
    } else {
      // Apply search filter with configurable limits
      if currentSearchQuery.isEmpty {
        sessionsToDisplay = Array(cachedSessions.prefix(Self.maxSessionsToDisplay))
      } else if let searchIndex = cachedSearchIndex {
        let matchingIds = searchIndex.search(currentSearchQuery)
        sessionsToDisplay = cachedSessions.filter { matchingIds.contains($0.id) }.prefix(Self.maxSearchResults).map { $0 }
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

  // MARK: - Actions

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

  @objc func showAboutDialog() {
    if let url = URL(string: "https://github.com/tuannvm/cchistory") {
      NSWorkspace.shared.open(url)
    }
  }

  @objc func openSettings() {
    if settingsWindow == nil {
      settingsWindow = SettingsWindow()
      settingsWindow?.onPathChanged = { [weak self] newPath in
        self?.handlePathChanged(newPath)
      }
      settingsWindow?.onWebServerToggled = { [weak self] isEnabled, port in
        self?.handleWebServerSettingsChanged(isEnabled: isEnabled, port: port)
      }
      settingsWindow?.onRequestWebServerURL = { [weak self] in
        self?.webServerURL?.absoluteString
      }
      settingsWindow?.onRequestWebServerStatus = { [weak self] in
        self?.webServer?.statusDescription
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

    // Restart file monitoring with new path
    refreshFileMonitoring()

    // Invalidate cache and reload
    cacheInvalidated = true
    loadSessionsAsync()
  }

  private func handleWebServerSettingsChanged(isEnabled: Bool, port: UInt16) {
    Task { @MainActor in
      if isWebServerRunning {
        await stopWebServer()
      }

      if isEnabled {
        await startWebServer()
      }

      settingsWindow?.loadSavedPath()
    }
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

    // Show copy feedback
    showCopyFeedback(for: sessionToCopy)
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

  @objc func quit() {
    NSApplication.shared.terminate(nil)
  }

  // MARK: - NSSearchFieldDelegate

  func controlTextDidChange(_ obj: Notification) {
    guard let searchField = obj.object as? NSSearchField else { return }
    currentSearchQuery = searchField.stringValue
  }

  @objc func searchFieldAction(_ sender: NSSearchField) {
    // Handle cancel button click in search field
    if sender.stringValue.isEmpty {
      currentSearchQuery = ""
    }
  }
}

// MARK: - Supporting Types

/// Custom NSMenuItem that stores session data
final class SessionMenuItem: NSMenuItem {
  let session: Session?

  init(session: Session, isCopied: Bool = false) {
    self.session = session

    let displayName = session.cleanedDisplayName
    let repoName = session.repoName

    let title: String
    if isCopied {
      title = "Copied — \(displayName)"
    } else {
      title = "\(displayName) — \(repoName)"
    }

    super.init(title: title, action: nil, keyEquivalent: "")

    let tooltip = """
      Session: \(displayName)
      Repository: \(repoName)
      Branch: \(session.gitBranch ?? "N/A")
      Time: \(session.formattedRelativeDate) (\(session.messageCount) messages)

      Click to copy resume command
      """
    self.toolTip = tooltip

    // Add visual feedback for copied state using system accent color
    if isCopied {
      self.attributedTitle = NSAttributedString(
        string: title,
        attributes: [
          .foregroundColor: NSColor.controlAccentColor,
          .font: NSFont.systemFont(ofSize: 13),
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

// MARK: - Web Server Control

@MainActor
extension AppDelegate {
  /// Whether the web server is currently running
  var isWebServerRunning: Bool {
    webServer?.isRunning ?? false
  }

  /// The URL of the web server (if running)
  var webServerURL: URL? {
    guard isWebServerRunning else { return nil }
    return webServer?.serverURL
  }

  /// Start the web server
  func startWebServer() async {
    print("[AppDelegate] startWebServer called, webServer is nil: \(webServer == nil)")
    do {
      try await webServer?.start()
      print("[AppDelegate] Web server started, isRunning: \(webServer?.isRunning ?? false)")
      settingsWindow?.loadSavedPath()
    } catch {
      print("[AppDelegate] Failed to start web server: \(error)")
      webServer?.recordStartError(error)

      // Show error alert
      let alert = NSAlert()
      alert.messageText = "Failed to Start Web Server"
      alert.informativeText = "Error: \(error.localizedDescription)\n\nPlease check if port \(webServer?.port ?? 8000) is already in use."
      alert.alertStyle = .critical
      alert.addButton(withTitle: "OK")
      alert.runModal()

      settingsWindow?.loadSavedPath()
    }
  }

  /// Stop the web server
  func stopWebServer() async {
    await webServer?.stop()
    print("[AppDelegate] Web server stopped")
  }
}
