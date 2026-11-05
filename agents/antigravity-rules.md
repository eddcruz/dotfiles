# Antigravity (Gemini) — manual configuration

Antigravity has no documented config file; configure it in the agent panel → ⋮ → Settings.

**General**
- Security Preset: Custom
- Outside of folders file access policy: Always Ask
- Terminal Command Auto Execution: Require Review
- Enable Sandbox Mode: on
- Plan Review Policy: Always Ask
- Commands Outside Sandbox, Terminal Commands, MCP Tools: empty

**Tool Permissions → File Access Rules → File Reads (Deny)**
- `**/.env`
- `**/.env.*`
- `/home/<user>/.claude`
- `/home/<user>/.codex`
- `/home/<user>/.gnupg`
- `/home/<user>/.ssh`

**VS Code settings.json:** `"antigravity.autoAcceptOnChat": false`

**On first sign-in:** do NOT check "Yes, I agree to help improve Antigravity".

**Known limitation:** when the agent hits a denied file it gets stuck on "Working"
instead of reporting the denial. Cancel and check what you asked for.
