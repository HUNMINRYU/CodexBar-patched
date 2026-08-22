#!/usr/bin/env bash
# Restore Claude OAuth for official CodexBar without rebuilding.
# Official 0.54.x remaps securityCLIExperimental -> securityFramework, so the
# usage fetch cannot read Claude Code-credentials when CodexBar's own cache
# item requires a Keychain prompt. The documented file fallback is
# ~/.claude/.credentials.json.
#
# Access tokens last ~8h. If the keychain/file copy is expired, this script
# refreshes via platform.claude.com (Claude CLI User-Agent) and writes both
# the file and the Claude Code keychain item.
set -euo pipefail

DEST="${HOME}/.claude/.credentials.json"
SERVICE="Claude Code-credentials"
ACCOUNT="$(id -un)"
CLIENT_ID="9d1c250a-e61b-44d9-88ed-5944d1962f5e"
ENDPOINT="https://platform.claude.com/v1/oauth/token"

mkdir -p "${HOME}/.claude"
umask 077

security find-generic-password -s "${SERVICE}" -a "${ACCOUNT}" -w \
  | DEST="${DEST}" SERVICE="${SERVICE}" ACCOUNT="${ACCOUNT}" \
    CLIENT_ID="${CLIENT_ID}" ENDPOINT="${ENDPOINT}" python3 -c '
import json, os, subprocess, sys, time, urllib.parse, urllib.request
from pathlib import Path

dest = Path(os.environ["DEST"])
service = os.environ["SERVICE"]
account = os.environ["ACCOUNT"]
client_id = os.environ["CLIENT_ID"]
endpoint = os.environ["ENDPOINT"]

data = json.loads(sys.stdin.read())
oauth = data.get("claudeAiOauth")
if not isinstance(oauth, dict) or not oauth.get("accessToken"):
    raise SystemExit("Claude Code-credentials has no claudeAiOauth.accessToken")

expires_at = oauth.get("expiresAt")
if isinstance(expires_at, (int, float)) and expires_at > 1e12:
    expires_at_s = expires_at / 1000.0
else:
    expires_at_s = expires_at
now = time.time()
need_refresh = not isinstance(expires_at_s, (int, float)) or expires_at_s <= now + 120

if need_refresh:
    refresh = oauth.get("refreshToken") or ""
    if not refresh:
        raise SystemExit("access token expired and no refreshToken")
    body = urllib.parse.urlencode({
        "grant_type": "refresh_token",
        "refresh_token": refresh,
        "client_id": client_id,
    }).encode()
    req = urllib.request.Request(
        endpoint,
        data=body,
        method="POST",
        headers={
            "Content-Type": "application/x-www-form-urlencoded",
            "Accept": "application/json",
            "User-Agent": "claude-cli/2.1.231 (external, cli)",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            payload = json.loads(resp.read().decode())
    except urllib.error.HTTPError as exc:
        raise SystemExit(f"refresh HTTP {exc.code}: {exc.read().decode()[:200]}") from exc
    access = payload.get("access_token") or ""
    if not access:
        raise SystemExit("refresh returned no access_token")
    now_ms = int(now * 1000)
    oauth["accessToken"] = access
    if payload.get("refresh_token"):
        oauth["refreshToken"] = payload["refresh_token"]
    oauth["expiresAt"] = now_ms + int(payload.get("expires_in") or 28800) * 1000
    if payload.get("refresh_token_expires_in"):
        oauth["refreshTokenExpiresAt"] = now_ms + int(payload["refresh_token_expires_in"]) * 1000
    data["claudeAiOauth"] = oauth
    print("refreshed expired Claude OAuth token")
else:
    print("existing Claude OAuth token still valid")

blob = json.dumps(data, separators=(",", ":"))
tmp = dest.with_suffix(".json.tmp")
tmp.write_text(blob)
tmp.chmod(0o600)
tmp.replace(dest)
proc = subprocess.run(
    ["security", "add-generic-password", "-U", "-s", service, "-a", account, "-w", blob],
    capture_output=True,
    text=True,
    check=False,
)
if proc.returncode != 0:
    raise SystemExit(f"keychain update failed: {(proc.stderr or proc.stdout)[:200]}")
print(f"wrote {dest} mode 0600")
print("verify: codexbar usage --provider claude --source oauth --format json --pretty")
'
