# Prerequisites

What you need to install + configure for these skills to actually run.

## Required

### 1. Claude Code

The harness that loads + runs the skills.

```bash
# https://claude.com/claude-code
```

Skills live at `~/.claude/skills/<skill-name>/SKILL.md`.

### 2. Obsidian + Obsidian CLI

The vault is the substrate. Skills read/write it via the CLI.

```bash
# Obsidian: https://obsidian.md
# Obsidian CLI: https://github.com/Yakitrak/obsidian-cli or similar
brew install obsidian-cli
```

Verify: `obsidian --version`.

### 3. `gws` CLI (Google Workspace)

For Calendar, Docs, Sheets, Slides, Drive, Gmail.

```bash
# Whatever your org's preferred install is — or roll your own thin wrapper
# around the Google Workspace APIs. The skills call `gws calendar`, `gws docs`,
# `gws sheets`, `gws slides`, `gws drive`, `gws gmail`.
gws auth login
```

### 4. Slack MCP

Anthropic's claude.ai Slack connector. Enables `mcp__claude_ai_Slack__*` tools.

Configure via Claude Code's MCP settings or your Anthropic console. The `/slack-catchup` skill depends on this.

### 5. Atlassian MCP

For Confluence + Jira reads/writes. Used by `/confluence-sync` and `/jira-board` (not in this repo, but referenced).

## Optional (but unlocks more)

### 6. Superwhisper

Voice-to-text for morning dictations + Zoom call transcription.

```bash
# https://superwhisper.com
```

Required for `/meeting-sync` and `/transfer-notes`.

### 7. Hammerspoon

macOS automation. Used to trigger Superwhisper recording when a Zoom meeting starts/ends.

```bash
brew install --cask hammerspoon
```

The Hammerspoon Lua config + the `process-zoom-transcript.sh` script live at `~/.hammerspoon/`. See `templates/process-zoom-transcript.sh.example` and `skills/transfer-notes/SKILL.md`.

### 8. Marp CLI

For rendering the lightning talk source to a deck (if you're curious).

```bash
brew install marp-cli
marp talk/lightning-talk.md -o lightning-talk.html
# Or watch mode:
marp --server talk --watch
```

## Per-platform notes

- **macOS only**: Hammerspoon, Superwhisper. The auto Zoom-transcription pipeline assumes macOS.
- **Linux/Windows**: most skills work — drop `/transfer-notes` and adjust `/meeting-sync` to point at whatever transcription source you have.

## Auth + tokens

Skills don't store secrets directly. They rely on:
- `gws` CLI's stored OAuth tokens
- Claude Code's MCP server configurations (Slack, Atlassian) which manage their own tokens

If you hit auth errors, the fix is almost always: re-authenticate the underlying CLI/MCP, not the skill.
