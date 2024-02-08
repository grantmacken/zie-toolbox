SHELL=/bin/bash
.ONESHELL:
.SHELLFLAGS := -eu -o pipefail -c
.DELETE_ON_ERROR:
MAKEFLAGS += --warn-undefined-variables
MAKEFLAGS += --no-builtin-rules
MAKEFLAGS += --silent


# This will create a packages folder, with an entry for each architecture supported by the package
default: apko


apko:
	podman pull cgr.dev/chainguard/apko
	podman run --rm --privileged -v $(CURDIR):/work -w /work cgr.dev/chainguard/apko build apko.yaml apko-wolfi:latest apko-wolfi.tar
	podman load --input apko-wolfi.tar
	podman images


run:
	podman run --rm -it apko-wolfi:test-amd64

latest.json:
	curl https://api.github.com/repos/neovim/neovim/releases -s -s | jq -r '.[0]' > $@

sdk:
	# podman pull ghcr.io/wolfi-dev/sdk:latest
	podman pull cgr.dev/chainguard/apko
	podman pull ghcr.io/wolfi-dev/melange
	# podman run --rm cgr.dev/chainguard/apko apko version
