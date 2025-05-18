ARG PG_MAJOR=latest
FROM postgres:${PG_MAJOR}-bookworm AS updated-image
# Needed for source shell functions into this Dockerfile
SHELL ["/bin/bash", "-c"]
COPY versions/${PG_MAJOR}.env /version.env
RUN \
    source /version.env; \
    \
    apt-get update; \
    apt-get dist-upgrade -y --autoremove; \
    \
    # runtime dependencies \
    echo "${REQUIRES}" | xargs \
        apt-get -y \
            --no-install-recommends \
            --no-install-suggests; \
    \
    # build dependencies \
    echo "${BUILD_REQUIRES}" | xargs \
        apt-get install -y \
            --no-install-recommends \
            --no-install-suggests; \
    \
    # fix locales \
    sed -i 's/#\ \(en_US.UTF-8\)/\1/' /etc/locale.gen; \
    DEBIAN_FRONTEND=noninteractive dpkg-reconfigure locales; \
    \
    # download and build su-exec \
    git clone -b master https://github.com/ncopa/su-exec.git /build \
        && cd /build \
        && git fetch \
        && git reset --hard origin/master \
        && make \
        && chmod +x,u+s su-exec \
        && mv su-exec /usr/local/bin/ \
        && rm -f /usr/local/bin/gosu \
        && sed -i 's/gosu/su-exec/g' /usr/local/bin/docker-entrypoint.sh; \
    cd /; \
    \
    # image cleanup \
    echo "${BUILD_REQUIRES}" | xargs \
        apt-get purge -y \
            --auto-remove \
            -o APT::AutoRemove::RecommendsImportant=false; \
    apt-get autoremove -y \
        --purge \
        -o APT::AutoRemove::RecommendsImportant=false; \
    apt-get -y clean; \
    rm -rf \
        /build \
        /var/lib/apt/lists/* \
        /version.env


FROM scratch
COPY --from=updated-image / /

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
