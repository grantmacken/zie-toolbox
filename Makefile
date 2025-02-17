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

TBX_CONTAINER_NAME=tbx-neovim-dev

DEPS   := gcc glibc-devel ncurses-devel openssl-devel libevent-devel readline-devel gettext-devel
# REMOVE := git
# gcc-c++

default: init config neovim deps luajit luarocks nlua busted clean

config: info/config.md
info/config.md:
	mkdir -p $(dir $@)
	buildah config --env NVIM_APPNAME=nvim $(CONTAINER)
	printf "%s\n" " - set nvim appname" | tee $@
ifdef GITHUB_ACTIONS
	buildah commit $(CONTAINER) $(TBX_CONTAINER_NAME)
	buildah push $(TBX_CONTAINER_NAME)
endif

clean:
	# buildah run $(CONTAINER) dnf leaves
	# buildah run $(CONTAINER) dnf remove -y $(REMOVE)
	buildah run $(CONTAINER) dnf autoremove -y
	buildah run $(CONTAINER) rm -rf /tmp/*

init: info/working.info
info/working.info:
	echo '##[ $@ ]##'
	mkdir -p $(dir $@)
	podman images | grep -oP '$(IMAGE)' || buildah pull $(IMAGE) | tee  $@
	buildah containers | grep -oP $(CONTAINER) || buildah from $(IMAGE) | tee -a $@
	echo

##[[ DEPS ]]##
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
neovim: info/neovim.md
info/neovim.md:
	echo '##[ $@ ]##'
	NAME=$(basename $(notdir $@))
	TARGET=files/$${NAME}/usr/local
	mkdir -p $${TARGET}
	SRC="https://github.com/neovim/neovim/releases/download/nightly/nvim-linux64.tar.gz"
	wget $${SRC} -q -O $${NAME}.tar.gz
	tar xz --strip-components=1 -C $${TARGET} -f $${NAME}.tar.gz
	buildah add --chmod 755 $(CONTAINER) files/$${NAME} &>/dev/null
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
	buildah run $(CONTAINER) sh -c 'cd /tmp && make && make install' &>/dev/null
	buildah run $(CONTAINER) ln -sf /usr/local/bin/luajit-2.1. /usr/local/bin/luajit
	# buildah run $(CONTAINER) mv /usr/local/bin/luajit-2.1. /usr/local/bin/luajit
	buildah run $(CONTAINER) ln -sf /usr/local/bin/luajit /usr/local/bin/lua
	#CHECK:
	buildah run $(CONTAINER) whereis luajit
	buildah run $(CONTAINER) luajit -v
	VERSION=$$(buildah run $(CONTAINER) sh -c 'luajit -v' | cut -d' ' -f2 )
	printf "| %-10s | %-13s | %-83s |\n" "luajit" "$$VERSION" "built from ROLLING release" | tee $@
	buildah run $(CONTAINER) rm -rf /tmp/*
	# buildah run $(CONTAINER) sh -c 'lua -v' | tee $@

luarocks: info/luarocks.md
latest/luarocks.tag_name:
	# echo '##[ $@ ]##'
	mkdir -p $(dir $@)
	wget -q -O - 'https://api.github.com/repos/luarocks/luarocks/tags' | jq -r '.[0]'  > $@

info/luarocks.md: latest/luarocks.tag_name
	 echo '##[ $@ ]##'
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
	buildah run $(CONTAINER) rm -rf /tmp/*
	buildah run $(CONTAINER) luarocks install luarocks &>/dev/null
	#Cean up buildah run $(CONTAINER) luarocks show luarocks
	printf "| %-10s | %-13s | %-83s |\n" "luarocks" "$$NAME" "built from source from latest luarocks tag" | tee $@
	buildah run $(CONTAINER) sh -c 'find /usr/local/share/lua/5.1/luarocks/ -type f -name "*.lua~" -exec rm {} \;'
	buildah run $(CONTAINER) sh -c 'rm /usr/local/bin/luarocks~ /usr/local/bin/luarocks-admin~'
	# CHECK:
	# buildah run $(CONTAINER) which luarocks
	# buildah run $(CONTAINER) whereis luarocks
	# buildah run $(CONTAINER) luarocks


nlua: info/nlua.info
info/nlua.info:
	buildah run $(CONTAINER) luarocks install nlua
	buildah run $(CONTAINER) luarocks show nlua
	buildah run $(CONTAINER) luarocks config lua_version 5.1
	buildah run $(CONTAINER) luarocks config lua_interpreter nlua
	# buildah run $(CONTAINER) luarocks config variables.LUA_INCDIR /usr/local/include/luajit-2.1
	buildah run $(CONTAINER) which nlua
	buildah run $(CONTAINER) whereis nlua
	buildah run $(CONTAINER) luarocks

busted: info/busted.info
info/busted.info:
	buildah run $(CONTAINER) luarocks install busted
	buildah run $(CONTAINER) luarocks show busted
	# buildah run $(CONTAINER) luarocks
	buildah run $(CONTAINER) which busted
	buildah run $(CONTAINER) whereis busted
	buildah run $(CONTAINER) cat usr/local/bin/busted



	# printf "| %-10s | %-13s | %-83s |\n" "nlua" "HEAD" "lua script added from github 'mfussenegger/nlua'" | tee $@
