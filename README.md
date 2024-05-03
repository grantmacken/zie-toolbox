# WIP grantmacken/zie-toolbox

The aim is to provide a personal development toolbx for code wrangling

My original attempt was to use a variant of a wolfi container from ublue toolboxes.
On reboot the wolfi toolbox image failed to load, so I have gone back to a fedora-toolbox image
and using toolbox instead of distrobox to enter the toolbox.

The idea here is to have a long running toolbox containing the CLI tools I require for code wrangling.

I have tried to limit contained CLI tools to stuff for code editing and have **excluded**
 1. Runtimes and compiler build tooling with  [chainguard container images](https://images.chainguard.dev)
 2. Language Server Protocal servers:  I run these as separate containers
 3. Code linters and formatters not associated LSP servers as separate wolfi containers
 <!-- Also checkout test containers are separate container -->

## Neovim , lua and luarocks:

Ihe image contains the latest release version of Neovim.

For a Neovim plugin manager I have chosen [nvim-neorocks](https://github.com/nvim-neorocks/rocks.nvim) which announces itself as

    A modern approach to Neovim plugin management!

As Neorocks depends on a local installation of both lua and luarocks so these are included in the container.

## Some useful CLI tools

I have added some CLI tools which I find useful into the toolbox container.
Although not required by Neovim they can be used by Neovim e.g. ripgrep as a faster grep

 - gh
 - bat
 - eza
 - fzf
 - fd-find
 - jq
 - flatpak-spawn
 - ripgrep
 - wl-clipboard
 - zoxide

Note: this list will be extended

## Enter the toolbox

```
podman pull ghcr.io/grantmacken/zie-toolbox:latest
toolbox create --image ghcr.io/grantmacken/zie-toolbox:latest tbx
toolbox enter tbx
```


## Building the toolbox:

TODO!


<!--

Wolfi based toolbox for immutable operating systems

A distrobox toolbox container for code wrangling

# Container Tools

Updated weekly to the latest version

 - [x] neovim: open terminal and terminal session starts neovim in the toolbox container

 CLI tools
 
 - [x] git
 - [x] gh
 - [x] make

 -->

















