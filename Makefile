SHELL=/bin/bash
.ONESHELL:
.SHELLFLAGS := -eu -o pipefail -c
.DELETE_ON_ERROR:
MAKEFLAGS += --warn-undefined-variables
MAKEFLAGS += --no-builtin-rules
MAKEFLAGS += --silent
# include .env
# https://github.com/ublue-os/toolboxes/tree/main/toolboxes
default: zie-toolbox  ## build the toolbox

bldr:
	echo '##[ $@ ]##'
	CONTAINER=$$(buildah from cgr.dev/chainguard/wolfi-base:latest)
	buildah run $${CONTAINER} sh -c 'apk add build-base cmake gettext-dev gperf libtermkey libtermkey-dev libuv-dev libvterm-dev lua-luv lua-luv-dev lua5.1-lpeg lua5.1-mpack luajit-dev msgpack samurai tree-sitter-dev unibilium-dev wget tree' &>/dev/null
	buildah run $${CONTAINER} sh -c 'apk add readline-dev luajit unzip'
	buildah run $${CONTAINER} sh -c 'which lua'
	buildah commit --rm $${CONTAINER} $@ &>/dev/null
	echo '##[ ------------------------------- ]##'


bldr-luarocks: ## a ephemeral localhost container which builds luarocks
	echo '##[ $@ ]##'
	CONTAINER=$$(buildah from localhost/bldr)
	buildah config --workingdir /home $${CONTAINER}
	# LUA_BINDIR=<Directory of lua binary> and LUA_BINDIR_SET=yes.
	buildah run $${CONTAINER} sh -c 'lua -v'
	echo '##[ ----------include----------------- ]##'
	buildah run $${CONTAINER} sh -c 'ls -al /usr/include' | grep lua
	echo '##[ -----------lib ------------------- ]##'
	buildah run $${CONTAINER} sh -c 'ls /usr/lib' | grep lua
	echo '##[ ------------------------------- ]##'
	buildah run $${CONTAINER} sh -c 'wget -qO- \
	https://github.com/luarocks/luarocks/archive/refs/tags/v3.9.2.tar.gz | tar xvz'  &>/dev/null
	buildah config --workingdir /home/luarocks-3.9.2 $${CONTAINER}  
	buildah run $${CONTAINER} sh -c './configure --with-lua=/usr/bin --with-lua-bin=/usr/bin --with-lua-lib=/usr/lib --with-lua-include=/usr/include/lua'
	buildah run $${CONTAINER} sh -c 'make & make install'
	buildah run $${CONTAINER} sh -c 'luarocks'
	buildah commit --rm $${CONTAINER} $@ &>/dev/null
	echo '##[ ------------------------------- ]##'


bldr-neovim: ## a ephemeral localhost container which builds neovim
	echo '##[ $@ ]##'
	CONTAINER=$$(buildah from cgr.dev/chainguard/wolfi-base:latest)
	buildah run $${CONTAINER} sh -c 'apk add build-base cmake gettext-dev gperf libtermkey libtermkey-dev libuv-dev libvterm-dev lua-luv lua-luv-dev lua5.1-lpeg lua5.1-mpack luajit-dev msgpack samurai tree-sitter-dev unibilium-dev wget tree' &>/dev/null
	buildah run $${CONTAINER} sh -c 'wget -qO- https://github.com/neovim/neovim/archive/refs/tags/nightly.tar.gz | tar xvz'  &>/dev/null
	buildah run $${CONTAINER} sh -c 'cd neovim-nightly && CMAKE_BUILD_TYPE=RelWithDebInfo; make && make install' &>/dev/null
	buildah run $${CONTAINER} sh -c 'which nvim && nvim --version'
	buildah commit --rm $${CONTAINER} $@
	echo '##[ ------------------------------- ]##'


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

zie-toolbox: bldr-rust bldr-neovim
	echo '##[ $@ ]##'
	CONTAINER=$$(buildah from docker-archive:apko-wolfi.tar)
	buildah config \
    --label com.github.containers.toolbox='true' \
    --label usage='This image is meant to be used with the distrobox command' \
    --label summary='a Wolfi based toolbox' \
    --label maintainer='Grant MacKenzie <grantmacken@gmail.com>' $${CONTAINER}
	buildah run $${CONTAINER} sh -c 'apk add luajit-dev' &>/dev/null
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
	echo "host-spawn version: $${HOST_SPAWN_VERSION}"
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
	buildah add --from localhost/bldr-rust $${CONTAINER} '/home/nonroot/.cargo/bin' '/usr/local/bin'
	buildah add --chmod 755 --from localhost/bldr-neovim $${CONTAINER} '/usr/local/bin/nvim' '/usr/local/bin/nvim'
	buildah add --from localhost/bldr-neovim $${CONTAINER} '/usr/local/lib/nvim' '/usr/local/lib/nvim'
	buildah add --from localhost/bldr-neovim $${CONTAINER} '/usr/local/share' '/usr/local/share'
	# buildah run $${CONTAINER} /bin/bash -c 'cat /etc/passwd'
	# buildah run $${CONTAINER} /bin/bash -c 'ln -fs /bin/sh /usr/bin/sh'
	echo ' - check apk installed binaries'
	buildah run $${CONTAINER} /bin/bash -c 'which make && make --version' || true
	buildah run $${CONTAINER} /bin/bash -c 'which gh && gh --version' || true
	buildah run $${CONTAINER} /bin/bash -c 'which gcloud && gcloud --version' || true
	buildah run $${CONTAINER} /bin/bash -c 'which lazygit && lazygit --version' || true
	echo ' check built binary artifacts not from apk' 
	buildah run $${CONTAINER} /bin/bash -c 'which nvim && nvim --version' || true
	buildah run $${CONTAINER} /bin/bash -c 'which nstow && nstow --version' || true
	buildah run $${CONTAINER} /bin/bash -c 'which stylua && stylua --version' || true
	# buildah run $${CONTAINER} /bin/bash -c 'cat /etc/passwd'
	# buildah run $${CONTAINER} /bin/bash -c "sed -i 's%/bin/ash%/bin/bash%' /etc/passwd"
	# buildah run $${CONTAINER} /bin/bash -c 'cat /etc/passwd'
	echo '##[ ----------lua checks----------------- ]##'
	buildah run $${CONTAINER} sh -c 'lua -v'
	echo '##[ ----------include----------------- ]##'
	buildah run $${CONTAINER} sh -c 'ls -al /usr/include' | grep lua || true
	echo '##[ -----------lib ------------------- ]##'
	buildah run $${CONTAINER} sh -c 'ls /usr/lib' | grep lua || true
	buildah run $${CONTAINER} sh -c 'wget -qO- https://github.com/luarocks/luarocks/archive/refs/tags/v3.9.2.tar.gz | tar xvz'  &>/dev/null
	buildah run $${CONTAINER} sh -c 'cd luarocks-3.9.2 \
&& ./configure --with-lua=/usr/bin --with-lua-bin=/usr/bin --with-lua-lib=/usr/lib --with-lua-include=/usr/include/lua \
&& make & make install'
	buildah run $${CONTAINER} sh -c 'luarocks'
	buildah commit --rm $${CONTAINER} ghcr.io/grantmacken/$@
	buildah push ghcr.io/grantmacken/$@:latest
	podman images
	echo '##[ ------------------------------- ]##'

luarocks:
	LUA_BINDIR="${XDG_BIN_DIR:-$HOME/.local/bin}" LUA_BINDIR_SET=yes nvim -u NORC -c "source ...

	

