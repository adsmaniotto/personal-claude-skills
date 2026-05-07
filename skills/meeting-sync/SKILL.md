---
name: meeting-sync
description: Bulk sync Superwhisper meeting recordings to the Obsidian vault. Scans recordings for a date, matches each to a Google Calendar event for title + attendees, writes detailed notes to zoom/ and structured summaries to the daily note. Use when the user says "sync my meetings", "pull meeting notes", "sync today's meetings", "backfill meetings", "sync yesterday's meetings", or wants meeting transcripts retroactively processed into the vault. (Renamed from granola-sync 2026-05-07; the old Granola-based flow is gone — this skill replaces it.)
tags: ['obsidian', 'meetings', 'superwhisper', 'calendar', 'bulk-sync']
user_invocable: true
---

# Meeting Sync

Bulk-process Superwhisper meeting recordings into the Obsidian vault. This is the manual/retroactive counterpart to the automated Zoom → Superwhisper → Claude pipeline documented in the `transfer-notes` skill.

**Why this exists**: Granola isn't permitted at Fetch anymore (as of 2026-04-20). This skill replicates Granola's daily-note sync capability using Superwhisper recordings + Google Calendar lookups + Claude summarization.

## Constants

- **Recording source**: `~/Documents/superwhisper/recordings/<unix_timestamp>/meta.json`
- **Vault root**: `<<VAULT_PATH>>`
- **Full-notes output**: `<vault>/zoom/YYYY-MM-DD HHMM - <title>.md`
- **Daily note**: `<vault>/daily/YYYY-MM-DD.md`
- **Daily note section header**: `## Meetings` (unified — used by both this skill and the auto pipeline)
- **Calendar**: `<<USER_EMAIL>>` (personal calendar only — don't pull from shared org calendars)
- **Timezone**: US Central (CDT = UTC-5 in April, CST = UTC-6 otherwise)
- **Skip thresholds**: duration < 30s OR transcript < 200 chars OR Claude classifies as non-meeting

## Execution

### Step 1: Resolve the target date

- Default: today (from the `currentDate` context variable)
- User may specify: "yesterday", "last Thursday", "2026-04-15", a date range, etc.
- Convert relative dates to absolute YYYY-MM-DD. For ranges, process each date sequentially.

### Step 2: List candidate recordings for the date

Superwhisper folders are named as unix timestamps (recording start time). Convert the target date to the unix timestamp range covering that day in Central time, then list matching folders:

```bash
# Start/end of target day in Central (handle DST — April uses -05:00, winter uses -06:00)
START_EPOCH=$(date -j -f "%Y-%m-%d %H:%M:%S %z" "YYYY-MM-DD 00:00:00 -0500" "+%s")
END_EPOCH=$(date -j -f "%Y-%m-%d %H:%M:%S %z" "YYYY-MM-DD 23:59:59 -0500" "+%s")

ls ~/Documents/superwhisper/recordings/ | awk -v s="$START_EPOCH" -v e="$END_EPOCH" '$1 >= s && $1 <= e'
```

### Step 3: Fetch calendar events for the day

One calendar query per date covers all recordings:

```bash
gws calendar events list --params '{
  "calendarId": "<<USER_EMAIL>>",
  "timeMin": "YYYY-MM-DDT00:00:00-05:00",
  "timeMax": "YYYY-MM-DDT23:59:59-05:00",
  "singleEvents": true,
  "orderBy": "startTime"
}' --format json
```

Filter out non-meeting events:
- `eventType`: `workingLocation`, `focusTime`, `outOfOffice`
- Summaries matching `Home`, `Office`, `BLOCK:`, `PTO`, `OOO`
- All-day events (`start.date` instead of `start.dateTime`)

### Step 4: Pre-check the daily note for duplicates

Read `<vault>/daily/YYYY-MM-DD.md` if it exists. Scan the `## Meetings` section for existing `### <title>` headings. Any recording whose matched calendar-event title already has a `###` heading in the daily note should be **skipped** (don't reprocess).

Also check the `zoom/` folder for pre-existing files with the expected name. If both the daily-note heading and the zoom file exist, that meeting is already fully synced.

### Step 5: Process each remaining recording

For each recording folder not already synced:

1. Read `meta.json` — extract `result` (transcript), `datetime` (start), `duration` (ms).
2. **Filter**: duration < 30s or transcript < 200 chars → skip, track as "too short".
3. **Match to calendar event**: compute recording window `[datetime, datetime + duration]`, find the calendar event whose start/end overlaps. If nothing matches, use fallback title "Untitled meeting (HH:MM)".
4. **Derive metadata**:
   - Title = event.summary (sanitize: replace `/` with `_`, strip `[w]` and similar bracketed tags)
   - **Attendees — calendar event is the source of truth, never inference.** Resolution order:
     1. **`event.attendees[].displayName`** if populated — use the first name.
     2. **Email local-part lookup against `people/*.md`** — Fetch emails follow `f.last@<<ORG_DOMAIN>>`. Match `f.last` to a people-page filename whose first letter matches `f` AND last name matches `last`. Examples: `g.liu` → `[[Guoxing]]`, `k.branaugh` → `[[Kyria]]`, `m.erlick` → `[[Mimi]]`. Match must agree on **both** initial and last name — never resolve on first-letter alone (that's how `m.erlick` got mis-resolved to "Melanie" once).
     3. **No people-page match** → use the literal local-part with a capital, e.g. `m.erlick` → `M. Erlick`. Better to surface a clearly-unresolved name than to guess wrong.
     4. **Drop**: <<USER_NAME>>, room resources (anything with "Room", "VC", "Conference" in the name), and any `responseStatus: declined` attendees.
   - Start time in 12-hour format (e.g., "2:30 PM")
5. **Write full notes** to `<vault>/zoom/YYYY-MM-DD HHMM - <title>.md`:
   ```
   ---
   datetime: <ISO from recording>
   title: <meeting title>
   source: superwhisper
   duration_sec: <seconds>
   recording_id: <unix timestamp>
   attendees: [Name1, Name2]
   ---

   ## Summary
   - 3-5 bullets

   ## Discussed topics
   ### <theme>
   - substantive bullets

   ## Action items
   - [ ] <<USER_NAME>>'s action 📅 YYYY-MM-DD
   - Other person's action (noted with owner)

   > [!note]- Full transcript
   > verbatim transcript here
   ```
6. **Append to daily note** under `## Meetings`:
   - `### <title> (<time>)`
   - `**Attendees**: Name1, Name2`
   - `[[zoom/YYYY-MM-DD HHMM - title]]` — link to full notes
   - The same `#### <theme>` thematic sections and action items as the vault file, **minus** the transcript callout (too long for daily note)

### Step 6: Generate notes inline (don't shell out)

Since Claude is already running the skill, generate the structured notes inline using the transcript and calendar metadata. Reuse the exact prompt structure from `~/.hammerspoon/process-zoom-transcript.sh` so output is identical to the auto pipeline. **Do not** shell out to `claude -p` per recording — that's slower, costs more tokens, and risks output drift between the two code paths.

### Step 7: Report results

Tell the user:
- Total recordings found for the date
- How many were processed (with meeting title + time)
- How many were skipped, and why (too short / already synced / couldn't match calendar)
- Path to daily note as an `obsidian://` URI for Cmd+click

## Formatting rules

- **First-name attendees only**, drop <<USER_NAME>>. Calendar event is the source of truth; resolve email local-parts via `people/*.md` lookup matching on both first-letter AND last name (see Step 5.4 for full resolution order). Never guess from first-letter alone.
- **Action items for <<USER_NAME>>**: `- [ ] ...` with `📅 YYYY-MM-DD` due date inferred from meeting context. Tasks without due dates don't appear in the Tasks plugin.
- **Action items for others**: plain bullet with owner noted (`- Andy to follow up with Louis`).
- **Wikilinks** for people, projects, teams — match existing `people/`, `projects/`, `teams/` files in the vault.
- **Themed sections** from the transcript — don't just regurgitate chronologically. Group by topic. Preserve strategic/political nuance, named decisions, specific numbers.

## Edge cases

- **Weekend sync**: process normally — <<USER_NAME>> sometimes has weekend calls.
- **Same meeting appears twice** (e.g., someone rejoined and started a new recording): combine them under one calendar-event match. Concatenate transcripts.
- **Non-Zoom meetings recorded via Superwhisper manual trigger**: still work. Calendar match handles the naming regardless of source.
- **Recording with no matching calendar event**: use "Untitled meeting (HH:MM)" as the title. Still write the file — the raw transcript is valuable even without metadata.
- **Personal/non-work content in recording**: if Claude determines this is personal, not a work meeting, it's fine to skip vault writes entirely. Don't force it.
- **Old `## Granola Meeting Notes` or `## Zoom meetings` sections in historical daily notes**: leave untouched. Only write to `## Meetings` going forward.

## Relationship to `transfer-notes` skill

- **`transfer-notes`** = documentation + troubleshooting for the **automated** pipeline (Hammerspoon-driven, fires at end of each Zoom call). Also contains reference copies of `init.lua` and `process-zoom-transcript.sh`.
- **`meeting-sync`** (this skill) = **manual/bulk** sync for a date range. Use this when the auto pipeline missed something, when you recorded via Superwhisper outside Zoom, or when you want to backfill.

Both skills produce identical output format so the daily note reads consistently regardless of whether a meeting was processed automatically or in bulk.
