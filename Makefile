# SPDX-License-Identifier: GPL-2.0-only
#
# Copyright (C) Red Hat, Inc. 2026
#
# Author: Michal Rábek <mrabek@redhat.com>

.DEFAULT_GOAL := all

DISTROS := debian fedora tumbleweed alpine
NVMETCLI_DISTROS := debian fedora tumbleweed

DOCKERFILES := $(addprefix main/Dockerfile.,$(DISTROS))
STAGING_DOCKERFILES := $(addprefix staging/Dockerfile.,$(DISTROS))
NVMETCLI_DOCKERFILES := $(addprefix nvmetcli/Dockerfile.,$(NVMETCLI_DISTROS))

BUILD_TARGETS := $(addprefix build-,$(DISTROS))
STAGING_BUILD_TARGETS := $(addprefix build-staging-,$(DISTROS))
NVMETCLI_BUILD_TARGETS := $(addprefix build-nvmetcli-,$(NVMETCLI_DISTROS))

# ----------------------------------------------------------------------
# containerDisk variants
#
# A containerDisk bakes a tool bundle into a bootable cloud image. Each
# <variant> builds for the distros in <variant>_DISTROS and takes its package
# list from the bundle of the same name in ci-containers.yaml. Add a variant by
# extending CONTAINERDISK_VARIANTS and defining its <variant>_DISTROS list.
# ----------------------------------------------------------------------
CONTAINERDISK_VARIANTS := nvmetcli
nvmetcli_DISTROS := debian fedora tumbleweed

# Expand the generate + build rules for one containerDisk variant ($1).
define CONTAINERDISK_rules
CONTAINERDISK_DOCKERFILES += $$(foreach d,$$($(1)_DISTROS),$(1)/Dockerfile.$$(d).containerdisk)
CONTAINERDISK_BUILD_TARGETS += $$(addprefix build-$(1)-containerdisk-,$$($(1)_DISTROS))

$(1)/Dockerfile.%.containerdisk: ci-containers.yaml generate.py templates/Dockerfile.containerdisk.j2
	./generate.py --distro $$* --bundles $(1) --variant $(1) \
		--template Dockerfile.containerdisk.j2 \
		--base-images containerdisk_base_images \
		--output $$@

build-$(1)-containerdisk: $$(addprefix build-$(1)-containerdisk-,$$($(1)_DISTROS))

# containerDisks inject the variant's tools into the base cloud image on the
# host (scripts/build-containerdisk.sh), then package the resulting qcow2 as a
# scratch containerDisk.
$$(addprefix build-$(1)-containerdisk-,$$($(1)_DISTROS)): build-$(1)-containerdisk-%: | $(1)/Dockerfile.%.containerdisk
	DOCKER="sudo docker" scripts/build-containerdisk.sh $$* $(1)
	sudo docker build -f $(1)/Dockerfile.$$*.containerdisk \
		-t ci:$(1)-$$*-containerdisk $(1)/build
endef

$(foreach v,$(CONTAINERDISK_VARIANTS),$(eval $(call CONTAINERDISK_rules,$(v))))

CONTAINERDISK_AGG_TARGETS := $(addsuffix -containerdisk,$(addprefix build-,$(CONTAINERDISK_VARIANTS)))

.PHONY: all help generate build staging-build build-nvmetcli \
        staging-dockerfiles \
        $(BUILD_TARGETS) $(STAGING_BUILD_TARGETS) $(NVMETCLI_BUILD_TARGETS) \
        $(CONTAINERDISK_AGG_TARGETS) $(CONTAINERDISK_BUILD_TARGETS)

all: generate build staging-build build-nvmetcli

help:
	@echo "Available targets:"
	@echo "  all                      - Generate and build all containers"
	@echo "  generate                 - Generate all Dockerfiles"
	@echo "  staging-dockerfiles      - Generate staging Dockerfiles"
	@echo "  build                    - Build normal containers"
	@echo "  staging-build            - Build staging containers"
	@echo "  build-nvmetcli           - Build nvmetcli containers"
	@echo "  build-<variant>-containerdisk         - Build all containerDisks for a variant"
	@echo "  Dockerfile.<distro>      - Generate main Dockerfile"
	@echo "  build-<distro>           - Build main container"
	@echo "  build-staging-<distro>   - Build staging container"
	@echo "  build-nvmetcli-<distro>  - Build nvmetcli container"
	@echo "  build-<variant>-containerdisk-<distro> - Build one containerDisk"
	@echo "  containerDisk variants:  $(CONTAINERDISK_VARIANTS)"

# ----------------------------------------------------------------------
# Generation
# ----------------------------------------------------------------------

generate: $(DOCKERFILES) $(STAGING_DOCKERFILES) $(NVMETCLI_DOCKERFILES) \
	$(CONTAINERDISK_DOCKERFILES)

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
