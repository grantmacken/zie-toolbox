SHELL=/bin/bash
.ONESHELL:
.SHELLFLAGS := -eu -o pipefail -c
.DELETE_ON_ERROR:
MAKEFLAGS += --warn-undefined-variables
MAKEFLAGS += --no-builtin-rules
MAKEFLAGS += --silent

FEDORA_VER := 40
GROUP_C_DEV := "C Development Tools and Libraries"
INSTALL := make bat eza fd-find flatpak-spawn fswatch fzf gh jq kitty-terminfo ripgrep wl-clipboard yq zoxide
XDG_CONFIG_DIRS := /etc/xdg
XDG_DATA_DIRS   := /usr/local/share:/usr/share
XDG_CONFIG_HOME := /etc/xdg
XDG_CACHE_HOME  := /var/cache
XDG_DATA_HOME   := /usr/local/share
XDG_STATE_HOME  := /var/lib
NVIM_LOG_FILE   := /var/lib/nvim/log

ROCKS_PATH   :=  $(XDG_DATA_HOME)/nvim/rocks
ROCKS_SERVER := https://nvim-neorocks.github.io/rocks-binaries/
LUA_VERSION  := 5.1
LUAROCKS_INSTALL := luarocks --lua-version=$(LUA_VERSION) --tree $(ROCKS_PATH) --server='$(ROCKS_SERVER)' install

# luarocksInstall = buildah run $1 $(LUAROCKS_INSTALL) $1
# nvimRocksInstall = buildah run $1 sh -c 'nvim --headless -c "Rocks install $2" -c "15sleep" -c "qall!"'


# include .env
default: zie-toolbox  ## build the toolbox

# https://github.com/ublue-os/toolboxes/blob/main/toolboxes/bluefin-cli/packages.bluefin-cli
wolfi: ## apk bins from wolfi-dev
	echo '##[ $@ ]##'
	CONTAINER=$$(buildah from cgr.dev/chainguard/wolfi-base:latest)
	# add apk binaries that my toolbox needs (not yet available via dnf)
	buildah run $${CONTAINER} sh -c 'apk add \
	atuin \
	google-cloud-sdk \
	starship \
	uutils'
	# buildah run $${CONTAINER} sh -c 'apk info'
	buildah run $${CONTAINER} sh -c 'apk info google-cloud-sdk'
	buildah run $${CONTAINER} sh -c 'apk info starship'
	buildah run $${CONTAINER} sh -c 'apk info uutils'
	buildah run $${CONTAINER} sh -c 'apk info atuin'
	buildah commit --rm $${CONTAINER} $@ &>/dev/null
	echo ' ------------------------------- '

latest/cosign.version:
	mkdir -p $(dir $@)
	echo -n ' - latest cosign release version: '
	wget -q -O - 'https://api.github.com/repos/sigstore/cosign/releases/latest' |
	jq  -r '.name' | tee $@

latest/luarocks.name:
	mkdir -p $(dir $@)
	wget -q -O - 'https://api.github.com/repos/luarocks/luarocks/tags' | jq  -r '.[0].name' | tee $@

latest/neovim-nightly.json:
	mkdir -p $(dir $@)
	wget -q -O - 'https://api.github.com/repos/neovim/neovim/releases/tags/nightly' > $@

latest/neovim.download: latest/neovim-nightly.json
	mkdir -p $(dir $@)
	jq -r '.assets[].browser_download_url' $< | grep nvim-linux64.tar.gz  | head -1 | tee $@

neovim: latest/neovim.download
	jq -r '.tag_name' latest/neovim-nightly.json
	jq -r '.name' latest/neovim-nightly.json
	CONTAINER=$$(buildah from cgr.dev/chainguard/wolfi-base)
	buildah run $${CONTAINER} sh -c 'apk add wget'
	echo -n 'download: ' && cat $<
	cat $< | buildah run $${CONTAINER} sh -c 'cat - | wget -q -O- -i- | tar xvz -C /usr/local' &>/dev/null
	buildah run $${CONTAINER} sh -c 'ls -al /usr/local' || true
	buildah commit --rm $${CONTAINER} $@

luarocks: latest/luarocks.name
	echo '##[ $@ ]##'
	CONTAINER=$$(buildah from cgr.dev/chainguard/wolfi-base:latest)
	buildah config --workingdir /home/nonroot $${CONTAINER}
	buildah run $${CONTAINER} sh -c 'mkdir /app && apk add \
	build-base \
	readline-dev \
	autoconf \
	luajit \
	luajit-dev \
	wget'
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
		--with-lua=/usr/bin \
		--with-lua-bin=/usr/bin \
		--with-lua-lib=/usr/lib \
		--with-lua-include=/usr/include/lua' &>/dev/null
	buildah run $${CONTAINER} sh -c 'make & make install' &>/dev/null
	buildah run $${CONTAINER} sh -c 'which luarocks'
	buildah commit --rm $${CONTAINER} $@ &>/dev/null
	echo '-------------------------------'

zie-toolbox: neovim luarocks latest/cosign.version
	buildah pull registry.fedoraproject.org/fedora-toolbox:$(FEDORA_VER)
	CONTAINER=$$(buildah from registry.fedoraproject.org/fedora-toolbox:$(FEDORA_VER))
	# buildah run $${CONTAINER} sh -c 'dnf group list --hidden'
	# buildah run $${CONTAINER} sh -c 'dnf group info $(GROUP_C_DEV)' || true
	# buildah run $${CONTAINER} sh -c 'dnf -y group install make &>/dev/null
	# buildah run $${CONTAINER} sh -c 'which make' || true
	buildah run $${CONTAINER} sh -c 'dnf -y install $(INSTALL)' &>/dev/null
	##[ COSIGN ]##
	COSIGN_VERSION=$(shell cat latest/cosign.version)
	echo " - add cosign from sigstore release version: $${COSIGN_VERSION}"
	SRC=https://github.com/sigstore/cosign/releases/download/$${COSIGN_VERSION}/cosign-linux-amd64
	TARG=/usr/local/bin/cosign
	buildah add --chmod 755 $${CONTAINER} $${SRC} $${TARG}
	buildah run $${CONTAINER} sh -c '  echo -n " - check: " &&  which cosign'
	##[ NEOVIM ]##
	echo ' - from container localhost/neovim add neovim'
	buildah add --from localhost/neovim $${CONTAINER} '/usr/local/nvim-linux64' '/usr/local/'  &>/dev/null
	buildah run $${CONTAINER} sh -c 'which nvim && nvim --version'
	##[ LUAROCKS ]##
	echo ' - from container localhost/luarocks add luarocks'
	buildah add --from localhost/luarocks $${CONTAINER} '/usr/local/bin' '/usr/local/bin'
	buildah add --from localhost/luarocks $${CONTAINER} '/usr/local/share/lua' '/usr/local/share/lua'
	buildah add --from localhost/luarocks $${CONTAINER} '/usr/local/etc' '/usr/local/etc'
	buildah add --from localhost/luarocks $${CONTAINER} '/usr/local/lib' '/usr/local/lib'
	buildah add --from localhost/luarocks $${CONTAINER} '/usr/include/lua' '/usr/include/lua'
	buildah add --from localhost/luarocks $${CONTAINER} '/usr/bin/lua*' '/usr/bin/'
	buildah run $${CONTAINER} sh -c 'lua -v'
	buildah run $${CONTAINER} sh -c 'which lua'
	buildah run $${CONTAINER} sh -c 'luarocks'
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
	buildah run $${CONTAINER} sh -c 'nvim --headless -c "lua =vim.g.rocks_nvim.rocks_path" -c "q"'
	buildah run $${CONTAINER} sh -c '$(LUAROCKS_INSTALL) rocks-git.nvim'
	# buildah run $${CONTAINER} sh -c '$(LUAROCKS_INSTALL) rocks-config.nvim'
	buildah run $${CONTAINER} sh -c 'nvim --headless -c "Rocks install oil.nvim" -c "15sleep" -c "q"'
	# buildah run $${CONTAINER} sh -c '$(ROCKS) "Rocks install toggleterm.nvim"'
	# buildah run $${CONTAINER} sh -c '$(ROCKS) "Rocks install mini.nvim"'
	# buildah run $${CONTAINER} sh -c '$(ROCKS) "Rocks install flash.nvim"'
	buildah run $(BUILD_CONTAINER) sh -c 'exa --tree $(XDG_CACHE_HOME)/nvim'
	buildah run $(BUILD_CONTAINER) sh -c 'exa --tree $(XDG_STATE_HOME)/nvim'
	buildah run $(BUILD_CONTAINER) sh -c 'exa --tree $(XDG_DATA_HOME)/nvim/site'
	buildah run $(BUILD_CONTAINER) sh -c 'exa --tree $(XDG_CONFIG_HOME)/nvim'
	buildah commit --rm $${CONTAINER} ghcr.io/grantmacken/$@
# ifdef GITHUB_ACTIONS
# 	buildah push ghcr.io/grantmacken/$@
# endif


installed.json:
	mkdir -p tmp
	echo 'Name,Version,Summary' > tmp/installed.tsv
	dnf info installed $(INSTALL) | grep -oP '(Name.+:\s\K.+)|(Ver.+:\s\K.+)|(Sum.+:\s\K.+)' |
	paste - - - |
	sed '1 i Name\tVersion\tSummary' |
	yq -p=tsv -o=json

pull:
	podman pull ghcr.io/grantmacken/zie-toolbox:latest

run:
	# podman pull registry.fedoraproject.org/fedora-toolbox:40
	toolbox create --image ghcr.io/grantmacken/zie-toolbox tbx
	toolbox enter tbx

reset:
	# podman pull registry.fedoraproject.org/fedora-toolbox:40
	toolbox create --image ghcr.io/grantmacken/zie-toolbox tbx
	toolbox enter tbx
