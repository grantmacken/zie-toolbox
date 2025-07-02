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
#.NOTPARALLEL: .env working info/working.md

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
TBX_IMAGE=ghcr.io/grantmacken/zie-toolbox
BEAM_IMAGE=ghcr.io/grantmacken/beam-me-up
# SHORTCUT
RUN := buildah run $(WORKING_CONTAINER) 
REMOVE := default-editor vim-minimal

tr = printf "| %-14s | %-8s | %-83s |\n" "$(1)" "$(2)" "$(3)" | tee -a $(4)
bdu = jq -r ".assets[] | select(.browser_download_url | contains(\"$1\")) | .browser_download_url" $2

default:  working build-tools host-spawn runtimes coding clean checks
ifdef GITHUB_ACTIONS
	buildah config \
	--label summary='a toolbox with cli tools, neovim' \
	--label maintainer='Grant MacKenzie <grantmacken@gmail.com>' \
	--env lang=C.UTF-8 $(WORKING_CONTAINER)
	buildah commit $(WORKING_CONTAINER) $(TBX_IMAGE)
	buildah push $(TBX_IMAGE):latest
endif

clean:
	# $(RUN) dnf remove -y $(REMOVE) &>/dev/null
	# $(RUN) dnf install -y zlib ncurses readline &>/dev/null 
	$(RUN) dnf autoremove -y &>/dev/null

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
	FROM_REGISTRY=$$(cat $< | jq -r '.Name')
	FROM_VERSION=$$(cat $< | jq -r '.Labels.version')
	FROM_NAME=$$(cat $< | jq -r '.Labels.name')
	printf "FROM_NAME=%s\n" "$$FROM_NAME" | tee $@
	printf "FROM_REGISTRY=%s\n" "$$FROM_REGISTRY" | tee -a $@
	printf "FROM_VERSION=%s\n" "$$FROM_VERSION" | tee -a $@
	buildah pull "$$FROM_REGISTRY:$$FROM_VERSION" &> /dev/null
	echo -n "WORKING_CONTAINER=" | tee -a .env
	buildah from "$${FROM_REGISTRY}:$${FROM_VERSION}" | tee -a .env
	echo -n "NPROC=" | tee -a .env
	$(RUN) nproc | tee -a .env

working: info/intro.md info/in-the-box.md info/working.md
checks:
	echo '##[ $@ ]##'
	# After removal of devel check ececs in working container
	echo -n 'checking neovim version...'
	$(RUN) nvim --version
	# echo -n 'checking luarocks version...'
	# $(RUN) luarocks --version
	echo -n 'checking erlixir version...'
	$(RUN) elixir --version
	echo -n 'checking gleam version...'
	$(RUN) gleam --version
	echo -n 'checking nodejs version...'
	$(RUN) node --version
	echo -n 'checking beam version...'
	$(RUN) erl -eval 'erlang:display(erlang:system_info(otp_release)), halt().'  -noshell

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
	printf "\n - Build tools\n" | tee -a $@
	printf "\n - Runtimes: BEAM and Nodejs Runtimes and associated languages\n" | tee -a $@
	printf "\n - Coding tools: Neovim and a selection of terminal CLI tools" | tee -a $@
	printf "\n - The focus is on providing terminal cli tooling around the the neovim editor and its plugin envronment" | tee -a $@


info/working.md:
	mkdir -p $(dir $@)
	printf "$(HEADING2) %s\n\n" "Built with buildah" | tee $@
	printf "The Toolbox is built from %s" "$(shell cat latest/fedora-toolbox.json | jq -r '.Labels.name')" | tee -a $@
	printf ", version %s\n" $(FROM_VERSION) | tee -a $@
	printf "\nToolbox is pulled from registry:  %s\n" $(FROM_REGISTRY) | tee -a $@
	buildah config \
		--env LANG="C.UTF-8" \
		--env CPPFLAGS="-D_DEFAULT_SOURCE" \
		--env CARGO_HOME="/usr/local/cargo" \
		$(WORKING_CONTAINER)

BUILDING := make gcc gcc-c++ pcre2 autoconf pkgconf #  rust cargo gnupg libgpg-error
DEVEL := gettext-devel \
		glibc-devel \
		libevent-devel \
		ncurses-devel \
		openssl-devel \
		perl-devel \
		readline-devel \
		zlib-devel
DEPS := $(BUILDING) $(DEVEL)


build-tools: info/build-tools.md
info/build-tools.md:
	echo '##[ $@ ]##'
	for item in $(DEPS)
	do
	$(RUN) dnf install --allowerasing --skip-unavailable --skip-broken --no-allow-downgrade -y $${item} &>/dev/null
	done
	printf "\n$(HEADING2) %s\n\n" "Selected Build Tooling for Make Installs" | tee $@
	$(call tr,"Name","Version","Summary",$@)
	$(call tr,"----","-------","----------------------------",$@)
	$(RUN) sh -c  'dnf info -q installed $(BUILDING) | \
	grep -oP "(Name.+:\s\K.+)|(Ver.+:\s\K.+)|(Sum.+:\s\K.+)" | \
	paste  - - -  | sort -u ' | \
	awk -F'\t' '{printf "| %-14s | %-8s | %-83s |\n", $$1, $$2, $$3}' | \
	tee -a $@

## HOST-SPAWN

SPAWN := firefox flatpak gcloud podman buildah skopeo systemctl rpm-ostree dconf

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
	$(RUN) host-spawn --version
	VER=$$($(RUN) host-spawn --version)
	printf "\n$(HEADING2) %s\n\n" "Do More With host-spawn" | tee -a $@
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
	printf "%s\n" "Host-spawn (version: $${VER}) allows the running of commands on your host machine from inside the toolbox" | tee -a $@
	# close table
	printf "\n%s\n" "For conveniance I have made the following host executables can be used from this toolbox" | tee -a $@
	for item in $(SPAWN)
	do
	$(RUN) ln -fs /usr/local/bin/host-spawn /usr/local/bin/$${item}
	printf " - %s\n" "$${item}" | tee -a $@
	done

##[[ RUNTIMES ]]##
runtimes: info/runtimes.md
info/runtimes.md: nodejs otp rebar3 elixir gleam
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

# latest/erlang.downloads:
# 	echo '##[ $@ ]##'
# 	mkdir -p $(dir $@)
# 	wget -q --timeout=10 --tries=3 https://www.erlang.org/downloads -O |
# 	grep -oP 'href="\K(otp-.*\.tar\.gz)' | grep -oP 'https://.*' > $@
# 	VER=$$(grep -oP 'The latest version of Erlang/OTP is(.+)>\K(\d+\.){2}\d+' $< )


latest/otp.json: 
	# echo '##[ $@ ]##'
	mkdir -p $(dir $@)
	wget -q --timeout=10 --tries=3 https://api.github.com/repos/erlang/otp/releases/latest -O $@

otp: info/otp.md
info/otp.md: latest/otp.json
	# echo '##[ $@ ]##'
	mkdir -p $(dir $@)
	$(RUN) mkdir -p /tmp/otp
	TAGNAME=$$(jq -r '.tag_name' $<)
	$(eval ver := $(shell jq -r '.name' $< | cut -d' ' -f2))
	ASSET=$$(jq -r '.assets[] | select(.name=="otp_src_$(ver).tar.gz") ' $<)
	SRC=$$(echo $${ASSET} | jq -r '.browser_download_url')
	mkdir -p files/otp && wget -q --timeout=10 --tries=3  $${SRC} -O- |
	tar xz --strip-components=1 -C files/otp &>/dev/null
	buildah add --chmod 755 $(WORKING_CONTAINER) files/otp /tmp/otp &>/dev/null
	$(RUN) sh -c 'cd /tmp/otp && ./configure \
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
	$(RUN) sh -c 'cd /tmp/otp && make -j$(NPROC) && make -j$(NPROC) install' &>/dev/null
	echo -n 'checking otp version...'
	$(RUN) erl -eval 'erlang:display(erlang:system_info(otp_release)), halt().'  -noshell
	$(call tr ,Erlang/OTP,$(ver),the Erlang Open Telecom Platform OTP,$@)
	$(RUN) rm -fR /tmp/otp

latest/elixir.json:
	# echo '##[ $@ ]##'
	mkdir -p $(dir $@)
	wget -q --timeout=10 --tries=3  https://api.github.com/repos/elixir-lang/elixir/releases/latest -O $@

elixir: info/elixir.md
info/elixir.md: latest/elixir.json
	# echo '##[ $@ ]##'
	TAGNAME=$$(jq -r '.tag_name' $<)
	SRC=https://github.com/elixir-lang/elixir/archive/$${TAGNAME}.tar.gz
	mkdir -p files/elixir && wget -q --timeout=10 --tries=3 $${SRC} -O- |
	tar xz --strip-components=1 -C files/elixir &>/dev/null
	$(RUN) mkdir -p /tmp/elixir
	buildah add --chmod 755 $(WORKING_CONTAINER) files/elixir /tmp/elixir &>/dev/null
	$(RUN) sh -c 'cd /tmp/elixir && make -j$(NPROC) && make -j$(NPROC) install' &>/dev/null
	echo -n 'checking elixir version...'
	# $(RUN) erl -eval 'erlang:display(erlang:system_info(otp_release)), halt().'  -noshell
	$(RUN) elixir --version
	LINE=$$($(RUN) elixir --version | grep -oP '^Elixir.+')
	VER=$$(echo "$${LINE}" | grep -oP 'Elixir\s\K.+' | cut -d' ' -f1)
	$(call tr,Elixir,$${VER},Elixir programming language, $@)
	VER=$$($(RUN) mix --version | grep -oP 'Mix \K.+' | cut -d' ' -f1)
	$(call tr,Mix,$${VER},Elixir build tool, $@)
	$(RUN) rm -fR /tmp/elixir

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
	wget -q --timeout=10 --tries=3 https://api.github.com/repos/gleam-lang/gleam/releases/latest -O- |
	jq -r '.assets[] | select(.name | endswith("x86_64-unknown-linux-musl.tar.gz"))' > $@

gleam: info/gleam.md
files/gleam.tar: latest/gleam.json
	mkdir -p $(dir $@)
	$(RUN) rm -f /usr/local/bin/gleam
	SRC=$$(jq -r '.browser_download_url' $<)
	wget $${SRC} -q -O- | gzip -d > $@

info/gleam.md: files/gleam.tar
	# echo '##[ $@ ]##'
	buildah add --chmod 755 $(WORKING_CONTAINER) $< /usr/local/bin/  &>/dev/null
	echo -n 'checking gleam version...'
	VER=$$($(RUN) gleam --version | cut -d' ' -f2 | tee)
	$(call tr,Gleam,$${VER},Gleam programming language,$@)

##[[ NODEJS ]]##
nodejs: info/nodejs.md

latest/nodejs.json:
	# echo '##[ $@ ]##'
	mkdir -p $(dir $@)
	wget -q 'https://api.github.com/repos/nodejs/node/releases/latest' -O $@

info/nodejs.md: latest/nodejs.json
	# echo '##[ $@ ]##'
	VER=$$(jq -r '.tag_name' $< )
	mkdir -p files/nodejs/usr/local
	wget -q https://nodejs.org/download/release/$${VER}/node-$${VER}-linux-x64.tar.gz -O- |
	tar xz --strip-components=1 -C files/nodejs/usr/local
	buildah add --chmod 755  $(WORKING_CONTAINER) files/nodejs &>/dev/null
	echo -n 'checking node version...'
	NODE_VER=$$($(RUN) node --version | tee)
	$(call tr,node,$${NODE_VER},Nodejs runtime, $@)
	echo -n 'checking npm version...'
	NPM_VER=$$($(RUN) npm --version | tee)
	$(call tr,npm,$${NPM_VER},Node Package Manager, $@)

# --root /usr/local/cargo

cargo:
	echo '##[ $@ ]##'
	$(RUN) mkdir -p /usr/local/cargo
	$(RUN) cargo install cargo-binstall --root /usr/local/cargo
	$(RUN) ls /usr/local/cargo/bin/
	$(RUN) ln -sf /usr/local/cargo/bin/cargo-binstall /usr/local/bin/cargo-binstall
	$(RUN) cargo-binstall --help
	$(RUN) cargo-binstall --no-confirm --no-symlinks --root /usr/local/cargo lux-cli
	$(RUN) ls /usr/local/cargo/bin/
	$(RUN) ln -sf /usr/local/cargo/bin/* /usr/local/bin/
	$(RUN) lx --help

## CODING TOOLS
info/coding.md: info/cli-tools.md \
	info/neovim.md \
	info/luajit.md \
	info/luarocks.md \
	info/npm-more.md \
	info/rocks-more.md
	cat info/cli-tools.md | tee $@
	printf "\n$(HEADING2) %s\n\n" "Coding Tools available for coding in the toolbox" | tee -a $@
	$(call tr,"Name","Version","Summary",$@)
	$(call tr,"----","-------","----------------------------",$@)
	cat info/neovim.md | tee -a $@
	cat info/luajit.md | tee -a $@
	cat info/luarocks.md | tee -a $@
	echo '##[ $@ ]##'
	printf "\n$(HEADING2) %s\n\n" "More Coding Tools" | tee $@
	cat << EOF | tee -a $@
	Extra tooling that can be used within the Neovim text editor plugin echo system.
	These are install via npm or luarocks.
	EOF
	# cat info/info/rocks-more.md | tee -a $@
	cat info/npm-more.md | tee -a $@
	cat info/rocks-more.md | tee -a $@
	# cat info/info/pip-more.md | tee -a $@

CLI := bat direnv eza fd-find fzf gh imagemagick jq just lynx python3-pip ripgrep stow wl-clipboard yq zoxide
info/cli-tools.md:
	mkdir -p $(dir $@)
	for item in $(CLI)
	do
	$(RUN) dnf install \
		--allowerasing \
		--skip-unavailable \
		--skip-broken \
		--no-allow-downgrade \
		-y \
		$${item} &>/dev/null
	done
	printf "\n$(HEADING2) %s\n\n" "Handpicked CLI tools available in the toolbox" | tee $@
	$(call tr,"Name","Version","Summary",$@)
	$(call tr,"----","-------","----------------------------",$@)
	$(RUN) sh -c  'dnf info -q installed $(CLI) | \
	   grep -oP "(Name.+:\s\K.+)|(Ver.+:\s\K.+)|(Sum.+:\s\K.+)" | \
	   paste  - - -  | sort -u ' | \
	   awk -F'\t' '{printf "| %-14s | %-8s | %-83s |\n", $$1, $$2, $$3}' | tee -a $@

latest/neovim.json:
	#  echo '##[ $@ ]##'
	mkdir -p $(dir $@)
	wget -q --timeout=10 --tries=3 'https://api.github.com/repos/neovim/neovim/releases/latest' -O  $@

info/neovim.md: latest/neovim.json
	# echo '##[ $@ ]##'
	mkdir -p $(dir $@)
	TARGET=files/neovim/usr/local
	mkdir -p $${TARGET}
	SRC=$(shell $(call bdu,linux-x86_64.tar.gz,$<))
	VER=$$(jq -r '.tag_name' $<)
	wget -q --timeout=10 --tries=3 $${SRC} -O- |
	tar xz --strip-components=1 -C $${TARGET} &>/dev/null
	buildah add --chmod 755 $(WORKING_CONTAINER) files/neovim &>/dev/null
	echo -n 'checking neovim locations...'
	$(RUN) whereis nvim
	echo -n 'checking neovim version...'
	$(RUN) nvim --version
	VER=$$($(RUN) nvim --version| grep -oP 'NVIM \K.+')
	$(call tr,Neovim,$${VER},The text editor with a focus on extensibility and usability,$@)

info/luajit.md:
	# echo '##[ $@ ]##'
	$(RUN) dnf install -y luajit-devel luajit  &>/dev/null
	echo -n 'checking luajit version...'
	$(RUN) luajit -v
	VERSION=$$($(RUN) luajit -v | grep -oP 'LuaJIT \K\d+\.\d+\.\d{1,3}')
	$(call tr,luajit,$${VERSION},The LuaJIT compiler,$@)

latest/luarocks.json:
	# echo '##[ $@ ]##'
	mkdir -p $(dir $@)
	wget  -q --timeout=10 --tries=3 https://api.github.com/repos/luarocks/luarocks/tags -O- | jq '.[0]' > $@

info/luarocks.md: latest/luarocks.json
	# echo '##[ $@ ]##'
	mkdir -p $(dir $@)
	mkdir -p files/luarocks
	SRC=$$(jq -r '.tarball_url' $<)
	$(RUN) mkdir -p 	/tmp/luarocks /etc/xdg/luarocks
	wget -q --timeout=10 --tries=3 $${SRC} -O- | tar xz --strip-components=1 -C files/luarocks &>/dev/null
	buildah add --chmod 755 $(WORKING_CONTAINER) files/luarocks /tmp/luarocks &>/dev/null
	$(RUN) sh -c 'cd /tmp/luarocks && ./configure \
		--lua-version=5.1 \
		--with-lua-interpreter=luajit \
		--sysconfdir=/etc/xdg \
		--force-config \
		--with-lua-include=/usr/include/luajit-2.1' &>/dev/null
	# $(RUN) sh -c 'cd /tmp && make bootstrap' &>/dev/null
	$(RUN) sh -c 'cd /tmp/luarocks && make && make install' &>/dev/null
	echo -n 'checking luarocks version...'
	$(RUN) luarocks --version
	# $(RUN) luarocks config --json | jq '.' &>/dev/null
	LINE=$$($(RUN) luarocks | grep -oP '^Lua.+')
	NAME=$$(echo $$LINE | grep -oP '^Lua\w+')
	VER=$$(echo $$LINE | grep -oP '^Lua\w+\s\K.+' | cut -d, -f1)
	SUM=$$(echo $$LINE | grep -oP '^Lua\w+\s\K.+' | cut -d, -f2)
	$(call tr,$${NAME},$${VER},$${SUM},$@)
	$(RUN) rm -fR tmp/luarocks


NPM_TOOLS := ast-grep tree-sitter-cli neovim
info/npm-more.md:
	echo '##[ $@ ]##'
	$(call tr,"----","-------","----------------------------",$@)
	$(call tr,"Name","Version","Summary",$@)
	$(call tr,"----","-------","----------------------------",$@)
	echo ' - tools are installed via npm'
	for item in $(NPM_TOOLS)
	do
	$(RUN) npm install --global $${item}
	done
	$(RUN) npm list --global --depth=0 
	echo -n 'checking ast-grep version...'
	VER=$(shell $(RUN) ast-grep --version | cut -d ' ' -f2 | tee)
	$(call tr,ast-grep,$${VER},Tool for code structural searching and linting and rewriting, $@)
	echo -n 'checking tree-sitter version ...'
	VER=$$($(RUN) tree-sitter --version | cut -d ' ' -f2 | tee)
	$(call tr,tree-sitter,$${VER},The tree-sitter Command Line Interface, $@)

lrInstall =  luarocks install \
			  --server $(ROCKS_BINARIES) \
			  --no-doc \
			  --force-fast \
			  --deps-mode one $1

ROCKS_BINARIES := https://nvim-neorocks.github.io/rocks-binaries
ROCKS := luafilesystem luarocks-build-treesitter-parser luarocks-build-treesitter-parser-cpp
info/rocks-more.md:
	echo '##[ $@ ]##'
	printf "\n$(HEADING2) %s\n\n" "Lua Rocks" | tee $@
	cat << EOF | tee -a $@
	These are Lua rocks that can be used within the Neovim text editor plugin echo system.
	EOF
	echo >> $@
	$(call tr,"----","-------","----------------------------",$@)
	$(call tr,"Name","Version","Summary",$@)
	$(call tr,"----","-------","----------------------------",$@)
	echo ' - tools are installed via luarocks'
	for rock in $(ROCKS)
	do
	$(RUN) $(call lrInstall, $${rock}) &>/dev/null
	done
	## TODO!
	$(RUN) luarocks list --porcelain || true

# pip-more:
# 	echo '##[ $@ ]##'
# 	$(RUN) pip install pylatexenc
# 	echo -n 'checking latex2text version ... '
# 	VER=$$($(RUN) latex2text --version | cut -d" " -f2 | tee)
# 	$(call tr,latex2text,$${VER}, ,$@)#
# 	#

# latest/nlua.json:
# 	echo '##[ $@ ]##'
# 	mkdir -p $(dir $@)
# 	wget  -q --timeout=10 --tries=3 https://api.github.com/repos/mfussenegger/nlua/tags -O- | jq '.[0]' > $@
#
# nlua: info/nlua.md
# info/nlua.md: latest/nlua.json
# 	echo '##[ $@ ]##'
# 	SRC=https://raw.githubusercontent.com/mfussenegger/nlua/main/nlua
# 	buildah add --chmod 755 $(WORKING_CONTAINER) $${SRC} /usr/local/bin/nlua &>/dev/null
# 	# $(RUN) luarocks config lua_version 5.1 &>/dev/null
# 	# $(RUN) luarocks config lua_interpreter nlua
# 	# $(RUN) luarocks config variables.LUA /usr/local/bin/nlua
# 	# $(RUN) luarocks config variables.LUA_INCDIR /usr/include/luajit-2.1
# 	# $(RUN) luarocks
# 	# VER=$$(jq -r '.name' $< )
# 	# $(call tr,nlua,$${VER},Neovim as a Lua interpreter,$@)
# 	# $(RUN) luarocks config variables.LUA_INCDIR /usr/local/include/luajit-2.1
#
# tiktoken_src = https://github.com/gptlang/lua-tiktoken/releases/download/v0.2.3/tiktoken_core-linux-x86_64-lua51.so
# TIKTOKEN_TARGET := /usr/local/lib/lua/5.1/tiktoken_core.so
#
# latest/tiktoken.json:
# 	# echo '##[ $@ ]##'
# 	mkdir -p $(dir $@)
# 	wget -q -O - https://api.github.com/repos/gptlang/lua-tiktoken/releases/latest | jq '.' > $@
#
# tiktoken: info/tiktoken.md
# info/tiktoken.md: latest/tiktoken.json
# 	# echo '##[ $@ ]##'
# 	SRC=$(shell $(call bdu,tiktoken_core-linux-x86_64-lua51.so,$<))
# 	VER=$$(jq -r '.tag_name' $<)
# 	buildah add --chmod 755 $(WORKING_CONTAINER) $${SRC} $(TIKTOKEN_TARGET)
# 	$(RUN) ls /usr/local/lib/lua/5.1 
# 	$(call tr,tiktoken,$${VER},The lua module for generating tiktok tokens,$@)
#


 

