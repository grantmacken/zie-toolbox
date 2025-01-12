SHELL       := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

MAKEFLAGS += --warn-undefined-variables
MAKEFLAGS += --no-builtin-rules
MAKEFLAGS += --no-builtin-variables
MAKEFLAGS += --silent
unexport MAKEFLAGS

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

IMAGE    :=  ghcr.io/grantmacken/tbx-cli-tools:latest
CONTAINER := tbx-cli-tools-working-container

TBX_CONTAINER_NAME=tbx-neovim-prerelease

default: init luajit luarocks 

ddddd:
ifdef GITHUB_ACTIONS
	buildah commit $(CONTAINER) $(TBX_CONTAINER_NAME)
	buildah push $(TBX_CONTAINER_NAME)
endif

clean:
	# buildah run $(CONTAINER) dnf leaves
	buildah run $(CONTAINER) dnf remove -y $(REMOVE)
	buildah run $(CONTAINER) dnf autoremove -y
	buildah run $(CONTAINER) rm -rf /tmp/*

init: info/working.info
info/working.info:
	echo '##[ $@ ]##'
	mkdir -p $(dir $@)
	podman images | grep -oP '$(IMAGE)' || buildah pull $(IMAGE) | tee  $@
	buildah containers | grep -oP $(CONTAINER) || buildah from $(IMAGE) | tee -a $@
	echo

##[[ NEOVIM ]]##
neovim: info/neovim.md
info/neovim.md:
	echo '##[ $@ ]##'
	NAME=$(basename $(notdir $@))
	TARGET=files/$${NAME}/usr/local
	mkdir -p $${TARGET}
	SRC="https://github.com/neovim/neovim/releases/download/nightly/nvim-linux64.tar.gz"
	wget $${SRC} -q -O- | tar xz --strip-components=1 -C files/${NAME}/usr/local
	buildah add --chmod 755 $(CONTAINER) files/${NAME} &>/dev/null
	# CHECK:
	buildah run $(CONTAINER) nvim -v
	buildah run $(CONTAINER) whereis nvim
	buildah run $(CONTAINER) which nvim
	# buildah run $(CONTAINER) printenv
	VERSION=$$(buildah run $(CONTAINER) sh -c 'nvim -v' | grep -oP 'NVIM \K.+' | cut -d'-' -f1 )
	printf "| %-10s | %-13s | %-83s |\n" "Neovim"\
		"$$VERSION" "The text editor with a focus on extensibility and usability" | tee -a $@

xcxc:
	printf "\n$(HEADING2) %s\n\n" "Neovim , luajit, luarocks, nlua" | tee $@
	# table header
	# printf "| %-10s | %-13s | %-83s |\n" "--- " "-------" "----------------------------" | tee -a $@
	printf "| %-10s | %-13s | %-83s |\n" "Name" "Version" "Summary" | tee -a $@
	printf "| %-10s | %-13s | %-83s |\n" "----" "-------" "----------------------------" | tee -a $@
	VERSION=$$(buildah run $(CONTAINER) sh -c 'nvim -v' | grep -oP 'NVIM \K.+' | cut -d'-' -f1 )
	# table row
	printf "| %-10s | %-13s | %-83s |\n" "Neovim" "$$VERSION" "The text editor with a focus on extensibility and usability" | tee -a $@

luajit: info/luajit.md
info/luajit.md:
	echo '##[ $@ ]##'
	URL=https://github.com/luajit/luajit/archive/refs/tags/v2.1.ROLLING.tar.gz
	mkdir -p files/luajit
	wget $${URL} -q -O- | tar xz --strip-components=1 -C files/luajit &>/dev/null
	buildah run $(CONTAINER) rm -rf /tmp/*
	buildah add --chmod 755 $(CONTAINER) files/luajit /tmp &>/dev/null
	buildah run $(CONTAINER) sh -c 'cd /tmp && make && make install'
	# buildah run $(CONTAINER) ls -al /usr/local/bin
	buildah run $(CONTAINER) ln -sf /usr/local/bin/luajit-2.1. /usr/local/bin/luajit
	# buildah run $(CONTAINER) mv /usr/local/bin/luajit-2.1. /usr/local/bin/luajit
	buildah run $(CONTAINER) ln -sf /usr/local/bin/luajit /usr/local/bin/lua
		# CHECK:
	buildah run $(CONTAINER) whereis luajit
	buildah run $(CONTAINER) which nvim
	buildah run $(CONTAINER) luajit -v
	VERSION=$$(buildah run $(CONTAINER) sh -c 'luajit -v' | cut -d' ' -f2 )
	printf "| %-10s | %-13s | %-83s |\n" "luajit" "$$VERSION" "built from ROLLING release" | tee $@
	buildah run $(CONTAINER) rm -rf /tmp/*
	# buildah run $(CONTAINER) sh -c 'lua -v' | tee $@

luarocks: info/luarocks.md
latest/luarocks.tag_name:
	# echo '##[ $@ ]##'
	mkdir -p $(dir $@)
	wget -q -O - 'https://api.github.com/repos/luarocks/luarocks/tags' > $@

info/luarocks.md: latest/luarocks.tag_name
	 echo '##[ $@ ]##'
	NAME=$$(jq -r '.name' $< | sed 's/v//')
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

