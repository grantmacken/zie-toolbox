SHELL=/bin/bash
.ONESHELL:
.SHELLFLAGS := -eu -o pipefail -c
.DELETE_ON_ERROR:
MAKEFLAGS += --warn-undefined-variables
MAKEFLAGS += --no-builtin-rules
MAKEFLAGS += --silent

# include .env
# https://github.com/ublue-os/toolboxes/tree/main/toolboxes
# echo "grep: GNU grep implementation - so I can use -oP flag "
# echo 'gh: GitHub official command line tool'
# echo 'gcloud: Google Cloud Command Line Interface'
# echo 'lazygit: simple terminal UI for git command'
# buildah run $${CONTAINER} sh -c "apk add gh" &>/dev/null

build: zie-toolbox  ## build the toolboxes
quadlet: $(HOME)/.config/containers/systemd/zie-wolfi-toolbox.container

zie-wolfi-toolbox:
	echo '##[ $@ ]##'
	CONTAINER=$$(buildah from cgr.dev/chainguard/wolfi-base)
	buildah run $${CONTAINER} sh -c 'apk update && apk upgrade && apk add grep' &>/dev/null
	buildah config \
    --label com.github.containers.toolbox='true' \
    --label usage='This image is meant to be used with the distrobox command' \
    --label summary='a Wolfi based toolbox' \
    --label maintainer='Grant MacKenzie <grantmacken@gmail.com>' $${CONTAINER}
	SRC=https://raw.githubusercontent.com/ublue-os/toolboxes/main/toolboxes/wolfi-toolbox/packages.wolfi
	TARG=/toolbox-packages
	buildah add $${CONTAINER} $${SRC} $${TARG}
	buildah run $${CONTAINER} sh -c "grep -v '^#' /toolbox-packages | xargs apk add" &>/dev/null
	buildah run $${CONTAINER} sh -c "rm -f /toolbox-packages"
	SRC=https://raw.githubusercontent.com/89luca89/distrobox/main/distrobox-host-exec
	TARG=/usr/bin/distrobox-host-exec
	buildah add --chmod 755 $${CONTAINER} $${SRC} $${TARG}
	SRC=https://raw.githubusercontent.com/89luca89/distrobox/main/distrobox-export
	TARG=/usr/bin/distrobox-export
	buildah add --chmod 755 $${CONTAINER} $${SRC} $${TARG}
	SRC=https://raw.githubusercontent.com/89luca89/distrobox/main/distrobox-init
	TARG=/usr/bin/entrypoint
	buildah add --chmod 755 $${CONTAINER} $${SRC} $${TARG}
	HOST_SPAWN_VERSION=$$(buildah run $${CONTAINER} /bin/bash -c 'grep -oP "host_spawn_version=.\K(\d+\.){2}\d+" /usr/bin/distrobox-host-exec')
	echo "$${HOST_SPAWN_VERSION}"
	SRC=https://github.com/1player/host-spawn/releases/download/$${HOST_SPAWN_VERSION}/host-spawn-x86_64
	TARG=/usr/bin/host-spawn
	buildah add --chmod 755 $${CONTAINER} $${SRC} $${TARG}
	# buildah run $${CONTAINER} /bin/bash -c 'which gh' || true
	buildah run $${CONTAINER} /bin/bash -c 'which host-spawn' || true
	buildah run $${CONTAINER} /bin/bash -c 'which entrypoint' || true
	buildah run $${CONTAINER} /bin/bash -c 'which distrobox-export'|| true
	buildah run $${CONTAINER} /bin/bash -c 'which distrobox-host-exec'|| true
	# buildah run $${CONTAINER} /bin/bash -c 'which neovim' || true
	#symlink to exectables on host
	buildah run $${CONTAINER} /bin/bash -c 'ln -fs /usr/bin/distrobox-host-exec /usr/local/bin/flatpak'
	buildah run $${CONTAINER} /bin/bash -c 'ln -fs /usr/bin/distrobox-host-exec /usr/local/bin/podman'
	buildah run $${CONTAINER} /bin/bash -c 'ln -fs /usr/bin/distrobox-host-exec /usr/local/bin/rpm-ostree'
	# buildah run $${CONTAINER} /bin/bash -c 'ln -fs /bin/sh /usr/bin/sh'
	buildah run $${CONTAINER} /bin/bash -c 'sed -i -e "/^root/s/\/bin\/ash/\/bin\/bash/" /etc/passwd'
	buildah commit --rm $${CONTAINER} ghcr.io/grantmacken/$@
	buildah push ghcr.io/grantmacken/$@:latest
	podman images
	echo '##[ ------------------------------- ]##'


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
	# buildah run $${CONTAINER} cargo install --git https://github.com/RaphGL/Tuckr.git &>/dev/null
	buildah run $${CONTAINER} cargo install cargo-binstall &>/dev/null
	buildah run $${CONTAINER} /home/nonroot/.cargo/bin/cargo-binstall --no-confirm --no-symlinks stylua new-stow &>/dev/null
	buildah run $${CONTAINER} rm /home/nonroot/.cargo/bin/cargo-binstall
	buildah run $${CONTAINER} ls /home/nonroot/.cargo/bin/
	# buildah config --env CARGO_HOME=/usr/local $${CONTAINER}
	# buildah run $${CONTAINER} sh -c 'ls /usr/local'
	buildah commit --rm $${CONTAINER} $@

# https://github.com/wolfi-dev/os/blob/main/lazygit.yaml
# LSPs
# https://github.com/wolfi-dev/os/blob/main/rust-analyzer.yaml
#  description: A Rust compiler front-end for IDEs
#

bldr-neovim: 
	echo '##[ $@ ]##'
	CONTAINER=$$(buildah from cgr.dev/chainguard/wolfi-base)
	buildah run $${CONTAINER} sh -c 'apk update && apk upgrade' &>/dev/null
	buildah run $${CONTAINER} sh -c 'apk add build-base busybox cmake gettext-dev gperf libtermkey libtermkey-dev libuv-dev libvterm-dev lua-luv lua-luv-dev lua5.1-lpeg lua5.1-mpack luajit-dev msgpack samurai tree-sitter-dev unibilium-dev' &>/dev/null
	buildah run $${CONTAINER} sh -c 'apk add git tree grep'
	buildah run $${CONTAINER} sh -c 'git clone --depth 1 https://github.com/neovim/neovim.git' &>/dev/null
	buildah run $${CONTAINER} sh -c 'cd neovim && make \
 CMAKE_BUILD_TYPE=RelWithDebInfo \
 CMAKE_INSTALL_PREFIX=/usr \
 CMAKE_INSTALL_LIBDIR=lib \
 ENABLE_JEMALLOC=FALSE \
 ENABLE_LTO=TRUE && make install' &>/dev/null
	buildah run $${CONTAINER} sh -c 'ls -alR /usr/local'
	buildah run $${CONTAINER} sh -c 'printenv'
	# buildah run $${CONTAINER} sh -c 'which nvim && nvim --version'
	buildah commit --rm $${CONTAINER} $@
	echo '##[ ------------------------------- ]##'


zie-toolbox: bldr-rust
	CONTAINER=$$(buildah from ghcr.io/grantmacken/zie-wolfi-toolbox:latest)
	# add additional tools from chainguard
	# echo "grep: GNU grep implementation - so I can use -oP flag "
	# echo 'gh: GitHub official command line tool'
	# echo 'gcloud: Google Cloud Command Line Interface'
	# echo 'lazygit: simple terminal UI for git command'
	buildah run $${CONTAINER} /bin/bash -c 'apk add neovim grep gh lazygit' &>/dev/null
	# buildah add --from localhost/bldr-neovim $${CONTAINER} '/usr/local' '/usr/local' || true
	# Add stuff NOT avaiable thru apk
	# buildah add --from localhost/bldr-go $${CONTAINER} '/usr/local/bin' '/usr/local/bin'
	buildah add --from localhost/bldr-rust $${CONTAINER} '/home/nonroot/.cargo/bin' '/usr/local/bin'
	# buildah run $${CONTAINER} /bin/bash -c 'ln -fs /bin/sh /usr/bin/sh'
	# buildah run $${CONTAINER} /bin/bash -c 'ln -fs /usr/bin/distrobox-host-exec /usr/local/bin/make'
	# buildah run $${CONTAINER} /bin/bash -c 'which make && make --version' || true
	buildah run $${CONTAINER} /bin/bash -c 'which gh && gh --version' || true
	buildah run $${CONTAINER} /bin/bash -c 'which gcloud && gcloud --version' || true
	buildah run $${CONTAINER} /bin/bash -c 'which lazygit && lazygit --version' || true
	buildah run $${CONTAINER} /bin/bash -c 'which nvim && nvim --version' || true
	# built artifacts not from apk
	buildah run $${CONTAINER} /bin/bash -c 'which nstow && nstow --help' || true
	# buildah run $${CONTAINER} sh -c 'apk info -vv | sort'
	buildah commit --rm $${CONTAINER} ghcr.io/grantmacken/$@
	podman images
	buildah push ghcr.io/grantmacken/$@:latest

# https://raw.githubusercontent.com/ublue-os/toolboxes/main/quadlets/wolfi-toolbox/wolfi-distrobox-quadlet.container
$(HOME)/.config/containers/systemd/zie-wolfi-toolbox.container:
	mkdir -p $(dir $@)
	echo '##[ $(notdir $@) ]]##'
	cat << EOF | tee $@
	[Unit]
	Description=Wolfi Toolbox for your distrobox fun
	[Container]
	Annotation=run.oci.keep_original_groups=1
	AutoUpdate=registry
	ContainerName=wolfi-quadlet
	Environment=SHELL=%s
	Environment=HOME=%h
	Environment=XDG_RUNTIME_DIR=%t
	Environment=USER=%u
	Environment=USERNAME=%u
	Environment=container=podman
	Exec=--verbose --name %u  --user %U --group %G --home %h --init "0" --pre-init-hooks " " --additional-packages " " -- " "
	Image=ghcr.io/grantmacken/zie-wolfi-toolbox:latest
	HostName=zie-wolfi-quadlet.%l
	Network=host
	PodmanArgs=--entrypoint /usr/bin/entrypoint
	PodmanArgs=--ipc host
	PodmanArgs=--no-hosts
	PodmanArgs=--privileged
	PodmanArgs=--label manager=distrobox
	PodmanArgs=--security-opt label=disable
	PodmanArgs=--security-opt apparmor=unconfined
	Ulimit=host
	User=root:root
	UserNS=keep-id
	Volume=/:/run/host:rslave
	Volume=/tmp:/tmp:rslave
	Volume=%h:%h:rslave
	Volume=/dev:/dev:rslave
	Volume=/sys:/sys:rslave
	Volume=/dev/pts
	Volume=/dev/null:/dev/ptmx
	Volume=/sys/fs/selinux
	Volume=/var/log/journal
	Volume=/var/home/%u:/var/home/%u:rslave
	Volume=%t:%t:rslave
	Volume=/etc/hosts:/etc/hosts:ro
	Volume=/etc/resolv.conf:/etc/resolv.conf:ro	
	EOF
	sleep 1

sdk:
	podman pull ghcr.io/wolfi-dev/sdk:latest

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
	# systemctl --no-pager --user show zie-wolfi-toolbox.service
	# journalctl --no-pager --user -xeu zie-wolfi-toolbox.service
	# systemctl --no-pager --user list-unit-files | grep wolfi
	systemctl --no-pager --user status zie-wolfi-toolbox.service
	# systemctl --no-pager --user restart zie-wolfi-toolbox.service
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


