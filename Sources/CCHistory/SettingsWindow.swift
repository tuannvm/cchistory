import AppKit

/// Settings window for configuring CCHistory preferences
@MainActor
final class SettingsWindow: NSPanel {
  private let claudePathKey = "claudeProjectsPath"
  private let defaultPath = "\(NSHomeDirectory())/.claude"

  private var pathTextField: NSTextField!
  private var browseButton: NSButton!
  private var resetButton: NSButton!
  private var applyButton: NSButton!
  private var statusLabel: NSTextField!
  private var descriptionLabel: NSTextField!

  var onPathChanged: ((String) -> Void)?

  init() {
    super.init(
      contentRect: NSRect(x: 0, y: 0, width: 600, height: 240),
      styleMask: [.titled, .closable],
      backing: .buffered,
      defer: false
    )

    self.title = "CCHistory Settings"
    self.isFloatingPanel = false
    self.isMovableByWindowBackground = true

    setupUI()
    loadSavedPath()
  }

  private func setupUI() {
    let contentView = NSView()
    contentView.translatesAutoresizingMaskIntoConstraints = false
    self.contentViewController = NSViewController()
    self.contentViewController?.view = contentView

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

      // Status label - spacious gap below reset
      statusLabel.topAnchor.constraint(equalTo: resetButton.bottomAnchor, constant: 16),
      statusLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 32),
      statusLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -32),
      statusLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 20),

      // Apply button - generous gap above and below
      applyButton.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 24),
      applyButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -32),
      applyButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -32),
      applyButton.widthAnchor.constraint(equalToConstant: 90),
    ])
  }

  private func loadSavedPath() {
    if let savedPath = UserDefaults.standard.string(forKey: claudePathKey) {
      pathTextField.stringValue = savedPath
    } else {
      pathTextField.stringValue = defaultPath
    }
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

    if validatePath() {
      UserDefaults.standard.set(newPath, forKey: claudePathKey)
      onPathChanged?(newPath)
      statusLabel.stringValue = "Settings saved. Relaunch the app to apply changes."
      statusLabel.textColor = .systemGreen

      DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
        self?.close()
      }
    }
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
