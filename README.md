# My toolbox for making stuff with Neovim and various CLI tools.

This is my toolbox, you might like to give it a wirl.

Read and adjust the Makefile to suit your whims.

## In The Box Overview

The aim is to provide a personal development toolbx for code wrangling

My original attempt was to use a variant of a wolfi container from ublue toolboxes.
On reboot the wolfi toolbox image failed to load, so I have gone back to a fedora-toolbox image
and using toolbox instead of distrobox to enter the toolbox.

The idea here is to have a **long running** toolbox containing the CLI tools I require for code wrangling.

For the *main* toolbox I have tried to limit contained CLI tools to useful stuff for code editing and have **excluded**
 1. Run-times and compiler build tooling with  [chainguard container images](https://images.chainguard.dev)
 2. Language Server Protocol servers:  I run these as separate containers
 3. CLI code linting and formatting not associated LSP servers will be in separate Wolfi containers

## Getting Started

1. Pull the image as gitHub actions produces the the zie-toolbox so you don't have to run make locally.
2. Create the toolbox with a easy to remember name
3. Enter the toolbox

```
podman pull ghcr.io/grantmacken/zie-toolbox
toolbox create --image ghcr.io/grantmacken/zie-toolbox tbx
toolbox enter tbx
```

| Name          | Version | Summary                                                                             |
| ----          | ------- | ----------------------------                                                        |
| bat           | 0.24.0  | Cat(1) clone with wings                                                             |
| direnv        | 2.32.3  | Per-directory shell configuration tool                                              |
| eza           | 0.19.3  | Modern replacement for ls                                                           |
| fd-find       | 10.1.0  | Fd is a simple, fast and user-friendly alternative to find                          |
| fzf           | 0.57.0  | A command-line fuzzy finder written in Go                                           |
| gh            | 2.63.2  | GitHub's official command line tool                                                 |
| jq            | 1.7.1   | Command-line JSON processor                                                         |
| make          | 4.4.1   | A GNU tool which simplifies the build process for users                             |
| ripgrep       | 14.1.1  | Line-oriented search tool                                                           |
| stow          | 2.4.1   | Manage the installation of software packages from source                            |
| wl-clipboard  | 2.2.1   | Command-line copy/paste utilities for Wayland                                       |
| yq            | 4.43.1  | Yq is a portable command-line YAML, JSON, XML, CSV, TOML  and properties processor  |
| zoxide        | 0.9.4   | Smarter cd command for your terminal                                                |
| ----          | ------- | ----------------------------                                                        |
## Neovim , luajit, luarocks, nlua

| Name       | Version       | Summary                                                                             |
| Neovim     | v0.11.0       | The text editor with a focus on extensibility and usability                         |
| luajit     | 2.1.ROLLING   | built from ROLLING release                                                          |
| luarocks   | 3.11.1        | built from source from latest luarocks tag                                          |
| nlua       | HEAD          | lua script added from github 'mfussenegger/nlua'                                    |
| host-spawn | 1.6.0         | run commands on your host machine from inside the toolbox                           |
| ----       | -------       | ----------------------------                                                        |

### Host Spawn Commands

The following host executables can be used from this toolbox
 - firefox
 - flatpak
 - podman
 - buildah
 - systemctl
 - rpm-ostree
 - dconf
