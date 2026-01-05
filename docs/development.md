# Development Guide

## Prerequisites

- Swift 5.9+
- macOS 13.0+
- Apple Developer account (for code signing)

## Building

```bash
# Set your code signing identity
export DEVELOPER_IDENTITY="<your-certificate-identity>"

# Build
swift build -c release

# Or use the build script
./build.sh
```

Find available identities with: `security find-identity -v -p codesigning`

## Running

```bash
swift run CCHistory
```

## Testing

```bash
swift test
```

## Project Structure

```
cchistory/
├── Sources/
│   └── CCHistory/
│       ├── CCHistory.swift      # Main app and menu bar logic
│       ├── HistoryParser.swift  # Parses session files
│       └── Session.swift        # Session data model
├── Assets.xcassets/             # App icons
├── docs/                        # Documentation
├── Package.swift                # Swift Package manifest
└── build.sh                     # Build script
```

## How It Works

```
~/.claude/projects/
  └── <sanitized-project-path>/     (e.g., "Users-username-Projects-repo")
      └── <session-id>.jsonl         (JSONL file with messages)

HistoryParser.parseSessionsFromProjects()
  → Scans project directories
  → Parses each .jsonl file for summary + timestamps
  → Extracts git info via shell commands
  → Returns [Session] sorted by criteria

AppDelegate.buildMenu()
  → Gets sessions from HistoryParser
  → Creates NSMenu with NSMenuItems
  → Each click copies resume command to clipboard
```

### Session File Format

Claude Code stores sessions as JSONL files. Each line is a JSON object:
- `type: "summary"` - Contains session name in `summary` field
- `type: "user"` - User message with `timestamp` (ISO8601 with fractional seconds)
- `type: "assistant"` - Assistant message with `timestamp`

**Critical:** Timestamps use format `yyyy-MM-dd'T'HH:mm:ss.SSS'Z'` - standard `ISO8601DateFormatter` doesn't handle fractional seconds, so a custom `DateFormatter` is used.

### Git Integration

`HistoryParser.extractGitInfo()` uses direct `Process` calls (no shell) to:
1. Validate path doesn't contain shell metacharacters
2. Verify path exists and is a directory
3. Check if it's a git repo
4. Get remote origin URL
5. Extract repo name from remote URL (or fallback to directory basename)
6. Get current branch

**Security**: Uses `Process` with argument arrays instead of shell scripts to prevent command injection.

## Sorting Options

| Option | Description | Shortcut |
|--------|-------------|----------|
| Most Active | Sessions with most messages | ⌘+1 |
| Most Recent | Sessions by last activity | ⌘+2 |
| Last Hour | Active in past 60 minutes | ⌘+3 |
| Last 24 Hours | Active in past day | ⌘+4 |
| Last Week | Active in past 7 days | ⌘+5 |
| All Time | All sessions by recency | ⌘+6 |

## Release Process

Releases are automated via GitHub Actions (`.github/workflows/release.yml`):
1. Triggered on version tags (`v*.*.*`)
2. Builds using `swift build -c release`
3. Creates app bundle with Info.plist
4. Signs with adhoc signature
5. Creates release with `CCHistory.zip`

For signed releases locally, use your `DEVELOPER_IDENTITY`.

## Code Conventions

- Use `final` on classes that shouldn't be subclassed
- Use `Sendable` conformance for Swift 6 concurrency safety
- Use `NSHomeDirectory()` instead of hardcoded user paths
- Prefer `@objc` functions for `NSMenuItem` actions
- Structs for data models, classes for NSObject subclasses
