SHELL=/bin/bash
.ONESHELL:
.SHELLFLAGS := -eu -o pipefail -c
.DELETE_ON_ERROR:
MAKEFLAGS += --warn-undefined-variables
MAKEFLAGS += --no-builtin-rules
MAKEFLAGS += --silent

# include .env
# https://github.com/ublue-os/toolboxes/tree/main/toolboxes

wolfi-base:
	podman pull cgr.dev/chainguard/wolfi-base
	podman run --rm wolfi-base sh -c 'apk info -vv | sort' | tee pkg.list

sbom:
	# podman run --rm wolfi-base ls /var/lib/db/sbom
	# podman run --rm maven ls /var/lib/db/sbom


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


build-chezmoi:
	CONTAINER=$$(buildah from cgr.dev/chainguard/go:latest)
	#buildah run $${CONTAINER} /bin/bash -c 'go env GOPATH'
	buildah run $${CONTAINER} sh -c 'git config --global http.postBuffer 524288000 && git config --global http.version HTTP/1.1 '
	buildah run $${CONTAINER} sh -c 'git clone https://github.com/twpayne/chezmoi.git'
	buildah run $${CONTAINER} sh -c 'cd chezmoi; make install-from-git-working-copy'
	# buildah run $${CONTAINER} sh -c 'tree $$(go env GOPATH) '
	# buildah run $${CONTAINER} sh -c 'mv $$(go env GOPATH)/bin/chezmoi /usr/local/bin/'
	# buildah run $${CONTAINER} sh -c 'which chezmoi && chezmoi --help'
	# # buildah run $${CONTAINER} sh -c 'which chezmoi && chezmoi --help'
	buildah commit --rm $${CONTAINER} buildr-chezmoi
	CONTAINER=$$(buildah from cgr.dev/chainguard/static:latest)
	buildah add --from localhost/buildr-chezmoi $${CONTAINER} '/root/go/bin/chezmoi' '/chezmoi'
	buildah commit --rm $${CONTAINER} chezmoi
	podman images
	docker run localhost/chezmoi


build-core:
	CONTAINER=$$(buildah from cgr.dev/chainguard/wolfi-base)
	buildah config \
    --label com.github.containers.toolbox='true' \
    --label usage='This image is meant to be used with the toolbox command' \
    --label summary='a Wolfi based toolbox' \
    --label maintainer='Grant MacKenzie <grantmacken@gmail.com>' $${CONTAINER}
	buildah run $${CONTAINER} sh -c 'apk update && apk upgrade'
	buildah run $${CONTAINER} sh -c 'apk info -vv | sort'
	buildah run $${CONTAINER} sh -c 'apk add bash git command-not-found procps sudo-rs'
	buildah run $${CONTAINER} /bin/bash -c 'apk add bzip2 coreutils curl diffutils findmnt findutils gnupg gpg iproute2 iputils keyutils libcap=2.68-r0 mount ncurses ncurses-terminfo net-tools openssh-client pigz posix-libc-utils procps rsync su-exec tcpdump tree tzdata umount util-linux util-linux-misc wget xz zip vulkan-loader'
	# Give UID = 1000 sudo
	buildah run $${CONTAINER} sh -c 'echo "#1000 ALL = (root) NOPASSWD:ALL" >> /etc/sudoers'
	buildah run $${CONTAINER} sh -c 'sed -i -e "/^root/s/\/bin\/ash/\/bin\/bash/" /etc/passwd'
	buildah run $${CONTAINER} sh -c 'cat /etc/passwd'
	buildah commit --rm $${CONTAINER} tbx-base

build-buildr:
	BUILDR=$$(buildah from localhost/tbx-base)
	buildah run $${BUILDR} /bin/bash -c 'apk add build-base cmake gettext-dev gperf libtermkey libtermkey-dev libuv-dev libvterm-dev lua-luv lua-luv-dev lua5.1-lpeg lua5.1-mpack luajit-dev msgpack samurai tree-sitter-dev unibilium-dev'
	buildah run $${BUILDR} sh -c 'apk info -vv | sort'
	buildah commit --rm $${BUILDR} tbx-buildr

build-neovim:
	BUILDR=$$(buildah from localhost/tbx-buildr)
	buildah run $${BUILDR} /bin/bash -c 'git config --global http.postBuffer 524288000 && git config --global http.version HTTP/1.1 '
	buildah run $${BUILDR} /bin/bash -c 'git clone https://github.com/neovim/neovim'
	buildah run $${BUILDR} /bin/bash -c 'cd neovim && make CMAKE_BUILD_TYPE=RelWithDebInfo CMAKE_INSTALL_PREFIX=/usr CMAKE_INSTALL_LIBDIR=lib && make install'
	buildah run $${BUILDR} /bin/bash -c 'which nvim && nvim --version'
	buildah run $${BUILDR} /bin/bash -c 'cd ../ && rm -R neovim'
	buildah commit --rm $${BUILDR} tbx-neovim

build: ##
	CONTAINER=$$(buildah from localhost/tbx-base)
	buildah add --from localhost/tbx-neovim $${CONTAINER} '/usr/share/nvim' '/usr/share/nvim'
	buildah add --from localhost/tbx-neovim $${CONTAINER} '/usr/bin/nvim' '/usr/bin/nvim'
	buildah add --from localhost/tbx-neovim $${CONTAINER} '/usr/lib/nvim' '/usr/lib/nvim'
	# Get Distrobox-host-exec 
	buildah add $${CONTAINER} 'https://raw.githubusercontent.com/89luca89/distrobox/main/distrobox-host-exec' '/usr/bin/distrobox-host-exec'
	buildah run $${CONTAINER} sh -c 'apk add grep'
	# buildah add  $${CONTAINER} '$(abspath files/usr/local/bin)' '/usr/local/bin'
	buildah run $${CONTAINER} sh -c 'grep -oP "host_spawn_version=\K.+" /usr/bin/distrobox-host-exec'
	buildah commit --rm $${CONTAINER} zie-neovim






# https://github.com/memorysafety/sudo-rs


