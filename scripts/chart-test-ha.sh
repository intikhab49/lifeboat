#!/usr/bin/env bash
# Installs Bitnami's own postgresql-ha Helm chart (repmgr nodes behind pgpool) with a
# Bitnami-layout postgresql-repmgr image swapped in, writes through pgpool and checks that the
# standby streams the row and that repmgr sees both nodes. pgpool is Bitnami's last public build
# (bitnamilegacy); lifeboat doesn't rebuild it.
# Needs a kind cluster, helm and kubectl.
# Usage: scripts/chart-test-ha.sh IMAGE [KIND_CLUSTER]
set -euo pipefail

image="$1" cluster="${2:-kind}"
chart_version="${CHART_VERSION:-16.3.2}"
repository="${image%:*}" tag="${image##*:}"

kind load docker-image "$image" --name "$cluster"
helm install db oci://registry-1.docker.io/bitnamicharts/postgresql-ha --version "$chart_version" \
  --set global.security.allowInsecureImages=true \
  --set postgresql.image.registry=docker.io --set postgresql.image.repository="$repository" \
  --set postgresql.image.tag="$tag" --set postgresql.image.pullPolicy=Never \
  --set postgresql.replicaCount=2 --set postgresql.password=chartpw \
  --set postgresql.repmgrPassword=repmgrpw \
  --set pgpool.image.repository=bitnamilegacy/pgpool --set pgpool.image.tag=4.6.3-debian-12-r0 \
  --set pgpool.adminPassword=adminpw \
  --wait --timeout 15m

pod() { echo "db-postgresql-ha-postgresql-$1"; }
sql() { # sql POD HOST SQL
  kubectl exec "$1" -c postgresql -- env PGPASSWORD=chartpw psql -h "$2" -U postgres -XtAq -c "$3"
}
sql "$(pod 0)" db-postgresql-ha-pgpool "create table chart_check (v text); insert into chart_check values ('through pgpool')"
replicated=""
for _ in $(seq 1 30); do
  replicated="$(sql "$(pod 1)" 127.0.0.1 'select v from chart_check' 2>/dev/null || true)"
  [[ "$replicated" == "through pgpool" ]] && break
  sleep 2
done
nodes="$(kubectl exec "$(pod 0)" -c postgresql -- env PGPASSWORD=repmgrpw \
  psql -h 127.0.0.1 -U repmgr -d repmgr -XtAq -c "select type || ' ' || active from repmgr.nodes order by node_id" | paste -sd';' -)"

echo "chart: bitnamicharts/postgresql-ha $chart_version, image $image"
echo "server via pgpool: $(sql "$(pod 0)" db-postgresql-ha-pgpool 'show server_version')"
echo "node 1 in recovery: $(sql "$(pod 1)" 127.0.0.1 'select pg_is_in_recovery()')"
echo "replicated row: ${replicated:-none}"
echo "repmgr nodes: $nodes"
[[ "$replicated" == "through pgpool" && "$nodes" == "primary true;standby true" ]]
