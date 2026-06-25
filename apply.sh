#!/usr/bin/env bash
# apply.sh — symlink zsh config + ~/.local/bin scripts into place.
# Idempotent: re-running refreshes symlinks without clobbering local customizations.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- 1. Back up existing ~/.zshrc if it's a real file (not a symlink we manage) ---
ZSHRC="$HOME/.zshrc"
if [[ -L "$ZSHRC" ]]; then
	rm "$ZSHRC"
elif [[ -f "$ZSHRC" ]]; then
	backup="$ZSHRC.pre-dotfiles.$(date +%s)"
	mv "$ZSHRC" "$backup"
	echo "Backed up existing ~/.zshrc -> $(basename "$backup")"
fi
ln -sf "$REPO_DIR/zsh/zshrc" "$ZSHRC"
echo "Linked ~/.zshrc -> $REPO_DIR/zsh/zshrc"

# --- 2. Copy ~/.zshrc.local.example to ~/.zshrc.local if ~/.zshrc.local doesn't exist ---
if [[ ! -f "$HOME/.zshrc.local" ]]; then
	cp "$REPO_DIR/zsh/zshrc.local.example" "$HOME/.zshrc.local"
	chmod 600 "$HOME/.zshrc.local" # secrets, restrict perms
	echo "Created ~/.zshrc.local (chmod 600) from example — edit it to add API keys + laptop-only aliases"
else
	echo "~/.zshrc.local already exists (kept as-is)"
fi

# --- 3. Back up + link ~/.p10k.zsh if it exists in repo ---
P10K_REPO="$REPO_DIR/zsh/p10k.zsh"
P10K_HOME="$HOME/.p10k.zsh"
if [[ -f "$P10K_REPO" ]]; then
	if [[ -L "$P10K_HOME" ]]; then rm "$P10K_HOME"; fi
	if [[ -f "$P10K_HOME" ]]; then
		mv "$P10K_HOME" "$P10K_HOME.pre-dotfiles.$(date +%s)"
	fi
	ln -sf "$P10K_REPO" "$P10K_HOME"
	echo "Linked ~/.p10k.zsh -> $REPO_DIR/zsh/p10k.zsh"
fi

# --- 4. Symlink every script in bin/ into ~/.local/bin/ ---
mkdir -p "$HOME/.local/bin"
for script in "$REPO_DIR"/bin/*; do
	[[ -f "$script" ]] || continue
	name="$(basename "$script")"
	target="$HOME/.local/bin/$name"
	if [[ -L "$target" ]]; then rm "$target"; fi
	ln -sf "$script" "$target"
	# Ensure source is executable
	chmod +x "$script"
done
echo "Linked $(ls "$REPO_DIR"/bin/* 2>/dev/null | wc -l) scripts into ~/.local/bin/"

# --- 5. Suggest next steps ---
echo
echo "=== apply.sh done ==="
echo "Next steps:"
echo "  1. Edit ~/.zshrc.local to add API keys + laptop-only aliases"
echo "  2. Run ./install-tools.sh if you haven't (installs rg, fd, bat, eza, jq, vivid, fzf, tmux, helix, gh, etc.)"
echo "  3. Restart shell: 'exec zsh'"
