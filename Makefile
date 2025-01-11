MAKEFLAGS += --warn-undefined-variables
MAKEFLAGS += --no-builtin-rules
MAKEFLAGS += --no-builtin-variables
MAKEFLAGS += --silent
unexport MAKEFLAGS

SHELL       := /usr/bin/bash
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

IMAGE     := registry.fedoraproject.org/fedora-toolbox:41
CONTAINER := fedora-toolbox-working-container

TBX_IMAGE=ghcr.io/grantmacken/tbx-cli-tools
TBX_CONTAINER_NAME=tbx-cli-tools


CLI   := bat direnv eza fd-find fzf gh jq make ripgrep stow wl-clipboard yq zoxide
SPAWN := firefox flatpak podman buildah systemctl rpm-ostree dconf
# common deps used to build luajit and luarocks
DEPS   := gcc gcc-c++ glibc-devel ncurses-devel openssl-devel libevent-devel readline-devel gettext-devel
REMOVE := vim-minimal

default: init config cli-tools host-spawn nodejs clean
ifdef GITHUB_ACTIONS
	buildah commit $(CONTAINER) $(TBX_IMAGE)
	buildah push $(TBX_IMAGE):latest
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

config: info/config.md
info/config.md:
	mkdir -p $(dir $@)
	buildah config \
		--shell /usr/bin/bash \
		--env SHELL=/usr/bin/bash \
		--cmd /usr/bin/bash \
		--author grantmacken \
	    --comment 'built from $(IMAGE)' \
		$(CONTAINER)
	printf "%s\n" " - set shell to bash" | tee $@

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

##[[ NODEJS ]]##
latest/nodejs.tagname:
	echo '##[ $@ ]##'
	mkdir -p $(dir $@)
	wget -q -O - 'https://api.github.com/repos/nodejs/node/releases/latest' |
	jq '.tag_name' |  tr -d '"' > $@

nodejs: info/nodejs.md
info/nodejs.md: latest/nodejs.tagname
	# echo '##[ $@ ]##'
	printf "$(HEADING2) %s\n\n" "Nodejs runtime" | tee $@
	NAME=$(basename $(notdir $@))
	VERSION=$(shell cat $<)
	printf "nodejs version: %s\n" "$${VERSION}"
	SRC=https://nodejs.org/download/release/$${VERSION}/node-$${VERSION}-linux-x64.tar.gz
	printf "download URL: %s\n" "$${SRC}"
	TARGET=files/$${NAME}/usr/local
	printf "download TARGET: %s\n" "$${TARGET}"
	mkdir -p $${TARGET}
	wget $${SRC} -q -O- | tar xz --strip-components=1 -C $${TARGET}
	buildah add --chmod 755  $(CONTAINER) files/$${NAME} &>/dev/null
	printf "The toolbox nodejs: %s runtime.\n This is the **latest** prebuilt release" "$${VERSION}"  | tee -a $@
	printf "%s\n" "Sourced from [node org](https://nodejs.org/download/release/)"  | tee -a $@
	printf "%s\n" "Node runtime included as is pretty much ubiquitous"  | tee -a $@

####################################################

setup:
	# podman pull $(TBX_IMAGE):latest
	# toolbox create --image ghcr.io/grantmacken/tbx-cli-tools:latest tbx-cli-tools
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
