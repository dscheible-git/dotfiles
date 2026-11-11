#!/usr/bin/env bash
# Install upstream lazygit and apt hooks that keep it updated.
# Run with: sudo bash /home/dominik/lazygit-updater-install/install.sh
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "This installer must run as root: sudo bash $0" >&2
    exit 1
fi

SRC_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="/usr/local/lib/lazygit-updater"
STATE_DIR="/var/lib/lazygit-updater"
APT_CONF="/etc/apt/apt.conf.d/99lazygit-updater"

for cmd in curl tar sha256sum dpkg install; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "Missing required command: $cmd" >&2
        exit 1
    fi
done

install -d -m 0755 "$LIB_DIR" "$STATE_DIR"
install -m 0755 "$SRC_DIR/check.sh" "$LIB_DIR/check.sh"
install -m 0755 "$SRC_DIR/update.sh" "$LIB_DIR/update.sh"

cat >/usr/local/bin/lazygit-update <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
/usr/local/lib/lazygit-updater/check.sh
exec /usr/local/lib/lazygit-updater/update.sh
EOF
chmod 0755 /usr/local/bin/lazygit-update

# Determine the latest upstream release.
latest=$(curl -fsSL --connect-timeout 5 --max-time 15 \
    -o /dev/null -w '%{url_effective}' \
    "https://github.com/jesseduffield/lazygit/releases/latest" 2>/dev/null |
    sed -nE 's#.*/tag/v?([0-9]+\.[0-9]+\.[0-9]+)$#\1#p')
if [ -z "$latest" ]; then
    echo "Could not determine the latest lazygit release." >&2
    exit 1
fi

echo "Installing lazygit $latest to /usr/local/bin/lazygit ..."
if ! LAZYGIT_UPDATE_VERSION="$latest" "$LIB_DIR/update.sh"; then
    echo "lazygit installation failed." >&2
    exit 1
fi

installed=$(/usr/local/bin/lazygit --version 2>/dev/null |
    tr ',' '\n' |
    sed -nE "s/^[[:space:]]*version='?([^']+)'?[[:space:]]*$/\1/p" |
    head -n1)
if [ "$installed" != "$latest" ]; then
    echo "lazygit installation failed: expected $latest, got ${installed:-nothing}." >&2
    exit 1
fi

cat >"$APT_CONF" <<'EOF'
// lazygit updater: check upstream after apt update, install staged release after apt upgrade.
APT::Update::Post-Invoke-Success { "/usr/local/lib/lazygit-updater/check.sh"; };
DPkg::Post-Invoke { "/usr/local/lib/lazygit-updater/update.sh"; };
EOF
chmod 0644 "$APT_CONF"

# If the new apt configuration is invalid, remove it again so apt stays usable.
if ! apt-config dump >/dev/null 2>&1; then
    rm -f "$APT_CONF"
    echo "APT configuration is invalid after installing $APT_CONF; removed it again." >&2
    exit 1
fi

echo "Installed lazygit $latest."
echo
echo "apt hooks installed:"
echo "  apt update  -> check for a newer lazygit release"
echo "  apt upgrade -> install it if a newer release was staged"
echo
echo "Manual update: sudo lazygit-update"
echo "Log file:      /var/log/lazygit-updater.log"
if dpkg -s lazygit >/dev/null 2>&1; then
    echo
    echo "Note: the apt package 'lazygit' is still installed, but /usr/local/bin/lazygit"
    echo "takes precedence in PATH. You can remove the old package with:"
    echo "  sudo apt remove lazygit"
fi
