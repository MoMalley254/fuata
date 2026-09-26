#!/usr/bin/env bash
set -euo pipefail
out="docs/issue-status.md"
{
  echo "# Issue status (generated $(date -u +%Y-%m-%dT%H:%MZ))"
  echo
  echo "Source of truth: GitHub. Regenerate with \`scripts/refresh-issue-status.sh\`."
  echo
  echo "| # | State | Milestone | Title |"
  echo "|---|---|---|---|"
  gh issue list --state all --limit 500 \
    --json number,title,state,milestone \
    --jq '.[] | "| #\(.number) | \(.state) | \(.milestone.title // "—") | \(.title) |"'
} > "$out"
echo "wrote $out"