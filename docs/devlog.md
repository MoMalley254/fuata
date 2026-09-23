# Devlog

A running, honest record of the build: goals, what got done, what broke, and why decisions were made. Newest day first. Keep entries short; this is raw material for the README, the changelog and interviews.

*What broke / learned* and *Decisions*. 

---

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
- [ ] Activity screen (#10)
- [ ] Drift database and repositories (#13) — domain models, ledger and mock repos already existed from Monday; real SQLite still to do
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
