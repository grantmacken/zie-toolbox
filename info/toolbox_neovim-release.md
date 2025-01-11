## My neovim release toolbox

This tbx-neovim-release toolbox is build on my tbx-cli-tools toolbox which contains a select bundle of cli tools useful in a code text editing context.
The tbx-cli-tools toolbox is built from the fedora-silverblue toolbox.

I know the fedora-silverblue is large in size base to build from, but I also know it provides a good reliable out of the box experience.

When you build an image from the another image, the new image is layered on top of the base image. 
When pulling a image, if base layers exists then the pull will not pull these base layers but create the image on top of
the base layers. So there is a case for sticking to single base image and cascade images from the origin base. 

