#!/usr/bin/env bash
# Moves the docs from one PostgreSQL minor to the next: the badge, the tags table, the examples,
# the action's description and its test. Lines that report a past run ("Results for ...") keep the
# version that run tested.
# Usage: scripts/readme-version.sh 17.11 17.12
set -euo pipefail
export LC_ALL=C

old="${1//./\.}" new="$2"
root="$(dirname "$0")/.."
sed -E -i \
  -e "/Results for/! s/(^|[^0-9.])$old([^0-9]|$)/\1$new\2/g" \
  -e "s/%20$old(%20|-)/%20$new\1/g" \
  "$root/README.md" "$root/action.yml" "$root/.github/workflows/action-test.yml"
