#!/usr/bin/env bash
# install-tools.sh — portable CLI tool installer for any dev host.
# Idempotent: skips tools that are already installed.
#
# Usage:
#   ./install-tools.sh              # install everything below
#   ./install-tools.sh --check      # just print status, don't install
#
# On a fresh host: git clone + run this. Then ./apply.sh to symlink config.

set -euo pipefail

# Color output
G="\033[32m"
Y="\033[33m"
D="\033[0m"
ok() { echo -e "${G}✓${D} $1"; }
have() { command -v "$1" >/dev/null 2>&1; }
skip() { echo -e "${Y}↷${D} $1 already installed"; }
install() { echo -e "${G}↓${D} installing $1..."; }

CHECK_ONLY=false
[[ "${1:-}" == "--check" ]] && CHECK_ONLY=true

# --- 1. OS package detection (apt for Ubuntu/Debian; pacman for CachyOS/Arch) ---
if command -v apt >/dev/null 2>&1; then
	PKG_MGR=apt
	pkg_install() { sudo apt update -qq && sudo apt install -y "$@"; }
elif command -v pacman >/dev/null 2>&1; then
	PKG_MGR=pacman
	pkg_install() { sudo pacman -S --needed --noconfirm "$@"; }
else
	echo "Unsupported package manager (no apt or pacman). Install manually." >&2
	exit 1
fi

# --- 2. Install apt/pacman-provided tools ---
TOOLS_BASE=(ripgrep fd bat eza jq vivid fzf tmux helix gh curl)
echo "=== base CLI tools (via $PKG_MGR) ==="
# Handle distro package-name differences
if [[ "$PKG_MGR" == "apt" ]]; then
	# apt names differ: ripgrep->rg, fd-find->fd, helix may not be in apt.
	# zsh-autosuggestions + zsh-syntax-highlighting provide the fish-like grey
	# ghost-text + arrow-accept + syntax colors that CachyOS bundles via
	# cachyos-config.zsh; on Ubuntu they're separate apt packages (the .zshrc
	# sources them from /usr/share/zsh-*/ paths).
	APT_PKGS=(ripgrep fd-find bat eza jq vivid fzf tmux gh curl zsh-autosuggestions zsh-syntax-highlighting)
	$CHECK_ONLY || pkg_install "${APT_PKGS[@]}"
	# Ubuntu ships fdfind/batcat instead of fd/bat — create the expected symlinks.
	# Gated on $CHECK_ONLY — don't sudo in --check mode
	if [[ -z "$CHECK_ONLY" ]]; then
		[[ -x /usr/bin/fdfind && ! -L /usr/local/bin/fd ]] && sudo ln -sf /usr/bin/fdfind /usr/local/bin/fd
		[[ -x /usr/bin/batcat && ! -L /usr/local/bin/bat ]] && sudo ln -sf /usr/bin/batcat /usr/local/bin/bat
	fi
else
	$CHECK_ONLY || pkg_install "${TOOLS_BASE[@]}"
fi
for t in rg fd bat eza jq vivid fzf tmux gh curl; do have "$t" && ok "$t" || skip "$t"; done

# --- 3. Node.js via nvm if node missing (pi install needs node >= 18) ---
have node && ok "node ($(node --version))" || {
	echo "=== node (via nvm) ==="
	$CHECK_ONLY || {
		curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
		export NVM_DIR="$HOME/.nvm"
		[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
		nvm install --lts
	}
}

# --- 4. Rust via rustup (cargo) ---
have cargo && ok "cargo ($(cargo --version))" || {
	echo "=== rust (via rustup) ==="
	$CHECK_ONLY || curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
}

# --- 5. uv (fast Python) ---
have uv && ok "uv ($(uv --version 2>/dev/null))" || {
	echo "=== uv ==="
	$CHECK_ONLY || curl -LsSf https://astral.sh/uv/install.sh | sh
}

# --- 6. pnpm (fast npm) ---
have pnpm && ok "pnpm ($(pnpm --version 2>/dev/null))" || {
	echo "=== pnpm ==="
	$CHECK_ONLY || npm install -g pnpm
}

# --- 7. bun (fast JS runtime) ---
have bun && ok "bun ($(bun --version 2>/dev/null))" || {
	echo "=== bun ==="
	$CHECK_ONLY || curl -fsSL https://bun.sh/install | bash
}

# --- 8. Powerlevel10k (standalone — does NOT require oh-my-zsh) ---
P10K_DIR="$HOME/.powerlevel10k"
[[ -d "$P10K_DIR/.git" ]] && skip "powerlevel10k" || {
	echo "=== powerlevel10k (standalone install) ==="
	$CHECK_ONLY || git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K_DIR"
}
# Hint to source it from zshrc — apply.sh's zshrc already sources ~/.p10k.zsh,
# but you also need: source ~/.powerlevel10k/powerlevel10k.zsh-theme
# We add that to zshrc.local.example so the user picks it up.
$CHECK_ONLY || {
	if ! grep -q "powerlevel10k.zsh-theme" "$HOME/.zshrc.local" 2>/dev/null; then
		echo "" >>"$HOME/.zshrc.local"
		echo "# --- Load powerlevel10k theme ---" >>"$HOME/.zshrc.local"
		echo 'source $HOME/.powerlevel10k/powerlevel10k.zsh-theme' >>"$HOME/.zshrc.local"
		echo "(added powerlevel10k theme load to ~/.zshrc.local)"
	fi
}

# --- 9. helix text editor (static binary from helix-editor.org) ---
have helix && ok "helix" || {
	echo "=== helix (static binary from helix-editor.org) ==="
	$CHECK_ONLY || {
		# Lookup latest Helix release tag dynamically.
		# Note: 'cargo install helix' is a different crate sharing the name 'helix'
		# (not the editor). The real editor is 'helix-term' on cargo, or download the
		# prebuilt static binary from GitHub releases.
		HELIOS_VER=$(curl -fsSL "https://api.github.com/repos/helix-editor/helix/releases/latest" 2>/dev/null |
			python3 -c "import json,sys; print(json.load(sys.stdin).get('tag_name',''))" 2>/dev/null)
		if [[ -z "$HELIOS_VER" ]]; then
			echo "  (couldn't look up latest helix version; install manually from helix-editor.org)"
		else
			mkdir -p "$HOME/.local"
			# NOTE: asset name is 'aarch64-linux', NOT 'aarch64-linux-gnu'
			ASSET="helix-${HELIOS_VER}-aarch64-linux.tar.xz"
			URL="https://github.com/helix-editor/helix/releases/download/${HELIOS_VER}/${ASSET}"
			if curl -fsSL "$URL" -o /tmp/helix.tar.xz 2>/dev/null; then
				tar -xf /tmp/helix.tar.xz -C "$HOME/.local" --strip-components=1 &&
					rm /tmp/helix.tar.xz &&
					ln -sf "$HOME/.local/bin/hx" "$HOME/.local/bin/helix" 2>/dev/null &&
					echo "  installed helix $HELIOS_VER to ~/.local/"
			else
				echo "  (download failed; install manually from helix-editor.org)"
			fi
		fi
	}
}

echo
echo "=== tools-install: done ==="
echo "Next: ./apply.sh to symlink zsh config + ~/.local/bin scripts into place."
