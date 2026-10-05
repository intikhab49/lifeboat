#!/usr/bin/env bash
# Runs a two-node repmgr cluster from any Bitnami-layout postgresql-repmgr image, set up like
# Bitnami's docker-compose.yml, and prints a transcript: replication, the repmgr extension,
# automatic failover when the primary stops, and the old primary rejoining as a standby.
# Two images behave the same when their transcripts are identical:
#   diff <(scripts/smoke-repmgr.sh REFERENCE) <(scripts/smoke-repmgr.sh CANDIDATE)
# Exits non-zero when a scenario fails.
set -euo pipefail
export MSYS_NO_PATHCONV=1 LC_ALL=C

image="$1"
p="lbrepmgr$$"
failures=0
trap 'docker rm -f "$p-0" "$p-1" >/dev/null 2>&1 || true
      docker volume rm "$p-0-data" "$p-1-data" >/dev/null 2>&1 || true
      docker network rm "$p-net" >/dev/null 2>&1 || true' EXIT

say() { printf '%s\n' "$*"; }
fail() { say "FAIL $*"; failures=$((failures + 1)); }

# q CONTAINER SQL [DATABASE]: run SQL as postgres over TCP, print unaligned tuples.
q() { docker exec -e PGPASSWORD=adminpw "$1" psql -h 127.0.0.1 -U postgres -d "${3:-postgres}" -v ON_ERROR_STOP=1 -XtAq -c "$2" 2>&1; }

wait_ready() {
  local c="$1" i
  for i in $(seq 1 240); do
    if docker logs "$c" 2>&1 | grep -q '\*\* Starting repmgrd \*\*' \
       && docker exec "$c" pg_isready -h 127.0.0.1 -p 5432 -U postgres -q >/dev/null 2>&1; then
      return 0
    fi
    if [[ "$(docker inspect -f '{{.State.Running}}' "$c" 2>/dev/null)" != true ]]; then
      fail "$c exited during startup"; docker logs "$c" 2>&1 | tail -n 30 >&2; return 1
    fi
    sleep 1
  done
  fail "$c not ready after 240s"; docker logs "$c" 2>&1 | tail -n 30 >&2; return 1
}

# wait_for NAME EXPECTED SECONDS COMMAND...: poll until COMMAND prints EXPECTED, then report.
wait_for() {
  local name="$1" expected="$2" seconds="$3" out="" i
  shift 3
  for i in $(seq 1 "$seconds"); do
    out="$("$@" 2>/dev/null || true)"
    [[ "$out" == "$expected" ]] && break
    sleep 1
  done
  say "$name: ${out:-none}"
  [[ "$out" == "$expected" ]] || fail "$name: expected '$expected'"
}

node() { # node INDEX: start node pg-INDEX of the cluster
  docker run -d --name "$p-$1" --hostname "$p-$1" --network "$p-net" -v "$p-$1-data:/bitnami/postgresql" \
    -e POSTGRESQL_POSTGRES_PASSWORD=adminpw -e POSTGRESQL_USERNAME=customuser \
    -e POSTGRESQL_PASSWORD=custompw -e POSTGRESQL_DATABASE=customdb -e REPMGR_PASSWORD=repmgrpw \
    -e REPMGR_PRIMARY_HOST="$p-0" -e REPMGR_PRIMARY_PORT=5432 -e REPMGR_PARTNER_NODES="$p-0,$p-1:5432" \
    -e REPMGR_NODE_NAME="$p-$1" -e REPMGR_NODE_NETWORK_NAME="$p-$1" -e REPMGR_PORT_NUMBER=5432 \
    "$image" >/dev/null
}

# Roles as repmgr records them, with this run's container prefix taken out.
cluster() {
  q "$1" "select node_name || ' ' || type || ' ' || active from repmgr.nodes order by node_name" repmgr \
    | sed "s/^$p-/pg-/" | paste -sd';' -
}

docker network create "$p-net" >/dev/null
docker volume create "$p-0-data" >/dev/null
docker volume create "$p-1-data" >/dev/null

# --- primary, then a standby that clones it ---
node 0
wait_ready "$p-0" || { say "failures: $failures"; exit 1; }
node 1
wait_ready "$p-1" || { say "failures: $failures"; exit 1; }

# As root: UID 1001 has no passwd entry outside the entrypoint's nss_wrapper, and repmgr wants one.
say "repmgr: $(docker exec -u root "$p-0" repmgr --version 2>&1)"
say "repmgrd: $(docker exec "$p-0" repmgrd --version 2>&1)"
say "extension: $(q "$p-0" "select extversion from pg_extension where extname = 'repmgr'" repmgr | sed 's/^/repmgr /')"
docker exec -e PGPASSWORD=repmgrpw "$p-0" psql -h 127.0.0.1 -U repmgr -d repmgr -XtAq -c 'select 1' >/dev/null 2>&1 \
  && say "repmgr user can connect: yes" || fail "repmgr user cannot connect"
say "pg-0 in recovery: $(q "$p-0" 'select pg_is_in_recovery()')"
say "pg-1 in recovery: $(q "$p-1" 'select pg_is_in_recovery()')"
wait_for "cluster" "pg-0 primary true;pg-1 standby true" 60 cluster "$p-0"
q "$p-0" "create table repl_check (v text); insert into repl_check values ('before failover')" >/dev/null
wait_for "replicated to pg-1" "before failover" 30 q "$p-1" 'select v from repl_check'
docker exec -e PGPASSWORD=custompw "$p-1" psql -h 127.0.0.1 -U customuser -d customdb -XtAq -c 'select current_user' \
  | sed 's/^/custom user on standby: /'

# --- the primary goes away: repmgrd on pg-1 promotes it ---
docker stop -t 10 "$p-0" >/dev/null
wait_for "pg-1 promoted (in recovery)" "f" 120 q "$p-1" 'select pg_is_in_recovery()'
q "$p-1" "insert into repl_check values ('after failover')" >/dev/null || fail "pg-1 does not take writes"
# A restarting node asks its partners which node is primary. Until repmgrd has recorded the
# promotion, the answer is still pg-0, which would come back as a second primary, so wait for it.
wait_for "failover recorded" "pg-0 primary false;pg-1 primary true" 60 cluster "$p-1"

# --- the old primary comes back and follows the new one ---
docker start "$p-0" >/dev/null
wait_for "pg-0 rejoined (in recovery)" "t" 180 q "$p-0" 'select pg_is_in_recovery()'
wait_for "replicated to pg-0" "after failover" 60 q "$p-0" "select v from repl_check where v = 'after failover'"
wait_for "cluster after failover" "pg-0 standby true;pg-1 primary true" 60 cluster "$p-1"

say "failures: $failures"
exit $((failures > 0))
