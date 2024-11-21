SHELL=/bin/bash
.SHELLFLAGS := -eu -o pipefail -c
.ONESHELL:
.DELETE_ON_ERROR:
.SECONDARY:

MAKEFLAGS += --warn-undefined-variables
MAKEFLAGS += --no-builtin-rules
MAKEFLAGS += --silent

IMAGE := ghcr.io/grantmacken/zie-toolbox
TBX := zie-toolbox-working-container

default: from-tbx

from-tbx: info/tbx.info
info/tbx.info:
	echo '##[ $@ ]##'
	mkdir -p $(dir $@)
	podman images | grep -oP '$(IMAGE)' || buildah pull $(IMAGE):latest | tee  $@
	buildah from  $(IMAGE) | tee -a $@

