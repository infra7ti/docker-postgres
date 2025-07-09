# syntax=docker/dockerfile:1

ARG DIST=rockylinux9
FROM rockylinux:${DIST//rockylinux/} AS updated-image
RUN set -eux; \
    dnf -y upgrade --refresh

FROM scratch AS runtime-image
# Needed for source shell functions into this Dockerfile
SHELL ["/bin/bash", "-c"]
ARG DIST=rockylinux9
ARG PG_MAJOR=latest
COPY --from=updated-image / /
COPY versions/${PG_MAJOR}.env /tmp/version.env
COPY targets/rockylinux/${DIST}/packages.env /tmp/packages.env
COPY targets/rockylinux/${DIST}/scripts/docker-*.sh /usr/local/bin/
RUN set -eux; \
    source /tmp/version.env; \
    source /tmp/packages.env; \
    # pgdg repository \
    REPO_BASE_URI=https://download.postgresql.org/pub/repos/yum/reporpms; \
    REPO_PACKAGE=pgdg-redhat-repo-latest.noarch.rpm; \
    dnf -y install \
        ${REPO_BASE_URI}/EL-${DIST//rockylinux/}-$(arch)/${REPO_PACKAGE}; \
    # EPEL repository \
    dnf -y install epel-release; \
    # runtime dependencies \
    echo "${REQUIRES}" | xargs \
        dnf -y install;

FROM scratch AS build-stage
# Needed for source shell functions into this Dockerfile
SHELL ["/bin/bash", "-c"]
ARG DIST=rockylinux9
ARG PG_MAJOR=latest
COPY --from=runtime-image / /
COPY targets/rockylinux/${DIST}/patches/postgresql-common.spec.patch /tmp/
RUN set -eux \
    source /tmp/version.env; \
    source /tmp/packages.env; \
    # build dependencies \
    echo "${BUILD_REQUIRES}" | xargs \
        dnf -y install; \
    dnf history list | head -2 \
      | sed '/ID/d;s/\([0-9]*\)\ .*/\1/g' \
      >> /tmp/dnf-buildreq-transaction; \
    \
    # download and build postgresql-common \
    git config --global http.sslVerify false; \
    git clone -b master \
        https://salsa.debian.org/postgresql/postgresql-common.git \
        /build/pg_common \
        && cd /build/pg_common \
        && git fetch \
        && git reset --hard origin/master \
        && patch -p1 < /tmp/postgresql-common.spec.patch \
        && sed -i 's/sudo //g' Makefile \
        && make rpmbuild \
        && make rpminstall; \
    \
    # download and build su-exec \
    git clone -b master https://github.com/ncopa/su-exec.git /build/su-exec \
        && cd /build/su-exec \
        && git fetch \
        && git reset --hard origin/master \
        && make \
        && chmod +x,u+s su-exec \
        && mv su-exec /usr/local/bin/ \
        && rm -f /usr/local/bin/gosu; \
    test -x /usr/local/bin/su-exec || exit -1; \
    \
    # image cleanup \
    DNF_TRANSACTION=$(cat /tmp/dnf-buildreq-transaction); \
    CLEAR_PACKAGES="${BUILD_REQUIRES}"; \
    dnf -y history undo ${DNF_TRANSACTION} \
    	|| echo "${CLEAR_PACKAGES}" | xargs \
            dnf -y remove; \
    dnf -y clean all; \
    rm -rf /build

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
