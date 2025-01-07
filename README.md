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

