#!/usr/bin/env bash
# =============================================================================
#  setup.sh — Base setup for an HP EliteBook 840 G10 (Ubuntu 26.04 LTS)
#  Gets the machine working. The Phosphor look is applied by install-phosphor.sh.
#
#  Usage (after a fresh Ubuntu install):
#     chmod +x setup.sh
#     ./setup.sh
#
#  Rules:
#   - Do NOT run with sudo. The script asks for your password when needed.
#   - Safe to re-run: steps that are already done are skipped (idempotent).
#   - Lesson learned: telemetry services are MASKED, never purged
#     (purging whoopsie/apport pulls gnome-shell with it and breaks the desktop).
# =============================================================================

set -Eeuo pipefail

# ---------- Helpers ----------------------------------------------------------
step() { printf '\n\033[1;32m==> %s\033[0m\n' "$1"; }
warn() { printf '\033[1;33m    ! %s\033[0m\n' "$1"; }

if [[ $EUID -eq 0 ]]; then
  echo "Do not run this script with sudo. Run it as your user: ./setup.sh"
  exit 1
fi

# Install only the packages available in the repos; warn about the rest.
install_pkgs() {
  local available=()
  for p in "$@"; do
    if apt-cache show "$p" &>/dev/null; then
      available+=("$p")
    else
      warn "Package not available in the repos, skipping: $p"
    fi
  done
  if (( ${#available[@]} )); then
    sudo apt-get install -y "${available[@]}"
  fi
}

ARCH="$(dpkg --print-architecture)"
CODENAME="$(. /etc/os-release && echo "${UBUNTU_CODENAME}")"

# Ask for the sudo password once at the start
sudo -v

# =============================================================================
# 1. SYSTEM UPDATE
# =============================================================================
step "1/10 Updating the system"
sudo apt-get update
sudo apt-get full-upgrade -y

# =============================================================================
# 2. PRIVACY: mask telemetry + remove Snap
# =============================================================================
step "2/10 Privacy: masking telemetry"
# Masking keeps the service installed (GNOME depends on it) but it can never start.
# '|| true' because some units may not exist.
for unit in whoopsie.service whoopsie.path apport.service \
            apport-autoreport.path apport-autoreport.timer apport-forward.socket; do
  sudo systemctl mask --now "$unit" 2>/dev/null || true
done
# Also disable apport crash reports in its config
if [[ -f /etc/default/apport ]]; then
  sudo sed -i 's/^enabled=1/enabled=0/' /etc/default/apport
fi

step "2/10 Privacy: removing Snap"
if command -v snap &>/dev/null; then
  # Remove snap apps first (most dependent first)
  for s in firefox thunderbird snap-store firmware-updater \
           snapd-desktop-integration prompting-client desktop-security-center; do
    sudo snap remove --purge "$s" 2>/dev/null || true
  done
  # Remaining bases and runtimes
  for s in $(snap list 2>/dev/null | awk 'NR>1 {print $1}' | grep -v '^snapd$'); do
    sudo snap remove --purge "$s" 2>/dev/null || true
  done
  sudo snap remove --purge snapd 2>/dev/null || true
  sudo systemctl stop snapd.service snapd.socket 2>/dev/null || true
  sudo apt-get purge -y snapd
fi
sudo apt-mark hold snapd 2>/dev/null || true
# Prevent apt from reinstalling snapd as a dependency
sudo tee /etc/apt/preferences.d/nosnap.pref >/dev/null <<'EOF'
Package: snapd
Pin: release a=*
Pin-Priority: -10
EOF
rm -rf "$HOME/snap"
sudo rm -rf /snap /var/snap /var/lib/snapd /var/cache/snapd

# =============================================================================
# 3. FIREWALL
# =============================================================================
step "3/10 Enabling firewall (UFW)"
install_pkgs ufw
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw --force enable

# =============================================================================
# 4. BASE TOOLS + OFFICE
# =============================================================================
step "4/10 Base tools, Python, Node.js and LibreOffice"
install_pkgs \
  curl wget git build-essential unzip zip tree ca-certificates gnupg \
  nethogs htop \
  python3 python3-pip python3-venv python-is-python3 \
  nodejs npm \
  libreoffice-calc libreoffice-writer libreoffice-gtk3 \
  libreoffice-l10n-es hunspell-es \
  gnome-tweaks gnome-shell-extension-manager

# pnpm (for Astro web projects): user-level in ~/.local/bin, no sudo.
if ! command -v pnpm &>/dev/null && command -v npm &>/dev/null; then
  mkdir -p "$HOME/.local"
  npm install -g pnpm --prefix "$HOME/.local"
fi

# =============================================================================
# 5. BROWSER: Brave (official repository, no snap)
# =============================================================================
step "5/10 Brave"
if ! command -v brave-browser &>/dev/null; then
  sudo curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg \
    https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
  echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main" \
    | sudo tee /etc/apt/sources.list.d/brave-browser-release.list >/dev/null
  sudo apt-get update
  sudo apt-get install -y brave-browser
fi

# =============================================================================
# 6. VS CODE (official Microsoft repository)
# =============================================================================
step "6/10 VS Code"
if ! command -v code &>/dev/null; then
  curl -fsSL https://packages.microsoft.com/keys/microsoft.asc \
    | gpg --dearmor | sudo tee /usr/share/keyrings/microsoft.gpg >/dev/null
  echo "deb [arch=${ARCH} signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/code stable main" \
    | sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null
  sudo apt-get update
  sudo apt-get install -y code
fi

# =============================================================================
# 7. DOCKER (official repo; falls back to Ubuntu's package if unavailable)
# =============================================================================
step "7/10 Docker"
if ! command -v docker &>/dev/null; then
  sudo install -m 0755 -d /etc/apt/keyrings
  sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  sudo chmod a+r /etc/apt/keyrings/docker.asc
  echo "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${CODENAME} stable" \
    | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
  if sudo apt-get update && apt-cache show docker-ce &>/dev/null; then
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io \
      docker-buildx-plugin docker-compose-plugin
  else
    warn "Docker has no repo for '${CODENAME}' yet. Using Ubuntu's package."
    sudo rm -f /etc/apt/sources.list.d/docker.list
    sudo apt-get update
    install_pkgs docker.io docker-compose-v2
  fi
fi
# Use docker without sudo (takes effect after logging out and back in)
sudo usermod -aG docker "$USER"

# =============================================================================
# 8. TERMINAL: Zsh + modern CLI tools (theming is in install-phosphor.sh)
# =============================================================================
step "8/10 Zsh and terminal tools"
install_pkgs \
  zsh zsh-autosuggestions zsh-syntax-highlighting \
  fonts-jetbrains-mono \
  eza bat fzf zoxide btop fastfetch lazygit ripgrep fd-find

# Starship prompt
if ! command -v starship &>/dev/null; then
  curl -sS https://starship.rs/install.sh | sh -s -- -y
fi

# Minimal .zshrc. Any existing one is backed up first.
[[ -f "$HOME/.zshrc" ]] && cp "$HOME/.zshrc" "$HOME/.zshrc.bak.$(date +%s)"
cat > "$HOME/.zshrc" <<'EOF'
# --- History ---
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt SHARE_HISTORY HIST_IGNORE_DUPS

# --- User paths (Claude Code, Codex, pnpm) ---
export PATH="$HOME/.local/bin:$PATH"

# --- Completion ---
autoload -Uz compinit && compinit

# --- Plugins ---
[[ -f /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]] && \
  source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
[[ -f /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] && \
  source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# --- Modern aliases ---
command -v eza    &>/dev/null && alias ls='eza --icons --group-directories-first' && alias ll='eza -la --icons --git'
command -v batcat &>/dev/null && alias cat='batcat --paging=never'
command -v fdfind &>/dev/null && alias fd='fdfind'

# --- Smart cd and prompt ---
command -v zoxide   &>/dev/null && eval "$(zoxide init zsh)"
command -v starship &>/dev/null && eval "$(starship init zsh)"
EOF

# Zsh as the default shell
if [[ "$SHELL" != "$(command -v zsh)" ]]; then
  chsh -s "$(command -v zsh)"
fi

# =============================================================================
# 9. GIT + SSH + PROJECTS FOLDER
# =============================================================================
step "9/10 Git, SSH key and ~/dev"
mkdir -p "$HOME/dev"

if [[ -z "$(git config --global user.name || true)" ]]; then
  read -rp "    Git name (e.g. Jane Doe): " GIT_NAME
  echo "    Tip: use your GitHub noreply address (github.com/settings/emails) to keep your email private."
  read -rp "    Git email: " GIT_EMAIL
  git config --global user.name  "$GIT_NAME"
  git config --global user.email "$GIT_EMAIL"
fi
git config --global init.defaultBranch main
git config --global pull.rebase false

if [[ ! -f "$HOME/.ssh/id_ed25519" ]]; then
  echo "    Creating SSH key. Use a passphrase."
  ssh-keygen -t ed25519 -C "$(hostname)-$(date +%Y%m)" -f "$HOME/.ssh/id_ed25519"
fi

# =============================================================================
# 10. AI CODING AGENTS (user-level install, system untouched)
#   Builder / reviewer / tester, interchangeable:
#   - Claude Code (terminal)
#   - Codex CLI (terminal)
#   - Gemini (Antigravity extension in VS Code, restored by Settings Sync)
# =============================================================================
step "10/10 Claude Code and Codex"
if ! command -v claude &>/dev/null; then
  curl -fsSL https://claude.ai/install.sh | bash
fi

# Codex CLI: user-level in ~/.local/bin, no sudo
if ! command -v codex &>/dev/null && command -v npm &>/dev/null; then
  npm install -g @openai/codex --prefix "$HOME/.local"
fi

# Agent security rules are installed separately: ./install-agents.sh

# =============================================================================
# BASIC DESKTOP SETTINGS
# =============================================================================
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null || true
gsettings set org.gnome.desktop.interface accent-color 'green'       2>/dev/null || true

sudo apt-get autoremove -y

# =============================================================================
# SUMMARY AND MANUAL STEPS
# =============================================================================
step "Done. Remaining manual steps:"
cat <<EOF

  1. Add your SSH key to GitHub (Settings → SSH and GPG keys → New SSH key):

$(cat "$HOME/.ssh/id_ed25519.pub")

     Then test:  ssh -T git@github.com

  2. Log out and back in (activates Zsh and docker without sudo).

  3. Open VS Code and sign in with GitHub to restore extensions via Settings Sync.

  4. Settings → Region & Language → Formats: pick your region.

  5. Agent security: run ./install-agents.sh and verify with its decoy test.
     Antigravity (Gemini) is set by hand: see agents/antigravity-rules.md.

  6. Apply the look:  ./install-phosphor.sh

EOF
