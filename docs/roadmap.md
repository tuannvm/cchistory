# CCHistory Roadmap

This document tracks planned features and improvements for CCHistory.

---

## Feature: Search Conversation History [COMPLETED]

Enable users to quickly find relevant sessions by searching through conversation content.

### What Was Built
- **Search UI**: `NSSearchField` at the top of menu bar dropdown with placeholder "Search sessions..."
- **Indexing**: In-memory `SearchIndex` built during session parsing
- **Indexed content**: Session name, project path, git repo/branch, last 15 messages
- **Live filtering**: Menu rebuilds as user types, showing only matching sessions
- **Performance**: O(n) index build, O(m) search query where m = sessions

### Implementation
See `SearchIndex.swift` for index implementation and `CCHistory.swift:106-175` for search UI integration.

### Open Questions (Resolved)
- How many messages per session? → **15** (configurable via `maxMessagesToIndex`)
- Search highlighting? → Not implemented (simple substring matching)
- Keyboard shortcut? → None (search field auto-focuses on menu open)

---

## Feature: Custom `.claude` Folder Location [COMPLETED]

Allow users to specify a custom location for their Claude Code projects directory.

### What Was Built
- [COMPLETED] **Settings Window**: `SettingsWindow.swift` (NSPanel) with:
  - Text field showing current path
  - "Browse..." button with `NSOpenPanel`
  - "Reset to Default" button
  - Real-time validation with error/warning messages
- [COMPLETED] **Persistence**: `UserDefaults` with key `claudeProjectsPath`
- [COMPLETED] **Integration**: Full flow from UI → `HistoryParser` re-init → cache reload
- [COMPLETED] **Security**: Path validation for dangerous characters, path traversal prevention

### Implementation
See `SettingsWindow.swift:114-194` for validation logic and `CCHistory.swift:306-327` for path change handling.

---

## Feature: Performance Improvements (Async Loading) [COMPLETED]

Implemented asynchronous session parsing to eliminate blocking UI delay.

### What Was Built
- **Immediate UI**: Menu shows "Loading..." indicator on app launch
- **Background Parsing**: Uses `Task.detached(priority: .userInitiated)` for off-main-thread parsing
- **In-Memory Cache**: `cachedSessions` stores parsed results
- **Auto-refresh**: Timer invalidates cache every 30 seconds
- **Cache Invalidation**: On `applicationDidBecomeActive` (user returns to app)

### Implementation
See `CCHistory.swift:72-98` for `loadSessionsAsync()` implementation.

---

## Feature: About Dialog [COMPLETED]

Show an About window with app version, repository link, and general information.

### What Was Built
- Menu item: "About CCHistory" in menu bar
- NSAlert showing:
  - App name and version (1.0.0)
  - GitHub repository link (github.com/tuannvm/cchistory)
  - Brief description
  - Feature list
  - Credits

### Implementation
See `CCHistory.swift:278-304` for `showAboutDialog()`.

---

## Feature: Improved Copy Feedback [COMPLETED]

Replace/supplement the notification with a more visible and intuitive copy confirmation.

### What Was Built
- **Visual feedback**: Menu item temporarily changes to "✓ Copied: [repo]: [name]"
- **Green bold text**: Uses `NSAttributedString` with `.systemGreen` color
- **Auto-revert**: Feedback clears after 1.5 seconds via `Timer`
- **Non-blocking**: Menu remains interactive during feedback

### Implementation
See `CCHistory.swift:360-377` for `showCopyFeedback()` and `SessionMenuItem:420-459` for visual rendering.

---

## Future Enhancements

### LLM-Based Session Naming

Optional local LLM integration (Ollama) to generate descriptive names for unnamed sessions.

### Search Highlighting

Highlight matching text in search results for better visibility.

### Keyboard Shortcuts

- Quick access to search field (e.g., `Cmd+/` or `Cmd+K`)
- Navigate search results with arrow keys

---

## Completed Features Summary

| Feature | Impact | Complexity | Status |
|---------|--------|------------|--------|
| Async Loading | High | Medium | [Done] |
| Search | High | Medium | [Done] |
| Clear Search & Result Limits | Medium | Low | [Done] |
| Custom Path (UI) | Medium | Low | [Done] |
| About Dialog | Low | Low | [Done] |
| Improved Copy Feedback | Medium | Low | [Done] |

---

## Recent Improvements (January 2026)

### Feature: Clear Search & Result Limits [COMPLETED]

Enhanced the search experience with better UX controls.

### What Was Built
- **ESC to clear**: Press ESC key in search field to instantly clear the search query
- **Result capping**: Limited display to 10 sessions (`maxSessionsToDisplay`) and 10 search results (`maxSearchResults`)
- **Configurable limits**: Extracted session limits into constants (`sessionsForSearchIndex = 200` for index)
- **Simplified UI**: Removed redundant header and LLM tip for cleaner menu
- **Improved search placeholder**: Changed from "Search sessions..." to "Search..."

### Implementation
See `CCHistory.swift:17-22` for constants and `CCHistory.swift:122-133` for search field configuration.

---

### Code Quality & Bug Fixes
- **Search index limit increased**: From 50 to 200 sessions for better coverage
- **Fixed redundant search handlers**: Removed duplicate NSSearchField action handler, keeping only delegate method
- **Removed dead code**: Cleaned up unused `getCurrentPath()` method in SettingsWindow
- **Swift 6 concurrency**: Updated to Swift 6.2, removed UserNotifications dependency
- **Clean build**: Zero compiler warnings achieved
- **Test coverage**: Added comprehensive tests for SearchIndex functionality

### Verified Guarantees
- [PASS] Thread-safe SearchIndex with value semantics
- [PASS] No memory leaks (proper `[weak self]` usage)
- [PASS] MainActor isolation correct throughout
- [PASS] Timer invalidation handled properly
- [PASS] UserDefaults persistence working correctly
