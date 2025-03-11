# zie toolbox

[toolbox why use?](https://docs.fedoraproject.org/en-US/fedora-silverblue/toolbox/#toolbox-why-use)

The idea here is to have a **long running** [toolbox](https://github.com/containers/toolbox) containing the CLI tools I require for code wrangling.

The Makefile generates two toolboxes.

 1. [zie-toolbox](https://github.com/grantmacken/zie-toolbox/pkgs/container/zie-toolbox)
    This base toolbox contains cli tools plus the neovim text editor
 2. [zie-toolbox-dx](https://github.com/grantmacken/zie-toolbox/pkgs/container/zie-toolbox-dx)
    The dx version is a my current development playground based on the gleam lang

The toolboxes are generated on [github actions](https://github.com/grantmacken/zie-toolbox/actions/)
These are my toolboxes so clone the repo and read and adjust the Makefile to suit your own whims.

The toolboxes are built **FROM** the latest fedora-toolbox image

