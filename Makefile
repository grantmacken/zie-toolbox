SHELL=/bin/bash
.SHELLFLAGS := -eu -o pipefail -c
.ONESHELL:
.DELETE_ON_ERROR:
.SECONDARY:

MAKEFLAGS += --warn-undefined-variables
MAKEFLAGS += --no-builtin-rules
MAKEFLAGS += --silent

TBX := zie-toolbox-working-container
BEAM := erlang erlang-rebar3 elixir

beam_me_up: from-tbx beam gleam
	# rebar3 elixir gleam:w
	buildah run $(TBX) which erl
	buildah run $(TBX) which rebar3
	buildah run $(TBX) which elixir
	buildah run $(TBX) which gleam
ifdef GITHUB_ACTIONS
	buildah commit $(TBX) ghcr.io/grantmacken/beam-me-up-toolbox
	buildah push ghcr.io/grantmacken/beam-me-up-toolbox
endif

from-tbx: info/tbx.info
info/tbx.info:
	echo '##[ $@ ]##'
	mkdir -p $(dir $@)
	podman images | grep -oP 'ghcr.io/grantmacken/zie-toolbox' || buildah pull ghcr.io/grantmacken/zie-toolbox | tee  $@
	buildah from ghcr.io/grantmacken/zie-toolbox | tee -a $@

beam: info/beam.info
info/beam.info:
	echo '##[ $@ ]##'
	mkdir -p $(dir $@)
	WORKING_CONTAINER
	for item in $(BEAM)
	buildah run $(TBX) localectl set-locale LANG=C.UTF-8
	buildah run $(TBX) localectl set-locale LC_ALL=C.UTF-8
	buildah run $(TBX) rpm -ql $${item} &>/dev/null ||
	buildah run $(TBX) dnf install \
		--allowerasing \
		--skip-unavailable \
		--skip-broken \
		--no-allow-downgrade \
		-y \
		$${item} &>/dev/null
	done
	buildah run $(TBX) sh -c "dnf -y info installed $(BEAM) | \
grep -oP '(Name.+:\s\K.+)|(Ver.+:\s\K.+)|(Sum.+:\s\K.+)' | \
paste - - - " | tee $@
	buildah run $(TBX) sh -c 'erl -version' | tee -a $@
	echo -n 'OTP Release: '
	buildah run $(TBX) erl -noshell -eval "erlang:display(erlang:system_info(otp_release)), halt()." | tee -a  $@
	echo -n 'Elixir: ' && buildah run $(TBX) sh -c 'elixir --version' | tee $@
	echo -n 'Mix: ' && buildah run $(TBX) sh -c 'mix --version' | tee -a $@
	echo -n 'Rebar3: ' && buildah run $(TBX) sh -c 'rebar3 --version' | tee -a $@

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
	buildah add --chmod 755 $(TBX) files/gleam /usr/local/bin/gleam
	buildah run $(TBX) gleam --version | tee $@
	buildah run $(TBX) gleam --help  | tee -a $@
