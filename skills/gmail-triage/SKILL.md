---
name: gmail-triage
description: Triage Gmail inbox — surface Google Doc mentions, calendar invites, and important emails while filtering noise
tags: [gmail, triage, productivity]
user_invocable: true
---

# Gmail Triage

Scan unread Gmail, classify messages, and present what matters — Google Doc activity, calendar invites, direct emails — while filtering Jira, sales, newsletters, and other noise.

## Execution Steps

### Step 1: Fetch Unread Inbox (parallel)

Run these two `gws` commands in parallel:

**Query A — Main inbox scan:**
```bash
gws gmail +triage --query 'is:unread -from:<<JIRA_BOT_EMAIL>> -label:CATEGORY_PROMOTIONS -label:CATEGORY_SOCIAL' --max 50 --format json --labels
```

**Query B — Google Docs notifications (catch miscategorized):**
```bash
gws gmail +triage --query 'is:unread from:(*@google.com) subject:(commented OR shared OR mentioned OR assigned)' --max 20 --format json
```

Merge results and deduplicate by message `id`.

### Step 2: Classify Each Message

Use **sender + subject + labels only** (no body fetch). Apply rules from `docs/classification-rules.md` in order — first match wins:

| Category | Description |
|----------|-------------|
| `GOOGLE_DOCS` | Doc/Sheet/Slide mentions, comments, shares |
| `CALENDAR` | Event invitations, updates, RSVPs |
| `INTERNAL` | From `@<<ORG_DOMAIN>>`, not docs/cal/jira |
| `EXTERNAL_IMPORTANT` | External sender, appears directed at <<USER_NAME>> |
| `SKIP` | Jira, sales, restaurant, newsletter, automated noise |

### Step 3: Full-Body Fetch for Ambiguous Externals

Only for `EXTERNAL_IMPORTANT` messages where sender+subject aren't conclusive:

```bash
gws gmail users messages get --params '{"userId": "me", "id": "<message_id>"}' --format json
```

Check for: unsubscribe links, marketing boilerplate, sales pitch language (`demo`, `free trial`, `pricing`, `quick question`). Reclassify to `SKIP` if detected. **Max 10 fetches.**

### Step 4: Present Grouped Results

Output in this order:

**Summary line:**
> Inbox triage (YYYY-MM-DD): X scanned, Y surfaced, Z filtered

**Google Docs Activity** (if any):
| Document | Action | From | Time |
|----------|--------|------|------|

**Calendar Invites** (if any):
| Event | From | When | Status |
|-------|------|------|--------|

**Direct Emails — Internal** (if any):
| From | Subject | Time |
|------|---------|------|

**Direct Emails — External** (if any):
| From | Subject | Time |
|------|---------|------|

**Filtered:** N messages filtered (Jira, promotions, automated). Say "show filtered" to see them.

### Step 5: Offer Next Actions

After presenting results, offer:
- **Read** — "read #N" to fetch full message body
- **Reply** — "draft reply to #N" to compose a response
- **Search** — "search older from [sender]" to find related messages
- **Show filtered** — display the filtered-out messages

## Constants

- **GWS triage subcommand**: `gws gmail +triage` returns id, threadId, snippet, from, to, subject, date, labels
- **GWS read subcommand**: `gws gmail users messages get --params '{"userId": "me", "id": "..."}' --format json` returns full message
- **Max main query**: 50 messages
- **Max docs query**: 20 messages
- **Max body fetches**: 10 (ambiguous externals only)
- **<<USER_NAME>>'s domain**: `<<ORG_DOMAIN>>`
- **<<USER_NAME>>'s email**: `<<USER_EMAIL>>`
