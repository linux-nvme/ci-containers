DISTROS := debian fedora tumbleweed alpine
DOCKERFILES := $(addprefix ../Dockerfile.,$(DISTROS))
BUILD_TARGETS := $(addprefix build-,$(DISTROS))

.PHONY: all help generate build $(BUILD_TARGETS)

all: generate build

help:
	@echo "Available targets:"
	@echo "  all                 - Generate and build all containers (default)"
	@echo "  generate            - Generate all Dockerfiles"
	@echo "  build               - Build all containers"
	@echo "  Dockerfile.<distro> - Generate Dockerfile for <distro>"
	@echo "  build-<distro>      - Build container for <distro>"

generate: $(DOCKERFILES)

build: $(BUILD_TARGETS)

../Dockerfile.%: ci-containers.yaml generate.py templates/Dockerfile.%.j2
	./generate.py --distro $* --bundles base,python --output $@

$(BUILD_TARGETS): build-%: | ../Dockerfile.%
	sudo docker build -f ../Dockerfile.$* -t ci:$* .
