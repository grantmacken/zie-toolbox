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

IMAGE    :=  ghcr.io/grantmacken/tbx-cli-tools:latest
CONTAINER := tbx-cli-tools-working-container
TBX_IMAGE := ghcr.io/grantmacken/tbx-nvim-release
TBX_CONTAINER_NAME=tbx-nvim-release

CLI   := bat direnv eza fd-find fzf gh jq make ripgrep stow wl-clipboard yq zoxide
SPAWN := firefox flatpak podman buildah systemctl rpm-ostree dconf
# common deps used to build luajit and luarocks
DEPS   := gcc gcc-c++ glibc-devel ncurses-devel openssl-devel libevent-devel readline-devel gettext-devel
REMOVE := vim-minimal
# default-editor gcc-c++ gettext-devel  libevent-devel  openssl-devel  readline-devel

default: init config neovim
ifdef GITHUB_ACTIONS
	buildah commit $(CONTAINER) $(TBX_IMAGE)
	buildah push $(TBX_IMAGE):latest
endif

config: info/config.md
info/config.md:
	mkdir -p $(dir $@)
	buildah config --env NVIM_APPNAME=$(TBX_CONTAINER_NAME) $(CONTAINER)
	printf "%s\n" " - set nvim appname" | tee $@

init: info/working.info
info/working.info:
	echo '##[ $@ ]##'
	mkdir -p $(dir $@)
	buildah pull $(IMAGE) | tee  $@
	buildah from $(IMAGE) | tee -a $@
	echo

##[[ NEOVIM ]]##
neovim: info/neovim.md
latest/neovim.tagname:
	echo '##[ $@ ]##'
	mkdir -p $(dir $@)
	wget -q -O - 'https://api.github.com/repos/neovim/neovim/releases/latest' |
	jq  '.tag_name' | tr -d '"' > $@

info/neovim.md: latest/neovim.tagname
	echo '##[ $@ ]##'
	VERSION=$$(cat $<)
	printf "neovim version%s \n" "$${VERSION}"
	TARGET=files/$(basename $(notdir $@))/usr/local
	mkdir -p $${TARGET}
	SRC="https://github.com/neovim/neovim/releases/download/$${VERSION}/nvim-linux64.tar.gz"
	wget $${SRC} -q -O- | tar xz --strip-components=1 -C $${TARGET}
	buildah add --chmod 755 $(CONTAINER) files/$(basename $(notdir $@)) &>/dev/null
	# CHECK:
	buildah run $(CONTAINER) nvim -v
	buildah run $(CONTAINER) whereis nvim
	buildah run $(CONTAINER) which nvim
	printf "| %-10s | %-13s | %-83s |\n" "Neovim"\
		"$$VERSION" "The text editor with a focus on extensibility and usability" | tee -a $@

####################################################

setup:
	# podman pull $(TBX_IMAGE):latest
	# podman inspect $(TBX_IMAGE)
	printf "toolbox container name: %s\n" "$(TBX_CONTAINER_NAME)"
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

