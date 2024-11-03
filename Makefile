SHELL=/bin/bash
.SHELLFLAGS := -eu -o pipefail -c
.ONESHELL:
.DELETE_ON_ERROR:
.SECONDARY:

MAKEFLAGS += --warn-undefined-variables
MAKEFLAGS += --no-builtin-rules
MAKEFLAGS += --silent

FEDORA_TOOLBOX    := registry.fedoraproject.org/fedora-toolbox:41
WORKING_CONTAINER := fedora-toolbox-working-container


CLI_INSTALL := bat eza fd-find flatpak-spawn fswatch fzf gh jq rclone ripgrep wl-clipboard yq zoxide
# DEV_INSTALL :=  kitty-terminfo make cmake ncurses-devel openssl-devel perl-core libevent-devel readline-devel gettext-devel intltool
DEPENDENCIES := $(CLI_INSTALL) $(DEV_INSTALL)
# include .env
CORE := neovim host-spawn
## rebar3 elixir gleam
BEAM := erlang

default: init cli neovim host-spawn
	buildah containers

reset:
	buildah rm $(WORKING_CONTAINER) || true
	rm -rfv info
	rm -rfv latest
	rm -rfv files
	rm -rfv tmp


commit:
	podman stop tbx || true
	toolbox rm tbx || true
	buildah commit $(WORKING_CONTAINER) tbx
	toolbox create --image localhost/tbx tbx

###############################################

init: info/buildah.info
info/buildah.info:
	echo '##[ $@ ]##'
	mkdir -p $(dir $@)
	podman images | grep -oP '$(FEDORA_TOOLBOX)' || buildah pull $(FEDORA_TOOLBOX) | tee  $@
	buildah containers | grep -oP $(WORKING_CONTAINER) || buildah from $(FEDORA_TOOLBOX) | tee -a $@
	echo

cli: info/cli.info
info/cli.info:
	echo '##[ $@ ]##'
	mkdir -p $(dir $@)
	for item in $(CLI_INSTALL)
	do
	buildah run $(WORKING_CONTAINER) rpm -ql $${item} &>/dev/null ||
	buildah run $(WORKING_CONTAINER) dnf install \
		--allowerasing \
		--skip-unavailable \
		--skip-broken \
		--no-allow-downgrade \
		-y \
		$${item}
	if [ "$${item}" == 'fd-find' ]
	then
	item=fd
	fi
	if [ "$${item}" == 'ripgrep' ]
	then
	item=rg
	fi
	buildah run $(WORKING_CONTAINER) whereis $${item}
	done
	buildah run $(WORKING_CONTAINER) sh -c "dnf -y info installed $(CLI_INSTALL) | \
grep -oP '(Name.+:\s\K.+)|(Ver.+:\s\K.+)|(Sum.+:\s\K.+)' | \
paste - - - " | tee $@
	buildah run $(WORKING_CONTAINER) dnf clean all

## NEOVIM
latest/neovim.json:
	echo '##[ $@ ]##'
	mkdir -p $(dir $@)
	wget -q -O - 'https://api.github.com/repos/neovim/neovim/releases/tags/nightly' > $@

neovim: info/neovim.info
info/neovim.info: latest/neovim.json
	echo '##[ $@ ]##'
	mkdir -p $(dir $@)
	buildah run $(WORKING_CONTAINER) sh -c "rm -rf /tmp/*"
	SRC=$$(jq  -r '.assets[].browser_download_url' $< | grep -oP '.+nvim-linux64.tar.gz$$')
	echo "source: $${SRC}"
	mkdir -p files/usr/local
	wget $${SRC} -q -O- | tar xz --strip-components=1 -C files/usr/local
	buildah add --chmod 755 $(WORKING_CONTAINER) files/usr/local /usr/local
	buildah run $(WORKING_CONTAINER) ls -al /usr/local
	buildah run $(WORKING_CONTAINER) sh -c 'nvim -V1 -v' | tee $@

## HOST-SPAWN

latest/host-spawn.json:
	echo '##[ $@ ]##'
	mkdir -p $(dir $@)
	wget -q -O - https://api.github.com/repos/1player/host-spawn/releases/latest > $@

host-spawn: info/host-spawn.info
info/host-spawn.info: latest/host-spawn.json
	echo '##[ $@ ]##'
	SRC=$$(jq  -r '.assets[].browser_download_url' $< | grep -oP '.+x86_64$$')
	TARG=/usr/local/bin/host-spawn
	echo "$$SRC"
	buildah add --chmod 755 $(WORKING_CONTAINER) $${SRC} $${TARG}
	buildah run $(WORKING_CONTAINER) sh -c 'ls -al /usr/local/bin/'
	buildah run $(WORKING_CONTAINER) sh -c 'echo -n " - check: " &&  which host-spawn'
	buildah run $(WORKING_CONTAINER) sh -c 'echo -n " - check: " &&  which host-spawn'
	buildah run $(WORKING_CONTAINER) sh -c 'echo -n " - host-spawn version: " &&  host-spawn --version' | tee $@
	buildah run $(WORKING_CONTAINER) sh -c 'host-spawn --help' | tee -a $@
	echo ' - add symlinks to exectables on host using host-spawn'
	buildah run $(WORKING_CONTAINER) /bin/bash -c 'ln -fs /usr/local/bin/host-spawn /usr/local/bin/make'
	buildah run $(WORKING_CONTAINER) /bin/bash -c 'ln -fs /usr/local/bin/host-spawn /usr/local/bin/flatpak'
	buildah run $(WORKING_CONTAINER) /bin/bash -c 'ln -fs /usr/local/bin/host-spawn /usr/local/bin/podman'
	buildah run $(WORKING_CONTAINER) /bin/bash -c 'ln -fs /usr/local/bin/host-spawn /usr/local/bin/buildah'
	buildah run $(WORKING_CONTAINER) /bin/bash -c 'ln -fs /usr/local/bin/host-spawn /usr/local/bin/systemctl'
	buildah run $(WORKING_CONTAINER) /bin/bash -c 'ln -fs /usr/local/bin/host-spawn /usr/local/bin/rpm-ostree'
