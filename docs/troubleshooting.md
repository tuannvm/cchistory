# Troubleshooting

## "No sessions found"

**Symptoms:** Menu shows "No sessions found" message.

**Solutions:**
- Ensure Claude Code has been used at least once
- Check that `~/.claude/projects/` exists: `ls ~/.claude/projects/`
- Verify session files exist: `ls ~/.claude/projects/*/*.jsonl`
- Check file permissions: `ls -la ~/.claude/projects/`

## Build errors

**Symptoms:** Build fails with code signing or Swift errors.

**Solutions:**
- Ensure Xcode or Swift toolchain is installed: `xcode-select -p`
- Ensure `DEVELOPER_IDENTITY` is set (for Makefile): `echo $DEVELOPER_IDENTITY`
- Find your identity: `security find-identity -v -p codesigning`
- Try verbose build: `swift build --verbose`
- Try using Makefile: `make build`

## Git branch not showing

**Symptoms:** Sessions show project name but no git branch.

**Solutions:**
- Ensure the project is a git repository: `git -C /path/to/project rev-parse --git-dir`
- Check that git is accessible: `which git`
- Verify remote origin exists: `git -C /path/to/project remote get-url origin`

## "App is damaged" error

**Symptoms:** macOS shows "CCHistory.app is damaged and can't be opened" when launching.

**Solutions:**
- Download pre-signed builds from [Releases](https://github.com/tuannvm/cchistory/releases)
- When building from source, ensure `DEVELOPER_IDENTITY` is set correctly
- Verify signature: `codesign -vvv CCHistory.app`

## Menu bar icon missing

**Symptoms:** App launches but no icon appears in menu bar.

**Solutions:**
- Check System Settings → Privacy & Security → Accessibility (menu bar apps sometimes need this)
- Verify app is running: `pgrep -lf CCHistory`
- Try restarting: `killall CCHistory && open CCHistory.app`

## Resume command doesn't work

**Symptoms:** Pasted command fails to resume session.

**Solutions:**
- Verify session ID is valid: `ls ~/.claude/projects/*/SESSION_ID.jsonl`
- Ensure project path exists: `cd "PROJECT_PATH"`
- Check Claude Code is installed: `which claude`

## Search not working

**Symptoms:** Search returns no results even though sessions exist.

**Solutions:**
- Check if search index is built: Search works after initial load completes (wait for "Loading..." to disappear)
- Press ESC to clear search field: Sometimes cached search query persists
- Refresh menu with Cmd+R: This rebuilds the search index
- Check session limit: Only first 200 sessions are indexed for search
- Verify search query: Search is case-insensitive and matches names, paths, branches, and message content
