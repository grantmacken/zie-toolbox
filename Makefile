SHELL=/bin/bash
.ONESHELL:
.SHELLFLAGS := -eu -o pipefail -c
.DELETE_ON_ERROR:
MAKEFLAGS += --warn-undefined-variables
MAKEFLAGS += --no-builtin-rules
MAKEFLAGS += --silent
# include .env
# https://github.com/ublue-os/toolboxes/tree/main/toolboxes
default:  zie-toolbox  ## build the toolbox

# apko: apko-wolfi.tar
# 	echo '##[ $@ ]##'
# 	echo ' - created $<'
# 	echo '##[ ------------------------------- ]##'
# apko-wolfi.tar: ## install apk wolfi binaries
# 	podman run --rm --privileged -v $(CURDIR):/work -w /work cgr.dev/chainguard/apko build apko.yaml apko-wolfi:latest apko-wolfi.tar

# https://github.com/ublue-os/toolboxes/blob/main/toolboxes/bluefin-cli/packages.bluefin-cli
bldr-wolfi: ## apk bins for wolfi 
	echo '##[ $@ ]##'
	CONTAINER=$$(buildah from cgr.dev/chainguard/wolfi-base:latest)
	# add apk stuff that distrobox needs
	buildah run $${CONTAINER} sh -c 'apk add bash bc bzip2 coreutils curl diffutils findmnt findutils git gnupg gpg iproute2 iputils keyutils libcap libice libsm libx11 libxau libxcb libxdmcp libxext libxmu libxt mount ncurses ncurses-terminfo net-tools openssh-client pigz posix-libc-utils procps rsync shadow su-exec tcpdump tree tzdata umount unzip util-linux util-linux-misc vulkan-loader wget xauth xz zip'
	# add apk stuff that I want mainly command line tools
	buildah run $${CONTAINER} sh -c 'apk add atuin build-base cmake eza \
		fd fzf gh google-cloud-sdk grep lazygit luajit ripgrep \
		sed zoxide'
	buildah run $${CONTAINER} sh -c 'apk info'
	buildah commit --rm $${CONTAINER} $@ &>/dev/null
	echo '##[ ------------------------------- ]##'


#build-base  # needed for nvim package builds - contains  binutils gcc glibc-dev make pkgconf wolfi-baselayout 
#eza     # A modern, maintained replacement for ls.
#fd      # A simple, fast and user-friendly alternative to 'find'
#gh      #  GitHub's official command line tool
#google-cloud-sdk # Google Cloud Command Line Interface
#grep    # GNU grep implementation implement -P flag Perl RegEx engine"
#lazygit # simple terminal UI for git commands
#luajit  # OpenResty's branch of LuaJIT @see https://github.com/wolfi-dev/os/blob/main/luajit.yaml
#luajit-dev # headers for luarocks install
#ripgrep # ripgrep recursively searches directories for a regex pattern while respecting your gitignore"
#sed     # GNU stream editor TODO? replace with sd"
#sudo-rs # TODO! CONFLICT with shadow memory safe implementation of sudo and su
#tree-sitter # for nvim treesitter  - Incremental parsing system for programming tools
#zoxide  # A smarter cd command. Supports all major shells

bldr-addons: bldr-neovim bldr-rust

bldr: ## a build tools builder for neovim
	echo '##[ $@ ]##'
	CONTAINER=$$(buildah from cgr.dev/chainguard/wolfi-base:latest)
	buildah run $${CONTAINER} sh -c 'apk add build-base cmake gettext-dev gperf libtermkey libtermkey-dev libuv-dev libvterm-dev lua-luv lua-luv-dev lua5.1-lpeg lua5.1-mpack luajit-dev msgpack samurai tree-sitter-dev unibilium-dev wget tree' &>/dev/null
	buildah run $${CONTAINER} sh -c 'apk add readline-dev luajit unzip'
	buildah commit --rm $${CONTAINER} $@ &>/dev/null
	echo '##[ ------------------------------- ]##'

# bldr-luarocks: bldr ## a ephemeral localhost container which builds luarocks
# 	echo '##[ $@ ]##'
# 	CONTAINER=$$(buildah from localhost/bldr)
# 	buildah config --workingdir /home $${CONTAINER}
# 	buildah run $${CONTAINER} sh -c 'lua -v'
# 	echo '##[ ----------include----------------- ]##'
# 	buildah run $${CONTAINER} sh -c 'ls -al /usr/include' | grep lua
# 	echo '##[ -----------lib ------------------- ]##'
# 	buildah run $${CONTAINER} sh -c 'ls /usr/lib' | grep lua
# 	echo '##[ ------------------------------- ]##'
# 	buildah run $${CONTAINER} sh -c 'wget -qO- \
# 	https://github.com/luarocks/luarocks/archive/refs/tags/v3.9.2.tar.gz | tar xvz'  &>/dev/null
# 	buildah config --workingdir /home/luarocks-3.9.2 $${CONTAINER}  
# 	buildah run $${CONTAINER} sh -c './configure --with-lua=/usr/bin --with-lua-bin=/usr/bin --with-lua-lib=/usr/lib --with-lua-include=/usr/include/lua'
# 	buildah run $${CONTAINER} sh -c 'make & make install'
# 	buildah run $${CONTAINER} sh -c 'luarocks'
# 	buildah commit --rm $${CONTAINER} $@ &>/dev/null
# 	echo '##[ ------------------------------- ]##'

bldr-neovim: bldr # a ephemeral localhost container which builds neovim
	echo '##[ $@ ]##'
	CONTAINER=$$(buildah from localhost/bldr)
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
	# only install stuff not in  wolfi apk registry
	buildah run $${CONTAINER} /home/nonroot/.cargo/bin/cargo-binstall --no-confirm --no-symlinks \
		stylua \
		silicon &>/dev/null
	cargo install --git https://github.com/RaphGL/Tuckr.git
	buildah run $${CONTAINER} rm /home/nonroot/.cargo/bin/cargo-binstall
	buildah run $${CONTAINER} ls /home/nonroot/.cargo/bin/
	buildah commit --rm $${CONTAINER} $@
	echo '##[ ------------------------------- ]##'

zie-wolfi-toolbox:
	echo '##[ $@ ]##'
	CONTAINER=$$(buildah from localhost/bldr-wolfi)
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
	echo "host-spawn version: $${HOST_SPAWN_VERSION}"
	SRC=https://github.com/1player/host-spawn/releases/download/$${HOST_SPAWN_VERSION}/host-spawn-x86_64
	TARG=/usr/bin/host-spawn
	buildah add --chmod 755 $${CONTAINER} $${SRC} $${TARG}
	buildah run $${CONTAINER} /bin/bash -c 'which host-spawn' || true
	buildah run $${CONTAINER} /bin/bash -c 'which entrypoint' || true
	buildah run $${CONTAINER} /bin/bash -c 'which distrobox-export'|| true
	buildah run $${CONTAINER} /bin/bash -c 'which distrobox-host-exec'|| true
	#symlink to exectables on host
	buildah run $${CONTAINER} /bin/bash -c 'ln -fs /usr/bin/distrobox-host-exec /usr/local/bin/flatpak'
	buildah run $${CONTAINER} /bin/bash -c 'ln -fs /usr/bin/distrobox-host-exec /usr/local/bin/podman'
	buildah run $${CONTAINER} /bin/bash -c 'ln -fs /usr/bin/distrobox-host-exec /usr/local/bin/buildah'
	buildah run $${CONTAINER} /bin/bash -c 'ln -fs /usr/bin/distrobox-host-exec /usr/local/bin/systemctl'
	buildah run $${CONTAINER} /bin/bash -c 'ln -fs /usr/bin/distrobox-host-exec /usr/local/bin/rpm-ostree'
	echo ' - check apk installed binaries'
	buildah run $${CONTAINER} /bin/bash -c 'which make && make --version' || true
	echo '-------------------------------'
	buildah run $${CONTAINER} /bin/bash -c 'which gh && gh --version' || true
	echo ' -------------------------------'
	buildah run $${CONTAINER} /bin/bash -c 'which gcloud && gcloud --version' || true
	echo ' -------------------------------'
	buildah run $${CONTAINER} /bin/bash -c 'which lazygit && lazygit --version' || true
	echo ' -------------------------------'
	buildah run $${CONTAINER} /bin/bash -c "sed -i 's%/bin/ash%/bin/bash%' /etc/passwd"
	# buildah run $${CONTAINER} /bin/bash -c 'cat /etc/passwd'
