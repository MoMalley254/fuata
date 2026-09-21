# Devlog

A running, honest record of the build: goals, what got done, what broke, and why decisions were made. Newest day first. Keep entries short; this is raw material for the README, the changelog and interviews.

**How to use:** at the start of the day, write 3 to 5 goals. At the end, tick them off and fill in *What broke / learned* and *Decisions*. Commit the devlog with the day's last commit.

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
- [ ] Finish the essential UI on mock data: Home (#8), add sheet (#9), Activity (#10)
- [ ] Drift database and repositories (#13)
- [ ] Ledger: balances, transfers, fees, with unit tests (#14)
- [ ] Limit engine with threshold tests (#15)
- [ ] Banner (#16) and the 2-hour listener spike (#18)

**Done / What broke / Decisions:** _(fill in)_

---

## Day 1: Mon 21 Sep 2026

**Goals**
- [x] Repo, issues, milestones and docs set up from the terminal
- [x] Requirements document (#2) and UI design brief (#3)
- [x] Pick a name and check it for collisions
- [x] Design doc with data model and ADRs (#4)
- [x] App theme and personalisation shell (#6)
- [ ] Devlog and testing checklist (#5) *(this commit)*

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

**What broke / learned:** _(fill in: anything that went wrong, and the fix)_

**Time spent:** _(fill in)_

**Tomorrow:** see Day 2.
