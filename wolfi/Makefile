SHELL=/bin/bash
.ONESHELL:
.SHELLFLAGS := -eu -o pipefail -c
.DELETE_ON_ERROR:
MAKEFLAGS += --warn-undefined-variables
MAKEFLAGS += --no-builtin-rules
MAKEFLAGS += --silent

default: apko

apko: melange
	podman pull cgr.dev/chainguard/apko
	podman run --rm --privileged -v $(CURDIR):/work -w /work cgr.dev/chainguard/apko build apko.yaml apko-wolfi apko-wolfi.tar

melange:
	# podman pull ghcr.io/wolfi-dev/melange
	podman run --rm --privileged -v "$${PWD}":/work cgr.dev/chainguard/melange keygen
	podman run --rm --privileged -v "$${PWD}":/work -w /work -- \
 cgr.dev/chainguard/melange build neovim.yaml \
 --arch x86_64 \
 --signing-key melange.rsa --keyring-append melange.rsa.pub

