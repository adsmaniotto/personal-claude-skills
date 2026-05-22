---
name: print-doc
description: >
  Print a document to the default printer. Accepts a markdown file (vault path
  or shorthand), a Google Docs URL, a Google Slides URL, a Google Drive file
  URL, or any local PDF. Markdown is rendered via pandoc + Chrome headless;
  Google Workspace files are exported as PDF via gws. Triggered by "print this",
  "print today's daily", "print [file]", "print this gdoc", "send to printer",
  or any request to put a doc on paper.
tags: [print, vault, obsidian, gdrive, utility]
user_invocable: true
---

# Print Document

Send a document to the system default printer. Supports markdown (vault notes), Google Docs, Google Slides, Google Drive files, and local PDFs — all collapsed to a single `lp` print call.

This skill assumes the printer is already set up in **System Settings → Printers & Scanners**. If your printer vendor's installer can't discover your Mac, the macOS AirPrint queue almost always works — add the printer there instead and skip the vendor app.

## Prerequisites

- **macOS** (uses `lp`, `sips`, Chrome at the standard path)
- A default printer. Verify: `lpstat -d`. If no default, pass `--printer <queue>`.
- `pandoc` (`brew install pandoc`) — only required for markdown input
- Google Chrome at `/Applications/Google Chrome.app/` — only required for markdown input. Chromium/Brave/Edge work too (swap the binary path in Step 2c).
- `gws` CLI configured — only required for Google Docs/Slides/Drive input
- `jq` — only required for the generic Drive branch (Step 4) — `brew install jq`
- For page-range printing: nothing extra; `lp -P` handles it

## Input dispatch

The user supplies one of:

| Input shape | Branch |
|---|---|
| `today`, `yesterday`, `today's daily` | Markdown → Step 2 |
| `<<VAULT_PATH>>/...md` or any `.md` path | Markdown → Step 2 |
| Bare filename or partial title | Search vault, then Markdown → Step 2 |
| `https://docs.google.com/document/d/<id>/...` | Google Doc → Step 3 |
| `https://docs.google.com/presentation/d/<id>/...` | Google Slides → Step 3 |
| `https://drive.google.com/file/d/<id>/...` | Google Drive file → Step 4 |
| Local `.pdf` path | Already-a-PDF → Step 5 directly |

Optional flags (parse from the user's message):

| Flag | Effect | lp option |
|---|---|---|
| `-n N`, `N copies` | print N copies | `-n N` |
| `--duplex`, `double-sided`, `two-sided` | double-sided (long-edge) | `-o sides=two-sided-long-edge` |
| `--pages 1`, `--pages 1-3`, `--pages 2,4,7`, `page 1 only` | restrict to a page range | `-P <range>` |
| `--preview`, `preview first` | open the PDF in Preview before printing; confirm with user | (skip lp) |
| `--paper letter\|a4` | paper size (default: Letter) | `-o media=Letter\|A4` |
| `--printer <queue>` | override default printer | `-d <queue>` |

## Step 1 — Setup temp workspace

Always work in a temp directory with named files. Do NOT use `mktemp -t prefix.ext` — on macOS that appends random chars after your template, so the file ends up without the expected extension, and Chrome will print HTML source as text instead of rendering it. Use `mktemp -d` and name the files yourself.

```bash
TMP=$(mktemp -d -t print-doc)
PDF="$TMP/out.pdf"
```

## Step 2 — Markdown branch (pandoc + Chrome)

### 2a — Resolve file

```bash
case "$input" in
  today|"today's daily"*) file="<<VAULT_PATH>>/daily/$(date +%F).md" ;;
  yesterday|"yesterday's daily"*) file="<<VAULT_PATH>>/daily/$(date -v-1d +%F).md" ;;
  /*|~*) file="$input" ;;
  *) file=$(find <<VAULT_PATH>> -iname "*${input}*.md" | head -1) ;;
esac
[ -f "$file" ] || { echo "Not found: $file"; exit 1; }
```

If multiple matches, list and ask.

### 2b — Render to styled HTML

Pandoc consumes YAML frontmatter as metadata (won't print in body — good). Wikilinks `[[Name]]` and callout markers `> [!note]-` print as literal text — acceptable. To strip the callout markers: `sed -E 's/> \[![a-z]+\]-? ?/> /'` before pandoc.

```bash
TITLE=$(basename "$file" .md)
CSS="$TMP/style.css"
HTML="$TMP/doc.html"

cat > "$CSS" <<'EOF'
body { font-family: -apple-system, system-ui, sans-serif; max-width: 7in; margin: 0.5in auto; line-height: 1.5; color: #222; }
h1, h2, h3 { color: #111; }
h1 { font-size: 1.6em; border-bottom: 1px solid #ddd; padding-bottom: 0.2em; }
h2 { font-size: 1.3em; margin-top: 1.5em; }
code { background: #f4f4f4; padding: 2px 4px; border-radius: 3px; font-size: 0.9em; }
pre { background: #f4f4f4; padding: 0.8em; border-radius: 4px; overflow-x: auto; }
blockquote { border-left: 3px solid #ccc; padding-left: 1em; color: #555; margin-left: 0; }
table { border-collapse: collapse; margin: 0.5em 0; }
th, td { border: 1px solid #ddd; padding: 4px 8px; text-align: left; }
ul, ol { padding-left: 1.5em; }
hr { border: none; border-top: 1px solid #ddd; margin: 1.5em 0; }
EOF

pandoc "$file" -o "$HTML" --standalone --metadata title="$TITLE" -c "$CSS"
```

### 2c — HTML → PDF via Chrome headless

```bash
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
  --headless --disable-gpu --no-pdf-header-footer \
  --print-to-pdf="$PDF" "file://$HTML" 2>/dev/null
```

Sanity-check: `file "$PDF"` should say `PDF document`. If it contains raw HTML text, the extension on `$HTML` was wrong — re-check 2b.

Browser alternates: swap the binary path for `Chromium.app/Contents/MacOS/Chromium`, `Brave Browser.app/Contents/MacOS/Brave Browser`, or `Microsoft Edge.app/Contents/MacOS/Microsoft Edge`.

Jump to Step 5.

## Step 3 — Google Docs / Slides branch

Extract the file ID from the URL (`docs.google.com/document/d/<id>/...` or `docs.google.com/presentation/d/<id>/...`):

```bash
FILE_ID=$(echo "$url" | sed -E 's|.*/d/([^/]+).*|\1|')
```

Export directly as PDF — both Docs and Slides support `application/pdf` export:

```bash
gws drive files export \
  --params "{\"fileId\": \"$FILE_ID\", \"mimeType\": \"application/pdf\"}" \
  --output "$PDF"
```

Verify: `file "$PDF"` should say `PDF document, version 1.4, N pages`.

Jump to Step 5.

## Step 4 — Google Drive file branch (generic)

For `drive.google.com/file/d/<id>/...`, first check the MIME type — could be a native PDF (use `get`), a Google Doc (use `export`), or something else.

```bash
FILE_ID=$(echo "$url" | sed -E 's|.*/file/d/([^/]+).*|\1|')
META=$(gws drive files get --params "{\"fileId\": \"$FILE_ID\", \"fields\": \"name,mimeType\"}")
MIME=$(echo "$META" | jq -r '.mimeType')

case "$MIME" in
  application/pdf)
    gws drive files get --params "{\"fileId\": \"$FILE_ID\", \"alt\": \"media\"}" --output "$PDF" ;;
  application/vnd.google-apps.document|application/vnd.google-apps.presentation)
    gws drive files export --params "{\"fileId\": \"$FILE_ID\", \"mimeType\": \"application/pdf\"}" --output "$PDF" ;;
  application/vnd.google-apps.spreadsheet)
    echo "Sheets-as-PDF rarely looks good; ask user to confirm before continuing"
    gws drive files export --params "{\"fileId\": \"$FILE_ID\", \"mimeType\": \"application/pdf\"}" --output "$PDF" ;;
  image/*)
    gws drive files get --params "{\"fileId\": \"$FILE_ID\", \"alt\": \"media\"}" --output "$TMP/img"
    sips -s format pdf "$TMP/img" --out "$PDF" ;;
  *) echo "Unhandled mime: $MIME"; exit 1 ;;
esac
```

Jump to Step 5.

## Step 5 — Preview (if requested), then print

```bash
if [ "$preview" = true ]; then
  open -a Preview "$PDF"
  # ask user to confirm before continuing
fi

opts=()
[ -n "$copies" ] && opts+=(-n "$copies")
[ "$duplex" = true ] && opts+=(-o sides=two-sided-long-edge)
[ -n "$pages" ] && opts+=(-P "$pages")           # e.g. -P 1, -P 1-3, -P 2,4,7
[ "$paper" = "a4" ] && opts+=(-o media=A4) || opts+=(-o media=Letter)
[ -n "$printer" ] && opts+=(-d "$printer")

lp "${opts[@]}" "$PDF"
```

Report the job ID (e.g., `request id is <queue>-NN`) back to the user. Cancel with `cancel <job-id>`; check status with `lpstat -W not-completed`.

## Notes

- **Markdown frontmatter** is metadata to pandoc — doesn't print in body.
- **Wikilinks** `[[Name]]` print verbatim.
- **Embeds** `![[file.png]]` won't resolve.
- **Daily-note dictation callouts** print as quoted blocks — readable.
- **Sheets as PDF**: the export will fit each tab to a page; for long spreadsheets, ask the user if they want a specific tab or filtered range first.
- **Slides**: each slide becomes a page. `--pages 1-5` for a deck excerpt.
- **Long docs**: default to `--preview` first if `file "$PDF"` reports >10 pages.
- **Job tracking**: `lpstat -W not-completed`. Clear stuck queue: `cancel -a <queue>`.
