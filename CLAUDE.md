# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

CCHistory is a macOS menu bar application that displays Claude Code conversation history. It reads local session files from `~/.claude/projects/` and provides quick access to resume sessions via the menu bar.

**Key Architecture Points:**
- **No server communication** - 100% local, reads only from filesystem
- **Menu bar only** - Uses `LSUIElement=true` to hide from Dock
- **Swift Package Manager** layout with `Sources/CCHistory/`
- **Code signing required** - `DEVELOPER_IDENTITY` env var must be set to build

## Build Commands

```bash
# Build (requires DEVELOPER_IDENTITY to be set)
export DEVELOPER_IDENTITY="<your-certificate-identity>"
./build.sh

# Or build manually
swift build -c release --product CCHistory

# Run directly (for development)
swift run CCHistory

# Find available code signing identities
security find-identity -v -p codesigning
```

## Architecture

### Data Flow

```
~/.claude/projects/ (or custom path from Settings)
  └── <sanitized-project-path>/     (e.g., "Users-username-Projects-repo")
      └── <session-id>.jsonl         (JSONL file with messages)

HistoryParser.parseSessionsWithIndex()
  → Scans project directories
  → Parses each .jsonl file for summary + timestamps
  → Extracts message content for search index
  → Builds SearchIndex with session metadata
  → Returns ParseResult (sessions + searchIndex)
  → Extracts git info via Process calls

AppDelegate.buildMenu()
  → Shows NSSearchField at top (live filtering)
  → Gets sessions from HistoryParser
  → Applies search filter if query exists
  → Creates NSMenu with NSMenuItems
  → Each click copies resume command to clipboard
  → Shows "✓ Copied" visual feedback for 1.5s

SettingsWindow
  → NSPanel with path text field
  → Browse button for directory picker
  → Validates path and shows errors
  → Saves to UserDefaults on Apply
  → Triggers re-parse on path change
```

### Key Files

| File | Purpose |
|------|---------|
| `CCHistory.swift` | Main app entry point, `@main` struct, `AppDelegate` with menu bar, search, and settings logic |
| `HistoryParser.swift` | Parses `~/.claude/projects/*/*.jsonl` files, extracts git info via `Process`, builds search index |
| `SearchIndex.swift` | In-memory search index for fast session lookup across names, paths, and message content |
| `Session.swift` | Data models (`Session`, `SessionSortOption`, `TimeFilter`) with computed properties |
| `SettingsWindow.swift` | `NSPanel` for configuring custom Claude projects directory with validation |
| `build.sh` | Build script that requires `DEVELOPER_IDENTITY` env var |

### Session File Format

Claude Code stores sessions as JSONL files. Each line is a JSON object:
- `type: "summary"` - Contains session name in `summary` field
- `type: "user"` - User message with `timestamp` (ISO8601 with fractional seconds)
- `type: "assistant"` - Assistant message with `timestamp`

**Critical:** Timestamps use format `yyyy-MM-dd'T'HH:mm:ss.SSS'Z'` - standard `ISO8601DateFormatter` doesn't handle fractional seconds, so a custom `DateFormatter` is used.

### Project Path Encoding

Claude Code sanitizes project paths in directory names:
- `/` → `-` (forward slash becomes hyphen)
- Example: `/Users/dev/my-repo` → `Users-dev-my-repo`

The code reverses this: `projectDir.replacingOccurrences(of: "-", with: "/")`

### Git Integration

`HistoryParser.extractGitInfo()` uses direct `Process` calls with argument arrays (no shell) to:
1. Validate path doesn't contain shell metacharacters (`$`;`|()` etc.)
2. Verify path exists and is a directory
3. Check if it's a git repo via `git -C <path> rev-parse --git-dir`
4. Get remote origin URL via `git -C <path> remote get-url origin`
5. Extract repo name from remote URL (stripping `.git` suffix) or fallback to directory basename
6. Get current branch via `git -C <path> rev-parse --abbrev-ref HEAD`

**Security**: Uses `Process` with argument arrays instead of shell scripts to prevent command injection. Path validation occurs before any git commands.

## Code Conventions

- Use `final` on classes that shouldn't be subclassed (`HistoryParser`, `AppDelegate`, `SessionMenuItem`)
- Use `Sendable` conformance for Swift 6 concurrency safety on value types passed across concurrency boundaries
- Use `NSHomeDirectory()` instead of hardcoded user paths
- Prefer `@objc` functions for `NSMenuItem` actions
- Structs for data models, classes for NSObject subclasses

## Release Process

Releases are automated via GitHub Actions in `.github/workflows/release.yml`:
1. Triggered on version tags (`v*.*.*`)
2. Builds using `swift build -c release`
3. Creates app bundle with Info.plist
4. Signs with adhoc signature (`--sign -`)
5. Creates release with `CCHistory.zip`

For signed releases locally, the build script uses your `DEVELOPER_IDENTITY`.

## Testing the App

```bash
# After building, verify signature
codesign -vvv CCHistory.app

# Launch the app
open CCHistory.app

# Check if running
pgrep -lf CCHistory

# Kill when done
killall CCHistory
```

## Common Issues

- **"App is damaged"** - Code signing issue. Ensure `DEVELOPER_IDENTITY` is set and valid.
- **No sessions found** - Check `~/.claude/projects/` exists and contains `.jsonl` files
- **Swift 6 build failures** - The toolchain may have issues; use existing binary from previous build
- **Git branch not showing** - Shell script fails silently if path doesn't exist or isn't a git repo
