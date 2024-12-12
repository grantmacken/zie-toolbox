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

COMMA := ,
EMPTY:=
SPACE := $(EMPTY) $(EMPTY)

IMAGE    := registry.fedoraproject.org/fedora-toolbox:41
CONTAINER := fedora-toolbox-working-container

CLI   := bat direnv eza fd-find fzf gh jq make ripgrep stow wl-clipboard yq zoxide
SPAWN := firefox flatpak podman buildah systemctl rpm-ostree dconf
# common deps used to build luajit and luarocks
DEPS := gcc gcc-c++ glibc-devel ncurses-devel openssl-devel libevent-devel readline-devel gettext-devel
REMOVE := vim-minimal default-editor gcc-c++ gettext-devel  libevent-devel  openssl-devel  readline-devel
# luarocks removed

default: init cli-tools neovim deps luajit luarocks 

# neovim
# cli-tools host-spawn neovim nlua
#  host-spawn deps luajit luarocks nlua nodejs clean ## build the toolbox
dddd:
ifdef GITHUB_ACTIONS
	buildah commit $(CONTAINER) ghcr.io/grantmacken/zie-toolbox
	buildah push ghcr.io/grantmacken/zie-toolbox
endif

clean:
	# buildah run $(CONTAINER) dnf leaves
	# buildah run $(CONTAINER) dnf autoremove
	buildah run $(CONTAINER) dnf remove -y $(REMOVE)
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
	echo '##[ $@ ]##'
	mkdir -p $(dir $@)
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
	printf "| %-13s | %-7s | %-83s |\n" "--- " "-------" "----------------------------"
	printf "| %-13s | %-7s | %-83s |\n" "Name" "Version" "Summary" | tee $@
	printf "| %-13s | %-7s | %-83s |\n" "----" "-------" "----------------------------"
	buildah run $(CONTAINER) sh -c  'dnf info -q installed $(CLI) | \
	   grep -oP "(Name.+:\s\K.+)|(Ver.+:\s\K.+)|(Sum.+:\s\K.+)" | \
	   paste  - - - ' | \
	   awk -F'\t' '{printf "| %-13s | %-7s | %-83s |\n", $$1, $$2, $$3}' | \
	   tee -a $@
	printf "| %-13s | %-7s | %-83s |\n" "----" "-------" "----------------------------" | tee -a $@


# https://github.com/kodepandai/awesome-gh-cli-extensions

##[[ NEOVIM ]]##
neovim: info/neovim.md

latest/neovim.json:
	# echo '##[ $@ ]##'
	mkdir -p $(dir $@)
	wget -q -O - 'https://api.github.com/repos/neovim/neovim/releases/tags/nightly' > $@

files/nvim/usr/local/bin/nvim: latest/neovim.json
	# echo '##[ $@ ]##'
	mkdir -p files/$(notdir $@)/usr/local
	SRC=$$(jq  -r '.assets[].browser_download_url' $< | grep -oP '.+nvim-linux64.tar.gz$$')
	echo "source: $${SRC}"
	wget $${SRC} -q -O- | tar xz --strip-components=1 -C files/$(notdir $@)/usr/local
	buildah add --chmod 755 $(CONTAINER) files/$(notdir $@)/usr/local

info/neovim.md: files/nvim/usr/local/bin/nvim
	printf "$(HEADING2) %s\n\n" "Neovim , luajit, luarocks, nlua" | tee $@
	printf "| %-13s | %-7s | %-83s |\n" "--- " "-------" "----------------------------"
	printf "| %-13s | %-7s | %-83s |\n" "Name" "Version" "Summary" | tee $@
	printf "| %-13s | %-7s | %-83s |\n" "----" "-------" "----------------------------"
	VERSION=$$(buildah run $(CONTAINER) sh -c 'nvim -v' | grep -oP 'NVIM \K.+')
	printf "| %-13s | %-7s | %-83s |\n" "Neovim" "$$VERSION" "Vim-fork focused on extensibility and usability" | tee $@


deps: ## deps for make installs
	# echo '##[ $@ ]##'
	# mkdir -p $(dir $@)
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

## https://github.com/openresty/luajit2
luajit: info/luajit.md
latest/luajit.json:
	# echo '##[ $@ ]##'
	mkdir -p $(dir $@)
	wget -q -O - https://api.github.com/repos/openresty/luajit2/tags |
	jq '.[0]' > $@

info/luajit.md: latest/luajit.json
	# echo '##[ $@ ]##'
	NAME=$$(jq -r '.name' $< | sed 's/v//')
	URL=$$(jq -r '.tarball_url' $<)
	#echo "name: $${NAME}"
	#echo "url: $${URL}"
	mkdir -p files/luajit
	wget $${URL} -q -O- | tar xz --strip-components=1 -C files/luajit &>/dev/null
	buildah run $(CONTAINER) rm -rf /tmp/*
	buildah add --chmod 755 $(CONTAINER) files/luajit /tmp
	buildah run $(CONTAINER) sh -c 'cd /tmp && make && make install' &>/dev/null
	buildah run $(CONTAINER) ln -sf /usr/local/bin/luajit-$${NAME} /usr/local/bin/luajit
	VERSION=$$(buildah run $(CONTAINER) sh -c 'luajit -v' | cut -d' ' -f2 )
	printf "| %-13s | %-7s | %-83s |\n" "luajit" "$$VERSION" "built from openresty fork" | tee $@
	# buildah run $(CONTAINER) sh -c 'lua -v' | tee $@

luarocks: info/luarocks.md
latest/luarocks.json:
	echo '##[ $@ ]##'
	mkdir -p $(dir $@)
	wget -q -O - 'https://api.github.com/repos/luarocks/luarocks/tags' |
	jq  '.[0]' > $@

info/luarocks.md: latest/luarocks.json
	echo '##[ $@ ]##'
	buildah run $(CONTAINER) rm -rf /tmp/*
	buildah run $(CONTAINER) mkdir -p /etc/xdg/luarocks
	NAME=$$(jq -r '.name' $< | sed 's/v//')
	URL=$$(jq -r '.tarball_url' $<)
	# echo "name: $${NAME}"
	# echo "url: $${URL}"
	mkdir -p files/luarocks
	wget $${URL} -q -O- | tar xz --strip-components=1 -C files/luarocks
	buildah run $(CONTAINER) rm -rf /tmp/*
	buildah add --chmod 755 $(CONTAINER) files/luarocks /tmp
	buildah run $(CONTAINER) sh -c 'cd /tmp && ./configure \
	--lua-version=5.1 --with-lua-interpreter=luajit \
	--sysconfdir=/etc/xdg --force-config --disable-incdir-check' &>/dev/null
	buildah run $(CONTAINER) sh -c 'cd /tmp && make && make install' &>/dev/null
	buildah run $(CONTAINER) rm -rf /tmp/*
	buildah run $(CONTAINER) sh -c "luarocks --version | grep -oP '^LuaRocks.+' | sed 's/,//' | paste - - -" | \
	   awk -F'\t' '{printf "| %-13s | %-7s | %-83s |\n", $$1, $$2, $$3}' | \
	   tee -a $@
	# printf "%s\n" "$$(buildah run $(CONTAINER) luarocks)" | grep -oP 'Luarocks.+'| tee  $@
	#buildah run $(CONTAINER) sh -c 'luarocks install busted'
	#buildah run $(CONTAINER) sh -c 'whereis busted'

nlua: info/nlua.info
info/nlua.info:
	SRC=https://raw.githubusercontent.com/mfussenegger/nlua/refs/heads/main/nlua
	TARG=/usr/bin/nlua
	buildah add --chmod 755 $(CONTAINER) $${SRC} $${TARG}
	# buildah run $(CONTAINER) luarocks install nlua
	# confirm it is working
	buildah run $(CONTAINER) sh -c 'echo "print(1 + 2)" | nlua'
	buildah run $(CONTAINER) sh -c 'luarocks config lua_interpreter nlua'
	# buildah run $(CONTAINER) sh -c 'luarocks'
	buildah run $(CONTAINER) sh -c 'cat /etc/xdg/luarocks/config-5.1.lua'
	buildah run $(CONTAINER) sh -c 'whereis luarocks'
	buildah run $(CONTAINER) sh -c 'which luarocks'
	buildah run $(CONTAINER) sh -c 'where is nlua'

## HOST-SPAWN
latest/host-spawn.json:
	echo '##[ $@ ]##'
	mkdir -p $(dir $@)
	wget -q -O - https://api.github.com/repos/1player/host-spawn/releases/latest > $@

host-spawn: info/host-spawn.md
info/host-spawn.md: latest/host-spawn.json
	echo '##[ $@ ]##'
	SRC=$$(jq  -r '.assets[].browser_download_url' $< | grep -oP '.+x86_64$$')
	TARG=/usr/local/bin/host-spawn
	buildah add --chmod 755 $(CONTAINER) $${SRC} $${TARG}
	printf "$(HEADING2) %s\n\n" "host-spawn" > $@
	echo 'With host-spawn we can run commands on your host machine from inside the toolbox' | tee -a $@
	printf "Host-spawn version %s\n " \
	$$(buildah run $(CONTAINER) sh -c 'host-spawn --version') | tee -a $@
	echo 'The following exectables on host can be used from this toolbox' | tee -a $@
	for item in $(SPAWN)
	do
	buildah run $(CONTAINER) ln -fs /usr/local/bin/host-spawn /usr/local/bin/$${item}
	printf " - %s\n" "$${item}" | tee -a $@
	done

	# buildah run $(CONTAINER) nlua -e "print(package.path)"
	# buildah run $(CONTAINER) nlua -e "print(package.cpath)"
	# buildah run $(CONTAINER) nlua -e "print(vim.fn.stdpath('data'))"
	# use nlua as lua interpreter when using luarocks
	# buildah run $(CONTAINER) sed -i 's/luajit/nlua/g' /etc/xdg/luarocks/config-5.1.lua
	# checks
	#

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

readme: info/README.md
info/README.md:
	cat info/toolbox_intro.md | tee $@
	cat info/toolbox_getting_started.md | tee -a $@
	cat info/toolbox_overview.md | tee -a $@
	cat info/neovim.md | tee -a $@
	cat info/nodejs.md | tee -a $@
	# rm info/README.md

pull:
	podman pull ghcr.io/grantmacken/zie-toolbox:latest

worktree:
	# automatically creates a new branch whose name is the final component of <path>
	git worktree add ../beam_me_up
