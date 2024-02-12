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
default: zie-toolbox  ## build the toolbox

bldr-rust: ## a ephemeral localhost container which builds rust executables
	echo '##[ $@ ]##'
	CONTAINER=$$(buildah from cgr.dev/chainguard/rust:latest)
	buildah run $${CONTAINER} rustc --version
	buildah run $${CONTAINER} cargo --version
	buildah run $${CONTAINER} cargo install cargo-binstall &>/dev/null
	buildah run $${CONTAINER} /home/nonroot/.cargo/bin/cargo-binstall --no-confirm --no-symlinks stylua new-stow &>/dev/null
	buildah run $${CONTAINER} rm /home/nonroot/.cargo/bin/cargo-binstall
	buildah run $${CONTAINER} ls /home/nonroot/.cargo/bin/
	buildah commit --rm $${CONTAINER} $@
	echo '##[ ------------------------------- ]##'

zie-toolbox: bldr-rust
	echo '##[ $@ ]##'
	CONTAINER=$$(buildah from docker-archive:apko-wolfi.tar)
	buildah config \
    --label com.github.containers.toolbox='true' \
    --label usage='This image is meant to be used with the distrobox command' \
    --label summary='a Wolfi based toolbox' \
    --label maintainer='Grant MacKenzie <grantmacken@gmail.com>' $${CONTAINER}
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
	#symlink to exectables on host
	buildah run $${CONTAINER} /bin/bash -c 'ln -fs /usr/bin/distrobox-host-exec /usr/local/bin/flatpak'
	buildah run $${CONTAINER} /bin/bash -c 'ln -fs /usr/bin/distrobox-host-exec /usr/local/bin/podman'
	buildah run $${CONTAINER} /bin/bash -c 'ln -fs /usr/bin/distrobox-host-exec /usr/local/bin/rpm-ostree'
	buildah run $${CONTAINER} /bin/bash -c 'sed -i -e "/^root/s/\/bin\/ash/\/bin\/bash/" /etc/passwd'
	buildah add --from localhost/bldr-rust $${CONTAINER} '/home/nonroot/.cargo/bin' '/usr/local/bin'
	# buildah run $${CONTAINER} /bin/bash -c 'ln -fs /bin/sh /usr/bin/sh'
	# binaries from apk
	buildah run $${CONTAINER} /bin/bash -c 'which neovim && neovim --version' || true
	buildah run $${CONTAINER} /bin/bash -c 'which make && make --version' || true
	buildah run $${CONTAINER} /bin/bash -c 'which gh && gh --version' || true
	buildah run $${CONTAINER} /bin/bash -c 'which gcloud && gcloud --version' || true
	buildah run $${CONTAINER} /bin/bash -c 'which lazygit && lazygit --version' || true
	# built artifacts not from apk
	buildah run $${CONTAINER} /bin/bash -c 'which nstow && nstow --help' || true
	buildah run $${CONTAINER} /bin/bash -c 'which stylua && stylua --help' || true
	buildah run $${CONTAINER} /bin/bash -c 'apk info -vv | sort'
	buildah commit --rm $${CONTAINER} ghcr.io/grantmacken/$@
	buildah push ghcr.io/grantmacken/$@:latest
	podman images
	echo '##[ ------------------------------- ]##'

