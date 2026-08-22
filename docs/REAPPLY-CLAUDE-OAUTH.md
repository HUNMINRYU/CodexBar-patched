# Re-apply Claude OAuth after a Sparkle / brew overwrite

Official CodexBar 0.54.x remaps `securityCLIExperimental` back to
`securityFramework`. If Claude usage source is OAuth and CodexBar's own
keychain cache item needs a prompt, the CLI/app fails with:

`Claude OAuth credentials read failed: CodexBar cache is temporarily unavailable.`

or, once the file fallback exists but the access token is stale:

`Claude OAuth token expired. CodexBar CLI does not launch Claude to refresh credentials.`

Claude Code itself can still be logged in. The official binary will not
read `Claude Code-credentials` without UI.

## Fast path (no rebuild)

```bash
bash Scripts/restore-claude-oauth-credentials.sh
codexbar usage --provider claude --source oauth --format json --pretty
```

Writes `~/.claude/.credentials.json` (0600) from the Claude Code keychain
item. If that token is expired, the script refreshes it (Claude CLI
User-Agent) and updates both the file and `Claude Code-credentials`.
Restart CodexBar or open the menu once. Access tokens last about 8 hours.

## Patched-app path

This branch (`fix/claude-oauth-0.54.1`) keeps the experimental Security
CLI reader. After Sparkle replaces `/Applications/CodexBar.app`:

```bash
git fetch origin
git rebase origin/main   # resolve if official moved
./Scripts/package_app.sh release
```

Then install the packaged app and turn off Sparkle if you do not want the
next official build to overwrite it.
