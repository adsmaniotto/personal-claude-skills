---
name: slack-catchup
description: >
  Check Slack DMs (1-on-1 and group), and public/private channel mentions for
  conversations still waiting on <<USER_NAME>>'s reply. Surfaces "on read" messages where
  someone messaged or @-mentioned <<USER_NAME>> but he never responded. Use this skill
  whenever the user says "catch up on Slack", "check my Slack", "am I on read",
  "did I miss anything", "unanswered messages", "dangling threads", "Slack backlog",
  "who's waiting on me", or any variation of checking for unread/unreplied Slack messages.
  Also use when the user asks about DMs, group DMs, or mentions from a specific time range.
tags: ['slack', 'catchup', 'mentions', 'dangling', 'dms']
user_invocable: true
---

# Slack Catch-Up

Find Slack conversations (DMs, group DMs, channel mentions) where <<USER_NAME>> hasn't replied.

## Constants

- **<<USER_NAME>>'s Slack user ID**: `<<SLACK_USER_ID>>`
- **Today's date**: Use `currentDate` from context
- **Default lookback**: yesterday (expand to last weekday if yesterday was a weekend)
- **Bot DMs to ignore**: Google Drive, HeyTaco, Slackbot, and any message with `[BOT]` tag
- **Timezone**: US Central (CST/CDT)

## Execution

### Step 1: Determine date range

Default is yesterday. If the user says "this week", "past few days", "since Monday", etc., adjust the `after:` date accordingly. Tell the user the range being searched.

For weekends: if yesterday was Saturday/Sunday, search back to Friday.

**Critical**: Slack's `after:` filter is **exclusive** — `after:2026-03-23` returns messages from Mar 24 onward, NOT from Mar 23. To capture messages from yesterday, use the day **before** yesterday as the `after:` date. For example, if today is Mar 24 and you want messages from Mar 23+, use `after:2026-03-22`.

### Step 2: Run 4 parallel Slack searches

Use `mcp__claude_ai_Slack__slack_search_public_and_private` for all four simultaneously:

**Search A — 1-on-1 DMs (inbound):**
```
query: "to:me after:{DATE_MINUS_1}"
channel_types: "im"
sort: "timestamp"
sort_dir: "desc"
limit: 20
include_context: true
max_context_length: 200
```

**Search B — 1-on-1 DMs (outbound — <<USER_NAME>>'s replies):**
```
query: "from:<@<<SLACK_USER_ID>>> after:{DATE_MINUS_1}"
channel_types: "im"
sort: "timestamp"
sort_dir: "desc"
limit: 20
include_context: true
max_context_length: 200
```

**Why this is needed**: Search A's `to:me` only returns messages *sent to* <<USER_NAME>>. If <<USER_NAME>> replied but nobody responded after, his reply won't appear in Search A's context window. Search B catches <<USER_NAME>>'s outbound DMs so we can cross-reference: if <<USER_NAME>> sent a message in a DM channel that also appears in Search A, that conversation is resolved even if the context didn't show his reply.

**Search C — Group DMs:**
```
query: "after:{DATE_MINUS_1}"
channel_types: "mpim"
sort: "timestamp"
sort_dir: "desc"
limit: 20
include_context: true
max_context_length: 300
```

Where `{DATE_MINUS_1}` is the day before the target start date (see Step 1 note on `after:` being exclusive).

**Search D — Channel mentions:**
```
query: "<@<<SLACK_USER_ID>>> after:{DATE_MINUS_1}"
channel_types: "public_channel,private_channel"
sort: "timestamp"
sort_dir: "desc"
limit: 20
include_context: true
max_context_length: 200
```

**Search E — <<USER_NAME>>'s channel messages (to catch thread replies):**
```
query: "from:<@<<SLACK_USER_ID>>> after:{DATE_MINUS_1}"
channel_types: "public_channel,private_channel"
sort: "timestamp"
sort_dir: "desc"
limit: 20
include_context: true
max_context_length: 300
```

**Why this is needed**: Search D only catches messages where someone literally typed `@<<USER_NAME>>`. But when <<USER_NAME>> posts a message or starts a thread in a channel, people often reply *without* @mentioning him — they're clearly responding to him but the reply won't show up in Search D. Search E finds <<USER_NAME>>'s own channel messages, then uses the `Context after` and `Reply count` fields to identify threads where someone replied but <<USER_NAME>> hasn't responded back. This catches the "thread reply to <<USER_NAME>>'s post" pattern that @mentions miss.

**How to classify Search E results**:
- If <<USER_NAME>>'s message has `Reply count > 0` and `Context after` shows replies from others but no follow-up from <<USER_NAME>> → **dangling** (someone answered <<USER_NAME>>'s question or responded to his post and he hasn't acknowledged)
- If <<USER_NAME>>'s message has replies and <<USER_NAME>> also replied after them → **resolved**
- If <<USER_NAME>>'s message has no replies → **ignore** (nobody responded, nothing to catch up on)
- If the thread is purely informational (<<USER_NAME>> shared a link, announcement, or FYI with no question) and replies are just emoji reactions or "thanks" → **likely resolved**, not dangling

Paginate if needed (check `pagination_info` for cursor).

### Step 2b: Targeted person lookups

When the user asks about a specific person (e.g., "how about Mimi"), search for their messages in both DMs and group DMs:

1. **Find their user ID** — use `slack_search_users` with their name
2. **Search DMs**: `from:<@THEIR_ID> after:{DATE_MINUS_1}` with `channel_types: "im"`
3. **Search group DMs**: `from:<@THEIR_ID> after:{DATE_MINUS_1}` with `channel_types: "mpim"`

**Do NOT use `to:me` or `in:<@<<SLACK_USER_ID>>>` for group DM searches** — these filters don't match mpim channels. The `to:me` modifier only works for 1-on-1 DMs, and `in:<@user>` targets a specific DM channel, not group DMs that include that user. For group DMs, search by `from:` only and let the `channel_types: "mpim"` filter do the work.

### Step 3: Classify from search context (no thread reads needed)

The search results include `Context before` and `Context after` which show surrounding messages. This is usually enough to determine reply status without reading full threads.

For each result from a real person (not a bot):

1. **Check context for <<USER_NAME>>'s reply** — if `Context after` shows a message from <<USER_NAME>> (`<<SLACK_USER_ID>>`), he replied. Mark as resolved.
2. **Cross-reference with Search B (outbound DMs)** — if <<USER_NAME>> sent a message in the same DM channel (matching channel ID) during the search window, he replied even if it didn't appear in Search A's context. Mark as resolved.
3. **Check if <<USER_NAME>> sent the last message** — if <<USER_NAME>>'s message is the most recent in the context window, it's not dangling.
4. **Check for closing signals** — if the last message from the other person contains a closing phrase (thanks, sounds good, got it, etc.), mark as likely resolved.
5. **Otherwise** — it's dangling (on read).

See `docs/dangling-logic.md` for the full decision tree and closing phrase list.

#### Bot filtering

Skip these entirely — don't even mention them:
- Google Drive notifications
- HeyTaco messages
- Slackbot
- Any message tagged `[BOT]` in the search results

#### Group DM handling

Group DMs need more careful reading because <<USER_NAME>> may be a passive participant in a multi-person conversation. A group DM is "on read" only if:
- Someone addressed <<USER_NAME>> specifically (`@<<USER_NAME>>` or a direct question/request to him), OR
- <<USER_NAME>> was the last person asked something and hasn't responded, OR
- The conversation clearly expects <<USER_NAME>>'s input (e.g., action items assigned to him)

Don't flag group DMs where <<USER_NAME>> is just CC'd on an ongoing discussion between others.

### Step 4: Present results

#### On Read (Needs Reply)

For each dangling conversation, show:

```
**{Person/Group Name}** ({relative time})
> {Quote of the message waiting on <<USER_NAME>>, ~1-2 lines}
```

Order by priority:
1. 1-on-1 DMs (highest — someone wrote directly to <<USER_NAME>>)
2. Group DMs where <<USER_NAME>> was specifically addressed
3. Channel mentions (@<<USER_NAME>>)
4. Channel thread replies to <<USER_NAME>>'s posts (no @mention but clearly responding to him)

#### All Clear

For conversations where <<USER_NAME>> replied, show a brief summary:
```
**You're good on:** {Name1} (replied), {Name2} (replied), ...
```

#### Likely Resolved

Bullet list of threads where the last message was a closing phrase — mention but don't flag as needing action.

### Step 5: Offer follow-ups

- "Want me to draft a reply for any of these?"
- "Should I search a broader date range?"
- "Want more context on any thread?"

## Edge Cases

- **Weekend**: Search back to Friday if yesterday was Sat/Sun
- **No results**: "All clear — nothing waiting on you"
- **Pagination**: If any search returns 20 results, paginate to get the full picture
- **Ambiguous group DMs**: When unsure if <<USER_NAME>> needs to reply, include it with a note like "you may want to weigh in"
- **Long lookback (>3 days)**: Warn that older threads may have been resolved via other channels (in-person, meetings, etc.)
