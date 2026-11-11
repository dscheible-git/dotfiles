#!/usr/bin/env bash
# Check GitHub for a newer lazygit release and stage it for the next apt upgrade.
# This script is intended to be run by APT::Update::Post-Invoke-Success.
set -u

REPO="jesseduffield/lazygit"
BIN="${LAZYGIT_BIN:-/usr/local/bin/lazygit}"
STATE_DIR="${LAZYGIT_UPDATER_STATE_DIR:-/var/lib/lazygit-updater}"
PENDING="$STATE_DIR/pending-version"
LOG="${LAZYGIT_UPDATER_LOG:-/var/log/lazygit-updater.log}"
LOCK="${LAZYGIT_UPDATER_LOCK:-/var/lock/lazygit-updater.lock}"

log() {
    printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >>"$LOG" 2>/dev/null || true
}

say() {
    printf 'lazygit: %s\n' "$*" >&2
}

installed_version() {
    # Split on commas so "git version=..." is not mistaken for "version=...".
    "$BIN" --version 2>/dev/null |
        tr ',' '\n' |
        sed -nE "s/^[[:space:]]*version='?([^']+)'?[[:space:]]*$/\1/p" |
        head -n1
}

latest_version() {
    local url
    url=$(curl -fsSL --connect-timeout 5 --max-time 15 \
        -o /dev/null -w '%{url_effective}' \
        "https://github.com/$REPO/releases/latest" 2>/dev/null) || return 1
    printf '%s\n' "$url" |
        sed -nE 's#.*/tag/v?([0-9]+\.[0-9]+\.[0-9]+)$#\1#p'
}

mkdir -p "$STATE_DIR" 2>/dev/null || true
touch "$LOG" 2>/dev/null || true

# Do not run twice concurrently (e.g. two apt processes at the same time).
exec 9>"$LOCK" 2>/dev/null || true
if command -v flock >/dev/null 2>&1; then
    flock -n 9 || exit 0
fi

latest=$(latest_version)
if [ -z "${latest:-}" ]; then
    log "check failed: could not determine latest release"
    exit 0
fi

installed=$(installed_version)
if [ -z "${installed:-}" ]; then
    printf '%s\n' "$latest" >"$PENDING"
    log "installed version unknown; staged $latest"
    say "lazygit $latest is available; it will be installed on the next apt upgrade."
    exit 0
fi

if dpkg --compare-versions "$latest" gt "$installed"; then
    printf '%s\n' "$latest" >"$PENDING"
    log "staged $latest (installed: $installed)"
    say "new version $latest available (installed: $installed); it will be installed on the next apt upgrade."
else
    rm -f "$PENDING"
    log "up to date (installed: $installed, latest: $latest)"
fi

exit 0
