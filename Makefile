MAKEFLAGS += --warn-undefined-variables
MAKEFLAGS += --no-builtin-rules
MAKEFLAGS += --no-builtin-variables
MAKEFLAGS += --silent
unexport MAKEFLAGS

SHELL       := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

.SUFFIXES:            # Delete the default suffixes
.ONESHELL:            #all lines of the recipe will be given to a single invocation of the shell
.DELETE_ON_ERROR:
.SECONDARY:

HEADING1 := \#
HEADING2 := $(HEADING1)$(HEADING1)
HEADING3 := $(HEADING2)$(HEADING1)

COMMA := ,
EMPTY:=
SPACE := $(EMPTY) $(EMPTY)

IMAGE    := registry.fedoraproject.org/fedora-toolbox:41
CONTAINER := fedora-toolbox-working-container

CLI   := bat direnv eza fd-find fzf gh jq make ripgrep stow wl-clipboard yq zoxide
SPAWN := firefox flatpak podman buildah systemctl rpm-ostree dconf
# common deps used to build luajit and luarocks
DEPS   := gcc gcc-c++ glibc-devel ncurses-devel openssl-devel libevent-devel readline-devel gettext-devel
REMOVE := vim-minimal
# default-editor gcc-c++ gettext-devel  libevent-devel  openssl-devel  readline-devel

default: init cli-tools deps neovim luajit luarocks neovim nlua host-spawn clean

xx1:
ifdef GITHUB_ACTIONS
	buildah commit $(CONTAINER) ghcr.io/grantmacken/zie-toolbox
	buildah push ghcr.io/grantmacken/zie-toolbox
endif

clean:
	# buildah run $(CONTAINER) dnf leaves
	buildah run $(CONTAINER) dnf remove -y $(REMOVE)
	buildah run $(CONTAINER) dnf autoremove -y
	buildah run $(CONTAINER) rm -rf /tmp/*

reset:
	buildah rm $(CONTAINER) || true
	rm -rfv info
	rm -rfv latest
	rm -rfv files

.PHONY: help
help: ## show this help
	@cat $(MAKEFILE_LIST) |
	grep -oP '^[a-zA-Z_-]+:.*?## .*$$' |
	sort |
	awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

init: info/working.info

info/working.info:
	echo '##[ $@ ]##'
	mkdir -p $(dir $@)
	podman images | grep -oP '$(IMAGE)' || buildah pull $(IMAGE) | tee  $@
	buildah containers | grep -oP $(CONTAINER) || buildah from $(IMAGE) | tee -a $@
	echo

cli-tools: info/cli.md
info/cli.md:
	mkdir -p $(dir $@)
	buildah run $(CONTAINER) dnf upgrade -y --minimal
	for item in $(CLI)
	do
	buildah run $(CONTAINER) dnf install \
		--allowerasing \
		--skip-unavailable \
		--skip-broken \
		--no-allow-downgrade \
		-y \
		$${item} &>/dev/null
	done
	printf "$(HEADING2) %s\n\n" "Handpicked CLI tools available in the toolbox" | tee $@
	# printf "| %-13s | %-7s | %-83s |\n" "--- " "-------" "----------------------------" | tee -a $@
	printf "| %-13s | %-7s | %-83s |\n" "Name" "Version" "Summary" | tee -a $@
	printf "| %-13s | %-7s | %-83s |\n" "----" "-------" "----------------------------" | tee -a $@
	buildah run $(CONTAINER) sh -c  'dnf info -q installed $(CLI) | \
	   grep -oP "(Name.+:\s\K.+)|(Ver.+:\s\K.+)|(Sum.+:\s\K.+)" | \
	   paste  - - -  | sort -u ' | \
	   awk -F'\t' '{printf "| %-13s | %-7s | %-83s |\n", $$1, $$2, $$3}' | \
	   tee -a $@
	# printf "| %-13s | %-7s | %-83s |\n" "----" "-------" "----------------------------" | tee -a $@

deps: ## deps for make installs
	echo '##[ $@ ]##'
	for item in $(DEPS)
	do
	buildah run $(CONTAINER) dnf install \
		--allowerasing \
		--skip-unavailable \
		--skip-broken \
		--no-allow-downgrade \
		-y \
		$${item} &>/dev/null
	done

##[[ NEOVIM ]]##
latest/neovim.tagname:
	echo '##[ $@ ]##'
	mkdir -p $(dir $@)
	wget -q -O - 'https://api.github.com/repos/neovim/neovim/releases/latest' |
	jq  '.tag_name' | tr -d '"' > $@

neovim: info/neovim.md
info/neovim.md: latest/neovim.tagname
	echo '##[ $@ ]##'
	VERSION=$$(cat $<)
	printf "neovim version%s \n" "$${VERSION}"
	TARGET=files/$(basename $(notdir $@))/usr/local
	mkdir -p $${TARGET}
	SRC="https://github.com/neovim/neovim/releases/download/$${VERSION}/nvim-linux64.tar.gz"
	wget $${SRC} -q -O- | tar xz --strip-components=1 -C $${TARGET}
	buildah add --chmod 755 $(CONTAINER) $${TARGET} &>/dev/null
	# CHECK:
	buildah run $(CONTAINER) nvim -v
	printf "| %-10s | %-13s | %-83s |\n" "Neovim"\
		"$$VERSION" "The text editor with a focus on extensibility and usability" | tee -a $@


luajit: info/luajit.md
info/luajit.md:
	echo '##[ $@ ]##'
	URL=https://github.com/luajit/luajit/archive/refs/tags/v2.1.ROLLING.tar.gz
	# mkdir -p files/luajit
	wget $${URL} -q -O- | tar xz --strip-components=1 -C files/luajit &>/dev/null
	buildah run $(CONTAINER) rm -rf /tmp/*
	src/luajit
	SRC=https://github.com/neovim/deps/tree/master/src/luajit
	buildah add --chmod 755 $(CONTAINER) /tmp &>/dev/null
	buildah run $(CONTAINER) sh -c 'cd /tmp && make CFLAGS="-DLUAJIT_ENABLE_LUA52COMPAT" && make install'
	# buildah run $(CONTAINER) ls -al /usr/local/bin
	buildah run $(CONTAINER) ln -sf /usr/local/bin/luajit-2.1. /usr/local/bin/luajit
	# buildah run $(CONTAINER) mv /usr/local/bin/luajit-2.1. /usr/local/bin/luajit
	buildah run $(CONTAINER) ln -sf /usr/local/bin/luajit /usr/local/bin/lua
	VERSION=$$(buildah run $(CONTAINER) sh -c 'luajit -v' | cut -d' ' -f2 )
	printf "| %-10s | %-13s | %-83s |\n" "luajit" "$$VERSION" "built from ROLLING release" | tee $@
	# buildah run $(CONTAINER) sh -c 'lua -v' | tee $@

luarocks: info/luarocks.md
latest/luarocks.json:
	# echo '##[ $@ ]##'
	mkdir -p $(dir $@)
	wget -q -O - 'https://api.github.com/repos/luarocks/luarocks/tags' |
	jq  '.[0]' > $@

info/luarocks.md: latest/luarocks.json
	# echo '##[ $@ ]##'
	buildah run $(CONTAINER) rm -rf /tmp/*
	buildah run $(CONTAINER) mkdir -p /etc/xdg/luarocks
	NAME=$$(jq -r '.name' $< | sed 's/v//')
	URL=$$(jq -r '.tarball_url' $<)
	# echo "name: $${NAME}"
	# echo "url: $${URL}"
	mkdir -p files/luarocks
	wget $${URL} -q -O- | tar xz --strip-components=1 -C files/luarocks &>/dev/null
	buildah run $(CONTAINER) rm -rf /tmp/*
	buildah add --chmod 755 $(CONTAINER) files/luarocks /tmp &>/dev/null
	buildah run $(CONTAINER) sh -c 'cd /tmp && ./configure \
	--lua-version=5.1 --with-lua-interpreter=luajit \
	--sysconfdir=/etc/xdg --force-config --disable-incdir-check' &>/dev/null
	buildah run $(CONTAINER) sh -c 'cd /tmp && make && make install' &>/dev/null
	buildah run $(CONTAINER) luarocks
	buildah run $(CONTAINER) rm -rf /tmp/*
	printf "| %-10s | %-13s | %-83s |\n" "luarocks" "$$NAME" "built from source from latest luarocks tag" | tee $@

nlua: info/nlua.info
info/nlua.info:
	SRC=https://raw.githubusercontent.com/mfussenegger/nlua/refs/heads/main/nlua
	TARG=/usr/bin/nlua
	buildah add --chmod 755 $(CONTAINER) $${SRC} $${TARG} &>/dev/null
	printf "| %-10s | %-13s | %-83s |\n" "nlua" "HEAD" "lua script added from github 'mfussenegger/nlua'" | tee $@

## HOST-SPAWN
latest/host-spawn.json:
	# echo '##[ $@ ]##'
	mkdir -p $(dir $@)
	wget -q -O - https://api.github.com/repos/1player/host-spawn/releases/latest |
	jq '.' > $@

host-spawn: info/host-spawn.md
info/host-spawn.md: latest/host-spawn.json
	# echo '##[ $@ ]##'
	NAME=$$(jq -r '.name' $< | sed 's/v//')
	SRC=$$(jq  -r '.assets[].browser_download_url' $< | grep -oP '.+x86_64$$')
	TARG=/usr/local/bin/host-spawn
	buildah add --chmod 755 $(CONTAINER) $${SRC} $${TARG} &>/dev/null
	printf "\n$(HEADING2) %s\n\n" "Host Spawn" | tee $@
	printf "%s\n" "Host-spawn (version: $${NAME}) allows the running of commands on your host machine from inside the toolbox" | tee -a $@
	# close table
	printf "\n%s\n" "The following host executables can be used from this toolbox" | tee -a $@
	for item in $(SPAWN)
	do
	buildah run $(CONTAINER) ln -fs /usr/local/bin/host-spawn /usr/local/bin/$${item}
	printf " - %s\n" "$${item}" | tee -a $@
	done

##[[ NODEJS ]]##

latest/nodejs.tagname:
	echo '##[ $@ ]##'
	mkdir -p $(dir $@)
	wget -q -O - 'https://api.github.com/repos/nodejs/node/releases/latest' | jq '.tag_name' | tee $@

files/node/usr/local/bin/node: latest/nodejs.tagname
	echo '##[ $@ ]##'
	mkdir -p files/$(notdir $@)/usr/local
	TAG=$(shell cat $<)
	SRC=https://nodejs.org/download/release/$${TAG}/node-$${TAG}-linux-x64.tar.gz
	echo "source: $${SRC}"
	wget $${SRC} -q -O- | tar xz --strip-components=1 -C files/$(notdir $@)/usr/local
	buildah add --chmod 755 $(CONTAINER) files/$(notdir $@)/usr/local

nodejs: info/nodejs.md
info/nodejs.md: files/node/usr/local/bin/node
	echo '##[ $@ ]##'
	mkdir -p $(dir $@)
	printf "$(HEADING2) %s\n\n" $(basename $(notdir $@)) > $@
	printf "The toolbox nodejs: %s runtime.\n This is the **latest** prebuilt release\
	available from [node org](https://nodejs.org/download/release/)"  \
	$$(cat latest/nodejs.tagname) >> $@

####################################################

pull:
	podman pull ghcr.io/grantmacken/zie-toolbox:latest

worktree:
	# automatically creates a new branch whose name is the final component of <path>
	git worktree add ../beam_me_up

