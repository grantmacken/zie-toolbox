# WIP grantmacken/zie-toolbox

## Requirements

1. Linux OS with [Podman and Toolbox](https://github.com/containers/toolbox)
2. Terminal: I use ptyxis the new gnome terminal installed with latest Fedora => 41 

I use Fedora silverblue so these come already installed out of the box.

## Getting Started

1. Pull the image as gitHub actions produces the the zie-toolbox so you don't have to run make locally.
2. Create the toolbox with a easy to remember name
3. Enter the toolbox

```
podman pull ghcr.io/grantmacken/zie-toolbox
toolbox create --image ghcr.io/grantmacken/zie-toolbox tbx
toolbox enter tbx
```


## In The Box Overview

The aim is to provide a personal development toolbx for code wrangling

My original attempt was to use a variant of a wolfi container from ublue toolboxes.
On reboot the wolfi toolbox image failed to load, so I have gone back to a fedora-toolbox image
and using toolbox instead of distrobox to enter the toolbox.

The idea here is to have a **long running** toolbox containing the CLI tools I require for code wrangling.

For the *main* toolbox I have tried to limit contained CLI tools to useful stuff for code editing and have **excluded**
 1. Runtimes and compiler build tooling with  [chainguard container images](https://images.chainguard.dev)
 2. Language Server Protocal servers:  I run these as separate containers
 3. Code linters and formatters not associated LSP servers as separate Wolfi containers
 <!-- Also checkout test containers are separate container -->

## Neovim , luajit and luarocks

Ihe image contains the latest release version of Neovim.


## Some useful CLI tools

I have added some CLI tools which I find useful into the toolbox container.
Although not required by Neovim they can be used by Neovim e.g. ripgrep as a faster grep

 - eza    A modern, maintained replacement for ls.
 - fd     A simple, fast and user-friendly alternative to 'find'
 - gh     GitHub's official command line tool
 - google-cloud-sdk  Google Cloud Command Line Interface
 - grep    GNU grep implementation implement -P flag Perl RegEx engine"
 - ripgrep Recursively searches directories for a regex pattern while respecting your gitignore
 - bat
 - fzf
 - jq
 - flatpak-spawn
 - host-spawn
 - wl-clipboard
 - zoxide

 - [luajit](https://github.com/openresty/luajit2) OpenResty's branch
 - [luarocks](shttps://luarocks.org/)


Note: this list will be extended

<!--


















