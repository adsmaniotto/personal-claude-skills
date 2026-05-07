---
name: integrate-into-wiki
description: >
  Take a raw source file (synced Confluence page, Google Doc, Zoom note, or
  pasted article) and integrate its content into <<USER_NAME>>'s Obsidian wiki layer —
  updating relevant project/people/team pages with cross-references, deltas,
  and new context. Append an entry to log.md. Triggered by "integrate this
  into the wiki", "fold X into the wiki", "/integrate", "process this source",
  "absorb this into the vault".
tags: ['obsidian', 'wiki', 'ingest', 'knowledge-base']
user_invocable: true
---

# Integrate Source into Wiki

<<USER_NAME>>'s Obsidian vault follows the [LLM Wiki pattern](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f): raw sources land in `confluence/`, `google-docs/`, `zoom/`, `daily/`. The *wiki layer* (`projects/`, `drafts/`, `teams/`, `people/`) is supposed to evolve as new sources arrive — but sync skills only deposit raw files; they don't update wiki pages. This skill closes that gap.

## When to use

The user invokes this with a path to a recently-synced or newly-added file. Examples:

- "Integrate `confluence/fl/TRIM-2.0-...md` into the wiki"
- "Fold `zoom/2026-04-28 1435 - QA (Triforce) Tool.md` into the relevant projects"
- "/integrate google-docs/eng/q2-okr-doc.md"

## Execution

### Step 1: Read and understand the source

`Read` the source file in full. Identify:

1. **Entities mentioned** — people (cross-reference `people/*.md`), projects (cross-reference `projects/*.md`), teams (cross-reference `teams/*.md`). Use `Glob` over each folder to get the canonical names; don't hardcode.
2. **Concepts and decisions** — anything that materially changes the picture for an existing wiki page (new commitment, new constraint, new deadline, new owner, new tradeoff).
3. **New territory** — concepts mentioned that don't have a wiki page yet, but probably should (high-frequency cross-references, named projects/products, recurring people).

### Step 2: Plan the integration

Before editing anything, present a brief plan to the user:

- Which wiki pages will be updated (with one-line reason each)
- Which new pages might be worth creating (name + why) — but **don't auto-create**; ask
- Which entity references in the source are dead links (mentioned but not in the wiki)

Wait for user confirmation before editing. This is a **read-mostly** operation by default.

### Step 3: Make the edits

For each wiki page being updated:

- Append a dated note under a relevant section (or a new "Recent updates" section if none fits).
- Format: `**YYYY-MM-DD** *(via [[<source-filename>|source]])*: <one-paragraph integration note>` — keep the note tight, not a transcript rehash.
- Cross-link: when the integration note mentions other entities, wikilink them.
- Preserve the source as-is — never modify files in `confluence/`, `google-docs/`, `zoom/`, `daily/`.

### Step 4: Update the index

If any wiki pages were created (after user confirmation in Step 2), update `<<VAULT_PATH>>/index.md` to include them in the appropriate section. See the index.md "Maintained by Claude Code" header — same convention.

### Step 5: Log it

Append an entry to `<<VAULT_PATH>>/log.md` in the parseable format:

```
## [YYYY-MM-DD] integrate | <source filename or short title>

- pages updated: [[page1]], [[page2]], …
- pages created: [[newpage]] (if any)
- key takeaways folded in: <2–3 bullets>
```

The `## [YYYY-MM-DD]` prefix matters — it makes `grep "^## \[" log.md | tail -10` work for quick recent-history scans.

## What this skill does NOT do

- **Does not summarize or rewrite the source itself.** The source is immutable — it stays raw in `confluence/` / `google-docs/` / `zoom/` / `daily/`.
- **Does not auto-create wiki pages.** New page creation requires explicit user OK in Step 2.
- **Does not reorganize the vault.** Folder structure and existing page locations are untouchable.

## Edge cases

- **Source is huge** (e.g. a 50-page Confluence doc): identify which sections are wiki-relevant; integrate only those. Note in the log entry which sections were skipped and why.
- **Source contradicts a wiki page**: surface the contradiction explicitly in the integration note (don't silently overwrite). <<USER_NAME>> decides which is current.
- **Source has no wiki-relevant content** (e.g. a personal call's zoom note): say so, append a log entry noting "no integration", do not edit any wiki pages.
- **Source filename has spaces**: use Obsidian's display-text wikilink syntax `[[2026-04-28 1435 - QA (Triforce) Tool|Triforce meeting 4/28]]` for cross-references.
