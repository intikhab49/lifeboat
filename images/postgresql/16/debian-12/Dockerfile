# PostgreSQL 16 with the same layout as Bitnami's postgresql image (paths, scripts, environment
# variables, extensions), built entirely from upstream source. Nothing comes from
# downloads.bitnami.com.
#
# Bitnami stopped publishing PostgreSQL 16 in 2025. This builds the current 16 point release with
# the scripts and the recipe of its last public release, postgresql-16.9.0-9 (16.9.0-debian-12-r13); see UPSTREAM.
# The shared components match the 18 image, and docs/reverse-engineering.md walks through the
# recipe. Every deliberate difference from it is marked "Deviation:".
#
# Build from the repository root:
#   docker build -f images/postgresql/16/debian-12/Dockerfile -t lifeboat/postgresql:16.15.0 .

ARG POSTGRESQL_VERSION=16.15
ARG POSTGRESQL_SHA256=c1575341fa7bd40f5274ea465b34390f4dc64cdd0770af327005caaeb9f6b7ed
ARG GEOS_VERSION=3.15.0
ARG GEOS_SHA256=d5e5192a686d065eaed082de14dd26244c5c8e02bff16b2c6cce3265f648e00e
ARG PROJ_VERSION=6.3.2
ARG PROJ_SHA256=cb776a70f40c35579ae4ba04fb4a388c1d1ce025a1df6171350dc19f25b80311
ARG GDAL_VERSION=3.13.3
ARG GDAL_SHA256=5e0c388d83da2d686cc00a40272882432cdb54edff43d4af173e532844a0a0ea
ARG JSONC_VERSION=0.16
ARG JSONC_DATE=20220414
ARG JSONC_SHA256=3ecaeedffd99a60b1262819f9e60d7d983844073abc74e495cb822b251904185
ARG ORAFCE_VERSION=4.16.13
ARG ORAFCE_SHA256=a127581dc9f3eda314f224c045a16e103ebd4137156eb636b0f32c42ca28aa96
ARG PLJAVA_VERSION=1.6.10
ARG PLJAVA_SHA256=443ac3add92351cb2b46ed17dd80b0f2cad5bc6c31eef8e7be7ef52937365085
ARG UNIXODBC_VERSION=2.3.14
ARG UNIXODBC_SHA256=4e2814de3e01fc30b0b9f75e83bb5aba91ab0384ee951286504bb70205524771
ARG PSQLODBC_VERSION=18.0.4
ARG PSQLODBC_SHA256=af12354a5960846f5578e168b456cde3c21a11c4788277663bf9266b1de3adda
ARG PROTOBUF_VERSION=36.2
ARG PROTOBUF_SHA256=3d9642a662d10e68ebae5e53f14dcce5105684212d5078f8e0d47d1ab3ae6b64
ARG ABSEIL_VERSION=20250512.1
ARG ABSEIL_SHA256=9b7a064305e9fd94d124ffa6cc358592eb42b5da588fb4e07d09254aa40086db
ARG PROTOBUFC_VERSION=1.5.2
ARG PROTOBUFC_SHA256=e2c86271873a79c92b58fef7ebf8de1aa0df4738347a8bd5d4e65a80a16d0d24
ARG POSTGIS_VERSION=3.6.4
ARG POSTGIS_SHA256=ed8dc6679f1e06f7b113592b04cde2a7e00f1b1e681294c8ca2204058990cec6
ARG PGAUDIT_VERSION=16.1
ARG PGAUDIT_SHA256=3bae908ab70ba0c6f51224009dbcfff1a97bd6104c6273297a64292e1b921fee
ARG PGBACKREST_VERSION=2.59.2
ARG PGBACKREST_SHA256=dbdc5edb5161c57bd3ae61e416b1cd763205ad6ce41d9356114432a0cc0ce577
ARG PGVECTOR_VERSION=0.8.7
ARG PGVECTOR_SHA256=cac0b10c360f05b2d521200105ba3697e773d4cd3731f5a915a7e37ebe0bea85
ARG PGFAILOVERSLOTS_VERSION=1.2.1
ARG PGFAILOVERSLOTS_SHA256=7d6cb5792e91eb147d2ab10a6c45dc27aee59e7f20335640abbc3719fe37ebf3
ARG WAL2JSON_VERSION=2.6
ARG WAL2JSON_SHA256=18b4bdec28c74a8fc98a11c72de38378a760327ef8e5e42e975b0029eb96ba0d
ARG PGAUTOFAILOVER_VERSION=2.2
ARG PGAUTOFAILOVER_SHA256=0f4018564e620592fcfb43d52ea2bc3ccba33bd824352fa9c7e55eb2ba0a4f6c
ARG NSSWRAPPER_VERSION=1.1.16
ARG NSSWRAPPER_SHA256=dc79ab072779be4403b45b60cd044dd13780d4bb9675d27abf1932ada7c8a88d
# Revision of Bitnami's image whose scripts are vendored next to this file (see UPSTREAM).
ARG IMAGE_REVISION=13
ARG BUILD_JOBS=4

FROM debian:bookworm AS build-base
SHELL ["/bin/bash", "-o", "errexit", "-o", "nounset", "-o", "pipefail", "-c"]
RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      autoconf automake bison bzip2 ca-certificates cmake curl file flex g++ gcc libbz2-dev \
      libedit-dev libicu-dev libldap2-dev liblz4-dev libpcre3-dev libreadline-dev libsqlite3-dev \
      libssl-dev libtool libxml2-dev libxml2-utils libxslt1-dev libyaml-dev libzstd-dev make meson \
      ninja-build perl pkg-config python3 sqlite3 uuid-dev xsltproc zlib1g-dev \
 && rm -rf /var/lib/apt/lists/*
COPY --chmod=0755 build/fetch build/collect-licenses /usr/local/bin/
# Bitnami's build environment, recovered from the LDFLAGS and CPPFLAGS that its pg_config
# records: every component links against the three /opt/bitnami prefixes and finds them at run
# time through RUNPATH, so the image needs no LD_LIBRARY_PATH.
ENV CC=gcc \
    CPPFLAGS="-I/opt/bitnami/protobuf/include -I/opt/bitnami/common/include -I/opt/bitnami/postgresql/include" \
    LDFLAGS="-Wl,-rpath=/opt/bitnami/protobuf/lib -L/opt/bitnami/protobuf/lib -Wl,-rpath=/opt/bitnami/common/lib -L/opt/bitnami/common/lib -Wl,-rpath=/opt/bitnami/postgresql/lib -L/opt/bitnami/postgresql/lib" \
    PKG_CONFIG_PATH="/opt/bitnami/protobuf/lib/pkgconfig:/opt/bitnami/common/lib/pkgconfig:/opt/bitnami/postgresql/lib/pkgconfig" \
    PATH="/opt/bitnami/postgresql/bin:/opt/bitnami/common/bin:/opt/bitnami/protobuf/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

FROM build-base AS postgresql
ARG POSTGRESQL_VERSION POSTGRESQL_SHA256 BUILD_JOBS
# Deviation: the official release tarball, whose checksum postgresql.org publishes, instead of a
# GitHub archive of the git tag. Same code; the tarball also carries the generated parser files.
# pg_config records the build environment, and Bitnami's has no PKG_CONFIG_PATH in it.
RUN fetch "https://ftp.postgresql.org/pub/source/v${POSTGRESQL_VERSION}/postgresql-${POSTGRESQL_VERSION}.tar.bz2" "$POSTGRESQL_SHA256" /src \
 && cd /src \
 && env -u PKG_CONFIG_PATH ./configure --prefix=/opt/bitnami/postgresql --with-libedit-preferred --with-openssl --with-libxml \
      --with-libxslt --with-readline --with-icu --with-uuid=e2fs --with-ldap CFLAGS=-O2 CXXFLAGS=-O2 --with-lz4 \
 && make world-bin --jobs="$BUILD_JOBS" \
 && make install-world-bin \
 && collect-licenses /src "/opt/bitnami/postgresql/licenses/postgresql-${POSTGRESQL_VERSION}.0.txt"

FROM build-base AS geos
ARG GEOS_VERSION GEOS_SHA256 BUILD_JOBS
RUN fetch "https://download.osgeo.org/geos/geos-${GEOS_VERSION}.tar.bz2" "$GEOS_SHA256" /src \
 && cmake -S /src -B /build -DCMAKE_INSTALL_PREFIX=/opt/bitnami/postgresql -DCMAKE_INSTALL_LIBDIR=lib \
      -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF \
 && make -C /build --jobs="$BUILD_JOBS" \
 && make -C /build install \
 && collect-licenses /src "/opt/bitnami/postgresql/licenses/geos-${GEOS_VERSION}.txt"

FROM build-base AS proj
ARG PROJ_VERSION PROJ_SHA256 BUILD_JOBS
# Deviation: the release tarball ships a generated configure script, so autogen.sh is not needed.
# Bitnami's PROJ was linked without the global flags: its programs carry only libtool's
# RUNPATH=/opt/bitnami/postgresql/lib and libproj.so none.
RUN fetch "https://download.osgeo.org/proj/proj-${PROJ_VERSION}.tar.gz" "$PROJ_SHA256" /src \
 && cd /src \
 && env -u LDFLAGS -u CPPFLAGS ./configure --prefix=/opt/bitnami/postgresql \
 && make --jobs="$BUILD_JOBS" \
 && make install \
 && collect-licenses /src "/opt/bitnami/postgresql/licenses/proj-${PROJ_VERSION}.txt"

FROM build-base AS json-c
ARG JSONC_VERSION JSONC_DATE JSONC_SHA256 BUILD_JOBS
RUN fetch "https://github.com/json-c/json-c/archive/refs/tags/json-c-${JSONC_VERSION}-${JSONC_DATE}.tar.gz" "$JSONC_SHA256" /src \
 && cmake -S /src -B /build -DCMAKE_INSTALL_PREFIX:PATH=/opt/bitnami/postgresql -DCMAKE_INSTALL_LIBDIR=lib \
      -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_FLAGS=-Wno-error \
 && make -C /build --jobs="$BUILD_JOBS" \
 && make -C /build install \
 && collect-licenses /src "/opt/bitnami/postgresql/licenses/json-c-${JSONC_VERSION}.${JSONC_DATE}.txt"

FROM build-base AS gdal
ARG GDAL_VERSION GDAL_SHA256 BUILD_JOBS
COPY --from=geos /opt/bitnami /opt/bitnami
COPY --from=proj /opt/bitnami /opt/bitnami
RUN fetch "https://github.com/OSGeo/gdal/releases/download/v${GDAL_VERSION}/gdal-${GDAL_VERSION}.tar.gz" "$GDAL_SHA256" /src \
 && cmake -S /src -B /build -DCMAKE_INSTALL_PREFIX:PATH=/opt/bitnami/postgresql -DCMAKE_INSTALL_LIBDIR=lib \
      -DCMAKE_BUILD_TYPE=Release -DBUILD_PYTHON_BINDINGS:BOOL=OFF -DGDAL_USE_EXTERNAL_LIBS:BOOL=OFF \
      -DGDAL_USE_PROJ=ON -DGDAL_USE_GEOS=ON -DBUILD_TESTING=OFF \
 && make -C /build --jobs="$BUILD_JOBS" \
 && cmake --build /build --target install \
 && collect-licenses /src "/opt/bitnami/postgresql/licenses/gdal-${GDAL_VERSION}.txt"

FROM build-base AS unixodbc
ARG UNIXODBC_VERSION UNIXODBC_SHA256 BUILD_JOBS
RUN fetch "https://www.unixodbc.org/unixODBC-${UNIXODBC_VERSION}.tar.gz" "$UNIXODBC_SHA256" /src \
 && cd /src \
 && ./configure --prefix=/opt/bitnami/common \
 && make --jobs="$BUILD_JOBS" \
 && make install \
 && collect-licenses /src "/opt/bitnami/common/licenses/unixodbc-${UNIXODBC_VERSION}.txt"

FROM build-base AS protobuf
ARG PROTOBUF_VERSION PROTOBUF_SHA256 ABSEIL_VERSION ABSEIL_SHA256 BUILD_JOBS
# Deviation: Abseil is compiled into protoc, so its Apache-2.0 license ships alongside it.
RUN fetch "https://github.com/protocolbuffers/protobuf/releases/download/v${PROTOBUF_VERSION}/protobuf-${PROTOBUF_VERSION}.tar.gz" "$PROTOBUF_SHA256" /src \
 && fetch "https://github.com/abseil/abseil-cpp/releases/download/${ABSEIL_VERSION}/abseil-cpp-${ABSEIL_VERSION}.tar.gz" "$ABSEIL_SHA256" /src/third_party/abseil-cpp-src \
 && cmake -S /src -B /build -DCMAKE_INSTALL_PREFIX=/opt/bitnami/protobuf -DCMAKE_INSTALL_LIBDIR=lib \
      -DCMAKE_BUILD_TYPE=Release -DCMAKE_POSITION_INDEPENDENT_CODE=ON -Dprotobuf_BUILD_TESTS=OFF \
      -DBUILD_SHARED_LIBS=OFF -Dprotobuf_BUILD_SHARED_LIBS=OFF \
      -DFETCHCONTENT_SOURCE_DIR_ABSL=/src/third_party/abseil-cpp-src \
 && make -C /build --jobs="$BUILD_JOBS" \
 && make -C /build install \
 && collect-licenses /src "/opt/bitnami/protobuf/licenses/protobuf-${PROTOBUF_VERSION}.0.txt" \
 && collect-licenses /src/third_party/abseil-cpp-src "/opt/bitnami/protobuf/licenses/abseil-cpp-${ABSEIL_VERSION}.txt"

FROM build-base AS protobuf-c
ARG PROTOBUFC_VERSION PROTOBUFC_SHA256 BUILD_JOBS
COPY --from=protobuf /opt/bitnami /opt/bitnami
# BUILD.txt lists no patch, but protobuf-c 1.5.2 does not compile against protobuf 36.2 without
# one (FieldDescriptor::label() is gone); see the header of the patch file. Like PROJ, Bitnami's
# protobuf-c was linked without the global flags (no RUNPATH).
COPY images/postgresql/16/debian-12/patches/protobuf-c-1.5.2-protobuf34.patch /tmp/
RUN apt-get -o Acquire::Retries=5 update \
 && DEBIAN_FRONTEND=noninteractive apt-get -o Acquire::Retries=5 install -y --no-install-recommends patch \
 && rm -rf /var/lib/apt/lists/*
RUN fetch "https://github.com/protobuf-c/protobuf-c/releases/download/v${PROTOBUFC_VERSION}/protobuf-c-${PROTOBUFC_VERSION}.tar.gz" "$PROTOBUFC_SHA256" /src \
 && patch -d /src -p1 < /tmp/protobuf-c-1.5.2-protobuf34.patch \
 && cd /src \
 && env -u LDFLAGS -u CPPFLAGS ./configure --prefix=/opt/bitnami/common \
 && make --jobs="$BUILD_JOBS" \
 && make install \
 && collect-licenses /src "/opt/bitnami/common/licenses/protobuf-c-${PROTOBUFC_VERSION}.txt"

FROM build-base AS postgis
ARG POSTGIS_VERSION POSTGIS_SHA256 BUILD_JOBS
COPY --from=postgresql /opt/bitnami /opt/bitnami
COPY --from=gdal /opt/bitnami /opt/bitnami
COPY --from=json-c /opt/bitnami /opt/bitnami
COPY --from=protobuf-c /opt/bitnami /opt/bitnami
RUN fetch "https://download.osgeo.org/postgis/source/postgis-${POSTGIS_VERSION}.tar.gz" "$POSTGIS_SHA256" /src \
 && cd /src \
 && ./configure --prefix=/opt/bitnami/postgresql --with-pgconfig=/opt/bitnami/postgresql/bin/pg_config \
      --with-geosconfig=/opt/bitnami/postgresql/bin/geos-config --with-projdir=/opt/bitnami/postgresql \
      --with-gdalconfig=/opt/bitnami/postgresql/bin/gdal-config --with-jsondir=/opt/bitnami/postgresql \
      --with-protobufdir=/opt/bitnami/protobuf \
 && make --jobs="$BUILD_JOBS" \
 && make install \
 && collect-licenses /src "/opt/bitnami/postgresql/licenses/postgis-${POSTGIS_VERSION}.txt"

FROM build-base AS pljava
ARG PLJAVA_VERSION PLJAVA_SHA256
RUN apt-get -o Acquire::Retries=5 update \
 && DEBIAN_FRONTEND=noninteractive apt-get -o Acquire::Retries=5 install -y --no-install-recommends \
      maven openjdk-17-jdk-headless \
 && rm -rf /var/lib/apt/lists/*
COPY --from=postgresql /opt/bitnami /opt/bitnami
RUN fetch "https://github.com/tada/pljava/archive/refs/tags/V${PLJAVA_VERSION//./_}.tar.gz" "$PLJAVA_SHA256" /src \
 && cd /src \
 && mvn --batch-mode --quiet clean package \
 && java -jar pljava-packaging/target/pljava-pg*.jar \
 && collect-licenses /src "/opt/bitnami/postgresql/licenses/pljava-${PLJAVA_VERSION}.txt"

FROM build-base AS psqlodbc
ARG PSQLODBC_VERSION PSQLODBC_SHA256 BUILD_JOBS
COPY --from=postgresql /opt/bitnami /opt/bitnami
COPY --from=unixodbc /opt/bitnami /opt/bitnami
RUN IFS=. read -r major minor patch <<<"$PSQLODBC_VERSION" \
 && fetch "https://github.com/postgresql-interfaces/psqlodbc/archive/refs/tags/$(printf 'REL-%02d_%02d_%04d' "$major" "$minor" "$patch").tar.gz" "$PSQLODBC_SHA256" /src \
 && cd /src \
 && autoreconf --install \
 && ./configure --prefix=/opt/bitnami/postgresql --with-libpq=/opt/bitnami/postgresql --with-unixodbc=/opt/bitnami/common \
 && make --jobs="$BUILD_JOBS" \
 && make install \
 && collect-licenses /src "/opt/bitnami/postgresql/licenses/psqlodbc-${PSQLODBC_VERSION}.txt"

FROM build-base AS pgbackrest
ARG PGBACKREST_VERSION PGBACKREST_SHA256 BUILD_JOBS
COPY --from=postgresql /opt/bitnami /opt/bitnami
RUN fetch "https://github.com/pgbackrest/pgbackrest/releases/download/release/${PGBACKREST_VERSION}/pgbackrest-${PGBACKREST_VERSION}.tar.gz" "$PGBACKREST_SHA256" /src \
 && meson setup --prefix /opt/bitnami/postgresql --pkg-config-path /opt/bitnami/postgresql/lib/pkgconfig /build /src \
 && ninja -C /build -j "$BUILD_JOBS" \
 && ninja -C /build install \
 && collect-licenses /src "/opt/bitnami/postgresql/licenses/pgbackrest-${PGBACKREST_VERSION}.txt"

FROM build-base AS extensions
ARG ORAFCE_VERSION ORAFCE_SHA256 PGAUDIT_VERSION PGAUDIT_SHA256 PGVECTOR_VERSION PGVECTOR_SHA256 \
    PGFAILOVERSLOTS_VERSION PGFAILOVERSLOTS_SHA256 WAL2JSON_VERSION WAL2JSON_SHA256 PGAUTOFAILOVER_VERSION \
    PGAUTOFAILOVER_SHA256 BUILD_JOBS
COPY --from=postgresql /opt/bitnami /opt/bitnami
RUN fetch "https://github.com/orafce/orafce/archive/refs/tags/VERSION_${ORAFCE_VERSION//./_}.tar.gz" "$ORAFCE_SHA256" /src/orafce \
 && make -C /src/orafce --jobs="$BUILD_JOBS" \
 && make -C /src/orafce install \
 && collect-licenses /src/orafce "/opt/bitnami/postgresql/licenses/orafce-${ORAFCE_VERSION}.txt"
RUN fetch "https://github.com/pgaudit/pgaudit/archive/refs/tags/${PGAUDIT_VERSION}.tar.gz" "$PGAUDIT_SHA256" /src/pgaudit \
 && make -C /src/pgaudit USE_PGXS=1 --jobs="$BUILD_JOBS" \
 && make -C /src/pgaudit USE_PGXS=1 install \
 && collect-licenses /src/pgaudit "/opt/bitnami/postgresql/licenses/pgaudit-${PGAUDIT_VERSION}.0.txt"
# Deviation: pgvector's Makefile defaults to OPTFLAGS=-march=native and Bitnami's recipe keeps it,
# so its vector.so only runs on CPUs like their build host and dies with SIGILL on CPUs without
# AVX (see scripts/cpu-compat.sh). OPTFLAGS="" is the portable build pgvector documents.
RUN fetch "https://github.com/pgvector/pgvector/archive/refs/tags/v${PGVECTOR_VERSION}.tar.gz" "$PGVECTOR_SHA256" /src/pgvector \
 && make -C /src/pgvector USE_PGXS=1 OPTFLAGS="" --jobs="$BUILD_JOBS" \
 && make -C /src/pgvector USE_PGXS=1 OPTFLAGS="" install \
 && collect-licenses /src/pgvector "/opt/bitnami/postgresql/licenses/pgvector-${PGVECTOR_VERSION}.txt"
RUN fetch "https://github.com/EnterpriseDB/pg_failover_slots/archive/refs/tags/v${PGFAILOVERSLOTS_VERSION}.tar.gz" "$PGFAILOVERSLOTS_SHA256" /src/pg-failover-slots \
 && make -C /src/pg-failover-slots USE_PGXS=1 --jobs="$BUILD_JOBS" \
 && make -C /src/pg-failover-slots USE_PGXS=1 install \
 && collect-licenses /src/pg-failover-slots "/opt/bitnami/postgresql/licenses/pg-failover-slots-${PGFAILOVERSLOTS_VERSION}.txt"
RUN fetch "https://github.com/eulerto/wal2json/archive/refs/tags/wal2json_${WAL2JSON_VERSION//./_}.tar.gz" "$WAL2JSON_SHA256" /src/wal2json \
 && make -C /src/wal2json USE_PGXS=1 --jobs="$BUILD_JOBS" \
 && make -C /src/wal2json USE_PGXS=1 install \
 && collect-licenses /src/wal2json "/opt/bitnami/postgresql/licenses/wal2json-${WAL2JSON_VERSION}.0.txt"
# Bitnami's 16 package, unlike 17 and 18, bundles pg_auto_failover; pg_autoctl's watch view needs ncurses.
RUN apt-get -o Acquire::Retries=5 update \
 && DEBIAN_FRONTEND=noninteractive apt-get -o Acquire::Retries=5 install -y --no-install-recommends \
      libkrb5-dev libncurses-dev \
 && rm -rf /var/lib/apt/lists/*
RUN fetch "https://github.com/citusdata/pg_auto_failover/archive/refs/tags/v${PGAUTOFAILOVER_VERSION}.tar.gz" "$PGAUTOFAILOVER_SHA256" /src/pg-auto-failover \
 && make -C /src/pg-auto-failover --jobs="$BUILD_JOBS" \
 && make -C /src/pg-auto-failover install \
 && collect-licenses /src/pg-auto-failover "/opt/bitnami/postgresql/licenses/pgautofailover-${PGAUTOFAILOVER_VERSION}.0.txt"

FROM build-base AS nss-wrapper
ARG NSSWRAPPER_VERSION NSSWRAPPER_SHA256 BUILD_JOBS
# nss_wrapper is a separate Bitnami package; its library's RUNPATH names only its own prefix.
RUN fetch "https://ftp.samba.org/pub/cwrap/nss_wrapper-${NSSWRAPPER_VERSION}.tar.gz" "$NSSWRAPPER_SHA256" /src \
 && LDFLAGS="-Wl,-rpath=/opt/bitnami/common/lib -L/opt/bitnami/common/lib" CPPFLAGS="-I/opt/bitnami/common/include" \
    cmake -S /src -B /build -DCMAKE_INSTALL_PREFIX=/opt/bitnami/common -DCMAKE_INSTALL_LIBDIR=lib \
      -DCMAKE_BUILD_TYPE=Release \
 && make -C /build --jobs="$BUILD_JOBS" \
 && make -C /build install \
 && collect-licenses /src "/opt/bitnami/common/licenses/nss-wrapper-${NSSWRAPPER_VERSION}.txt"

FROM build-base AS assemble
ARG TARGETARCH POSTGRESQL_VERSION GEOS_VERSION PROJ_VERSION GDAL_VERSION JSONC_VERSION JSONC_DATE ORAFCE_VERSION \
    PLJAVA_VERSION UNIXODBC_VERSION PSQLODBC_VERSION PROTOBUF_VERSION ABSEIL_VERSION PROTOBUFC_VERSION \
    POSTGIS_VERSION PGAUDIT_VERSION PGBACKREST_VERSION PGVECTOR_VERSION PGFAILOVERSLOTS_VERSION \
    WAL2JSON_VERSION NSSWRAPPER_VERSION PGAUTOFAILOVER_VERSION
COPY --from=postgresql /opt/bitnami /opt/bitnami
COPY --from=gdal /opt/bitnami /opt/bitnami
COPY --from=json-c /opt/bitnami /opt/bitnami
COPY --from=unixodbc /opt/bitnami /opt/bitnami
COPY --from=protobuf-c /opt/bitnami /opt/bitnami
COPY --from=postgis /opt/bitnami /opt/bitnami
COPY --from=pljava /opt/bitnami /opt/bitnami
COPY --from=psqlodbc /opt/bitnami /opt/bitnami
COPY --from=pgbackrest /opt/bitnami /opt/bitnami
COPY --from=extensions /opt/bitnami /opt/bitnami
COPY --from=nss-wrapper /opt/bitnami /opt/bitnami
# Packaged like Bitnami's component: no libtool archives, no static libraries besides
# PostgreSQL's own libpg*.a, no man pages or docs, executables writable by their owner, every
# ELF file stripped.
RUN find /opt/bitnami \( -name '*.la' -o \( -name '*.a' ! -name 'libpg*.a' \) \) -delete \
 && rm -rf /opt/bitnami/*/share/man /opt/bitnami/*/share/doc \
 && { rmdir --ignore-fail-on-non-empty /opt/bitnami/*/share 2>/dev/null || true; } \
 && find /opt/bitnami -type f -perm -u+x ! -perm -u+w -exec chmod u+w {} + \
 && find /opt/bitnami -type f -exec sh -c 'for f; do if file -b "$f" | grep -q "^ELF"; then strip "$f"; fi; done' sh {} + \
 && printf 'postgis-%s,GPL-2.0-or-later,https://download.osgeo.org/postgis/source/postgis-%s.tar.gz\n' \
      "$POSTGIS_VERSION" "$POSTGIS_VERSION" > /opt/bitnami/postgresql/licenses/gpl-source-links.txt
# The SPDX documents Bitnami ships, rewritten for what was built here, so scanners that read them
# (Trivy, for one) still see every bundled component. Deviation: Bitnami's tag protobuf with the
# Go library's CPE (golang:protobuf) and psqlODBC as LGPL-3.0-only; its sources say
# LGPL-2.0-or-later. Abseil, compiled into protoc, is listed too.
COPY --chmod=0755 build/write-spdx /usr/local/bin/
RUN psqlodbc_tag="$(IFS=. read -r a b c <<<"$PSQLODBC_VERSION"; printf 'REL-%02d_%02d_%04d' "$a" "$b" "$c")" \
 && printf '%s\t%s\t%s\t%s\t%s\n' \
      postgresql "${POSTGRESQL_VERSION}.0" PostgreSQL postgresql:postgresql "https://ftp.postgresql.org/pub/source/v${POSTGRESQL_VERSION}/postgresql-${POSTGRESQL_VERSION}.tar.bz2" \
      geos "$GEOS_VERSION" LGPL-2.1-only libgeos:geos "https://download.osgeo.org/geos/geos-${GEOS_VERSION}.tar.bz2" \
      proj "$PROJ_VERSION" MIT proj:proj "https://download.osgeo.org/proj/proj-${PROJ_VERSION}.tar.gz" \
      gdal "$GDAL_VERSION" MIT osgeo:gdal "https://github.com/OSGeo/gdal/releases/download/v${GDAL_VERSION}/gdal-${GDAL_VERSION}.tar.gz" \
      json-c "${JSONC_VERSION}.${JSONC_DATE}" MIT json-c_project:json-c "https://github.com/json-c/json-c/archive/refs/tags/json-c-${JSONC_VERSION}-${JSONC_DATE}.tar.gz" \
      orafce "$ORAFCE_VERSION" 0BSD orafce:orafce "https://github.com/orafce/orafce/archive/refs/tags/VERSION_${ORAFCE_VERSION//./_}.tar.gz" \
      pljava "$PLJAVA_VERSION" BSD-3-Clause - "https://github.com/tada/pljava/archive/refs/tags/V${PLJAVA_VERSION//./_}.tar.gz" \
      unixodbc "$UNIXODBC_VERSION" LGPL-2.1-only unixodbc:unixodbc "https://www.unixodbc.org/unixODBC-${UNIXODBC_VERSION}.tar.gz" \
      psqlodbc "$PSQLODBC_VERSION" LGPL-2.0-or-later postgresql:psqlodbc "https://github.com/postgresql-interfaces/psqlodbc/archive/refs/tags/${psqlodbc_tag}.tar.gz" \
      protobuf "${PROTOBUF_VERSION}.0" BSD-3-Clause google:protobuf-cpp "https://github.com/protocolbuffers/protobuf/releases/download/v${PROTOBUF_VERSION}/protobuf-${PROTOBUF_VERSION}.tar.gz" \
      abseil-cpp "$ABSEIL_VERSION" Apache-2.0 - "https://github.com/abseil/abseil-cpp/releases/download/${ABSEIL_VERSION}/abseil-cpp-${ABSEIL_VERSION}.tar.gz" \
      protobuf-c "$PROTOBUFC_VERSION" BSD-2-Clause protobuf-c:protobuf-c "https://github.com/protobuf-c/protobuf-c/releases/download/v${PROTOBUFC_VERSION}/protobuf-c-${PROTOBUFC_VERSION}.tar.gz" \
      postgis "$POSTGIS_VERSION" GPL-2.0-or-later postgis:postgis "https://download.osgeo.org/postgis/source/postgis-${POSTGIS_VERSION}.tar.gz" \
      pgaudit "${PGAUDIT_VERSION}.0" PostgreSQL - "https://github.com/pgaudit/pgaudit/archive/refs/tags/${PGAUDIT_VERSION}.tar.gz" \
      pgbackrest "$PGBACKREST_VERSION" MIT pgbackrest:pgbackrest "https://github.com/pgbackrest/pgbackrest/releases/download/release/${PGBACKREST_VERSION}/pgbackrest-${PGBACKREST_VERSION}.tar.gz" \
      pgvector "$PGVECTOR_VERSION" PostgreSQL pgvector:pgvector "https://github.com/pgvector/pgvector/archive/refs/tags/v${PGVECTOR_VERSION}.tar.gz" \
      pg-failover-slots "$PGFAILOVERSLOTS_VERSION" PostgreSQL pg-failover-slots:pg-failover-slots "https://github.com/EnterpriseDB/pg_failover_slots/archive/refs/tags/v${PGFAILOVERSLOTS_VERSION}.tar.gz" \
      wal2json "${WAL2JSON_VERSION}.0" BSD-3-Clause wal2json:wal2json "https://github.com/eulerto/wal2json/archive/refs/tags/wal2json_${WAL2JSON_VERSION//./_}.tar.gz" \
      pgautofailover "${PGAUTOFAILOVER_VERSION}.0" PostgreSQL - "https://github.com/citusdata/pg_auto_failover/archive/refs/tags/v${PGAUTOFAILOVER_VERSION}.tar.gz" \
    | write-spdx /opt/bitnami/postgresql/.spdx-postgresql.spdx "PostgreSQL ${POSTGRESQL_VERSION}.0" "$TARGETARCH" \
 && ln -s /opt/bitnami/postgresql/.spdx-postgresql.spdx /opt/bitnami/postgresql/.spdx-postgresql.json \
 && printf '%s\t%s\t%s\t%s\t%s\n' \
      nss-wrapper "$NSSWRAPPER_VERSION" BSD-3-Clause nss-wrapper:nss-wrapper "https://ftp.samba.org/pub/cwrap/nss_wrapper-${NSSWRAPPER_VERSION}.tar.gz" \
    | write-spdx /opt/bitnami/common/.spdx-nss-wrapper.spdx "NSS Wrapper ${NSSWRAPPER_VERSION}" "$TARGETARCH" \
 && ln -s /opt/bitnami/common/.spdx-nss-wrapper.spdx /opt/bitnami/common/.spdx-nss-wrapper.json

# Deviation: the official Debian 12 image instead of bitnami/minideb, so the base does not come
# from Broadcom either. Bitnami's prebuildfs supplies the same install_packages helper.
FROM debian:bookworm-slim
ARG TARGETARCH
ARG POSTGRESQL_VERSION IMAGE_REVISION

LABEL org.opencontainers.image.base.name="docker.io/library/debian:bookworm-slim" \
      org.opencontainers.image.description="PostgreSQL built from upstream source with the layout of Bitnami's postgresql image. Not affiliated with Broadcom or Bitnami." \
      org.opencontainers.image.licenses="Apache-2.0 AND PostgreSQL AND GPL-2.0-or-later" \
      org.opencontainers.image.source="https://github.com/intikhab49/lifeboat" \
      org.opencontainers.image.title="postgresql" \
      org.opencontainers.image.version="${POSTGRESQL_VERSION}.0"

ENV HOME="/" \
    OS_ARCH="${TARGETARCH:-amd64}" \
    OS_FLAVOUR="debian-12" \
    OS_NAME="linux"

COPY images/postgresql/16/debian-12/prebuildfs /
SHELL ["/bin/bash", "-o", "errexit", "-o", "nounset", "-o", "pipefail", "-c"]
# Install required system packages and dependencies
RUN install_packages ca-certificates curl libbsd0 libbz2-1.0 libedit2 libffi8 libgcc-s1 libgmp10 libgnutls30 libhogweed6 libicu72 libidn2-0 libldap-2.5-0 liblz4-1 liblzma5 libmd0 libncurses6 libnettle8 libp11-kit0 libpcre3 libreadline8 libsasl2-2 libsqlite3-0 libssl3 libstdc++6 libtasn1-6 libtinfo6 libunistring2 libuuid1 libxml2 libxslt1.1 libzstd1 locales procps zlib1g
COPY --from=assemble /opt/bitnami /opt/bitnami
RUN apt-get update && apt-get upgrade -y && \
    apt-get clean && rm -rf /var/lib/apt/lists /var/cache/apt/archives
RUN chmod g+rwX /opt/bitnami
RUN find / -perm /6000 -type f -exec chmod a-s {} \; || true
RUN update-locale LANG=C.UTF-8 LC_MESSAGES=POSIX && \
    DEBIAN_FRONTEND=noninteractive dpkg-reconfigure locales && \
    echo 'en_US.UTF-8 UTF-8' >> /etc/locale.gen
RUN /opt/bitnami/scripts/locales/generate-locales.sh
RUN uninstall_packages curl

COPY images/postgresql/16/debian-12/rootfs /
# Deviation: the startup banner names this image instead of claiming to be Bitnami's.
RUN sed -i 's|Welcome to the Bitnami ${BITNAMI_APP_NAME} container|lifeboat ${BITNAMI_APP_NAME}, built from upstream source (not affiliated with Broadcom or Bitnami)|' \
      /opt/bitnami/scripts/libbitnami.sh \
 && /opt/bitnami/scripts/postgresql/postunpack.sh
ENV APP_VERSION="${POSTGRESQL_VERSION}.0" \
    BITNAMI_APP_NAME="postgresql" \
    IMAGE_REVISION="${IMAGE_REVISION}" \
    LANG="en_US.UTF-8" \
    LANGUAGE="en_US:en" \
    NSS_WRAPPER_LIB="/opt/bitnami/common/lib/libnss_wrapper.so" \
    PATH="/opt/bitnami/common/bin:/opt/bitnami/postgresql/bin:$PATH"

VOLUME [ "/bitnami/postgresql", "/docker-entrypoint-initdb.d", "/docker-entrypoint-preinitdb.d" ]

EXPOSE 5432

USER 1001
ENTRYPOINT [ "/opt/bitnami/scripts/postgresql/entrypoint.sh" ]
CMD [ "/opt/bitnami/scripts/postgresql/run.sh" ]
