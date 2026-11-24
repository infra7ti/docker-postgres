# infra7/postgres

Hardened PostgreSQL container images built on top of the official Debian `stable` release, featuring automated upstream security updates, `jemalloc` memory allocator, built-in `HEALTHCHECK`, standardized RHEL-compatible UID/GID (`26:26`), and `gosu` replaced by `su-exec`.

## Key Features

* **Security & Hardening:**
  * Latest Debian security patches applied at build time.
  * `gosu` replaced by a lightweight, compiled-from-source `su-exec`.
  * Package managers (`apt`, `dpkg`), network transfer tools (`curl`, `wget`, `nc`), man pages, and residual SUID/SGID binaries stripped from the final image.
  * Non-interactive shells (`/usr/sbin/nologin`) and locked local account passwords.
  * Built-in `HOME=/tmp` and directory permissions ready for read-only root filesystems (`read_only: true`), `cap_drop: [ALL]`, and arbitrary `--user` overrides.
* **Performance, Reliability & Compatibility:**
  * `libjemalloc2` preloaded via `LD_PRELOAD` (architecture-agnostic for `linux/amd64` and `linux/arm64`).
  * Built-in `HEALTHCHECK` using `pg_isready` out of the box (unlike the upstream official image).
  * `postgres` user/group standardized to UID/GID `26` for seamless volume permissions across RHEL, RockyLinux, AlmaLinux, and Fedora hosts.
  * Default `en_US.UTF-8` locale pre-configured.
* **Dynamic Release Tracking:**
  * Automatically fetches all active PostgreSQL major/minor releases directly from `postgresql.org` in ascending build order.

> **Note:** Unlike the upstream image (which uses UID `999` and versioned `PGDATA` paths starting in PostgreSQL 18), `infra7/postgres` standardizes the `postgres` user to **UID/GID `26:26`** and keeps `PGDATA=/var/lib/postgresql/data` across all versions for consistent volume mounting.

## Building Images Locally

The `Makefile` supports **Docker (`buildx`)**, **Podman**, and **Buildah**:

```bash
# Check detected PostgreSQL active releases and build order
make info

# Build all active versions locally (native architecture) using Docker
make

# Build a specific subset of major versions
make skip-build="15 16 17 18"

# Build using Podman or Buildah
make engine=podman
make engine=buildah

# Specific-arch / Multi-arch build (linux/amd64, linux/arm64, etc)
make repo=local platform=linux/amd64
```

## Quick Start (Compose)

Compatible with both `docker compose` and `podman compose`. Create the required secret files first:

```bash
mkdir -p secrets
echo "postgres" > secrets/postgres.user
openssl rand -base64 24 > secrets/postgres.pass
chmod 600 secrets/*
```

Start the container:

```bash
docker compose up -d
# or
podman compose up -d
```

For general PostgreSQL environment variables and initialization behavior, refer to the official [PostgreSQL Docker documentation](https://github.com).

## License

This project is licensed under the **MIT License** — see the [LICENSE](https://github.com) file for details.  
The **Infra7** name and brand remain the exclusive property of their respective owners and may not be used to endorse derived images without prior permission.
