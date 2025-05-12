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

DASH := -
DOT := .
COMMA := ,
EMPTY:=
SPACE := $(EMPTY) $(EMPTY)

include .env

FED_IMAGE := registry.fedoraproject.org/fedora-toolbox
CONTAINER := fedora-toolbox-working-container

CLI_IMAGE=ghcr.io/grantmacken/tbx-cli-tools
CLI_CONTAINER_NAME=tbx-cli-tools

# IMAGE    :=  ghcr.io/grantmacken/tbx-cli-tools:latest
# CONTAINER := tbx-cli-tools-working-container

TBX_IMAGE=ghcr.io/grantmacken/zie-toolbox
TBX_CONTAINER_NAME=zie-toolbox

CLI   := bat direnv eza fd-find fzf gh jq make ripgrep stow wl-clipboard yq zoxide
SPAWN := firefox flatpak podman buildah skopeo systemctl rpm-ostree dconf
DEPS  := gcc gcc-c++ glibc-devel ncurses-devel openssl-devel libevent-devel readline-devel gettext-devel
BEAM  := otp rebar3 elixir gleam nodejs
# cargo
REMOVE := default-editor vim-minimal

tr = printf "| %-14s | %-8s | %-83s |\n" "$(1)" "$(2)" "$(3)" | tee -a $(4)
bdu = jq -r ".assets[] | select(.browser_download_url | contains(\"$1\")) | .browser_download_url" $2

# gcc-c++ gettext-devel  libevent-devel  openssl-devel  readline-devel
default: working host-spawn neovim

# cli-tools build-tools otp

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
	FROM_REGISTRY=$(shell cat $< | jq -r '.Name')
	FROM_VERSION=$(shell cat $< | jq -r '.Labels.version')
	FROM_NAME=$(shell cat $< | jq -r '.Labels.name')
	printf "FROM_NAME=%s\n" $$FROM_NAME | tee $@
	printf "FROM_REGISTRY=%s\n" $$FROM_REGISTRY | tee -a $@
	VERSION=$(shell cat latest/fedora-toolbox.json | jq -r '.Labels.version')
	printf "FROM_VERSION=%s\n" $$FROM_VERSION | tee -a $@
	buildah pull $$FROM_REGISTRY:$$FROM_VERSION &> /dev/null
	echo -n "WORKING_CONTAINER=" | tee -a .env
	buildah from $$FROM_REGISTRY:$$FROM_VERSION | tee -a .env

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

clean:
	buildah run $(WORKING_CONTAINER) dnf autoremove -y
	buildah run $(WORKING_CONTAINER) rm -rf /tmp/*

.PHONY: help
help: ## show this help
	cat $(MAKEFILE_LIST) |
	grep -oP '^[a-zA-Z_-]+:.*?## .*$$' |
	sort |
	awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

working: info/working.md
info/working.md:
	mkdir -p $(dir $@)
	printf "$(HEADING2) %s\n\n" "Built with buildah" | tee $@
	printf "The Toolbox is built from %s" "$(shell cat latest/fedora-toolbox.json | jq -r '.Labels.name')" | tee -a $@
	printf ", version %s\n" $(FROM_VERSION) | tee -a $@
	printf "Pulled from registry:  %s\n" $(FROM_REGISTRY) | tee -a $@

cli-tools: info/cli.md
info/cli.md:
	buildah config --env LANG=C.UTF-8 $(WORKING_CONTAINER)
	mkdir -p $(dir $@)
	buildah run $(WORKING_CONTAINER) dnf upgrade -y --minimal
	for item in $(CLI)
	do
	buildah run $(WORKING_CONTAINER) dnf install \
		--allowerasing \
		--skip-unavailable \
		--skip-broken \
		--no-allow-downgrade \
		-y \
		$${item} &>/dev/null
	done
	printf "$(HEADING2) %s\n\n" "Handpicked CLI tools available in the toolbox" | tee $@
	$(call tr,"Name","Version","Summary",$@)
	$(call tr,"----","-------","----------------------------",$@)
	buildah run $(WORKING_CONTAINER) sh -c  'dnf info -q installed $(CLI) | \
	   grep -oP "(Name.+:\s\K.+)|(Ver.+:\s\K.+)|(Sum.+:\s\K.+)" | \
	   paste  - - -  | sort -u ' | \
	   awk -F'\t' '{printf "| %-14s | %-8s | %-83s |\n", $$1, $$2, $$3}' | \
	   tee -a $@
	$(call tr,"----","-------","----------------------------",$@)

build-tools: info/deps.md
info/deps.md:
	# echo '##[ $@ ]##'
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
	$(call tr,"----","-------","----------------------------",$@)

## HOST-SPAWN
host-spawn: info/host-spawn.md
latest/host-spawn.json:
	# echo '##[ $@ ]##'
	mkdir -p $(dir $@)
	wget -q -O - https://api.github.com/repos/1player/host-spawn/releases/latest |
	jq '.' > $@

info/host-spawn.md: latest/host-spawn.json
	# echo '##[ $@ ]##'
	mkdir -p $(dir $@)
	$(eval hs_src := $(shell $(call bdu,x86_64,$<)))
	# direct add
	buildah add --chmod 755 $(WORKING_CONTAINER) $(hs_src) /usr/local/bin/host-spawn &>/dev/null
	$(eval hs_ver := $(shell jq -r '.tag_name' $<))
	$(call tr,host-spawn,$(hs_ver),run host cli commands inside the toolbox,$@)

xxxx:
	printf "\n$(HEADING2) %s\n\n" "Host Spawn" | tee $@
	printf "%s\n" "Host-spawn (version: $${NAME}) " | tee -a $@
	# close table
	printf "\n%s\n" "The following host executables can be used from this toolbox" | tee -a $@
	for item in $(SPAWN)
	do
	buildah run $(WORKING_CONTAINER) ln -fs /usr/local/bin/host-spawn /usr/local/bin/$${item}
	printf " - %s\n" "$${item}" | tee -a $@
	done

##[[ EDITOR ]]##

NEOVIM_SRC := https://github.com/neovim/neovim/releases/download/nightly/nvim-linux-x86_64.tar.gz
nvimVersion != buildah run $(WORKING_CONTAINER) nvim --version| grep -oP 'NVIM \K.+' | cut -d'-' -f1

neovim: info/neovim.md
info/neovim.md:
	echo '##[ $@ ]##'
	mkdir -p $(dir $@)
	mkdir -p files/neovim/usr/local
	wget -q --timeout=10 --tries=3 $(NEOVIM_SRC) -O- | tar xz --strip-components=1 -C files/neovim/usr/local &>/dev/null
	buildah add --chmod 755 $(WORKING_CONTAINER) files/neovim &>/dev/null
	buildah run $(WORKING_CONTAINER) ls -la /usr/local/bin
	# $(call nvimVersion)
	$(call tr,Neovim,$(call nvimVersion),The text editor with a focus on extensibility and usability,$@)

# xxssaxx:
# buildah run $(WORKING_CONTAINER) nvim -v
# buildah run $(WORKING_CONTAINER) whereis nvim
# buildah run $(WORKING_CONTAINER) which nvim
# # buildah run $(WORKING_CONTAINER) printenv
# VERSION=$$(buildah run $(WORKING_CONTAINER) sh -c 'nvim -v' | grep -oP 'NVIM \K.+' | cut -d'-' -f1 )
# printf "| %-10s | %-13s | %-83s |\n" "Neovim"\
# "$$VERSION" "The text editor with a focus on extensibility and usability" | tee -a $@

luajit: info/luajit.md
info/luajit.md:
	echo '##[ $@ ]##'
	# printf "\n$(HEADING2) %s\n\n" "$$NAME"
	buildah run $(WORKING_CONTAINER) dnf install -y luajit luajit-devel
	VERSION=$$(buildah run $(WORKING_CONTAINER) sh -c 'luajit -v')
	printf "| %-10s |\n" "$$VERSION" | tee -a $@

luarocks: info/luarocks.md

latest/luarocks.tag_name:
	# echo '##[ $@ ]##'
	mkdir -p $(dir $@)
	wget -q 'https://api.github.com/repos/luarocks/luarocks/tags' -O- | jq -r '.[0].name'  > $@

info/luarocks.md: latest/luarocks.tag_name
	echo '##[ $@ ]##'
	buildah run $(WORKING_CONTAINER) rm -rf /tmp/*
	buildah run $(WORKING_CONTAINER) mkdir -p /etc/xdg/luarocks
	NAME=$$(jq -r '.name' $< | sed 's/v//')
	URL=$$(jq -r '.tarball_url' $<)
	# echo "name: $${NAME}"
	# echo "url: $${URL}"
	mkdir -p files/luarocks
	wget $${URL} -q -O- | tar xz --strip-components=1 -C files/luarocks &>/dev/null
	buildah run $(WORKING_CONTAINER) rm -rf /tmp/*
	buildah add --chmod 755 $(WORKING_CONTAINER) files/luarocks /tmp &>/dev/null
	buildah run $(WORKING_CONTAINER) sh -c 'cd /tmp && ./configure \
	--lua-version=5.1 --with-lua-interpreter=luajit \
	--sysconfdir=/etc/xdg --force-config --disable-incdir-check' &>/dev/null
	buildah run $(WORKING_CONTAINER) sh -c 'cd /tmp && make && make install' &>/dev/null
	buildah run $(WORKING_CONTAINER) rm -rf /tmp/*
	buildah run $(WORKING_CONTAINER) luarocks install luarocks &>/dev/null
	#Cean up buildah run $(WORKING_CONTAINER) luarocks show luarocks
	printf "| %-10s | %-13s | %-83s |\n" "luarocks" "$$NAME" "built from source from latest luarocks tag" | tee $@
	buildah run $(WORKING_CONTAINER) sh -c 'find /usr/local/share/lua/5.1/luarocks/ -type f -name "*.lua~" -exec rm {} \;'
	buildah run $(WORKING_CONTAINER) sh -c 'rm /usr/local/bin/luarocks~ /usr/local/bin/luarocks-admin~'
	# CHECK:
#buildah run $(WORKING_CONTAINER) which luarocks
	#buildah run $(WORKING_CONTAINER) whereis luarocks
	#buildah run $(WORKING_CONTAINER) luarocks

nlua: info/nlua.info
info/nlua.info:
	echo '##[ $@ ]##'
	buildah run $(WORKING_CONTAINER) luarocks install nlua
	buildah run $(WORKING_CONTAINER) luarocks show nlua
	buildah run $(WORKING_CONTAINER) luarocks config lua_version 5.1
	## TODO: I think this is redundant as we only have to use the above
	## @see https://github.com/mfussenegger/nlua
	buildah run $(WORKING_CONTAINER) luarocks config lua_interpreter nlua
	buildah run $(WORKING_CONTAINER) luarocks config variables.LUA /usr/local/bin/nlua
	# buildah run $(WORKING_CONTAINER) luarocks config variables.LUA_INCDIR /usr/local/include/luajit-2.1
	buildah run $(WORKING_CONTAINER) which nlua
	buildah run $(WORKING_CONTAINER) whereis nlua
	printf "| %-10s | %-13s | %-83s |\n" "nlua" " " "@see https://github.com/mfussenegger/nlua" | tee -a $@
	buildah run $(WORKING_CONTAINER) luarocks install busted
	printf "| %-10s | %-13s | %-83s |\n" "busted" " " "@see " | tee -a $@

tiktoken: info/tiktoken.info
info/tiktoken.info:
	echo '##[ $@ ]##'
	SRC=https://github.com/gptlang/lua-tiktoken/releases/download/v0.2.3/tiktoken_core-linux-x86_64-lua51.so
	TARG=/usr/local/lib/lua/5.1/tiktoken_core-linux.so
	# nlua -e 'print(package.)'
	buildah add --chmod 755 $(WORKING_CONTAINER) $${SRC} $${TARG} &>/dev/null
	printf "| %-10s | %-13s | %-83s |\n" "tiktoken" "0.2.3" "The lua module for generating tiktok tokens" | tee -a $@
	# buildah run $(WORKING_CONTAINER) exa --tree /usr/local/lib/lua/5.1
	# buildah run $(WORKING_CONTAINER) exa --tree /usr/local/share/lua/5.1


# beam: info/beam.md
# info/beam.md: 
# 	printf "\n$(HEADING2) %s\n\n" "BEAM tooling" | tee $@
# 	cat << EOF | tee -a $@
# 	The BEAM is the virtual machine at the core of the Erlang Open Telecom Platform (OTP).
# 	Installed in this toolbox are the Erlang and Elixir programming languages.
# 	Also installed are the Rebar3 build tool and the Mix build tool for Elixir.
# 	This tooling is used to develop with the Gleam programming language.
# 	EOF
# 	$(call beam_tr,"Name","Version","Summary") | tee  $@
# 	$(call beam_tr,"----","-------","----------------------------") | tee -a $@
# 	cat info/otp.md | tee -a $@
# 	cat info/elixir.md | tee -a $@
# 	cat info/rebar3.md | tee -a $@
# 	cat info/gleam.md | tee -a $@
# 	$(call beam_tr,"----","-------","----------------------------") | tee -a $@

## keep this 

latest/otp.version:
	mkdir -p $(dir $@)
	wget -q -O- https://www.erlang.org/downloads |
	grep -oP 'The latest version of Erlang/OTP is(.+)>\K(\d+\.){2}\d+' | tee $@

latest_otp_version = wget -q -O- https://www.erlang.org/downloads | \
	grep -oP 'The latest version of Erlang/OTP is(.+)>\K(\d+\.){2}\d+'

latest/otp.json:
	# echo '##[ $@ ]##'
	$(eval otp_tag := $(shell $(call latest_otp_version)))
	wget -q -O - https://api.github.com/repos/erlang/otp/releases |
	jq -r '.[] | select(.tag_name | endswith("'$(otp_tag)'"))' > $@


otp: info/otp.md
info/otp.md: latest/otp.json
	# echo '##[ $@ ]##'
	$(eval otp_src := $(shell $(call bdu,otp_sr,$<)))
	$(eval otp_ver := $(shell jq -r '.tag_name' $< | cut -d- -f2))
	mkdir -p files/otp && wget -q --timeout=10 --tries=3  $(otp_src) -O- |
	tar xz --strip-components=1 -C files/otp &>/dev/null
	buildah add --chmod 755 $(WORKING_CONTAINER) files/otp /tmp &>/dev/null
	buildah run $(WORKING_CONTAINER) sh -c 'cd /tmp && ./configure \
	--prefix=/usr/local \
	--without-asn1 \
	--without-cdv \
	--without-snmp \
	--without-cosEvent \
	--without-debugger \
	--without-dialyzer \
	--without-et \
	--without-hipe \
	--without-javac \
	--without-megaco \
	--without-observer \
	--without-odbc \
	--without-wx' &>/dev/null
	buildah run $(WORKING_CONTAINER) sh -c 'cd /tmp && make && make install' &>/dev/null
	buildah run $(WORKING_CONTAINER) rm -rf /tmp/*
	$(call tr ,OTP,$(otp_ver),the Erlang Open Telecom Platform OTP,$@)

latest/elixir.json:
	echo '##[ $@ ]##'
	mkdir -p $(dir $@)
	wget -q --show-progress --timeout=10 --tries=3  https://api.github.com/repos/elixir-lang/elixir/releases/latest -O- |
	jq '.' > $@

elixir_download = $(addsuffix .zip,https://github.com/elixir-lang/elixir/releases/download/$(1)/elixir-otp-$(2))
get_otp_version = $(shell buildah run $(1) erl -noshell -eval "erlang:display(erlang:system_info(otp_release)), halt().")

elixir: info/elixir.md
info/elixir.md: latest/elixir.json
	echo '##[ $@ ]##'
	# using precompiled binaries
	$(eval tag_name := $(shell jq -r '.tag_name' $<))
	# echo -n "TAGNAME: "
	# echo "$(tag_name)"
	$(eval major := $(call get_otp_version, $(WORKING_CONTAINER)))
	# echo -n "MAJOR: "
	# echo "$(major)"
	$(eval src := $(call elixir_download,$(tag_name),$(major)))
	echo "download URL: $(src)"
	wget -q --timeout=10 --tries=3 $(src) -O elixir.zip
	mkdir -p files/elixir/usr/local
	unzip elixir.zip -d files/elixir/usr/local &>/dev/null
	buildah add $(WORKING_CONTAINER) files/elixir &>/dev/null
	$(eval elixir_v := $(shell buildah run $(WORKING_CONTAINER) elixir -v))
	$(eval elixir_ver := $(shell echo "$(elixir_v)" | grep -oP 'Elixir \K.+' | cut -d' ' -f1))
	$(call tr,Elixir,$(elixir_ver),Elixir programming language, $@)
	# printf "| %-8s | %-7s | %-83s |\n" "elixir" "$(elixir_ver)" "compiled with Erlang/OTP $(major)" | tee -a $@
	$(eval mix_ver := $(shell buildah run $(WORKING_CONTAINER) mix -v | grep -oP 'Mix \K.+' | cut -d' ' -f1))
	$(call tr,Mix,$(mix_ver),Elixir build tool, $@)
	# printf "| %-8s | %-7s | %-83s |\n" "mix" "$(mix_ver)" "Mix, elixir build tool" | tee -a $@

latest/rebar3.json:
	echo '##[ $@ ]##'
	mkdir -p $(dir $@)
	wget -q -O - https://api.github.com/repos/erlang/rebar3/releases/latest | jq '.' > $@

rebar3: info/rebar3.md
info/rebar3.md: latest/rebar3.json
	echo '##[ $@ ]##'
	$(eval rebar_ver := $(shell jq -r '.tag_name' $<))
	$(eval rebar_src := $(shell jq -r '.assets[].browser_download_url' $<))
	buildah add --chmod 755 $(WORKING_CONTAINER) $(rebar_src) /usr/local/bin/rebar3 &>/dev/null
	$(eval rebar_sum := $(shell buildah run $(WORKING_CONTAINER) rebar3 -v | grep -oP '^.+ \Kon.+'))
	$(call tr,Rebar3,$(rebar_ver),$(rebar_sum),$@)


##[[ GLEAM ]]##
latest/gleam.download:
	mkdir -p $(dir $@)
	wget -q -O - 'https://api.github.com/repos/gleam-lang/gleam/releases/latest' |
	jq  -r '.assets[].browser_download_url' |
	grep -oP '.+x86_64-unknown-linux-musl.tar.gz$$' > $@

gleam: info/gleam.md
info/gleam.md: latest/gleam.download
	mkdir -p $(dir $@)
	mkdir -p files/gleam/usr/local/bin
	$(eval gleam_src := $(shell cat $<))
	wget $(gleam_src) -q -O- | tar xz --strip-components=1 --one-top-level="gleam" -C files/gleam/usr/local/bin
	buildah add --chmod 755 $(WORKING_CONTAINER) files/gleam &>/dev/null
	$(eval gleam_ver := $(shell buildah run $(WORKING_CONTAINER) gleam --version | cut -d' ' -f2))
	$(call tr,Gleam,$(gleam_ver),Gleam programming language,$@)

xxxxx:
	printf "$(HEADING1) %s\n\n" "A bundle LSP server and 'runtime' container images" | tee $@
	cat << EOF | tee -a $@
	The main developer experience language this toolbox provides for, is for the Gleam language.
	EOF
	buildah run $(WORKING_CONTAINER) gleam --help  | tee -a $@


##[[ NODEJS ]]##
latest/nodejs.tagname:
	echo '##[ $@ ]##'
	mkdir -p $(dir $@)
	wget -q -O - 'https://api.github.com/repos/nodejs/node/releases/latest' |
	jq '.tag_name' |  tr -d '"' > $@

nodejs: info/nodejs.md
info/nodejs.md: latest/nodejs.tagname
	# echo '##[ $@ ]##'
	# printf "\n$(HEADING2) %s\n\n" "Nodejs runtime" | tee $@
	$(eval node_ver := $(shell cat $<))
	mkdir -p files/nodejs/usr/local
	wget https://nodejs.org/download/release/$(node_ver)/node-$(node_ver)-linux-x64.tar.gz -q -O- |
	tar xz --strip-components=1 -C files/nodejs/usr/local
	buildah add --chmod 755  $(WORKING_CONTAINER) files/nodejs &>/dev/null
	$(call tr,Nodejs,$(node_ver),Nodejs runtime, $@)

