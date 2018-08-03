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

project(camkes-vm-linux C)

include("vm-linux-helpers.cmake")
include("linux-source-helpers.cmake")
include(ExternalProject)

set(configure_string "")

config_option(CAmkESVMDefaultBuildrootOverlay CAMKES_VM_DEFAULT_BUILDROOT_OVERLAY "Enable the building of the default buildroot overlay"
    DEFAULT OFF)

config_option(CAmkESVMLinuxVchan CAMKES_VM_LINUX_VCHAN "Enable installation of VChan packages and modules in the guest VM"
    DEFAULT OFF
    DEPENDS "CAmkESVMDefaultBuildrootOverlay"
)

add_config_library(camkes-vm-linux "${configure_string}")

if(CAmkESVMDefaultBuildrootOverlay)
    # Add packages,libs and modules used in the linux vm
    set(binary_dir ${CMAKE_BINARY_DIR}/camkes-linux-artifacts)

    # Get Custom toolchain for 32 bit Linux
    FindCustomPollyToolchain(LINUX_32BIT_TOOLCHAIN "linux-gcc-32bit-pic")

    # Setup Linux Sources
    GetDefaultLinuxMajor(linux_major)
    GetDefaultLinuxMinor(linux_minor)
    GetDefaultLinuxMd5(linux_md5)
    DownloadLinux(${linux_major} ${linux_minor} ${linux_md5} vm_linux_extract_dir download_vm_linux)
    # Linux config and symvers are to be copied to unpacked archive
    set(linux_config "${CMAKE_CURRENT_SOURCE_DIR}/linux_configs/${linux_major}.${linux_minor}/config")
    set(linux_symvers "${CMAKE_CURRENT_SOURCE_DIR}/linux_configs/${linux_major}.${linux_minor}/Module.symvers")
    # Configure unpacked archive with config and symvers
    ConfigureLinux(${vm_linux_extract_dir} ${linux_config} ${linux_symvers} configure_vm_linux
        DEPENDS download_vm_linux
    )

    # Build camkes connector apps
    set(connector_apps_stamp_dir ${CMAKE_CURRENT_BINARY_DIR}/camkes-connector-apps-stamp)
    set(connector_apps_binary_dir ${binary_dir}/connector-apps)
    ExternalProject_Add(camkes-connector-apps
        URL file:///${CMAKE_CURRENT_SOURCE_DIR}/camkes-linux-artifacts/camkes-linux-apps/camkes-connector-apps
        BINARY_DIR ${connector_apps_binary_dir}
        BUILD_ALWAYS ON
        STAMP_DIR ${connector_apps_stamp_dir}
        EXCLUDE_FROM_ALL
        INSTALL_COMMAND ""
        CMAKE_ARGS
            -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}
            -DCMAKE_TOOLCHAIN_FILE=${LINUX_32BIT_TOOLCHAIN}
    )

    # Build camkes connector modules
    set(connector_modules_stamp_dir ${CMAKE_CURRENT_BINARY_DIR}/camkes-connector-modules-stamp)
    set(connector_modules_binary_dir ${binary_dir}/connector-modules)
    ExternalProject_Add(camkes-connector-modules
        URL file:///${CMAKE_CURRENT_SOURCE_DIR}/camkes-linux-artifacts/camkes-linux-modules/camkes-connector-modules
        BINARY_DIR ${connector_modules_binary_dir}
        BUILD_ALWAYS ON
        STAMP_DIR ${connector_modules_stamp_dir}
        EXCLUDE_FROM_ALL
        INSTALL_COMMAND ""
        DEPENDS download_vm_linux configure_vm_linux
        CMAKE_ARGS
            -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}
            -DCMAKE_TOOLCHAIN_FILE=${LINUX_32BIT_TOOLCHAIN}
            -DLINUX_KERNEL_DIR=${vm_linux_extract_dir}
            -DCROSSVM_SRC=${CMAKE_SOURCE_DIR}/projects/vm/libs/libcrossvm
            -DCONNECTORS_INCLUDE_DIR=${CMAKE_CURRENT_SOURCE_DIR}/camkes-linux-artifacts/camkes-linux-apps/camkes-connector-apps/libs/camkes/include
            -DMODULE_HELPERS_FILE=${CMAKE_CURRENT_SOURCE_DIR}/camkes-linux-artifacts/camkes-linux-modules/linux-module-helpers.cmake
    )

    # Declare camkes connector apps
    AddExternalProjFilesToOverlay(camkes-connector-apps ${connector_apps_binary_dir} default_buildroot_overlay "usr/sbin"
        FILES pkgs/consumes_event/consumes_event_init
        pkgs/consumes_event/consumes_event_wait pkgs/emits_event/emits_event_emit
        pkgs/emits_event/emits_event_init pkgs/dataport/dataport_init pkgs/dataport/dataport_read
        pkgs/dataport/dataport_write pkgs/string_reverse/string_reverse)

    # Declare camkes connector modules
    AddExternalProjFilesToOverlay(camkes-connector-modules ${connector_modules_binary_dir} default_buildroot_overlay "lib/modules/4.8.16/kernel/drivers/vmm"
        FILES consumes_event.ko dataport.ko emits_event.ko)

    # Add additional init scripts to the default buildroot overlay
    AddFileToOverlayDir("init" ${CMAKE_CURRENT_LIST_DIR}/camkes-linux-artifacts/camkes-linux-init-scripts/buildroot_init/init_template "." default_buildroot_overlay)
    AddFileToOverlayDir("S90camkes_init" ${CMAKE_CURRENT_LIST_DIR}/camkes-linux-artifacts/camkes-linux-init-scripts/buildroot_init/camkes_init "etc/init.d" default_buildroot_overlay)

    # Install VChan artifacts
    if(CAmkESVMLinuxVchan)
        # Build vchan apps
        set(vchan_apps_stamp_dir ${CMAKE_CURRENT_BINARY_DIR}/camkes-vchan-apps-stamp)
        set(vchan_apps_binary_dir ${binary_dir}/vchan-apps)
        # Add External vhcan apps project
        ExternalProject_Add(camkes-vchan-apps
            URL file:///${CMAKE_CURRENT_SOURCE_DIR}/camkes-linux-artifacts/camkes-linux-apps/camkes-vchan-apps
            BINARY_DIR ${vchan_apps_binary_dir}
            BUILD_ALWAYS ON
            STAMP_DIR ${vchan_apps_stamp_dir}
            EXCLUDE_FROM_ALL
            INSTALL_COMMAND ""
            CMAKE_ARGS
                -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}
                -DCMAKE_TOOLCHAIN_FILE=${LINUX_32BIT_TOOLCHAIN}
        )
        # Build vchan modules
        set(vchan_modules_stamp_dir ${CMAKE_CURRENT_BINARY_DIR}/camkes-vchan-modules-stamp)
        set(vchan_modules_binary_dir ${binary_dir}/vchan-modules)
        # Add External vhcan modules project
        ExternalProject_Add(camkes-vchan-modules
            URL file:///${CMAKE_CURRENT_SOURCE_DIR}/camkes-linux-artifacts/camkes-linux-modules/camkes-vchan-modules
            BINARY_DIR ${vchan_modules_binary_dir}
            BUILD_ALWAYS ON
            STAMP_DIR ${vchan_modules_stamp_dir}
            EXCLUDE_FROM_ALL
            INSTALL_COMMAND ""
            DEPENDS download_vm_linux configure_vm_linux
            CMAKE_ARGS
                -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}
                -DCMAKE_TOOLCHAIN_FILE=${LINUX_32BIT_TOOLCHAIN}
                -DCROSSVM_SRC=${CMAKE_SOURCE_DIR}/projects/vm/libs/libcrossvm
                -DVCHAN_INCLUDE_DIR=${CMAKE_CURRENT_SOURCE_DIR}/camkes-linux-artifacts/camkes-linux-apps/camkes-vchan-apps/libs/vchan/includes
                -DMODULE_HELPERS_FILE=${CMAKE_CURRENT_SOURCE_DIR}/camkes-linux-artifacts/camkes-linux-modules/linux-module-helpers.cmake
                -DLINUX_KERNEL_DIR=${vm_linux_extract_dir}
        )
        # Declare vchan apps
        AddExternalProjFilesToOverlay(camkes-vchan-apps ${vchan_apps_binary_dir} default_buildroot_overlay "usr/sbin"
            FILES virt/sel4_vchan_testsuite virt/vchan_test_prog virt/vmm_manager_tests virt/vm_guest_manip)
        # Declare vchan modules
        AddExternalProjFilesToOverlay(camkes-vchan-modules ${vchan_modules_binary_dir} default_buildroot_overlay "lib/modules/4.8.16/kernel/drivers/vmm"
            FILES vmm_manager.ko)
    endif()
endif()
