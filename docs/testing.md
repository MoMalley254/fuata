# Testing: Fuata

**Related:** [requirements](requirements.md) (US-xx IDs), [design](design.md)

## 1. Strategy

| Level | What | How | When |
|---|---|---|---|
| Unit tests | Ledger, limit engine, parser, money helpers (pure Dart) | `flutter test` | Written with the code; **must pass before merging** |
| Widget tests | Key components (status card, transaction row) | `flutter test` | Only if time allows |
| Manual device tests | Everything involving Android: banner, listener, permissions, reboot | Checklist in section 3 on a **real device** | Thursday, before release |
| Privacy checks | No `INTERNET`, backup off, no unexpected network use | Commands in section 4 | Before tagging v0.1.0 |

**Priority rule:** ledger and limit-engine tests are never cut; everything else depends on them.

```bash
flutter analyze
flutter test
flutter test --coverage    # optional
```

## 2. Unit test plan

### Money helpers
| ID | Case | Expected |
|---|---|---|
| M-01 | Parse "1,250.50" with 2 decimals | 125050 minor units |
| M-02 | Format 125050 KES | "1,250.50" |
| M-03 | Currency with 0 decimals (e.g. JPY) | No decimal handling errors |
| M-04 | Sum of 0.10 + 0.20 as minor units | Exactly 30, no float drift |

### Ledger (US-02, US-03)
| ID | Case | Expected |
|---|---|---|
| L-01 | Unit with opening balance only | Balance = opening |
| L-02 | Add `spent` 350 | Balance decreases by 350 |
| L-03 | Add `got` 5,000 | Balance increases by 5,000 |
| L-04 | Move 2,000 from A to B | A −2,000, B +2,000, **total across units unchanged** |
| L-05 | Moved rows in spending and income totals | Excluded from both |
| L-06 | Fee as child `spent` row | Counted in spending; balance reduced by amount + fee |
| L-07 | Pending transaction | Excluded from balance and limits until confirmed |
| L-08 | Confirm a pending transaction | Balance and totals update |
| L-09 | Update balance to a new true value | Adjustment row equals the difference; balance matches |
| L-10 | Edit or delete a transaction | Balance recomputes correctly (never stale) |
| L-11 | Spending "today" across midnight boundary | Rows before/after local midnight land in the right day |
| L-12 | Archived unit | Excluded from totals but history kept |

### Limit engine (US-04, US-06)
| ID | Case | Expected |
|---|---|---|
| T-01 | Ratio 0.69 | Safe |
| T-02 | Ratio 0.70 | Warning |
| T-03 | Ratio 0.89 | Warning |
| T-04 | Ratio 0.90 | Danger |
| T-05 | Ratio 0.99 | Danger |
| T-06 | Ratio 1.00 and above | Overdraft |
| T-07 | Any unit balance below zero | Overdraft regardless of ratio |
| T-08 | No limit set | Neutral state, no alerts |
| T-09 | Per-unit limit vs overall limit | Each computed on its own scope |
| T-10 | Custom thresholds (e.g. 50/80) | Respected |
| T-11 | Week starts Monday; month is calendar month | Period boundaries correct |
| T-12 | Alert fires once per threshold per period | No repeat on the next transaction in the same band |
| T-13 | Limit and unit currencies differ | Unit excluded from the overall total |
| T-14 | One transaction jumps 50% → 105% | One "over" alert; lower levels marked used |
| T-15 | Quiet hours 22:00–07:00 | 23:00 and 06:59 quiet; 07:00 and 12:00 not; start == end never quiet |
| T-16 | Two claims for the same (limit, period, level) | Exactly one wins (drift primary key) |
| T-17 | Limit amount changed / limit deleted | Its announcements are cleared; editing levels or the switch keeps them |

### Summaries (US-12) — issue #23

| ID | Case | Expected |
|---|---|---|
| S-01 | Moved, adjustment and pending rows | Not in spent or got |
| S-02 | Summary spent vs `Ledger.spentInPeriod` | Same figure for day, week and month |
| S-03 | Sunday 23:59 vs Monday 00:00 | Sunday is last week, Monday this week |
| S-04 | 31 Aug 23:59 vs 1 Sep 00:00 | Calendar month boundary respected |
| S-05 | Unit in another currency | Excluded from the total (see T-13) |
| S-06 | "Java House" and "java house " | One recipient, amounts added, ranked by amount |
| S-07 | Fee row with a parent payment | Added to the parent's recipient, not a second transaction |
| S-08 | Money received | Ranked by who it came from |
| S-09 | Spending across units | Split biggest first |
| S-10 to S-12 | Previous period | Cut at the same point (time of day, day of week, day of month), incl. Dec to Jan |
| S-13 to S-17 | Story text | Total, top spot and comparison; no comparison without a previous figure; empty and income-only wording |
| S-18 | Average per day | Counts today; 1 day on a Monday |
| S-19 | Friendly money | ".00" dropped, real cents kept |

### Parser (US-08, US-09, US-10, US-11)
Use several fake messages, never real ones.

| ID | Case | Expected |
|---|---|---|
| P-01 | Labeled amount, code, date, person, balance | All fields extracted with correct types |
| P-02 | Amount formats: "Ksh350.00", "KES 1,250", "350" | Correct minor units |
| P-03 | Different names/numbers in the varying part | Still matches |
| P-04 | Regex special characters in the sample ( `.` `(` `+` `$` ) | Escaped; no false matches or crashes |
| P-05 | Message that does not match any template | Returns no match; goes to "couldn't read" |
| P-06 | Multiple templates on one unit (sent, received, withdrawal) | Correct template and direction chosen |
| P-07 | Same transaction code seen twice | Second is deduped, no duplicate row |
| P-08 | Same payment as SMS and push, no code | Deduped by unit + amount + 2-minute window |
| P-09 | Date formats (e.g. "21/9/26 at 1:12 PM", ISO) | Parsed to correct UTC timestamp |
| P-10 | Balance in message differs from computed | Unit flagged for reconciliation |
| P-11 | Template round trip: export to JSON, import | Identical behaviour |
| P-12 | Very long or empty message | No crash |

### Notification capture (US-10, US-11) — issue #22
Run against real drift repositories on an in-memory database (`test/domain/capture_pipeline_test.dart`); fake messages only.

| ID | Case | Expected |
|---|---|---|
| N-01 | Notification from an app that was never allowed | Ignored; no transaction **and no unparsed entry** (nothing stored) |
| N-02 | Notification from an app that is switched off | Same as N-01 |
| N-03 | Allowed app, message matches a template | Pending transaction, `source = notification`, `rawText` null |
| N-04 | Auto-accept on | Same transaction is confirmed immediately |
| N-05 | Same code arrives twice (P-07 via the listener path) | One row |
| N-06 | Same payment from two allowed apps, no code, inside 2 minutes (P-08) | One row |
| N-07 | Two notifications for one payment handed over together | Exactly one row (serial queue) |
| N-08 | Unreadable message re-posted three times | One "Couldn't read these" entry |
| N-09 | Same unreadable text from two different apps | Two entries |
| N-10 | Allow-list storage: one row per package, off keeps the row, order by name, toggling a template-referenced source doesn't break the FK | `capture_source_repository_test.dart` |

## 3. Manual device checklist

**Setup:** real Android device (API 26+), release or profile build installed, notification permission granted. Record device, Android version and build in the table at the end. Mark each row ☐ → ✅ or ❌ and add a note.

### Install and first run (US-01, US-14)
- [ ] First launch shows onboarding; every step can be skipped
- [ ] Adding a unit needs no card or account number
- [ ] Custom name, emoji/icon and colour are shown on Home
- [ ] Name and accent colour change the app's appearance
- [ ] Light, dark and system themes all work

### Transactions and balances (US-02, US-03)
- [ ] Spent, Got and Moved each save in about three taps from Home
- [ ] Balances on Home and My money match by hand
- [ ] Moved money does not change "spent today"
- [ ] Editing and deleting a transaction updates balances immediately
- [ ] Update balance creates an adjustment entry

### Limits and status (US-04, US-06)
- [ ] Setting a daily limit changes the Home hero card
- [ ] Safe → Warning → Danger → Overdraft transitions happen at 70%, 90%, 100%
- [ ] Status is legible without colour (icon and label present)
- [ ] Alert notification appears once per threshold, on its own channel
- [ ] Spend to 70% / 90% / 100% of the daily limit: three alerts, each once; spending more in the same band adds none
- [ ] Jump from under 70% straight past 100% with one transaction: one "over" alert, no 70%/90% ones afterwards
- [ ] Close the app, then let a captured notification cross a threshold: the alert still appears, exactly once (background isolate)
- [ ] Raise a limit's amount after alerting: approaching the new number alerts again. Only moving the alert sliders does not repeat anything
- [ ] Alert-level sliders: drag; the preview's emoji flips at the chosen numbers; the two thumbs cannot get within 5% of each other
- [ ] Quiet hours on, alert during the window: it appears in the shade with no sound or pop-up (channel "Limit alerts (quiet hours)"); outside the window it buzzes
- [ ] Alerts switch off: nothing fires, and turning it back on does not replay old ones
- [ ] Per-unit limit (Limits > More, and the unit page): only that unit's spending counts, the alert names the unit, blank field removes it

### Banner (US-05, US-07)
- [ ] Banner shows emoji, amount left and progress bar
- [ ] It updates within 2 seconds of adding a transaction
- [ ] Selected units only are shown; lock-screen amounts redacted by default
- [ ] "+ Add" from the banner opens quick add
- [ ] Swipe the banner away; it returns after the next transaction
- [ ] Disable banner in settings; it disappears

- [ ] Banner shows a status-coloured small icon (currently the launcher PNG, which MIUI hides — see design.md 5.3)
### Capture: share and paste (US-08, US-09, US-11)
- [ ] Paste a sample; label words; live preview shows extracted fields
- [ ] "Try another message" works with a second sample
- [ ] Sharing text from another app into Fuata opens the flow with no permissions
- [ ] Result lands in the review inbox as pending
- [ ] Looks right / Fix / Not mine behave correctly
- [ ] A non-matching message appears under "Couldn't read these" with "Teach me"

### Capture: notification listener (US-10)
- [ ] Onboarding explains the access clearly; on a sideloaded build the "restricted settings" step is documented and works
- [ ] After granting access, a notification from an allow-listed app creates a pending transaction
- [ ] A notification from a non-allow-listed app creates nothing and stores nothing
- [ ] **App fully closed** (swiped from recents): capture still works
- [ ] **After reboot:** capture still works without opening the app
- [ ] **Battery optimisation on:** note behaviour; the "keep me alive" guidance is shown
- [ ] Revoke notification access: app detects it and warns; re-grant restores capture
- [ ] Duplicate notification (same code) produces one transaction only
- [ ] Banner updates when a captured transaction is confirmed
- [ ] Me → Auto-catch lists installed apps; switching one on/off survives closing the app
- [ ] Auto-catch shows "Access is on/off" correctly, and updates after coming back from Android's settings
- [ ] **Open app on Home, then trigger an allow-listed notification: the pending item appears without restarting or switching tabs** (the background isolate writes through its own connection)
- [ ] Same, with the app closed, then open it: the pending item is there
- [ ] Post a notification from an app that is *not* switched on, then check the database: no transaction and no unparsed row
- [ ] Extracted text is the message body, not the notification tag or title (the #18 MIUI symptom, design.md 5.1)
- [ ] After updating the app (new build installed over the old), open the app once, then confirm capture resumes

### Summaries and detail level (US-12, US-13)
- [ ] Today/Week/Month figures match hand-calculated totals
- [ ] Top recipients and per-unit split are correct
- [ ] Day / Week / Month switch works; "See all" lists every recipient; "Show me more" opens and closes
- [ ] Reachable from Home ("See my summaries") and from the Activity app bar
- [ ] After midnight, reopen the screen: it shows the new day (see Known limitations)
- [ ] Simple, Balanced and Detailed levels show the intended fields only

### Data and privacy (US-15, US-16)
- [ ] Export creates a JSON file in a folder the user chooses
- [ ] Import from that file restores all units, transactions and templates
- [ ] Importing a corrupt or foreign file fails safely and changes nothing
- [ ] Import never overwrites existing data without confirmation
- [ ] Privacy screen states data stays on the phone
- [ ] Amounts are hidden in the recents screen (if enabled)

### Performance and robustness
- [ ] With 5,000 seeded transactions: Home opens under 2 s; Activity scrolls smoothly
- [ ] Rotating the device and changing font size do not break layouts
- [ ] Airplane mode makes no difference to any feature
- [ ] Changing the device time zone or date does not corrupt totals

### Accessibility
- [ ] Text remains readable at the largest system font size
- [ ] TalkBack reads the hero status and amounts sensibly
- [ ] Tap targets are comfortably large

## 4. Privacy verification (before tagging v0.1.0)

Build the release APK and inspect the merged manifest. Adjust the build-tools version to yours.

```bash
flutter build apk --release
APK=build/app/outputs/flutter-apk/app-release.apk
"$ANDROID_HOME"/build-tools/<version>/aapt2 dump permissions "$APK"
# Expected: NO android.permission.INTERNET (and no other network permissions)

"$ANDROID_HOME"/build-tools/<version>/aapt2 dump xmltree --file AndroidManifest.xml "$APK" | grep -i allowBackup
# Expected: allowBackup = false
```

Also confirm in Android Settings → Apps → Fuata → Permissions that no network or contacts permission is listed.

**Handy `adb` tips for testing the listener without a real bank message** (Android 11+). `cmd notification post` is posted as `com.android.shell`, which has no launcher icon, so it is not in the Auto-catch list: in a **debug build** type `com.android.shell` into Me → Auto-catch → "Add by package name", then switch it off again afterwards:

```bash
adb shell cmd notification post -S bigtext -t "Test Bank" fuata_test \
  "Confirmed. Ksh350.00 paid to JAVA HOUSE on 21/9/26 at 1:12 PM. Code QW12ABC3."
adb reboot
adb shell dumpsys deviceidle whitelist      # see battery-optimisation exemptions
```

## 5. Test run log

| Date | Build | Device / Android | Tester | Passed | Failed | Notes |
|---|---|---|---|---|---|---|
| | | | | | | |

## 6. Defect log

Failures found during a run become GitHub issues labelled `type: bug`, with steps, expected and actual results, and device details. Link them here.

| # | Summary | Severity | Status |
|---|---|---|---|
| | | | |

## 7. Known limitations (documented, not bugs)

- Manufacturer battery managers may stop the listener; guidance is provided but cannot be guaranteed.
- Notification content can be truncated or hidden by the SMS app, which can prevent parsing.
- Overall limits cover only units in the limit's currency (v0.1 is effectively single-currency).
- The database is not encrypted in v0.1 (ADR-010).
- Summary figures are computed when transactions change, so a summary screen left open across midnight keeps showing the old day until the next change or until it is reopened.
