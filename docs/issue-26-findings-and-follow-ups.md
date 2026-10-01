# Issue #26: Manual device test pass, findings and follow-ups

I ran the manual device test pass for #26 and these are my findings. For each one I note what I saw, why I think it happens (from reading the code), the solution I'm going with, and the follow-up issue to open.

Where I haven't confirmed a cause yet, I've marked it **To confirm** and said how I'll check.

---

## 0. Summary and order of work

| # | Finding | Area | Severity | Size | Follow-up issue |
|---|---------|------|----------|------|-----------------|
| F1 | Banner tap or + Add from a closed app doesn't open the add sheet | nav | High | M | `refactor(nav): adopt go_router and fix banner cold-start routing` |
| F2 | Banner has no "show no units" state | banner | Low | S | `feat(banner): "no units" option` |
| F3 | Me screen is cramped; profile needs its own screen | ui | Medium | M | `refactor(ui): split Profile out of Me` |
| F4 | Home units and transactions aren't tappable | ui | High | XS | `fix(ui): make Home units and transactions tappable` |
| F5 | Activity doesn't scroll | ui | **Blocker** | XS | `fix(ui): Activity list doesn't scroll` |
| F6 | Week Peek missing on Home, "coming soon" in settings | ui | Medium | M | `feat(ui): Week Peek home widget` |
| F7 | Hide-amounts eye only hides on one screen | privacy | Medium | M | `feat(privacy): global hide amounts switch` |
| F8 | "Add something" is below the units list | ui | Low | XS | `fix(ui): add-unit action in My money app bar` |
| F9 | Archived units can't be seen or restored | data/ui | High | M | `feat(units): archived units screen and unarchive` |
| F10 | Reading rules empty state is blank and off-centre | ui | Low | S | `fix(ui): educational empty state for reading rules` |
| F11 | Teach-a-message fails on the Co-op message (ref, payee, date) | capture | **High** | L | `fix(capture): rule builder code, payee and date parsing` |
| F12 | No welcome screen in onboarding | onboarding | Medium | S | `feat(onboarding): welcome screen` |
| F13 | Onboarding steps leave a big empty gap | onboarding | Medium | S | `fix(onboarding): StepFrame layout` |
| F14 | Money step doesn't explain what units are | onboarding | Medium | S | `feat(onboarding): explain units` |
| F15 | Banner step doesn't prepare me for the notification permission | onboarding | High | S | `feat(onboarding): pre-permission copy for banner step` |
| F16 | Auto-catch step doesn't say what "Turn on" does | onboarding | **High** | M | `feat(onboarding): auto-catch walkthrough` |
| F17 | No dialog before Android's notification-access screen | permissions | **High** | S | `feat(permissions): notification-access primer dialog` |
| F18 | No dialog when choosing apps to watch | permissions | Medium | S | `feat(permissions): apps-to-watch explainer` |
| F19 | Categories not implemented | feature | Medium | L | `feat(categories): rename and add categories` |
| F20 | "Hide amounts in Recents" does nothing | privacy | Medium | S | `feat(privacy): FLAG_SECURE for Recents` |
| F21 | "Erase everything" is a stub | data | Medium | M | `feat(data): erase everything` |
| F22 | Unmatched notifications from watched apps look to be stored as raw text | privacy | **High** | S | `fix(capture): don't store unmatched notification text` |

Order I'll work in:

1. **Blockers and one-liners:** F5, F4, F8.
2. **The core promise of the app:** F11, F1, F22.
3. **Trust and first run:** F17, F16, F15, F12, F13, F14, F18. These share one reusable dialog and one layout fix (see section 8).
4. **Structure:** F3, F9, F7.
5. **Feature gaps (can go to v1.1):** F6, F19, F20, F21, F2, F10.

**Milestone:** F1, F4, F5, F11, F16, F17 and F22 block `v0.1.0` (#27). The rest can move to `v1.1 Backlog` if time is short.

---

## 1. Navigation and entry

### F1: Banner tap or "+ Add" from a closed app doesn't open the add sheet

**What I saw:** With the app fully closed, tapping the banner's **+ Add** opens the app but not the add sheet.

**Why:**
- `main.dart` handles `BannerAction.quickAdd` by calling `showAddTransactionSheet(rootNavigatorKey.currentContext)` in a post-frame callback.
- On a cold start `AppGate` first renders a blank `Scaffold` while settings load, then swaps to `RootShell` or `OnboardingScreen`. The sheet is requested before that swap settles, so it is dropped or lost when `AppGate` rebuilds.
- Nothing in the repo calls `getNotificationAppLaunchDetails()`, which is how the notification plugin reports which notification launched a terminated app. So on a cold start the action may never be seen at all. **To confirm:** add a `debugPrint` in `BannerPlatform._onResponse` and cold-start from the banner.
- A plain banner tap (`BannerAction.open`) is intentionally a no-op, so that part is expected.

**Solution (decided): move to `go_router`.**

1. Add `go_router` and switch `MaterialApp` to `MaterialApp.router`. Pass the existing `rootNavigatorKey` as the router's `navigatorKey`, and move `FlutterSmartDialog.observer` into the router's `observers`. Keep `builder: FlutterSmartDialog.init()`.
2. Route table:
    - `/splash` shown while settings load (replaces the blank `Scaffold` in `AppGate`)
    - `/onboarding`
    - `/` (the four-tab shell, as a `StatefulShellRoute` so each tab keeps its state like the current `IndexedStack`)
    - `/add` the add-transaction sheet
    - `/unit/:id`
    - `/inbox`
    - `/profile` (F3)
    - `/settings/...` (F3)
3. A single `redirect` owns the "where may I be" logic: settings still loading goes to `/splash`; onboarding not complete goes to `/onboarding` (this also means a banner action never opens an add sheet over onboarding); otherwise the requested location is allowed. Refresh it with a `refreshListenable` that listens to `settingsProvider`.
4. `/add` is presented as a real route using a small custom bottom-sheet `Page` (wrapping `ModalBottomSheetRoute`), so it can be a deep link. Every existing `showAddTransactionSheet(context)` call (the FAB, the banner) becomes `context.push('/add')`.
5. Cold start: in `main()`, before `runApp`, call `FlutterLocalNotificationsPlugin().getNotificationAppLaunchDetails()`. If the app was launched by a banner action, set the router's `initialLocation` to `/add` (or `/` for a plain tap). The redirect decides whether it is allowed yet.
6. Warm start: `_onBannerAction` calls `router.go('/add')` or does nothing for `open`. It no longer uses `rootNavigatorKey.currentContext`.
7. Move the share-intake landing (`RootShell._onSharedText` pushing the review inbox) to `context.push('/inbox')`, and give the later home-screen widget (#29) the same route table.

**Acceptance:**
- From a swiped-away app, **+ Add** opens the sheet within about a second; a plain banner tap opens Today.
- Same result after a reboot, and in both debug and release builds.
- During onboarding, neither action opens the sheet.
- Android back from the add sheet returns to Today.

---

### F2: Banner has no "show no units" state

**What I saw:** In the banner setup, "Units shown" only offers **All** or specific units. I can't choose to show none.

**Why:** `bannerUnitIds` being empty means "all", so there's no way to say "none". `banner_setup_screen.dart` also collapses "everything picked" and "nothing picked" back to **All**.

**Solution:** add an explicit mode to `AppSettings`:

```dart
enum BannerUnitsMode { all, selected, none }
```

- Store it as a new settings key defaulting to `all`; keep `bannerUnitIds` for `selected`.
- Add a **None** chip to "Units shown". `BannerContent.build` returns no unit lines for `none`, so the expanded banner shows only "Spent today …".
- Add the new key to `backup_codec.dart` and `backup_import.dart`, with a safe default when reading older backups, and update their tests.

**Acceptance:** Choosing **None** removes the unit lines in both the live preview and the real banner, and survives restart and backup/restore.

---

## 2. Me, Profile and settings structure

### F3: Me is cramped; profile needs its own screen

**What I saw:** Me holds the profile, Home options, detail level, limits/banner/messages, appearance and privacy in one long scroll.

**Solution:**
- **Profile screen** (`profile_screen.dart`): name, accent colour and avatar. It opens from the **profile action on Today** (the avatar in `Greeting`, made tappable and labelled "Profile" for accessibility). Reuse the existing `ProfileBlock` as its body.
- **Me becomes plain Settings.** A list of rows, each opening its own screen or sheet, rather than cards with controls inline:
    - Home (headline, sections)
    - Detail level
    - Appearance
    - Auto-catch
    - Caught from messages
    - Message reading rules
    - Limits & alerts
    - Banner
    - Categories
    - Privacy & data (hide amounts, lock-screen redaction, back up & restore, erase)
- Rename the tab from **Me** to **Settings**, since it no longer holds anything about me.
- Split `me_screen.dart` into `settings_screen.dart` plus small section widgets, reusing `ActionRow`. These become `/profile` and `/settings/...` in the router from F1.

**Acceptance:** Today avatar opens Profile. Settings contains no inline pickers longer than one row. Tests that look for the "Me" label are updated.

---

## 3. Home, Activity and lists

### F4: Home units and transactions aren't tappable

**What I saw:** Tapping a unit card or a "Lately" transaction on Today does nothing.

**Why:** In `home_screen.dart`, `UnitRow` builds `UnitCard(...)` and `HomeContent` builds `TransactionRow(...)` without passing `onTap`, although both widgets support it.

**Solution:**
- `UnitCard.onTap` goes to `/unit/:id` (the unit detail screen).
- `TransactionRow.onTap` calls `showTransactionDetail(context, transaction: t, unit: unitById[t.unitId])`.
- While in there, replace the repeated `state.units.firstWhere(...)` calls (four per row) with a single `unitById` map and a neutral icon fallback. `firstWhere` throws a `StateError` when a transaction's unit isn't in the list, which will happen for archived units (F9).

**To confirm:** `HomeState.lately` takes the latest three of all transactions, while Activity only shows confirmed ones. Check whether pending captures appear in "Lately" but not in Activity, and if so, show a small "pending" pill on the row.

**Acceptance:** Tapping a unit card opens its page; tapping a Lately row opens the detail sheet; a row whose unit is archived doesn't crash.

---

### F5: Activity doesn't scroll down

**What I saw:** On Activity, I can't scroll past the first screenful.

**Why (confirmed in the code):** `GroupedList` builds `ListView.builder(shrinkWrap: true, physics: NeverScrollableScrollPhysics())`, and `ActivityScreen` puts it inside an `Expanded`. The list refuses to scroll and nothing above it scrolls either. The same widget is used inside the unit page's own `ListView`, where that setup is correct, so it can't just be deleted.

**Solution:** give `GroupedList` a `shrinkWrap` flag that defaults to `false`:

```dart
ListView.builder(
  shrinkWrap: shrinkWrap,
  physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
  // ...
)
```

`UnitDetailScreen` passes `shrinkWrap: true`; `ActivityScreen` uses the default and scrolls.

**Also in this issue:** the day-header total adds up `spent` and `got` amounts using the currency of the first transaction's unit. With mixed currencies that is a made-up number, so hide the total when a day contains more than one currency.

**Acceptance:** With 100+ transactions Activity scrolls with the filter chips pinned, and the unit page still scrolls as one page.

---

### F6: Week Peek is missing on Home and still says "coming soon" in settings

**What I saw:** Settings shows a Week Peek toggle labelled "Coming soon", and Home has no week peek. I want it as its own widget.

**Why:** `HomeSection.weekPeek` exists and its toggle saves, but `HomeContent` only checks for `units` and `lately`, so nothing renders for it.

**Solution:**
- New standalone widget, `WeekPeekCard` in `widgets/home/week_peek.dart`: seven bars for the last seven days with today highlighted, a dashed line for the daily limit when one exists, day initials underneath, and a tap that opens Summary on the week view.
- Data comes from a new pure function `Ledger.spentByDay(transactions, days: 7)` with unit tests, exposed through `HomeState`.
- `HomeContent` renders it when `settings.homeSections` contains `HomeSection.weekPeek`.
- Remove "Coming soon" from `HomeSection.weekPeek.description`.
- Make it on by default for new installs; people who already saved their sections keep what they chose.
- Add a text alternative for screen readers ("Spent 1,200 on Tuesday").

**Acceptance:** Toggle on and the strip appears; off and it's gone; a day with no spending draws an empty bar; it looks right in dark mode.

---

## 4. My money

### F7: The hide-money eye only hides amounts on that one screen

**What I saw:** The eye on My money hides amounts there, but Today, Activity and the unit pages still show them.

**Why:** `MyMoneyScreen` keeps `bool _hidden` in its own widget state. It isn't shared and isn't saved, and only that screen and `UnitListTile(hideAmount:)` respect it.

**Solution:** make it a persisted global setting.
- Add `amountsHidden` to `AppSettings` (and the backup codec) and a provider for it.
- Create one `AmountText` widget, or a masked-format helper on `Money`, and use it everywhere an amount appears: Today hero and `StatusRingCard`, `UnitCard`, `TransactionRow`, Activity day totals, the transaction detail sheet, unit page, Summary cards and the banner preview.
- The eye icon appears on Today, My money and the unit page, and toggles the same value.
- Label the three different "hide" settings clearly so they aren't confused:
    - **Hide amounts in the app** (this one)
    - **Hide in app switcher** (F20)
    - **Hide banner on lock screen** (already exists)

**Acceptance:** The eye on any screen hides amounts on every screen, including sheets and Summary. It survives navigation and restart. A widget test checks that no `Ksh` text is visible while hidden.

---

### F8: "Add something" is below the units, so I have to scroll to add more

**What I saw:** On My money, the add button is after the last unit, so with several units I have to scroll to reach it.

**Solution:** add an `IconButton(Icons.add)` to the My money `AppBar.actions` that calls `showEditUnitSheet(context)`. Remove the bottom "Add something" row once there is at least one unit, and keep it only as the empty-state action. I'm using the app bar rather than a floating button because Today already uses a floating button for "add transaction", and the same shape meaning two things would be confusing.

The same app bar overflow menu is where the "Archived" entry from F9 goes.

---

### F9: I can archive a unit but can't see archived units or unarchive them

**What I saw:** After archiving, the unit disappears and there's no way back to it.

**Why:**
- `UnitRepository` has `archiveUnit` but no `unarchiveUnit`.
- `watchUnits(includeArchived: true)` exists but `unitsProvider` never uses it.
- `UnitDetailScreen` reads the active-only list, so an archived unit's page says "This one's gone".
- History for an archived unit still shows in Activity but is labelled "Unknown" with a 💰, because `unitById` has no entry for it.

**Solution:**
1. **Data:** add `Future<void> unarchiveUnit(String id)` to the repository interface, the Drift repository and the mock, with tests in `app_database_test.dart`. Add `allUnitsProvider` (includes archived) and `archivedUnitsProvider`.
2. **Archived screen:** My money app bar overflow menu gets **Archived (N)**, hidden when N is 0. It opens `ArchivedUnitsScreen`: name, last balance, "Archived on …" and a **Restore** button on each row. Tapping a row opens the unit page.
3. **Unit page:** read from `allUnitsProvider`. When `unit.archived`, show an "Archived" notice, replace **Archive** with **Restore**, and disable **Update balance**.
4. **Everywhere else:** Activity and the detail sheet use `allUnitsProvider` for names and icons so history reads "Cash (archived)" instead of "Unknown".
5. **Behaviour I'm deciding now:**
    - Reading rules for an archived unit stop catching messages. `CapturePipeline` skips archived units' templates, and the archive dialog says so.
    - Per-unit limits on an archived unit are paused, not deleted.
    - A restored unit keeps its original sort position.
    - The archive dialog tells the person how to undo it: "You can restore it from My money > Archived."

**Acceptance:** Archive a unit and it leaves Today, My money and the banner; it appears under Archived; Restore brings it back with history and rules intact; backup and restore keep the flag.

---

## 5. Message reading rules

### F10: Reading rules screen is very blank when no rules exist

**What I saw:** On a unit's Reading rules screen with no rules, there's one line of text and a button, and the "no rules" text and button don't look centred.

**Why:** `RulesBody` shows a single sentence and a button in a plain `Column`. It says nothing about what a rule is. **To confirm:** the off-centre look. I'll wrap the content in `Center` + `SingleChildScrollView` + `SizedBox(width: double.infinity)` with `crossAxisAlignment: center` and check on the device.

**Solution:** replace it with an educational empty state:
- Icon, then the headline **"Teach Fuata to read your bank messages"**.
- One sentence: "A rule shows Fuata what one kind of message looks like, so it can pull out the amount, who it was to and when."
- Three numbered steps: **1 Paste a message**, **2 Tap the words** (amount, person, date, code), **3 Save it**, with a small made-up example line showing coloured chips.
- Primary button **Teach a message**.
- Footer: "Rules stay on this phone. You can switch them off or delete them any time."

This becomes the shared `EducationalEmptyState` component, also reused for the empty Archived screen (F9).

---

### F11: Teach a message fails on the Co-op message

The message I tested with:

> Please NEVER share your PIN, PASSWORD, any codes or CARD details with ANYONE! not even people who may claim to be bank staff. Ref:AC4368F03026: Dear MORRIS, MPESA transfer of KES 500 to MORRIS KINYUA NJUGUNA-0743230001 at 28-09-2026 11:03 PM was successful.MPESA Ref:UIS9P8GJV5.

Tokenization itself works. Three things fail. They are separate bugs in separate places, so I'll do them as three small PRs under one parent issue, each with its own tests.

#### F11a: The bank ref can't be labelled

**What I saw:** I can't label `Ref:AC4368F03026` as the transaction code.

**Why (confirmed in the code):** The tokenizer treats `Ref:AC4368F03026` as one word, so a code label covers the whole thing. But the code field's pattern is `[A-Za-z0-9]+`, which can't match a colon. So the generated regex can't match its own sample and the rule silently fails.

**Solution (decided): loosen the code pattern to allow punctuation between characters**, so the entire `Ref:AC4368F03026` is taken as the transaction code. In `CaptureTemplate._fieldPattern`:

```dart
case TemplateFieldType.code:
  // Letters and digits, with punctuation allowed *between* them
  // (Ref:AC123, TXN-45/B, ab_12.3) but never leading or trailing,
  // so a sentence-ending "." or ":" stays outside the code.
  return r'[A-Za-z0-9]+(?:[:_\-./][A-Za-z0-9]+)*';
```

Notes:
- The tokenizer already peels trailing `.,;:!?` off a word, so the closing colon in `Ref:AC4368F03026:` stays literal text outside the code.
- The stored code will be `Ref:AC4368F03026`, including the `Ref:`. That is what I want.
- Add one guard for everyone: after any label change, check that the template matches its own sample. If it doesn't, show "This rule can't read its own sample, so a label probably includes something it can't match" and disable Save. Right now the rule just fails with no message.

**Acceptance:** Labelling `Ref:AC4368F03026` as code previews the full value; the rule matches a later message with a different ref; a code at the end of a sentence doesn't swallow the full stop.

#### F11b: Payee only shows "M"

**What I saw:** When payee is the last thing I label, the Found card shows just "M". When I label something else after it, the full payee shows.

**Why (confirmed in the code):** The person field compiles to a lazy match, `[\s\S]+?`. Issue #20 deliberately removed the trailing literal from the pattern, so when payee is the last label nothing follows it and a lazy match stops at one character. When another label follows, the literal text between them gives it a stopping point.

**Solution:** give a last lazy field a boundary:
- If there is text after the field in the sample, append a lookahead of the next few literal characters, for example `(?= at )`. The lookahead isn't consumed, so the variable tail of the message stays flexible.
- If the field runs to the end of the sample, match to the end of the line with `[^\n]+`.
- Use `[^\n]+?` instead of `[\s\S]+?` for person, so a payee never runs across a line break.

**Acceptance:** Payee labelled as the last field on the Co-op message shows `MORRIS KINYUA NJUGUNA-0743230001` in full.

#### F11c: Date fails to label

**What I saw:** The date doesn't label, and the Found card says "not labeled" even after I've labelled it.

**Why (confirmed in two places):**
1. `Parser._parseDate` only knows slash formats (`d/M/yy`, `d/M/yyyy`, with `at` or `HH:mm`). `28-09-2026 11:03 PM` matches none, so it returns null.
2. `FoundCard` shows "not labeled" for any null value. So a date I labelled but that couldn't be read looks exactly like one I never labelled.

**Solution (decided): accept dash-separated dates, and more formats generally.**
- In `_parseDate`, first normalise: trim; lowercase `at` and `on`; uppercase `am`/`pm`; turn `-` and `.` between numbers into `/`; collapse spaces. Then try these patterns (day first, which I'll document):
    - `d/M/yyyy h:mm a`, `d/M/yy h:mm a`
    - `d/M/yyyy HH:mm[:ss]`, `d/M/yy HH:mm`
    - `d/M/yy`, `d/M/yyyy`
    - `d MMM yyyy` (with or without time) and `dd-MMM-yy`
    - ISO, as now
    - Keep the `en_US` locale pin that is already there.
- Tighten the date field's regex so it doesn't depend on the lazy match: `\d{1,4}[-/.]\d{1,2}[-/.]\d{1,4}(?:[ ,]*(?:at\s+)?\d{1,2}:\d{2}(?::\d{2})?\s*(?:[AaPp][Mm])?)?`.
- Make `FoundCard` show three states for each row: found (the value), not labelled (the dashed chip), and labelled but couldn't be read ("Couldn't read '28-09-2026 11:03 PM' as a date"). `ParseResult` needs to carry the raw text or a field-errors map for that.
- To confirm: what time the capture pipeline uses when `occurredAt` is null. It should be the time the notification arrived.

**Acceptance:** `28-09-2026 11:03 PM` previews as 28 Sep 2026, 11:03 PM; `28/9/26 at 11:03 PM` and `2026-09-28 23:03` still parse; an unreadable date shows the "couldn't read" state.

#### F11d: Things this message shows that I'm noting but not fixing here

- **Two codes in one message** (bank ref and M-PESA ref): the second becomes `code2` and `Parser.parse` overwrites `code`, so the last one in map order wins. Short term the last labelled code wins and I'll document it. Later, split it into "Reference (used to spot duplicates)" and "Other code".
- **Unlabelled varying text becomes fixed text** (for example the phone number after the dash). That is existing issue **#55** ("This part changes"), which matters more now.
- **The long fixed warning at the start** has to match exactly in every future message, which is brittle if the bank changes it. Part of #55 as well.

#### F11e: Test messages

I couldn't find official, citable examples of Kenyan bank or mobile-money SMS formats. The shapes below are approximate with made-up numbers; I'll replace each with a redacted real message from my own phone and keep them as fixtures in `test/fixtures/messages.dart`.

| # | Source | Shape | What it stresses |
|---|---|---|---|
| 1 | Co-op | the message above | glued punctuation, dash date, two refs, trailing payee |
| 2 | M-PESA sent | `UIS9P8GJV5 Confirmed. Ksh500.00 sent to JOHN DOE 0712345678 on 28/9/26 at 11:03 PM. New M-PESA balance is Ksh1,234.56. Transaction cost, Ksh7.00.` | code first, `Ksh500.00` with no space, fee, balance |
| 3 | M-PESA received | `... Confirmed. You have received Ksh1,000.00 from JANE DOE 0722000000 on 28/9/26 at 9:15 AM. New M-PESA balance is ...` | direction is got, 12-hour times |
| 4 | M-PESA paybill | `... Confirmed. Ksh1,200.00 sent to KPLC PREPAID for account 12345678 on ...` | account number mustn't become the payee |
| 5 | M-PESA till | `... Confirmed. Ksh350.00 paid to SUPERMARKET LTD. on 28/9/26 at 1:12 PM.` | full stop after the payee |
| 6 | M-PESA agent withdrawal | `... Confirmed. on 28/9/26 at 4:10 PM Withdraw Ksh2,000.00 from 123456 - AGENT NAME ...` | different word order |
| 7 | Fuliza | `... Confirmed. Fuliza M-PESA amount is Ksh100.00. Interest charged Ksh1.00. Total Fuliza balance ...` | several amounts, avoid double counting |
| 8 | Airtel Money | `Txn ID XYZ123. You have sent KES 500 to ...` | different keywords and casing |
| 9 | Bank debit | `Acct: XXXX1234 debited KES 1,500.00 on 28-Sep-26 ... Bal: KES ...` | `dd-MMM-yy`, `Bal:` |
| 10 | Card payment | `Card ending 1234 used for KES 2,300.00 at SOME SHOP on 28/09/2026 ...` | merchant in the middle |
| 11 | Salary credit | `Your account has been credited with KES 85,000.00 ...` | large amount, got |
| 12 | Failed or reversed | `... Transaction failed / reversed ...` | must not become a transaction |

One parameterised test runs every fixture through: label like a person would, build the template, check it matches its own sample, then parse a second message of the same shape with a different name, amount and date. That second step is the real test, because it proves the rule generalises.

---

## 6. Onboarding

The current flow: **0** welcome, name and colour; **1** add money; **2** daily limit; **3** banner; **4** auto-catch.

### F12: No welcome screen

**What I saw:** The very first screen is a form. Nothing introduces the app or prepares me for setup.

**Solution:** add a new step 0 with no fields, warm and personal:
- A friendly hero (emoji or simple illustration); no step dots on this screen.
- Headline: **"Hi, I'm Fuata 👋"**
- Body: "I help you keep track of your money without the stress: what you have, what you've spent, and what's left for today. Everything stays on this phone."
- Three small lines: **Takes about 2 minutes**, **Skip anything you like**, **You can change it all later**.
- One button, **"Let's get started"**.
- The current step 0 becomes "What should we call you?".

Implementation: a `HelloStep` widget, `_stepCount` goes from 5 to 6, `StepDots` hidden on the first screen, and `onboarding_test.dart` plus widget tests that assume step 0 has the name field are updated. The copy sticks to *you* and *I* and avoids product words like units, templates and listeners; those belong on the explainer screens.

---

### F13: Content sits at the top with a big empty space above the buttons (first and limit screens)

**What I saw:** On the name/colour screen and the limit screen the content is at the top and there's a large gap before the buttons at the bottom.

**Why:** `StepFrame` is a column of a scrolling content area pinned to the top plus buttons pinned to the bottom. Short content leaves a hole in between.

**Solution:** fix it once in `StepFrame`:
- Add an optional `hero` slot (emoji or illustration) above the title.
- Wrap the content in `LayoutBuilder` > `SingleChildScrollView` > `ConstrainedBox(minHeight: viewport)` > `Column` with a `Spacer(flex: 1)` above and `Spacer(flex: 2)` below, so short content sits around 35 to 40% down the screen and long content just scrolls. This stays keyboard-safe.

For the limit screen specifically, also say that the limit is a gentle guide ("Fuata never stops you spending; it tells you early") and that the number can be changed later in Settings > Limits & alerts.

**Acceptance:** No large gap on a tall phone or a small one; opening the keyboard doesn't hide the primary button.

---

### F14: The money step doesn't explain what units are

**What I saw:** Screen 2 asks me to add units but never says what a unit is or how it helps.

**Solution:** add a short card above the quick-pick tiles:

> **What's a "unit"?**
> A unit is just a place your money lives: your cash, your M-PESA, a bank account.
> **Why add them?** You can see what's in each one, moving money between them doesn't count as spending, and Fuata can read messages for each one.

Use a tiny illustration of three tiles (Cash, M-PESA, Bank), and the existing `ReassuranceNote` for "We never ask for account or card numbers."

---

### F15: The banner step doesn't tell me a permission prompt is coming

**What I saw:** Tapping **Yes, show it** doesn't say that Android will ask for permission, why I should allow it, or what happens if I don't.

**Why:** The banner step only sets `bannerOn`. The notification permission (Android 13 and above) is requested later and implicitly, by `BannerPlatform.show()` and `showAlert()` via `_requestPermissionOnce()` the first time anything is posted, which is right after onboarding finishes. If I tap "Don't allow", `bannerEnabled` stays `true` and nothing shows, with no explanation.

**Solution:**
- Add copy below the preview:
  > **Heads-up:** when you tap *Yes*, Android will ask "Allow Fuata to send you notifications?" Please choose **Allow**; that's how the banner shows up. If you choose *Don't allow*, Fuata still works. You just won't see the banner or limit alerts, and you can turn them on later in Settings.
- Ask for the permission at that moment: on **Yes, show it**, call `requestNotificationsPermission()`, wait for the answer, and only then set `bannerEnabled`. If granted, continue. If denied, set `bannerEnabled = false`, show "No problem. You can turn the banner on later in Settings > Banner." and continue.
- In Settings > Banner, if the toggle is on but `areNotificationsEnabled()` is false, show "Android is blocking Fuata's notifications" with an **Open settings** button (after two denials Android stops showing the prompt).
- Skip the copy on Android 12 and below, which has no prompt.

---

### F16: The auto-catch step doesn't say what happens when I tap "Turn on"

**What I saw:** The last screen, the most important one, explains what is read but not what happens next.

**Why:** **Turn on** finishes onboarding and opens `AutoCatchScreen`. Nothing says that this takes me out to Android's settings or what I'll see there.

**Solution:** rewrite the last step as a "here's what will happen" screen.

Headline: **"One last thing: catching payments for you"**

*Here's how it goes:*
1. **Tap Show me how.** We finish setup and open the Auto-catch page.
2. **Tap "Turn on access".** That opens Android's *Notification access* list.
3. **Find Fuata and switch it on.** Android will show a warning. That's normal (see F17).
4. **Come back to Fuata** and pick which apps to watch: your messages app, M-PESA, your bank.

Keep the three existing points (what it reads, what it ignores, where it stays), but make them true first (F22). Add **"What if I say no?"**: "Nothing breaks. You can add payments by hand or share a message to Fuata, and turn this on any time in Settings > Auto-catch."

Rename the primary button from **Turn on** to **Show me how**, because it doesn't turn anything on by itself. Keep **Set it up later**.

---

## 7. Permissions

### F17: No dialog before Android's notification-access screen (onboarding and Settings)

**What I saw:** In Auto-catch settings, tapping **Turn on access** takes me straight to Android's settings with no warning. Android treats this as a critical, high-risk permission and will try hard to talk me out of it, and nothing prepares me for that.

**Solution:** build one `showNotificationAccessPrimer(context)` dialog and use it in both places (the onboarding hand-off and Settings > Auto-catch > **Turn on access**).

What Android actually does, so the copy is accurate:
- Notification access is one of Android's most sensitive permissions. Turning it on shows a confirmation that the app will be able to read all notifications, including personal information such as contact names and message text, and dismiss them. It reads as a warning.
- On an APK installed outside the Play Store (how v0.1 ships), Android 13 and above can grey out the switch as a "Restricted setting" until I open *App info > ⋮ > Allow restricted settings*. The screen already mentions this; the dialog should say it up front.
- Some phone makers add their own extra warnings.

Copy:

> **Before we jump to Android's settings 👋**
>
> To catch your payments, Fuata needs *notification access*. When you tap **Take me there**, Android opens a list of apps. Find **Fuata** and switch it on.
>
> **Heads-up: Android is going to sound alarmed.** It will warn that Fuata can "read all notifications". Android shows that message for every app with this permission, on purpose, because the permission is powerful. Here's what Fuata actually does:
> • It only looks at the apps **you** choose.
> • It never sends anything anywhere. There's no internet permission in this app.
> • You can switch it off any time, in Fuata or in Android settings.
>
> If the switch is greyed out, tap **⋮** in Fuata's *App info* and choose **Allow restricted settings**, then try again.
>
> **If you'd rather not:** that's fine. Fuata works without it. You'd add payments by hand or share a message to Fuata.
>
> [Not now]  [Take me there]

Behaviour:
- Show it every time **Turn on access** is tapped while access is off. When access is already on, **Manage access** skips the dialog.
- When I come back (the screen already re-checks on resume), show "Access is on 🎉" or "Still off. Want to try again?".
- Buttons are at least 48 dp and the dialog reads correctly in TalkBack.
- Built on the shared `PermissionPrimerDialog` (section 8).

---

### F18: No dialog when selecting apps to watch

**What I saw:** Switching on an app to watch gives no explanation, and the same OS-level scariness applies.

**Why it matters:** Choosing the messages app is a bigger decision than it looks, because Android delivers every notification from that app to Fuata: chats, one-time codes, delivery updates.

**Solution:** show a dialog the first time any app is switched on, and again when a messages app is switched on:

> **Watching "Messages"**
> Fuata will see the notifications this app shows, including ones that aren't about money. It only keeps the ones it can read as payments, using the rules you teach it.
> Tip: pick your **messages app** and your **bank or M-PESA app**. You don't need anything else.
> You can turn any app off here at any time.
> [Got it]

The sentence "only keeps the ones it can read as payments" must be true before this ships (F22). Also:
- Show recommended apps first (default messages app, M-PESA, banking apps).
- Show a "Watching 2 apps" summary at the top.
- If notification access is off when I toggle an app, add "This will start working once notification access is on" with a **Turn on access** button that opens the F17 dialog.

---

## 8. Settings gaps

### F19: Categories are not implemented

**What I saw:** Settings shows "Categories, coming soon". Detail level "Balanced" also promises a category.

**To confirm:** I didn't see a category column in `tables.dart` in the packed files; check the schema.

**Solution:** ship a minimal version.
- A `Categories` table (`id`, `name`, `emoji`, `sortOrder`, `archived`) and a nullable `categoryId` on transactions, with the migration, backup codec and tests.
- A default set: Food, Transport, Airtime, Bills, Rent, Shopping, Health, Fun, Other.
- A category chip row in the add sheet and the fix sheet.
- A settings screen to rename, add and archive categories.
- A per-category line in Summary.
- This also unblocks backlog **#32** (recipient to category rules).

If this slips to v1.1, remove the Categories row and the word "category" from the Balanced description until it ships.

---

### F20: "Hide amounts in Recents" does nothing

**What I saw:** Turning it on has no effect on the app switcher.

**Why (confirmed in the code):** The toggle only saves a boolean. There is no `FLAG_SECURE` or recents-screenshot handling in the Kotlin or Dart code, and the toggle's own subtitle says the OS hook comes later.

**Solution:** use `FLAG_SECURE` over a method channel.
- `MainActivity` gets a channel method `setSecure(bool)` that sets or clears `WindowManager.LayoutParams.FLAG_SECURE`.
- The app calls it at startup and whenever the setting changes. Read the setting before the first frame (or default to secure until settings load) so the first Recents snapshot is protected.
- Effect: the app switcher shows a blank card, and screenshots and screen recording are blocked too. Say so in the subtitle: "Hides Fuata in the app switcher. Also blocks screenshots."
- Rename the toggle to **Hide in app switcher** (F7).

**Acceptance:** With it on, the app switcher shows a blank Fuata, also after a cold start; off, it shows normally.

---

### F21: "Erase everything" still says coming soon

**What I saw:** Tapping it shows "Not yet".

**Solution:**
- Add `Future<void> eraseAll()` to the backup repository. In one transaction it deletes rows from every table (units, transactions, limits, templates, unparsed captures, capture sources and the allow-list, alert log, settings) and resets settings to defaults.
- Also cancel the banner and any alerts, clear the native allow-list mirror, and clear any native-side store (`CaptureStore.kt`).
- Two-step confirmation: first a dialog offering **Back up first** (which opens Back up & restore), then typing **ERASE** to confirm. Afterwards route to onboarding.
- Never touch backup files I've already saved.
- Remove `ComingSoonRow` and `_confirmEraseUnavailable`.
- Tests: after `eraseAll`, every watch stream is empty and `onboardingComplete` is false.

---

## 9. Found while reading the code

### F22: Unmatched notifications from watched apps look to be stored as raw text

**What I noticed:** In `capture_pipeline.dart`, a notification from an allowed app that matches no rule is saved through `_recordUnparsed(sourcePackage, trimmed)`, which keeps the raw text so it can appear under "I couldn't read this". I didn't see any "does this look like money?" check before that.

**To confirm:** I only saw the call sites in the packed repo. Open `capture_pipeline.dart` and `CaptureStore.kt` and check, then post a chat message and an OTP to a watched app and look at the database.

**Why it matters:** If I watch my messages app, every chat, OTP and delivery notification could end up in the database and in backups. That contradicts the onboarding promise that other notifications are dropped the moment they arrive, and US-10.

**Solution:** gate before storing.
- Only record an unparsed capture when the text looks financial: it contains a currency token (`KES`, `Ksh`, `KSh`, `/=`), or a number with commas or decimals near words like *sent, received, paid, debited, credited, transfer, withdraw, balance*. Anything else is dropped without being written.
- Always drop one-time-code text (`\b\d{4,8}\b` near `code`, `OTP`, `PIN` or `verification`), even if it also looks financial.
- Expire unparsed captures after 14 days and cap how many are kept.
- Add a test: a chat message and an OTP must produce no row.
- Until this ships, soften the F16, F17 and F18 copy so it doesn't promise more than the app does.

---

## 10. Shared building blocks (build once)

| Component | Used by |
|---|---|
| `PermissionPrimerDialog` (title, body, bullets, "what Android will say", primary and secondary buttons) | F15, F17, F18 |
| `AmountText` and the `amountsHidden` provider | F7 everywhere |
| Code pattern, date normaliser and message fixture corpus | F11 and later template packs (#34) |
| `StepFrame` with hero and vertically weighted body | F12, F13, F14 |
| `EducationalEmptyState` (icon, headline, numbered steps, button) | F10, F9 (empty Archived), F6 (empty week) |
| `go_router` route table | F1, F3, F4, F9 |

---

## 11. Issues to open

Use these titles with the labels from `docs/github-issues.md` (`type: ...`, `area: ...`). Branches follow `fix/...` and `feat/...`.

**v0.1 MVP (blocks release)**
- `fix(ui): Activity list doesn't scroll` (F5) · `type: bug` `area: ui`
- `fix(ui): make Home units and transactions tappable` (F4) · `type: bug` `area: ui`
- `refactor(nav): adopt go_router and fix banner cold-start routing` (F1) · `type: bug` `area: banner`
- `fix(capture): rule builder code, payee and date parsing` (F11a to F11c, with the F11e fixtures) · `type: bug` `area: capture`
- `fix(capture): don't store unmatched notification text` (F22) · `type: bug` `area: capture` `risk`
- `feat(permissions): notification-access primer dialog` (F17) · `type: feature` `area: ui` `area: capture`
- `feat(onboarding): auto-catch walkthrough and banner permission copy` (F15, F16) · `type: feature` `area: ui`

**v1.1 Backlog (or later in v0.1 if time allows)**
- `feat(onboarding): welcome screen, StepFrame layout and units explainer` (F12 to F14)
- `feat(units): archived units screen and unarchive` (F9)
- `feat(privacy): global hide amounts switch` (F7)
- `refactor(ui): split Profile out of Me` (F3)
- `feat(ui): Week Peek home widget` (F6)
- `feat(permissions): apps-to-watch explainer` (F18)
- `feat(privacy): FLAG_SECURE for Recents` (F20)
- `feat(data): erase everything` (F21)
- `feat(categories): rename and add categories` (F19)
- `feat(banner): "no units" option` (F2)
- `fix(ui): educational empty state for reading rules` (F10)
- `fix(ui): add-unit action in My money app bar` (F8)
- Already in the backlog and now more important: **#55** ("This part changes" wildcard).

---

## 12. Re-test checklist

- [ ] App swiped away: banner **+ Add** opens the add sheet; banner body opens Today; same after a reboot.
- [ ] During onboarding, a banner action does not open the add sheet.
- [ ] Activity scrolls with 100+ items; the unit page still scrolls as one page.
- [ ] Tap a unit card and a "Lately" row on Today.
- [ ] Hide amounts: every screen is masked, including sheets, Summary and the banner preview.
- [ ] Archive a unit, find it under Archived, restore it; history is intact.
- [ ] Co-op message: label ref, payee, amount and date; preview shows all four; save; a second Co-op message with a different recipient is caught.
- [ ] A dash-separated date (`28-09-2026 11:03 PM`) is read correctly.
- [ ] Onboarding on a small phone and a tall phone: no big gaps; the keyboard doesn't hide the button.
- [ ] Deny the notification permission in onboarding: banner shows as off, no crash, snackbar explains.
- [ ] Notification access: primer dialog, then Android's list, then the restricted-settings path on a sideloaded build, then back to "Access is on".
- [ ] Watch the messages app; send a chat message and an OTP; nothing is stored.
- [ ] Hide in app switcher on: Recents shows a blank card.
- [ ] Erase everything: back to onboarding with an empty database.