# Email Classification Rules

Ordered decision tree — **first match wins**. Apply using sender, subject, and labels only (no body needed for most).

## Rule 1: Jira → SKIP

Match ANY:
- From contains `@atlassian.net`
- Subject contains `[JIRA]`
- Subject matches ticket pattern: `[A-Z]+-\d+` (e.g., LABS-181)
- From contains `jira@`, `confluence@`, `bitbucket@`

## Rule 2: Google Docs → GOOGLE_DOCS

From matches `*@google.com` AND subject contains any of:
- `commented`, `comment on`, `replied`
- `shared`, `shared a document`, `shared a spreadsheet`, `shared a presentation`
- `mentioned you`, `assigned you`, `assigned to you`
- `suggested edits`, `editing suggestion`
- `Document:`, `Spreadsheet:`, `Presentation:`

Also match: From is `drive-shares-dm-noreply@google.com` or `comments-noreply@docs.google.com`

## Rule 3: Calendar → CALENDAR

Match ANY:
- From is `calendar-notification@google.com`
- Subject starts with `Invitation:`, `Updated invitation:`, `Canceled:`, `Cancelled:`
- Subject contains `accepted your invitation`, `declined your invitation`, `tentatively accepted`
- From contains `calendar-server@google.com`

## Rule 4: Promotions Label → SKIP

Message has label `CATEGORY_PROMOTIONS`.

## Rule 5: Restaurant / Food → SKIP

From domain matches any of:
- `doordash.com`, `uber.com`, `ubereats.com`, `grubhub.com`
- `toasttab.com`, `toast.com`, `square.com`
- `yelp.com`, `opentable.com`, `resy.com`
- `seamless.com`, `postmates.com`, `caviar.com`
- `chipotle.com`, `starbucks.com`, `chick-fil-a.com`, `dominos.com`

## Rule 6: Sales Pitch → SKIP

From domain is NOT `<<ORG_DOMAIN>>` AND subject contains any of:
- `demo`, `free trial`, `pricing`, `quick question`
- `schedule a call`, `15 minutes`, `touch base`
- `transform your`, `boost your`, `grow your`
- `limited time`, `exclusive offer`, `special offer`
- `unsubscribe` (in subject — rare but definitive)

## Rule 7: Internal → INTERNAL

From domain is `<<ORG_DOMAIN>>` (and not already matched by Rules 1-3).

## Rule 8: Automated Noreply → SKIP

From address contains any of:
- `noreply@`, `no-reply@`, `donotreply@`, `do-not-reply@`
- `notifications@`, `notification@`
- `mailer-daemon@`, `postmaster@`
- `updates@`, `info@`, `support@` (generic automated senders)

Exception: Google Docs and Calendar senders already caught in Rules 2-3.

## Rule 9: Known Noise Domains → SKIP

From domain matches any of:
- `linkedin.com`, `linkedinmail.com`
- `facebookmail.com`, `twitter.com`, `x.com`
- `meetup.com`, `eventbrite.com`
- `canva.com`, `figma.com`
- `notion.so`, `notebooklm.google.com`
- `coderpad.io`, `hackerrank.com`, `leetcode.com`
- `grouptogether.com`, `gofundme.com`
- `medium.com`, `substack.com`
- `mailchimp.com`, `sendinblue.com`, `constantcontact.com`

## Rule 10: Default → EXTERNAL_IMPORTANT

Everything else. These get a body fetch in Step 3 if the subject is ambiguous.

### Ambiguous Subject Indicators (trigger body fetch)

Subject is considered ambiguous if it does NOT contain:
- A direct question
- <<USER_NAME>>'s name or a personal reference
- A reply prefix (`Re:`, `Fwd:`)

For ambiguous externals, fetch the body and reclassify to SKIP if:
- Body contains an unsubscribe link (`unsubscribe`, `opt out`, `email preferences`)
- Body contains marketing boilerplate (`view in browser`, `view as web page`)
- Body has more than 3 tracking pixel images
- Body matches sales pitch patterns from Rule 6
