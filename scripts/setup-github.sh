#!/usr/bin/env bash
# Creates labels, milestones and issues for the project from the terminal.
# Run from inside the cloned repo AFTER `gh repo create ... --push`.
# Requires: gh (authenticated). Safe to re-run for labels; do NOT re-run issues.
set -euo pipefail

MVP="v0.1 MVP"
BACKLOG="v1.1 Backlog"

echo "==> Labels"
label() { gh label create "$1" --color "$2" --description "$3" --force >/dev/null; }
label "type: feature" 0E8A16 "New functionality"
label "type: bug"     D73A4A "Something is broken"
label "type: docs"    0075CA "Documentation"
label "type: test"    FBCA04 "Tests and test passes"
label "type: chore"   C5DEF5 "Setup, tooling, release"
label "area: ui"      F9D0C4 "Screens and components"
label "area: ledger"  BFD4F2 "Balances and transactions"
label "area: limits"  BFD4F2 "Limits and status engine"
label "area: banner"  BFD4F2 "Notification banner"
label "area: capture" BFD4F2 "Message and notification capture"
label "area: data"    BFD4F2 "Database, export, import"
label "risk"          B60205 "Could derail the schedule"
label "v1.1"          5319E7 "Planned after the first release"

echo "==> Milestones"
gh api repos/{owner}/{repo}/milestones -f title="$MVP" \
  -f due_on="2026-09-24T20:00:00Z" \
  -f description="First working release" >/dev/null || true
gh api repos/{owner}/{repo}/milestones -f title="$BACKLOG" \
  -f description="Deferred features" >/dev/null || true

echo "==> Issues (order matters: numbers match docs/github-issues.md)"
issue() { # title | labels (comma separated) | milestone | body
  gh issue create --title "$1" --label "$2" --milestone "$3" --body "$4" >/dev/null
  echo "  created: $1"
  sleep 1
}

# ---- Setup and docs (#1-#5)
issue "chore: initialise repo and Flutter project" "type: chore" "$MVP" \
"README skeleton, .gitignore, issue/PR templates, folder structure (ui/domain/data), lint rules.
**Done when:** project builds and runs on a device."
issue "docs: requirements document" "type: docs" "$MVP" \
"Add docs/requirements.md and link it from the README."
issue "docs: UI design brief and design tokens" "type: docs,area: ui" "$MVP" \
"Add docs/ui-design-brief.md. Record the chosen visual direction and tokens in docs/design.md."
issue "docs: design doc (data model, architecture, decision records)" "type: docs" "$MVP" \
"ER diagram, layer diagram, decision records: drift, Riverpod, notification listener over SMS permission, no encryption in v0.1, integer minor units."
issue "docs: devlog and testing checklist" "type: docs" "$MVP" \
"Create docs/devlog.md and docs/testing.md (manual device checklist)."

# ---- UI (#6-#12)
issue "feat(ui): app theme, tokens and personalisation shell" "type: feature,area: ui" "$MVP" \
"Light/dark themes, accent colour, bundled fonts (no runtime font download), status colours, reusable components: status ring card, unit card, transaction row, chips."
issue "feat(ui): onboarding flow" "type: feature,area: ui" "$MVP" \
"Name, accent, first units, optional daily limit, banner and auto-catch explainers. Everything skippable."
issue "feat(ui): Home (Today) screen" "type: feature,area: ui" "$MVP" \
"Hero status card in 4 states, unit cards, Lately list, empty state, bottom nav."
issue "feat(ui): add-transaction sheet" "type: feature,area: ui" "$MVP" \
"Spent/Got/Moved toggle, keypad-first amount, unit chips, collapsed More section."
issue "feat(ui): Activity screen and transaction detail" "type: feature,area: ui" "$MVP" \
"Day groups, filter chips, detail sheet, Simple/Balanced/Detailed detail levels."
issue "feat(ui): My money and unit pages" "type: feature,area: ui" "$MVP" \
"Unit cards, update balance, edit name/icon/colour."
issue "feat(ui): Me and personalisation settings" "type: feature,area: ui" "$MVP" \
"Home options, detail level, appearance, privacy panel."

# ---- Engine (#13-#27)
issue "feat(data): local database and repositories" "type: feature,area: data" "$MVP" \
"drift schema for Unit, Transaction, Limit, Template. Implements the repository interfaces already used by the UI. Includes migrations setup."
issue "feat(ledger): computed balances, transfers, fees" "type: feature,area: ledger" "$MVP" \
"Balance = opening + signed transactions (never stored). Moved is excluded from spending totals. Unit tests for money math and transfers."
issue "feat(limits): limit engine and status" "type: feature,area: limits" "$MVP" \
"Daily/weekly/monthly limits, overall and per unit. Safe/Warning/Danger/Overdraft (70/90/100%). Threshold unit tests."
issue "feat(banner): ongoing notification banner" "type: feature,area: banner" "$MVP" \
"Status emoji, progress bar, selected units, quick-add action, re-post if dismissed, separate alert channel."
issue "feat(banner): banner setup screen with live preview" "type: feature,area: banner,area: ui" "$MVP" \
"Choose units, headline, progress bar, lock-screen redaction. Live preview."
issue "spike: notification listener with app closed" "type: chore,risk,area: capture" "$MVP" \
"Time-box: 2 hours. Throwaway listener logs one notification and writes one DB row from a background isolate. Record findings in the design doc."
issue "feat(capture): template model and parser" "type: feature,area: capture" "$MVP" \
"Labeled spans to regex with typed groups. Multiple templates per unit. Tests with several fake samples."
issue "feat(capture): rule builder UI" "type: feature,area: capture,area: ui" "$MVP" \
"Paste sample, tap-to-label chips, live preview, test against more samples, save."
issue "feat(capture): share/paste to review inbox" "type: feature,area: capture" "$MVP" \
"Share target and paste path create pending transactions."
issue "feat(capture): notification listener with app allow-list and dedupe" "type: feature,area: capture" "$MVP" \
"Discard non-allowed notifications immediately. Dedupe by transaction code."
issue "feat(insight): Today/Week/Month summaries" "type: feature,area: ui" "$MVP" \
"Spent vs got, top recipients, per-unit split, simple by default with a more expander."
issue "feat(data): JSON export/import" "type: feature,area: data" "$MVP" \
"Validate on import. Never overwrite silently."
issue "chore(privacy): remove INTERNET permission and disable backup" "type: chore" "$MVP" \
"Verify against the built release APK manifest."
issue "test: manual device test pass" "type: test" "$MVP" \
"App closed, rebooted, battery-optimised, notification access revoked and re-granted."
issue "chore(release): v0.1.0" "type: chore" "$MVP" \
"CHANGELOG, signed APK, GitHub Release, README screenshots."

# ---- v1.1 backlog
for t in \
 "SQLCipher encryption with Android Keystore and app lock" \
 "Home screen widget" \
 "Outing mode (temporary budget with its own banner)" \
 "Scheduled daily/weekly/monthly summary notifications" \
 "Recipient to category rules" \
 "Recurring bills and expected income" \
 "Template packs: export/import/share by file or QR, bundled presets" \
 "Scheduled encrypted export to a user-chosen folder" \
 "Listener-inactive detection and manufacturer keep-alive guides" \
 "Opt-in redacted diagnostics copy button" \
 "iOS manual/share-sheet edition" \
 "Open-source licence review and contribution guide"; do
  issue "feat: $t" "type: feature,v1.1" "$BACKLOG" "Deferred from v0.1. See docs/requirements.md."
done

echo "Done."
