#!/usr/bin/env bash

git switch -c fix/116-empty-home-call-to-action

git add -A
git commit -m 'fix(ui): Empty Home needs a call to action' -m 'Closes #116

- Empty Home now carries the one action that works: a FilledButton opening showEditUnitSheet.
- Floating + is hidden while units.isEmpty, since it opens a sheet that says "add some money first".
- A quiet line points at Settings → Auto-catch for the person who skipped that step too.'

git push -u origin fix/116-empty-home-call-to-action

gh pr create \
  --base main \
  --head fix/116-empty-home-call-to-action \
  --title 'fix(ui): Empty Home needs a call to action' \
  --body 'Closes #116

- With no units, Empty Home shows a FilledButton that opens the unit sheet.
- The floating + is hidden while units.isEmpty — it adds a transaction, and there is nothing to attach one to.
- A secondary line points at Settings → Auto-catch.'

gh pr merge fix/116-empty-home-call-to-action --merge --delete-branch

git switch main
git pull --ff-only