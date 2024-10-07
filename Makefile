SHELL=/bin/bash
.ONESHELL:
.SHELLFLAGS := -eu -o pipefail -c
.DELETE_ON_ERROR:
MAKEFLAGS += --warn-undefined-variables
MAKEFLAGS += --no-builtin-rules
MAKEFLAGS += --silent

FEDORA_TOOLBOX := registry.fedoraproject.org/fedora-toolbox
WORKING_CONTAINER := fedora-toolbox-working-container

CLI_INSTALL := bat eza fd-find flatpak-spawn fswatch fzf gh jq rclone ripgrep wl-clipboard yq zoxide
DEV_INSTALL := kitty-terminfo make cmake ncurses-devel openssl-devel perl-core libevent-devel readline-devel gettext-devel intltool 
DEPENDENCIES :=  $(CLI_INSTALL) $(DEV_INSTALL)
# include .env
CORE := init dependencies neovim
## luajit luarocks
BEAM := erlang rebar3

default: $(CORE)

reset:
	buildah rm $(WORKING_CONTAINER) || true
	rm -rf info

init: info/buildah.info
info/buildah.info:
	echo '##[ $@ ]##'
	mkdir -p $(dir $@)
	podman images | grep -oP '$(FEDORA_TOOLBOX)' || buildah pull $(FEDORA_TOOLBOX):latest | tee  $@
	buildah containers | grep -oP $(WORKING_CONTAINER) || buildah from $(FEDORA_TOOLBOX):latest | tee -a $@
	echo

dependencies: info/dependencies.info
info/dependencies.info:
	echo '##[ $@ ]##'
	mkdir -p $(dir $@)
	for item in $(DEPENDENCIES)
	do
	buildah run $(WORKING_CONTAINER) sh -c "dnf -y info installed $${item} &>/dev/null || dnf -y install $${item}"
	done
	buildah run $(WORKING_CONTAINER) sh -c "dnf -y info installed $(DEPENDENCIES) | \
grep -oP '(Name.+:\s\K.+)|(Ver.+:\s\K.+)|(Sum.+:\s\K.+)' | \
paste - - - " | tee $@

## NEOVIM
latest/neovim.json:
	echo '##[ $@ ]##'
	mkdir -p $(dir $@)
	wget -q -O - 'https://api.github.com/repos/neovim/neovim/releases/tags/nightly' > $@

neovim: info/neovim.info
info/neovim.info: latest/neovim.json
	echo '##[ $@ ]##'
	mkdir -p $(dir $@)
	buildah run $(WORKING_CONTAINER) sh -c "rm -rf /tmp/*"
	NAME=$$(jq -r '.name' $< | sed 's/v//')
	URL=$$(jq -r '.tarball_url' $<)
	echo "name: $${NAME}"
	echo "url: $${URL}"
	echo "waiting for download ... "
	buildah run $(WORKING_CONTAINER) sh -c "wget $${URL} -q -O- | tar xz --no-same-owner --strip-components=1 -C /tmp"
	buildah run $(WORKING_CONTAINER) sh -c 'cd /tmp && make && make install'
	buildah run $(WORKING_CONTAINER) sh -c 'nvim -V1 -v' | tee $@

## https://github.com/openresty/luajit2
latest/luajit.json:
	echo '##[ $@ ]##'
	mkdir -p $(dir $@)
	wget -q -O - https://api.github.com/repos/openresty/luajit2/tags |
	jq '.[0]' > $@

luajit: info/luajit.info
info/luajit.info: latest/luajit.json
	echo '##[ $@ ]##'
	NAME=$$(jq -r '.name' $< | sed 's/v//')
	URL=$$(jq -r '.tarball_url' $<)
	echo "name: $${NAME}"
	echo "url: $${URL}"
	buildah run $(WORKING_CONTAINER) sh -c "rm -rf /tmp/*"
	buildah run $(WORKING_CONTAINER) sh -c "wget $${URL} -q -O- | tar xz --strip-components=1 -C /tmp"
	buildah run $(WORKING_CONTAINER) sh -c 'cd /tmp && make && make install'
	buildah run $(WORKING_CONTAINER) ln -sf /usr/local/bin/luajit-$${NAME} /usr/local/bin/luajit
	buildah run $(WORKING_CONTAINER) ln -sf  /usr/local/bin/luajit /usr/local/bin/lua
	buildah run $(WORKING_CONTAINER) ln -sf /usr/local/bin/luajit /usr/local/bin/lua-5.1
	buildah run $(WORKING_CONTAINER) ls -al /usr/local/bin
	buildah run $(WORKING_CONTAINER) sh -c 'luajit -v' | tee $@

latest/luarocks.json:
	echo '##[ $@ ]##'
	mkdir -p $(dir $@)
	wget -q -O - 'https://api.github.com/repos/luarocks/luarocks/tags' |
	jq  '.[0]' > $@

luarocks: info/luarocks.info
info/luarocks.info: latest/luarocks.json
	echo '##[ $@ ]##'
	buildah run $(WORKING_CONTAINER) sh -c "rm -rf /tmp/*"
	NAME=$$(jq -r '.name' $< | sed 's/v//')
	URL=$$(jq -r '.tarball_url' $<)
	echo "name: $${NAME}"
	echo "url: $${URL}"
	echo "waiting for download ... "
	buildah run $(WORKING_CONTAINER) sh -c "wget $${URL} -q -O- | tar xz --strip-components=1 -C /tmp"
	buildah run $(WORKING_CONTAINER) sh -c 'cd /tmp && ./configure --with-lua-include=/usr/local/include'
	buildah run $(WORKING_CONTAINER) sh -c 'cd /tmp && make && make install '
	buildah run $(WORKING_CONTAINER) sh -c 'luarocks config variables.LUA_INCDIR /usr/local/include/luajit-2.1'
	buildah run $(WORKING_CONTAINER) sh -c 'luarocks' | tee $@

## BEAM

latest/erlang.json:
	echo '##[ $@ ]##'
	mkdir -p $(dir $@)
	wget -q -O - https://api.github.com/repos/erlang/otp/releases/latest > $@

erlang: info/erlang.info
info/erlang.info: latest/erlang.json
	echo '##[ $@ ]##'
	jq -r '.tarball_url' $<
	buildah run $(WORKING_CONTAINER) sh -c "rm -rf /tmp/*"
	NAME=$$(jq -r '.name' $< | sed 's/v//')
	URL=$$(jq -r '.tarball_url' $<)
	echo "name: $${NAME}"
	echo "url: $${URL}"
	echo "waiting for download ... "
	buildah run $(WORKING_CONTAINER) sh -c "wget $${URL} -q -O- | tar xz --strip-components=1 -C /tmp"
	buildah run $(WORKING_CONTAINER) sh -c "exa /tmp"
	buildah run $(WORKING_CONTAINER)  /bin/bash -c 'cd /tmp && ./configure \
--without-javac --without-odbc --without-wx --without-debugger --without-observer --without-cdv --without-et'
	buildah run $(WORKING_CONTAINER)  /bin/bash -c 'cd /tmp && make && make install'
	buildah run $(WORKING_CONTAINER) rm -rf /tmp/*
	buildah run $(WORKING_CONTAINER) sh -c 'erl -version' > $@
	echo -n 'OTP Release: ' >> $@
	buildah run $(WORKING_CONTAINER) erl -noshell -eval "erlang:display(erlang:system_info(otp_release)), halt()." >>  $@

latest/elixir.json:
	echo '##[ $@ ]##'
	mkdir -p $(dir $@)
	wget -q -O - https://api.github.com/repos/elixir-lang/elixir/releases/latest > $@

elixir: info/elixir.info
info/elixir.info: latest/elixir.json
	echo '##[ $@ ]##'
	buildah run $(WORKING_CONTAINER) sh -c "rm -rf /tmp/*"
	NAME=$$(jq -r '.name' $< | sed 's/v//')
	URL=$$(jq -r '.tarball_url' $<)
	echo "name: $${NAME}"
	echo "url: $${URL}"
	echo "waiting for download ... "
	buildah run $(WORKING_CONTAINER) sh -c "wget $${URL} -q -O- | tar xz --strip-components=1 -C /tmp"
	buildah run $(WORKING_CONTAINER) sh -c 'cd /tmp && make && make install'
	buildah run $(WORKING_CONTAINER) sh -c 'elixir --version' | tee $@
	buildah run $(WORKING_CONTAINER) sh -c 'mix --version' | tee -a $@

rebar3: info/rebar3.info
info/rebar3.info:
	buildah run $(WORKING_CONTAINER) curl -Ls --output /usr/local/bin/rebar3 https://s3.amazonaws.com/rebar3/rebar3
	buildah run $(WORKING_CONTAINER) chmod +x /usr/local/bin/rebar3
	buildah run $(WORKING_CONTAINER) rebar3 help | tee $@


cosign_version = wget -q -O - 'https://api.github.com/repos/sigstore/cosign/releases/latest' | jq  -r '.name'

cosign: info/cosign.info
info/cosign.info:
	echo '##[ $@ ]##'
	COSIGN_VERSION=$$($(call cosign_version))
	echo " - add cosign from sigstore release version: $${COSIGN_VERSION}"
	SRC=https://github.com/sigstore/cosign/releases/download/$${COSIGN_VERSION}/cosign-linux-amd64
	TARG=/usr/local/bin/cosign
	buildah add --chmod 755 $(WORKING_CONTAINER) $${SRC} $${TARG}
	buildah run $(WORKING_CONTAINER) sh -c '  echo -n " - check: " &&  which cosign'
	buildah run $(WORKING_CONTAINER) cosign | tee $@

host_spawn_version = wget -q -O - 'https://api.github.com/repos/1player/host-spawn/tags' | jq  -r '.[0].name'

host-spawn: info/host-spawn.info
info/host-spawn.info:
	echo '##[ $@ ]##'
	HOST_SPAWN_VERSION=$$($(call host_spawn_version))
	echo " - from src add host-spawn: $${HOST_SPAWN_VERSION}"
	SRC=https://github.com/1player/host-spawn/releases/download/$${HOST_SPAWN_VERSION}/host-spawn-x86_64
	TARG=/usr/local/bin/host-spawn
	buildah add --chmod 755 $(WORKING_CONTAINER) $${SRC} $${TARG}
	buildah run $(WORKING_CONTAINER) sh -c 'echo -n " - check: " &&  which host-spawn'
	buildah run $(WORKING_CONTAINER) sh -c 'echo -n " - host-spawn version: " &&  host-spawn --version' | tee $@
	buildah run $(WORKING_CONTAINER) sh -c 'host-spawn --help' | tee -a $@
	echo ' - add symlinks to exectables on host using host-spawn'
	buildah run $(WORKING_CONTAINER) /bin/bash -c 'ln -fs /usr/local/bin/host-spawn /usr/local/bin/flatpak'
	buildah run $(WORKING_CONTAINER) /bin/bash -c 'ln -fs /usr/local/bin/host-spawn /usr/local/bin/podman'
	buildah run $(WORKING_CONTAINER) /bin/bash -c 'ln -fs /usr/local/bin/host-spawn /usr/local/bin/buildah'
	buildah run $(WORKING_CONTAINER) /bin/bash -c 'ln -fs /usr/local/bin/host-spawn /usr/local/bin/systemctl'
	buildah run $(WORKING_CONTAINER) /bin/bash -c 'ln -fs /usr/local/bin/host-spawn /usr/local/bin/rpm-ostree'

commit:
	podman stop nv || true
	toolbox rm nv || true
	buildah commit $(WORKING_CONTAINER) nv
	toolbox create --image localhost/nv nv

check:
	echo '##[ $@ ]##'
	buildah run $(WORKING_CONTAINER) which gleam
	buildah run $(WORKING_CONTAINER) gleam --help

### Gleam

latest/gleam.download:
	mkdir -p $(dir $@)
	wget -q -O - 'https://api.github.com/repos/gleam-lang/gleam/releases/latest' |
	jq  -r '.assets[].browser_download_url' |
	grep -oP '.+x86_64-unknown-linux-musl.tar.gz$$' > $@

gleam: info/gleam.info
info/gleam.info: latest/gleam.download
	mkdir -p $(dir $@)
	DOWNLOAD_URL=$$(cat $<)
	echo "download url: $${DOWNLOAD_URL}"
	buildah run $(WORKING_CONTAINER)  sh -c "curl -Ls $${DOWNLOAD_URL} | \
tar xzf - --one-top-level="gleam" --strip-components 1 --directory /usr/local/bin"
	buildah run $(WORKING_CONTAINER) gleam --version > $@
	buildah run $(WORKING_CONTAINER) gleam --help >> $@

