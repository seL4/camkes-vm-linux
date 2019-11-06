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
function(DownloadLinux linux_major linux_minor linux_md5 linux_out_dir linux_out_target)
    # Linux version and out variables
    set(linux_version "${linux_major}.${linux_minor}")
    set(linux_dir "linux-${linux_version}")
    set(linux_archive "${linux_dir}.tar.gz")
    set(linux_url "https://www.kernel.org/pub/linux/kernel/v${linux_major}.x/${linux_archive}")
    # Create a cmake file to download the linux source. We do this so we don't download the
    # the linux source until build time
    file(WRITE ${CMAKE_CURRENT_BINARY_DIR}/download_linux.cmake
        "file(DOWNLOAD ${linux_url} ${CMAKE_CURRENT_BINARY_DIR}/out/${linux_archive} \
            SHOW_PROGRESS \
            EXPECTED_MD5 ${linux_md5})"
    )
    # Custom command to execute linux source download
    add_custom_command(OUTPUT out/${linux_archive}
        COMMAND ${CMAKE_COMMAND} -P ${CMAKE_CURRENT_BINARY_DIR}/download_linux.cmake
        VERBATIM
    )
    add_custom_target(download_${linux_out_target} DEPENDS "${CMAKE_CURRENT_BINARY_DIR}/out/${linux_archive}")
    # Unpack linux tar archive
    # We track the .cmake_extracted file instead of the directory to avoid 'ninja clean' trying to delete
    # the extracted directory
    add_custom_command(OUTPUT out/${linux_dir}/.cmake_extracted
        COMMAND ${CMAKE_COMMAND} -E tar xf ${linux_archive}
        COMMAND touch ${linux_dir}/.cmake_extracted
        WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/out
        VERBATIM
        DEPENDS download_${linux_out_target} ${CMAKE_CURRENT_BINARY_DIR}/out/${linux_archive}
    )
    # Create custom target for tar extract
    add_custom_target(extract_${linux_out_target} DEPENDS "${CMAKE_CURRENT_BINARY_DIR}/out/${linux_dir}/.cmake_extracted")
    # Add clean target for extracted linux directory.
    add_custom_target(clean-${linux_out_target}
        COMMAND bash -c "rm -r ${CMAKE_CURRENT_BINARY_DIR}/out/${linux_dir}"
    )
    # Add linux out target
    add_custom_target(${linux_out_target} DEPENDS extract_${linux_out_target})
    set_property(TARGET ${linux_out_target} PROPERTY EXTRACT_DIR "${CMAKE_CURRENT_BINARY_DIR}/out/${linux_dir}")
    # Pass out directory back to parent
    set(${linux_out_dir} "${CMAKE_CURRENT_BINARY_DIR}/out/${linux_dir}" PARENT_SCOPE)
endfunction(DownloadLinux)

# Function for configuring the Linux source located at 'linux_dir' with given
# config (linux_config_location) and symvers (linux_symvers_location)
function(ConfigureLinux linux_dir linux_config_location linux_symvers_location configure_linux_target)
    # Get any existing dependencies for configuring linux
    cmake_parse_arguments(PARSE_ARGV 4 CONFIGURE_LINUX
        ""
        "ARCH;CROSS_COMPILE"
        "DEPENDS"
    )
    if (NOT "${CONFIGURE_LINUX_UNPARSED_ARGUMENTS}" STREQUAL "")
        message(FATAL_ERROR "Unknown arguments to ConfigureLinux: ${CONFIGURE_LINUX_UNPARSED_ARGUMENTS}")
    endif()
    set(configure_flags "")
    if (NOT "${CONFIGURE_LINUX_ARCH}" STREQUAL "")
        set(configure_flags "ARCH=${CONFIGURE_LINUX_ARCH}")
    endif()
    if (NOT "${CONFIGURE_LINUX_CROSS_COMPILE}" STREQUAL "")
        set(configure_flags "${configure_flags} CROSS_COMPILE=${CONFIGURE_LINUX_CROSS_COMPILE}")
    endif()

    # Copy linux config & symvers
    add_custom_command(OUTPUT ${linux_dir}/.config ${linux_dir}/Module.symvers
        COMMAND ${CMAKE_COMMAND} -E copy "${linux_config_location}" "${linux_dir}/.config"
        COMMAND ${CMAKE_COMMAND} -E copy "${linux_symvers_location}" "${linux_dir}/Module.symvers"
        VERBATIM
        DEPENDS  ${CONFIGURE_LINUX_DEPENDS}
    )
    # Create copy config target
    add_custom_target(${configure_linux_target}_copy_configs
        DEPENDS "${linux_dir}/.config" "${linux_dir}/Module.symvers"
    )
    # Prepare/Configure Linux Build Directory
    add_custom_command(OUTPUT ${linux_dir}/.config.old
        COMMAND bash -c "make oldconfig ${configure_flags} "
        COMMAND bash -c "make prepare ${configure_flags} "
        COMMAND bash -c "make modules_prepare ${configure_flags} "
        VERBATIM
        WORKING_DIRECTORY ${linux_dir}
        DEPENDS ${configure_linux_target}_copy_configs ${CONFIGURE_LINUX_DEPENDS}
    )
    add_custom_target(${configure_linux_target} DEPENDS "${linux_dir}/.config.old")
endfunction(ConfigureLinux)
