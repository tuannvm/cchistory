import AppKit
import SwiftUI

/// About window for CCHistory app
@MainActor
final class AboutWindow: NSPanel {
  init() {
    super.init(
      contentRect: NSRect(x: 0, y: 0, width: 360, height: 420),
      styleMask: [.titled, .closable],
      backing: .buffered,
      defer: false
    )

    self.title = "About CCHistory"
    self.isFloatingPanel = false
    self.isMovableByWindowBackground = true
    self.backgroundColor = NSColor.windowBackgroundColor

    setupUI()
  }

  private func setupUI() {
    let contentView = NSView()
    contentView.translatesAutoresizingMaskIntoConstraints = false
    contentView.wantsLayer = true
    contentView.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

    self.contentViewController = NSViewController()
    self.contentViewController?.view = contentView

    // App icon
    let iconView = NSImageView()
    iconView.image = NSImage.cchistoryLogo
    iconView.imageScaling = .scaleProportionallyUpOrDown
    iconView.translatesAutoresizingMaskIntoConstraints = false
    iconView.widthAnchor.constraint(equalToConstant: 80).isActive = true
    iconView.heightAnchor.constraint(equalToConstant: 80).isActive = true
    contentView.addSubview(iconView)

    // App name
    let appNameLabel = NSTextField(labelWithString: "CCHistory")
    appNameLabel.font = NSFont.systemFont(ofSize: 24, weight: .bold)
    appNameLabel.textColor = NSColor.labelColor
    appNameLabel.alignment = .center
    appNameLabel.translatesAutoresizingMaskIntoConstraints = false
    appNameLabel.isEditable = false
    appNameLabel.isBordered = false
    appNameLabel.backgroundColor = .clear
    contentView.addSubview(appNameLabel)

    // Version
    let versionLabel = NSTextField(labelWithString: "Version 1.0.0")
    versionLabel.font = NSFont.systemFont(ofSize: 13)
    versionLabel.textColor = NSColor.secondaryLabelColor
    versionLabel.alignment = .center
    versionLabel.translatesAutoresizingMaskIntoConstraints = false
    versionLabel.isEditable = false
    versionLabel.isBordered = false
    versionLabel.backgroundColor = .clear
    contentView.addSubview(versionLabel)

    // Links container (Website, GitHub)
    let linksStack = NSStackView()
    linksStack.orientation = .horizontal
    linksStack.spacing = 20
    linksStack.translatesAutoresizingMaskIntoConstraints = false
    contentView.addSubview(linksStack)

    // Website link
    let websiteButton = NSButton(title: "Website", target: self, action: #selector(openWebsite))
    websiteButton.isBordered = false
    websiteButton.focusRingType = .none
    styleLinkButton(websiteButton)
    linksStack.addArrangedSubview(websiteButton)

    // GitHub link
    let githubButton = NSButton(title: "GitHub", target: self, action: #selector(openGitHub))
    githubButton.isBordered = false
    githubButton.focusRingType = .none
    styleLinkButton(githubButton)
    linksStack.addArrangedSubview(githubButton)

    // Description
    let descLabel = NSTextField(labelWithString: "Claude Code conversation history\nmenu bar application.")
    descLabel.font = NSFont.systemFont(ofSize: 12)
    descLabel.textColor = NSColor.labelColor
    descLabel.alignment = .center
    descLabel.translatesAutoresizingMaskIntoConstraints = false
    descLabel.isEditable = false
    descLabel.isBordered = false
    descLabel.backgroundColor = .clear
    contentView.addSubview(descLabel)

    // Features list
    let featuresLabel = NSTextField(labelWithString: """
    Features:
    • Search across sessions
    • Sort by activity/recency
    • Copy resume commands
    • Custom path support
    """)
    featuresLabel.font = NSFont.systemFont(ofSize: 11)
    featuresLabel.textColor = NSColor.secondaryLabelColor
    featuresLabel.alignment = .center
    featuresLabel.translatesAutoresizingMaskIntoConstraints = false
    featuresLabel.isEditable = false
    featuresLabel.isBordered = false
    featuresLabel.backgroundColor = .clear
    contentView.addSubview(featuresLabel)

    // Copyright
    let copyrightLabel = NSTextField(labelWithString: "© 2024")
    copyrightLabel.font = NSFont.systemFont(ofSize: 11)
    copyrightLabel.textColor = NSColor.tertiaryLabelColor
    copyrightLabel.alignment = .center
    copyrightLabel.translatesAutoresizingMaskIntoConstraints = false
    copyrightLabel.isEditable = false
    copyrightLabel.isBordered = false
    copyrightLabel.backgroundColor = .clear
    contentView.addSubview(copyrightLabel)

    // Layout constraints
    NSLayoutConstraint.activate([
      // Icon
      iconView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 30),
      iconView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),

      // App name
      appNameLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 16),
      appNameLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),

      // Version
      versionLabel.topAnchor.constraint(equalTo: appNameLabel.bottomAnchor, constant: 4),
      versionLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),

      // Links
      linksStack.topAnchor.constraint(equalTo: versionLabel.bottomAnchor, constant: 16),
      linksStack.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),

      // Description
      descLabel.topAnchor.constraint(equalTo: linksStack.bottomAnchor, constant: 24),
      descLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
      descLabel.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 20),
      descLabel.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -20),

      // Features
      featuresLabel.topAnchor.constraint(equalTo: descLabel.bottomAnchor, constant: 20),
      featuresLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),

      // Copyright
      copyrightLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
      copyrightLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
    ])
  }

  private func styleLinkButton(_ button: NSButton) {
    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.alignment = .center

    button.attributedTitle = NSAttributedString(
      string: button.title,
      attributes: [
        .foregroundColor: NSColor.controlAccentColor,
        .font: NSFont.systemFont(ofSize: 13),
        .underlineStyle: NSUnderlineStyle.single.rawValue,
        .paragraphStyle: paragraphStyle,
      ]
    )
  }

  @objc private func openWebsite() {
    if let url = URL(string: "https://github.com/tuannvm/cchistory") {
      NSWorkspace.shared.open(url)
    }
  }

  @objc private func openGitHub() {
    if let url = URL(string: "https://github.com/tuannvm/cchistory") {
      NSWorkspace.shared.open(url)
    }
  }
}
