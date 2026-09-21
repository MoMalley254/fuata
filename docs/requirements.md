# Requirements: Pocket (working title)

**Version:** 0.1 · **Status:** Draft · **Author:** _your name_ · **Target release:** v0.1.0 (Thursday)

## 1. Purpose

A local-first Android app that lets a person see, at a glance, how much money they have across cash, mobile money, banks and cards, how much they have spent today, to whom, and where money came from. It exists because spending is scattered across payment types and hard to reconcile by hand.

## 2. Users

**Primary persona: "Amina".** Earns modest income, pays in cash, mobile money and bank/card, tends to overspend when out, and wants a quick answer to "am I okay today?" without doing bookkeeping. Not a finance expert. Cares about privacy and does not want to hand over bank credentials.

## 3. Scope

**In scope (v0.1):** units, transactions (spent / got / moved), computed balances, limits and status, notification banner, message parsing (paste/share and notification listener) with user-defined templates, review inbox, summaries, JSON export/import.

**Out of scope (v0.1) / non-goals:**
- Any server, account, sync or analytics. No network calls.
- Collecting card numbers, account numbers, PINs or credentials.
- iOS, home widget, outing mode, recipient-category rules, recurring bills, template packs, database encryption and app lock (see backlog).
- Being a bank statement. Balances are the user's own estimate with a verification trail.

## 4. User stories and acceptance criteria

| ID | As a user I want to... | Acceptance criteria |
|---|---|---|
| US-01 | create money units with my own name, icon/emoji and colour | Can add, edit, archive a unit; opening balance is optional; currency per unit; no account/card number field exists |
| US-02 | record what I spent, got or moved | Amount entry takes ≤ 3 taps after opening; Moved creates a linked pair and is **not** counted as spending or income |
| US-03 | see each unit's current amount | Balance = opening + signed transactions; never stored separately; all amounts stored as integer minor units |
| US-04 | set a daily and monthly limit | Overall and optional per-unit; status is Safe / Warning / Danger / Overdraft with documented thresholds (70% / 90% / 100%) |
| US-05 | see my status in the notification curtain | Ongoing banner shows status emoji, amount left and progress; updates within 2 s of any change; selectable units; can be disabled |
| US-06 | be alerted when I approach or pass a limit | Separate alert channel; fires once per threshold per period |
| US-07 | quickly add a transaction from the banner | Banner action opens a fast-add entry without navigating menus |
| US-08 | teach the app to read a bank/mobile-money message | Paste a sample, label words (amount, code, date, person, balance, fee), see a live preview, save as a template; can test against extra samples |
| US-09 | share or paste a message and get a transaction | Works with no permissions; result goes to the review inbox |
| US-10 | let the app catch notifications from apps I choose | User grants notification access and picks allowed apps; non-allowed notifications are discarded immediately and never stored |
| US-11 | review what was captured | Inbox with Looks right / Fix / Not mine; unparsed messages listed with a "Teach me" action; duplicates (same code) are not created twice |
| US-12 | see summaries for today, week and month | Spent vs got, top recipients, per-unit split; simple by default with a "more" expander |
| US-13 | control how much detail I see | Detail level Simple / Balanced / Detailed applied to Activity and transaction detail |
| US-14 | personalise the app | Name, accent colour, Home headline, sections, theme |
| US-15 | back up and move my data myself | Export/import a JSON file to any location the user chooses; import is validated and never overwrites silently |
| US-16 | trust that my data stays on my phone | Release build has no `INTERNET` permission; Android auto-backup disabled; a Privacy screen states this |

## 5. Functional rules

- **Money:** integer minor units; currency stored per unit; no floating point.
- **Types:** `spent`, `got`, `moved`. Moved = two linked entries, excluded from spending and income totals.
- **Status:** `ratio = spent / limit` → `<0.7` Safe, `0.7-<0.9` Warning, `0.9-<1.0` Danger, `>=1.0` or any unit below zero → Overdraft. Thresholds configurable.
- **Sources:** each transaction records `manual`, `shared`, or `notification`, plus status `confirmed` or `pending`.
- **Dedup:** by transaction code when present; otherwise unit + amount + 2-minute window.
- **Reconcile:** if a parsed message includes "balance after" and it disagrees with the computed balance, flag the unit and offer an adjustment entry.
- **Fees:** stored on the transaction; counted in spending.

## 6. Non-functional requirements

| Area | Requirement |
|---|---|
| Privacy | No network access or telemetry; release manifest excludes `INTERNET`; only allow-listed notification content is read and only parsed fields are kept (raw message text is optional and off by default) |
| Security | Auto-backup disabled; amounts can be hidden in recents; SQLCipher and app lock deferred to v1.1 |
| Performance | App cold start < 2 s on a mid-range device; banner update < 2 s after an event; smooth scrolling with 5,000 transactions |
| Reliability | Ledger, limit engine and parser have unit tests; listener survives app close and reboot (manual test) |
| Usability | Core actions reachable in ≤ 2 taps from Home; accessible contrast; status never shown by colour alone |
| Compatibility | Android 8.0+ (API 26) minimum, targeting the current Android release |
| Maintainability | Layered structure (UI / domain / data); repository interfaces; Conventional Commits; docs in `/docs` |

## 7. Constraints and assumptions

- Solo developer, roughly 4 days, Flutter, local database (drift/SQLite), no backend.
- The notification listener depends on the user granting special access; behaviour varies by manufacturer.
- Message formats vary and change, so parsing is template-based and user-editable.
- Assumption: users have the same SMS/notification app content visible (not hidden by privacy settings).

## 8. Risks

| Risk | Impact | Mitigation |
|---|---|---|
| Listener with app closed (background isolate + DB access) | Core feature fails | Early time-boxed spike; fall back to share/paste capture |
| Template builder scope creep | Schedule slip | v1 = paste, tap-to-label, preview, save |
| Manufacturer battery killers | Missed captures | In-app "keep me alive" guide; "listener inactive" warning |
| Play Store policy on notification access | Distribution limits | Prominent in-app disclosure; GitHub APK release path |
| Banner colour limits on Android | Weaker "at a glance" signal | Emoji + progress bar + coloured icon |

## 9. Definition of done (v0.1.0)

- All US-01 to US-16 acceptance criteria met, or explicitly moved to backlog with an issue.
- Unit tests pass for ledger, limits, parser; manual test checklist completed on a real device.
- Release APK built and attached to a GitHub Release with a CHANGELOG entry.
- `README`, `docs/requirements.md`, `docs/design.md`, `docs/testing.md` and `docs/devlog.md` up to date.
