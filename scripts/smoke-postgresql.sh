#!/usr/bin/env bash
# Runs the same scenarios against any Bitnami-layout PostgreSQL image and prints a transcript.
# Two images behave the same when their transcripts are identical:
#   diff <(scripts/smoke-postgresql.sh REFERENCE) <(scripts/smoke-postgresql.sh CANDIDATE)
# Exits non-zero when a scenario fails outright (server never ready, wrong data, no replication).
set -euo pipefail
export MSYS_NO_PATHCONV=1 LC_ALL=C

image="$1"
p="lbsmoke$$"
failures=0
trap 'docker rm -f "$p-main" "$p-uid" "$p-primary" "$p-replica" >/dev/null 2>&1 || true
      docker volume rm "$p-data" >/dev/null 2>&1 || true
      docker network rm "$p-net" >/dev/null 2>&1 || true' EXIT

say() { printf '%s\n' "$*"; }
fail() { say "FAIL $*"; failures=$((failures + 1)); }

# q CONTAINER USER PASSWORD DATABASE SQL: run SQL over TCP, print unaligned tuples.
q() { docker exec -e PGPASSWORD="$3" "$1" psql -h 127.0.0.1 -U "$2" -d "$4" -v ON_ERROR_STOP=1 -XtAq -c "$5" 2>&1; }

wait_ready() {
  local c="$1" i
  for i in $(seq 1 180); do
    if docker logs "$c" 2>&1 | grep -q '\*\* Starting PostgreSQL \*\*' \
       && docker exec "$c" pg_isready -h 127.0.0.1 -p 5432 -U postgres -q >/dev/null 2>&1; then
      return 0
    fi
    if [[ "$(docker inspect -f '{{.State.Running}}' "$c" 2>/dev/null)" != true ]]; then
      fail "$c exited during startup"; docker logs "$c" 2>&1 | tail -n 20 >&2; return 1
    fi
    sleep 1
  done
  fail "$c not ready after 180s"; docker logs "$c" 2>&1 | tail -n 20 >&2; return 1
}

expect() { # expect NAME EXPECTED ACTUAL
  say "$1: $3"
  [[ "$3" == "$2" ]] || fail "$1: expected '$2'"
}

docker network create "$p-net" >/dev/null
docker volume create "$p-data" >/dev/null

# --- standalone server configured through environment variables, plus an init script ---
docker create --name "$p-main" --network "$p-net" -v "$p-data:/bitnami/postgresql" \
  -e POSTGRESQL_USERNAME=app -e POSTGRESQL_PASSWORD=apppw -e POSTGRESQL_DATABASE=appdb \
  -e POSTGRESQL_POSTGRES_PASSWORD=superpw -e POSTGRESQL_WAL_LEVEL=logical "$image" >/dev/null
init_dir="$(mktemp -d)"
printf 'CREATE TABLE init_marker (id int);\nINSERT INTO init_marker VALUES (42);\n' > "$init_dir/10-init.sql"
tar -C "$init_dir" -cf - 10-init.sql | docker cp - "$p-main:/docker-entrypoint-initdb.d/"
rm -rf "$init_dir"
docker start "$p-main" >/dev/null
wait_ready "$p-main"

expect "app login" "app|appdb" "$(q "$p-main" app apppw appdb 'select current_user, current_database()')"
expect "init script" "42" "$(q "$p-main" app apppw appdb 'select id from init_marker')"
expect "postgres is superuser" "t" "$(q "$p-main" postgres superpw postgres "select rolsuper from pg_roles where rolname = 'postgres'")"
su() { q "$p-main" postgres superpw "${2:-postgres}" "$1"; }
say "server_version: $(su 'show server_version')"
say "shared_preload_libraries: $(su 'show shared_preload_libraries')"
say "wal_level: $(su 'show wal_level')"
say "ssl_library: $(su 'show ssl_library')"
say "encoding: $(su "select pg_encoding_to_char(encoding), datcollate, datctype from pg_database where datname = 'appdb'")"
say "icu collations: $(su "select count(*) from pg_collation where collprovider = 'i'")"
say "lz4 column: $(su 'create table t_lz4 (x text compression lz4); insert into t_lz4 select repeat(md5(g::text), 200) from generate_series(1, 1) g; select pg_column_compression(x) from t_lz4; drop table t_lz4')"

# --- every available extension, created in a scratch database ---
su 'create database exttest' >/dev/null
for ext in $(su 'select name from pg_available_extensions order by 1'); do
  if out="$(su "create extension if not exists \"$ext\" cascade" exttest)"; then
    say "extension $ext: ok"
  else
    say "extension $ext: $(sed -n 1p <<<"$out")"
  fi
done
say "postgis: $(su 'select postgis_full_version()' exttest)"
say "pgvector: $(su "create table items (id int, e vector(3)); insert into items values (1, '[1,2,3]'), (2, '[4,5,6]'), (3, '[3,1,2]'); create index on items using hnsw (e vector_l2_ops); set enable_seqscan = off; select string_agg(id::text, ',' order by e <-> '[3,1,2]') from items" exttest | tail -n 1)"
say "pgvector distance: $(su "select '[1,2,3]'::vector <-> '[4,5,6]'" exttest)"
# Recent point releases only accept pgoutput and test_decoding as output plugins unless the session
# allows more at connection time (a SET in the same query is too late). Older ones have no such
# setting, and naming it there would refuse the connection.
w2j_opts=""
if [[ "$(su "select count(*) from pg_settings where name = 'output_plugin_libraries'")" == 1 ]]; then
  w2j_opts='-c output_plugin_libraries=pgoutput,test_decoding,wal2json'
fi
w2j() {
  docker exec -e PGPASSWORD=superpw -e PGOPTIONS="$w2j_opts" \
    "$p-main" psql -h 127.0.0.1 -U postgres -d exttest -v ON_ERROR_STOP=1 -XtAq -c "$1" 2>&1
}
w2j "select 'slot' from pg_create_logical_replication_slot('lb_slot', 'wal2json')" >/dev/null || fail "wal2json slot"
su "create table w2j (id int primary key, v text); insert into w2j values (1, 'one')" exttest >/dev/null || fail "wal2json table"
say "wal2json: $(w2j "select data from pg_logical_slot_get_changes('lb_slot', null, null) where data like '%insert%'" || true)"
say "pgbackrest: $(docker exec "$p-main" pgbackrest version)"

# --- restart on the same volume: data survives, init scripts do not run twice ---
docker restart "$p-main" >/dev/null
wait_ready "$p-main"
expect "after restart" "1" "$(q "$p-main" app apppw appdb 'select count(*) from init_marker')"

# --- arbitrary non-root UID (OpenShift style): exercises nss_wrapper ---
docker run -d --name "$p-uid" --user 1234:0 -e POSTGRESQL_PASSWORD=uidpw "$image" >/dev/null
wait_ready "$p-uid"
expect "arbitrary uid login" "postgres" "$(q "$p-uid" postgres uidpw postgres 'select current_user')"

# --- streaming replication between a primary and a replica ---
repl_env=(-e POSTGRESQL_REPLICATION_USER=repl -e POSTGRESQL_REPLICATION_PASSWORD=replpw -e POSTGRESQL_PASSWORD=pw)
docker run -d --name "$p-primary" --network "$p-net" -e POSTGRESQL_REPLICATION_MODE=master "${repl_env[@]}" "$image" >/dev/null
wait_ready "$p-primary"
docker run -d --name "$p-replica" --network "$p-net" -e POSTGRESQL_REPLICATION_MODE=slave \
  -e POSTGRESQL_MASTER_HOST="$p-primary" "${repl_env[@]}" "$image" >/dev/null
wait_ready "$p-replica"
q "$p-primary" postgres pw postgres "create table repl_check (v text); insert into repl_check values ('replicated')" >/dev/null
replicated=""
for _ in $(seq 1 30); do
  replicated="$(q "$p-replica" postgres pw postgres 'select v from repl_check' 2>/dev/null || true)"
  [[ "$replicated" == replicated ]] && break
  sleep 1
done
expect "replica in recovery" "t" "$(q "$p-replica" postgres pw postgres 'select pg_is_in_recovery()')"
expect "replicated row" "replicated" "$replicated"

say "failures: $failures"
exit $((failures > 0))
