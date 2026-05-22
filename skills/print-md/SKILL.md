---
name: print-md
description: >
  Print a markdown file from your Obsidian vault (or anywhere on disk) to the
  default printer. Renders markdown → styled PDF via pandoc + Chrome headless,
  then sends to lp. Handles Obsidian wikilinks, callouts, and frontmatter
  gracefully. Triggered by "print this", "print today's daily", "print [file]",
  "send to printer", or any request to put a markdown doc on paper.
tags: [print, vault, obsidian, utility]
user_invocable: true
---

# Print Markdown

Render a markdown file (typically from your Obsidian vault) into a styled PDF and send it to the system default printer.

This skill assumes the printer is already set up in **System Settings → Printers & Scanners**. If the printer vendor's installer is failing to discover your Mac, the AirPrint queue almost always works — add the printer there instead and skip the vendor app.

## Prerequisites

- **macOS** (uses `lp`, Chrome at the standard `/Applications/Google Chrome.app/` path)
- A printer set as default. Verify: `lpstat -d` should print `system default destination: <queue>`. If not, run `lpstat -p` to list queues and either set a default in System Settings or pass `-d <queue>` to `lp`.
- `pandoc` (Homebrew: `brew install pandoc`)
- Google Chrome — used as the PDF renderer. We deliberately avoid pandoc's `wkhtmltopdf` / `pdflatex` backends because neither is reliably installed on macOS. If you use Chromium, Brave, or Edge, swap the binary path in Step 3.

## Inputs

The user supplies one of:

- **A vault shorthand**:
  - `today` → `<<VAULT_PATH>>/daily/$(date +%F).md`
  - `yesterday` → `<<VAULT_PATH>>/daily/$(date -v-1d +%F).md`
  - `today's daily note`, `yesterday's daily`, etc. — same as above
- **A full path**: `<<VAULT_PATH>>/projects/foo.md` or any absolute path
- **A bare filename or partial title**: search the vault with `find <<VAULT_PATH>> -iname "*<query>*.md"` and confirm the match if more than one

Optional flags (parse from the user's message):

| Flag | Effect |
|------|--------|
| `-n N`, `N copies` | print N copies |
| `--duplex`, `double-sided`, `two-sided` | double-sided (long-edge) |
| `--preview`, `preview first` | open the PDF in Preview before printing; confirm with user |
| `--paper letter\|a4` | paper size (default: Letter) |
| `--printer <queue>` | override default printer |

## Step 1 — Resolve the file

```bash
case "$input" in
  today|"today's daily"*) file="<<VAULT_PATH>>/daily/$(date +%F).md" ;;
  yesterday|"yesterday's daily"*) file="<<VAULT_PATH>>/daily/$(date -v-1d +%F).md" ;;
  /*|~*) file="$input" ;;
  *) file=$(find <<VAULT_PATH>> -iname "*${input}*.md" | head -1) ;;
esac
[ -f "$file" ] || { echo "Not found: $file"; exit 1; }
```

If the search finds multiple matches, list them and ask the user which one.

## Step 2 — Render to styled HTML

Pandoc consumes YAML frontmatter as metadata (won't print in body — good). Wikilinks `[[Name]]` and Obsidian callout markers `> [!note]-` print as literal text; that's acceptable for a printout. If you want cleaner output, strip the `[!note]-` marker with `sed -E 's/> \[![a-z]+\]-? ?/> /'` before pandoc.

**Critical**: use a temp DIRECTORY with named files inside, not `mktemp -t prefix.html`. On macOS, `mktemp -t` appends random chars AFTER your template, so the file ends up without the expected extension — Chrome then treats it as `text/plain` and prints the raw HTML source instead of rendering it.

```bash
TITLE=$(basename "$file" .md)
TMP=$(mktemp -d -t print-md)
CSS="$TMP/style.css"
HTML="$TMP/doc.html"
PDF="$TMP/doc.pdf"

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

## Step 3 — Convert HTML → PDF via Chrome headless

```bash
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
  --headless --disable-gpu --no-pdf-header-footer \
  --print-to-pdf="$PDF" "file://$HTML" 2>/dev/null
```

Sanity-check the PDF was actually rendered: `file "$PDF"` should say `PDF document`. If you're paranoid, `open -a Preview "$PDF"` before printing. If the PDF contains raw HTML tags as text, the file extension on `$HTML` was wrong — re-check Step 2.

If you don't have Chrome, swap the binary:

| Browser | Path |
|---------|------|
| Chromium | `/Applications/Chromium.app/Contents/MacOS/Chromium` |
| Brave | `/Applications/Brave Browser.app/Contents/MacOS/Brave Browser` |
| Edge | `/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge` |

## Step 4 — Preview (if requested)

```bash
if [ "$preview" = true ]; then
  open -a Preview "$PDF"
fi
```

Then ask the user to confirm before continuing.

## Step 5 — Print

Build options:

```bash
opts=()
[ -n "$copies" ] && opts+=(-n "$copies")
[ "$duplex" = true ] && opts+=(-o sides=two-sided-long-edge)
[ "$paper" = "a4" ] && opts+=(-o media=A4) || opts+=(-o media=Letter)
[ -n "$printer" ] && opts+=(-d "$printer")

lp "${opts[@]}" "$PDF"
```

Report the job ID back to the user (e.g., `request id is <queue>-NN`). They can cancel with `cancel <job-id>` or check status with `lpstat -W not-completed`.

## Notes

- **Frontmatter** is treated as metadata by pandoc — it won't appear in the printed body. That's the desired default for vault notes.
- **Wikilinks** `[[Name]]` print verbatim. A printed page can't follow links anyway; this is fine.
- **Embeds** `![[file.png]]` won't resolve. Rare in prose; warn the user if the file uses them heavily.
- **Daily-note dictation callouts** (`> [!note]- Raw dictation`) print as quoted blocks — readable, retains source intent.
- **Long notes**: for very long project docs, default to `--preview` first to gut-check page count before printing.
- **Job tracking**: `lpstat -W not-completed` lists active jobs. To clear a stuck queue: `cancel -a <queue>`.
