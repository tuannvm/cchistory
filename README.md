# CCHistory

<div align="center">
  <img src="Assets.xcassets/AppIcon.appiconset/logo.svg" alt="CCHistory Logo" width="128" height="128">
</div>

A macOS menu bar application that displays your Claude Code conversation history locally without any external server communication.

## Preview

![CCHistory Screenshot](Assets/screenshot.png)

## Features

- **Menu Bar Integration**: Runs as a menu bar app with an icon showing available Claude Code sessions
- **Multiple Sorting Options**:
  - **Most Active**: Sessions with the most messages (default)
  - **Most Recent**: Sessions sorted by last activity timestamp
  - **Last Hour**: Sessions active in the past hour
  - **Last 24 Hours**: Sessions active in the past day
  - **Last Week**: Sessions active in the past 7 days
  - **All Time**: All sessions, sorted by recency
- **Smart Session Naming**: Uses session summary names from your Claude Code history
- **Enhanced Session Display**:
  - Repository/Project name
  - Git branch (if available)
  - Relative timestamp (e.g., "2h ago", "just now")
  - Message count
- **Resume Support**: Click any session to copy the resume command to clipboard
- **Git Integration**: Automatically extracts git repo name and branch from project paths
- **Auto-Refresh**: Refreshes session list every 30 seconds
- **Manual Refresh**: Press `Cmd+R` to refresh manually
- **Notifications**: Shows notification when resume command is copied

## Requirements

- macOS 13.0 or later
- Xcode or Swift Package Manager
- Claude Code installed with history in `~/.claude/`
- Apple Developer account (for code signing when building from source)

## Installation

### Download from [Releases](https://github.com/tuannvm/cchistory/releases)

Download the latest `CCHistory.zip`, extract it, and move `CCHistory.app` to your Applications folder.

### Build from Source

```bash
# Clone the repository
git clone https://github.com/tuannvm/cchistory.git
cd cchistory

# Set your code signing identity (find it with: security find-identity -v -p codesigning)
export DEVELOPER_IDENTITY="<your-certificate-identity>"

# Build using the provided script
./build.sh
```

## Usage

1. **Launch the app**:
   ```bash
   open CCHistory.app
   ```

2. **Click the menu bar icon** (message circle icon) to see your sessions

3. **Change sort option**:
   - Click "Sort By..." in the menu
   - Select your preferred sorting method
   - Keyboard shortcuts: `Cmd+1` through `Cmd+6`

4. **Click on a session** to copy the resume command to clipboard

5. **Paste in terminal** to resume that Claude Code session:
   ```bash
   cd "/path/to/project" && claude --resume <session-id>
   ```

## Project Structure

```
cchistory/
├── Sources/
│   └── CCHistory/
│       ├── CCHistory.swift      # Main app and menu bar logic
│       ├── HistoryParser.swift  # Parses session files
│       └── Session.swift        # Session data model
├── Assets.xcassets/             # App icons and images
│   └── AppIcon.appiconset/
│       ├── logo.svg             # App logo (SVG)
│       └── Contents.json        # Icon metadata
├── Assets/                      # Documentation assets
│   └── screenshot.png           # App screenshot (to be added)
├── .github/workflows/           # CI/CD
│   └── release.yml              # Release automation
├── Package.swift                # Swift Package manifest
├── build.sh                     # Build script
├── README.md                    # This file
└── LICENSE                      # MIT License
```

## How It Works

1. **Session Parsing**: Reads `~/.claude/projects/*/` directories for session files
2. **Session Files**: Each `<session-id>.jsonl` file contains:
   - Summary entries with session names
   - User/assistant messages with timestamps
   - Session metadata (project path, git branch, etc.)
3. **Git Integration**: Extracts repo name and branch from project paths
4. **Resume Command**: Generates `cd "PROJECT_PATH" && claude --resume SESSION_ID`

## Sorting Options

| Option | Description | Shortcut |
|--------|-------------|----------|
| Most Active | Sessions with most messages | ⌘+1 |
| Most Recent | Sessions by last activity | ⌘+2 |
| Last Hour | Active in past 60 minutes | ⌘+3 |
| Last 24 Hours | Active in past day | ⌘+4 |
| Last Week | Active in past 7 days | ⌘+5 |
| All Time | All sessions by recency | ⌘+6 |

## Privacy & Security

- **100% Local**: No external server communication
- **No Analytics**: No tracking or telemetry
- **Read-Only**: Only reads Claude Code history, never modifies it
- **No Credentials**: Doesn't access any credentials or API keys

## Troubleshooting

### "No sessions found"
- Ensure Claude Code has been used at least once
- Check that `~/.claude/projects/` exists and contains session files
- Verify file permissions: `ls -la ~/.claude/projects/`

### Build errors
- Ensure Xcode or Swift toolchain is installed: `xcode-select -p`
- Ensure `DEVELOPER_IDENTITY` is set: `export DEVELOPER_IDENTITY="<your-identity>"`
- Try: `swift build --verbose` for more details

### Git branch not showing
- Ensure the project is a git repository
- Check that git is accessible: `which git`

### "App is damaged" error
- The app must be code signed to run on macOS
- Download from [Releases](https://github.com/tuannvm/cchistory/releases) for pre-signed builds
- When building from source, set `DEVELOPER_IDENTITY` environment variable

## Development

### Prerequisites
- Swift 5.9+
- macOS 13.0+
- Apple Developer account (for code signing)

### Building
```bash
# Set your code signing identity
export DEVELOPER_IDENTITY="<your-certificate-identity>"

# Build
swift build -c release

# Or use the build script
./build.sh
```

### Running
```bash
swift run CCHistory
```

### Testing
```bash
swift test
```

## License

MIT License - see [LICENSE](LICENSE) for details.

## Inspired By

- [claude-run](https://github.com/kamranahmedse/claude-run) - A beautiful web UI for browsing Claude Code conversation history

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
# cchistory
