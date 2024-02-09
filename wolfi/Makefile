SHELL=/bin/bash
.ONESHELL:
.SHELLFLAGS := -eu -o pipefail -c
.DELETE_ON_ERROR:
MAKEFLAGS += --warn-undefined-variables
MAKEFLAGS += --no-builtin-rules
MAKEFLAGS += --silent

default: apko

apko:
	podman pull cgr.dev/chainguard/apko
	podman run --rm --privileged -v $(CURDIR):/work -w /work cgr.dev/chainguard/apko build apko.yaml apko-wolfi apko-wolfi.tar

