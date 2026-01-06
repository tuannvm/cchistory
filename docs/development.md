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

## Menu Bar Icon

The CCHistory menu bar icon is generated programmatically using `NSBezierPath` drawing in `IconData.swift`. This approach avoids file loading issues and ensures consistent rendering across different macOS versions.

### How It Works

The icon is created as an extension on `NSImage`:

```swift
extension NSImage {
    static let cchistoryLogo: NSImage = {
        // 22x22 pixel image for menu bar display
        let size = NSSize(width: 22, height: 22)
        let image = NSImage(size: size)
        image.isTemplate = false  // Preserve colors
        image.lockFocus()

        // Draw using NSBezierPath
        // 1. Dark rounded background
        // 2. Orange speech bubble
        // 3. Clock symbol with hands
        // 4. Message dots

        image.unlockFocus()
        return image
    }()
}
```

### Key Design Elements

| Element | Color | Position |
|---------|-------|----------|
| Background | Dark (#1a1a1a) | Full 22x22 area |
| Rounded square | Dark gray (#262626) | Centered, 5px corner radius |
| Speech bubble | Orange (#D97757) | Center-left |
| Clock face | Dark (#1a1a1a, 90% opacity) | Inside bubble |
| Clock hands | Orange (#D97757) | Center of clock |
| Message dots | Dark (#1a1a1a, 60% opacity) | Bottom of bubble |

### Important Implementation Details

1. **`isTemplate = false`** - Critical! Without this, macOS renders the icon as a single-color silhouette (white square in dark mode)
2. **Fill entire area first** - Prevents transparency issues
3. **`resizingMode = .stretch`** - Ensures proper scaling
4. **22x22 points** - Standard menu bar icon size (displays as 44x44 pixels on Retina)

### Modifying the Icon

To modify the icon design:

1. Edit `Sources/CCHistory/IconData.swift`
2. Adjust the `NSBezierPath` drawing commands
3. Rebuild and test: `./build.sh && open CCHistory.app`

### Original Logo

The original logo design is in `Sources/CCHistory/Assets.xcassets/AppIcon.appiconset/logo.svg` as a reference, but the menu bar icon is a simplified programmatic version optimized for small size display.

## Async Loading

CCHistory uses asynchronous loading to ensure the app launches instantly without blocking the UI while parsing session files.

### Architecture

```
AppDelegate (MainActor)
  ├── cachedSessions: [Session]     // In-memory cache
  ├── isLoading: Bool               // Loading state
  └── cacheInvalidated: Bool        // Dirty flag

loadSessionsAsync()
  → Task.detached runs parsing off main thread
  → MainActor.run updates UI on completion

buildMenu()
  → Shows "Loading..." if isLoading && no cache
  → Uses cachedSessions if available
  → Triggers reload if cacheInvalidated
```

### Cache Invalidation

The cache is invalidated in these scenarios:
1. **App activation** (`applicationDidBecomeActive`) - User may have new sessions
2. **Sort option change** - Different sort requires re-parsing
3. **Manual refresh** - User presses `Cmd+R`

### Swift 6 Concurrency

- `@MainActor` on `AppDelegate` ensures all UI operations run on main thread
- `Task.detached` runs parsing in background without blocking UI
- `MainActor.run` ensures UI updates happen on main thread after parsing completes

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
