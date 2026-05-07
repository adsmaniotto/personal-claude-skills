---
marp: true
theme: gaia
size: 16:9
paginate: true
backgroundColor: "#6b1bcf"
header: Tony Smaniotto · Automation Labs
footer: Fetch AI Dev Day · 2026-05-08
style: |-
  /* Palette: purple #6b61de + orange #ffa400 (Eye Dropper sample) */
  section {
    font-family: -apple-system, "SF Pro Display", system-ui, sans-serif;
    color: #ffffff;
    background-color: #6b1bcf;
    font-size: 22px;
    line-height: 1.4;
  }
  section h1 {
    font-size: 1.8em;
    margin-bottom: 0.5em;
  }
  section p {
    margin: 0.8em 0;
  }
  section li {
    margin: 0.4em 0;
  }
  h1, h2 {
    color: #ffffff;
  }
  h3, h4 {
    color: #ffd9a0;
  }
  strong {
    color: #ffa400;
  }
  a {
    color: #ffa400;
  }
  code {
    background: rgba(255, 255, 255, 0.12);
    color: #ffd9a0;
    padding: 0 0.3em;
    border-radius: 3px;
    font-family: ui-monospace, "SF Mono", Menlo, monospace;
  }
  pre code {
    background: #1f2937;
    color: #f9fafb;
    border-radius: 6px;
  }
  blockquote {
    color: #e8e3f5;
    border-left: 4px solid #ffa400;
    font-style: italic;
  }
  table {
    color: #ffffff;
  }
  th, td {
    border-color: rgba(255, 255, 255, 0.25);
  }
  header, footer {
    color: rgba(255, 255, 255, 0.75);
  }
  /* split layout for the meta-demo slide */
  section.split {
    display: grid;
    grid-template-columns: 1fr 1fr;
    grid-template-rows: auto 1fr;
    gap: 1.2rem;
  }
  section.split h2 {
    grid-column: 1 / 3;
    margin-bottom: 0;
  }
  section.split pre {
    font-size: 0.55em;
    margin: 0;
  }
  section.split .right {
    align-self: center;
  }
  /* Title + closing slides use the gradient */
  section.lead {
    background: linear-gradient(135deg, #6b61de 0%, #ffa400 100%);
  }
  section.lead h1 {
    font-size: 2.6em;
    line-height: 1.1;
    color: #ffffff;
  }
  section.lead h3, section.lead p {
    color: #ffffff;
  }
  section.huge {
    text-align: center;
    background: linear-gradient(135deg, #6b61de 0%, #ffa400 100%);
  }
  section.huge h1 {
    font-size: 4em;
    margin: 0;
    color: #ffffff;
  }
  section.huge h4 {
    color: #ffffff;
  }
---

<!-- _class: lead -->

# Building a Knowledge Management System

### *(or "My Other Brain Runs on Claude Code")*

**Tony Smaniotto** · Automation Labs
Fetch AI Dev Day · 2026-05-08

---

# Knowledge management is a P0 need in a Tech Lead role

Staying present and focused on what matters while also
- Having productive meetings + processing info from them (Avg 5 meetings/day)
- Posting on Slack (13 channels and 10 DMs last week!)
- Writing docs
- Writing code
- Sometimes my kid busts in the room and demands Claude to draw a picture for him

**Context management is a bottleneck to good decision-making.**

<!-- Speaker note: name a relatable example — meeting on Tuesday, decision logged in Slack on Wednesday, by Friday it's gone. -->

---

# The plan? Ramble into my AirPods while I walk my dog every morning and let Claude figure out what to do with it.

Leaning hard into voice-to-text wherever possible.

**Superwhisper**: transcribes my voice notes on mobile and desktop

**Obsidian**: a notes app on steroids (syncs cross-platform)

**Claude Code**: sits on top of my notes vault + treats it like any other repo. Synthesizes raw dictation, calendar events, and pre-existing docs to help me contextualize the day ahead of me.

---

# The notes are managed with Skills


🎙 **`/daily-notes`** → voice memo from this morning + calendar analysis = structured themes + action items (and when's the best time to tackle them)

💬 **`/slack-catchup`** → DMs and @-mentions where I'm "on read" surface as a triage list (I also run this at end-of-day).

📧 **`/gmail-triage`** → important threads (Doc mentions, calendar invites) get lifted out of the noise.

🧾 **`/meeting-sync`** → notes from prior meetings (Zoom + Superwhisper transcripts) land in the vault as wiki entries.

**By 9am** all of these have ran and Claude gives me a read on what today might look like.

---

# The Skills are powered by Tools

Each skill is markdown. The markdown points at real integrations.

📥 **Slack MCP** *(Anthropic's connector)* → `/slack-catchup`

📅 **`gws` CLI** *(Google Workspace — Calendar, Docs, Sheets, Slides, Drive, Gmail)* → `/daily-notes`, `/gmail-triage`, `/create-google-doc`, `/gdocs-sync`, `/write-slides`

📨 **Atlassian MCP** *(Confluence + Jira)* → `/confluence-sync`, `/jira-board`

🗂 **Obsidian CLI** *(read/write the vault from the terminal)* → `/daily-notes`, `/integrate-into-wiki`, `/obsidian-cli`

🎙 **Superwhisper** + **Hammerspoon** *(local: voice transcription + macOS triggers)* → `/meeting-sync`, `/transfer-notes`

🎨 **Marp CLI** → renders this exact markdown into the deck you're looking at.

---
# The outcome: 
---

# I can even turn my local notes into decks

I write a doc in Obsidian and `marp --server --watch` renders it.

Watch the heading change when I save.

> *(live demo — type a word, hit ⌘S)*

---

# Caveats

- The LLM **hallucinates**. I still have to read.
- Claude weighs all docs equal importance.
- Memory **drifts**.
- The setup itself is **work**. Days, not hours.

But the *steady-state* maintenance is the cheap part now.

That's the unlock.

---

# Try this in 30 minutes

1. Drop a `CLAUDE.md` in your repo or vault. Tell Claude what it's looking at.
2. Pick one source — an article, a meeting note. Have Claude integrate it into one wiki page with cross-references.
3. Take one repetitive workflow. Make it a skill. *(One markdown file.)*

> The LLM does the bookkeeping.
> You do the curation.
> Wikis stop being mausoleums.

---

<!-- _class: huge -->

# Questions?

#### *Or just read the source —*
#### `~/ObsidianVault/drafts/lightning-talk-knowledge-base.md`
