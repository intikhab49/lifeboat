#!/usr/bin/env bash
# Moves a major that Bitnami no longer builds (17, 16) to PostgreSQL's latest minor of it, using
# postgresql.org's release list and the .sha256 file published next to each source tarball.
# Usage: scripts/bump-postgresql-minor.sh 17
set -euo pipefail
export LC_ALL=C

major="$1"
root="$(dirname "$0")/.."
dockerfile="$root/images/postgresql/$major/debian-12/Dockerfile"
old="$(sed -n 's/^ARG POSTGRESQL_VERSION=//p' "$dockerfile")"

minor="$(curl -fsSL --retry 3 https://www.postgresql.org/versions.json \
  | jq -r --arg m "$major" '.[] | select(.major == $m) | .latestMinor')"
[[ "$minor" =~ ^[0-9]+$ ]] || { echo "bump: no release of $major in versions.json" >&2; exit 1; }
new="$major.$minor"
if [[ "$new" == "$old" ]]; then
  echo "up to date: PostgreSQL $old"
  exit 0
fi
# Only ever move forward; a stale mirror of versions.json must not downgrade the image.
[[ "$(printf '%s\n%s\n' "$old" "$new" | sort -V | tail -1)" == "$new" ]] || { echo "bump: $new is older than $old" >&2; exit 1; }

sum="$(curl -fsSL --retry 3 "https://ftp.postgresql.org/pub/source/v$new/postgresql-$new.tar.bz2.sha256" | cut -d' ' -f1)"
[[ "$sum" =~ ^[0-9a-f]{64}$ ]] || { echo "bump: no SHA-256 published for $new" >&2; exit 1; }
sed -i -e "s|^ARG POSTGRESQL_VERSION=.*|ARG POSTGRESQL_VERSION=$new|" \
       -e "s|^ARG POSTGRESQL_SHA256=.*|ARG POSTGRESQL_SHA256=$sum|" "$dockerfile"
bash "$root/scripts/readme-version.sh" "$old" "$new"
echo "  PostgreSQL $old -> $new"
