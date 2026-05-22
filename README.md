# personal-claude-skills

Companion repo for the lightning talk **"Building a Knowledge Management System"** *(Fetch AI Dev Day, 2026-05-08)*.

These are the actual Claude Code skills powering my morning routine, my meeting-note pipeline, and my Obsidian wiki layer — genericized so you can fork them and adapt to your own setup.

## What's in here

```
.
├── README.md          ← this file
├── SETUP.md           ← step-by-step config swaps
├── prereqs.md         ← CLI/MCP installs you'll need
├── skills/            ← genericized skills
│   ├── daily-notes/
│   ├── slack-catchup/
│   ├── gmail-triage/
│   ├── meeting-sync/
│   ├── integrate-into-wiki/
│   ├── transfer-notes/
│   ├── obsidian-cli/
│   └── print-doc/
├── templates/         ← example config files
│   ├── user_teammates.md.example
│   ├── process-zoom-transcript.sh.example
│   └── CLAUDE.vault.md.example
├── talk/              ← the lightning talk source (Marp markdown)
│   └── lightning-talk.md
└── install.sh         ← optional: substitute placeholders + copy into ~/.claude/skills/
```

## How this works at a high level

1. **Skills live as markdown files** in `~/.claude/skills/<name>/SKILL.md`.
2. Claude Code's harness loads them automatically. Tab-complete-able as `/<name>`.
3. Each skill describes a workflow in prose + concrete CLI invocations. The harness reads the skill and follows the instructions.

The Karpathy *"LLM Wiki"* pattern is the spine: raw inputs (synced docs, voice notes, meeting transcripts) flow into a Claude-maintained wiki layer; skills are the orchestration surface.

## Quick start

```bash
# 1) Read the prereqs
open prereqs.md

# 2) Read SETUP.md to find/swap the placeholders
open SETUP.md

# 3) Optional: use install.sh to substitute + copy into your ~/.claude/skills/
./install.sh
```

## Placeholders

Every personal token has been replaced with a `<<PLACEHOLDER>>` marker. See `SETUP.md` for the full list and how to find each value for your own setup.

| Placeholder | What it is |
|---|---|
| `<<USER_NAME>>` | Your first name |
| `<<USER_EMAIL>>` | Your work email |
| `<<ORG_DOMAIN>>` | Your org's email domain (e.g., `acme.com`) |
| `<<VAULT_PATH>>` | Absolute path to your Obsidian vault |
| `<<SLACK_USER_ID>>` | Your Slack user ID (the `U…` string) |
| `<<ATLASSIAN_HOST>>` | Your Atlassian site host |
| `<<JIRA_BOT_EMAIL>>` | The Jira notification bot email (to filter from Gmail triage) |

## Caveats

- This is a **snapshot for the talk**, not a maintained library. Skills will drift from my personal copy over time.
- My setup is opinionated: macOS + Obsidian + Hammerspoon + Superwhisper + Claude Code. Some skills (`/meeting-sync`, `/transfer-notes`) won't work without the Hammerspoon/Superwhisper pieces.
- The Slack, Atlassian, and Google Workspace integrations require working `gws` CLI auth + the matching MCP servers configured in Claude Code.

## License

Take what's useful. Attribution appreciated, not required.
