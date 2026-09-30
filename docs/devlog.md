# Devlog

A running, honest record of the build: goals, what got done, what broke, and why decisions were made. Newest day first. Keep entries short; this is raw material for the README, the changelog and interviews.

*What broke / learned* and *Decisions*.

---

## Day 10: Wed 30 Sep 2026 — Finishing limits and alerts (#63)

**Goals**
- [x] Per-unit limits, under "More" and on the unit page
- [x] Alert-level sliders, quiet hours, live banner preview (ui-design-brief.md 7.8)
- [x] Alerts that actually fire: once per threshold per period, separate channel (US-06)
- [ ] Verify on a real device (moves to #26)

**Done**
- `AlertEngine` (`lib/domain/logic/alert_engine.dart`): pure "what is due" over limits + transactions + what already fired. One alert per limit per evaluation, for the highest level crossed.
- AlertLogRepository and an alert_firings table, added to the v1 onCreate. No schemaVersion bump: nothing has shipped, so there is no install that needs the additive onUpgrade step. A commented-out if (from < 2) await m.createTable(alertFirings); in app_database.dart documents the migration to uncomment if this ever does ship behind a real release. `claimDueAlerts` claims before showing; `fireDueAlerts` (`platform/alerts.dart`) shows. Called from the UI isolate (`alertSyncProvider`) and from the listener's background isolate right after the banner re-post.
- Limits screen: Alerts card (toggle, range slider, "try it" scrubber driving the real `BannerPreview`), Quiet hours card, "More" list of per-unit limits. `EditUnitLimitsSheet` handles add/edit/remove in one place (blank field = no limit).

**What broke / learned**
- Nothing was run on a device or compiled in the session that wrote this. `flutter pub run build_runner build` is required (new table), then `flutter test`.

**Decisions**
- **Claim, don't check.** Both isolates can see the same crossing. "Already fired?" then "fire" would race; the table's primary key makes the claim atomic, and a failed claim means *do not show*.
- **Alert levels are stored on each `LimitRule`** (they already had `warnAt`/`dangerAt`), and one slider pair edits all of them; new limits inherit. No new settings for levels.
- **Quiet hours deliver silently rather than drop.** Android fixes a channel's sound at creation, so quiet alerts use their own low-importance channel (`fuata_alerts_quiet`).
- **Changing a limit's amount clears its announcements** (raise 1,000 to 5,000 and you should be nudged again); changing only levels or the switch does not, so dragging a slider never repeats an alert.
- The slider writes on release, not per tick, so the banner and alerts don't re-run mid-drag.
- The banner and Home ring still follow the overall daily limit only. Per-unit limits alert but do not change the banner emoji.

**Time spent:** _tbc_

---

## Day 9: Tue 29 Sep 2026 — Notification listener, allow-list and dedupe (#22)

**Goals**
- [x] Real listener replacing the #18 spike: discard non-allowed apps immediately
- [x] Allow-list stored in `capture_sources`, picked in the app (US-10)
- [x] Dedupe safe when notifications arrive together
- [x] Fix the spike's text-extraction gap (design.md 5.1)
- [ ] Verify on a real device (moves to #26)

**Done**
- `CaptureProcessor` (`lib/domain/logic/capture_pipeline.dart`): the #21 capture logic lifted out of `CaptureService` so the background isolate can run it with no Riverpod. `CaptureService` now wraps it; the outcome types are re-exported from `capture_providers.dart`, so no screen changed its imports.
- `CaptureSource` model, `CaptureSourceRepository` (drift + mock), `allowedPackagesProvider`, and an Auto-catch screen under Me: notification-access status, a searchable app list, one switch per app.
- Native: `NotificationListener.kt` gates on a `SharedPreferences` mirror of the allow-list before reading anything; `CaptureEngine.kt` keeps one headless engine alive across a burst; `NotificationText.kt` is the documented extras walk; `CaptureChannel.kt` replaces the spike channel.
- Tests written: `capture_pipeline_test.dart` (US-10, P-07, P-08, simultaneous arrival, unparsed dedupe), `serial_queue_test.dart`, `capture_source_repository_test.dart`.

**What broke / learned**
- Reading the spike again showed something the spike could never have caught: it wrote rows from a second drift connection, and drift only re-runs a stream for writes made through the *same* database instance. Rows would land in the file but an open Home or inbox would not refresh. Added a native ping plus `markTablesUpdated`, and the same call on app resume.
- Dedupe by code is check-then-insert. With one engine per notification (the spike's shape) an SMS and its push twin would race and both insert; that is why there is now one engine and a serial queue.
- Found while writing the tests: "Teach me" re-runs capture on text already in the unparsed list, so a still-unreadable message added a copy every time. Deduped on (package, text).
- The repo's own adb test tip posts as `com.android.shell`, which has no launcher icon and so can't appear in the picker; added a debug-only "add by package name" field.

**Decisions**
- Allow-list enforced natively *and* against the database, not one or the other (design.md 5.2).
- Turning an app off flips `enabled`; rows are never deleted (`templates.captureSourceId` references the table).
- `FLAG_GROUP_SUMMARY` notifications are skipped; revisit if a device posts only a summary.
- Templates are not yet tied to a source: a template with no `captureSourceId` matches any allowed app. Source-scoped matching is a later refinement, not needed for US-10.

**Time spent:** 4hours

---

## Day 6: Sat 26 Sep 2026 — Template model and parser (#19)

**Goals**
- [x] Capture template model: labeled spans -> generated regex (ADR-007)
- [x] Parser: match a message against a unit's templates, extract typed fields
- [x] Unit tests against fake messages (testing.md P-01 to P-12, minus the two that need a repository)

**Done**
- `lib/domain/models/template.dart`: `CaptureTemplate` plus `CaptureTemplate.fromLabeledSample()`, which is the actual ADR-007 mechanism — takes a pasted sample and a list of `LabeledSpan`s (start/end offsets + `TemplateFieldType`: amount, code, date, person, balance, fee) and walks the sample once, escaping literal text and swapping each labeled span for a named regex group (`(?<amount>...)`, `(?<amount2>...)` if a field type repeats). `fieldMap` (group name -> field type) is exactly `tables.dart`'s `fieldMapJson` column, just not JSON-encoded yet — `toJson`/`fromJson` do that encoding so a repository (#20) can store and reload a template unchanged.
- `lib/domain/logic/parser.dart`: `Parser.parse(message, templates, currencyCode: ...)` tries each enabled template in order and returns the first match, with amount/fee/balance run through `Money.parseMajor` (after stripping an optional currency-letter prefix like "Ksh") and the date field tried as ISO first, then a short list of `intl` patterns covering "21/9/26 at 1:12 PM"-style messages. A template with `direction: either` sniffs `received`/`credited`/`deposit` in the message to decide spent vs got when the template itself doesn't pin it down.
- `test/domain/parser_test.dart`: three fake M-Pesa-style templates (paid/received/withdraw) built the same way the rule builder will build them, covering P-01 (all fields, correct types), P-02 (amount formats, including a bare "350" with no currency prefix), P-03 (same template, different name/amount/code still matches), P-04 (literal `.`, `(`, `)` in the sample survive as literal — checked both that the exact sample still matches *and* that a message with different literal punctuation in the same spots does *not* match), P-05 (no template matches -> `ParseResult.noMatch()`), P-06 (three templates on one unit, each message picks the right one and the right direction), P-09 (both date styles), P-10 (balance field is extracted; noted that comparing it to the computed balance is ledger work, not the parser's), P-11 (JSON round-trip gives byte-identical parse behaviour), P-12 (empty message, a 5000-line message, and a real match buried in noise — none crash).

**What broke / learned**
- First pass at the amount pattern didn't allow a currency prefix with no digits between it and the decimal-less case ("350" alone) — realized while writing P-02's bare-amount test, not from a bug report, so added that case explicitly rather than assuming the happy-path samples covered it.
- Regex named-group syntax (`(?<name>...)`) meant field-type names had to double as valid Dart group names — fine since `TemplateFieldType.values` are already single words, but worth remembering if a field type with an underscore or a name starting with a digit is ever added later.
- No device or emulator needed for any of this — pure Dart, matches design.md's reason for keeping the domain layer Flutter-free. Couldn't actually run `flutter test` in this environment (no Dart SDK / network access to pub.dev here), so the regex-construction and template-matching logic was cross-checked against an equivalent Python `re` harness (named groups, escaping, multi-template selection) before writing the Dart. Still needs a real `flutter test` run before merging, per testing.md's priority rule.

**Decisions**
- Dedup (testing.md P-07/P-08) is explicitly **not** in the parser. It needs to compare a parse result against already-stored transactions, which means repository access — that lands with the review inbox (#21) and the listener (#22), where it actually has something to compare against. Left a comment in the test file pointing at this so it isn't mistaken for a gap.
- Reconciliation (P-10: quoted balance vs. computed balance) is the same story — the parser's job stops at handing back `balanceAfterMinor`; deciding it disagrees with the ledger and flagging the unit is design.md section 3's job, not the parser's.
- `direction: either`'s keyword sniff is a small, deliberately narrow heuristic (three words) rather than a general classifier — matches ADR-007's "deterministic, explainable" reasoning. Most real templates will pin `direction` directly since a given message shape is consistently one or the other; `either` is an escape hatch, not the default path.

**Time spent:** _~2 hours_

**Tomorrow:** rule builder UI (#20) — paste sample, tap-to-label chips feeding `LabeledSpan`s into `CaptureTemplate.fromLabeledSample`, live preview using `Parser.parse` against the sample itself, "test against another message" using a second pasted sample.

---

## Day 5: Fri 25 Sep 2026 — Spike #18 and MIUI rabbit hole

**Goals**
- [x] Run spike #18 end to end on a real device
- [x] Confirm drift's two-isolate write is safe (ADR-001's top risk)
- [x] Record the finding in `docs/design.md` §5.1

**Done**
- Wired a temporary "Notification access" button into Me → Limits, banner and messages, so the grant can be reached without `adb shell cmd notification allow_listener`. Added a new `ActionRow` widget next to the existing `ComingSoonRow` family — same visual language, primary-tinted border and chevron so it reads as live rather than placeholder.
- Ran the spike across four scenarios: foreground, backgrounded, rapid-fire (×10), post-reboot-without-launching-the-app. All four captured reliably. 23 rows written across the session with no `SQLITE_BUSY` and no engine-startup failures.
- Confirmed the two-isolate write path: the background isolate opens its own `AppDatabase` while the UI isolate has one open on the same `fuata.sqlite`, and both commit cleanly. `NativeDatabase.createInBackground` is safe. **ADR-001's top risk is closed.**

**What broke / learned**
- **MIUI does not bind the listener on a `cmd notification allow_listener` grant.** Symptoms: `enabled_notification_listeners` contains the component, `dumpsys package` reports the app enabled and unstopped, but Fuata is absent from `dumpsys notification`'s "Live notification listeners" section and `dumpsys activity services` shows no bound service. Notifications are silently dropped with no callback. The grant has to go through **Settings → Notification access** as an off→on toggle, which routes through `MiuiSecurityCenter` and forces a re-register; the adb path only edits `Settings.Secure`, which MIUI's own permission layer doesn't read.
- **`am kill <pkg>` is a no-op while notification access is granted** — the bound listener keeps the process alive by design. Worse, the kill request itself can make the notification manager unbind the listener without rebinding it, so subsequent notifications are dropped until the app is relaunched. Use `am force-stop` for the "stopped package" test instead, and accept that it too is expected to prevent capture until the user opens the app.
- **`run-as ... sqlite3` fails on release builds** (`Permission denied: exec failed for sqlite3`) even though `run-as cat` works — the app's SELinux context can't execute the system binary. Workaround: `adb exec-out run-as $PKG cat $DB > /tmp/…` plus the `-wal` and `-shm` sidecars, then query locally. Worth remembering for #22/#26 — the on-device query isn't reliable across OEMs.
- **Debug-build caveat noted.** `am kill` behaviour and background lifecycle differ meaningfully between debug and release (JIT, memory footprint, low-memory killer aggressiveness). The finding above is from a debug build; the release verification is deferred to #26's device test pass.

**Decisions**
- Recorded the MIUI prerequisite in `docs/design.md` §5.1 and cross-referenced it from ADR-006, so the next person to build a capture feature hits the working path directly rather than re-deriving it.
- Left the ~20 spike rows in `unparsed_captures` in place — useful evidence for #22 to compare extraction behaviour against. Not cleaning them out.

**Time spent:** _~3 hours_

**Tomorrow:** parser and template model (#19), pure Dart with unit tests against fake bank messages; no device required.

## Day 4: Thu 24 Sep 2026 (planned)

**Goals**
- [ ] Summaries: today, week, month (#23)
- [ ] JSON export/import (#24)
- [ ] Remove `INTERNET` from release manifest, disable backup (#25)
- [ ] Manual device test pass using `docs/testing.md` (#26)
- [ ] Release v0.1.0: CHANGELOG, signed APK, README screenshots (#27)

**Cut order if behind:** summaries first, then banner quick-add, then review inbox (auto-accept instead). Never cut ledger and limit-engine tests.

**Done / What broke / Decisions:** _(fill in at the end of the day)_

---

## Day 2 (cont.): Drift database and repositories (#13)

**Done**
- Wrote the drift schema (`lib/data/db/tables.dart`) covering every entity in design.md's ER diagram — Unit, Transaction, Category, LimitRule, Template, CaptureSource, UnparsedCapture, plus the settings key/value table — not just the four issue #13 names, since Transaction/Template/LimitRule already reference the others by id.
- `AppDatabase` (`lib/data/db/app_database.dart`): single file in app-private storage, opened lazily, foreign keys enforced, `schemaVersion 1` with an `onUpgrade` stub for the next change.
- `Drift*Repository` classes implement the same four interfaces (`UnitRepository`, `TransactionRepository`, `LimitRepository`, `SettingsRepository`) the mocks already did, and are now the default in `app_providers.dart` via a new `appDatabaseProvider`. No screen changed.
- Settings are stored as loose key/value rows rather than typed columns, so adding one more personalisation toggle later never needs a migration; `DriftSettingsRepository` owns the mapping to/from `AppSettings` and falls back to `AppSettings.defaults` on a fresh install.
- Round-trip tests in `test/data/db/app_database_test.dart` against an in-memory database: unit archive/unarchive, a linked `moved` pair, limit upsert-by-id, and settings defaults-then-save.

**Decisions**
- Renamed every generated drift data class with `@DataClassName` (`UnitRow`, `TransactionRow`, `LimitRuleRow`, ...) — drift's default naming would otherwise generate a `LimitRule` fighting with the domain model of the same name.
- Enums stored as their `.name` string, not an int index: reordering an enum's cases can't silently reinterpret an old row as the wrong value.
- Category, Template, CaptureSource and UnparsedCapture get tables now but no repository yet — deferred to the issues that build the features that use them (#19-#22), so this issue stays scoped to what #13 actually asked for.

**What broke / learned**
Nothing broke yet — the schema and repositories are new code with no prior implementation to reconcile against. The real test is still ahead: `dart run build_runner build` has to run before any of this compiles, and the two-isolate spike (#18) is where a schema written today either holds up or doesn't.

**Time spent:** _~2 hours_

---

## Day 3: Wed 23 Sep 2026 (planned)

**Goals**
- [ ] Template model and parser with tests (#19)
- [ ] Rule builder UI (#20)
- [ ] Share/paste to review inbox (#21)
- [ ] Notification listener with allow-list and dedupe (#22)
- [ ] Done when: a real notification creates a pending transaction and the banner updates

**Done / What broke / Decisions:** _(fill in)_

---

## Day 2: Tue 22 Sep 2026 (planned)

**Goals**
- [x] Finish Home screen (#8) properly wired to the real theme/status system
- [X] Add-transaction sheet (#9)
- [X] Activity screen (#10)
- [X] Drift database and repositories (#13) — domain models, ledger and mock repos already existed from Monday; real SQLite still to do
- [ ] Banner (#16) and the 2-hour listener spike (#18)

  **Done**
- Built the theme and component layer separately from Home (StatusPill, StatusRingCard, UnitCard, TransactionRow, AppChoiceChip, WordLabelChip, `AppColors` as a `ThemeExtension`).
- Caught two real duplications while reconciling that work with yesterday's Home screen: a second status enum (`BudgetStatus` alongside the domain's `SpendStatus`) and a `MoneyUnit` enum in `unit_card.dart` that silently shadowed the actual `MoneyUnit` model.
- Fixed by making `SpendStatus` the single status source of truth (presentation extensions in `app_status.dart`), and switching `UnitCard` to the domain's `UnitKind`. Rewired `home_screen.dart` to use the real widgets and theme tokens throughout — no more hardcoded hex colors or private duplicate widgets.
- Added `Money.majorValue` and `currencySymbol()` as a documented, display-only bridge between integer minor units and the widgets' `double` + symbol API.
  **What broke / learned**
  Building the theme/components and Home screen as separate pieces (mine from Monday, yours from the same day) meant they never got reconciled until today — Home kept working the whole time, so nothing *looked* broken, but it was quietly running on placeholder colors instead of the real design system. Lesson: when two people (or two sessions) build adjacent layers in parallel, integrate them the same day rather than letting each "work" in isolation. `flutter analyze` didn't catch the `MoneyUnit` collision because the two types never got imported into the same file — worth remembering that the analyzer won't save you from a naming collision unless something actually forces both into scope together.
  Mock repos looked done but weren't reactive (async* yields once, stream closes). New transactions silently vanished until app restart. Fixed with a small broadcast-stream store shared across all three mock repos.
  **Time spent:** _3hours_

---

## Day 1: Mon 21 Sep 2026

**Goals**
- [x] Repo, issues, milestones and docs set up from the terminal
- [x] Requirements document (#2) and UI design brief (#3)
- [x] Pick a name and check it for collisions
- [x] Design doc with data model and ADRs (#4)
- [x] App theme and personalisation shell (#6)
- [x] Devlog and testing checklist (#5) *(this commit)*
  **Done**
- Created the private repo and ran the setup script: 13 labels, 2 milestones, 27 MVP issues and 12 backlog issues.
- Scaffolded the Flutter project (Android only, minSdk 26) with a layered folder structure: `ui/`, `domain/`, `data/`.
- Wrote `requirements.md`, `ui-design-brief.md`, `design.md` (architecture, ER model, 10 ADRs) and the issue plan.
- Implemented the theme and personalisation shell (#6).
  **Decisions**
- **Name: Fuata** (Swahili, "follow"). Checked against Play Store listings, GitHub and web search. Rejected *Pesa Leo* (an existing Tanzanian loan app), *Baki* (an iOS expense tracker with nearly the same pitch), *Kiasi* (an existing Tanzanian savings and budgeting app), and the whole "Pesa___" family (saturated, and associated with loan apps, a bad fit for a privacy-first tracker).
- **UI first, engine second:** screens depend on repository interfaces and run on in-memory mocks; drift replaces them later without touching the screens.
- **Signed `amountMinor`:** balance is a plain sum; transfers are linked pairs; fees are child rows (ADR-005).
- **No encryption in v0.1:** time-boxed, mitigated by disabling backup; SQLCipher planned for v1.1 (ADR-010).
  **What broke / learned:** Nothing broke; the day was scaffolding and docs. The main lesson carried into Day 2: building the theme/components and the screens that consume them without checking them against each other the same day let them drift apart quietly (see Day 2).

**Time spent:** _3hours_

**Tomorrow:** see Day 2.