#!/usr/bin/env make
SHELL := /bin/bash
BUILDDIR := $(PWD)/build

repo := local
targets := targets/bookworm
versions := $(sort $(wildcard versions/*.env))

.PHONY: all
all:

$(targets): targets/%: %
	@true

%: $(BUILDDIR)/latest.txt
	@tgt=$@; for filepath in $(versions); do \
	    filename="$${filepath##*/}"; \
	    version="$${filename%.*}"; \
	    latest=$$(< $(BUILDDIR)/latest.txt); \
	    extraopts=$${extraopts:-'--load'}; \
	    if [ $${version} == $${latest} ]; then \
	        extraopts="--tag $(repo)/postgres:latest $${extraopts}"; \
	    fi; \
	    source $${filepath}; \
	    docker buildx build . \
	        --file targets/$${tgt}/Dockerfile \
		--platform linux/amd64,linux/arm64 \
		--build-arg PG_MAJOR=$${PG_MAJOR} \
		--build-arg PG_VERSION=$${PG_VERSION} \
		--tag $(repo)/postgres:$${PG_MAJOR} \
		--tag $(repo)/postgres:$${PG_VERSION} \
		--tag $(repo)/postgres:$${PG_MAJOR}-$${tgt} \
		--tag $(repo)/postgres:$${PG_VERSION}-$${tgt} \
		$${extraopts} \
	    || exit $${?}; \
	done

$(BUILDDIR)/latest.txt:
	@latest=1; for filepath in $(versions); do \
	    filename="$${filepath##*/}"; \
	    version="$${filename%.*}"; \
	    if [ $${version} -gt 0$${latest} ]; then \
	        latest=$${version}; \
	    fi; \
	done; \
	mkdir -p build && \
	echo $${latest} > $(BUILDDIR)/latest.txt
