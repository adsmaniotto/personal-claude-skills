# SETUP

How to swap the `<<PLACEHOLDER>>` markers for your own values.

## Step 1: Find each value

| Placeholder | Where to find it |
|---|---|
| `<<USER_NAME>>` | Your first name |
| `<<USER_EMAIL>>` | Your work email (e.g., `j.doe@acme.com`) |
| `<<ORG_DOMAIN>>` | The domain part of your email (e.g., `acme.com`) |
| `<<VAULT_PATH>>` | Absolute path to your Obsidian vault — e.g., `/Users/jdoe/MyVault` |
| `<<SLACK_USER_ID>>` | In Slack, click your avatar → "Profile" → "⋯" → "Copy member ID" (starts with `U`) |
| `<<ATLASSIAN_HOST>>` | The host part of your org's Atlassian URL (e.g., `acme.atlassian.net`) |
| `<<JIRA_BOT_EMAIL>>` | The from-address of Jira email notifications you want to filter out of Gmail triage |
| `<<HOME_USER>>` | Your macOS username (output of `whoami`) |

## Step 2: Substitute

### Option A — `install.sh` does it for you

Edit `install.sh` to set the values at the top, then run:

```bash
./install.sh
```

This sed-substitutes the placeholders and copies the result into `~/.claude/skills/`.

### Option B — manual

```bash
# In the repo root
find skills -name "*.md" -exec sed -i '' \
  -e 's|<<USER_NAME>>|Jane|g' \
  -e 's|<<USER_EMAIL>>|j.doe@acme.com|g' \
  -e 's|<<ORG_DOMAIN>>|acme.com|g' \
  -e 's|<<VAULT_PATH>>|/Users/jdoe/MyVault|g' \
  -e 's|<<SLACK_USER_ID>>|U0XXXXXXX|g' \
  -e 's|<<ATLASSIAN_HOST>>|acme.atlassian.net|g' \
  -e 's|<<JIRA_BOT_EMAIL>>|jira@acme.atlassian.net|g' \
  -e 's|<<HOME_USER>>|jdoe|g' \
  {} \;
```

Then copy `skills/*` into `~/.claude/skills/`.

## Step 3: Adapt the org-specific examples

Some skill content is **example-only** and won't match your team — but it shouldn't break the skill, just feel out of place. Adjust as you go:

- **Teammate names in `/daily-notes`** (Anh, Josh, Guoxing, Kristina, Melanie, Andy, Frank, Marlena, Danielle) — these are illustrative. Replace or remove as you build out your own teammate list (see `templates/user_teammates.md.example`).
- **Calendar names in `/daily-notes`** — `Prod/Tech`, `Inclusion & Impact Calendar`, `Fetch University` are Fetch-specific shared calendars. Replace with your own org's shared calendars to filter out.
- **`Fetch Frid-AI` event filter** — that's a specific recurring event series at Fetch that I treat as time-blocks, not meetings. Replace with whatever recurring no-meeting calendar holds you have.
- **Email-resolution pattern in `/meeting-sync`** — the skill assumes Fetch's `f.last@<<ORG_DOMAIN>>` email pattern (e.g., `g.liu` → "Guoxing Liu"). If your org uses a different pattern (`firstlast@`, `first.last@`, `flast@`, etc.), update the resolver in `skills/meeting-sync/SKILL.md` Step 5.4.
- **Granola references in `/daily-notes`** — Granola got banned at my org on 2026-04-20; the skill mentions this for historical context. Strip if it's noise to you.

## Step 4: Set up the templates

`templates/user_teammates.md.example` → copy to `~/.claude/projects/<vault-id>/memory/user_teammates.md` (or your harness's memory location) and fill in your actual teammate names.

`templates/process-zoom-transcript.sh.example` → only relevant if you're setting up the auto Zoom→vault pipeline. See `skills/transfer-notes/SKILL.md` for the install steps.

`templates/CLAUDE.vault.md.example` → drop into the root of your Obsidian vault as `CLAUDE.md`. This is what tells Claude how your vault is organized.

## Step 5: Verify

Try the easiest skill first:

```bash
# In Claude Code, with the skill installed:
/daily-notes
```

If it errors on missing dependencies, walk through `prereqs.md`.

## Troubleshooting

- **"Skill not found"** — make sure the skill directory is at `~/.claude/skills/<name>/SKILL.md` (not just `~/.claude/skills/<name>.md`). The harness expects a directory.
- **"obsidian: command not found"** — install Obsidian CLI; see `prereqs.md`.
- **gws auth errors** — re-run `gws auth login` for the affected scope.
- **Slack search returns 0 results** — verify the Slack MCP is connected in Claude Code's MCP settings.
