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

set(VM_ARTIFACTS_DIR "${CMAKE_CURRENT_LIST_DIR}" CACHE INTERNAL "")

# Function for getting the major version for the default Linux guest kernel provided
# by the project
# version: caller variable which is set to the kernel major version
function(GetDefaultLinuxMajor version)
    set(${version} "4" PARENT_SCOPE)
endfunction(GetDefaultLinuxMajor)

# Function for getting the minor version for the default Linux guest kernel provided
# by the project
# version: caller variable which is set to the kernel minor version
function(GetDefaultLinuxMinor version)
    set(${version} "8.16" PARENT_SCOPE)
endfunction(GetDefaultLinuxMinor)

# Function for getting the md5 hash for the default Linux guest kernel provided
# by the project
# md5: caller variable which is set to the kernel md5
function(GetDefaultLinuxMd5 md5)
    set(${md5} "5230b0185b5f4916feab86c450207606" PARENT_SCOPE)
endfunction(GetDefaultLinuxMd5)

# Function for getting the version for the default Linux guest kernel provided
# by the project
# version: caller variable which is set to the kernel version
function(GetDefaultLinuxVersion version)
    GetDefaultLinuxMinor(minor)
    GetDefaultLinuxMajor(major)
    set(${version} "${major}.${minor}" PARENT_SCOPE)
endfunction(GetDefaultLinuxVersion)

# Function for downloading the Linux source inorder to build kernel modules
function(DownloadLinux)
    # Use the linux md5 hash if its passed in
    if(LINUX_MD5)
        set(linux_md5 "${LINUX_MD5}")
    endif()
    # Use the linux major and minor if its passed in
    if(LINUX_MAJOR AND LINUX_MINOR)
        set(linux_major ${LINUX_MAJOR})
        set(linux_minor ${LINUX_MINOR})
    else()
        # Else default to a pre-defined major/minor
        GetDefaultLinuxMajor(linux_major)
        GetDefaultLinuxMinor(linux_minor)
        GetDefaultLinuxMd5(linux_md5)
    endif()
    set(linux_version "${linux_major}.${linux_minor}")
    set(linux_dir "linux-${linux_version}")
    set(linux_archive "${linux_dir}.tar.gz")
    set(linux_url "https://www.kernel.org/pub/linux/kernel/v${linux_major}.x/${linux_archive}")
    # Download the linux archive and verify its hash
    if(NOT linux_md5 STREQUAL "")
        file(DOWNLOAD ${linux_url} ${CMAKE_CURRENT_BINARY_DIR}/out/${linux_archive}
            SHOW_PROGRESS
            EXPECTED_MD5 ${linux_md5})
    else()
        file(DOWNLOAD ${linux_url} ${CMAKE_CURRENT_BINARY_DIR}/out/${linux_archive} SHOW_PROGRESS)
    endif()
    # Unpack linux tar archive
    add_custom_command(OUTPUT out/${linux_dir}
        COMMAND ${CMAKE_COMMAND} -E tar xf ${linux_archive}
        WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/out
        VERBATIM
        DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/out/${linux_archive}
    )
    # Create custom target for tar extract
    add_custom_target(extract_${linux_archive} DEPENDS "${CMAKE_CURRENT_BINARY_DIR}/out/${linux_dir}")
    # Linux config and symvers are to be copied to unpacked archive
    set(linux_config "${VM_ARTIFACTS_DIR}/linux_configs/${linux_version}/config")
    set(linux_symvers "${VM_ARTIFACTS_DIR}/linux_configs/${linux_version}/Module.symvers")
    # Copy linux config & symvers
    add_custom_command(OUTPUT out/${linux_dir}/.config out/${linux_dir}/Module.symvers
        COMMAND ${CMAKE_COMMAND} -E copy "${linux_config}" "${CMAKE_CURRENT_BINARY_DIR}/out/${linux_dir}/.config"
        COMMAND ${CMAKE_COMMAND} -E copy "${linux_symvers}" "${CMAKE_CURRENT_BINARY_DIR}/out/${linux_dir}/Module.symvers"
        VERBATIM
        DEPENDS extract_${linux_archive}
    )
    add_custom_target(copy_linux_configs
        DEPENDS "${CMAKE_CURRENT_BINARY_DIR}/out/${linux_dir}/.config" "${CMAKE_CURRENT_BINARY_DIR}/out/${linux_dir}/Module.symvers"
    )
    # Add download linux vm target
    add_custom_target(download_vm_linux DEPENDS extract_${linux_archive} copy_linux_configs)
    set_property(TARGET download_vm_linux PROPERTY EXTRACT_DIR "${CMAKE_CURRENT_BINARY_DIR}/out/${linux_dir}")
endfunction(DownloadLinux)

# Function to define a linux kernel module. Given the directory to the
# kernel module
# module_dir: Directory to linux kernel module
function(DefineLinuxModule module_dir)
    cmake_parse_arguments(PARSE_ARGV 1 DEFINE_LINUX_MODULE
        ""
        ""
        "DEPENDS;INCLUDES")
    # We require the linux source for compiling our kernel modules
    if (NOT TARGET download_vm_linux)
        DownloadLinux()
    endif()
    # Get linux extract directory (Kbuild directory)
    get_target_property(linux_extract_dir download_vm_linux EXTRACT_DIR)
    get_filename_component(module_name ${module_dir} NAME)
    # Prepare Linux Build Directory
    if(NOT TARGET prepare_linux_build)
        add_custom_command(OUTPUT ${linux_extract_dir}/.config.old
            COMMAND bash -c "make oldconfig"
            COMMAND bash -c "make prepare"
            COMMAND bash -c "make modules_prepare"
            VERBATIM
            WORKING_DIRECTORY ${linux_extract_dir}
            DEPENDS ${DEFINE_LINUX_MODULE_DEPENDS} download_vm_linux
        )
        add_custom_target(prepare_linux_build DEPENDS "${linux_extract_dir}/.config.old")
    endif()
    # Build Linux Module
    set(module_includes "")
    foreach(inc IN LISTS DEFINE_LINUX_MODULE_INCLUDES)
        if(module_includes STREQUAL "")
            set(module_includes "-I${inc}")
        else()
            set(module_includes "${module_includes} -I${inc}")
        endif()
    endforeach()
    add_custom_command(OUTPUT ${module_name}.ko
        COMMAND bash -c "make MODULE_INCLUDES=\"${module_includes}\" KHEAD=${linux_extract_dir}"
        COMMAND ${CMAKE_COMMAND} -E copy "${CMAKE_CURRENT_SOURCE_DIR}/${module_dir}/${module_name}.ko" "${CMAKE_CURRENT_BINARY_DIR}/${module_name}.ko"
        VERBATIM
        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/${module_dir}
        DEPENDS ${DEFINE_LINUX_MODULE_DEPENDS} prepare_linux_build download_vm_linux
    )
    # Add target for linux module
    add_custom_target(build_module_${module_name} ALL DEPENDS "${CMAKE_CURRENT_BINARY_DIR}/${module_name}.ko")
endfunction(DefineLinuxModule)
