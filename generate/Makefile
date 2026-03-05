DISTROS := debian fedora tumbleweed alpine
DOCKERFILES := $(addprefix ../Dockerfile.,$(DISTROS))
BUILD_TARGETS := $(addprefix build-,$(DISTROS))

BUNDLES_debian   := base,python
BUNDLES_fedora   := base,python
BUNDLES_tumbleweed := base,python
BUNDLES_alpine   := base,python

FEATURES_debian := muon
FEATURE_DOCKERFILES_debian := $(addprefix ../Dockerfile.debian.,$(FEATURES_debian))
FEATURE_DOCKERFILES := $(FEATURE_DOCKERFILES_debian)
FEATURE_BUILD_TARGETS := $(patsubst ../Dockerfile.%,build-%,$(FEATURE_DOCKERFILES))

.PHONY: all help generate build $(BUILD_TARGETS) $(FEATURE_BUILD_TARGETS)

all: generate build

help:
	@echo "Available targets:"
	@echo "  all                           - Generate and build all containers (default)"
	@echo "  generate                      - Generate all Dockerfiles"
	@echo "  build                         - Build all containers"
	@echo "  Dockerfile.<distro>           - Generate Dockerfile for <distro>"
	@echo "  Dockerfile.<distro>.<feature> - Generate Dockerfile for <distro> with <feature>"
	@echo "  build-<distro>                - Build container for <distro>"
	@echo "  build-<distro>.<feature>      - Build container for <distro> with <feature>"

generate: $(DOCKERFILES) $(FEATURE_DOCKERFILES)

build: $(BUILD_TARGETS) $(FEATURE_BUILD_TARGETS)

../Dockerfile.%: ci-containers.yaml generate.py templates/Dockerfile.%.j2
	./generate.py --distro $* --bundles $(BUNDLES_$*) --output $@

$(FEATURE_DOCKERFILES_debian): ../Dockerfile.debian.%: ci-containers.yaml generate.py templates/Dockerfile.debian.j2
	./generate.py --distro debian --bundles $(BUNDLES_debian) --features $* --output $@

$(BUILD_TARGETS): build-%: | ../Dockerfile.%
	sudo docker build -f ../Dockerfile.$* -t ci:$* .

$(FEATURE_BUILD_TARGETS): build-%: | ../Dockerfile.%
	sudo docker build -f ../Dockerfile.$* -t ci:$* .
