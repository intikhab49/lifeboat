#!/usr/bin/env bash
# Moves the docs from one PostgreSQL minor to the next: the badge, the tags table, the examples,
# the action's description and its test. Lines that report a past run ("Results for ...") keep the
# version that run tested. With "repmgr" it moves only the lines about postgresql-repmgr (they
# mention repmgr); without it, only the other lines.
# Usage: scripts/readme-version.sh 17.11 17.12 [repmgr]
set -euo pipefail
export LC_ALL=C

old="$(sed 's/[.]/[.]/g' <<<"$1")" new="$2"
if [[ "${3:-}" == repmgr ]]; then lines="/repmgr/"; else lines="/repmgr/!"; fi
root="$(dirname "$0")/.."
sed -E -i \
  -e "/Results for/b" \
  -e "$lines s/(^|[^0-9.])$old([^0-9]|$)/\1$new\2/g" \
  -e "$lines s/%20$old(%20|-)/%20$new\1/g" \
  "$root/README.md" "$root/action.yml" "$root/.github/workflows/action-test.yml"
