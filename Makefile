SHELL       := /usr/bin/bash
.SHELLFLAGS := -eu -o pipefail -c

MAKEFLAGS += --warn-undefined-variables
MAKEFLAGS += --no-builtin-rules
MAKEFLAGS += --no-builtin-variables
MAKEFLAGS += --silent
unexport MAKEFLAGS

.SUFFIXES:            # Delete the default suffixes
.ONESHELL:            # All lines of the recipe will be given to a single invocation of the shell
.DELETE_ON_ERROR:
.SECONDARY:

HEADING1 := \#
HEADING2 := $(HEADING1)$(HEADING1)
HEADING3 := $(HEADING2)$(HEADING1)

COMMA := ,
EMPTY:=
SPACE := $(EMPTY) $(EMPTY)

IMAGE    :=  ghcr.io/grantmacken/zie-toolbox
CONTAINER := zie-toolbox-working-container

# The Bluefin Developer Experience (bluefin-dx)
TBX_IMAGE=ghcr.io/grantmacken/zie-toolbox-dx
TBX_CONTAINER_NAME=zie-toolbox-dx

BEAM := erlang erlang-rebar3 elixir

default: init golang

sssss:
ifdef GITHUB_ACTIONS
	buildah commit $(CONTAINER) $(TBX_IMAGE)
	buildah push $(TBX_IMAGE):latest
endif

init: info/working.info
info/working.info:
	echo '##[ $@ ]##'
	mkdir -p $(dir $@)
	podman images | grep -oP '$(IMAGE)' || buildah pull $(IMAGE) | tee  $@
	buildah containers | grep -oP $(CONTAINER) || buildah from $(IMAGE) | tee -a $@
	echo

beam: info/beam.info
info/beam.info:
	echo '##[ $@ ]##'
	mkdir -p $(dir $@)
	for item in $(BEAM)
	do
	buildah run $(CONTAINER) dnf install \
		--allowerasing \
		--skip-unavailable \
		--skip-broken \
		--no-allow-downgrade \
		-y \
		$${item} &>/dev/null
	done
	buildah run $(CONTAINER) sh -c "dnf -y info installed $(BEAM) | \
grep -oP '(Name.+:\s\K.+)|(Ver.+:\s\K.+)|(Sum.+:\s\K.+)' | \
paste - - - " | tee $@
	buildah run $(CONTAINER) sh -c 'erl -version' | tee -a $@
	echo -n 'OTP Release: '
	buildah run $(CONTAINER) erl -noshell -eval "erlang:display(erlang:system_info(otp_release)), halt()." | tee -a  $@
	echo -n 'Elixir: ' && buildah run $(CONTAINER) sh -c 'elixir --version' | tee $@
	echo -n 'Mix: ' && buildah run $(CONTAINER) sh -c 'mix --version' | tee -a $@
	echo -n 'Rebar3: ' && buildah run $(CONTAINER) sh -c 'rebar3 --version' | tee -a $@

latest/gleam.download:
	mkdir -p $(dir $@)
	wget -q -O - 'https://api.github.com/repos/gleam-lang/gleam/releases/latest' |
	jq  -r '.assets[].browser_download_url' |
	grep -oP '.+x86_64-unknown-linux-musl.tar.gz$$' > $@

gleam: info/gleam.info
info/gleam.info: latest/gleam.download
	mkdir -p $(dir $@)
	mkdir -p files
	DOWNLOAD_URL=$$(cat $<)
	echo "download url: $${DOWNLOAD_URL}"
	wget $${DOWNLOAD_URL} -q -O- | tar xz --strip-components=1 --one-top-level="gleam" -C files
	buildah add --chmod 755 $(CONTAINER) files/gleam /usr/local/bin/gleam
	buildah run $(CONTAINER) gleam --version | tee $@
	buildah run $(CONTAINER) gleam --help  | tee -a $@

latest/golang.download:
	mkdir -p $(dir $@)
	wget -q -O - https://go.dev/dl | 
	grep -oP '^.+class="download" href=.+\K(\d{1,2}\.\d{1,2}.\d{1,2})' | \
	head -n 1 | tee $@

golang: info/golang.info
info/golang.info: latest/golang.download
	echo "download url: "
