SHELL       := /usr/bin/bash
.SHELLFLAGS := -eu -o pipefail -c

MAKEFLAGS += --warn-undefined-variables
MAKEFLAGS += --no-builtin-rules
MAKEFLAGS += --no-builtin-variables
MAKEFLAGS += --silent
# MAKEFLAGS += --jobs=$(shell nproc)

unexport MAKEFLAGS

.SUFFIXES:            # Delete the default suffixes
.ONESHELL:            # All lines of the recipe will be given to a single invocation of the shell
.DELETE_ON_ERROR:
.SECONDARY:
# .NOTPARALLEL: .env working info/working.md


HEADING1 := \#
HEADING2 := $(HEADING1)$(HEADING1)
HEADING3 := $(HEADING2)$(HEADING1)

DASH := -
DOT := .
COMMA := ,
EMPTY:=
SPACE := $(EMPTY) $(EMPTY)
include .env
WORKING_CONTAINER ?= fedora-toolbox-working-container
FED_IMAGE := registry.fedoraproject.org/fedora-toolbox
CLI_IMAGE=ghcr.io/grantmacken/tbx-cli-tools
CLI_CONTAINER_NAME=tbx-cli-tools

TBX_IMAGE=ghcr.io/grantmacken/zie-toolbox
TBX_CONTAINER_NAME=zie-toolbox

CLI   := bat direnv eza fd-find fzf gh jq make ripgrep stow wl-clipboard yq zoxide
# autoconf automake binutils # deps include: gcc glibc libstdc++ 
#
DEVEL := gettext-devel \
		glibc-devel \
		libevent-devel \
		ncurses-devel \
		openssl-devel \
		perl-devel \
		readline-devel \
		zlib-devel

DEPS := gcc gcc-c++ pkgconf $(DEVEL)

# cargo
REMOVE := default-editor vim-minimal $(DEVEL)

tr = printf "| %-14s | %-8s | %-83s |\n" "$(1)" "$(2)" "$(3)" | tee -a $(4)
bdu = jq -r ".assets[] | select(.browser_download_url | contains(\"$1\")) | .browser_download_url" $2

default: working 

# cli-tools build-tools host-spawn coding-tools runtimes clean

clean:
	buildah run $(WORKING_CONTAINER) dnf remove -y $(REMOVE)
	buildah run $(WORKING_CONTAINER) dnf autoremove -y
	buildah run $(WORKING_CONTAINER) rm -Rf /tmp && mkdir -p /tmp

clear:
	rm -f info/*.md
	buildah rm --all
	# rm -f .env

latest/fedora-toolbox.json:
	echo '##[ $@ ]##'
	mkdir -p $(dir $@)
	skopeo inspect docker://${FED_IMAGE}:latest | jq '.' > $@

.env: latest/fedora-toolbox.json
	echo '##[ $@ ]##'
	FROM_REGISTRY=$$(cat $< | jq -r '.Name'); \
	FROM_VERSION=$$(cat $< | jq -r '.Labels.version'); \
	FROM_NAME=$$(cat $< | jq -r '.Labels.name'); \
	printf "FROM_NAME=%s\n" "$$FROM_NAME" | tee $@; \
	printf "FROM_REGISTRY=%s\n" "$$FROM_REGISTRY" | tee -a $@; \
	printf "FROM_VERSION=%s\n" "$$FROM_VERSION" | tee -a $@; \
	buildah pull "$$FROM_REGISTRY:$$FROM_VERSION" &> /dev/null; \
	echo -n "WORKING_CONTAINER=" | tee -a .env; \
	buildah from "$${FROM_REGISTRY}:$${FROM_VERSION}" | tee -a .env; \
	echo -n "NPROC=" | tee -a .env; \
	buildah run $(WORKING_CONTAINER) nproc | tee -a .env

xdefault: init cli-tools deps host-spawn neovim luajit luarocks nlua tiktoken dx clean
ifdef GITHUB_ACTIONS
	buildah config \
	--label summary='a toolbox with cli tools, neovim' \
	--label maintainer='Grant MacKenzie <grantmacken@gmail.com>' \
	--env lang=C.UTF-8 $(WORKING_CONTAINER)
	buildah commit $(WORKING_CONTAINER) $(TBX_IMAGE)
	buildah push $(TBX_IMAGE):latest
endif

dx: beam nodejs clean
ifdef GITHUB_ACTIONS
	buildah config \
	--label summary='dx toolbox for the gleam lang' \
	--label maintainer='Grant MacKenzie <grantmacken@gmail.com>' \
	--env lang=C.UTF-8 $(WORKING_CONTAINER)
	buildah commit $(WORKING_CONTAINER) $(TBX_IMAGE)-dx
	buildah push $(TBX_IMAGE)-dx:latest
endif

working: info/intro.md info/in-the-box.md info/working.md

info/intro.md:
	mkdir -p $(dir $@)
	printf "$(HEADING1) %s\n\n" "Zie Toolbox" | tee  $@
	cat << EOF | tee -a $@
	Toolbox is a tool that helps you create and manage development environments in containers.
	Unfamiliar with Toolbox? Check out the 
	[Toolbox documentation](https://docs.fedoraproject.org/en-US/fedora-silverblue/toolbox/).
	This toolbox is generated on [github actions](https://github.com/grantmacken/zie-toolbox/actions/)
	weekly. This is my current working toolbox that fit my current coding requirements. 
	If it might not be your cup of tea, clone the repo and read and adjust the 
	Makefile to suit your own whims.
	EOF

info/in-the-box.md:
	mkdir -p $(dir $@)
	printf "\n$(HEADING2) %s\n\n" "In The Box" | tee  $@
	cat << EOF | tee -a $@
	The idea here is to have a **long running** personal development toolbox containing the tools I require.
	The main tool categories are:
	EOF
	printf "\n - CLI tools\n" | tee -a $@
	# printf "\n - Build tools\n" | tee -a $@
	printf "\n - Coding tools\n" | tee -a $@
	printf "\n - BEAM and Nodejs Runtimes and associated languages\n" | tee -a $@

info/working.md:
	mkdir -p $(dir $@)
	printf "$(HEADING2) %s\n\n" "Built with buildah" | tee $@
	printf "The Toolbox is built from %s" "$(shell cat latest/fedora-toolbox.json | jq -r '.Labels.name')" | tee -a $@
	printf ", version %s\n" $(FROM_VERSION) | tee -a $@
	printf "\nPulled from registry:  %s\n" $(FROM_REGISTRY) | tee -a $@
	buildah config \
		--env LANG="C.UTF-8" \
		--env CPPFLAGS="-D_DEFAULT_SOURCE" \
		$(WORKING_CONTAINER)
	buildah run $(WORKING_CONTAINER) pwd
	buildah run $(WORKING_CONTAINER) printenv
	buildah run $(WORKING_CONTAINER) nproc

cli-tools: info/cli-tools.md
info/cli-tools.md:
	mkdir -p $(dir $@)
	buildah run $(WORKING_CONTAINER) dnf upgrade -y --minimal &>/dev/null
	for item in $(CLI)
	do
	buildah run $(WORKING_CONTAINER) dnf install \
		--allowerasing \
		--skip-unavailable \
		--skip-broken \
		--no-allow-downgrade \
		-y \
		$${item}  || { echo "Failed to install $${item}"; exit 1; }; \ 
	done &>/dev/null
	printf "\n$(HEADING2) %s\n\n" "Handpicked CLI tools available in the toolbox" | tee $@
	$(call tr,"Name","Version","Summary",$@)
	$(call tr,"----","-------","----------------------------",$@)
	buildah run $(WORKING_CONTAINER) sh -c  'dnf info -q installed $(CLI) | \
	   grep -oP "(Name.+:\s\K.+)|(Ver.+:\s\K.+)|(Sum.+:\s\K.+)" | \
	   paste  - - -  | sort -u ' | \
	   awk -F'\t' '{printf "| %-14s | %-8s | %-83s |\n", $$1, $$2, $$3}' | tee -a $@

build-tools: info/build-tools.md
info/build-tools.md:
	echo '##[ $@ ]##'
	for item in $(DEPS)
	do
	buildah run $(WORKING_CONTAINER) dnf install \
		--allowerasing \
		--skip-unavailable \
		--skip-broken \
		--no-allow-downgrade \
		-y \
		$${item} &>/dev/null
	done
	printf "$(HEADING2) %s\n\n" "Development dependencies for make installs" | tee $@
	$(call tr,"Name","Version","Summary",$@)
	$(call tr,"----","-------","----------------------------",$@)
	buildah run $(WORKING_CONTAINER) sh -c  'dnf info -q installed $(DEPS) | \
	grep -oP "(Name.+:\s\K.+)|(Ver.+:\s\K.+)|(Sum.+:\s\K.+)" | \
	paste  - - -  | sort -u ' | \
	awk -F'\t' '{printf "| %-14s | %-8s | %-83s |\n", $$1, $$2, $$3}' | \
	tee -a $@

## HOST-SPAWN
host-spawn: info/host-spawn.md
latest/host-spawn.json:
	echo '##[ $@ ]##'
	mkdir -p $(dir $@)
	wget -q https://api.github.com/repos/1player/host-spawn/releases/latest -O $@

info/host-spawn.md: latest/host-spawn.json
	echo '##[ $@ ]##'
	mkdir -p $(dir $@)
	SRC=$(shell $(call bdu,x86_64,$<))
	buildah add --chmod 755 $(WORKING_CONTAINER) $${SRC} /usr/local/bin/host-spawn &>/dev/null
	echo -n 'checking host-spawn version...'
	buildah run $(WORKING_CONTAINER) host-spawn --version
	VER=$$(buildah run $(WORKING_CONTAINER) host-spawn --version)
	printf "\n$(HEADING2) %s\n\n" "Host Spawn" | tee -a $@
	$(call tr,"Name","Version","Summary",$@)
	$(call tr,"----","-------","----------------------------",$@)
	$(call tr,host-spawn,$${VER},Run commands on your host machine from inside toolbox,$@)
	echo >> $@
	cat << EOF | tee -a $@
	The host-spawn tool is a wrapper around the toolbox command that allows you to run
	commands on your host machine from inside the toolbox.
	To use the host-spawn tool, either run the following command: host-spawn <command>
	Or just call host-spawn with no argument and this will pop you into you host shell.
	When doing this remember to pop back into the toolbox with exit.
	EOF
	printf "Checkout the %s for more information.\n\n" "[host-spawn repo](https://github.com/1player/host-spawn)" | tee -a $@

coding-tools: info/coding-tools.md
info/coding-tools.md: neovim luajit luarocks nlua tiktoken
	echo '##[ $@ ]##'
	printf "$(HEADING2) %s\n\n" "Tools available for coding in the toolbox" | tee $@
	$(call tr,"Name","Version","Summary",$@)
	$(call tr,"----","-------","----------------------------",$@)
	cat info/neovim.md | tee -a $@
	cat info/luajit.md | tee -a $@
	cat info/luarocks.md | tee -a $@
	cat info/nlua.md | tee -a $@
	cat info/tiktoken.md | tee -a $@

##[[ NEOVIM ]]##
neovim: info/neovim.md
latest/neovim.json:
	echo '##[ $@ ]##'
	mkdir -p $(dir $@)
	wget -q --timeout=10 --tries=3 'https://api.github.com/repos/neovim/neovim/releases/latest' -O  $@

info/neovim.md: latest/neovim.json
	echo '##[ $@ ]##'
	mkdir -p $(dir $@)
	TARGET=files/neovim/usr/local
	mkdir -p $${TARGET}
	SRC=$(shell $(call bdu,linux-x86_64.tar.gz,$<))
	VER=$$(jq -r '.tag_name' $<)
	wget -q --timeout=10 --tries=3 $${SRC} -O- |
	tar xz --strip-components=1 -C $${TARGET} &>/dev/null
	buildah add --chmod 755 $(WORKING_CONTAINER) files/neovim
	echo -n 'checking neovim locations...'
	buildah run $(WORKING_CONTAINER) whereis nvim
	echo -n 'checking neovim version...'
	buildah run $(WORKING_CONTAINER) nvim --version
	VER=$$(buildah run $(WORKING_CONTAINER) nvim --version| grep -oP 'NVIM \K.+')
	$(call tr,Neovim,$${VER},The text editor with a focus on extensibility and usability,$@)

luajit: info/luajit.md
info/luajit.md:
	buildah run $(WORKING_CONTAINER) dnf install -y luajit-devel luajit  &>/dev/null
	echo -n 'checking luajit version...'
	buildah run $(WORKING_CONTAINER) luajit -v
	VERSION=$$(buildah run $(WORKING_CONTAINER) luajit -v | grep -oP 'LuaJIT \K\d+\.\d+\.\d{1,3}')
	$(call tr,luajit,$${VERSION},The LuaJIT compiler,$@)

latest/luarocks.json:
	echo '##[ $@ ]##'
	mkdir -p $(dir $@)
	wget  -q --timeout=10 --tries=3 https://api.github.com/repos/luarocks/luarocks/tags -O- | jq '.[0]' > $@

luarocks: info/luarocks.md
info/luarocks.md: latest/luarocks.json
	echo '##[ $@ ]##'
	mkdir -p $(dir $@)
	mkdir -p files/luarocks
	SRC=$$(jq -r '.tarball_url' $<)
	buildah run $(WORKING_CONTAINER) sh -c 'test -d /tmp && rm -Rf /tmp && mkdir -p /tmp && mkdir -p /etc/xdg/luarocks'
	wget -q --timeout=10 --tries=3 $${SRC} -O- | tar xz --strip-components=1 -C files/luarocks &>/dev/null
	buildah add --chmod 755 $(WORKING_CONTAINER) files/luarocks /tmp &>/dev/null
	buildah run $(WORKING_CONTAINER) sh -c 'cd /tmp && ./configure \
		--lua-version=5.1 \
		--with-lua-interpreter=luajit \
		--sysconfdir=/etc/xdg \
		--force-config \
		--with-lua-include=/usr/include/luajit-2.1' &>/dev/null
	buildah run $(WORKING_CONTAINER) sh -c 'cd /tmp && make bootstrap' &>/dev/null
	echo -n 'checking luarocks version...'
	buildah run $(WORKING_CONTAINER) luarocks --version
	LINE=$$(buildah run $(WORKING_CONTAINER) luarocks | grep -oP '^Lua.+')
	NAME=$$(echo $$LINE | grep -oP '^Lua\w+')
	VER=$$(echo $$LINE | grep -oP '^Lua\w+\s\K.+' | cut -d, -f1)
	SUM=$$(echo $$LINE | grep -oP '^Lua\w+\s\K.+' | cut -d, -f2)
	$(call tr,$${NAME},$${VER},$${SUM},$@)

nlua: info/nlua.md
info/nlua.md:
	echo '##[ $@ ]##'
	buildah run $(WORKING_CONTAINER) luarocks install nlua &>/dev/null
	LINE=$$(buildah run $(WORKING_CONTAINER) luarocks show nlua | grep -oP '^nlua.+')
	# echo "$${LINE}"
	VER=$$(echo "$${LINE}" | grep -oP '^nlua.+' | cut -d" " -f2)
	SUM=$$(echo "$${LINE}" |  grep -oP '^nlua.+' | cut -d"-" -f3)
	buildah run $(WORKING_CONTAINER) luarocks config lua_version 5.1 &>/dev/null
	buildah run $(WORKING_CONTAINER) luarocks config lua_interpreter nlua
	buildah run $(WORKING_CONTAINER) luarocks config variables.LUA /usr/local/bin/nlua &>/dev/null
	$(call tr,nlua,$${VER},$${SUM},$@)
	# buildah run $(WORKING_CONTAINER) luarocks config variables.LUA_INCDIR /usr/local/include/luajit-2.1

tiktoken_src = https://github.com/gptlang/lua-tiktoken/releases/download/v0.2.3/tiktoken_core-linux-x86_64-lua51.so
TIKTOKEN_TARGET := /usr/local/lib/lua/5.1/tiktoken_core-linux.so

latest/tiktoken.json:
	# echo '##[ $@ ]##'
	mkdir -p $(dir $@)
	wget -q -O - https://api.github.com/repos/gptlang/lua-tiktoken/releases/latest | jq '.' > $@

tiktoken: info/tiktoken.md
info/tiktoken.md: latest/tiktoken.json
	# echo '##[ $@ ]##'
	$(eval tiktoken_src := $(shell $(call bdu,tiktoken_core-linux-x86_64-lua51.so,$<)))
	$(eval tiktoken_ver := $(shell jq -r '.tag_name' $<))
	buildah add --chmod 755 $(WORKING_CONTAINER) $(tiktoken_src) $(TIKTOKEN_TARGET) &>/dev/null
	$(call tr,tiktoken,$(tiktoken_ver),The lua module for generating tiktok tokens,$@)
	# nlua -e 'print(package.)'
	# buildah run $(WORKING_CONTAINER) exa --tree /usr/local/lib/lua/5.1
	# buildah run $(WORKING_CONTAINER) exa --tree /usr/local/share/lua/5.1

##[[ RUNTIMES ]]##
runtimes: info/runtimes.md
info/runtimes.md: otp rebar3 elixir gleam nodejs
	printf "\n$(HEADING2) %s\n\n" "Runtimes and associated languages" | tee $@
	cat << EOF | tee -a $@
	Included in this toolbox are the latest releases of the Erlang, Elixir and Gleam programming languages.
	The Erlang programming language is a general-purpose, concurrent, functional programming language
	and **runtime** system. It is used to build massively scalable soft real-time systems with high availability.
	The BEAM is the virtual machine at the core of the Erlang Open Telecom Platform (OTP).
	The included Elixir and Gleam programming languages also run on the BEAM.
	BEAM tooling included is the latest versions of the Rebar3 and the Mix build tools.
	The latest nodejs **runtime** is also installed, as Gleam can compile to javascript as well a Erlang.
	EOF
	$(call tr,"Name","Version","Summary",$@)
	$(call tr,"----","-------","----------------------------",$@)
	cat info/otp.md    | tee -a $@
	cat info/rebar3.md | tee -a $@
	cat info/elixir.md | tee -a $@
	cat info/gleam.md  | tee -a $@
	cat info/nodejs.md | tee -a $@

latest/erlang.downloads:
	echo '##[ $@ ]##'
	mkdir -p $(dir $@)
	wget -q --timeout=10 --tries=3 https://www.erlang.org/downloads -O |
	grep -oP 'href="\K(otp-.*\.tar\.gz)' | grep -oP 'https://.*' > $@
	VER=$$(grep -oP 'The latest version of Erlang/OTP is(.+)>\K(\d+\.){2}\d+' $< )

otp-deps: build-tools-common $(addprefix dep-install-,$(ERLANG_DEPS))

$(addprefix dep-install-,$(ERLANG_DEPS)):
	@item=$(patsubst dep-install-%,%,$@); \
	echo "Installing Erlang dependency $$item..."; \
	buildah run $(WORKING_CONTAINER) dnf install \
		--allowerasing \
		--skip-unavailable \
		--skip-broken \
		--no-allow-downgrade \
		-y \
		$$item




latest/otp.json:
	echo '##[ $@ ]##'
	mkdir -p $(dir $@)
	wget -q --timeout=10 --tries=3 https://api.github.com/repos/erlang/otp/releases/latest -O $@

otp: otp-deps info/otp.md
info/otp.md: latest/otp.json
	echo '##[ $@ ]##'
	mkdir -p $(dir $@)
	buildah run $(WORKING_CONTAINER) sh -c 'rm -Rf /tmp && mkdir -p /tmp'
	TAGNAME=$$(jq -r '.tag_name' $<)
	$(eval ver := $(shell jq -r '.name' $< | cut -d' ' -f2))
	ASSET=$$(jq -r '.assets[] | select(.name=="otp_src_$(ver).tar.gz") ' $<)
	SRC=$$(echo $${ASSET} | jq -r '.browser_download_url')
	mkdir -p files/otp && wget -q --timeout=10 --tries=3  $${SRC} -O- |
	tar xz --strip-components=1 -C files/otp &>/dev/null
	buildah add --chmod 755 $(WORKING_CONTAINER) files/otp /tmp &>/dev/null
	buildah run $(WORKING_CONTAINER) sh -c 'cd /tmp && ./configure \
		--prefix=/usr/local \
		--enable-threads \
		--enable-shared-zlib \
		--enable-ssl=dynamic-ssl-lib \
		--enable-jit \
		--enable-kernel-poll \
		--without-debugger \
		--without-observer \
		--without-wx \
		--without-et \
		--without-megaco \
		--without-cosEvent \
		--without-odbc' &>/dev/null
	buildah run $(WORKING_CONTAINER) sh -c 'cd /tmp && make -j$(NPROC) && make -j$(NPROC) install' &>/dev/null
	echo -n 'checking otp version...'
	buildah run $(WORKING_CONTAINER) erl -eval 'erlang:display(erlang:system_info(otp_release)), halt().'  -noshell
	$(call tr ,Erlang/OTP,$(ver),the Erlang Open Telecom Platform OTP,$@)

latest/elixir.json:
	# echo '##[ $@ ]##'
	mkdir -p $(dir $@)
	wget -q --timeout=10 --tries=3  https://api.github.com/repos/elixir-lang/elixir/releases/latest -O $@

elixir: info/elixir.md
info/elixir.md: latest/elixir.json
	echo '##[ $@ ]##'
	TAGNAME=$$(jq -r '.tag_name' $<)
	SRC=https://github.com/elixir-lang/elixir/archive/$${TAGNAME}.tar.gz
	echo $${SRC}
	mkdir -p files/elixir && wget -q --timeout=10 --tries=3 $${SRC} -O- |
	tar xz --strip-components=1 -C files/elixir &>/dev/null
	buildah run $(WORKING_CONTAINER) bash -c 'rm -Rf /tmp && mkdir -p /tmp'
	buildah add --chmod 755 $(WORKING_CONTAINER) files/elixir /tmp &>/dev/null
	buildah run $(WORKING_CONTAINER) bash -c 'cd /tmp && make -j$(NPROC) && make -j$(NPROC) install' &>/dev/null
	echo -n 'checking elixir version...'
	# buildah run $(WORKING_CONTAINER) erl -eval 'erlang:display(erlang:system_info(otp_release)), halt().'  -noshell
	buildah run $(WORKING_CONTAINER) elixir --version
	LINE=$$(buildah run $(WORKING_CONTAINER) elixir --version | grep -oP '^Elixir.+')
	VER=$$(echo "$${LINE}" | grep -oP 'Elixir\s\K.+' | cut -d' ' -f1)
	$(call tr,Elixir,$${VER},Elixir programming language, $@)
	VER=$$(buildah run $(WORKING_CONTAINER) mix --version | grep -oP 'Mix \K.+' | cut -d' ' -f1)
	$(call tr,Mix,$${VER},Elixir build tool, $@)

latest/rebar3.json:
	# echo '##[ $@ ]##'
	mkdir -p $(dir $@)
	wget -q --timeout=10 --tries=3 https://api.github.com/repos/erlang/rebar3/releases/latest -O $@

rebar3: info/rebar3.md
info/rebar3.md: latest/rebar3.json
	# echo '##[ $@ ]##'
	VER=$$(jq -r '.tag_name' $<)
	SRC=$(shell $(call bdu,rebar3,$<))
	buildah add --chmod 755 $(WORKING_CONTAINER) $${SRC} /usr/local/bin/rebar3 &>/dev/null
	$(call tr,Rebar3,$${VER},the erlang build tool,$@)

##[[ GLEAM ]]##
latest/gleam.json:
	# echo '##[ $@ ]##'
	mkdir -p $(dir $@)
	wget --timeout=10 --tries=3 https://api.github.com/repos/gleam-lang/gleam/releases/latest -O- |
	jq -r '.assets[] | select(.name | endswith("x86_64-unknown-linux-musl.tar.gz"))' > $@

gleam: info/gleam.md
files/gleam.tar: latest/gleam.json
	mkdir -p $(dir $@)
	buildah run $(WORKING_CONTAINER) rm -f /usr/local/bin/gleam
	SRC=$$(jq -r '.browser_download_url' $<)
	wget $${SRC} -q -O- | gzip -d > $@

info/gleam.md: files/gleam.tar
	echo '##[ $@ ]##'
	buildah run $(WORKING_CONTAINER) bash -c 'rm -Rf /usr/local/bin/gleam && mkdir -p /tmp'
	buildah add --chmod 755 $(WORKING_CONTAINER) $< /usr/local/bin/  &>/dev/null
	echo -n 'checking gleam version...'
	buildah run $(WORKING_CONTAINER) gleam --version
	VER=$$(buildah run $(WORKING_CONTAINER) gleam --version | cut -d' ' -f2)
	$(call tr,Gleam,$${VER},Gleam programming language,$@)

##[[ NODEJS ]]##
latest/nodejs.json:
	# echo '##[ $@ ]##'
	mkdir -p $(dir $@)
	wget -q 'https://api.github.com/repos/nodejs/node/releases/latest' -O $@

nodejs: info/nodejs.md
info/nodejs.md: latest/nodejs.json
	# echo '##[ $@ ]##'
	VER=$$(jq -r '.tag_name' $< )
	mkdir -p files/nodejs/usr/local
	wget -q https://nodejs.org/download/release/$${VER}/node-$${VER}-linux-x64.tar.gz -O- |
	tar xz --strip-components=1 -C files/nodejs/usr/local
	buildah add --chmod 755  $(WORKING_CONTAINER) files/nodejs &>/dev/null
	$(call tr,Nodejs,$${VER},Nodejs runtime, $@)

