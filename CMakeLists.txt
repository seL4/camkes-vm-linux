#
# Copyright 2018, Data61
# Commonwealth Scientific and Industrial Research Organisation (CSIRO)
# ABN 41 687 119 230.
#
# This software may be distributed and modified according to the terms of
# the BSD 2-Clause license. Note that NO WARRANTY is provided.
# See "LICENSE_BSD2.txt" for details.
#
# @TAG(DATA61_BSD)
#

cmake_minimum_required(VERSION 3.8.2)

project(vm-linux C)

include("vm-linux-helpers.cmake")
include("camkes-linux-artifacts/linux-artifacts-helpers.cmake")
include(ExternalProject)

# Add packages,libs and modules used in the linux vm
set(stamp_dir ${CMAKE_CURRENT_BINARY_DIR}/camkes-linux-artifacts-stamp)
set(binary_dir ${CMAKE_BINARY_DIR}/camkes-linux-artifacts)

# Get Custom toolchain for 32 bit Linux
FindCustomPollyToolchain(LINUX_32BIT_TOOLCHAIN "linux-gcc-7-32bit-pic")

ExternalProject_Add(camkes-linux-artifacts
    URL file:///${CMAKE_CURRENT_SOURCE_DIR}/camkes-linux-artifacts
	BINARY_DIR ${binary_dir}
    BUILD_ALWAYS ON
    STAMP_DIR ${stamp_dir}
    EXCLUDE_FROM_ALL
    INSTALL_COMMAND ""
    CMAKE_ARGS
        -DCROSSVM_SRC=${CMAKE_SOURCE_DIR}/projects/vm/libs/libcrossvm
        -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}
        -DCMAKE_TOOLCHAIN_FILE=${LINUX_32BIT_TOOLCHAIN}
)

DeclareExternalProjObjectFiles(camkes-linux-artifacts ${binary_dir}
    FILES pkgs/helloworld/helloworld pkgs/consumes_event/consumes_event_init
    pkgs/consumes_event/consumes_event_wait pkgs/emits_event/emits_event_emit
    pkgs/emits_event/emits_event_init pkgs/dataport/dataport_init pkgs/dataport/dataport_read
    pkgs/dataport/dataport_write pkgs/string_reverse/string_reverse modules/consumes_event.ko
    modules/dataport.ko modules/emits_event.ko modules/vmm_manager.ko)

# Add the packages to the default buildroot overlay
AddFileToOverlayDir("helloworld" ${CMAKE_BINARY_DIR}/camkes-linux-artifacts/pkgs/helloworld/helloworld "usr/sbin" default_buildroot_overlay)
AddFileToOverlayDir("consumes_event_init" ${CMAKE_BINARY_DIR}/camkes-linux-artifacts/pkgs/consumes_event/consumes_event_init "usr/sbin" default_buildroot_overlay)
AddFileToOverlayDir("consumes_event_wait" ${CMAKE_BINARY_DIR}/camkes-linux-artifacts/pkgs/consumes_event/consumes_event_wait "usr/sbin" default_buildroot_overlay)
AddFileToOverlayDir("emits_event_emit" ${CMAKE_BINARY_DIR}/camkes-linux-artifacts/pkgs/emits_event/emits_event_emit "usr/sbin" default_buildroot_overlay)
AddFileToOverlayDir("emits_event_init" ${CMAKE_BINARY_DIR}/camkes-linux-artifacts/pkgs/emits_event/emits_event_init "usr/sbin" default_buildroot_overlay)
AddFileToOverlayDir("dataport_init" ${CMAKE_BINARY_DIR}/camkes-linux-artifacts/pkgs/dataport/dataport_init "usr/sbin" default_buildroot_overlay)
AddFileToOverlayDir("dataport_read" ${CMAKE_BINARY_DIR}/camkes-linux-artifacts/pkgs/dataport/dataport_read "usr/sbin" default_buildroot_overlay)
AddFileToOverlayDir("dataport_write" ${CMAKE_BINARY_DIR}/camkes-linux-artifacts/pkgs/dataport/dataport_write "usr/sbin" default_buildroot_overlay)
AddFileToOverlayDir("string_reverse" ${CMAKE_BINARY_DIR}/camkes-linux-artifacts/pkgs/string_reverse/string_reverse "usr/sbin" default_buildroot_overlay)

# Add the kernel modules to the default buildroot overlay
AddFileToOverlayDir("consumes_event.ko" ${CMAKE_BINARY_DIR}/camkes-linux-artifacts/modules/consumes_event.ko "lib/modules/4.8.16/kernel/drivers/vmm" default_buildroot_overlay)
AddFileToOverlayDir("dataport.ko" ${CMAKE_BINARY_DIR}/camkes-linux-artifacts/modules/dataport.ko "lib/modules/4.8.16/kernel/drivers/vmm" default_buildroot_overlay)
AddFileToOverlayDir("emits_event.ko" ${CMAKE_BINARY_DIR}/camkes-linux-artifacts/modules/emits_event.ko "lib/modules/4.8.16/kernel/drivers/vmm" default_buildroot_overlay)
AddFileToOverlayDir("vmm_manager.ko" ${CMAKE_BINARY_DIR}/camkes-linux-artifacts/modules/vmm_manager.ko "lib/modules/4.8.16/kernel/drivers/vmm" default_buildroot_overlay)

# Add additional init scripts to the default buildroot overlay
AddFileToOverlayDir("init" ${CMAKE_CURRENT_LIST_DIR}/camkes-linux-artifacts/init_scripts/buildroot_init/init_template "." default_buildroot_overlay)
AddFileToOverlayDir("S90camkes_init" ${CMAKE_CURRENT_LIST_DIR}/camkes-linux-artifacts/init_scripts/buildroot_init/camkes_init "etc/init.d" default_buildroot_overlay)
