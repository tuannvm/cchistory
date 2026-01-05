import SwiftUI
import AppKit
import UserNotifications

@main
struct CCHistory: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var historyParser = HistoryParser()
    var sessions: [Session] = []
    var currentSortOption: SessionSortOption = .mostActive

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create menu bar status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "message.circle", accessibilityDescription: "Claude History")
            button.image?.isTemplate = true
        }

        buildMenu()

        // Refresh menu every 30 seconds
        Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.refreshMenu()
        }
    }

    func buildMenu() {
        guard let statusItem = statusItem else { return }

        let menu = NSMenu()

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

        // Load sessions with current sort option
        sessions = historyParser.getSessions(sortOption: currentSortOption, limit: 10)

        if sessions.isEmpty {
            let noSessionsItem = NSMenuItem(title: "No sessions found", action: nil, keyEquivalent: "")
            noSessionsItem.isEnabled = false
            menu.addItem(noSessionsItem)
        } else {
            // Add each session
            for (index, session) in sessions.enumerated() {
                let menuItem = SessionMenuItem(session: session)
                menuItem.tag = index
                menuItem.action = #selector(sessionClicked(_:))
                menuItem.target = self
                menu.addItem(menuItem)
            }
        }

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
        let refreshItem = NSMenuItem(title: "Refresh", action: #selector(refreshMenu), keyEquivalent: "r")
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
           let newOption = SessionSortOption.allCases.element(at: index) {
            currentSortOption = newOption
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

    @objc func refreshMenu() {
        buildMenu()
    }

    @objc func sessionClicked(_ sender: NSMenuItem) {
        guard let sessionItem = sender as? SessionMenuItem,
              let session = sessionItem.session else {
            return
        }

        copyResumeCommand(for: session)
        showNotification(for: session)
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
}

/// Custom NSMenuItem that stores session data
final class SessionMenuItem: NSMenuItem {
    let session: Session?

    init(session: Session) {
        self.session = session

        let repoName = session.repoName
        let branch = session.gitBranch.map { " [\($0)]" } ?? ""
        let count = session.messageCount
        let timeAgo = session.formattedRelativeDate
        let displayName = session.cleanedDisplayName

        super.init(title: "\(repoName): \(displayName)\(branch) • \(timeAgo) (\(count) msgs)", action: nil, keyEquivalent: "")

        let tooltip = """
        Project: \(session.projectPath.isEmpty ? "None" : session.projectPath)
        Session: \(displayName)
        Time: \(session.formattedDate)
        Messages: \(count)
        Branch: \(session.gitBranch ?? "N/A")

        Click to copy resume command
        """
        self.toolTip = tooltip
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
            let escapedPath = projectPath
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
