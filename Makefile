#!/usr/bin/env make
SHELL := /bin/bash

engine := docker
repo := local
platform := linux/amd64,linux/arm64
default_target := debian
target_ver := stable
pg_url := https://postgresql.org

define GET_RELEASES
curl -fsSL -A "Mozilla/5.0" "$(pg_url)" \
	| grep -oE '<li[^>]*><strong>[0-9]+\.[0-9]+</strong>' \
	| sed -E 's|^<li[^>]*><strong>([0-9]+)\.([0-9]+)</strong>$$|\1:\1.\2|' \
	| sort -Vr \
	| awk -F: '!seen[$$1]++' \
	| sort -V
endef

targets := $(notdir $(sort $(wildcard targets/*)))

.PHONY: all info $(targets)

all: $(targets)

info:
	@echo "Retrieving releases info from $(pg_url)..."
	@RELEASES=$$($(GET_RELEASES)); \
	if [ -z "$$RELEASES" ]; then \
		echo "Error: Can't read release info from $(pg_url)" >&2; \
		exit 1; \
	fi; \
	latest=$$(echo "$$RELEASES" | tail -n 1 | cut -d: -f1); \
	echo "Detected Channels (build order):"; \
	echo "$$RELEASES" | awk -F: -v l="$$latest" '{if ($$1==l) print "  latest -> PG " $$1 " (" $$2 ")"; else print "  active -> PG " $$1 " (" $$2 ")"}'

$(targets): %:
	@tgt="$@"; \
	RELEASES=$$($(GET_RELEASES)); \
	if [ -z "$$RELEASES" ]; then \
		echo "Error: Can't read release info from $(pg_url)" >&2; \
		exit 1; \
	fi; \
	latest=$$(echo "$$RELEASES" | tail -n 1 | cut -d: -f1); \
	for entry in $$RELEASES; do \
	    PG_MAJOR="$${entry%%:*}"; \
	    PG_VERSION="$${entry##*:}"; \
	    if [[ " $(skip-build) " =~ " $${PG_MAJOR} " ]]; then \
	        continue; \
	    fi; \
	    \
	    tag_list=("$(repo)/postgres:$${PG_MAJOR}-$${tgt}" "$(repo)/postgres:$${PG_VERSION}-$${tgt}"); \
	    if [ "$${tgt}" == "$(default_target)" ]; then \
	        tag_list+=("$(repo)/postgres:$${PG_MAJOR}" "$(repo)/postgres:$${PG_VERSION}"); \
	        if [ "$${PG_MAJOR}" == "$${latest}" ]; then \
	            tag_list+=("$(repo)/postgres:latest"); \
	        fi; \
	    fi; \
	    \
	    build_opts="$(extraopts)"; \
	    target_platform="$(platform)"; \
	    if [ -z "$${build_opts}" ]; then \
	        target_platform="linux/$$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')"; \
	    fi; \
	    \
	    echo "Building PostgreSQL $${PG_VERSION} ($${tgt}/$(target_ver)) using $(engine)..."; \
	    build_args=( \
	        --file "targets/$${tgt}/Dockerfile" \
	        --platform "$${target_platform}" \
	        --build-arg DISTRO="$${tgt}" \
	        --build-arg DISTRO_VER="$(target_ver)" \
	        --build-arg PG_MAJOR="$${PG_MAJOR}" \
	        --build-arg PG_VERSION="$${PG_VERSION}" \
	    ); \
	    \
	    case "$(engine)" in \
	        docker) \
	            [ -z "$${build_opts}" ] && build_opts="--load"; \
	            [ "0$(DEBUG)" -ne 0 ] && debug="-D" || debug=""; \
	            tags_flags=(); \
	            for t in "$${tag_list[@]}"; do tags_flags+=(--tag "$$t"); done; \
	            docker buildx $${debug} build . "$${build_args[@]}" "$${tags_flags[@]}" $${build_opts} || exit $${?}; \
	            ;; \
	        podman|buildah) \
	            [ "$(engine)" == "podman" ] && cmd="podman build" || cmd="buildah bud"; \
	            primary_manifest="$${tag_list[0]}"; \
	            $(engine) manifest rm "$${primary_manifest}" >/dev/null 2>&1 || true; \
	            $${cmd} . "$${build_args[@]}" --manifest "$${primary_manifest}" || exit $${?}; \
	            for t in "$${tag_list[@]:1}"; do \
	                $(engine) tag "$${primary_manifest}" "$$t" || exit $${?}; \
	            done; \
	            if [[ "$${build_opts}" == *"--push"* ]]; then \
	                for t in "$${tag_list[@]}"; do \
	                    $(engine) manifest push --all "$${primary_manifest}" "docker://$$t" || exit $${?}; \
	                done; \
	            fi; \
	            ;; \
	        *) \
	            echo "Unsupported engine: $(engine). Use docker, podman, or buildah." >&2; \
	            exit 1; \
	            ;; \
	    esac; \
	done
