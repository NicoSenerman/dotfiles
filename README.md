# dotfiles

Personal dev environment setup — shell config, themes, CLI tools install script.

## Quick start on a fresh host

```bash
git clone https://github.com/NicoSenerman/dotfiles ~/Documents/Projects/dotfiles
cd ~/Documents/Projects/dotfiles
./install-tools.sh        # installs the portable CLI tools via apt/cargo/npm
./apply.sh                # symlinks zsh config + .local/bin scripts into place
```

After apply.sh, restart your shell or `exec zsh`.

## Secrets

API keys / tokens are NOT in this repo. Load them via a per-host file that's not
tracked by git (e.g. ~/.config/secrets/env, sourced from ~/.zshrc.local).
See apply.sh + zsh/zshrc.local.example for the pattern.

## Structure

- `zsh/`         — zsh config (zshrc main + p10k config + zshrc.local for secrets)
- `bin/`         — ~/.local/bin scripts (host-agnostic ones)
- `tools/`       — install-tools.sh + the tool list
- `apply.sh`     — symlinks everything into place
