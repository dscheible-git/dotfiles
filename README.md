# dotfiles

Personal configuration files for a Debian/Ubuntu machine.

## What is included

| File | Target |
| --- | --- |
| `.zshrc` | `~/.zshrc` |
| `.zshenv` | `~/.zshenv` |
| `.p10k.zsh` | `~/.p10k.zsh` |
| `.config/tmux/tmux.conf` | `~/.config/tmux/tmux.conf` |

`install.sh` installs the packages and tools these configs rely on and then
symlinks the files above into `$HOME`. Existing files are backed up with a
timestamp suffix before being replaced.

## Usage

```sh
./install.sh              # full install
./install.sh --no-fonts   # skip the MesloLGS NF font download
./install.sh --no-link    # install packages only, do not link configs
```

The script installs:

- apt packages: zsh, git, tmux, neovim, fzf, bat, ripgrep, lazygit, gdu,
  tree, xclip, build-essential, unzip and fontconfig
- Oh My Zsh with `zsh-autosuggestions` and Powerlevel10k
- TPM and the tmux plugins referenced by `tmux.conf`
- Rust via rustup and opencode
- MesloLGS NF, the font used by the Powerlevel10k prompt

After the first run, set zsh as the login shell if it is not already:

```sh
chsh -s "$(command -v zsh)"
```
