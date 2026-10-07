<picture>
  <source media="(prefers-color-scheme: dark)" srcset=".github/assets/banner-dark.png">
  <img alt="lifeboat: Bitnami's PostgreSQL image, rebuilt from upstream source" src=".github/assets/banner-light.png">
</picture>

[![build](https://github.com/intikhab49/lifeboat/actions/workflows/build.yml/badge.svg)](https://github.com/intikhab49/lifeboat/actions/workflows/build.yml)
[![GitHub Marketplace](https://img.shields.io/badge/Marketplace-lifeboat-ff5b1f?logo=github)](https://github.com/marketplace/actions/postgresql-with-pgvector-and-postgis-lifeboat)
[![image](https://img.shields.io/badge/ghcr.io-lifeboat%2Fpostgresql-0e2a47?logo=docker&logoColor=white)](https://github.com/intikhab49/lifeboat/pkgs/container/lifeboat%2Fpostgresql)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-18.6%20%7C%2017.11%20%7C%2016.15-336791?logo=postgresql&logoColor=white)](#tags)
[![arch](https://img.shields.io/badge/arch-amd64%20%7C%20arm64-ff5b1f)](#tags)
[![license](https://img.shields.io/badge/license-Apache--2.0-blue)](LICENSE)

**A drop-in replacement for `bitnami/postgresql`, rebuilt from upstream source** (and for
`bitnami/postgresql-repmgr`, [the HA image](#high-availability-postgresql-repmgr)). Same paths,
scripts, environment variables and tags, so it works with Bitnami's Helm chart, your
docker-compose files and your CI. Free to pull, amd64 and arm64, with pgvector, PostGIS and 50+
extensions, and none of its binaries come from Broadcom.

[Use it](#use-it) · [GitHub Actions](#github-actions) · [Why from source](#why-not-just-build-bitnamis-dockerfile) · [How it's built](#how-its-built) · [The pgvector crash](#the-pgvector-crash-this-build-fixes) · [Proof](#proof-its-the-same-image) · [FAQ](#faq)

If you are here because of this:

```
Error response from daemon: failed to resolve reference "docker.io/bitnami/postgresql:17.6.0-debian-12-r0": docker.io/bitnami/postgresql:17.6.0-debian-12-r0: not found
```

Broadcom removed the versioned `bitnami/*` tags from Docker Hub in 2025. `bitnami/postgresql` now
only has `latest`, and the copies in `bitnamilegacy` stopped getting updates in August 2025.
Change the image and keep the rest of your setup.

## Use it

```bash
docker run -d -p 5432:5432 -e POSTGRESQL_PASSWORD=secret ghcr.io/intikhab49/lifeboat/postgresql:18.6.0
```

```yaml
# docker-compose.yml
services:
  db:
    image: ghcr.io/intikhab49/lifeboat/postgresql:18
    environment:
      POSTGRESQL_PASSWORD: secret
    volumes:
      - db:/bitnami/postgresql
volumes:
  db:
```

With Bitnami's Helm chart:

```bash
helm install db oci://registry-1.docker.io/bitnamicharts/postgresql \
  --set image.registry=ghcr.io \
  --set image.repository=intikhab49/lifeboat/postgresql \
  --set image.tag=18.6.0 \
  --set global.security.allowInsecureImages=true
```

> [!NOTE]
> The chart refuses images it doesn't know (`Original containers have been substituted for
> unrecognized ones`), hence the last flag. CI installs the real chart in replication mode with
> each image on every build: chart 18.12.4 with 18, 16.7.27 with 17 and 15.5.38 with 16.

Every `POSTGRESQL_*` variable, `/docker-entrypoint-initdb.d`, the `/bitnami/postgresql` volume,
UID 1001, replication mode and arbitrary-UID support (OpenShift) work the same way, because they
are Bitnami's own scripts.

### Tags

| Tag | Meaning |
|---|---|
| `18.6.0-debian-12-r17` | same version, OS and scripts revision as Bitnami's tag of that name |
| `18.6.0`, `18.6`, `18`, `latest` | moving tags, as on Bitnami |
| `17.11.0`, `17.11`, `17` | PostgreSQL 17 |
| `16.15.0`, `16.15`, `16` | PostgreSQL 16, with pg_auto_failover as in Bitnami's 16 |

Bitnami no longer releases 17 or 16. Their last public builds were `17.6.0-debian-12-r10` and
`16.9.0-debian-12-r13`, and neither tag can be pulled from Docker Hub today. lifeboat runs the
scripts from those two releases on the current point release of each major, with the same
components as 18. A daily job opens a pull request when PostgreSQL ships a new point release of
17 or 16, and every Bitnami sync of 18 carries its component updates to 17 and 16. If your setup
pins one of Bitnami's old 17 or 16 tags, use `17` or `16`: a newer point release of the same major
reads the same data directory, so nothing needs a dump and restore. The extensions are newer than in those builds (PostGIS 3.6.4 instead of 3.4.4, pgvector
0.8.7 instead of 0.8.0 or 0.8.1), so after switching, run `SELECT postgis_extensions_upgrade();`
and `ALTER EXTENSION vector UPDATE;` in the databases that use them.

### High availability: postgresql-repmgr

`ghcr.io/intikhab49/lifeboat/postgresql-repmgr` replaces `bitnami/postgresql-repmgr`, the image
behind Bitnami's postgresql-ha chart: the same PostgreSQL build plus repmgr 5.5.0, with Bitnami's
repmgr scripts, so automatic failover and `REPMGR_*` settings work as before.

```bash
helm install db oci://registry-1.docker.io/bitnamicharts/postgresql-ha \
  --set postgresql.image.registry=ghcr.io --set postgresql.image.repository=intikhab49/lifeboat/postgresql-repmgr \
  --set postgresql.image.tag=18 \
  --set pgpool.image.repository=bitnamilegacy/pgpool --set pgpool.image.tag=4.6.3-debian-12-r0 \
  --set global.security.allowInsecureImages=true
```

| Tag | Meaning |
|---|---|
| `18.6.0-debian-12-r19` | same version, OS and scripts revision as Bitnami's postgresql-repmgr tag of that name |
| `18.6.0`, `18.6`, `18`, `latest` | moving tags of postgresql-repmgr, as on Bitnami |

CI runs two nodes the way Bitnami's docker-compose.yml does, stops the primary, checks that the
standby is promoted and that the old primary rejoins as a standby, then installs the postgresql-ha
chart (16.3.2) and writes through pgpool. pgpool itself is not rebuilt here, so the chart still
uses Bitnami's last public pgpool image from `bitnamilegacy`.

## GitHub Actions

As a step, with extensions ready to use:

```yaml
- uses: intikhab49/lifeboat@v1
  id: pg
  with:
    extensions: vector, postgis
- run: psql "${{ steps.pg.outputs.url }}" -c "select '[1,2,3]'::vector <-> '[4,5,6]'"
```

| Input | Default | What it does |
|---|---|---|
| `version` | `18` | image tag, for example `17` or `18.6.0` |
| `port` | `5432` | host port |
| `username`, `password`, `database` | `postgres` | `POSTGRESQL_USERNAME`, `POSTGRESQL_PASSWORD`, `POSTGRESQL_DATABASE` |
| `extensions` | | created in that database, for example `vector, postgis` |
| `shared-preload-libraries` | | for example `pgaudit,pg_stat_statements` |
| `env` | | any other `POSTGRESQL_*` setting, one `KEY=VALUE` per line |
| `container-name` | `postgresql` | for `docker logs` or `docker exec` later |

Outputs: `url` (`postgresql://…`), `host`, `port`, `container`.

Or as a service container, the way `bitnami/postgresql` used to be used:

```yaml
services:
  postgres:
    image: ghcr.io/intikhab49/lifeboat/postgresql:18
    env:
      POSTGRESQL_PASSWORD: postgres
    ports: ['5432:5432']
```

## Why not just build Bitnami's Dockerfile?

Because it doesn't build PostgreSQL. It downloads a 52 MB prebuilt package from
`downloads.bitnami.com` and unpacks it, and it already has a build secret for pointing that
download at a private server. The day Broadcom closes the public one, every "build it yourself"
fork stops building.

lifeboat compiles all of it from upstream source: PostgreSQL plus the 18 components Bitnami
bundles with it (PostGIS, GDAL, GEOS, PROJ, pgvector, pgAudit, pgBackRest, orafce, PL/Java,
psqlODBC, wal2json, pg_failover_slots, protobuf, nss_wrapper and the rest). Every source archive is
pinned by SHA-256 in the [Dockerfile](images/postgresql/18/debian-12/Dockerfile), and a daily job
follows Bitnami's releases.

## How it's built

<picture>
  <source media="(prefers-color-scheme: dark)" srcset=".github/assets/how-it-is-built-dark.png">
  <img alt="Read the recipe, fill the gaps, build from source, prove it matches" src=".github/assets/how-it-is-built-light.png">
</picture>

Bitnami's PostgreSQL package carries its own build log. The tarball on `downloads.bitnami.com`
has a `BUILD.txt` with the exact sources, versions and `configure` flags, and `pg_config` inside the
package records the build environment (`CC`, `LDFLAGS`, `CPPFLAGS`) that `BUILD.txt` leaves out.
The binaries fill in the rest: the RUNPATH they share, the GCC version in `.comment`, and which
files get stripped or deleted. The full walkthrough, with commands to check every claim, is in
[docs/reverse-engineering.md](docs/reverse-engineering.md).

## The pgvector crash this build fixes

Bitnami compiles pgvector with `-march=native`, the default in pgvector's Makefile that its own
comment says to turn off for portable builds, so their `vector.so` only runs on CPUs like their
build servers. PostgreSQL itself runs on every CPU below. pgvector does not:

| CPU (QEMU model) | PostgreSQL | Bitnami's pgvector | lifeboat's pgvector |
|---|---|---|---|
| amd64 Nehalem, no AVX | runs | **illegal instruction** at `CREATE EXTENSION vector` | runs |
| amd64 Sandy Bridge, AVX without AVX2 | runs | **illegal instruction** | runs |
| amd64 Haswell, AVX2 without AVX-512 | runs | **illegal instruction** building an HNSW index | runs |
| arm64 Cortex-A53, A72 (Raspberry Pi 3, 4 class) | runs | **illegal instruction** | runs |

The Haswell row is the one that matters: in Bitnami's build, building an HNSW index, pgvector's
main index, crashes on a CPU with AVX2 but no AVX-512. AMD CPUs before Zen 4 and Intel Core chips
from the 12th generation on have no AVX-512 either. On a GitHub Actions amd64 runner, Bitnami's
image crashed in this repo's HNSW test while lifeboat's passed. That includes the image you can still pull, `docker.io/bitnami/postgresql:latest`
(built 2026-10-02). When a backend dies this way, the server drops every other connection too:

```
LOG:  client backend (PID 52) was terminated by signal 4: Illegal instruction
LOG:  terminating any other active server processes
LOG:  all server processes terminated; reinitializing
```

Bitnami's last PostgreSQL 17 image, 17.6.0, does the same. In this repo's CI, on an AMD EPYC 7763
(AVX2, no AVX-512), its HNSW index build crashed the server, which restarted in recovery mode.
lifeboat's 17 passed the same test on the same machine.

CI now runs this check on Bitnami's own images in every build. In the run of 2026-10-05, all four
(postgresql 18, its last 17 and 16 builds, 17.6.0 and 16.9.0, and postgresql-repmgr 18) failed
pgvector's HNSW test on every older CPU above, on amd64 and arm64. On the two amd64 runners
without AVX-512, Bitnami's 18 and 16 also crashed on the runner's own CPU. lifeboat's images
passed every row.

Check any copy with `scripts/cpu-compat.sh IMAGE`.

## Proof it's the same image

Every CI run also builds Bitnami's own image from the same `bitnami/containers` commit and
compares the two. Results for 18.6.0 on amd64, from the run of 2026-10-04:

| Check | Result |
|---|---|
| Container config: env, user, entrypoint, command, ports, volumes | identical |
| Behavior, 76 checks: env-var setup, init scripts, all 56 extensions, PostGIS build info, pgvector HNSW, wal2json, restart, arbitrary UID, streaming replication | identical (on a CPU with AVX-512, where Bitnami's pgvector runs) |
| Extensions and their versions | 56 of 56 identical |
| GDAL formats | 121 of 121 identical |
| All 196 binaries and shared libraries: linked libraries and RUNPATH | identical |
| `pg_config` build flags, tool versions, file modes | identical |
| Components Trivy finds | the same 18, plus Abseil |
| Bitnami's Helm chart 18.12.4, primary and read replica | runs, replicates |

Each run's summary on the Actions tab has the full file-level diff and the components Trivy finds
in both images. Every difference that remains is listed below.

17 and 16 go through the same CPU, behavior and Helm chart checks on every build. Their comparison
with Bitnami's last builds of those majors (17.6.0 and 16.9.0) is informational, since lifeboat's
are newer point releases with newer components.

## Differences from Bitnami's image

The ones that change how something is built are marked `Deviation:` in the Dockerfile.

- Everything is compiled from upstream source, nothing is downloaded prebuilt.
- pgvector is built with `OPTFLAGS=""` so it runs on any CPU of its architecture.
- Every source archive is checked against a pinned SHA-256.
- The runtime base is the official `debian:bookworm-slim` instead of `bitnami/minideb`. Perl is
  not installed: minideb pulls it in through `usrmerge`, and Bitnami's package list never asks for
  it.
- License files hold the full upstream texts, including Abseil, which Bitnami's omit.
- The SPDX files scanners read sit at the same paths with the same component names, minus three
  errors in Bitnami's: protobuf's CPE, psqlODBC's license and the missing Abseil entry.
- The startup banner says lifeboat instead of "Welcome to the Bitnami postgresql container".
- postgresql-repmgr: repmgr comes from EnterpriseDB's GitHub release, since `repmgr.org` no longer
  serves the tarball (same file, same SHA-256), and its SPDX entry says GPL-3.0-or-later, as its
  COPYRIGHT file does, where Bitnami's says GPL-3.0-only. Bitnami built its repmgr package with
  `/opt/bitnami/repmgr/lib` in every binary's RUNPATH and in `pg_config`'s flags; that directory
  holds nothing, and lifeboat's binaries are the ones from the postgresql build, so it is left out.

## FAQ

**`bitnami/postgresql:<version>` says "not found" or "manifest unknown". What happened?** Broadcom
deleted the versioned tags in 2025. Point the same setup at
`ghcr.io/intikhab49/lifeboat/postgresql:<version>`, or at `:17` or `:16` for an old 17 or 16 tag
([Tags](#tags)); the environment variables and volume paths don't change.

**My Bitnami PostgreSQL chart is stuck in `ImagePullBackOff`.** Same cause. Override
`image.registry`, `image.repository` and `image.tag` as shown in [Use it](#use-it), plus
`global.security.allowInsecureImages=true`.

**pgvector crashes with "Illegal instruction" or "signal 4".** That is the `-march=native` build
described [above](#the-pgvector-crash-this-build-fixes). This image builds it portably.

**Can I keep using `bitnamilegacy/postgresql`?** It works, but it has been frozen since August
2025, so nothing fixed since then has reached it.

**Is this Bitnami's image?** No. It runs Bitnami's Apache-2.0 container scripts, unmodified, on
top of components built here. Not affiliated with Broadcom or Bitnami.

**How do I verify an image?** Every tag carries SLSA build provenance and an SBOM:
`gh attestation verify oci://ghcr.io/intikhab49/lifeboat/postgresql:18.6.0 --owner intikhab49`

**Does it get updates?** It is rebuilt every week, which picks up Debian security fixes. When
Bitnami ships a new revision, a daily job opens a pull request with the new versions, which must
pass the CPU and behavior checks.

**What about Redis, MongoDB, Kafka and the others?** PostgreSQL and postgresql-repmgr are first.
The same method works for any image whose package ships a `BUILD.txt`. [Ask for one](https://github.com/intikhab49/lifeboat/issues/new?template=image-request.yml).

## License

Build files and tests: Apache-2.0 ([LICENSE](LICENSE)). The vendored Bitnami scripts are
Apache-2.0, © Broadcom. Each component in the image keeps its own license, see [NOTICE](NOTICE).
