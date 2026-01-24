import AppKit

/// Settings window for configuring CCHistory preferences
final class SettingsWindow: NSPanel {
  private let claudePathKey = "claudeProjectsPath"
  private let defaultPath = "\(NSHomeDirectory())/.claude"

  private var pathTextField: NSTextField!
  private var browseButton: NSButton!
  private var resetButton: NSButton!
  private var applyButton: NSButton!
  private var statusLabel: NSTextField!
  private var descriptionLabel: NSTextField!
  private var webServerToggle: NSButton!
  private var webServerPortField: NSTextField!
  private var webServerUrlLabel: NSTextField!
  private var webServerStatusLabel: NSTextField!

  var onPathChanged: ((String) -> Void)?
  var onWebServerToggled: ((Bool, UInt16) -> Void)?
  var onRequestWebServerURL: (() -> String?)?
  var onRequestWebServerStatus: (() -> String?)?

  init() {
    super.init(
      contentRect: NSRect(x: 0, y: 0, width: 600, height: 360),
      styleMask: [.titled, .closable, .fullSizeContentView],
      backing: .buffered,
      defer: false
    )

    self.title = "CCHistory Settings"
    self.isFloatingPanel = false
    self.isMovableByWindowBackground = true
    self.titlebarAppearsTransparent = true

    setupUI()
    loadSavedPath()
  }

  private func setupUI() {
    // Create visual effect view for glass background
    let visualEffectView = NSVisualEffectView()
    visualEffectView.translatesAutoresizingMaskIntoConstraints = false
    visualEffectView.material = .hudWindow
    visualEffectView.blendingMode = .behindWindow
    visualEffectView.state = .active

    self.contentViewController = NSViewController()
    self.contentViewController?.view = visualEffectView

    // Container view for content
    let contentView = NSView()
    contentView.translatesAutoresizingMaskIntoConstraints = false
    visualEffectView.addSubview(contentView)

    // Pin content view to visual effect view
    NSLayoutConstraint.activate([
      contentView.topAnchor.constraint(equalTo: visualEffectView.topAnchor),
      contentView.leadingAnchor.constraint(equalTo: visualEffectView.leadingAnchor),
      contentView.trailingAnchor.constraint(equalTo: visualEffectView.trailingAnchor),
      contentView.bottomAnchor.constraint(equalTo: visualEffectView.bottomAnchor),
    ])

    // Title label
    let titleLabel = NSTextField(labelWithString: "Claude Projects Directory")
    titleLabel.font = NSFont.boldSystemFont(ofSize: 13)
    titleLabel.translatesAutoresizingMaskIntoConstraints = false
    titleLabel.isEditable = false
    titleLabel.isBordered = false
    titleLabel.backgroundColor = .clear
    contentView.addSubview(titleLabel)

    // Description label
    descriptionLabel = NSTextField(labelWithString: "Customize where CCHistory looks for your Claude Code conversation history.")
    descriptionLabel.font = NSFont.systemFont(ofSize: 11)
    descriptionLabel.textColor = .secondaryLabelColor
    descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
    descriptionLabel.isEditable = false
    descriptionLabel.isBordered = false
    descriptionLabel.backgroundColor = .clear
    descriptionLabel.lineBreakMode = .byWordWrapping
    contentView.addSubview(descriptionLabel)

    // Path text field with larger height
    pathTextField = NSTextField()
    pathTextField.translatesAutoresizingMaskIntoConstraints = false
    pathTextField.placeholderString = defaultPath
    pathTextField.focusRingType = .none
    contentView.addSubview(pathTextField)

    // Browse button
    browseButton = NSButton(title: "Browse...", target: self, action: #selector(browseClicked))
    browseButton.translatesAutoresizingMaskIntoConstraints = false
    contentView.addSubview(browseButton)

    // Reset button
    resetButton = NSButton(title: "Reset to Default", target: self, action: #selector(resetClicked))
    resetButton.translatesAutoresizingMaskIntoConstraints = false
    contentView.addSubview(resetButton)

    // Status label
    statusLabel = NSTextField(labelWithString: "")
    statusLabel.translatesAutoresizingMaskIntoConstraints = false
    statusLabel.isEditable = false
    statusLabel.isBordered = false
    statusLabel.backgroundColor = .clear
    statusLabel.textColor = .systemRed
    statusLabel.font = NSFont.systemFont(ofSize: 11)
    contentView.addSubview(statusLabel)

    // Web server section title
    let webServerTitle = NSTextField(labelWithString: "Web Server")
    webServerTitle.font = NSFont.boldSystemFont(ofSize: 13)
    webServerTitle.translatesAutoresizingMaskIntoConstraints = false
    webServerTitle.isEditable = false
    webServerTitle.isBordered = false
    webServerTitle.backgroundColor = .clear
    contentView.addSubview(webServerTitle)

    // Web server toggle
    webServerToggle = NSButton(checkboxWithTitle: "Enable local web access", target: self, action: #selector(webServerToggleChanged))
    webServerToggle.translatesAutoresizingMaskIntoConstraints = false
    contentView.addSubview(webServerToggle)

    // Web server port
    let portLabel = NSTextField(labelWithString: "Port")
    portLabel.font = NSFont.systemFont(ofSize: 11)
    portLabel.textColor = .secondaryLabelColor
    portLabel.translatesAutoresizingMaskIntoConstraints = false
    portLabel.isEditable = false
    portLabel.isBordered = false
    portLabel.backgroundColor = .clear
    contentView.addSubview(portLabel)

    webServerPortField = NSTextField()
    webServerPortField.translatesAutoresizingMaskIntoConstraints = false
    webServerPortField.placeholderString = "8000"
    webServerPortField.focusRingType = .none
    webServerPortField.alignment = .left
    contentView.addSubview(webServerPortField)

    // Web server URL label
    webServerUrlLabel = NSTextField(labelWithString: "")
    webServerUrlLabel.font = NSFont.systemFont(ofSize: 11)
    webServerUrlLabel.textColor = .secondaryLabelColor
    webServerUrlLabel.translatesAutoresizingMaskIntoConstraints = false
    webServerUrlLabel.isEditable = false
    webServerUrlLabel.isBordered = false
    webServerUrlLabel.backgroundColor = .clear
    webServerUrlLabel.lineBreakMode = .byTruncatingMiddle
    contentView.addSubview(webServerUrlLabel)

    // Web server status label
    webServerStatusLabel = NSTextField(labelWithString: "")
    webServerStatusLabel.font = NSFont.systemFont(ofSize: 11)
    webServerStatusLabel.textColor = .secondaryLabelColor
    webServerStatusLabel.translatesAutoresizingMaskIntoConstraints = false
    webServerStatusLabel.isEditable = false
    webServerStatusLabel.isBordered = false
    webServerStatusLabel.backgroundColor = .clear
    webServerStatusLabel.lineBreakMode = .byTruncatingMiddle
    contentView.addSubview(webServerStatusLabel)

    // Apply button
    applyButton = NSButton(title: "Apply", target: self, action: #selector(applyClicked))
    applyButton.translatesAutoresizingMaskIntoConstraints = false
    applyButton.keyEquivalent = "\r"
    contentView.addSubview(applyButton)

    // Layout constraints with generous spacing
    NSLayoutConstraint.activate([
      // Title label - more top padding
      titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 32),
      titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 32),
      titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -32),

      // Description label - spacious gap below title
      descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
      descriptionLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 32),
      descriptionLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -32),

      // Path text field - generous gap below description
      pathTextField.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 24),
      pathTextField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 32),
      pathTextField.trailingAnchor.constraint(equalTo: browseButton.leadingAnchor, constant: -16),
      pathTextField.heightAnchor.constraint(equalToConstant: 28),

      // Browse button - aligned with text field
      browseButton.centerYAnchor.constraint(equalTo: pathTextField.centerYAnchor),
      browseButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -32),
      browseButton.widthAnchor.constraint(equalToConstant: 100),

      // Reset button - more gap below text field
      resetButton.topAnchor.constraint(equalTo: pathTextField.bottomAnchor, constant: 16),
      resetButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -32),
      resetButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 130),

      // Web server section
      webServerTitle.topAnchor.constraint(equalTo: resetButton.bottomAnchor, constant: 24),
      webServerTitle.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 32),
      webServerTitle.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -32),

      webServerToggle.topAnchor.constraint(equalTo: webServerTitle.bottomAnchor, constant: 8),
      webServerToggle.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 32),

      portLabel.centerYAnchor.constraint(equalTo: webServerPortField.centerYAnchor),
      portLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 32),

      webServerPortField.topAnchor.constraint(equalTo: webServerToggle.bottomAnchor, constant: 12),
      webServerPortField.leadingAnchor.constraint(equalTo: portLabel.trailingAnchor, constant: 12),
      webServerPortField.widthAnchor.constraint(equalToConstant: 80),
      webServerPortField.heightAnchor.constraint(equalToConstant: 24),

      webServerUrlLabel.topAnchor.constraint(equalTo: webServerPortField.bottomAnchor, constant: 8),
      webServerUrlLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 32),
      webServerUrlLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -32),

      webServerStatusLabel.topAnchor.constraint(equalTo: webServerUrlLabel.bottomAnchor, constant: 6),
      webServerStatusLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 32),
      webServerStatusLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -32),

      // Status label - spacious gap below URL label
      statusLabel.topAnchor.constraint(equalTo: webServerStatusLabel.bottomAnchor, constant: 16),
      statusLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 32),
      statusLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -32),
      statusLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 20),

      // Apply button - generous gap above and below
      applyButton.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 24),
      applyButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -32),
      applyButton.widthAnchor.constraint(equalToConstant: 90),
      applyButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -32),
    ])
  }

  // MARK: - Actions

  func loadSavedPath() {
    if let savedPath = UserDefaults.standard.string(forKey: claudePathKey) {
      pathTextField.stringValue = savedPath
    } else {
      pathTextField.stringValue = defaultPath
    }

    let isEnabled = UserDefaults.standard.bool(forKey: "webServerEnabled")
    let port = UserDefaults.standard.integer(forKey: "webServerPort")
    webServerToggle.state = isEnabled ? .on : .off
    webServerPortField.stringValue = port > 0 ? "\(port)" : "8000"
    updateWebServerUrlLabel(isEnabled: isEnabled)
    updateWebServerStatusLabel(isEnabled: isEnabled)
  }

  @objc private func browseClicked() {
    let panel = NSOpenPanel()
    panel.canChooseFiles = false
    panel.canChooseDirectories = true
    panel.allowsMultipleSelection = false
    panel.canCreateDirectories = true
    panel.title = "Select Claude Projects Directory"
    panel.prompt = "Select"

    panel.begin { [weak self] response in
      guard let self = self, response == .OK, let url = panel.url else {
        return
      }
      self.pathTextField.stringValue = url.path
      _ = self.validatePath()
    }
  }

  @objc private func resetClicked() {
    pathTextField.stringValue = defaultPath
    _ = validatePath()
  }

  @objc private func applyClicked() {
    let newPath = pathTextField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)

    guard validatePath() else { return }

    let portValue = webServerPortField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let port = UInt16(portValue), port > 0 else {
      statusLabel.stringValue = "Port must be a number between 1 and 65535."
      statusLabel.textColor = .systemRed
      return
    }

    UserDefaults.standard.set(newPath, forKey: claudePathKey)
    UserDefaults.standard.set(Int(port), forKey: "webServerPort")

    let isEnabled = (webServerToggle.state == .on)
    UserDefaults.standard.set(isEnabled, forKey: "webServerEnabled")

    onPathChanged?(newPath)
    onWebServerToggled?(isEnabled, port)

    statusLabel.stringValue = "Settings saved."
    statusLabel.textColor = .systemGreen
    updateWebServerUrlLabel(isEnabled: isEnabled)
    updateWebServerStatusLabel(isEnabled: isEnabled)

    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
      self?.close()
    }
  }

  @objc private func webServerToggleChanged() {
    updateWebServerUrlLabel(isEnabled: webServerToggle.state == .on)
    updateWebServerStatusLabel(isEnabled: webServerToggle.state == .on)
  }

  private func updateWebServerUrlLabel(isEnabled: Bool) {
    guard isEnabled else {
      webServerUrlLabel.stringValue = "Web access disabled."
      return
    }

    if let url = onRequestWebServerURL?() {
      webServerUrlLabel.stringValue = "Open from iPhone: \(url)"
    } else {
      webServerUrlLabel.stringValue = "Server not running."
    }
  }

  private func updateWebServerStatusLabel(isEnabled: Bool) {
    guard isEnabled else {
      webServerStatusLabel.stringValue = "Server stopped."
      webServerStatusLabel.textColor = .secondaryLabelColor
      return
    }

    if let status = onRequestWebServerStatus?() {
      webServerStatusLabel.stringValue = status
    } else {
      webServerStatusLabel.stringValue = "Starting web server..."
    }
    webServerStatusLabel.textColor = .secondaryLabelColor
  }

  private func validatePath() -> Bool {
    let path = pathTextField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
    let fileManager = FileManager.default

    var isDir: ObjCBool = false

    if path.isEmpty {
      statusLabel.stringValue = "Path cannot be empty."
      statusLabel.textColor = .systemRed
      return false
    }

    if !fileManager.fileExists(atPath: path, isDirectory: &isDir) {
      statusLabel.stringValue = "Path does not exist."
      statusLabel.textColor = .systemRed
      return false
    }

    if !isDir.boolValue {
      statusLabel.stringValue = "Path must be a directory."
      statusLabel.textColor = .systemRed
      return false
    }

    // Check if it looks like a Claude directory
    let projectsPath = "\(path)/projects"
    if !fileManager.fileExists(atPath: projectsPath) {
      statusLabel.stringValue = "Warning: No 'projects' directory found at this path."
      statusLabel.textColor = .systemOrange
      return true
    }

    statusLabel.stringValue = ""
    return true
  }
}
