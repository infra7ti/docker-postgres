ARG PG_MAJOR=latest
FROM postgres:${PG_MAJOR}-bookworm AS builder
RUN grep security /etc/apt/sources.list \
        | egrep -v '#' \
        | tee /tmp/security.sources.list \
    && apt-get -q update \
    && apt-get -y upgrade -o Dir::Etc::SourceList=/tmp/security.sources.list \
    && apt-get -y \
      --no-install-recommends \
      --no-install-suggests \
      install \
	ca-certificates \
	gcc \
	git \
	libc-dev \
        libjemalloc2 \
	make \
    && sed -i 's/#\ \(en_US.UTF-8\)/\1/' /etc/locale.gen \
    && DEBIAN_FRONTEND=noninteractive dpkg-reconfigure locales \
    && git clone -b master https://github.com/ncopa/su-exec.git /build \
    && cd /build \
    && git fetch \
    && git reset --hard origin/master \
    && make \
    && chmod +x,u+s su-exec \
    && mv su-exec /usr/local/bin/ \
    && rm -f /usr/local/bin/gosu \
    && sed -i 's/gosu/su-exec/g' \
        /usr/local/bin/docker-entrypoint.sh; \
    cd / \
    && apt-get -y remove \
        --purge \
        *-dev \
        gcc \
        git \
        libc-dev \
	libc6-dev \
        libcrypt-dev \
        libnsl-dev \
        libtirpc-dev \
        linux-libc-dev \
        make \
    && apt-get -y autoremove --purge \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
        /tmp/security.sources.list \
	/build


FROM scratch
COPY --from=builder / /

WORKDIR /var/lib/postgresql
USER postgres

ARG PG_MAJOR
ENV PG_MAJOR=${PG_MAJOR}
ENV PATH=$PATH:/usr/lib/postgresql/${PG_MAJOR}/bin
ENV LANG=en_US.UTF-8

ARG PG_VERSION
ENV PG_VERSION=${PG_VERSION}-1.pgdg120+1
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
