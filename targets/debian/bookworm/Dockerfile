# syntax=docker/dockerfile:1

ARG DISTRO=bookworm
ARG PG_MAJOR=latest
FROM postgres:${PG_MAJOR}-${DISTRO} AS updated-image
RUN set -eux; \
    apt-get update; \
    apt-get dist-upgrade -y --autoremove;

FROM scratch AS runtime-image
# Needed for source shell functions into this Dockerfile
SHELL ["/bin/bash", "-c"]
ARG DISTRO=bookworm
ARG PG_MAJOR=latest
COPY --from=updated-image / /
COPY versions/${PG_MAJOR}.env /tmp/version.env
COPY targets/debian/${DISTRO}/packages.env /tmp/packages.env
RUN set -eux; \
    source /tmp/version.env; \
    source /tmp/packages.env; \
    # runtime dependencies \
    echo "${REQUIRES}" | xargs \
        apt-get install -y \
            --no-install-recommends \
            --no-install-suggests; \
    dpkg --get-selections > /tmp/runtime-selections; \
    \
    # fix locales \
    sed -i 's/#\ \(en_US.UTF-8\)/\1/' /etc/locale.gen; \
    DEBIAN_FRONTEND=noninteractive dpkg-reconfigure locales; \
    \
    # set postgres fixed uid/gid (used 26 to be compatible with RHEL/Fedora) \
    groupdel tape && \
    groupmod -g 26 postgres && \
    usermod -u 26 postgres && \
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
    source /tmp/version.env; \
    source /tmp/packages.env; \
    # build dependencies \
    echo "${BUILD_REQUIRES}" | xargs \
        apt-get install -y \
            --no-install-recommends \
            --no-install-suggests; \
    dpkg --get-selections > /tmp/buildtime-selections; \
    \
    # download and build su-exec \
    git config --global http.sslVerify false; \
    git clone -b master https://github.com/ncopa/su-exec.git /build \
        && cd /build \
        && git fetch \
        && git reset --hard origin/master \
        && make \
        && chmod +x,u+s su-exec \
        && mv su-exec /usr/local/bin/ \
        && rm -f /usr/local/bin/gosu \
        && sed -i 's/gosu/su-exec/g' /usr/local/bin/docker-*.sh; \
    test -x /usr/local/bin/su-exec || exit -1; \
    \
    # image cleanup \
    CLEAR_PACKAGES="${BUILD_REQUIRES} $( \
        diff -u runtime-selections buildtime-selections \
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
        /build \
        /tmp/* \
        /var/lib/apt/lists/*


FROM scratch
COPY --from=build-stage / /

WORKDIR /var/lib/postgresql
USER postgres

ARG PG_MAJOR
ENV PG_MAJOR=${PG_MAJOR}
ENV PATH=$PATH:/usr/lib/postgresql/${PG_MAJOR}/bin
ENV LANG=en_US.UTF-8

ARG PG_VERSION
ENV PG_VERSION=${PG_VERSION}
ENV PGDATA=/var/lib/postgresql/data

HEALTHCHECK \
   --interval=10s \
   --start-period=15s \
   --retries=3 \
   --timeout=3s \
   CMD pg_isready -U postgres -p ${PG_PORT:-5432}

STOPSIGNAL SIGINT
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["postgres"]
