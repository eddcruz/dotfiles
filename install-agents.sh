#!/usr/bin/env bash
# =============================================================================
#  install-agents.sh — Installs the security rules for AI coding agents
#  Claude Code (~/.claude/settings.json) and Codex (~/.codex/config.toml).
#  Antigravity (Gemini) is configured by hand: see agents/antigravity-rules.md.
#
#  Usage:  ./install-agents.sh      (from the dotfiles folder, no sudo)
#  Safe to re-run. Backs up existing files before replacing them.
# =============================================================================
set -Eeuo pipefail
cd "$(dirname "$0")"

if [[ $EUID -eq 0 ]]; then echo "Do not use sudo. Run: ./install-agents.sh"; exit 1; fi

backup() { [[ -f "$1" ]] && cp "$1" "$1.bak.$(date +%s)" || true; }

# Claude Code: rules use ~ so they work for any user as-is
mkdir -p "$HOME/.claude"
backup "$HOME/.claude/settings.json"
cp agents/claude-settings.json "$HOME/.claude/settings.json"
echo "Claude Code rules -> ~/.claude/settings.json"

# Codex: TOML has no ~ expansion, so __HOME__ becomes your real home folder
mkdir -p "$HOME/.codex"
backup "$HOME/.codex/config.toml"
sed "s|__HOME__|$HOME|g" agents/codex-config.toml > "$HOME/.codex/config.toml"
echo "Codex rules       -> ~/.codex/config.toml (paths set to $HOME)"

cat <<'MSG'

Now verify each agent with a decoy and a control file:
  echo secret > ~/.ssh/decoy.txt         # must be BLOCKED
  codex sandbox -- cat ~/.ssh/decoy.txt
  codex sandbox -- cat ~/.bashrc         # control: must be READ
  rm ~/.ssh/decoy.txt
A rule only counts as working after this test passes.
MSG
