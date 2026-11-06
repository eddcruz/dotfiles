# dotfiles

Scripted setup for my personal laptop (HP EliteBook 840 G10 · Ubuntu 26.04 LTS): bootstrap scripts, the **Phosphor** terminal look, and security rules for AI coding agents.

![Phosphor terminal](docs/screenshot.png)

## Why

A fresh install should be a few commands away from a working, private, good-looking machine — not an afternoon of copy-pasting commands from old notes.

## Quick start (fresh install)

```bash
sudo apt install -y git
git clone https://github.com/eddcruz/dotfiles.git ~/dev/dotfiles
cd ~/dev/dotfiles
./setup.sh              # base system: privacy, tools, agents
./install-phosphor.sh   # look and feel
```

Then install the agent security rules:

```bash
./install-agents.sh     # Claude Code + Codex, paths adapted to your user
```

Antigravity (Gemini) is configured by hand: see `agents/antigravity-rules.md`.

VS Code extensions are not included: use Settings Sync or your own list.

> **Privacy tip:** when `setup.sh` asks for your Git email, use your GitHub noreply address
> (github.com/settings/emails) so your real email never lands in public commits.

## What's inside

| Path | What it does |
|---|---|
| `setup.sh` | 10-step base install: no Snap, masked telemetry, firewall, Brave, VS Code, Docker, LibreOffice, Zsh, Claude Code, Codex |
| `install-phosphor.sh` | Nerd Font, terminal palette, Starship prompt, btop, fastfetch, wallpaper, and a clean desktop: Papirus icons with green folders, auto-hiding dock, battery % and weekday in the top bar, redundant launchers hidden |
| `phosphor/` | Theme files for each tool |
| `install-agents.sh` | Installs the Claude Code and Codex rules, adapting paths to your home folder |
| `agents/` | Security rules for AI coding agents: block reads of `~/.ssh`, `.env` files and other agents' credentials |

## AI agent security

Three agents work on the same machine (Claude Code, Codex, Gemini via Antigravity), so each one is locked down the same way:

| Agent | Writes and commands | Denied reads | Verified by |
|---|---|---|---|
| Claude Code | Manual approval | 8 rules | Explicit denial on a test `.env` |
| Codex | Two profiles: `revisor` (default, read-only) and `constructor` (writes only inside the project) | 6 rules | `codex sandbox` test with a control file |
| Gemini (Antigravity) | Require review + sandbox | 6 rules | Never returned a denied file (indirect) |

Rules are only trusted after a test: ask the agent to read a decoy file and confirm it is blocked — with a control file that should be readable, so a broken config can't pass as a working one.

Switch Codex to the writing profile for one session only:

```bash
codex -c default_permissions=constructor
```

## Manual steps after install

Some settings are personal or need a GUI, so they stay manual:

1. **Region:** Settings → Region & Language → Language *English (United States)*, Formats *United Kingdom* (English weekday names, day/month dates). Log out to apply.
2. **LibreOffice:** Tools → Options → Languages and Locales → Locale *Spanish (Mexico)* for MXN currency and Spanish spell-check.
3. **Antigravity (Gemini):** security settings by hand, see `agents/antigravity-rules.md`.
4. **Fingerprint (optional):** unlock only; `sudo` keeps asking for the password. At boot use the password so the GNOME keyring unlocks.
5. **Firmware:** `fwupdmgr refresh` then `fwupdmgr get-updates` as separate commands, on AC power.

## Adapting it to your machine

This is my setup, built for my laptop, but most of it is reusable:

| Part | For someone else |
|---|---|
| `agents/` rules + the decoy/control test | **Use as-is.** `install-agents.sh` adapts the paths to your user |
| Phosphor theme (`phosphor/`, `install-phosphor.sh`) | **Reuse.** Works on any GNOME desktop with Ptyxis |
| `setup.sh` | **Review first.** It removes Snap and masks telemetry: read it before running |
| Language, formats, keyboard | **Change** to your own (see manual steps above) |
| Firmware and fingerprint notes | **HP EliteBook only** |

Tested on Ubuntu 26.04 LTS with GNOME. Fork it and edit freely.

## Lessons learned

Things that broke once, so the scripts now avoid them:

| Problem | Fix |
|---|---|
| Purging `whoopsie`/`apport` removed `gnome-shell` | Telemetry is **masked** with `systemctl mask`, never purged |
| `libreoffice-gtk4` ignored dark mode | Use `libreoffice-gtk3` |
| Hidden launcher still showed (LibreOffice ships `NoDisplay=false`) | Delete any existing `NoDisplay=` line before adding `NoDisplay=true` |
| Codex sandbox could not run anything | Profiles need `"/" = "read"` before narrowing permissions |
| `fwupdmgr refresh && get-updates` never checked updates | `refresh` exits non-zero when metadata is current: run them separately |
| Ptyxis ignored the palette | The gsettings key is `palette`, not `palette-id` |

## Phosphor palette

| Role | Color |
|---|---|
| Background | `#0d1117` |
| Text | `#b5d8bc` |
| Green | `#3fb950` |
| Bright green | `#7ee787` |
| Cyan | `#56d4dd` |
| Amber | `#d29922` |
| Red | `#f85149` |

## Security

This repo never contains secrets (keys, tokens, passwords or `.env` files). `.gitignore` blocks them, GitHub push protection is on, and commits use a noreply email.
