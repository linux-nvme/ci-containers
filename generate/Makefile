DISTROS := debian fedora tumbleweed alpine
DOCKERFILES := $(addprefix ../Dockerfile.,$(DISTROS))
STAGING_DOCKERFILES := $(addprefix ../staging/Dockerfile.,$(DISTROS))
BUILD_TARGETS := $(addprefix build-,$(DISTROS))
STAGING_BUILD_TARGETS := $(addprefix build-staging-,$(DISTROS))

.PHONY: all help generate build staging-dockerfiles $(BUILD_TARGETS) $(STAGING_BUILD_TARGETS)

all: generate staging-dockerfiles build staging-build

help:
	@echo "Available targets:"
	@echo "  all                     - Generate and build all containers (default)"
	@echo "  generate                - Generate normal Dockerfiles"
	@echo "  staging-dockerfiles     - Generate staging Dockerfiles"
	@echo "  build                   - Build normal containers"
	@echo "  staging-build           - Build staging containers"
	@echo "  Dockerfile.<distro>     - Generate Dockerfile for <distro>"
	@echo "  build-<distro>          - Build normal container for <distro>"
	@echo "  build-staging-<distro>  - Build staging container for <distro>"

# Generation targets
generate: $(DOCKERFILES)
staging-dockerfiles: $(STAGING_DOCKERFILES)

../Dockerfile.%: ci-containers.yaml generate.py templates/Dockerfile.%.j2
	./generate.py --distro $* --bundles base,python --output $@

../staging/Dockerfile.%: ci-containers.yaml generate.py templates/Dockerfile.%.j2
	./generate.py --distro $* --bundle base,staging --features muon --output $@

# Build targets
build: $(BUILD_TARGETS)
staging-build: $(STAGING_BUILD_TARGETS)

$(BUILD_TARGETS): build-%: | ../Dockerfile.%
	sudo docker build -f ../Dockerfile.$* -t ci:$* .

$(STAGING_BUILD_TARGETS): build-staging-%: | ../staging/Dockerfile.%
	sudo docker build -f ../staging/Dockerfile.$* -t ci:$*-staging .
