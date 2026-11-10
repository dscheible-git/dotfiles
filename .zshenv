# Load Rust toolchain (installed by install.sh via rustup)
if [ -f "$HOME/.cargo/env" ]; then
    . "$HOME/.cargo/env"
fi

# opencode. typeset -U deduplicates the path array, so nested shells and an
# inherited PATH do not make the same directory appear multiple times.
typeset -U path
path=("$HOME/.opencode/bin" $path)
