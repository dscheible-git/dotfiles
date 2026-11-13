# dotfiles

Personal configuration files for a Debian/Ubuntu machine.

## What is included

| File | Target |
| --- | --- |
| `.zshrc` | `~/.zshrc` |
| `.zshenv` | `~/.zshenv` |
| `.p10k.zsh` | `~/.p10k.zsh` |
| `.config/tmux/tmux.conf` | `~/.config/tmux/tmux.conf` |
| `keyd/default.conf` | `/etc/keyd/default.conf` |

`install.sh` installs the packages and tools these configs rely on and then
symlinks the files above into `$HOME`. Existing files are backed up with a
timestamp suffix before being replaced.

The keyd config is copied to `/etc/keyd/default.conf` instead of being
symlinked, because keyd runs as root and its config supports executing
commands. A root-owned copy avoids pointing root at a user-writable file.

## Keyboard remapping

`keyd/default.conf` makes the German `<` key (keyd name `102nd`) a navigation
layer while held. Tapping `<` still produces `<`, and `Shift+<` / `AltGr+<`
still produce `>` / `|`.

```text
s e d f   →   ← ↑ ↓ →
u i o     →   7 8 9
j k l     →   4 5 6
m , .     →   1 2 3
space     →   0
```

## Usage

```sh
./install.sh
```

The installer is interactive and asks before each step whether to perform it:

- update apt and install the required packages
- install Oh My Zsh, `zsh-autosuggestions` and Powerlevel10k
- link the configuration files into `$HOME`
- install keyd and apply the German keyboard remapping
- install the MesloLGS NF Nerd Font
- install Rust via rustup
- install opencode
- install the tmux plugin manager and plugins

Every question defaults to yes. If no terminal is attached, the installer
answers yes to all of them and prints a warning.

The available steps install:

- apt packages: zsh, git, tmux, neovim, fzf, bat, ripgrep, lazygit, gdu,
  tree, xclip, build-essential, unzip and fontconfig
- Oh My Zsh with `zsh-autosuggestions` and Powerlevel10k
- TPM and the tmux plugins referenced by `tmux.conf`
- keyd, with the German `<` navigation layer copied to `/etc/keyd/default.conf`
- Rust via rustup and opencode
- MesloLGS NF, the font used by the Powerlevel10k prompt

After the first run, set zsh as the login shell if it is not already:

```sh
chsh -s "$(command -v zsh)"
```
