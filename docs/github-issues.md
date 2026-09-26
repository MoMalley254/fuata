# GitHub Setup: Labels, Milestones, Issues

## Labels

`type: feature` · `type: bug` · `type: docs` · `type: test` · `type: chore` · `area: ui` · `area: ledger` · `area: limits` · `area: banner` · `area: capture` · `area: data` · `risk` · `v1.1` · `good first issue`

## Milestones

- **v0.1 MVP** (due Thursday)
- **v1.1 Backlog** (no date)

## Branch and PR convention

One branch per issue: `feat/<short-name>`, `fix/<short-name>`, `docs/<short-name>`. Open a PR that says `Closes #N`, merge to `main`. Commits follow Conventional Commits (`feat(ledger): ...`).

---

## Milestone: v0.1 MVP

### Setup and docs
1. **chore: initialise repo and Flutter project** `type: chore`
   README skeleton, `.gitignore`, licence, issue and PR templates, folder structure (`ui/`, `domain/`, `data/`), lint rules.
2. **docs: requirements document** `type: docs`
   Add `docs/requirements.md`. Done when merged and linked from the README.
3. **docs: UI design brief and design tokens** `type: docs` `area: ui`
   Add `docs/ui-design-brief.md`, then record the chosen visual direction and tokens in `docs/design.md`.
4. **docs: design doc (data model, architecture, decision records)** `type: docs`
   ER diagram, layer diagram, and short records for: drift, Riverpod, notification listener over SMS permission, no encryption in v0.1, integer minor units.
5. **docs: devlog and testing checklist** `type: docs`
   Create `docs/devlog.md` and `docs/testing.md` (manual checklist).

### UI (built first, against mock data)
6. **feat(ui): app theme, tokens and personalisation shell** `type: feature` `area: ui`
   Light/dark themes, accent colour, typography, status colours, reusable components (status ring card, unit card, transaction row, chips).
7. **feat(ui): onboarding flow** `type: feature` `area: ui`
   Name, accent, add first units, optional daily limit, optional banner and auto-catch explainers. All skippable.
8. **feat(ui): Home (Today) screen** `type: feature` `area: ui`
   Hero status card in four states, unit cards, "Lately", empty state, bottom nav.
9. **feat(ui): add-transaction sheet** `type: feature` `area: ui`
   Spent/Got/Moved, keypad-first amount, unit chips, collapsed "More".
10. **feat(ui): Activity screen and transaction detail** `type: feature` `area: ui`
    Day groups, filter chips, detail sheet, Simple/Balanced/Detailed levels.
11. **feat(ui): My money and unit pages** `type: feature` `area: ui`
    Unit cards, update balance, edit name/icon/colour.
12. **feat(ui): Me and personalisation settings** `type: feature` `area: ui`
    Home options, detail level, appearance, privacy panel.

### Engine (wired in after the UI)
13. **feat(data): local database and repositories** `type: feature` `area: data`
    drift schema for Unit, Transaction, Limit, Template; repository interfaces already used by the UI; migrations.
14. **feat(ledger): computed balances, transfers, fees** `type: feature` `area: ledger`
    Balance = opening + signed transactions; Moved excluded from spending; unit tests for money math and transfers.
15. **feat(limits): limit engine and status** `type: feature` `area: limits`
    Daily/weekly/monthly, overall and per-unit; Safe/Warning/Danger/Overdraft; threshold unit tests.
16. **feat(banner): ongoing notification banner** `type: feature` `area: banner`
    Status emoji, progress bar, selected units, quick-add action, re-post if dismissed, separate alert channel.
17. **feat(banner): banner setup screen with live preview** `type: feature` `area: banner` `area: ui`
18. **spike: notification listener with app closed** `type: chore` `risk` `area: capture`
    Time-boxed to 2 hours. Throwaway listener logs one notification and writes one DB row via a background isolate. Record findings in the design doc.
19. **feat(capture): template model and parser** `type: feature` `area: capture`
    Labeled spans → regex with typed groups; multiple templates per unit; tests with several fake samples.
20. **feat(capture): rule builder UI** `type: feature` `area: capture` `area: ui`
    Paste sample, tap-to-label chips, live preview, test against more samples, save.
21. **feat(capture): share/paste to review inbox** `type: feature` `area: capture`
22. **feat(capture): notification listener with app allow-list and dedupe** `type: feature` `area: capture`
    Discard non-allowed notifications immediately; dedupe by code.
23. **feat(insight): Today/Week/Month summaries** `type: feature` `area: ui`
24. **feat(data): JSON export/import** `type: feature` `area: data`
    Validation on import; never overwrites silently.
25. **chore(privacy): remove INTERNET permission and disable backup** `type: chore`
    Verify in the built APK's manifest.
26. **test: manual device test pass** `type: test`
    App closed, rebooted, battery-optimised, notification access revoked and re-granted.
27. **chore(release): v0.1.0** `type: chore`
    CHANGELOG, signed APK, GitHub Release, README screenshots.

## Milestone: v1.1 Backlog (create now, do later)

- SQLCipher encryption with Android Keystore, and app lock `v1.1`
- Home screen widget `v1.1`
- Outing mode (temporary budget with its own banner) `v1.1`
- Scheduled daily/weekly/monthly summary notifications `v1.1`
- Recipient → category rules `v1.1`
- Recurring bills and expected income `v1.1`
- Template packs: export/import/share by file or QR, bundled presets `v1.1`
- Scheduled encrypted export to a user-chosen folder `v1.1`
- "Listener seems inactive" detection and manufacturer-specific keep-alive guides `v1.1`
- Opt-in redacted diagnostics copy button `v1.1`
- iOS manual/share-sheet edition `v1.1`
- Open-source licence review and contribution guide `v1.1`
- Rule builder: "This part changes" wildcard `area: capture` `area: ui` `v1.1`
- Rule builder: user-defined custom fields `area: capture` `area: ui` `v1.1`

## Post-#20 follow-ups

Two enhancements from ui-design-brief.md 7.7's palette that #20 deliberately
did not build (both need a domain-model addition, so are out of scope for #20):

55. **feat(capture): "This part changes" wildcard** `type: feature` `area: capture` `area: ui` `v1.1`
    A span labeled as a wildcard compiles to a non-capturing `[\s\S]+?` —
    "this word varies between messages". Today any unlabeled word becomes
    fixed literal text and breaks the rule on the next differently-worded
    message.

56. **feat(capture): user-defined custom fields** `type: feature` `area: capture` `area: ui` `v1.1`
    7.7's palette has "Add my own field". Today only the six built-in
    `TemplateFieldType` values are labelable. Needs a template-owned
    custom field type, `ParsedFields.custom` (a `Map<String, String>`),
    and UI in `FieldPalette` to name one.
