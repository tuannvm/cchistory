import AppKit
import SwiftUI

/// Custom search field that guarantees click-to-focus behavior
final class ClickToFocusSearchField: NSSearchField {
  override func mouseDown(with event: NSEvent) {
    // Always make this field first responder on click
    window?.makeFirstResponder(self)
    super.mouseDown(with: event)
  }

  override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
    // Accept first mouse even if window isn't key
    return true
  }
}

/// Popover view controller containing search field and session list
@MainActor
final class PopoverViewController: NSViewController {
  private var sessions: [Session] = []
  private var filteredSessions: [Session] = []
  var onSessionClicked: ((Session) -> Void)?
  var onClearSearch: (() -> Void)?
  var onChangeSort: ((SessionSortOption) -> Void)?
  var onOpenSettings: (() -> Void)?
  var onOpenAbout: (() -> Void)?
  var onRefresh: (() -> Void)?

  private let sortOption: SessionSortOption
  private let searchIndex: SearchIndex?
  private var currentSearchQuery: String = ""

  private var scrollView: NSScrollView!
  private var stackView: NSStackView!
  private(set) var searchField: NSSearchField!

  init(sessions: [Session], sortOption: SessionSortOption, searchIndex: SearchIndex?) {
    self.sessions = sessions
    self.sortOption = sortOption
    self.searchIndex = searchIndex
    self.filteredSessions = Array(sessions.prefix(10))
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func loadView() {
    view = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 500))
    view.wantsLayer = true
    view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    setupUI()
  }

  private func setupUI() {
    // Search field at top - configured for proper click handling
    let searchField = ClickToFocusSearchField()
    searchField.placeholderString = "Search sessions..."
    searchField.focusRingType = .default
    searchField.bezelStyle = .roundedBezel
    searchField.isEditable = true
    searchField.isSelectable = true
    searchField.translatesAutoresizingMaskIntoConstraints = false
    searchField.target = self
    searchField.action = #selector(searchChanged(_:))
    view.addSubview(searchField)
    self.searchField = searchField

    // Clear search button (hidden by default)
    let clearButton = NSButton(title: "✕ Clear", target: self, action: #selector(clearSearchClicked))
    clearButton.isBordered = false
    clearButton.focusRingType = .none
    clearButton.translatesAutoresizingMaskIntoConstraints = false
    clearButton.isHidden = true
    view.addSubview(clearButton)

    // Scroll view for session list
    scrollView = NSScrollView()
    scrollView.hasVerticalScroller = true
    scrollView.hasHorizontalScroller = false
    scrollView.drawsBackground = false
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(scrollView)

    // Stack view for sessions
    stackView = NSStackView()
    stackView.orientation = .vertical
    stackView.spacing = 0
    stackView.alignment = .leading
    stackView.translatesAutoresizingMaskIntoConstraints = false
    scrollView.documentView = stackView

    // Bottom action buttons
    let actionsView = createActionsView()
    actionsView.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(actionsView)

    // Layout
    NSLayoutConstraint.activate([
      // Search field
      searchField.topAnchor.constraint(equalTo: view.topAnchor, constant: 12),
      searchField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
      searchField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
      searchField.heightAnchor.constraint(equalToConstant: 24),

      // Clear button
      clearButton.leadingAnchor.constraint(equalTo: searchField.trailingAnchor, constant: 8),
      clearButton.centerYAnchor.constraint(equalTo: searchField.centerYAnchor),

      // Scroll view
      scrollView.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 12),
      scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
      scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
      scrollView.bottomAnchor.constraint(equalTo: actionsView.topAnchor, constant: -12),

      // Stack view width
      stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),

      // Actions view
      actionsView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      actionsView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      actionsView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
    ])

    // Don't auto-focus here - let the panel show first, then focus from outside
    updateSessionList()
  }

  func focusSearchField() {
    searchField?.becomeFirstResponder()
  }

  private func createActionsView() -> NSView {
    let actionsView = NSView()
    actionsView.wantsLayer = true
    actionsView.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

    let refreshButton = NSButton(title: "Refresh", target: self, action: #selector(refreshClicked))
    refreshButton.translatesAutoresizingMaskIntoConstraints = false
    actionsView.addSubview(refreshButton)

    let settingsButton = NSButton(title: "Settings...", target: self, action: #selector(settingsClicked))
    settingsButton.translatesAutoresizingMaskIntoConstraints = false
    actionsView.addSubview(settingsButton)

    let aboutButton = NSButton(title: "About", target: self, action: #selector(aboutClicked))
    aboutButton.translatesAutoresizingMaskIntoConstraints = false
    actionsView.addSubview(aboutButton)

    NSLayoutConstraint.activate([
      refreshButton.leadingAnchor.constraint(equalTo: actionsView.leadingAnchor, constant: 12),
      refreshButton.centerYAnchor.constraint(equalTo: actionsView.centerYAnchor),

      settingsButton.centerXAnchor.constraint(equalTo: actionsView.centerXAnchor),
      settingsButton.centerYAnchor.constraint(equalTo: actionsView.centerYAnchor),

      aboutButton.trailingAnchor.constraint(equalTo: actionsView.trailingAnchor, constant: -12),
      aboutButton.centerYAnchor.constraint(equalTo: actionsView.centerYAnchor),

      actionsView.heightAnchor.constraint(equalToConstant: 44),
    ])

    return actionsView
  }

  func updateSessions(_ sessions: [Session]) {
    self.sessions = sessions
    self.filteredSessions = Array(sessions.prefix(10))
    updateSessionList()
  }

  private func updateSessionList() {
    // Remove all existing views
    for view in stackView.arrangedSubviews {
      stackView.removeArrangedSubview(view)
      view.removeFromSuperview()
    }

    if filteredSessions.isEmpty {
      let emptyLabel = NSTextField(labelWithString: currentSearchQuery.isEmpty ? "No sessions found" : "No matching sessions")
      emptyLabel.alignment = .center
      emptyLabel.textColor = .secondaryLabelColor
      emptyLabel.translatesAutoresizingMaskIntoConstraints = false
      stackView.addArrangedSubview(emptyLabel)
    } else {
      for session in filteredSessions {
        let itemView = createSessionItemView(session: session)
        stackView.addArrangedSubview(itemView)
      }
    }

    stackView.addArrangedSubview(NSView()) // Spacer
  }

  private func createSessionItemView(session: Session) -> NSView {
    let containerView = NSView()
    containerView.wantsLayer = true
    containerView.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
    containerView.translatesAutoresizingMaskIntoConstraints = false

    let repoLabel = NSTextField(labelWithString: session.repoName)
    repoLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
    repoLabel.translatesAutoresizingMaskIntoConstraints = false
    repoLabel.isEditable = false
    repoLabel.isBordered = false
    repoLabel.backgroundColor = .clear
    containerView.addSubview(repoLabel)

    let nameLabel = NSTextField(labelWithString: session.cleanedDisplayName)
    nameLabel.font = NSFont.systemFont(ofSize: 12)
    nameLabel.textColor = .labelColor
    nameLabel.translatesAutoresizingMaskIntoConstraints = false
    nameLabel.isEditable = false
    nameLabel.isBordered = false
    nameLabel.backgroundColor = .clear
    nameLabel.lineBreakMode = .byTruncatingTail
    containerView.addSubview(nameLabel)

    let infoLabel = NSTextField(labelWithString: "\(session.formattedRelativeDate) • \(session.messageCount) msgs")
    infoLabel.font = NSFont.systemFont(ofSize: 11)
    infoLabel.textColor = .secondaryLabelColor
    infoLabel.translatesAutoresizingMaskIntoConstraints = false
    infoLabel.isEditable = false
    infoLabel.isBordered = false
    infoLabel.backgroundColor = .clear
    containerView.addSubview(infoLabel)

    let button = NSButton()
    button.title = ""
    button.isBordered = false
    button.translatesAutoresizingMaskIntoConstraints = false
    button.action = #selector(sessionItemClicked(_:))
    button.target = self
    button.tag = filteredSessions.firstIndex(where: { $0.id == session.id }) ?? 0
    containerView.addSubview(button)

    NSLayoutConstraint.activate([
      repoLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 8),
      repoLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
      repoLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),

      nameLabel.topAnchor.constraint(equalTo: repoLabel.bottomAnchor, constant: 2),
      nameLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
      nameLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),

      infoLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
      infoLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
      infoLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
      infoLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -8),

      button.topAnchor.constraint(equalTo: containerView.topAnchor),
      button.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
      button.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
      button.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),

      containerView.heightAnchor.constraint(greaterThanOrEqualToConstant: 60),
    ])

    return containerView
  }

  @objc private func searchChanged(_ sender: NSSearchField) {
    currentSearchQuery = sender.stringValue

    if currentSearchQuery.isEmpty {
      filteredSessions = Array(sessions.prefix(10))
    } else if let searchIndex = searchIndex {
      let matchingIds = searchIndex.search(currentSearchQuery)
      filteredSessions = sessions.filter { matchingIds.contains($0.id) }.prefix(10).map { $0 }
    } else {
      filteredSessions = []
    }

    updateSessionList()
  }

  @objc private func clearSearchClicked() {
    searchField?.stringValue = ""
    searchChanged(searchField!)
  }

  @objc private func sessionItemClicked(_ sender: NSButton) {
    let index = sender.tag
    if index < filteredSessions.count {
      onSessionClicked?(filteredSessions[index])
    }
  }

  @objc private func refreshClicked() {
    onRefresh?()
  }

  @objc private func settingsClicked() {
    onOpenSettings?()
  }

  @objc private func aboutClicked() {
    onOpenAbout?()
  }
}
