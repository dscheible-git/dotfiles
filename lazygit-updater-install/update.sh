#!/usr/bin/env bash
# Install the lazygit release staged by check.sh.
# This script is intended to be run by DPkg::Post-Invoke (i.e. after apt upgrade).
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

mkdir -p "$STATE_DIR" 2>/dev/null || true
touch "$LOG" 2>/dev/null || true

# Do not run twice concurrently (e.g. two apt processes at the same time).
exec 9>"$LOCK" 2>/dev/null || true
if command -v flock >/dev/null 2>&1; then
    flock -n 9 || exit 0
fi

version="${LAZYGIT_UPDATE_VERSION:-}"
if [ -z "$version" ]; then
    [ -s "$PENDING" ] || exit 0
    version=$(head -n1 "$PENDING" | tr -d '[:space:]')
fi

# Only accept a plain release version. This keeps the value safe for URLs and paths.
if ! [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    log "invalid staged version: '$version'"
    rm -f "$PENDING"
    exit 0
fi

installed=$(installed_version)
if [ -n "${installed:-}" ] && ! dpkg --compare-versions "$version" gt "$installed"; then
    rm -f "$PENDING"
    exit 0
fi

case "$(uname -m)" in
    x86_64 | amd64) asset="linux_x86_64" ;;
    aarch64 | arm64) asset="linux_arm64" ;;
    armv7l | armv6l) asset="linux_armv6" ;;
    i386 | i486 | i586 | i686) asset="linux_32-bit" ;;
    *)
        log "unsupported architecture: $(uname -m)"
        say "unsupported architecture $(uname -m); not updating."
        exit 0
        ;;
esac

tmp=$(mktemp -d "${TMPDIR:-/tmp}/lazygit-updater.XXXXXX") || {
    log "mktemp failed"
    exit 0
}
trap 'rm -rf "$tmp"' EXIT

base="https://github.com/$REPO/releases/download/v$version"
archive="lazygit_${version}_${asset}.tar.gz"

if ! curl -fsSL --retry 2 --connect-timeout 10 --max-time 120 \
    -o "$tmp/$archive" "$base/$archive"; then
    log "download failed: $base/$archive"
    say "download of lazygit $version failed; will retry on the next apt upgrade."
    exit 0
fi

if ! curl -fsSL --retry 2 --connect-timeout 10 --max-time 30 \
    -o "$tmp/checksums.txt" "$base/checksums.txt"; then
    log "checksum download failed for $version"
    say "checksum download for lazygit $version failed; will retry on the next apt upgrade."
    exit 0
fi

checksum_line=$(grep -F "  $archive" "$tmp/checksums.txt" | head -n1 || true)
if [ -z "$checksum_line" ]; then
    log "checksum entry missing for $archive"
    say "checksum entry for lazygit $version is missing; aborting."
    exit 0
fi

if ! (cd "$tmp" && printf '%s\n' "$checksum_line" | sha256sum -c --status -); then
    log "checksum verification failed for $archive"
    say "checksum verification for lazygit $version failed; aborting."
    exit 0
fi

if ! tar -xzf "$tmp/$archive" -C "$tmp" lazygit; then
    log "extraction failed for $archive"
    say "extraction of lazygit $version failed; aborting."
    exit 0
fi

install -d -m 0755 "$(dirname "$BIN")"
if ! install -m 0755 "$tmp/lazygit" "$BIN.new"; then
    log "install failed: $BIN"
    say "installing lazygit $version failed."
    exit 0
fi
if ! mv -f "$BIN.new" "$BIN"; then
    log "mv failed: $BIN"
    say "installing lazygit $version failed."
    exit 0
fi

now=$(installed_version)
if [ "$now" = "$version" ]; then
    rm -f "$PENDING"
    log "updated to $version"
    say "updated to $version."
else
    log "installed $version but binary reports '$now'"
    say "lazygit $version installed, but the version check reports '$now'."
fi

exit 0
