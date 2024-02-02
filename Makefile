SHELL=/bin/bash
.ONESHELL:
.SHELLFLAGS := -eu -o pipefail -c
.DELETE_ON_ERROR:
MAKEFLAGS += --warn-undefined-variables
MAKEFLAGS += --no-builtin-rules
MAKEFLAGS += --silent

# include .env
# https://github.com/ublue-os/toolboxes/tree/main/toolboxes

# build: zie-wolfi-toolbox zie-toolbox ## build the toolboxes

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
	buildah run $${CONTAINER} sh -c 'apk add bash bzip2 coreutils curl diffutils findmnt findutils git gnupg gpg iproute2 iputils keyutils libcap=2.68-r0 libsm libx11 libxau libxcb libxdmcp libxext libice libxmu libxt mount ncurses ncurses-terminfo net-tools openssh-client pigz posix-libc-utils procps rsync su-exec tcpdump tree tzdata umount unzip util-linux util-linux-misc wget xauth xz zip vulkan-loader' &>/dev/null
	# additional tools from chainguard
	echo "grep: GNU grep implementation"
	echo 'gh GitHub's official command line tool'
	buildah run $${CONTAINER} sh -c 'apk add cosign grep gh' &>/dev/null
	#gcloud Google Cloud Command Line Interface
	buildah run $${CONTAINER} sh -c 'apk add google-cloud-sdk' &>/dev/null
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

bldr-go: ## a ephemeral localhost container which builds go executables
	CONTAINER=$$(buildah from cgr.dev/chainguard/go:latest)
	# #buildah run $${CONTAINER} /bin/bash -c 'go env GOPATH'
	buildah run $${CONTAINER} sh -c 'mkdir -p $$(go env GOPATH) $$(go env GOCACHE)'
	# echo 'COSIGN' install with apk
	# buildah run $${CONTAINER} sh -c 'git clone https://github.com/sigstore/cosign' &>/dev/null
	# buildah run $${CONTAINER} sh -c 'cd cosign && go install ./cmd/cosign' 
	# buildah run $${CONTAINER} sh -c 'which cosign'
	# #buildah run $${CONTAINER} sh -c 'mv $$(go env GOPATH)/bin/cosign /usr/local/bin/'
	# buildah run $${CONTAINER} sh -c 'rm -fR cosign' || true
	echo 'CHEZMOI'
	buildah run $${CONTAINER} sh -c 'git clone --depth 1 https://github.com/twpayne/chezmoi.git'
	buildah run $${CONTAINER} sh -c 'cd chezmoi; make install-from-git-working-copy' &>/dev/null
	buildah run $${CONTAINER} sh -c 'mkdir -p /usr/local/bin'
	buildah run $${CONTAINER} sh -c 'mv $$(go env GOPATH)/bin/chezmoi /usr/local/bin/chezmoi'
	buildah run $${CONTAINER} sh -c 'which chezmoi && chezmoi --help'
	buildah run $${CONTAINER} sh -c 'rm -fR chezmoi' || true
	echo 'GH-CLI' # the github cli install with apk
	# buildah run $${CONTAINER} sh -c 'git clone https://github.com/cli/cli.git gh-cli'
	# buildah run $${CONTAINER} sh -c 'cd gh-cli && make install prefix=/usr/local/gh' &>/dev/null
	# buildah run $${CONTAINER} sh -c 'tree /usr/local/gh'
	# buildah run $${CONTAINER} sh -c 'mv /usr/local/gh/bin/* /usr/local/bin/'
	# buildah run $${CONTAINER} sh -c 'which gh && gh --version && gh --help'
	# buildah run $${CONTAINER} sh -c 'rm -fR gh-cli' || true
	echo 'LAZYGIT' 
	# buildah run $${CONTAINER} sh -c 'git clone https://github.com/jesseduffield/lazygit.git' 
	# buildah run $${CONTAINER} sh -c 'cd lazygit && go install' &>/dev/null
	# buildah run $${CONTAINER} sh -c 'mv $$(go env GOPATH)/bin/lazygit /usr/local/bin/'
	# buildah run $${CONTAINER} sh -c 'which lazygit'
	# buildah run $${CONTAINER} sh -c 'rm -fR lazygit' || true
	buildah commit --rm $${CONTAINER} $@
	podman images
	podman save --quiet -o $@.tar localhost/$@

## https://edu.chainguard.dev/chainguard/chainguard-images/reference/rust/
## https://github.com/wolfi-dev/os/blob/main/ripgrep.yaml
## https://github.com/wolfi-dev/os/blob/main/tree-sitter.yaml
## https://github.com/wolfi-dev/os/blob/main/fd.yaml
bldr-rust: ## a ephemeral localhost container which builds go executables
	CONTAINER=$$(buildah from cgr.dev/chainguard/rust:latest)
	buildah run $${CONTAINER} rustc --version
	buildah run $${CONTAINER} cargo --version
	# buildah run $${CONTAINER} echo $${CARGO_HOME} || true
	buildah run $${CONTAINER} cargo install cargo-binstall &>/dev/null
	buildah run $${CONTAINER} /home/nonroot/.cargo/bin/cargo-binstall --no-confirm --no-symlinks stylua
	buildah run $${CONTAINER} rm /home/nonroot/.cargo/bin/cargo-binstall
	buildah run $${CONTAINER} ls /home/nonroot/.cargo/bin/
	# buildah config --env CARGO_HOME=/usr/local $${CONTAINER}
	# buildah run $${CONTAINER} sh -c 'ls /usr/local'
	buildah commit --rm $${CONTAINER} $@
	podman images
	podman save --quiet -o $@.tar localhost/$@

# https://github.com/wolfi-dev/os/blob/main/lazygit.yaml
# LSPs
# https://github.com/wolfi-dev/os/blob/main/rust-analyzer.yaml
#  description: A Rust compiler front-end for IDEs
zie-distro: 
	# podman load --quiet --input bldr-go/bldr-go.tar
	# podman load --quiet --input bldr-rust/bldr-rust.tar
	CONTAINER=$$(buildah from cgr.dev/chainguard/wolfi-base)
	SRC=https://raw.githubusercontent.com/89luca89/distrobox/main/distrobox-host-exec
	TARG=/usr/bin/distrobox-host-exec
	buildah add $${CONTAINER} $${SRC} $${TARG} from cgr.dev/chainguard/wolfi-base)

bldr-neovim: 
	CONTAINER=$$(buildah from cgr.dev/chainguard/wolfi-base)
	buildah run $${CONTAINER} sh -c 'apk update && apk upgrade' &>/dev/null
	buildah run $${CONTAINER} sh -c 'apk add build-base busybox cmake gettext-dev gperf libtermkey libtermkey-dev libuv-dev libvterm-dev lua-luv lua-luv-dev lua5.1-lpeg lua5.1-mpack luajit-dev msgpack samurai tree-sitter-dev unibilium-dev'
	buildah run $${CONTAINER} sh -c 'apk add git tree grep'
	buildah run $${CONTAINER} sh -c 'git clone --depth 1 https://github.com/neovim/neovim.git'
	buildah run $${CONTAINER} sh -c 'cd neovim && make CMAKE_BUILD_TYPE=RelWithDebInfo CMAKE_INSTALL_PREFIX=/usr/local'
	buildah run $${CONTAINER} sh -c 'cd neovim && make install'
	buildah run $${CONTAINER} sh -c 'tree /usr/local'
	# buildah run $${CONTAINER} sh -c 'cd neovim && cmake -S cmake.deps -B .deps -G Ninja -D 
	# CMAKE_BUILD_TYPE=RelWithDebInfo -DUSE_BUNDLED=OFF -DUSE_BUNDLED_TS_PARSERS=ON'
	# buildah run $${CONTAINER} sh -c 'cd neovim && cmake cmake --build .deps'
	# buildah run $${CONTAINER} sh -c 'cd neovim && cmake -B output -G Ninja 
	# -DCMAKE_BUILD_TYPE=RelWithDebInfo -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_INSTALL_LIBDIR=lib -DENABLE_JEMALLOC=FALSE -DENABLE_LTO=TRUE -DCMAKE_VERBOSE_MAKEFILE=TRUE -DCI_BUILD=OFF'

zie-toolbox: 
	# podman load --quiet --input bldr-go/bldr-go.tar
	# podman load --quiet --input bldr-rust/bldr-rust.tar
	CONTAINER=$$(buildah from cgr.dev/chainguard/wolfi-base)
	buildah config \
    --label com.github.containers.toolbox='true' \
    --label usage='This image is meant to be used with the distrobox command' \
    --label summary='a Wolfi based toolbox' \
    --label maintainer='Grant MacKenzie <grantmacken@gmail.com>' $${CONTAINER}
	buildah run $${CONTAINER} sh -c 'apk update && apk upgrade' &>/dev/null
	# https://github.com/ublue-os/toolboxes/blob/main/toolboxes/wolfi-toolbox/packages.wolfi
	buildah run $${CONTAINER} sh -c 'apk add bash bzip2 coreutils curl diffutils findmnt findutils git gnupg gpg iproute2 iputils keyutils libcap=2.68-r0 libsm libx11 libxau libxcb libxdmcp libxext libice libxmu libxt mount ncurses ncurses-terminfo net-tools openssh-client pigz posix-libc-utils procps rsync su-exec tcpdump tree tzdata umount unzip util-linux util-linux-misc wget xauth xz zip vulkan-loader' &>/dev/null
	# like boxkit add additional tools from chainguard
	echo "grep: GNU grep implementation - so I can use -oP flag "
	echo 'gh: GitHub official command line tool'
	echo 'gcloud: Google Cloud Command Line Interface'
	echo 'lazygit: simple terminal UI for git command'
	buildah run $${CONTAINER} /bin/bash -c 'apk add grep gh google-cloud-sdk' &>/dev/null
	# echo 'xxxx' | buildah run $${CONTAINER} /bin/bash -c 'cat - ' 
	# Add stuff NOT avaiable thru apk
	# buildah add --from localhost/bldr-go $${CONTAINER} '/usr/local/bin' '/usr/local/bin'
	# buildah add --from localhost/bldr-rust $${CONTAINER} '/home/nonroot/.cargo/bin' '/usr/local/bin'
	# Add Distrobox-host-exe and host-spawn
	# SRC=https://raw.githubusercontent.com/89luca89/distrobox/main/distrobox-host-exec
	# TARG=/usr/bin/distrobox-host-exec
	# buildah add $${CONTAINER} $${SRC} $${TARG}
	# HOST_SPAWN_VERSION=$$(buildah run $${CONTAINER} /bin/bash -c 'grep -oP "host_spawn_version=.\K(\d+\.){2}\d+" /usr/bin/distrobox-host-exec')
	# echo $${HOST_SPAWN_VERSION}
	# buildah run $${CONTAINER} /bin/bash -c "wget https://github.com/1player/host-spawn/releases/download/$${HOST_SPAWN_VERSION}/host-spawn-x86_64 -O /usr/bin/host-spawn"
	# buildah run $${CONTAINER} /bin/bash -c 'chmod +x /usr/bin/host-spawn'
	# buildah run $${CONTAINER} /bin/bash -c 'ln -fs /bin/sh /usr/bin/sh'
	# # symlink to exectables on host
	# buildah run $${CONTAINER} /bin/bash -c 'ln -fs /usr/bin/distrobox-host-exec /usr/local/bin/flatpak'
	# buildah run $${CONTAINER} /bin/bash -c 'ln -fs /usr/bin/distrobox-host-exec /usr/local/bin/podman'
	# buildah run $${CONTAINER} /bin/bash -c 'ln -fs /usr/bin/distrobox-host-exec /usr/local/bin/rpm-ostree'
	# # Add Make as already in os symlink here? otherwise use build-base
	# buildah run $${CONTAINER} /bin/bash -c 'ln -fs /usr/bin/distrobox-host-exec /usr/local/bin/make'
	# Change root shell to BASH
	buildah run $${CONTAINER} /bin/bash -c 'sed -i -e "/^root/s/\/bin\/ash/\/bin\/bash/" /etc/passwd'
	# buildah run $${CONTAINER} sh -c 'echo "#1000 ALL = (root) NOPASSWD:ALL" >> /etc/sudoers'
	buildah run $${CONTAINER} sh -c 'which gh && gh --version'
	buildah run $${CONTAINER} sh -c 'which gcloud && gcloud --version'
	buildah run $${CONTAINER} sh -c 'which chezmoi && chezmoi'
	buildah run $${CONTAINER} sh -c 'which lazygit && lazygit --version'
	# buildah run $${CONTAINER} sh -c 'apk info -vv | sort'
	buildah commit --rm $${CONTAINER} ghcr.io/grantmacken/$@
	podman images
	buildah push ghcr.io/grantmacken/$@:latest

upgrade:
	distrobox-upgrade zie

stop:
	distrobox stop --all

remove:
	distrobox rm --all

start:
	podman golang

ps:
	podman ps --all

clean: 
	distrobox stop --yes zie || true
	distrobox rm -f zie || true
	distrobox ls
	podman rmi -f -i ghcr.io/grantmacken/zie-toolbox:latest || true
	podman rmi -f -i localhost/tbx || true
	podman images




create: clean
	# https://github.com/89luca89/distrobox/blob/main/docs/usage/distrobox-create.md
	distrobox  stop -y zie
	distrobox  stop -y zie
	# distrobox create --image ghcr.io/grantmacken/zie-toolbox:latest --name zie  # --verbose
	# https://docs.podman.io/en/stable/markdown/podman-create.1.html
	# podman create cgr.dev/chainguard/go:latest -n golang

export-bin: 
	# from within container
	# https://github.com/89luca89/distrobox/blob/main/docs/usage/distrobox-export.md
	# distrobox-export

ephemeral:
	#https://github.com/89luca89/distrobox/blob/main/docs/usage/distrobox-ephemeral.md

inspect:
	# podman inspect zie | jq -r '.[0].Config.CreateCommand'
	podman inspect cgr.dev/chainguard/go

check: 
	echo 'hi'
	#systemctl --no-pager --user show wolfi-distrobox-quadlet.service
	# journalctl --no-pager --user -xeu wolfi-distrobox-quadlet.service
	# cat $(HOME)/.config/containers/systemd/wolfi-distrobox-quadlet.container
	#echo
	# systemctl --no-pager --user list-unit-files
	# podman auto-update --dry-run --format "{{.Image}} {{.Updated}}"
	# /usr/lib/systemd/system-generators/podman-system-generator --user --dryrun
 # $(HOME)/.config/containers/systemd/golang.image \
 # $(HOME)/.config/containers/systemd/erlang.image \
 # $(HOME)/.config/containers/systemd/nodelang.image \


# https://docs.podman.io/en/stable/markdown/podman-systemd.unit.5.html
#
# We create the quadlet image file. 
# This generates a oneshot systemd unit
# Then we invoke `systemctl --user daemon-reload`, so systemd sees the unit
# Then we start the oneshot systemd unit which pulls the latest image specified in the quadlet image file
# Next we set up a systemd timer for the unit so the latest container image is pulled on a weekly bases  
# TODO! check is pulling from remote registry

IMAGE_NAME_LIST := wait-for-it
BuildImagesList :=  $(patsubst %,$(HOME)/.config/containers/systemd/%.image,$(IMAGE_NAME_LIST))

.PHONY: images
images: $(BuildImagesList)

.PHONY: images
images-clean:
	echo $(BuildImagesList)
	rm -fv $(BuildImagesList) || true


status:
	#systemctl --no-pager --user cat erlang-image.service || true
	# systemctl --no-pager --user is-enabled rustlang-image.service || true
	# systemctl --no-pager --user list-unit-files --state=generated | grep -oP '^.+-image.service'
	# systemctl --no-pager --user status dive-image.service || true
	# systemctl --no-pager --user status dive-image.timer || true
	# # systemctl --no-pager --user status wait-for-it-image.service || true
	# # systemctl --no-pager --user  list-units --type=target || true
	# systemctl --no-pager --user --user list-jobs || true
	# # podman images | grep -oP '^cgr.+'
	# systemctl --no-pager --user cat dive-image.service || true
	systemctl --no-pager --user  list-timers --all || true
	# # systemd-analyze --no-pager --user unit-paths || true
	# cat /home/gmack/.local/share/systemd/timers/stamp-flatpak-user-update.timer || true
	# systemctl --user show-environment

	systemctl --no-pager  --user list-units || true


