SHELL=/bin/bash
.ONESHELL:
.SHELLFLAGS := -eu -o pipefail -c
.DELETE_ON_ERROR:
MAKEFLAGS += --warn-undefined-variables
MAKEFLAGS += --no-builtin-rules
MAKEFLAGS += --silent

FEDORA_VER := 40
FEDORA_TOOLBOX := registry.fedoraproject.org/fedora-toolbox
WORKING_CONTAINER := fedora-toolbox-working-container

XDG_CONFIG_DIRS := /etc/xdg
XDG_DATA_DIRS   := /usr/local/share
XDG_CONFIG_HOME := ~/.config
XDG_CACHE_HOME  := ~/.cache
XDG_DATA_HOME   := ~/.local/share
XDG_STATE_HOME  := ~/.local/state

NVIM_APPNAME    := nv
NVIM_LOG_FILE   := $(XDG_STATE_HOME)/$(NVIM_APPNAME).log
PATH_SITE       := $(XDG_DATA_HOME)/$(NVIM_APPNAME)/site
START_PATH      := $(PATH_SITE)/pack/deps/start
OPT_PATH        := $(PATH_SITE)/pack/deps/opt
MINI_URL        := https://github.com/echasnovski/mini.nvim

NVIM_URL := https://github.com/neovim/neovim/releases/download/nightly/nvim-linux64.tar.gz

# LUA_BINDIR   := /usr/bin
# ROCKS_PATH   :=  $(XDG_DATA_HOME)/nvim/rocks
# ROCKS_SERVER := https://nvim-neorocks.github.io/rocks-binaries/
# LUA_VERSION  := 5.1
# LUAROCKS_INSTALL := luarocks --lua-version=$(LUA_VERSION) --tree $(ROCKS_PATH) --server $(ROCKS_SERVER) install
# LUAROCKS_CMD := luarocks --lua-version=$(LUA_VERSION) --tree $(ROCKS_PATH) --server $(ROCKS_SERVER)

CLI_INSTALL := bat eza fd-find flatpak-spawn fswatch fzf gh jq rclone ripgrep wl-clipboard yq zoxide
DEV_INSTALL := kitty-terminfo make ncurses-devel openssl-devel perl-core libevent-devel readline-devel
#TODO rebar3
# libtermcap-devel ncurses-devel libevent-devel readline-devel
# [system agents] [DEPENDENCIES]
DEPENDENCIES :=  $(CLI_INSTALL) $(DEV_INSTALL)
# luarocksinstall = buildah run $1 $(luarocks_install) $1
# nvimrocksinstall = buildah run $1 sh -c 'nvim --headless -c "rocks install $2" -c "15sleep" -c "qall!"'

# include .env
default: build ## build the toolbox
build: init dependencies neovim

reset:
	buildah rm $(WORKING_CONTAINER) || true
	rm -rf info


latest: latest/cosign.version latest/luarocks.version latest/neovim.download

latest/neovim-nightly.json:
	mkdir -p $(dir $@)
	wget -q -O - 'https://api.github.com/repos/neovim/neovim/releases/tags/nightly' > $@

latest/neovim.download: latest/neovim-nightly.json
	mkdir -p $(dir $@)
	jq -r '.assets[].browser_download_url' $< | grep nvim-linux64.tar.gz  | head -1 | tee $@

pull:
	buildah pull $(FEDORA_TOOLBOX):latest


init: info/buildah.info
info/buildah.info:
	mkdir -p info
	podman images | grep -oP '$(FEDORA_TOOLBOX)' || buildah pull $(FEDORA_TOOLBOX):latest | tee  $@
	buildah containers | grep -oP $(WORKING_CONTAINER) || buildah from $(FEDORA_TOOLBOX):$(FEDORA_VER) | tee -a $@
	echo

dependencies: info/dependencies.info
info/dependencies.info:
	for item in $(DEPENDENCIES)
	do
	buildah run $(WORKING_CONTAINER) sh -c "dnf -y info installed $${item} &>/dev/null || dnf -y install $${item}"
	done
	buildah run $(WORKING_CONTAINER) sh -c "dnf -y info installed $(DEPENDENCIES) | \
grep -oP '(Name.+:\s\K.+)|(Ver.+:\s\K.+)|(Sum.+:\s\K.+)' | \
paste - - - " | tee $@


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
	buildah run $(WORKING_CONTAINER) sh -c "rm -rf /tmp/*"
	buildah run $(WORKING_CONTAINER) ln -sf /usr/local/bin/luajit-$${NAME} /usr/local/bin/luajit
	buildah run $(WORKING_CONTAINER) ln -sf  /usr/local/bin/luajit /usr/local/bin/lua
	buildah run $(WORKING_CONTAINER) ls -al /usr/local/bin


latest/luarocks.json: 
	echo '##[ $@ ]##'
	mkdir -p $(dir $@)
	wget -q -O - 'https://api.github.com/repos/luarocks/luarocks/tags' |
	jq  '.[0]' > $@


luarocks: info/luarocks.info
info/luarocks.info: latest/luarocks.json
	echo '##[ $@ ]##'
	buildah run $(WORKING_CONTAINER) sh -c "rm -rf /tmp/*"
	buildah run $(WORKING_CONTAINER) sh -c 'ln -sf /usr/local/bin/luajit /usr/local/bin/lua-5.1'
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
	buildah run $(WORKING_CONTAINER) sh -c "rm -rf /tmp/*"


rebar3: info/rebar3.info
info/rebar3.info:
	buildah run $(WORKING_CONTAINER) curl -Ls --output /usr/local/bin/rebar3 https://s3.amazonaws.com/rebar3/rebar3
	buildah run $(WORKING_CONTAINER) chmod +x /usr/local/bin/rebar3
	buildah run $(WORKING_CONTAINER) rebar3 help | tee $@

neovim: info/neovim.info
info/neovim.info: latest/neovim.download
	echo -n 'release tag: ' && jq -r '.tag_name' latest/neovim-nightly.json
	echo -n 'release name: ' && jq -r '.name' latest/neovim-nightly.json
	DOWNLOAD_URL=$$(cat $<)
	echo "download url: $${DOWNLOAD_URL}"
	buildah run $(WORKING_CONTAINER) sh -c "wget $${DOWNLOAD_URL} -q -O- | tar xz --strip-components=1 -C /usr/local"
	nvim -v | tee $@

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



#################
### HOME
################

mini: info/mini.info
info/mini.info:
	[ -d $(START_PATH)/mini.lua ] || git clone --filter=blob:none $(MINI_URL) $(START_PATH)/mini.lua
	cat $(START_PATH)/mini.lua/README.md | tee $@

conf:
	echo '##[ $@ ]##'
	mkdir -p $(XDG_CONFIG_HOME)/$(NVIM_APPNAME)/
	cp -rf files/config/nvim/* $(XDG_CONFIG_HOME)/$(NVIM_APPNAME)/
	exa --tree $(XDG_CONFIG_HOME)/$(NVIM_APPNAME)
	buildah config \
--env NVIM_APPNAME=$(NVIM_APPNAME) \
--env TERM=xterm-256color \
--env LANG=C.UTF-8 $(WORKING_CONTAINER)

nv:
	buildah config \
--env XDG_CONFIG_DIRS=$(XDG_CONFIG_DIRS) \
--env XDG_DATA_DIRS=$(XDG_DATA_DIRS) \
--env XDG_CACHE_HOME=$(XDG_CACHE_HOME) \
--env XDG_CONFIG_HOME=$(XDG_CONFIG_HOME) \
--env XDG_DATA_HOME=$(XDG_DATA_HOME) \
--env XDG_STATE_HOME=$(XDG_STATE_HOME) \
--env NVIM_APPNAME=$(NVIM_APPNAME) \
--env NVIM_LOG_FILE=$(NVIM_LOG_FILE) \
--env TERM=xterm-256color \
--env LANG=C.UTF-8 $(WORKING_CONTAINER)
	# buildah add $(WORKING_CONTAINER)  './files/etc/xdg/nvim' '$(XDG_CONFIG_HOME)/nvim'
	# buildah run $(WORKING_CONTAINER) sh -c 'exa --tree $(XDG_CONFIG_HOME)/nvim'
	# buildah run $(WORKING_CONTAINER) sh -c 'exa $(START_PATH)'
	buildah run $(WORKING_CONTAINER) printenv
	buildah commit $(WORKING_CONTAINER) $@
	podman images | grep $@


packadd:
	#buildah run $(WORKING_CONTAINER) nvim --headless -c 'packadd mini.nvim | helptags ALL' -c '1sleep' -c 'q'
	buildah run $(WORKING_CONTAINER) exa $(START_PATH)

eco:
	buildah run $(WORKING_CONTAINER) nvim --headless -c 'echo "hi"' -c '5sleep' -c 'q'

remote:
	buildah run $(WORKING_CONTAINER) nvim
	# buildah run $(WORKING_CONTAINER) nvim --headlesss --listen /tmp/nvim.pipe 




	# buildah run $(WORKING_CONTAINER)  /bin/bash -c 'cd /tmp && ./configure --help'


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


ROCKS_CORE := rocks-git.nvim rocks-config.nvim rocks-lazy.nvim rocks-treesitter.nvim
ROCKS_DEV := kanagawa.nvim

# rocks-git.nvim for installing from git repositories.
# rocks-config.nvim for plugin configuration.
# rocks-lazy.nvim for lazy-loading.
# rocks-treesitter.nvim for automatic tree-sitter parser management.

neorocks:
	echo '##[ $@ ]##'
	# buildah run $(WORKING_CONTAINER) sh -c 'nvim --headless -c "Rocks install fzf-lua " -c "1sleep" -c "q"'
	buildah run $(WORKING_CONTAINER) $(LUAROCKS_INSTALL) rocks-git.nvim
	for rock in $(ROCKS_CORE)
	do
	buildah run $(WORKING_CONTAINER) nvim --headless -c "Rocks install $${rock}"  -c "5sleep"  -c "q"
	done
	buildah run $(WORKING_CONTAINER) nvim --headless -c "Rocks install sync"  -c "5sleep"  -c "q"


toml: files/etc/xdg/nvim/rocks.toml
files/etc/xdg/nvim/rocks.toml:
	buildah run $(WORKING_CONTAINER) cat $(XDG_CONFIG_HOME)/nvim/rocks.toml

open:
	buildah run $(WORKING_CONTAINER) nvim --server $(XDG_CACHE_HOME)/nvim/server.pipe



send:
	buildah run $(WORKING_CONTAINER) nvim --server $(XDG_CACHE_HOME)/nvim/server.pipe --remote-expr 'vim.print("hi")'

list:
	buildah run $(WORKING_CONTAINER) $(LUAROCKS_CMD) list

search:
	buildah run $(WORKING_CONTAINER) $(LUAROCKS_CMD) search kanagawa.nvim

#
#
# buildah run $${CONTAINER} sh -c 'nvim --headless -c "Rocks install fzf-lua " -c "1sleep" -c "q"'
# buildah run $${CONTAINER} sh -c 'nvim --headless -c "Rocks install flash.nvim" -c "10sleep" -c "q"'
# buildah run $${CONTAINER} sh -c 'nvim --headless -c "Rocks install kanagawa.nvim" -c "10sleep" -c "q"'
# buildah run $${CONTAINER} sh -c 'nvim --headless -c "Rocks install toggleterm.nvim" -c "10sleep" -c "q"'
# buildah run $${CONTAINER} sh -c 'nvim --headless -c "Rocks install gitsigns.nvim" -c "10sleep" -c "q"'
# buildah run $${CONTAINER} sh -c 'nvim --headless -c "Rocks install mini.nvim" -c "10sleep" -c "q"'
# buildah run $${CONTAINER} sh -c 'nvim --headless -c "Rocks install conform.nvim" -c "10sleep" -c "q"#





###################################################################
#buildah run $(WORKING_CONTAINER)  sh -c 'dnf clean all'


	# buildah run $(WORKING_CONTAINER) pwd


xxx:
	CONTAINER=$(WORKING_CONTAINER)
	buildah config --workingdir /home/nonroot $${CONTAINER} 
	buildah run $${CONTAINER} sh -c 'mkdir -p /app && apk add \
	readline-dev \
	autoconf \
	luajit \
	luajit-dev'
	buildah run $${CONTAINER} sh -c 'lua -v'
	echo '##[ ----------include----------------- ]##'
	buildah run $${CONTAINER} sh -c 'ls -al /usr/include' | grep lua
	echo '##[ -----------lib ------------------- ]##'
	buildah run $${CONTAINER} sh -c 'ls /usr/lib' | grep lua
	VERSION=$(shell cat $< | cut -c 2-)
	echo "luarocks version: $${VERSION}"
	URL=https://github.com/luarocks/luarocks/archive/refs/tags/v$${VERSION}.tar.gz
	echo "luarocks URL: $${URL}"
	buildah run $${CONTAINER} sh -c "wget -qO- $${URL} | tar xvz" &>/dev/null
	buildah config --workingdir /home/nonroot/luarocks-$${VERSION} $${CONTAINER}
	buildah run $${CONTAINER} sh -c './configure \
		--lua-version=$(LUA_VERSION)  \
		--with-lua-bin=/usr/bin \
		--with-lua-lib=/usr/lib \
		--with-lua-include=/usr/include/lua' &>/dev/null
	buildah run $${CONTAINER} sh -c 'make & make install' &>/dev/null
	buildah run $${CONTAINER} sh -c 'which luarocks'
	# buildah commit --rm $${CONTAINER} $@ &>/dev/null
	echo '-------------------------------'



zie-toolbox: latest neovim
	CONTAINER=$$(buildah from registry.fedoraproject.org/fedora-toolbox:$(FEDORA_VER))
	echo ' - dnf install command line utils'
	buildah run $${CONTAINER} sh -c 'dnf -y install $(DNF_INSTALL)'
	buildah run $${CONTAINER} sh -c 'which make' || true
	buildah run $${CONTAINER} sh -c 'ln -s /usr/bin/luajit /usr/bin/lua'
	buildah run $${CONTAINER} sh -c 'lua -v'
	buildah run $${CONTAINER} sh -c 'which lua'
	# buildah run $${CONTAINER} sh -c 'exa --tree /usr/lib' || true
	# buildah run $${CONTAINER} sh -c 'exa --tree /usr/bin' || true
	buildah run $${CONTAINER} sh -c 'exa --tree /usr/include/lua' || true
	VERSION=$(shell cat latest/luarocks.version | cut -c 2-)
	echo "luarocks version: $${VERSION}"
	URL=https://github.com/luarocks/luarocks/archive/refs/tags/$${VERSION}.tar.gz
	echo "luarocks URL: $${URL}"
	buildah run $${CONTAINER} sh -c "cd /tmp && wget -qO- $${URL} | tar xvz" &>/dev/null
	buildah config --workingdir /tmp/luarocks-$${VERSION} $${CONTAINER}
	buildah run $${CONTAINER} sh -c './configure \
		--with-lua=/usr/bin \
		--with-lua-bin=/usr/bin \
		--with-lua-lib=/usr/lib \
		--with-lua-include=/usr/include/lua'
	buildah run $${CONTAINER} sh -c 'make & make install' &>/dev/null
	buildah config --workingdir / $${CONTAINER}
	buildah run $${CONTAINER} sh -c 'rm /tmp/*' &>/dev/null

sddd:
	##[ LUAROCKS ]##
	buildah run $${CONTAINER} sh -c 'make & make install' &>/dev/null
	buildah config --workingdir /tmp/luarocks-$${VERSION} $${CONTAINER}
	# echo ' - from container localhost/luarocks add luarocks'
	# buildah add --from localhost/luarocks $${CONTAINER} '/usr/local/bin' '/usr/local/bin'
	# buildah add --from localhost/luarocks $${CONTAINER} '/usr/local/share/lua' '/usr/local/share/lua'
	# buildah add --from localhost/luarocks $${CONTAINER} '/usr/local/etc' '/usr/local/etc'
	# buildah add --from localhost/luarocks $${CONTAINER} '/usr/local/lib' '/usr/local/lib'
	# buildah add --from localhost/luarocks $${CONTAINER} '/usr/include/lua' '/usr/include/lua'
	# buildah add --from localhost/luarocks $${CONTAINER} '/usr/bin/lua*' '/usr/bin/'
	buildah run $${CONTAINER} sh -c 'luarocks'
	do
	buildah run $(WORKING_CONTAINER) sh -c "dnf -y info installed $${item} &>/dev/null || dnf -y install $${item}"
	done


sdsdsd:

	##[ NEOVIM ]##
	echo ' - from container localhost/neovim add neovim'
	buildah add --from localhost/neovim $${CONTAINER} '/usr/local/nvim-linux64' '/usr/local/'  &>/dev/null
	buildah run $${CONTAINER} sh -c 'which nvim && nvim --version'
	##[ HOST SPAWN ]##
	HOST_SPAWN_VERSION=$(shell wget -q -O - 'https://api.github.com/repos/1player/host-spawn/tags' | jq  -r '.[0].name')
	echo " - from src add host-spawn: $${HOST_SPAWN_VERSION}"
	SRC=https://github.com/1player/host-spawn/releases/download/$${HOST_SPAWN_VERSION}/host-spawn-x86_64
	TARG=/usr/local/bin/host-spawn
	buildah add --chmod 755 $${CONTAINER} $${SRC} $${TARG}
	buildah run $${CONTAINER} /bin/bash -c 'which host-spawn'
	echo ' - add symlinks to exectables on host using host-spawn'
	buildah run $${CONTAINER} /bin/bash -c 'ln -fs /usr/local/bin/host-spawn /usr/local/bin/flatpak'
	buildah run $${CONTAINER} /bin/bash -c 'ln -fs /usr/local/bin/host-spawn /usr/local/bin/podman'
	buildah run $${CONTAINER} /bin/bash -c 'ln -fs /usr/local/bin/host-spawn /usr/local/bin/buildah'
	buildah run $${CONTAINER} /bin/bash -c 'ln -fs /usr/local/bin/host-spawn /usr/local/bin/systemctl'
	buildah run $${CONTAINER} /bin/bash -c 'ln -fs /usr/local/bin/host-spawn /usr/local/bin/rpm-ostree'
	buildah run $${CONTAINER} /bin/bash -c 'ln -fs /usr/local/bin/host-spawn /usr/local/bin/brew'
	# with brew I have installed gleam
	buildah run $${CONTAINER} /bin/bash -c 'ln -fs /usr/local/bin/host-spawn /usr/local/bin/gleam'
	buildah run $${CONTAINER} /bin/bash -c 'which host-spawn'
	# continue
	buildah config \
		--env NVIM_LOG_FILE=$(NVIM_LOG_FILE) \
		--env XDG_CACHE_HOME=$(XDG_CACHE_HOME) \
		--env XDG_CONFIG_HOME=$(XDG_CONFIG_HOME) \
		--env XDG_DATA_HOME=$(XDG_DATA_HOME) \
		--env XDG_STATE_HOME=$(XDG_STATE_HOME) \
		--env TERM=xterm-256color \
		$${CONTAINER}
	buildah run $${CONTAINER} sh -c \
		'mkdir -v -p \
		$(XDG_CACHE_HOME)/nvim \
		$(XDG_CONFIG_HOME)/nvim \
		$(XDG_DATA_HOME)/nvim \
		$(XDG_STATE_HOME)/nvim'
	buildah add $${CONTAINER} './files/etc/xdg/nvim' '/etc/xdg/nvim'
	buildah run $${CONTAINER} sh -c 'ls -alR /etc/xdg/nvim'
	echo && echo '------------------------------'
	buildah run $${CONTAINER} sh -c 'luarocks --lua-version=$(LUA_VERSION) --tree $(ROCKS_PATH) --server $(ROCKS_SERVER) install rocks.nvim'
	sleep 5
	buildah run $${CONTAINER} sh -c 'nvim --headless -c "lua =vim.g.rocks_nvim.rocks_path" -c "q"'
	buildah run $${CONTAINER} sh -c 'nvim --headless -c "Rocks install oil.nvim" -c "5sleep" -c "q"'
	# buildah run $${CONTAINER} sh -c 'nvim --headless -c "Rocks install fzf-lua " -c "1sleep" -c "q"'
	# buildah run $${CONTAINER} sh -c 'nvim --headless -c "Rocks install flash.nvim" -c "10sleep" -c "q"'
	# buildah run $${CONTAINER} sh -c 'nvim --headless -c "Rocks install kanagawa.nvim" -c "10sleep" -c "q"'
	# buildah run $${CONTAINER} sh -c 'nvim --headless -c "Rocks install toggleterm.nvim" -c "10sleep" -c "q"'
	# buildah run $${CONTAINER} sh -c 'nvim --headless -c "Rocks install gitsigns.nvim" -c "10sleep" -c "q"'
	# buildah run $${CONTAINER} sh -c 'nvim --headless -c "Rocks install mini.nvim" -c "10sleep" -c "q"'
	# buildah run $${CONTAINER} sh -c 'nvim --headless -c "Rocks install conform.nvim" -c "10sleep" -c "q"'
	# # treesitter so libs preinstalled /usr/local/lib/nvim/parsers 
	# #  bash.so  c.so  lua.so  markdown_inline.so  markdown.so  python.so  query.so  vimdoc.so  vim.so
	# buildah run $${CONTAINER} sh -c 'nvim --headless -c "Rocks install tree-sitter-toml dev" -c "10sleep" -c "q"'
	# buildah run $${CONTAINER} sh -c 'nvim --headless -c "Rocks install tree-sitter-gleam dev" -c "10sleep" -c "q"'
	buildah run $${CONTAINER} sh -c 'exa --tree $(XDG_CACHE_HOME)/nvim' || true
	buildah run $${CONTAINER} sh -c 'exa --tree $(XDG_STATE_HOME)/nvim' || true
	buildah run $${CONTAINER} sh -c 'exa --tree $(XDG_DATA_HOME)/nvim/site' || true
	buildah run $${CONTAINER} sh -c 'exa --tree $(XDG_CONFIG_HOME)/nvim' || true
	buildah commit --rm $${CONTAINER} ghcr.io/grantmacken/$@
# ifdef GITHUB_ACTIONS
# 	buildah push ghcr.io/grantmacken/$@
# endif

