# SPDX-License-Identifier: GPL-2.0-only
#
# Copyright (C) Red Hat, Inc. 2026
#
# Author: Michal Rábek <mrabek@redhat.com>

DISTROS := debian fedora tumbleweed alpine
NVMETCLI_DISTROS := debian fedora tumbleweed

DOCKERFILES := $(addprefix main/Dockerfile.,$(DISTROS))
STAGING_DOCKERFILES := $(addprefix staging/Dockerfile.,$(DISTROS))
NVMETCLI_DOCKERFILES := $(addprefix nvmetcli/Dockerfile.,$(DISTROS))

BUILD_TARGETS := $(addprefix build-,$(DISTROS))
STAGING_BUILD_TARGETS := $(addprefix build-staging-,$(DISTROS))
NVMETCLI_BUILD_TARGETS := $(addprefix build-nvmetcli-,$(NVMETCLI_DISTROS))

.PHONY: all help generate build staging-build build-nvmetcli \
        staging-dockerfiles $(BUILD_TARGETS) $(STAGING_BUILD_TARGETS) $(NVMETCLI_BUILD_TARGETS)

all: generate build staging-build build-nvmetcli

help:
	@echo "Available targets:"
	@echo "  all                      - Generate and build all containers"
	@echo "  generate                 - Generate all Dockerfiles"
	@echo "  staging-dockerfiles      - Generate staging Dockerfiles"
	@echo "  build                    - Build normal containers"
	@echo "  staging-build            - Build staging containers"
	@echo "  build-nvmetcli           - Build nvmetcli containers"
	@echo "  Dockerfile.<distro>      - Generate main Dockerfile"
	@echo "  build-<distro>           - Build main container"
	@echo "  build-staging-<distro>   - Build staging container"
	@echo "  build-nvmetcli-<distro>  - Build nvmetcli container"

# ----------------------------------------------------------------------
# Generation
# ----------------------------------------------------------------------

generate: $(DOCKERFILES) $(STAGING_DOCKERFILES) $(NVMETCLI_DOCKERFILES)

staging-dockerfiles: $(STAGING_DOCKERFILES)

main/Dockerfile.%: ci-containers.yaml generate.py templates/Dockerfile.%.j2
	@if [ "$*" = "debian" ]; then \
		./generate.py --distro $* \
			--bundles nvme,muon-dep,musl,coverage,analyzers,docs,python \
			--features muon \
			--output $@; \
	else \
		./generate.py --distro $* \
			--bundles nvme,analyzers,python \
			--output $@; \
	fi

staging/Dockerfile.%: ci-containers.yaml generate.py templates/Dockerfile.%.j2
	./generate.py --distro $* --bundles muon --output $@

nvmetcli/Dockerfile.%: ci-containers.yaml generate.py templates/Dockerfile.%.j2
	./generate.py --distro $* --bundles nvmetcli --output $@

build: $(BUILD_TARGETS)
staging-build: $(STAGING_BUILD_TARGETS)
build-nvmetcli: $(NVMETCLI_BUILD_TARGETS)

$(BUILD_TARGETS): build-%: | main/Dockerfile.%
	sudo docker build -f main/Dockerfile.$* -t ci:$* .

$(STAGING_BUILD_TARGETS): build-staging-%: | staging/Dockerfile.%
	sudo docker build -f staging/Dockerfile.$* -t ci:$*-staging .

$(NVMETCLI_BUILD_TARGETS): build-nvmetcli-%: | nvmetcli/Dockerfile.%
	sudo docker build -f nvmetcli/Dockerfile.$* -t ci:nvmetcli-$* .
