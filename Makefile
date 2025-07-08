#!/usr/bin/env make
SHELL := /bin/bash

repo := local
platform := linux/amd64,linux/arm64
default_dist := bookworm
targets := $(sort $(wildcard targets/*/*))
versions := $(sort $(wildcard versions/[0-9]*.env))

.PHONY: all
all: $(targets)

$(targets): targets/%: %
	@true

%: versions/latest.env
	@tgt=${@}; for filepath in $(versions); do \
	    source $${filepath}; \
	    dist="$${tgt##*/}" \
	    filename="$${filepath##*/}"; \
	    version="$${filename%.*}"; \
	    latest=$$(grep -iPo 'PG_MAJOR=\K[\S*].*' versions/latest.env); \
	    extraopts=$${extraopts:-'--load'}; \
	    if [ "$${dist}" == "$${default_dist}" ]; then \
	        extraopts="--tag $(repo)/postgres:$${PG_MAJOR} $${extraopts}"; \
	        extraopts="--tag $(repo)/postgres:$${PG_VERSION} $${extraopts}"; \
	        if [ "$${version}" == "$${latest}" ]; then \
	            extraopts="--tag $(repo)/postgres:latest $${extraopts}"; \
	        fi; \
	    fi; \
	    if [[ ! "$(skip-build)" =~ "$${version}" ]]; then \
	        [ 0$(DEBUG) -ne 0 ] && debug=-D; \
	        docker buildx $${debug} build . \
	            --file targets/$${tgt}/Dockerfile \
		    --platform $(platform) \
		    --build-arg PG_MAJOR=$${PG_MAJOR} \
		    --build-arg PG_VERSION=$${PG_VERSION} \
		    --tag "$(repo)/postgres:$${PG_MAJOR}-$${dist}" \
		    --tag "$(repo)/postgres:$${PG_VERSION}-$${dist}" \
		    $${extraopts} \
	        || exit $${?}; \
	    fi; \
	done

versions/latest.env:
	@latest=1; for filepath in $(versions); do \
	    filename="$${filepath##*/}"; \
	    version="$${filename%.*}"; \
	    if [ $${version} -gt 0$${latest} ]; then \
	        latest=$${version}; \
	    fi; \
	done; \
	ln -snf $${latest}.env versions/latest.env
