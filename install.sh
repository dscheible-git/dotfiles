#!/usr/bin/env bash
#
# Dotfiles installer for dominik.
#
# Installs system packages, terminal tooling, shell/tmux plugins, fonts and
# links the configuration files from this repository into $HOME.
#
# Usage:
#   ./install.sh              # full install
#   ./install.sh --no-fonts   # skip Nerd Font installation
#   ./install.sh --no-link    # only install packages, do not link configs
#   ./install.sh --help
#
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

INSTALL_FONTS=1
LINK_CONFIGS=1

info()  { printf '\n==> %s\n' "$*"; }
warn()  { printf 'WARNING: %s\n' "$*" >&2; }

usage() {
    sed -n '2,13p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    exit 0
}

for arg in "$@"; do
    case "$arg" in
        --no-fonts) INSTALL_FONTS=0 ;;
        --no-link)  LINK_CONFIGS=0 ;;
        -h|--help)  usage ;;
        *) warn "Unknown option: $arg"; usage ;;
    esac
done

if [ "$(id -u)" -eq 0 ]; then
    SUDO=()
else
    SUDO=(sudo)
fi

# ---------------------------------------------------------------------------
# Packages
# ---------------------------------------------------------------------------

# Needed by the shell config, tmux, neovim and this installer.
CORE_PACKAGES=(
    zsh git curl wget
    tmux neovim
    fzf bat ripgrep
    lazygit gdu tree
    xclip
    build-essential
    unzip fontconfig
)

install_apt_packages() {
    if ! command -v apt-get >/dev/null 2>&1; then
        warn "apt-get not found. This installer currently supports Debian/Ubuntu only."
        exit 1
    fi

    info "Updating apt package lists"
    "${SUDO[@]}" apt-get update

    info "Installing apt packages"
    DEBIAN_FRONTEND=noninteractive "${SUDO[@]}" apt-get install -y "${CORE_PACKAGES[@]}"
}

# ---------------------------------------------------------------------------
# Shell: Oh My Zsh, plugins and theme
# ---------------------------------------------------------------------------

install_oh_my_zsh() {
    local omz_dir="$HOME/.oh-my-zsh"
    local custom_dir="$omz_dir/custom"

    if [ ! -d "$omz_dir" ]; then
        info "Installing Oh My Zsh"
        git clone https://github.com/ohmyzsh/ohmyzsh.git "$omz_dir"
    else
        echo "    Oh My Zsh already installed"
    fi

    if [ ! -d "$custom_dir/plugins/zsh-autosuggestions" ]; then
        info "Installing zsh-autosuggestions"
        git clone https://github.com/zsh-users/zsh-autosuggestions.git \
            "$custom_dir/plugins/zsh-autosuggestions"
    else
        echo "    zsh-autosuggestions already installed"
    fi

    if [ ! -d "$custom_dir/themes/powerlevel10k" ]; then
        info "Installing Powerlevel10k"
        git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \
            "$custom_dir/themes/powerlevel10k"
    else
        echo "    Powerlevel10k already installed"
    fi
}

# ---------------------------------------------------------------------------
# Config links
# ---------------------------------------------------------------------------

link_file() {
    local src="$1"
    local dest="$2"

    if [ ! -e "$src" ]; then
        warn "Source does not exist, skipping: $src"
        return
    fi

    mkdir -p "$(dirname "$dest")"

    if [ -L "$dest" ] && [ "$(readlink -f "$dest")" = "$(readlink -f "$src")" ]; then
        echo "    already linked: $dest"
        return
    fi

    if [ -e "$dest" ] || [ -L "$dest" ]; then
        local backup="${dest}.bak.$(date +%Y%m%d%H%M%S)"
        echo "    backing up $dest -> $backup"
        mv "$dest" "$backup"
    fi

    echo "    $src -> $dest"
    ln -s "$src" "$dest"
}

link_configs() {
    info "Linking configuration files"

    link_file "$DOTFILES_DIR/.zshrc"    "$HOME/.zshrc"
    link_file "$DOTFILES_DIR/.zshenv"   "$HOME/.zshenv"
    link_file "$DOTFILES_DIR/.p10k.zsh" "$HOME/.p10k.zsh"

    # tmux reads ~/.tmux.conf before ~/.config/tmux/tmux.conf. Move a legacy
    # ~/.tmux.conf out of the way so the XDG config below is actually used.
    if [ -e "$HOME/.tmux.conf" ] || [ -L "$HOME/.tmux.conf" ]; then
        local backup="$HOME/.tmux.conf.bak.$(date +%Y%m%d%H%M%S)"
        echo "    moving legacy ~/.tmux.conf -> $backup"
        mv "$HOME/.tmux.conf" "$backup"
    fi
    link_file "$DOTFILES_DIR/.config/tmux/tmux.conf" "$HOME/.config/tmux/tmux.conf"
}

# ---------------------------------------------------------------------------
# Fonts (Powerlevel10k works best with a Nerd Font)
# ---------------------------------------------------------------------------

install_fonts() {
    local font_dir="$HOME/.local/share/fonts"
    local base_url="https://github.com/romkatv/powerlevel10k-media/raw/master"
    local font

    mkdir -p "$font_dir"
    for font in \
        "MesloLGS%20NF%20Regular.ttf" \
        "MesloLGS%20NF%20Bold.ttf" \
        "MesloLGS%20NF%20Italic.ttf" \
        "MesloLGS%20NF%20Bold%20Italic.ttf"
    do
        local name="${font//%20/ }"
        if [ -f "$font_dir/$name" ]; then
            echo "    $name already installed"
        else
            echo "    downloading $name"
            curl -fLo "$font_dir/$name" "$base_url/$font"
        fi
    done

    if command -v fc-cache >/dev/null 2>&1; then
        fc-cache -f "$font_dir" >/dev/null
    fi
}

# ---------------------------------------------------------------------------
# Other tools
# ---------------------------------------------------------------------------

install_rust() {
    if [ -x "$HOME/.cargo/bin/rustc" ]; then
        echo "    Rust toolchain already installed"
        return
    fi

    info "Installing Rust via rustup"
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs |
        sh -s -- -y --no-modify-path
}

install_opencode() {
    if [ -x "$HOME/.opencode/bin/opencode" ] || command -v opencode >/dev/null 2>&1; then
        echo "    opencode already installed"
        return
    fi

    info "Installing opencode"
    curl -fsSL https://opencode.ai/install | bash -s -- --no-modify-path
}

install_tmux_plugins() {
    local tpm_dir="$HOME/.tmux/plugins/tpm"

    if [ ! -d "$tpm_dir" ]; then
        info "Installing tmux plugin manager (TPM)"
        git clone --depth=1 https://github.com/tmux-plugins/tpm "$tpm_dir"
    else
        echo "    TPM already installed"
    fi

    if [ -x "$tpm_dir/bin/install_plugins" ]; then
        info "Installing tmux plugins"
        "$tpm_dir/bin/install_plugins" || warn "Could not install tmux plugins automatically"
    fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

info "Installing dotfiles from $DOTFILES_DIR"

install_apt_packages
install_oh_my_zsh

if [ "$LINK_CONFIGS" -eq 1 ]; then
    link_configs
fi

if [ "$INSTALL_FONTS" -eq 1 ]; then
    install_fonts
fi

install_rust
install_opencode

# Must run after the tmux config is linked so TPM sees the @plugin entries.
install_tmux_plugins

if [ "$SHELL" != "$(command -v zsh)" ]; then
    echo
    echo "Your login shell is $SHELL."
    echo "Make zsh the default with: chsh -s $(command -v zsh)"
fi

info "Done. Restart your shell or run: exec zsh"
