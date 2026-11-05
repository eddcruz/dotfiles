#!/usr/bin/env bash
# =============================================================================
#  install-phosphor.sh — Applies the Phosphor look (green phosphor CRT)
#  Terminal (Ptyxis), Starship, btop, fastfetch, wallpaper and Nerd Font.
#  VS Code is applied by hand (see phosphor/vscode-colors.jsonc).
#
#  Usage:  ./install-phosphor.sh      (from the dotfiles folder, no sudo)
#  Idempotent: safe to run several times. Backs up what it replaces.
# =============================================================================
set -Eeuo pipefail
cd "$(dirname "$0")"
DOT="$(pwd)"

step() { printf '\n\033[1;32m==> %s\033[0m\n' "$1"; }
warn() { printf '\033[1;33m    ! %s\033[0m\n' "$1"; }
backup() { [[ -f "$1" && ! -L "$1" ]] && cp "$1" "$1.bak.$(date +%s)" || true; }

if [[ $EUID -eq 0 ]]; then echo "Do not use sudo. Run: ./install-phosphor.sh"; exit 1; fi

# -----------------------------------------------------------------------------
step "1/5 JetBrains Mono Nerd Font (icons in terminal and prompt)"
FONT_DIR="$HOME/.local/share/fonts/JetBrainsMonoNerd"
if fc-list | grep -qi "JetBrainsMono Nerd Font"; then
  echo "    Already installed."
else
  mkdir -p "$FONT_DIR"
  TMP="$(mktemp -d)"
  if curl -fL --retry 2 -o "$TMP/jbm.tar.xz" \
       https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz; then
    tar -xJf "$TMP/jbm.tar.xz" -C "$FONT_DIR"
    fc-cache -f "$FONT_DIR" >/dev/null
    echo "    Installed in $FONT_DIR"
  else
    warn "Download failed (network blocking GitHub?). Re-run from another network."
  fi
  rm -rf "$TMP"
fi

# -----------------------------------------------------------------------------
step "2/5 Ptyxis terminal: Phosphor palette and font"
PAL_DIR="$HOME/.local/share/org.gnome.Ptyxis/palettes"
mkdir -p "$PAL_DIR"
cp "$DOT/phosphor/ptyxis/phosphor.palette" "$PAL_DIR/phosphor.palette"
if gsettings list-schemas | grep -q '^org.gnome.Ptyxis$'; then
  UUID="$(gsettings get org.gnome.Ptyxis default-profile-uuid 2>/dev/null | tr -d "'" || true)"
  if [[ -n "$UUID" ]]; then
    gsettings set "org.gnome.Ptyxis.Profile:/org/gnome/Ptyxis/Profiles/$UUID/" palette 'phosphor' \
      || warn "Could not set the palette; pick it in Ptyxis → Preferences → Profile → Palette."
  else
    warn "Ptyxis has no profile yet. Open it once and re-run the script."
  fi
  if fc-list | grep -qi "JetBrainsMono Nerd Font"; then
    gsettings set org.gnome.Ptyxis use-system-font false
    gsettings set org.gnome.Ptyxis font-name 'JetBrainsMono Nerd Font 12' || warn "Pick the font by hand: Ptyxis → Preferences → Font"
  fi
else
  warn "Ptyxis not found; skipping."
fi

# -----------------------------------------------------------------------------
step "3/5 Starship: Phosphor prompt"
mkdir -p "$HOME/.config"
backup "$HOME/.config/starship.toml"
cp "$DOT/phosphor/starship.toml" "$HOME/.config/starship.toml"

# -----------------------------------------------------------------------------
step "4/5 btop and fastfetch: Phosphor theme"
mkdir -p "$HOME/.config/btop/themes"
cp "$DOT/phosphor/btop/phosphor.theme" "$HOME/.config/btop/themes/phosphor.theme"
BTOP_CONF="$HOME/.config/btop/btop.conf"
if [[ -f "$BTOP_CONF" ]] && grep -q '^color_theme' "$BTOP_CONF"; then
  sed -i 's|^color_theme.*|color_theme = "phosphor"|' "$BTOP_CONF"
else
  echo 'color_theme = "phosphor"' >> "$BTOP_CONF"
fi

# fastfetch in Phosphor colors
mkdir -p "$HOME/.config/fastfetch"
cp "$DOT/phosphor/fastfetch/config.jsonc" "$HOME/.config/fastfetch/config.jsonc"

# -----------------------------------------------------------------------------
step "5/5 Desktop: wallpaper, dark mode and green accent"
WALL_DIR="$HOME/.local/share/backgrounds"
mkdir -p "$WALL_DIR"
cp "$DOT/phosphor/wallpaper/phosphor.png" "$WALL_DIR/phosphor.png"
gsettings set org.gnome.desktop.background picture-uri      "file://$WALL_DIR/phosphor.png" || true
gsettings set org.gnome.desktop.background picture-uri-dark "file://$WALL_DIR/phosphor.png" || true
gsettings set org.gnome.desktop.background picture-options 'zoom' || true
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' || true
gsettings set org.gnome.desktop.interface accent-color 'green' 2>/dev/null || true

# -----------------------------------------------------------------------------
step "Done. Remaining (by hand):"
cat <<EOF

  1. Close and reopen the terminal to see the palette and prompt.
  2. VS Code: open phosphor/vscode-colors.jsonc and follow its instructions.
  3. Try btop:  btop   (quit with q)
  4. If you see boxes instead of icons, the Nerd Font did not install (step 1).

EOF
