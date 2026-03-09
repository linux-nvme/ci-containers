# SPDX-License-Identifier: GPL-2.0-only
#
# Copyright (C) Red Hat, Inc. 2026
#
# Author: Michal Rábek <mrabek@redhat.com>

DISTROS := debian fedora tumbleweed alpine
DOCKERFILES := $(addprefix main/Dockerfile.,$(DISTROS))
STAGING_DOCKERFILES := $(addprefix staging/Dockerfile.,$(DISTROS))
BUILD_TARGETS := $(addprefix build-,$(DISTROS))
STAGING_BUILD_TARGETS := $(addprefix build-staging-,$(DISTROS))

.PHONY: all help generate build staging-dockerfiles $(BUILD_TARGETS) $(STAGING_BUILD_TARGETS)

all: generate build staging-build

help:
	@echo "Available targets:"
	@echo "  all                     - Generate and build all containers (default)"
	@echo "  generate                - Generate all Dockerfiles"
	@echo "  staging-dockerfiles     - Generate staging Dockerfiles"
	@echo "  build                   - Build normal containers"
	@echo "  staging-build           - Build staging containers"
	@echo "  Dockerfile.<distro>     - Generate Dockerfile for <distro>"
	@echo "  build-<distro>          - Build normal container for <distro>"
	@echo "  build-staging-<distro>  - Build staging container for <distro>"

# Generation targets
generate: $(DOCKERFILES) $(STAGING_DOCKERFILES)
staging-dockerfiles: $(STAGING_DOCKERFILES)

main/Dockerfile.%: ci-containers.yaml generate.py templates/Dockerfile.%.j2
	@if [ "$*" = "debian" ]; then \
		./generate.py --distro $* --bundles base,muon,musl,coverage,coverity,python --features muon --output $@; \
	else \
		./generate.py --distro $* --bundles base,muon,python --features muon --output $@; \
	fi

staging/Dockerfile.%: ci-containers.yaml generate.py templates/Dockerfile.%.j2
	./generate.py --distro $* --bundle base,staging  --output $@

# Build targets
build: $(BUILD_TARGETS)
staging-build: $(STAGING_BUILD_TARGETS)

$(BUILD_TARGETS): build-%: | main/Dockerfile.%
	sudo docker build -f main/Dockerfile.$* -t ci:$* .

$(STAGING_BUILD_TARGETS): build-staging-%: | staging/Dockerfile.%
	sudo docker build -f staging/Dockerfile.$* -t ci:$*-staging .
