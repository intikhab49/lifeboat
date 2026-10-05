#!/usr/bin/env bash
# Moves an image directory to Bitnami's latest release of it. It re-vendors their scripts from
# bitnami/containers, then re-pins every component to the version in the BUILD.txt of their new
# package, downloading each changed source once to pin its SHA-256. Only BUILD.txt is read from
# the package (the first few KB of the stream); no Bitnami binary is used.
# Needs: gh (authenticated), curl, git, sha256sum.
# Usage: scripts/sync-from-bitnami.sh images/postgresql/18/debian-12
set -euo pipefail
export LC_ALL=C

dir="$1"
dockerfile="$dir/Dockerfile"
repo="$(sed -n 's/^repo=//p' "$dir/UPSTREAM")"
path="$(sed -n 's/^path=//p' "$dir/UPSTREAM")"
current="$(sed -n 's/^commit=//p' "$dir/UPSTREAM")"
slug="${repo#https://github.com/}"

latest="$(gh api "repos/$slug/commits?path=$path&per_page=1" --jq '.[0].sha')"
if [[ "$latest" == "$current" ]]; then
  echo "up to date: $slug@$current"
  exit 0
fi
echo "bitnami: $current -> $latest"

theirs="$(curl -fsSL "https://raw.githubusercontent.com/$slug/$latest/$path/Dockerfile")"
before="$(curl -fsSL "https://raw.githubusercontent.com/$slug/$current/$path/Dockerfile")"
component="$(grep -oE '"postgresql-[0-9][^"]*-linux-\$\{OS_ARCH\}-debian-[0-9]+"' <<<"$theirs" | tr -d '"')"
component="${component/\$\{OS_ARCH\}/amd64}"
nss="$(grep -oE 'nss-wrapper-[0-9.]+-[0-9]+' <<<"$theirs" | sed -n 1p)"

# tar stops after BUILD.txt; curl then fails writing (exit 23), which is expected.
build_txt="$( (curl -sSL "https://downloads.bitnami.com/files/stacksmith/$component.tar.gz" 2>/dev/null || true) \
  | tar -xzf - --wildcards --occurrence=1 '*/BUILD.txt' -O)"
[[ -n "$build_txt" ]] || { echo "sync: could not read BUILD.txt of $component" >&2; exit 1; }
urls="$(grep -E '^curl ' <<<"$build_txt" | grep -oE 'https?://[^ "]+')"

pick() { # pick ERE: print the first capture group of the first matching source URL
  sed -nE "s~$1~\1~p" <<<"$urls" | sed -n 1p # "~" because git URLs contain "#"
}
declare -A new
new[POSTGRESQL]="$(pick '.*/postgres/postgres/archive/refs/tags/REL_([0-9]+_[0-9]+)\.tar\.gz' | tr _ .)"
new[GEOS]="$(pick '.*/libgeos/geos/archive/([0-9.]+)\.tar\.gz')"
new[PROJ]="$(pick '.*/OSGeo/PROJ/archive/([0-9.]+)\.tar\.gz')"
new[GDAL]="$(pick '.*/gdal/releases/download/v([0-9.]+)/.*')"
new[JSONC]="$(pick '.*/json-c-([0-9.]+)-[0-9]{8}\.tar\.gz')"
new[JSONC_DATE]="$(pick '.*/json-c-[0-9.]+-([0-9]{8})\.tar\.gz')"
new[ORAFCE]="$(pick '.*/orafce/archive/refs/tags/VERSION_([0-9_]+)\.tar\.gz' | tr _ .)"
new[PLJAVA]="$(pick '.*/tada/pljava/archive/V([0-9_]+)\.tar\.gz' | tr _ .)"
new[UNIXODBC]="$(pick '.*/unixODBC-([0-9.]+)\.tar\.gz')"
new[PSQLODBC]="$(pick '.*/psqlodbc/archive/refs/tags/REL-([0-9_]+)\.tar\.gz' | awk -F_ '{printf "%d.%d.%d", $1, $2, $3}')"
new[PROTOBUF]="$(pick '.*/protobuf/releases/download/v([0-9.]+)/protobuf-[0-9.]+\.tar\.gz')"
new[ABSEIL]="$(pick '.*/abseil-cpp/releases/download/([0-9.]+)/.*')"
new[PROTOBUFC]="$(pick '.*/protobuf-c/releases/download/v([0-9.]+)/.*')"
new[POSTGIS]="$(pick '.*/postgis-([0-9.]+)\.tar\.gz')"
new[PGAUDIT]="$(pick '.*/pgaudit/pgaudit/archive/([0-9.]+)\.tar\.gz')"
new[PGBACKREST]="$(pick '.*/pgbackrest-([0-9.]+)\.tar\.gz')"
new[PGVECTOR]="$(pick '.*/pgvector/pgvector#refs/tags/v([0-9.]+)')"
new[PGFAILOVERSLOTS]="$(pick '.*/pg_failover_slots#refs/tags/v([0-9.]+)')"
new[WAL2JSON]="$(pick '.*/wal2json_([0-9_]+)\.tar\.gz' | tr _ .)"
new[NSSWRAPPER]="$(sed -E 's/^nss-wrapper-([0-9.]+)-[0-9]+$/\1/' <<<"$nss")"

# Where lifeboat downloads each source; keep in step with the Dockerfile's fetch lines.
url() {
  local v="$2"
  case "$1" in
    POSTGRESQL) echo "https://ftp.postgresql.org/pub/source/v$v/postgresql-$v.tar.bz2" ;;
    GEOS) echo "https://download.osgeo.org/geos/geos-$v.tar.bz2" ;;
    PROJ) echo "https://download.osgeo.org/proj/proj-$v.tar.gz" ;;
    GDAL) echo "https://github.com/OSGeo/gdal/releases/download/v$v/gdal-$v.tar.gz" ;;
    JSONC) echo "https://github.com/json-c/json-c/archive/refs/tags/json-c-$v-${new[JSONC_DATE]}.tar.gz" ;;
    ORAFCE) echo "https://github.com/orafce/orafce/archive/refs/tags/VERSION_${v//./_}.tar.gz" ;;
    PLJAVA) echo "https://github.com/tada/pljava/archive/refs/tags/V${v//./_}.tar.gz" ;;
    UNIXODBC) echo "https://www.unixodbc.org/unixODBC-$v.tar.gz" ;;
    PSQLODBC) IFS=. read -r a b c <<<"$v"
              printf 'https://github.com/postgresql-interfaces/psqlodbc/archive/refs/tags/REL-%02d_%02d_%04d.tar.gz\n' "$a" "$b" "$c" ;;
    PROTOBUF) echo "https://github.com/protocolbuffers/protobuf/releases/download/v$v/protobuf-$v.tar.gz" ;;
    ABSEIL) echo "https://github.com/abseil/abseil-cpp/releases/download/$v/abseil-cpp-$v.tar.gz" ;;
    PROTOBUFC) echo "https://github.com/protobuf-c/protobuf-c/releases/download/v$v/protobuf-c-$v.tar.gz" ;;
    POSTGIS) echo "https://download.osgeo.org/postgis/source/postgis-$v.tar.gz" ;;
    PGAUDIT) echo "https://github.com/pgaudit/pgaudit/archive/refs/tags/$v.tar.gz" ;;
    PGBACKREST) echo "https://github.com/pgbackrest/pgbackrest/releases/download/release/$v/pgbackrest-$v.tar.gz" ;;
    PGVECTOR) echo "https://github.com/pgvector/pgvector/archive/refs/tags/v$v.tar.gz" ;;
    PGFAILOVERSLOTS) echo "https://github.com/EnterpriseDB/pg_failover_slots/archive/refs/tags/v$v.tar.gz" ;;
    WAL2JSON) echo "https://github.com/eulerto/wal2json/archive/refs/tags/wal2json_${v//./_}.tar.gz" ;;
    NSSWRAPPER) echo "https://ftp.samba.org/pub/cwrap/nss_wrapper-$v.tar.gz" ;;
  esac
}

set_arg() { sed -i "s|^ARG $1=.*|ARG $1=$2|" "$dockerfile"; }
arg() { sed -n "s/^ARG $1=//p" "$dockerfile"; }
old_tag="$(arg POSTGRESQL_VERSION).0-debian-12-r$(arg IMAGE_REVISION)"
old_version="$(arg POSTGRESQL_VERSION)"

for name in POSTGRESQL GEOS PROJ GDAL JSONC ORAFCE PLJAVA UNIXODBC PSQLODBC PROTOBUF ABSEIL PROTOBUFC \
            POSTGIS PGAUDIT PGBACKREST PGVECTOR PGFAILOVERSLOTS WAL2JSON NSSWRAPPER; do
  v="${new[$name]}"
  [[ -n "$v" ]] || { echo "sync: $name not found in BUILD.txt; the recipe changed, update this script" >&2; exit 1; }
  old="$(sed -n "s/^ARG ${name}_VERSION=//p" "$dockerfile")"
  old_date="$(sed -n 's/^ARG JSONC_DATE=//p' "$dockerfile")"
  if [[ "$v" == "$old" && ( "$name" != JSONC || "${new[JSONC_DATE]}" == "$old_date" ) ]]; then
    continue
  fi
  source_url="$(url "$name" "$v")"
  sum="$(curl -fsSL --retry 3 "$source_url" | sha256sum | cut -d' ' -f1)"
  set_arg "${name}_VERSION" "$v"
  set_arg "${name}_SHA256" "$sum"
  [[ "$name" == JSONC ]] && set_arg JSONC_DATE "${new[JSONC_DATE]}"
  echo "  $name $old -> $v"
done

# Every bundled component must be one this script knows, or a new one slipped in.
known="postgresql geos proj gdal json-c orafce pljava unixodbc psqlodbc protobuf protobuf-c postgis pgaudit pgbackrest pgvector pg-failover-slots wal2json"
for c in $(sed -nE 's#^cd /bitnami/blacksmith-sandox/([a-z0-9-]+)-[0-9][0-9.]*\.tmp$#\1#p' <<<"$build_txt"); do
  [[ " $known " == *" $c "* ]] || { echo "sync: Bitnami now bundles '$c'; add it to the Dockerfile" >&2; exit 1; }
done

revision="$(sed -nE 's/.*IMAGE_REVISION="([0-9]+)".*/\1/p' <<<"$theirs")"
set_arg IMAGE_REVISION "$revision"

# The README names the one tag that matches a Bitnami tag exactly; keep it current.
new_tag="$(arg POSTGRESQL_VERSION).0-debian-12-r$revision"
readme="$(dirname "$0")/../README.md"
if [[ "$new_tag" != "$old_tag" ]] && grep -qF "\`$old_tag\`" "$readme"; then
  sed -i "s/\`${old_tag//./\\.}\`/\`$new_tag\`/" "$readme"
  echo "  README tag $old_tag -> $new_tag"
fi
# A new minor also moves the badge, the examples and the action's test to it.
if [[ "$(arg POSTGRESQL_VERSION)" != "$old_version" ]]; then
  bash "$(dirname "$0")/readme-version.sh" "$old_version" "$(arg POSTGRESQL_VERSION)"
  echo "  README version $old_version -> $(arg POSTGRESQL_VERSION)"
fi

# Their runtime package list is ours too.
packages="$(grep -E '^RUN install_packages ' <<<"$theirs")"
ours="$(grep -E '^RUN install_packages ' "$dockerfile")"
if [[ "$packages" != "$ours" ]]; then
  escaped="$(sed 's/[&|]/\\&/g' <<<"$packages")"
  sed -i "s|^RUN install_packages .*|$escaped|" "$dockerfile"
  echo "  runtime packages changed"
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
git -C "$work" init -q
git -C "$work" config core.autocrlf false
git -C "$work" remote add origin "$repo"
git -C "$work" sparse-checkout set "$path"
git -C "$work" fetch -q --depth 1 --filter=blob:none origin "$latest"
git -C "$work" checkout -q FETCH_HEAD
rm -rf "$dir/prebuildfs" "$dir/rootfs"
cp -r "$work/$path/prebuildfs" "$work/$path/rootfs" "$dir/"
rm -rf "$dir/prebuildfs/opt/bitnami/checksums"
sed -i "s|^commit=.*|commit=$latest|" "$dir/UPSTREAM"

echo
echo "Changes in Bitnami's Dockerfile that may need a hand-made change here:"
diff <(grep -vE 'org.opencontainers.image.(created|version)|-linux-\$\{OS_ARCH\}-debian|APP_VERSION=|IMAGE_REVISION=' <<<"$before") \
     <(grep -vE 'org.opencontainers.image.(created|version)|-linux-\$\{OS_ARCH\}-debian|APP_VERSION=|IMAGE_REVISION=' <<<"$theirs") \
  || true
