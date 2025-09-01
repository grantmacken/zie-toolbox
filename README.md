# Zie Toolbox

Toolbox is a tool that helps you create and manage development environments in containers.
Unfamiliar with Toolbox? Check out the 
[Toolbox documentation](https://docs.fedoraproject.org/en-US/fedora-silverblue/toolbox/).
This toolbox is generated on [github actions](https://github.com/grantmacken/zie-toolbox/actions/)
weekly. This is my current working toolbox that fit my current coding requirements. 
If it might not be your cup of tea, clone the repo and read and adjust the 
Makefile to suit your own whims.
## Built with buildah

The Toolbox is built from fedora-toolbox, version 42

Toolbox is pulled from registry:  registry.fedoraproject.org/fedora-toolbox

## In The Box

The idea here is to have a **long running** personal development toolbox containing the tools I require.
The main tool categories are:

 - Build tools

 - Runtimes: BEAM and Nodejs Runtimes and associated languages

 - Coding tools: Neovim and a selection of terminal CLI tools
## Selected Build Tooling for Make Installs

| Name           | Version  | Summary                                                                             |
| ----           | -------  | ----------------------------                                                        |
| autoconf       | 2.72     | A GNU tool for automatically configuring source code                                |
| gcc            | 15.2.1   | Various compilers (C, C++, Objective-C, ...)                                        |
| gcc-c++        | 15.0.1   | C++ support for GCC                                                                 |
| gcc-c++        | 15.2.1   | C++ support for GCC                                                                 |
| make           | 4.4.1    | A GNU tool which simplifies the build process for users                             |
| pcre2          | 10.45    | Perl-compatible regular expression library                                          |
| pkgconf        | 2.3.0    | Package compiler and linker metadata toolkit                                        |

## Runtimes and associated languages

Included in this toolbox are the latest releases of the Erlang, Elixir and Gleam programming languages.
The Erlang programming language is a general-purpose, concurrent, functional programming language
and **runtime** system. It is used to build massively scalable soft real-time systems with high availability.
The BEAM is the virtual machine at the core of the Erlang Open Telecom Platform (OTP).
The included Elixir and Gleam programming languages also run on the BEAM.
BEAM tooling included is the latest versions of the Rebar3 and the Mix build tools.
The latest nodejs **runtime** is also installed, as Gleam can compile to javascript as well a Erlang.
| Name           | Version  | Summary                                                                             |
| ----           | -------  | ----------------------------                                                        |
| Erlang/OTP     | 28.0.2   | the Erlang Open Telecom Platform OTP                                                |
| Rebar3         | 3.25.1   | the erlang build tool                                                               |
| Elixir         | 1.18.4   | Elixir programming language                                                         |
| Mix            | 1.18.4   | Elixir build tool                                                                   |
| Gleam          | 1.12.0   | Gleam programming language                                                          |
| node           | v24.7.0  | Nodejs runtime                                                                      |
| npm            | 11.5.1   | Node Package Manager                                                                |

## Do More With host-spawn

| Name           | Version  | Summary                                                                             |
| ----           | -------  | ----------------------------                                                        |
| host-spawn     | v1.6.2   | Run commands on your host machine from inside toolbox                               |

The host-spawn tool is a wrapper around the toolbox command that allows you to run
commands on your host machine from inside the toolbox.
To use the host-spawn tool, either run the following command: host-spawn <command>
Or just call host-spawn with no argument and this will pop you into you host shell.
When doing this remember to pop back into the toolbox with exit.
Checkout the [host-spawn repo](https://github.com/1player/host-spawn) for more information.


## Tools available for coding in the toolbox

| Name           | Version  | Summary                                                                             |
| ----           | -------  | ----------------------------                                                        |
| Neovim         | v0.11.4  | The text editor with a focus on extensibility and usability                         |
| luajit         | 2.1.174  | The LuaJIT compiler                                                                 |
| LuaRocks       | 3.12.2   |  the Lua package manager                                                            |

## More Coding Tools

Extra tooling that can be used within the Neovim text editor plugin echo system.
These are install via npm or luarocks.

| ----           | -------  | ----------------------------                                                        |
| Name           | Version  | Summary                                                                             |
| ----           | -------  | ----------------------------                                                        |
| tree-sitter    | 0.25.8   | The tree-sitter Command Line Interface                                              |

## Handpicked CLI tools available in the toolbox

| Name           | Version  | Summary                                                                             |
| ----           | -------  | ----------------------------                                                        |
| ImageMagick    | 7.1.1.47 | An X application for displaying and manipulating images                             |
| bat            | 0.25.0   | Cat(1) clone with wings                                                             |
| direnv         | 2.35.0   | Per-directory shell configuration tool                                              |
| fd-find        | 10.2.0   | Fd is a simple, fast and user-friendly alternative to find                          |
| fzf            | 0.65.1   | A command-line fuzzy finder written in Go                                           |
| gh             | 2.76.1   | GitHub's official command line tool                                                 |
| jq             | 1.7.1    | Command-line JSON processor                                                         |
| just           | 1.42.4   | Just a command runner                                                               |
| lynx           | 2.9.2    | A text-based Web browser                                                            |
| ripgrep        | 14.1.1   | Line-oriented search tool                                                           |
| stow           | 2.4.1    | Manage the installation of software packages from source                            |
| texlive-scheme-basic | svn54191 | basic scheme (plain and latex)                                                      |
| wl-clipboard   | 2.2.1    | Command-line copy/paste utilities for Wayland                                       |
| yq             | 4.43.1   | Yq is a portable command-line YAML, JSON, XML, CSV, TOML  and properties processor  |
| zoxide         | 0.9.8    | Smarter cd command for your terminal                                                |
