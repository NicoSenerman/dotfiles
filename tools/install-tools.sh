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
	# apt names differ: ripgrep->rg, fd-find->fd, helix may not be in apt
	APT_PKGS=(ripgrep fd-find bat eza jq vivid fzf tmux gh curl)
	$CHECK_ONLY || pkg_install "${APT_PKGS[@]}"
	# Symlink fd-find -> fd on Ubuntu (Ubuntu refuses to ship a binary called "fd")
	[[ ! -L /usr/local/bin/fd && "$PKG_MGR" == "apt" ]] && sudo ln -sf "$(command -v fdfind 2>/dev/null)" /usr/local/bin/fd true
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

# --- 8. Powerlevel10k + its recommended fonts ---
[[ -d ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k ]] && skip "powerlevel10k" || {
	echo "=== powerlevel10k (zsh prompt) ==="
	$CHECK_ONLY || {
		# oh-my-zsh is the assumed loader (the laptop uses cachyos-zsh which wraps it);
		# if not present, install it first
		[[ -d ~/.oh-my-zsh ]] || {
			sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
		}
		git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \
			${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
	}
}

# --- 9. vivid themes (for LS_COLORS) ---
have vivid && ok "vivid (themes via $(vivid --version 2>/dev/null || echo 'n/a'))" || skip "vivid (themes)"

# --- 10. helix text editor (apt may not have it; use cargo if missing) ---
have helix && ok "helix" || {
	echo "=== helix (via cargo if not in packages) ==="
	$CHECK_ONLY || cargo install helix || echo "  (helix install failed; install manually from helix-editor.org)"
}

echo
echo "=== tools-install: done ==="
echo "Next: ./apply.sh to symlink zsh config + ~/.local/bin scripts into place."
