# syntax=docker/dockerfile:1

ARG DISTRO=debian
ARG DISTRO_VER=stable
ARG PG_MAJOR=latest
FROM postgres:${PG_MAJOR} AS updated-image
RUN set -eux; \
    apt-get update; \
    apt-get dist-upgrade -y --autoremove;

FROM scratch AS runtime-image
# Needed for source shell functions into this Dockerfile
SHELL ["/bin/bash", "-c"]
ARG DISTRO=debian
ARG PG_MAJOR=latest
COPY --from=updated-image / /
COPY targets/debian/packages.env /tmp/packages.env
RUN set -eux; \
    source /tmp/packages.env; \
    # runtime dependencies \
    echo "${REQUIRES}" | xargs \
        apt-get install -y \
            --no-install-recommends \
            --no-install-suggests; \
    dpkg --get-selections > /tmp/runtime-selections; \
    \
    # make an architecture agnostic link (amd64/arm64) for jemalloc \
    ln -sf /usr/lib/*-linux-gnu/libjemalloc.so.2 /usr/local/lib/libjemalloc.so.2; \
    \
    # fix locales \
    sed -i 's/#\ \(en_US.UTF-8\)/\1/' /etc/locale.gen; \
    DEBIAN_FRONTEND=noninteractive dpkg-reconfigure locales; \
    \
    # set postgres fixed uid/gid (used 26 to be compatible with RHEL/Fedora) \
    groupdel tape && \
    groupmod -g 26 postgres && \
    usermod -u 26 postgres && \
    mkdir -p /var/lib/postgresql/data && \
    chown -R postgres:postgres \
      /etc/postgresql \
      /var/lib/postgresql \
      /var/log/postgresql \
      /var/run/postgresql

FROM scratch AS build-stage
# Needed for source shell functions into this Dockerfile
SHELL ["/bin/bash", "-c"]
COPY --from=runtime-image / /
RUN set -eux; \
    source /tmp/packages.env; \
    # build dependencies \
    echo "${BUILD_REQUIRES}" | xargs \
        apt-get install -y \
            --no-install-recommends \
            --no-install-suggests; \
    dpkg --get-selections > /tmp/buildtime-selections; \
    \
    # download and build su-exec \
    git clone --depth 1 -b master https://github.com/ncopa/su-exec.git /build \
        && make -C /build \
        && chmod a+x,u+s /build/su-exec \
        && mv /build/su-exec /usr/local/bin/ \
        && rm -f /usr/local/bin/gosu \
        && sed -i 's/gosu/su-exec/g' /usr/local/bin/docker-*.sh; \
    test -x /usr/local/bin/su-exec || exit -1; \
    \
    # image cleanup & hardening \
    CLEAR_PACKAGES="${BUILD_REQUIRES} $( \
        diff -u /tmp/runtime-selections /tmp/buildtime-selections \
            | sed '/^+[a-z]/!d;s/\s.*//g;s/\+\(\w*\)/\1/g' \
    )"; \
    echo "${CLEAR_PACKAGES}" | xargs \
        apt-get purge -y \
            --auto-remove \
            -o APT::AutoRemove::RecommendsImportant=false; \
    apt-get autoremove -y \
        --purge \
        -o APT::AutoRemove::RecommendsImportant=false; \
    apt-get -y clean; \
    rm -rf \
        /usr/bin/apt* \
        /usr/bin/dpkg* \
        /usr/bin/curl \
        /usr/bin/wget \
        /bin/nc* /usr/bin/nc* \
        /build \
        /tmp/* \
        /var/tmp/* \
        /usr/share/man/* \
        /usr/share/doc/* \
        /var/lib/apt/lists/*; \
    \
    find / -xdev -perm /6000 -type f ! -path "/usr/local/bin/su-exec" -exec chmod a-s {} + || true; \
    \
    sed -i -E 's|^([^:]+:[^:]+:[0-9]+:[0-9]+:[^:]*:[^:]*):/bin/(ba)?sh$|\1:/usr/sbin/nologin|' /etc/passwd; \
    passwd -l root; \
    usermod -L postgres;


FROM scratch
COPY --from=build-stage / /

WORKDIR /var/lib/postgresql
USER postgres

ARG DISTRO=debian
ARG DISTRO_VER=stable
ARG PG_MAJOR
ARG PG_VERSION

LABEL org.opencontainers.image.title="PostgreSQL ${PG_VERSION} (${DISTRO} ${DISTRO_VER})" \
      org.opencontainers.image.version="${PG_VERSION}"

ENV PG_MAJOR=${PG_MAJOR} \
    PG_VERSION=${PG_VERSION} \
    PATH=$PATH:/usr/lib/postgresql/${PG_MAJOR}/bin \
    LANG=en_US.UTF-8 \
    PGDATA=/var/lib/postgresql/data \
    HOME=/tmp \
    LD_PRELOAD=/usr/local/lib/libjemalloc.so.2

HEALTHCHECK \
   --interval=10s \
   --start-period=15s \
   --retries=3 \
   --timeout=3s \
   CMD pg_isready -U postgres -p ${PG_PORT:-5432}

STOPSIGNAL SIGINT
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["postgres"]
