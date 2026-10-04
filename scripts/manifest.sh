#!/usr/bin/env bash
# Prints a diffable description of a Bitnami-layout image, taken from the inside: OS packages,
# file tree, extensions, build flags, linked libraries, tool versions and vendored scripts.
# Sections start with "## <name>"; scripts/parity.sh splits and diffs them.
# Usage: docker run --rm -i -u root --entrypoint bash IMAGE -s < scripts/manifest.sh
set -euo pipefail
export LC_ALL=C

# Before installing the inspection tools, so they don't show up as packages.
echo "## os-packages"
dpkg-query -W -f '${Package}\n' | sort

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq >/dev/null
apt-get install -y -qq --no-install-recommends binutils file >/dev/null 2>&1

# Older Bitnami releases have no /opt/bitnami/protobuf, so walk only the prefixes an image has.
prefixes=()
for d in /opt/bitnami/postgresql /opt/bitnami/common /opt/bitnami/protobuf; do
  [[ -d "$d" ]] && prefixes+=("$d")
done
pg_bin=/opt/bitnami/postgresql/bin

echo "## files"
find "${prefixes[@]}" -mindepth 1 \( -type l -printf 'link %p -> %l\n' \) -o \( -type d -printf 'dir  %p\n' \) \
  -o \( -type f -printf 'file %p\n' \) | sort

echo "## modes"
find "${prefixes[@]}" -type f -perm -u+x -printf '%m %p\n' | sort

echo "## extensions"
for control in /opt/bitnami/postgresql/share/extension/*.control; do
  printf '%s %s\n' "$(basename "$control" .control)" \
    "$(sed -n "s/^[[:space:]]*default_version[[:space:]]*=[[:space:]]*'\(.*\)'.*/\1/p" "$control")"
done | sort

echo "## pg_config"
"$pg_bin/pg_config"

echo "## elf"
find "${prefixes[@]}" -type f | sort | while read -r f; do
  file -b "$f" | grep -q '^ELF' || continue
  needed="$(readelf -d "$f" 2>/dev/null | sed -n 's/.*(NEEDED).*\[\(.*\)\]/\1/p' | sort | paste -sd' ' -)"
  runpath="$(readelf -d "$f" 2>/dev/null | sed -n 's/.*(\(RUNPATH\|RPATH\)).*\[\(.*\)\]/\1=\2/p')"
  printf '%s | %s | %s\n' "$f" "${needed:--}" "${runpath:--}"
done

echo "## unresolved"
find "${prefixes[@]}" -type f | while read -r f; do
  file -b "$f" | grep -q '^ELF' || continue
  ldd "$f" 2>/dev/null | sed -n "s|^\s*\(.*\) => not found|$f: \1|p"
done | sort

echo "## versions"
# v TOOL ARGS: runs TOOL, or reports it missing, so a component one image lacks shows up in the diff.
v() { if [[ -x "$1" ]]; then "$@"; else echo "absent: $1"; fi; }
{
  v "$pg_bin/postgres" --version
  v "$pg_bin/psql" --version
  v "$pg_bin/pgbackrest" version
  echo "gdal $(v "$pg_bin/gdal-config" --version)"
  echo "geos $(v "$pg_bin/geos-config" --version)"
  # sed/grep read their whole input; head would close the pipe early (SIGPIPE, exit 141).
  v "$pg_bin/proj" 2>&1 | sed -n 1p
  v /opt/bitnami/protobuf/bin/protoc --version
  # protoc-c also logs a timestamped Abseil warning, which would differ on every run.
  v /opt/bitnami/common/bin/protoc-c --version 2>&1 | grep -vE '^WARNING: All log messages|^W[0-9]{4} '
  echo "unixodbc $(v /opt/bitnami/common/bin/odbc_config --version)"
} 2>&1

echo "## gdal-formats"
"$pg_bin/gdalinfo" --formats 2>/dev/null | sed 1d | awk '{print $1}' | sort

echo "## scripts"
find /opt/bitnami/scripts /usr/sbin/install_packages /usr/sbin/uninstall_packages /usr/sbin/run-script \
  -type f -exec sha256sum {} + | awk '{print $2, $1}' | sort

echo "## licenses"
find "${prefixes[@]}" -path '*/licenses/*' -type f -printf '%p %s\n' | sort
