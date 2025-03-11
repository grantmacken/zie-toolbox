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

FED_IMAGE := registry.fedoraproject.org/fedora-toolbox:latest
CONTAINER := fedora-toolbox-working-container

CLI_IMAGE=ghcr.io/grantmacken/tbx-cli-tools
CLI_CONTAINER_NAME=tbx-cli-tools

# IMAGE    :=  ghcr.io/grantmacken/tbx-cli-tools:latest
# CONTAINER := tbx-cli-tools-working-container

TBX_IMAGE=ghcr.io/grantmacken/zie-toolbox
TBX_CONTAINER_NAME=zie-toolbox

CLI   := bat direnv eza fd-find fzf gh jq make ripgrep stow wl-clipboard yq zoxide
SPAWN := firefox flatpak podman buildah skopeo systemctl rpm-ostree dconf
DEPS  := gcc glibc-devel ncurses-devel openssl-devel libevent-devel readline-devel gettext-devel
BEAM  := erlang elixir
# cargo
REMOVE := default-editor vim-minimal
# gcc-c++ gettext-devel  libevent-devel  openssl-devel  readline-devel

default: init cli-tools deps host-spawn neovim luajit luarocks nlua tiktoken dx clean
ifdef GITHUB_ACTIONS
	buildah config \
	--label summary='a toolbox with cli tools, neovim' \
	--label maintainer='Grant MacKenzie <grantmacken@gmail.com>' \
	--env lang=C.UTF-8 $(CONTAINER)
	buildah commit $(CONTAINER) $(TBX_IMAGE)
	buildah push $(TBX_IMAGE):latest
endif

dx: beam gleam nodejs clean
ifdef GITHUB_ACTIONS
	buildah config \
	--label summary='dx toolbox for the gleam lang' \
	--label maintainer='Grant MacKenzie <grantmacken@gmail.com>' \
	--env lang=C.UTF-8 $(CONTAINER)
	buildah commit $(CONTAINER) $(TBX_IMAGE)-dx
	buildah push $(TBX_IMAGE)-dx:latest
endif

clean:
	buildah run $(CONTAINER) dnf autoremove -y
	buildah run $(CONTAINER) rm -rf /tmp/*

rm:
	buildah rm $(CONTAINER) || true

.PHONY: help
help: ## show this help
	cat $(MAKEFILE_LIST) |
	grep -oP '^[a-zA-Z_-]+:.*?## .*$$' |
	sort |
	awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

init: info/working.info
info/working.info:
	echo '##[ $@ ]##'
	mkdir -p $(dir $@)
	podman images | grep -oP '$(FED_IMAGE)' || buildah pull $(FED_IMAGE)
	buildah containers | grep -oP $(CONTAINER) || buildah from $(FED_IMAGE)
	INFO=$$(buildah run $(CONTAINER) cat /etc/os-release)
	VER=$$(echo "$${INFO}" | grep VERSION_ID | cut -d= -f2) 
	echo "VERSION_ID=$${VER}"
	NEXT=$$(($${VER} + 1))
	echo $${INFO} | tee $@
	echo "RAWHIDE=$${NEXT}" | tee -a $@

	# echo

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

deps: info/deps.md
info/deps.md:
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
	printf "$(HEADING2) %s\n\n" "Development dependencies for make installs" | tee $@
	buildah run $(CONTAINER) sh -c  'dnf info -q installed $(DEPS) | \
	grep -oP "(Name.+:\s\K.+)|(Ver.+:\s\K.+)|(Sum.+:\s\K.+)" | \
	paste  - - -  | sort -u ' | \
	awk -F'\t' '{printf "| %-14s | %-7s | %-83s |\n", $$1, $$2, $$3}' | \
	tee -a $@

## HOST-SPAWN
host-spawn: info/host-spawn.md
latest/host-spawn.json:
	# echo '##[ $@ ]##'
	mkdir -p $(dir $@)
	wget -q -O - https://api.github.com/repos/1player/host-spawn/releases/latest |
	jq '.' > $@

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

##[[ NEOVIM ]]##

neovim: info/neovim.md
info/neovim.md:
	echo '##[ $@ ]##'
	NAME=$(basename $(notdir $@))
	TARGET=files/$${NAME}/usr/local
	mkdir -p $${TARGET}
	printf "\n$(HEADING2) %s\n\n" "$$NAME"
	SRC=https://github.com/neovim/neovim/releases/download/nightly/nvim-linux-x86_64.tar.gz
	printf "\ndownload: %s\n\n" "$$SRC"
	curl -sSL $${SRC} | tar xz --strip-components=1 -C $${TARGET}
	buildah add --chmod 755 $(CONTAINER) files/$${NAME} &>/dev/null
	# CHECK:
	buildah run $(CONTAINER) nvim -v
	buildah run $(CONTAINER) whereis nvim
	buildah run $(CONTAINER) which nvim
	# buildah run $(CONTAINER) printenv
	VERSION=$$(buildah run $(CONTAINER) sh -c 'nvim -v' | grep -oP 'NVIM \K.+' | cut -d'-' -f1 )
	printf "| %-10s | %-13s | %-83s |\n" "Neovim"\
		"$$VERSION" "The text editor with a focus on extensibility and usability" | tee -a $@

luajit: info/luajit.md
info/luajit.md:
	echo '##[ $@ ]##'
	NAME=$(basename $(notdir $@))
	printf "\n$(HEADING2) %s\n\n" "$$NAME"
	buildah run $(CONTAINER) dnf install -y luajit luajit-devel
	VERSION=$$(buildah run $(CONTAINER) sh -c 'luajit -v')
	printf "| %-10s |\n" "$$VERSION" | tee -a $@

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
	#buildah run $(CONTAINER) which luarocks
	#buildah run $(CONTAINER) whereis luarocks
	#buildah run $(CONTAINER) luarocks

nlua: info/nlua.info
info/nlua.info:
	echo '##[ $@ ]##'
	buildah run $(CONTAINER) luarocks install nlua
	buildah run $(CONTAINER) luarocks show nlua
	buildah run $(CONTAINER) luarocks config lua_version 5.1
	## TODO: I think this is redundant as we only have to use the above
	## @see https://github.com/mfussenegger/nlua
	buildah run $(CONTAINER) luarocks config lua_interpreter nlua
	buildah run $(CONTAINER) luarocks config variables.LUA /usr/local/bin/nlua
	# buildah run $(CONTAINER) luarocks config variables.LUA_INCDIR /usr/local/include/luajit-2.1
	buildah run $(CONTAINER) which nlua
	buildah run $(CONTAINER) whereis nlua
	printf "| %-10s | %-13s | %-83s |\n" "nlua" " " "@see https://github.com/mfussenegger/nlua" | tee -a $@
	buildah run $(CONTAINER) luarocks install busted
	printf "| %-10s | %-13s | %-83s |\n" "busted" " " "@see " | tee -a $@

tiktoken: info/tiktoken.info
info/tiktoken.info:
	echo '##[ $@ ]##'
	SRC=https://github.com/gptlang/lua-tiktoken/releases/download/v0.2.3/tiktoken_core-linux-x86_64-lua51.so
	TARG=/usr/local/lib/lua/5.1/tiktoken_core-linux.so
	# nlua -e 'print(package.)'
	buildah add --chmod 755 $(CONTAINER) $${SRC} $${TARG} &>/dev/null
	printf "| %-10s | %-13s | %-83s |\n" "tiktoken" "0.2.3" "The lua module for generating tiktok tokens" | tee -a $@
	# buildah run $(CONTAINER) exa --tree /usr/local/lib/lua/5.1
	# buildah run $(CONTAINER) exa --tree /usr/local/share/lua/5.1

beam: info/beam.info
info/beam.info:
	NAME=$(basename $(notdir $@))
	printf "\n$(HEADING2) %s\n\n" "$$NAME" | tee $@
	cat << EOF | tee -a $@
	The BEAM is the virtual machine at the core of the Erlang Open Telecom Platform (OTP).
	Installed in this toolbox are the Erlang and Elixir programming languages.
	Also installed are the Rebar3 build tool and the Mix build tool for Elixir.
	This tooling is used to develop with the Gleam programming language.
	EOF
	printf "\n%s\n\n" "To get up to date Beam tooling we install from the fedora rawhide registry" | tee -a $@
	buildah run $(CONTAINER) dnf install fedora-repos-rawhide -y &>/dev/null
	RAWHIDE_VER=$$(cat info/working.info | grep RAWHIDE | cut -d= -f2)
	echo "RAWHIDE_VER=$${RAWHIDE_VER}"
	for item in $(BEAM)
	do
	buildah run $(CONTAINER) dnf install --disablerepo=* --enablerepo=rawhide --releasever=$${RAWHIDE_VER} -y $${item}
	done
	echo 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'
	buildah run $(CONTAINER) dnf -y info installed $(BEAM) |
	grep -oP '(Name.+:\s\K.+)|(Ver.+:\s\K.+)|(Sum.+:\s\K.+)' |
	paste - - -  tee $@
	buildah run $(CONTAINER) sh -c 'erl -version' | tee -a $@
	echo -n 'OTP Release: '
	buildah run $(CONTAINER) erl -noshell -eval "erlang:display(erlang:system_info(otp_release)), halt()." | tee -a  $@
	echo -n 'Elixir: ' && buildah run $(CONTAINER) sh -c 'elixir --version'
	echo -n 'Mix: ' && buildah run $(CONTAINER) sh -c 'mix --version'
	SRC=https://s3.amazonaws.com/rebar3-nightly/rebar3
	TARG=/usr/local/bin/rebar3
	buildah add --chmod 755 $(CONTAINER) $${SRC} $${TARG} &>/dev/null
	echo -n 'Rebar3: ' && buildah run $(CONTAINER) sh -c 'rebar3 --version'


##[[ NODEJS ]]##
latest/nodejs.tagname:
	echo '##[ $@ ]##'
	mkdir -p $(dir $@)
	wget -q -O - 'https://api.github.com/repos/nodejs/node/releases/latest' |
	jq '.tag_name' |  tr -d '"' > $@

nodejs: info/nodejs.md
info/nodejs.md: latest/nodejs.tagname
	# echo '##[ $@ ]##'
	printf "\n$(HEADING2) %s\n\n" "Nodejs runtime" | tee $@
	NAME=$(basename $(notdir $@))
	VERSION=$(shell cat $<)
	SRC=https://nodejs.org/download/release/$${VERSION}/node-$${VERSION}-linux-x64.tar.gz
	printf "download URL: %s\n" "$${SRC}"
	TARGET=files/$${NAME}/usr/local
	printf "download TARGET: %s\n" "$${TARGET}"
	mkdir -p $${TARGET}
	wget $${SRC} -q -O- | tar xz --strip-components=1 -C $${TARGET}
	buildah add --chmod 755  $(CONTAINER) files/$${NAME} &>/dev/null
	cat << EOF | tee -a $@
	Gleam can be compiled to javascript and run in the nodejs runtime.
	This toolbox contains the latest nodejs runtime version, 
	sourced from [node org](https://nodejs.org/download/release/$${VERSION})
	EOF

latest/gleam.download:
	mkdir -p $(dir $@)
	wget -q -O - 'https://api.github.com/repos/gleam-lang/gleam/releases/latest' |
	jq  -r '.assets[].browser_download_url' |
	grep -oP '.+x86_64-unknown-linux-musl.tar.gz$$' > $@

gleam: info/gleam.info
info/gleam.info: latest/gleam.download
	mkdir -p $(dir $@)
	NAME=$(basename $(notdir $@))
	TARGET=files/$${NAME}/usr/local/bin
	mkdir -p $${TARGET}
	SRC=$$(cat $<)
	printf " - source: %s \n" "$${SRC}" | tee -a $@
	wget $${SRC} -q -O- | tar xz --strip-components=1 --one-top-level="gleam" -C $${TARGET}
	buildah add --chmod 755 $(CONTAINER) files/$${NAME} &>/dev/null
	printf "$(HEADING1) %s\n\n" "A bundle LSP server and 'runtime' container images" | tee $@
	cat << EOF | tee -a $@
	The main developer experience language this toolbox provides for, is for the Gleam language.
	EOF
	buildah run $(CONTAINER) gleam --help  | tee -a $@

setup:
	podman pull $(TBX_IMAGE):latest
	if toolbox list --containers | grep -q $(TBX_CONTAINER_NAME)
	then
		echo " ---------------------------------------"
		echo " Recreate the toolbox container $(TBX_CONTAINER_NAME) "
		echo " ---------------------------------------"
		echo " - 1: Remove the toolbox container $(TBX_CONTAINER_NAME)"
		toolbox rm -f $(TBX_CONTAINER_NAME)
		echo " - 2: Recreate toolbox from the latest image and"
		echo "      give it the same name as the removed container"
		toolbox create --image $(TBX_IMAGE):latest $(TBX_CONTAINER_NAME)
	else
		echo " -----------------------------------------------------------"
		echo " Create the toolbox container with name: $(TBX_CONTAINER_NAME)  "
		echo " -----------------------------------------------------------"
		toolbox create --image $(TBX_IMAGE):latest $(TBX_CONTAINER_NAME)
	fi


