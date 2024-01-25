SHELL=/bin/bash
.ONESHELL:
.SHELLFLAGS := -eu -o pipefail -c
.DELETE_ON_ERROR:
MAKEFLAGS += --warn-undefined-variables
MAKEFLAGS += --no-builtin-rules
MAKEFLAGS += --silent

# include .env
# https://github.com/ublue-os/toolboxes/tree/main/toolboxes


build: zie-wolfi-toolbox zie-toolbox ## build the toolboxes

zie-wolfi-toolbox: 
	buildah pull -q cgr.dev/chainguard/wolfi-base
	CONTAINER=$$(buildah from cgr.dev/chainguard/wolfi-base)
	buildah config \
    --label com.github.containers.toolbox='true' \
    --label usage='This image is meant to be used with the distrobox command' \
    --label summary='a Wolfi based toolbox' \
    --label maintainer='Grant MacKenzie <grantmacken@gmail.com>' $${CONTAINER}
	buildah run $${CONTAINER} sh -c 'apk update && apk upgrade' &>/dev/null
	# buildah run $${CONTAINER} sh -c 'apk info -vv | sort'
	# https://github.com/ublue-os/toolboxes/blob/main/toolboxes/wolfi-toolbox/packages.wolfi
	buildah run $${CONTAINER} sh -c 'apk add grep bash bzip2 coreutils curl diffutils findmnt findutils git gnupg gpg iproute2 iputils keyutils libcap=2.68-r0 libsm libx11 libxau libxcb libxdmcp libxext libice libxmu libxt mount ncurses ncurses-terminfo net-tools openssh-client pigz posix-libc-utils procps rsync su-exec tcpdump tree tzdata umount unzip util-linux util-linux-misc wget xauth xz zip vulkan-loader' &>/dev/null
	# Add Distrobox-host-exe and host-spawn
	SRC=https://raw.githubusercontent.com/89luca89/distrobox/main/distrobox-host-exec
	TARG=/usr/bin/distrobox-host-exec
	buildah add $${CONTAINER} $${SRC} $${TARG}
	HOST_SPAWN_VERSION=$$(buildah run $${CONTAINER} /bin/bash -c 'grep -oP "host_spawn_version=.\K(\d+\.){2}\d+" /usr/bin/distrobox-host-exec')
	echo $${HOST_SPAWN_VERSION}
	buildah run $${CONTAINER} /bin/bash -c "wget https://github.com/1player/host-spawn/releases/download/$${HOST_SPAWN_VERSION}/host-spawn-x86_64 -O /usr/bin/host-spawn"
	buildah run $${CONTAINER} /bin/bash -c 'chmod +x /usr/bin/host-spawn'
	buildah run $${CONTAINER} /bin/bash -c 'ln -fs /bin/sh /usr/bin/sh'
	# symlink to exectables on host
	buildah run $${CONTAINER} /bin/bash -c 'mkdir -p /usr/local/bin'
	buildah run $${CONTAINER} /bin/bash -c 'ln -fs /usr/bin/distrobox-host-exec /usr/local/bin/flatpak'
	buildah run $${CONTAINER} /bin/bash -c 'ln -fs /usr/bin/distrobox-host-exec /usr/local/bin/podman'
	buildah run $${CONTAINER} /bin/bash -c 'ln -fs /usr/bin/distrobox-host-exec /usr/local/bin/rpm-ostree'
	# Add Make as already in os symlink here? otherwise use build-base
	buildah run $${CONTAINER} /bin/bash -c 'ln -fs /usr/bin/distrobox-host-exec /usr/local/bin/make'
	# Change root shell to BASH
	buildah run $${CONTAINER} /bin/bash -c 'sed -i -e "/^root/s/\/bin\/ash/\/bin\/bash/" /etc/passwd'
	# buildah run $${CONTAINER} sh -c 'echo "#1000 ALL = (root) NOPASSWD:ALL" >> /etc/sudoers'
	buildah commit --rm $${CONTAINER} ghcr.io/grantmacken/$@
	podman images
	buildah push ghcr.io/grantmacken/$@:latest

buildr-go: ## a ephemeral localhost container which builds go executables
	CONTAINER=$$(buildah from cgr.dev/chainguard/go:latest)
	#buildah run $${CONTAINER} /bin/bash -c 'go env GOPATH'
	buildah run $${CONTAINER} sh -c 'git config --global http.postBuffer 524288000 && git config --global http.version HTTP/1.1 '
	buildah run $${CONTAINER} sh -c 'git clone https://github.com/twpayne/chezmoi.git'
	buildah run $${CONTAINER} sh -c 'cd chezmoi; make install-from-git-working-copy' &>/dev/null
	buildah run $${CONTAINER} sh -c 'mkdir -p /usr/local/bin'
	buildah run $${CONTAINER} sh -c 'mv $$(go env GOPATH)/bin/chezmoi /usr/local/bin/chezmoi'
	# buildah run $${CONTAINER} sh -c 'tree $$(go env GOPATH) '
	# buildah run $${CONTAINER} sh -c 'which chezmoi && chezmoi --help'
	# # buildah run $${CONTAINER} sh -c 'which chezmoi && chezmoi --help'
	buildah commit --rm $${CONTAINER} $@


zie-toolbox: buildr-go
	CONTAINER=$$(buildah from ghcr.io/grantmacken/zie-wolfi-toolbox:latest)
	buildah add --from localhost/buildr-go $${CONTAINER} '/usr/local/bin/chezmoi' '/usr/local/bin/chezmoi'
	buildah commit --rm $${CONTAINER} ghcr.io/grantmacken/$@
	podman images
	buildah push ghcr.io/grantmacken/$@:latest


clean: 
	rm -f $(HOME)/.config/containers/systemd/wolfi-distrobox-quadlet.container
	rm -f $(HOME)/.config/containers/systemd/bluefin-cli.container

create:
	# https://github.com/89luca89/distrobox/blob/main/docs/usage/distrobox-create.md
	# distrobox create --compatibility
	# man --no-pager distrobox-compatibility
	# distrobox create --image ghcr.io/grantmacken/zie-brew-toolbox --name brew  # --verbose
	distrobox create --image localhost/tbx:latest --name tbx  # --verbose

export-bin: 
	# from within container
	# https://github.com/89luca89/distrobox/blob/main/docs/usage/distrobox-export.md
	# distrobox-export

ephemeral:
	https://github.com/89luca89/distrobox/blob/main/docs/usage/distrobox-ephemeral.md



check: 
ifdef CONTAINER_ID
	echo 'hi'
	#systemctl --no-pager --user show wolfi-distrobox-quadlet.service
	# journalctl --no-pager --user -xeu wolfi-distrobox-quadlet.service
	# cat $(HOME)/.config/containers/systemd/wolfi-distrobox-quadlet.container
	#echo
	# systemctl --no-pager --user list-unit-files
	# podman auto-update --dry-run --format "{{.Image}} {{.Updated}}"
	# /usr/lib/systemd/system-generators/podman-system-generator --user --dryrun
endif

quadlets: $(HOME)/.config/containers/systemd/wolfi-distrobox-quadlet.container
	tree $(HOME)/.config/containers/systemd
	systemctl --user daemon-reload

$(HOME)/.config/containers/systemd/wolfi-distrobox-quadlet.container:
	mkdir -p $(dir $@)
	wget -qO- https://raw.githubusercontent.com/ublue-os/toolboxes/main/quadlets/wolfi-toolbox/wolfi-distrobox-quadlet.container |
	sed 's%ghcr.io/ublue-os/wolfi-toolbox:latest%ghcr.io/grantmacken/zie-wolfi-toolbox:latest%' | 
	tee $@



wolfi-base:
	podman pull cgr.dev/chainguard/wolfi-base
	podman run --rm wolfi-base sh -c 'apk info -vv | sort' | tee pkg.list

sbom:
	# podman run --rm wolfi-base ls /var/lib/db/sbom
	# podman run --rm maven ls /var/lib/db/sbom

pull-zie:
	# for building
	podman pull ghcr.io/grantmacken/zie-wolfi-toolbox:latest

pull-lang:
	# for building
	podman pull cgr.dev/chainguard/rust:latest
	podman pull cgr.dev/chainguard/node:latest
	podman pull cgr.dev/chainguard/go:latest
	podman pull cgr.dev/chainguard/maven:latest
	podman pull cgr.dev/chainguard/erlan:latestg
	podman pull cgr.dev/chainguard/ocam:latest
	podman pull cgr.dev/chainguard/perl:latest

pull-deploy:
	# for deployment
	podman pull cgr.dev/chainguard/google-cloud-sdk:latest
	podman pull cgr.dev/chainguard/static:latest
	podman pull cgr.dev/chainguard/opam
	podman pull cgr.dev/chainguard/wasmtime
	# apps

pull-apps:
	podman pull cgr.dev/chainguard/cosign
	podman pull cgr.dev/chainguard/curl
	podman pull cgr.dev/chainguard/dive
	podman pull cgr.dev/chainguard/wait-for-it

pull-wolfi:
	podman pull cgr.dev/chainguard/melange
	podman pull cgr.dev/chainguard/apko

# info:
# 	apk info --installed brew
# 	apk info --version brew
# 	echo
# 	apk info --provides brew
# 	apk info --depends brew
# 	echo
# 	apk info --contents brew
	# apk info --description brew


# build-brew:
# 	CONTAINER=$$(buildah from ghcr.io/grantmacken/zie-wolfi-toolbox)
# 	buildah config \
#     --label com.github.containers.toolbox='true' \
#     --label usage='Enter toolbox to install cli applications' \
#     --label summary='a Wolfi based toolbox with brew' \
#     --label maintainer='Grant MacKenzie <grantmacken@gmail.com>' $${CONTAINER}
# 	SRC=https://raw.githubusercontent.com/ublue-os/toolboxes/main/toolboxes/bluefin-cli/files/etc/profile.d/bash_completion.sh
# 	TARG=/etc/profile.d/bash_completion.sh
# 	buildah add $${CONTAINER} $${SRC} $${TARG}
# 	buildah run $${CONTAINER} cat $${TARG}
# 	FILE=https://raw.githubusercontent.com/ublue-os/toolboxes/main/toolboxes/bluefin-cli/files/etc/profile.d/00-bluefin-cli-brew-firstrun.sh
# 	TARG=/etc/profile.d/00-bluefin-cli-brew-firstrun.sh
# 	buildah add $${CONTAINER} $${SRC} $${TARG}
# 	buildah run $${CONTAINER} cat $${TARG}
# 	echo
# 	FILE=https://raw.githubusercontent.com/ublue-os/toolboxes/main/toolboxes/bluefin-cli/files/root/.bash_profile
# 	TARG=/root/.bash_profile
# 	buildah add $${CONTAINER} $${SRC} $${TARG}
# 	buildah run $${CONTAINER} cat $${TARG}
# 	echo
# 	FILE=https://raw.githubusercontent.com/ublue-os/toolboxes/main/toolboxes/bluefin-cli/files/root/.bashrc
# 	TARG=/root/.bashrc
# 	buildah add $${CONTAINER} $${SRC} $${TARG}
# 	buildah run $${CONTAINER} cat $${TARG}
# 	echo
# 	# buildah run $${CONTAINER} /bin/bash -c 'apk info -vv | sort'
# 	buildah run $${CONTAINER} /bin/bash -c 'apk add brew cosign skopeo sudo-rs'
# 	buildah run $${CONTAINER} /bin/bash -c 'mv /home/linuxbrew /home/homebrew'
# 	buildah commit --rm $${CONTAINER} ghcr.io/grantmacken/zie-brew-toolbox
# 	buildah push ghcr.io/grantmacken/zie-brew-toolbox


# init-brew:
# 	green=$$'\033[32m'; bold=$$'\033[1m'; normal=$$'\033[0m'
# 	echo $${XDG_DATA_HOME}
# 	if test ! -f /etc/linuxbrew.firstrun
# 	then
# 	 printf "Setting up sudo for $${green}$${USER}$${normal}...\t\t\t "
# 	 # echo "#$${UID} ALL = (root) NOPASSWD:ALL" | su-exec root tee -a /etc/sudoers > /dev/null
# 	 printf "$${green}[ OK ]$${normal}\n"
# 	 su-exec root cat /etc/sudoers
# 	fi
# 	printf "Setting up Linuxbrew" && echo
# 	if test ! -d /home/linuxbrew; then
# 	printf ' -  mkdir /home/linuxbrew'
# 	su-exec root mkdir -p /home/linuxbrew
# 	fi
# 	if test ! -d /home/linuxbrew/.linuxbrew
# 	then
# 	 echo "create in xdg data dir a brew cli"
# 	 if test ! -d "$${XDG_DATA_HOME}"/brew-cli
# 	 then
# 	 mkdir -p "$${XDG_DATA_HOME}"/brew-cli
# 	 fi
# 	fi
# 	if test ! -d /usr/local/share/bash-completion/completions
# 	then
# 	printf "Setting up Tab-Completions...\t "
# 	su-exec root mkdir -p /usr/local/share/bash-completion
# 	su-exec root mount --bind /run/host/usr/share/bash-completion /usr/local/share/bash-completion
# 	printf "$${green}[ OK ]$${normal}\n"
# 	fi
# 	if test ! -f /etc/linuxbrew.firstrun
# 	then
# 	 su-exec root touch /etc/linuxbrew.firstrun
# 	 printf "\nBluefin-CLI first run complete!\n\n"
# 	fi






# build-neovim:
# 	BUILDR=$$(buildah from localhost/tbx-buildr)
# 	buildah run $${BUILDR} /bin/bash -c 'git config --global http.postBuffer 524288000 && git config --global http.version HTTP/1.1 '
# 	buildah run $${BUILDR} /bin/bash -c 'git clone https://github.com/neovim/neovim'
# 	buildah run $${BUILDR} /bin/bash -c 'cd neovim && make CMAKE_BUILD_TYPE=RelWithDebInfo CMAKE_INSTALL_PREFIX=/usr CMAKE_INSTALL_LIBDIR=lib && make install'
# 	buildah run $${BUILDR} /bin/bash -c 'which nvim && nvim --version'
# 	buildah run $${BUILDR} /bin/bash -c 'cd ../ && rm -R neovim'
# 	buildah commit --rm $${BUILDR} tbx-neovim
#
# build: ##
# 	# CONTAINER=$$(buildah from localhost/tbx-base)
# 	# buildah add --from localhost/tbx-neovim $${CONTAINER} '/usr/share/nvim' '/usr/share/nvim'
# 	# buildah add --from localhost/tbx-neovim $${CONTAINER} '/usr/bin/nvim' '/usr/bin/nvim'
# 	# buildah add --from localhost/tbx-neovim $${CONTAINER} '/usr/lib/nvim' '/usr/lib/nvim'
# 	# # Get Distrobox-host-exec 
# 	# buildah add $${CONTAINER} 'https://raw.githubusercontent.com/89luca89/distrobox/main/distrobox-host-exec' '/usr/bin/distrobox-host-exec'
# 	# buildah run $${CONTAINER} sh -c 'apk add grep'
# 	# # buildah add  $${CONTAINER} '$(abspath files/usr/local/bin)' '/usr/local/bin'
# 	# buildah run $${CONTAINER} sh -c 'grep -oP "host_spawn_version=\K.+" /usr/bin/distrobox-host-exec'
# 	# buildah commit --rm $${CONTAINER} zie-neovim
# 	#
#
#
#
#

# https://github.com/memorysafety/sudo-rs


