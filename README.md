<!--
     Copyright 2018, Data61, CSIRO (ABN 41 687 119 230)

     SPDX-License-Identifier: CC-BY-SA-4.0
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
