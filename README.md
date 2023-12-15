# grantmacken/zie-toolbox

A dev toolbx  for an immutable OS
based on fedora-minimal


```
podman pull ghcr.io/grantmacken/zie:latest
toolbox create --image ghcr.io/grantmacken/zie
toolbox list
# enter
toolbox enter 
# to boot directly into neovim
toolbox run -c zie nvim
# to debug
podman start --attach zie
```
