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

CLI   := bat direnv eza fd-find fzf gh jq make ripgrep stow wl-clipboard yq zoxide
SPAWN := firefox flatpak podman buildah systemctl rpm-ostree dconf
# common deps used to build luajit and luarocks
DEPS   := gcc gcc-c++ glibc-devel ncurses-devel openssl-devel libevent-devel readline-devel gettext-devel
REMOVE := vim-minimal
# default-editor gcc-c++ gettext-devel  libevent-devel  openssl-devel  readline-devel

default: init neovim
ifdef GITHUB_ACTIONS
	buildah commit $(CONTAINER) ghcr.io/grantmacken/tbx-nvim-release
	buildah push ghcr.io/grantmacken/tbx-nvim-release:latest
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
	buildah add --chmod 755 $(CONTAINER) $${TARGET} &>/dev/null
	# CHECK:
	buildah run $(CONTAINER) nvim -v
	printf "| %-10s | %-13s | %-83s |\n" "Neovim"\
		"$$VERSION" "The text editor with a focus on extensibility and usability" | tee -a $@

####################################################

pull:
	podman pull ghcr.io/grantmacken/tbx-nvim-release:latest

