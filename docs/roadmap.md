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

## Feature: Custom `.claude` Folder Location

Allow users to specify a custom location for their Claude Code projects directory.

### Scope
- Single global setting (not per-project overrides)
- Preferences/Settings window with path picker
- Path validation and error handling
- UserDefaults persistence

### Implementation Approach
1. **Settings Window**: Create `NSWindow` or `NSPanel` with:
   - Text field showing current path
   - "Browse..." button with `NSOpenPanel`
   - "Reset to Default" button (`~/.claude`)
2. **Storage**: Use `UserDefaults.standard` with key like `claudeProjectsPath`
3. **Integration**: Update `HistoryParser` to read from custom path instead of hardcoded `NSHomeDirectory()/.claude/projects`
4. **Validation**: Check path exists and contains expected structure before applying

### Open Questions
- Should changes require app restart or take effect immediately?
- Where to access settings? (Menu item: "Preferences..." or "Settings...")
- What to show if custom path is invalid? (Fallback to default + error dialog)

---

## Feature: Performance Improvements (Async Loading)

Eliminate the blocking UI delay on app launch by implementing asynchronous session parsing.

### Current Problem
- `HistoryParser.parseSessionsFromProjects()` runs synchronously on main thread
- App shows nothing until all sessions are parsed
- For large histories, this causes noticeable delay (seconds)

### Proposed Solution
1. **Immediate UI**: Show menu with "Loading..." indicator on app launch
2. **Background Parsing**: Move parsing to background using Swift concurrency:
   ```swift
   Task.detached(priority: .userInitiated) {
       let sessions = await historyParser.parseSessionsFromProjects()
       await MainActor.run {
           self.buildMenu(with: sessions)
       }
   }
   ```
3. **In-Memory Cache**: Store parsed sessions to avoid re-parsing
4. **Re-scan Strategy**: Only re-parse when app "reopens" (menu bar apps receive `applicationDidBecomeActive` or similar events)

### Implementation Changes
- Refactor `HistoryParser` to use `async` functions
- Add loading state to `AppDelegate`
- Implement cache invalidation logic (time-based or manual refresh)
- Consider debouncing rapid menu open/close events

### Open Questions
- How often to invalidate cache? (Time-based vs. manual "Refresh" action vs. filesystem watcher)
- Should we show session count while loading? (e.g., "Loaded 12/50 sessions...")
- What if user tries to interact during load? (Disable menu items vs. show partial results)

---

## Priority Considerations

| Feature | Impact | Complexity | Dependencies |
|---------|--------|------------|--------------|
| Async Loading | High | Medium | None |
| Search | High | Medium | Async Loading (for better UX) |
| Custom Path | Low | Low | None |

**Suggested order:**
1. Async Loading (foundational performance fix)
2. Search (high-value feature, builds on async work)
3. Custom Path (lower priority, independent)
