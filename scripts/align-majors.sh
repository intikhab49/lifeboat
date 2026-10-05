#!/usr/bin/env bash
# Copies 18's component pins into the images built from the same recipe, so they carry the same
# components, as the README says:
#   postgresql 17 and 16: everything except PostgreSQL itself, pgaudit (one release line per
#     PostgreSQL major) and pg_auto_failover (16 only), which stay as each major pins them.
#   postgresql-repmgr 18: everything except PostgreSQL, whose version follows Bitnami's
#     postgresql-repmgr release (see sync-from-bitnami.sh), and repmgr, which 18 doesn't have.
# Usage: scripts/align-majors.sh
set -euo pipefail
export LC_ALL=C

root="$(dirname "$0")/.."
source_file="$root/images/postgresql/18/debian-12/Dockerfile"
all="$(grep -E '^ARG [A-Z0-9_]+_(VERSION|SHA256|DATE)=' "$source_file")"

align() { # align IMAGE_DIR EXCLUDED_PREFIXES_ERE
  local dockerfile="$root/$1/Dockerfile" label="${1#images/}" line name old
  label="${label%/debian-12}"
  while IFS= read -r line; do
    name="${line#ARG }"; name="${name%%=*}"
    old="$(sed -n "s/^ARG $name=//p" "$dockerfile")"
    [[ -n "$old" ]] || { echo "align: $label has no ARG $name; add the component by hand" >&2; exit 1; }
    if [[ "$line" != "ARG $name=$old" ]]; then
      sed -i "s|^ARG $name=.*|$line|" "$dockerfile"
      [[ "$name" == *_SHA256 ]] || echo "  $label: $name $old -> ${line#*=}"
    fi
  done < <(grep -vE "^ARG ($2)_" <<<"$all")
}

align images/postgresql/17/debian-12 'POSTGRESQL|PGAUDIT|PGAUTOFAILOVER'
align images/postgresql/16/debian-12 'POSTGRESQL|PGAUDIT|PGAUTOFAILOVER'
align images/postgresql-repmgr/18/debian-12 'POSTGRESQL'
