---
name: daily-notes
description: >
  Pull today's Obsidian daily notes, extract themes, and ask follow-ups to help
  get started. Triggered by "pull today's notes", "daily notes", "what did I
  dictate today", "check my notes", "morning review", "obsidian notes".
tags: ['obsidian', 'notes', 'daily', 'voice']
user_invocable: true
---

# Daily Notes Review

Read today's voice-dictated Obsidian daily note, extract themes, and surface action items.

## Prerequisites

- Obsidian CLI on `$PATH` (`obsidian help` to verify)
- Obsidian must be running (CLI communicates with the app)

## Constants

- **Daily note path**: Resolve via `obsidian daily:path` (today) or `daily/YYYY-MM-DD.md` (other dates)
- **Date format**: `YYYY-MM-DD.md`
- **Today's date**: Use `currentDate` from context, or accept a user-specified date

## Execution

### Step 1: Read the daily note and pull today's calendar

Do both in parallel:

1. **Daily note**: Run `obsidian daily:read` via Bash for today's note. For a user-specified date, use `obsidian read path="daily/YYYY-MM-DD.md"` instead.
2. **Calendar**: Run `gws calendar +agenda` via Bash to get today's upcoming events. This provides context for interpreting the notes — e.g., what meetings are coming up, what commitments are on the schedule, and where action items might land. **Calendar filtering**:
   - Only include events from <<USER_NAME>>'s personal calendar (`<<USER_EMAIL>>`) as his actual meetings. Ignore shared/org calendars like `Prod/Tech`, `Inclusion & Impact Calendar`, etc. — those are just calendars he has visibility into.
   - **Drop "Frid-AI" events** (e.g., "Fetch Frid-AI Monthly Demo", "Fetch Frid-AI Working Time"). These are time blocks <<USER_NAME>> holds for AI-related focus work, not meetings — they don't belong in the calendar list and shouldn't drive action-item inference.
   - **Exception**: Include birthdays and Fetchiversaries from the `Fetch Birthdays & Fetchiversary` calendar, but only for teammates (see memory file `user_teammates.md` for the list). Mention these as a quick callout, not as calendar events.

### Step 2: Handle missing or empty notes

If `obsidian read` returns an error or empty content:
- Tell the user: "No daily note found for YYYY-MM-DD."
- Check the previous 2 days with `obsidian read path="daily/YYYY-MM-DD.md"` (both in parallel) and offer those as alternatives.
- Stop here — don't fabricate content.

### Step 3: Analyze the content

The notes are voice-dictated stream-of-consciousness — rambling, mixing topics, sometimes with markdown headers for meetings. Parse with that expectation.

Group related thoughts into themes. Common categories (use whichever apply, don't force all):

- **Strategy / big picture** — business thinking, positioning, roadmap ideas
- **Technical** — architecture decisions, code plans, debugging notes
- **People / org** — team dynamics, hiring, feedback, 1:1 notes
- **Action items** — explicit TODOs, commitments, follow-ups (stated or implied)
- **Meetings** — notes from specific meetings (often under headers)
- **Personal** — non-work reflections, health, habits

### Step 4: Present themed summary

For each theme, write 2-4 bullet points capturing the substance — not a transcript rehash. Use <<USER_NAME>>'s own language where it's vivid. Preserve specific names, numbers, and decisions.

Flag any **decisions or commitments** made (e.g., "told Sarah we'd ship by Friday", "decided to drop the Kafka approach").

### Step 5: Surface action items

Pull out a flat list of action items — both explicit ("I need to...") and implied ("should probably talk to X about Y"). Mark implied ones as such. **Format every action item as an Obsidian checkbox** (`- [ ]`) so they're trackable in the daily note. **Always add due dates** using the Obsidian Tasks plugin format: `📅 YYYY-MM-DD` appended inline. Infer dates from context (e.g., "by end of week" = Friday, "next week" = following Monday, immediate follow-ups = next business day). This is required for tasks to appear in the Obsidian Tasks plugin queries (`Tasks.md`).

### Step 6: Clean up the daily note

After analysis, rewrite the daily note file to replace the raw voice dictation with a clean, structured version. The cleaned note should contain:

1. **Original dictation** — preserve the raw text in a collapsed callout block so nothing is lost:
   ```
   > [!note]- Raw dictation
   > (original voice-dictated text here)
   ```
2. **Themed summary** — the same themed bullets presented to the user (use `##` headers per theme)
3. **Action items** — the extracted checkboxes under a `## Action items` header

**Writing the cleaned note back**: Use the Write tool to write the entire cleaned note to `daily/YYYY-MM-DD.md` in a single call. This is faster and simpler than chunked obsidian CLI appends. The obsidian CLI does NOT truncate long content (tested up to 100K chars), but the Write tool avoids the overhead of multiple sequential shell calls entirely.

**Do NOT use `obsidian append` or `obsidian create` to write the cleaned note.** Always use the Write tool. Compose the entire file in memory first, then write once. No exceptions.

### Step 7: Ask follow-up questions

Ask 2-3 targeted questions to help prioritize the day. These should:
- Connect themes to each other where relevant
- Push toward concrete next steps
- **Actively surface tensions, contradictions, or competing priorities** in the notes — e.g., two people being assigned overlapping work, commitments that conflict with available time, or stated goals that pull in different directions. <<USER_NAME>> values this kind of nudge.
- Cross-reference with the calendar — flag if a meeting is coming up that relates to an unresolved action item, or if the day looks packed and some items might need to be deferred

Examples: "You mentioned both X and Y — are those competing for this week?" or "The commitment to Z by Friday — is that still realistic given the refactor?" or "You have a 1:1 with Anh at 3pm — is that where you'd want to raise the resourcing ask?"

## Granola Meeting Links

When the user provides Granola meeting URLs (e.g., `https://notes.granola.ai/t/<id>`), add them to the relevant meeting section in the daily note:

1. **Extract the meeting ID** from the URL — the UUID before the hyphenated suffix (e.g., `c445f38e-4303-40dd-89cd-d0b15f18df9e` from `.../t/c445f38e-4303-40dd-89cd-d0b15f18df9e-008umkv4`)
2. **Match to a meeting heading** already in the daily note (by title or time) and add a `[Granola](<url>)` link to the **Doc**/**links** line
3. **If the meeting has no summary content yet** (e.g., it was a stub or just had an agenda), try `mcp__granola__get_meetings` with the ID to fetch the AI summary and populate the section
4. **If Granola returned "No summary"** for the meeting, keep the link-only stub — the link itself is still valuable as a reference to the Granola page where the user may have private notes
5. **If a meeting section doesn't exist yet**, create one under `## Granola Meeting Notes` with the standard format (heading, attendees, summary sections)

This workflow is separate from `/meeting-sync` (which bulk-syncs all meetings for a date). Granola links — historical only, since Granola was banned at Fetch 2026-04-20 — are for targeted enrichment of specific older meetings where the user still has the URL.

## Edge Cases

- **Weekend dates**: Process normally — <<USER_NAME>> sometimes dictates on weekends
- **Very short notes** (< 5 lines): Summarize briefly, note it was a light day, still ask follow-ups
- **Multiple days requested**: Process each date sequentially, present separately
- **Headers present**: Use them as natural theme boundaries but don't be limited by them
