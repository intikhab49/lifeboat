#!/usr/bin/env bash
# Copies every component pin except PostgreSQL itself from 18's Dockerfile into 17's and 16's, so
# the three majors carry the same components, as the README says. pgaudit has one release line per
# PostgreSQL major and pg_auto_failover ships in 16 only, so those stay as each major pins them.
# Usage: scripts/align-majors.sh
set -euo pipefail
export LC_ALL=C

root="$(dirname "$0")/.."
source_file="$root/images/postgresql/18/debian-12/Dockerfile"
pins="$(grep -E '^ARG [A-Z0-9_]+_(VERSION|SHA256|DATE)=' "$source_file" | grep -vE '^ARG (POSTGRESQL|PGAUDIT|PGAUTOFAILOVER)_')"

for major in 17 16; do
  dockerfile="$root/images/postgresql/$major/debian-12/Dockerfile"
  while IFS= read -r line; do
    name="${line#ARG }"; name="${name%%=*}"
    old="$(sed -n "s/^ARG $name=//p" "$dockerfile")"
    [[ -n "$old" ]] || { echo "align: $major has no ARG $name; add the component by hand" >&2; exit 1; }
    if [[ "$line" != "ARG $name=$old" ]]; then
      sed -i "s|^ARG $name=.*|$line|" "$dockerfile"
      [[ "$name" == *_SHA256 ]] || echo "  $major: $name $old -> ${line#*=}"
    fi
  done <<<"$pins"
done
