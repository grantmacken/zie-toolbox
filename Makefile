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
## buildr_addons are for the cli tools not available in from the wolfi apk repo
## NOTE: neovim is built from source although it is available from the wolfi apk repo
bldr-addons: bldr-neovim

# bldr-rust

# apko: apko-wolfi.tar
# 	echo '##[ $@ ]##'
# 	echo ' - created $<'
# 	echo '##[ ------------------------------- ]##'
# apko-wolfi.tar: ## install apk wolfi binaries
# 	podman run --rm --privileged -v $(CURDIR):/work -w /work cgr.dev/chainguard/apko build apko.yaml apko-wolfi:latest apko-wolfi.tar
# buildah run $${CONTAINER} sh -c 'apk add \
# build-base \
# cmake \
# libxcrypt'
# add apk stuff that I want mainly command line tools
# add runtimes
# NOTE: treesitter-cli requires nodejs runtime
# buildah run $${CONTAINER} sh -c 'apk add \
# luajit \
# nodejs-21'

# https://github.com/ublue-os/toolboxes/blob/main/toolboxes/bluefin-cli/packages.bluefin-cli
wolfi: ## apk bins from wolfi-dev 
	echo '##[ $@ ]##'
	CONTAINER=$$(buildah from cgr.dev/chainguard/wolfi-base:latest)
	# add apk stuff that distrobox needs
	# https://github.com/ublue-os/toolboxes/blob/main/toolboxes/wolfi-toolbox/packages.wolfi
	buildah run $${CONTAINER} sh -c 'apk add \
	bash \
	bzip2 \
	coreutils \
	curl \
	diffutils \
	findmnt \
	findutils \
	git \
	gnupg \
	gpg \
	iproute2 \
	iputils \
	keyutils \
	libcap \
	libsm \
	libx11 \
	libxau \
	libxcb \
	libxdmcp \
	libxext \
	libice \
	libxmu \
	libxt \
	linux-pam \
	mount \
	ncurses \
	ncurses-terminfo \
	net-tools \
	openssh-client \
	pigz \
	posix-libc-utils \
	procps \
	rsync \
	shadow \
	su-exec \
	tcpdump \
	tree \
	tzdata \
	umount \
	unzip \
	util-linux \
	util-linux-misc \
	wget \
	xauth \
	xz \
	zip \
	vulkan-loader' &>/dev/null
	buildah run $${CONTAINER} sh -c 'apk add \
	atuin \
	eza \
	fd \
	fzf \
	gh \
	google-cloud-sdk \
	grep \
	jq \
	make \
	ripgrep \
	sed \
	uutils \
	starship \
	zoxide' &>/dev/null
	buildah run $${CONTAINER} sh -c 'apk info'
	buildah commit --rm $${CONTAINER} $@ &>/dev/null
	echo '##[ ------------------------------- ]##'

# build-base  # needed for nvim package builds - contains  binutils gcc glibc-dev make pkgconf wolfi-baselayout 
# eza     # A modern, maintained replacement for ls.
# fd      # A simple, fast and user-friendly alternative to 'find'
# gh      #  GitHub's official command line tool
# google-cloud-sdk # Google Cloud Command Line Interface
# grep    # GNU grep implementation implement -P flag Perl RegEx engine"
# lazygit # simple terminal UI for git commands
# luajit  # OpenResty's branch of LuaJIT @see https://github.com/wolfi-dev/os/blob/main/luajit.yaml
# luajit-dev # headers for luarocks install
# ripgrep # ripgrep recursively searches directories for a regex pattern while respecting your gitignore"
# sed     # GNU stream editor TODO? replace with sd"
# sudo-rs # TODO! CONFLICT with shadow memory safe implementation of sudo and su
# tree-sitter # for nvim treesitter  - Incremental parsing system for programming tools
# zoxide  # A smarter cd command. Supports all major shells

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

bldr-neovim: # a ephemeral localhost container which builds neovim
	echo '##[ $@ ]##'
	CONTAINER=$$(buildah from cgr.dev/chainguard/wolfi-base:latest)
	buildah run $${CONTAINER} sh -c 'apk add \
	build-base \
	cmake \
	gettext-dev \
	gperf \
	libtermkey \
	libtermkey-dev \
	libuv-dev  \
	libvterm-dev \
	libxcrypt \
	lua-luv \
	lua-luv-dev \
	lua5.1-lpeg \
	lua5.1-mpack \
	luajit \
	luajit-dev \
	msgpack \
	readline-dev \
	samurai \
	tree \
	tree-sitter-dev \
	unibilium-dev \
	unzip \
	wget' &>/dev/null
	buildah run $${CONTAINER} sh -c 'wget -qO- https://github.com/neovim/neovim/archive/refs/tags/nightly.tar.gz | tar xvz'  &>/dev/null
	buildah run $${CONTAINER} sh -c 'cd neovim-nightly && CMAKE_BUILD_TYPE=Release; make && make install' &>/dev/null
	buildah run $${CONTAINER} sh -c 'which nvim && nvim --version'
	buildah commit --rm $${CONTAINER} $@ &>/dev/null
	echo '-------------------------------'

bldr-rust: ## a ephemeral localhost container which builds rust executables
	echo '##[ $@ ]##'
	CONTAINER=$$(buildah from cgr.dev/chainguard/rust:latest)
	buildah run $${CONTAINER} rustc --version
	buildah run $${CONTAINER} cargo --version
	buildah run $${CONTAINER} cargo install cargo-binstall &>/dev/null
	# only install stuff not in  wolfi apk registry
	buildah run $${CONTAINER} /home/nonroot/.cargo/bin/cargo-binstall --no-confirm --no-symlinks stylua silicon tree-sitter-cli &>/dev/null
	buildah run $${CONTAINER} rm /home/nonroot/.cargo/bin/cargo-binstall
	buildah run $${CONTAINER} ls /home/nonroot/.cargo/bin/
	buildah commit --rm $${CONTAINER} $@
	echo '##[ ------------------------------- ]##'

zie-toolbox: wolfi bldr-addons
	echo '##[ $@ ]##'
	CONTAINER=$$(buildah from localhost/wolfi)
	echo ' - configuration labels'
	buildah config \
	--label com.github.containers.toolbox='true' \
	--label usage='This image is meant to be used with the distrobox command' \
	--label summary='a Wolfi based toolbox' \
	--label maintainer='Grant MacKenzie <grantmacken@gmail.com>' $${CONTAINER}
	echo ' - configuration enviroment'
	buildah config --env LANG=C.UTF-8 $${CONTAINER}
	echo ' - into container: distrobox-host-exec '
	SRC=https://raw.githubusercontent.com/89luca89/distrobox/main/distrobox-host-exec
	TARG=/usr/bin/distrobox-host-exec
	buildah add --chmod 755 $${CONTAINER} $${SRC} $${TARG}
	echo ' - into container: distrobox-export'
	SRC=https://raw.githubusercontent.com/89luca89/distrobox/main/distrobox-export
	TARG=/usr/bin/distrobox-export
	buildah add --chmod 755 $${CONTAINER} $${SRC} $${TARG}
	echo ' - into container: distrobox-init'
	SRC=https://raw.githubusercontent.com/89luca89/distrobox/main/distrobox-init
	TARG=/usr/bin/entrypoint
	buildah add --chmod 755 $${CONTAINER} $${SRC} $${TARG}
	echo -n ' - set var: HOST_SPAWN_VERSION '
	HOST_SPAWN_VERSION=$$(buildah run $${CONTAINER} /bin/bash -c 'grep -oP "host_spawn_version=.\K(\d+\.){2}\d+" /usr/bin/distrobox-host-exec')
	echo "$${HOST_SPAWN_VERSION}"
	echo ' - into container: host-spawn'
	SRC=https://github.com/1player/host-spawn/releases/download/$${HOST_SPAWN_VERSION}/host-spawn-x86_64
	TARG=/usr/bin/host-spawn
	buildah add --chmod 755 $${CONTAINER} $${SRC} $${TARG}
	buildah run $${CONTAINER} /bin/bash -c 'which host-spawn'
	buildah run $${CONTAINER} /bin/bash -c 'which entrypoint'
	buildah run $${CONTAINER} /bin/bash -c 'which distrobox-export'
	buildah run $${CONTAINER} /bin/bash -c 'which distrobox-host-exec'
	# https://github.com/rcaloras/bash-preexec
	echo ' - add bash-preexec'
	SRC=https://raw.githubusercontent.com/rcaloras/bash-preexec/master/bash-preexec.sh
	TARG=/usr/share/bash-preexec
	buildah run $${CONTAINER} /bin/bash -c 'ls -al /usr/share'
	buildah add --chmod 755 $${CONTAINER} $${SRC} $${TARG}
	echo ' - add /etc/bashrc: the systemwide bash per-interactive-shell startup filestarship config file'
	SRC=https://raw.githubusercontent.com/ublue-os/toolboxes/main/toolboxes/bluefin-cli/files/etc/bashrc
	TARG=/etc/bashrc
	buildah add --chmod 755 $${CONTAINER} $${SRC} $${TARG}
	echo ' - add starship config file'
	SRC=https://raw.githubusercontent.com/ublue-os/toolboxes/main/toolboxes/bluefin-cli/files/etc/starship.toml
	TARG=/etc/starship.toml
	buildah add --chmod 755 $${CONTAINER} $${SRC} $${TARG}
	buildah run $${CONTAINER} /bin/bash -c 'ls -al /etc'
	echo ' - symlink to exectables on host'
	buildah run $${CONTAINER} /bin/bash -c 'ln -fs /usr/bin/distrobox-host-exec /usr/local/bin/flatpak'
	buildah run $${CONTAINER} /bin/bash -c 'ln -fs /usr/bin/distrobox-host-exec /usr/local/bin/podman'
	buildah run $${CONTAINER} /bin/bash -c 'ln -fs /usr/bin/distrobox-host-exec /usr/local/bin/buildah'
	buildah run $${CONTAINER} /bin/bash -c 'ln -fs /usr/bin/distrobox-host-exec /usr/local/bin/systemctl'
	buildah run $${CONTAINER} /bin/bash -c 'ln -fs /usr/bin/distrobox-host-exec /usr/local/bin/rpm-ostree'
	# echo ' - from: bldr rust'
	# buildah add --from localhost/bldr-rust $${CONTAINER} '/home/nonroot/.cargo/bin' '/usr/local/bin'
	# buildah add --chmod 755 --from localhost/bldr-neovim $${CONTAINER} '/usr/local/bin/nvim' '/usr/local/bin/nvim'
	echo ' - from: bldr neovim'
	buildah add --from localhost/bldr-neovim $${CONTAINER} '/usr/local/lib/nvim' '/usr/local/lib/nvim'
	buildah add --from localhost/bldr-neovim $${CONTAINER} '/usr/local/share' '/usr/local/share'
	#buildah add --chmod 755 --from localhost/bldr-luarocks $${CONTAINER} '/usr/local/bin/luarocks' '/usr/local/bin/luarocks'
	#buildah add --from localhost/bldr-luarocks $${CONTAINER} '/usr/local/share/lua' '/usr/local/share/lua'
	echo ' - check some apk installed binaries'
	buildah run $${CONTAINER} /bin/bash -c 'which make && make --version'
	echo '-------------------------------'
	buildah run $${CONTAINER} /bin/bash -c 'which gh && gh --version'
	echo ' -------------------------------'
	buildah run $${CONTAINER} /bin/bash -c 'which gcloud && gcloud --version'
	echo ' -------------------------------'
	echo ' CHECK BUILT BINARY ARTIFACTS NOT FROM APK'
	echo ' --- from bldr-neovim '
	buildah run $${CONTAINER} /bin/bash -c 'which nvim && nvim --version'
	echo ' ==============================='
	echo ' Setup '
	echo ' --- bash instead of ash '
	buildah run $${CONTAINER} /bin/bash -c "sed -i 's%/bin/ash%/bin/bash%' /etc/passwd"
	# buildah run $${CONTAINER} /bin/bash -c 'cat /etc/passwd'
	buildah run $${CONTAINER} /bin/bash -c 'ln /bin/sh /usr/bin/sh'
	echo ' --- permissions fo su-exec'
	buildah run $${CONTAINER} /bin/bash -c 'chmod u+s /sbin/su-exec'
	echo ' -------------------------------'
	# buildah run $${CONTAINER} /bin/bash -c 'ls -al /sbin/su-exec'
	echo ' --- su-exec as sudo'
	SRC=files/sudo
	TARG=/usr/bin/sudo
	buildah add --chmod 755 $${CONTAINER} $${SRC} $${TARG}
	buildah commit --rm $${CONTAINER} ghcr.io/grantmacken/$@
	# buildah push ghcr.io/grantmacken/$@:latest
	podman images
	echo '##[ ------------------------------- ]##'
#
# pull:
# 	podman pull ghcr.io/grantmacken/zie-toolbox:latest
# 	podman images | grep zie
#
# distrobox: pull
# 	vim.fn.stdpath('data')
# 	distrobox create --image ghcr.io/grantmacken/zie-toolbox:latest --name zie-wolfi
#
# quadlet-status: 
# 	echo -n ' - is enabled: ' && systemctl --no-pager --user is-enabled zie-toolbox.service || true
# 	echo -n ' - is active: '&& systemctl --no-pager --user is-active zie-toolbox.service || true
#
# quadlet-reset: 
# 	if systemctl --no-pager --user is-active zie-toolbox.service
# 	then 
# 	systemctl --no-pager --user stop zie-toolbox.service
# 	fi
# 	if systemctl --no-pager --user is-enabled zie-toolbox.service
# 	then 
# 	systemctl --no-pager --user disable zie-toolbox.service
# 	fi
# 	rm $(HOME)/.config/containers/systemd/zie-toolbox.container
# 	$(MAKE) quadlet


# kitty-session: $(HOME)/.config/kitty/session.conf
# 	cat << EOF | tee $@
# 	cd $HOME/zie
# 	launch /bin/bash -c 'distrobox enter zie-quadlet'
# 	EOF

# quadlet: $(HOME)/.config/containers/systemd/zie-toolbox.container
# 	echo 'OK! quadlet added'
# 	systemctl --user daemon-reload
# 	systemctl --no-pager --user is-enabled zie-toolbox.service || systemctl --no-pager --user enable zie-toolbox.service
# 	systemctl --no-pager --user is-active zie-toolbox.service  || systemctl --no-pager --user start zie-toolbox.service
# 	systemctl --no-pager --user list-unit-files  --state=generated || grep zie
# 	systemctl --no-pager --user show zie-toolbox.service | grep -oP '^UnitFile.+$$' 
# 	systemctl --no-pager --user show zie-toolbox.service | grep -oP '^Load.+$$' 
# 	systemctl --no-pager --user show zie-toolbox.service | grep -oP '^Active.+$$' 
# 	systemctl --no-pager --user status zie-toolbox.service | grep -oP 'Active.+'
# 	echo -n ' - is enabled: ' && systemctl --no-pager --user is-enabled zie-toolbox.service || true
# 	echo -n ' - is active: '&& systemctl --no-pager --user is-active zie-toolbox.service || true
# 	# journalctl --no-pager --user -xeu zie-toolbox.service
# 	distrobox ls



