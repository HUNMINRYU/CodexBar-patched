#!/usr/bin/env bash
# Restore Claude OAuth for official CodexBar without rebuilding.
# Official 0.54.x remaps securityCLIExperimental -> securityFramework, so the
# usage fetch cannot read Claude Code-credentials when CodexBar's own cache
# item requires a Keychain prompt. The documented file fallback is
# ~/.claude/.credentials.json.
set -euo pipefail

DEST="${HOME}/.claude/.credentials.json"
SERVICE="Claude Code-credentials"

mkdir -p "${HOME}/.claude"
umask 077

security find-generic-password -s "${SERVICE}" -w | DEST="${DEST}" python3 -c '
import json, os, sys
from pathlib import Path

dest = Path(os.environ["DEST"])
data = json.loads(sys.stdin.read())
oauth = data.get("claudeAiOauth")
if not isinstance(oauth, dict) or not oauth.get("accessToken"):
    raise SystemExit("Claude Code-credentials has no claudeAiOauth.accessToken")

tmp = dest.with_suffix(".json.tmp")
tmp.write_text(json.dumps(data, separators=(",", ":")))
tmp.chmod(0o600)
tmp.replace(dest)
print(f"wrote {dest} mode 0600")
print("verify: codexbar usage --provider claude --source oauth --format json --pretty")
'
