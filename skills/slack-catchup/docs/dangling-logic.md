# Dangling Thread Classification Logic

## Decision Tree

For each conversation unit (thread or flat channel segment):

```
1. Are ALL messages from bots/apps?
   └─ YES → SKIP (bot-only, no action needed)
   └─ NO  → continue

2. Did <<USER_NAME>> START this thread and no one replied?
   └─ YES → SKIP (outbound message, not inbound backlog)
   └─ NO  → continue

3. Is <<USER_NAME>>'s message the chronologically last one?
   └─ YES → NOT DANGLING (<<USER_NAME>> already replied)
   └─ NO  → continue

4. Does the last message contain a closing phrase?
   └─ YES → LIKELY RESOLVED
   └─ NO  → continue

5. Did <<USER_NAME>> ever reply in this conversation?
   └─ NO  → DANGLING (no reply) — <<USER_NAME>> was mentioned/messaged but never responded
   └─ YES → DANGLING (new messages) — Others posted after <<USER_NAME>>'s last message
```

## Closing Phrases

A message is considered a "closing signal" if it contains any of these patterns (case-insensitive):

### Gratitude / acknowledgment
- thanks
- thank you
- ty
- thx
- appreciated
- appreciate it

### Agreement / confirmation
- sounds good
- sounds great
- perfect
- got it
- will do
- on it
- noted
- makes sense
- fair enough
- works for me
- all good
- no worries

### Approval
- lgtm
- approved
- ship it
- go for it
- looks good
- good to go

### Emoji signals
- :thumbsup:
- :+1:
- :white_check_mark:
- :heavy_check_mark:
- :pray:
- :raised_hands:
- :ok_hand:

## Classification Labels

| Label | Meaning | Action |
|-------|---------|--------|
| `SKIP` | Bot-only or outbound thread with no replies | Omit from results |
| `NOT_DANGLING` | <<USER_NAME>> already replied last | Omit from results |
| `DANGLING_NO_REPLY` | <<USER_NAME>> was mentioned/messaged, never replied | Show in "Needs Your Reply" |
| `DANGLING_NEW_MSGS` | Others posted after <<USER_NAME>>'s last message | Show in "Needs Your Reply" |
| `LIKELY_RESOLVED` | Last message is a closing phrase | Show in "Likely Resolved" |

## Notes

- Bot detection: Check if the message `username` ends in `bot` or `app`, or if the message has `subtype: "bot_message"`
- <<USER_NAME>>'s user ID: `<<SLACK_USER_ID>>` — match against message `user` field
- Thread vs flat: If `thread_ts` is present and differs from `ts`, the message is in a thread
- For DMs, treat the entire recent conversation window as one unit rather than splitting by thread
