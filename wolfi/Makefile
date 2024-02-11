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

melange: commitish
	# podman pull ghcr.io/wolfi-dev/melange
	podman run --rm --privileged -v "$${PWD}":/work cgr.dev/chainguard/melange keygen
	podman run --rm --privileged -v "$${PWD}":/work -w /work -- \
 cgr.dev/chainguard/melange build neovim.yaml \
 --arch x86_64 \
 --signing-key melange.rsa --keyring-append melange.rsa.pub

commitish: latest.json
	jq -r .tag_name latest.json
	NEW=$$(jq -r .target_commitish $< ) 
	jq -r .name latest.json 
	OLD=$$(grep -oP 'sha: \K.+$$' neovim.yaml ) || true
	echo "old: $${OLD}"
	echo "new: $${NEW}"
	sed -i "s/$${OLD}/$${NEW}/" neovim.yaml 
	# grep -oP 'sha: \K.+$$' neovim.yaml

latest.json:
	curl https://api.github.com/repos/neovim/neovim/releases -s | jq -r '.[0]' > $@


