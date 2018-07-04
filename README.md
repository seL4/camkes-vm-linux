<!--
     Copyright 2018, Data61
     Commonwealth Scientific and Industrial Research Organisation (CSIRO)
     ABN 41 687 119 230.

     This software may be distributed and modified according to the terms of
     the BSD 2-Clause license. Note that NO WARRANTY is provided.
     See "LICENSE_BSD2.txt" for details.

     @TAG(DATA61_BSD)
-->

CAmkES VM Linux
===============

This directory contains a series of tools, CMake helpers, linux images and
root file system artifacts suitable for creating and using in a CAmkES VM.
The contents of this repository include:
* `images/`: This directory contains a prebuilt linux 4.8.16 kernel image and a
buildroot rootfs image that can be used for CAmkES VM guest.
* `camkes-linux-artifacts/`: This directory contains a series of camkes
artifacts that can be installed in your linux VM guest. These include
packages and modules that provide the crossvm functionality.
* `vm-linux-helpers.cmake`: A series of CMake helpers to define rootfile system
overlays for a CAmkES VM linux guest and retrieve default linux images.
