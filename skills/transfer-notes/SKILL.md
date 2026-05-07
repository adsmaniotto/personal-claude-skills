---
name: transfer-notes
description: Install, troubleshoot, or retrigger <<USER_NAME>>'s Zoom → Superwhisper → Obsidian → Claude transcription pipeline. Use when the user says "set up zoom transcription", "fix zoom transcripts", "why didn't my zoom get transcribed", "check transcript log", "retrigger that transcript", "my last meeting didn't save", "reinstall zoom automation", or anything that sounds like debugging or rebuilding the automated meeting-note pipeline.
tags: ['obsidian', 'zoom', 'superwhisper', 'hammerspoon', 'automation', 'transcripts']
user_invocable: true
---

# Zoom Transcript Sync (transfer-notes)

Manage <<USER_NAME>>'s end-to-end automated meeting-note pipeline. The pipeline runs continuously in the background — this skill is for **installing**, **troubleshooting**, **retriggering**, and **tuning** it.

## How the pipeline works

1. **Hammerspoon** (`~/.hammerspoon/init.lua`) watches for Zoom meeting windows using `hs.window.filter`.
2. When a meeting window appears → fires `superwhisper://record` URL scheme → Superwhisper starts recording in **Voice mode** (raw transcript only, no LLM processing by Superwhisper).
3. When the meeting window closes → fires `superwhisper://record` again (toggle) → Superwhisper stops. After a 15s delay (lets Superwhisper finalize) → invokes `~/.hammerspoon/process-zoom-transcript.sh`.
4. The script finds the newest Superwhisper recording, filters out short ones (< 30s or < 200 chars), then shells out to `claude -p` with a prompt that:
   - Reads the raw transcript from `meta.json`'s `result` field
   - **Queries Google Calendar** (`gws calendar events list`) for the event that was happening during the recording window — pulls the real meeting title and attendees
   - Writes a structured markdown file to `<vault>/zoom/YYYY-MM-DD HHMM - <real meeting title>.md` (frontmatter + Summary + Discussed topics + Action items + collapsed full transcript)
   - **Appends structured notes** (Summary + Discussed topics + Action items, without the transcript callout) to the current daily note under `## Meetings`, with a wikilink to the full file
5. A macOS notification fires when complete.

**State is managed in Hammerspoon**: `isRecording` flag + 2.5s debounce prevent double-toggles from rapid Zoom window events (pre-meeting window flashes in/out).

## Constants and file paths

- **Hammerspoon config**: `~/.hammerspoon/init.lua`
- **Processing script**: `~/.hammerspoon/process-zoom-transcript.sh`
- **Superwhisper recordings**: `~/Documents/superwhisper/recordings/<unix_timestamp>/meta.json`
- **Vault output**: `<<VAULT_PATH>>/zoom/`
- **Daily note**: `<<VAULT_PATH>>/daily/YYYY-MM-DD.md`
- **Log**: `/tmp/zoom-transcript.log`
- **Claude CLI**: `/usr/local/bin/claude` (absolute path required — Hammerspoon's PATH doesn't include `/usr/local/bin`)
- **Zoom window titles watched**: `"Zoom Meeting"`, `"Zoom Webinar"`
- **Debounce**: 2.5s (coalesces rapid window events)
- **Post-meeting delay before processing**: 15s (lets Superwhisper finalize)
- **Skip thresholds**: duration < 30s OR transcript < 200 chars

## Common operations

### Troubleshoot: "my last meeting didn't get transcribed"

Check in this order:

1. **Read the log**: `tail -50 /tmp/zoom-transcript.log`. Expect lines like `=== <date> ===` then `Processing recording <id> (<sec>s, <chars> chars)` then `Done`.
2. **Common log signatures**:
   - `Skipped: <N>s, <M> chars` → recording below the 30s/200char threshold. Normal for mic checks; if it's a real meeting, lower the threshold in the script.
   - `claude: command not found` → PATH issue. Script should hardcode `/usr/local/bin/claude`.
   - `skipped: not a meeting` → Claude's content filter decided the transcript wasn't a real meeting. Look at the raw `result` in the newest Superwhisper recording to see what it actually captured.
   - No new log entries at all → Hammerspoon never fired the script. Check: (a) Hammerspoon running? (menu bar icon), (b) Accessibility permission granted? (System Settings → Privacy & Security → Accessibility), (c) window title actually "Zoom Meeting"? (Zoom occasionally changes this — see "Debug Zoom window titles" below).
3. **Check the newest recording**: `ls -1t ~/Documents/superwhisper/recordings/ | head -3` → look at `meta.json` to verify Superwhisper actually recorded.

### Retrigger manually for a specific recording

The script always processes the **newest** recording. To force processing of a specific older recording, `touch` it first:

```bash
touch ~/Documents/superwhisper/recordings/<timestamp>/
bash ~/.hammerspoon/process-zoom-transcript.sh
```

### Fake a recording to test the pipeline

When you need to verify the Claude → vault write path without joining a real Zoom (e.g., after changing the summarization prompt), write a synthetic `meta.json` with meeting-like content:

```bash
TS=$(date +%s)
DIR="$HOME/Documents/superwhisper/recordings/$TS"
mkdir -p "$DIR"
cat > "$DIR/meta.json" <<'JSON'
{
  "datetime": "<ISO datetime>",
  "duration": 420000,
  "modeName": "Voice",
  "result": "<at least 200 chars of meeting-like content — multiple topics, named people, decisions. If it sounds like a mic test, Claude will skip it.>"
}
JSON
bash ~/.hammerspoon/process-zoom-transcript.sh
```

### Reinstall the pipeline on a new Mac

1. `brew install --cask hammerspoon` and launch it. Grant Accessibility permission.
2. Ensure Superwhisper is installed and `superwhisper://record` URL scheme is enabled in its settings.
3. Drop `init.lua` into `~/.hammerspoon/` (see **Reference: init.lua** below).
4. Drop `process-zoom-transcript.sh` into `~/.hammerspoon/` and `chmod +x` it (see **Reference: process-zoom-transcript.sh** below).
5. Confirm `/usr/local/bin/claude` exists (`which claude`). If Claude CLI is elsewhere, update the hardcoded path in the script.
6. Confirm `/usr/bin/jq` exists.
7. Reload Hammerspoon config (menu bar → *Reload Config*). Expect a floating alert confirming reload.
8. Test: fake a recording (see above) and verify a new file appears in `<vault>/zoom/`.

### Debug Zoom window titles

If Hammerspoon stops firing because Zoom changed its window title, replace the `init.lua` with the diagnostic version that logs every Zoom window's title on creation:

```lua
local zoomFilter = hs.window.filter.new(false):setAppFilter("zoom.us")
zoomFilter:subscribe(hs.window.filter.windowCreated, function(win)
  hs.alert.show("Zoom window: '" .. (win:title() or "nil") .. "'", 4)
end)
```

Join a meeting, note the exact title Zoom uses, then update the `allowTitles` list in the production `init.lua` to include it.

### Tune the summarization prompt

The prompt Claude uses to format the vault file lives inside `process-zoom-transcript.sh` as the `PROMPT` variable. To adjust:

- **Make summaries longer/shorter** → change "3-5 bullets" instruction.
- **Change the file structure** → edit the file-structure spec in the prompt.
- **Add routing** (e.g. 1:1s to `people/<name>.md` instead of `zoom/`) → add a classification instruction to the prompt. The existing prompt puts everything under `zoom/` intentionally; adding routing is a later enhancement.
- **Change the daily-note pointer format** → edit step 4 of the prompt.

After editing the prompt, re-run against the latest recording to verify output quality before relying on it for a real meeting.

### Disable the automation temporarily

Quit Hammerspoon from the menu bar, or comment out the two `zoomFilter:subscribe` lines in `init.lua` and reload config.

## Known quirks

- **Option+Space conflict with Granola**: the pipeline uses the `superwhisper://record` URL scheme specifically because Granola *also* binds Option+Space, so sending a raw keystroke lets Granola win the race. Don't revert to keystroke-based triggering unless Granola is uninstalled.
- **Whisper "thank you" hallucination**: if you see a new vault file with just a "thank you" transcript, it means Superwhisper recorded near-silence and Whisper hallucinated — the real bug is the pipeline fired start/stop in rapid succession. The debounce should prevent this, but if you see it recurring, the debounce window may need to be larger than 2.5s.
- **Voice mode only**: Superwhisper has other modes (Default, Meeting Minutes) but the pipeline explicitly uses Voice so Claude — not Superwhisper — controls summarization. Don't switch to Meeting Minutes mode unless you're also willing to rewrite the prompt.
- **Headless Claude needs `--dangerously-skip-permissions`**: the script runs under Hammerspoon with no TTY, so Claude can't prompt for Edit/Write approvals. This is why the flag is present. Acceptable risk on <<USER_NAME>>'s own machine running his own script.
- **Frontmatter is queryable via Obsidian Bases**: every vault file gets `datetime`, `source`, `duration_sec`, `recording_id` in YAML frontmatter. Build a Base over `zoom/` if you want a sortable index.

## What this skill *doesn't* do (on purpose)

- **No classification routing to `people/` or `team/`**: every meeting lands in `zoom/` with a calendar-derived title. The old transfer-notes routed 1:1s into `people/<name>.md` based on SuperWhisper Meeting Minutes mode — dead code because <<USER_NAME>> uses Voice mode. If <<USER_NAME>> wants per-person aggregation, the place to add it is the Claude prompt in `process-zoom-transcript.sh` (detect 2-person events and append to `people/<other-person>.md` instead).
- **No bulk backfill** — this skill manages the *continuous automation only*. For retroactive sync (e.g., "process yesterday's recordings", "backfill last week"), use the `meeting-sync` skill.
- **No Superwhisper mode switching**: the pipeline assumes Voice mode. Switching modes is a Superwhisper settings change, not a skill operation.

## Companion skill

- **`meeting-sync`** = the manual/bulk version of this pipeline. Processes Superwhisper recordings for a given date range, matches each to a calendar event, writes to `zoom/` and daily note. Same output format as this skill's auto-pipeline. Invoke when auto-pipeline missed a meeting, when you recorded outside Zoom (Google Meet, Teams, phone), or for date-range backfills. *(Renamed from `granola-sync` 2026-05-07.)*

## Reference: `init.lua`

```lua
-- Trigger Superwhisper recording for Zoom meetings + process transcript after.
-- Zoom fires multiple window events when joining (pre-meeting window flashes in/out),
-- and superwhisper://record is a toggle, so we debounce and track state.

local isRecording = false
local debounceTimer = nil

local function hasMeetingWindow()
  local wins = hs.window.filter.new(false)
    :setAppFilter("zoom.us", { allowTitles = { "Zoom Meeting", "Zoom Webinar" } })
    :getWindows()
  return #wins > 0
end

local function processTranscript()
  local script = os.getenv("HOME") .. "/.hammerspoon/process-zoom-transcript.sh"
  hs.task.new("/bin/bash", nil, { script }):start()
end

local function syncRecordingState()
  if debounceTimer then debounceTimer:stop() end
  debounceTimer = hs.timer.doAfter(2.5, function()
    local inMeeting = hasMeetingWindow()
    if inMeeting and not isRecording then
      hs.urlevent.openURL("superwhisper://record")
      isRecording = true
      hs.notify.new({ title = "Superwhisper", informativeText = "Started (Zoom joined)" }):send()
    elseif not inMeeting and isRecording then
      hs.urlevent.openURL("superwhisper://record")
      isRecording = false
      hs.notify.new({ title = "Superwhisper", informativeText = "Stopped (Zoom ended) — processing..." }):send()
      hs.timer.doAfter(15, processTranscript)
    end
  end)
end

local zoomFilter = hs.window.filter.new(false)
  :setAppFilter("zoom.us", { allowTitles = { "Zoom Meeting", "Zoom Webinar" } })

zoomFilter:subscribe(hs.window.filter.windowCreated, syncRecordingState)
zoomFilter:subscribe(hs.window.filter.windowDestroyed, syncRecordingState)
```

## Reference: `process-zoom-transcript.sh`

The script is the source of truth — read the live file directly rather than trusting a cached copy in this doc (prevents drift):

```bash
cat ~/.hammerspoon/process-zoom-transcript.sh
```

High-level behavior the script orchestrates:

1. Find the newest Superwhisper recording folder
2. Extract `result` (transcript), `datetime`, `duration` from `meta.json`
3. Skip if < 30s or < 200 chars
4. Hand off to Claude via `/usr/local/bin/claude --dangerously-skip-permissions -p` with a prompt that tells Claude to:
   - Query Google Calendar (`gws calendar events list` on <<USER_NAME>>'s personal calendar) for the event overlapping the recording window
   - Filter out non-meeting events (workingLocation, focusTime, Home/Office/BLOCK blockers, all-day events)
   - Write full notes (summary + discussed topics + action items + collapsed full transcript) to `<vault>/zoom/YYYY-MM-DD HHMM - <real title>.md`
   - Append structured notes (same content minus transcript callout) to daily note under `## Meetings`
   - Skip entirely if transcript is clearly not a real meeting

If the script gets out of sync with this doc or needs modification, edit the live file at `~/.hammerspoon/process-zoom-transcript.sh` — the doc describes intent, not implementation.
