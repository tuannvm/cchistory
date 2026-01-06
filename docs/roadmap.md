# CCHistory Roadmap

This document tracks planned features and improvements for CCHistory.

---

## Feature: Search Conversation History

Enable users to quickly find relevant sessions by searching through conversation content.

### Scope
- Search across session names (summaries) and message content
- In-memory index built on app launch
- Real-time filtering as user types

### Implementation Approach
1. **Search UI**: Add `NSSearchField` at the top of the menu bar dropdown
2. **Indexing**: Build an in-memory index during session parsing:
   - Session name (from `summary` message)
   - Last N messages per session (configurable, e.g., 10-20 messages)
3. **Filtering**: Live filter menu items as search query changes
4. **Performance**: Use index for fast substring search; avoid re-reading files

### Open Questions
- How many messages per session to index? (Trade-off: memory vs. completeness)
- Should search highlight matching text in results?
- Keyboard shortcut to focus search field?

---

## Feature: Custom `.claude` Folder Location ⚠️ PARTIAL

Allow users to specify a custom location for their Claude Code projects directory.

### Status
- ✅ Backend: `HistoryParser` accepts `claudePath` parameter with security validation
- ❌ UI: No Settings window to configure the path
- ❌ Persistence: No UserDefaults integration

### What's Already Implemented (`HistoryParser.swift:9-25`)
```swift
init(claudePath: String? = nil) {
    // Security validation for dangerous characters
    // Path standardization to prevent traversal attacks
    // Falls back to ~/.claude if invalid
}
```

### Remaining Work
1. **Settings Window**: Create `NSWindow` or `NSPanel` with:
   - Text field showing current path
   - "Browse..." button with `NSOpenPanel`
   - "Reset to Default" button (`~/.claude`)
2. **Storage**: Use `UserDefaults.standard` with key like `claudeProjectsPath`
3. **Integration**: Wire Settings UI to `HistoryParser` init
4. **Validation**: Check path exists and contains expected structure before applying

### Open Questions
- Should changes require app restart or take effect immediately?
- Where to access settings? (Menu item: "Preferences..." or "Settings...")
- What to show if custom path is invalid? (Fallback to default + error dialog)

---

## Feature: Performance Improvements (Async Loading) ✅ COMPLETED

Implemented asynchronous session parsing to eliminate blocking UI delay.

### What Was Built
- **Immediate UI**: Menu shows "Loading..." indicator on app launch
- **Background Parsing**: Uses `Task.detached(priority: .userInitiated)` for off-main-thread parsing
- **In-Memory Cache**: `cachedSessions` stores parsed results
- **Auto-refresh**: Timer invalidates cache every 30 seconds
- **Cache Invalidation**: On `applicationDidBecomeActive` (user returns to app)

### Implementation
See `CCHistory.swift:50-74` for `loadSessionsAsync()` implementation.

---

## Feature: About Dialog

Show an About window with app version, repository link, and general information.

### Scope
- Menu item: "About CCHistory"
- NSAlert/NSPanel showing:
  - App name and version
  - GitHub repository link
  - Brief description
  - Credits

### Implementation Approach
1. **Menu Item**: Add to menu bar before "Quit"
2. **Version Source**: Read from Package.swift or Build version in Info.plist
3. **Dialog**: Use `NSAlert` with custom message or create `NSWindow` as About panel
4. **Link Handling**: Make repo URL clickable (via `NSAttributedString` with `.link` attribute)

---

## Feature: Improved Copy Feedback

Replace/supplement the notification with a more visible and intuitive copy confirmation.

### Current State
- Uses `UNUserNotificationCenter` (system notification)
- Can be intrusive and may be disabled by user
- No visual feedback in the menu itself

### Proposed Solutions
1. **Toast-style popup**: Small transient window near menu bar that fades out
2. **Menu item change**: Temporarily change clicked item text to "✓ Copied!" then revert
3. **Sound + visual**: Play subtle sound + show brief overlay
4. **Status bar tooltip**: Show brief message in status item button

### Implementation Considerations
- Should not block menu interaction
- Should be dismissible or auto-dismiss after 1-2 seconds
- Should work even if notifications are disabled

---

## Priority Considerations

| Feature | Impact | Complexity | Dependencies | Status |
|---------|--------|------------|--------------|--------|
| Async Loading | High | Medium | None | ✅ Done |
| Search | High | Medium | None | 📋 Todo |
| Custom Path (UI) | Medium | Low | Partial backend exists | 📋 Todo |
| About Dialog | Low | Low | None | 📋 Todo |
| Improved Copy Feedback | Medium | Low | None | 📋 Todo |

**Suggested order:**
1. ~~Async Loading~~ ✅ (completed)
2. About Dialog (quick win, independent)
3. Improved Copy Feedback (UX improvement)
4. Custom Path UI (complete the partial backend)
5. Search (larger feature, high value)
