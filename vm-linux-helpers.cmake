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

RequireFile(UPDATE_INITRD_ROOTFS_PATH update_dtb_initrd.py PATHS "${CMAKE_CURRENT_LIST_DIR}/tools")
set(VM_LINUX_PROJECT_DIR "${CMAKE_CURRENT_LIST_DIR}" CACHE INTERNAL "")

# Function to add a given file to an overlay directory.
# filename: The preferred name of the file in the overlay
# file_location: Absolute path to the file we are adding the overlay
# root_location: The location that the file we are adding will exist in the VM's root filesystem
# overlay_name: Overlay target name
function(AddFileToOverlayDir filename file_location root_location overlay_name)
    # Get any existing dependencies when adding the file into the overlay
    cmake_parse_arguments(PARSE_ARGV 4 ROOTFS_FILE_OVERLAY "" "" "DEPENDS")
    if(NOT "${ROOTFS_FILE_OVERLAY_UNPARSED_ARGUMENTS}" STREQUAL "")
        message(FATAL_ERROR "Unknown arguments to AddFileToOverlay")
    endif()
    set(rootfs_output_dir "${CMAKE_CURRENT_BINARY_DIR}/${overlay_name}")
    if(TARGET ${overlay_name})
        get_target_property(rootfs_output_dir ${overlay_name} ROOTFS_OUTPUT_DIR)
    else()
        add_custom_target(${overlay_name})
        set_property(
            TARGET ${overlay_name}
            APPEND
            PROPERTY ROOTFS_OUTPUT_DIR "${rootfs_output_dir}"
        )
    endif()
    # Copy the file into the rootfs output directory at 'root_location'
    add_custom_command(
        OUTPUT ${rootfs_output_dir}/${root_location}/${filename}
        COMMAND
            ${CMAKE_COMMAND} -E copy "${file_location}"
            "${rootfs_output_dir}/${root_location}/${filename}"
        VERBATIM
        DEPENDS ${file_location} ${ROOTFS_FILE_OVERLAY_DEPENDS}
    )
    # Add the copy command as a dependency for the overlay directory
    set_property(
        TARGET ${overlay_name}
        APPEND
        PROPERTY DEPENDS "${rootfs_output_dir}/${root_location}/${filename}"
    )
endfunction(AddFileToOverlayDir)

# Add a given overlay (location to directory or image file) to install on a given rootfs_image
# rootfs_overlay : Absolute path to directory or overlay file
# rootfs_image: Absolute path to the rootfs image you are overlaying
# rootfs_distro: The distribution of the rootfs image belongs to. This currently only supports debian/ubuntu and buildroot
# rootfs_overlay_mode: The overlay mode. These being 'overlay','fs_install', 'rootfs_install'
# output_rootfs_location: The output location (absolute path) of the rootfs image
# target_name: Target name for adding the overlay to the given rootfs image
function(
    AddOverlayToRootfs
    rootfs_overlay
    rootfs_image
    rootfs_distro
    rootfs_overlay_mode
    output_rootfs_location
    target_name
)
    if(TARGET ${target_name})
        message(FATAL_ERROR "Already declared ${target_name} as a target")
    endif()
    # Get any existing dependencies when adding overlay directory
    cmake_parse_arguments(PARSE_ARGV 6 ROOTFS_OVERLAY "SPLITGZ;GZIP" "" "DEPENDS;CUSTOM_INIT")
    if(NOT "${ROOTFS_OVERLAY_UNPARSED_ARGUMENTS}" STREQUAL "")
        message(
            FATAL_ERROR
                "Unknown arguments to AddOverlayDirectoryToRootfs - ${ROOTFS_OVERLAY_UNPARSED_ARGUMENTS}"
        )
    endif()
    # Additional flags to build the rootfs
    set(additional_install_flags "")
    if(${ROOTFS_OVERLAY_SPLITGZ})
        set(additional_install_flags "--splitgz")
    endif()
    if(NOT ${ROOTFS_OVERLAY_CUSTOM_INIT} STREQUAL "")
        set(
            additional_install_flags
            "${additional_install_flags} --custom-init=${ROOTFS_OVERLAY_CUSTOM_INIT}"
        )
    endif()
    if(${ROOTFS_OVERLAY_GZIP})
        set(additional_install_flags "${additional_install_flags} --gzip")
        set(gzip_ext ".gz")
    endif()
    # Command to install the rootfs artifacts
    add_custom_command(
        OUTPUT out_${target_name}/output_overlay_rootfs.cpio${gzip_ext}
        COMMAND
            bash -c
            "${VM_LINUX_PROJECT_DIR}/tools/rootfs_unpack/install_artifacts_rootfs.sh --mode=${rootfs_overlay_mode} --image=${rootfs_image} \
        --distro=${rootfs_distro} --root-install=${rootfs_overlay} --output-image-name=output_overlay_rootfs.cpio \
        --output-dir=${CMAKE_CURRENT_BINARY_DIR}/out_${target_name} ${additional_install_flags}"
        VERBATIM
        DEPENDS ${rootfs_overlay} ${ROOTFS_OVERLAY_DEPENDS}
    )
    # Create custom target for the command
    add_custom_target(
        ${target_name}
        DEPENDS
            "${CMAKE_CURRENT_BINARY_DIR}/out_${target_name}/output_overlay_rootfs.cpio${gzip_ext}"
    )
    set(
        ${output_rootfs_location}
        "${CMAKE_CURRENT_BINARY_DIR}/out_${target_name}/output_overlay_rootfs.cpio${gzip_ext}"
        PARENT_SCOPE
    )
endfunction(AddOverlayToRootfs)

# Wrapper function to add an overlay directory to a rootfs image
# This uses the overlay target created when calling 'AddFileToOverlayDir'
function(
    AddOverlayDirToRootfs
    rootfs_overlay_target
    rootfs_image
    rootfs_distro
    rootfs_overlay_mode
    output_rootfs_location
    target_name
)
    AddOverlayToRootfs(
        "$<TARGET_PROPERTY:${rootfs_overlay_target},ROOTFS_OUTPUT_DIR>"
        ${rootfs_image}
        ${rootfs_distro}
        ${rootfs_overlay_mode}
        return_location
        ${target_name}
        DEPENDS
        "$<TARGET_PROPERTY:${rootfs_overlay_target},DEPENDS>"
        ${ARGN}
    )
    set(${output_rootfs_location} "${return_location}" PARENT_SCOPE)
endfunction(AddOverlayDirToRootfs)

# Wrapper function to declare object files in an external project and add them to the targeted overlay
# external_target: Target of external project
# external_install_dir: The install/binary directory where the files are located
# overlay_target: The overlay target we are adding files to
# overlay_root_location: The location in the overlay the file is to be installed. Note all files passed in a given
# call of this helper will install in the same root location.
# FILES: A list of files to declare from an external project and add to the given overlay
function(
    AddExternalProjFilesToOverlay
    external_target
    external_install_dir
    overlay_target
    overlay_root_location
)
    # Get the external project files to add the the overlay
    cmake_parse_arguments(PARSE_ARGV 4 EXTERNAL_PROJ_OVERLAY "" "" "FILES")
    # Error checking
    if(NOT "${EXTERNAL_PROJ_OVERLAY_UNPARSED_ARGUMENTS}" STREQUAL "")
        message(FATAL_ERROR "Unknown arguments to AddExternalProjFilesToOverlay")
    endif()
    # Necessary to provide a least one file
    if(NOT EXTERNAL_PROJ_OVERLAY_FILES)
        message(FATAL_ERROR "NO FILES declared in AddExternalProjFilesToOverlay")
    endif()
    # Declare the project files
    include(external-project-helpers)
    DeclareExternalProjObjectFiles(
        ${external_target}
        ${external_install_dir}
        FILES
        ${EXTERNAL_PROJ_OVERLAY_FILES}
    )
    # Iterate adding each file to the overlay
    foreach(file IN LISTS EXTERNAL_PROJ_OVERLAY_FILES)
        get_filename_component(file_name ${file} NAME)
        AddFileToOverlayDir(
            "${file_name}"
            ${external_install_dir}/${file}
            "${overlay_root_location}"
            ${overlay_target}
            DEPENDS
            ${external_target}
        )
    endforeach()
endfunction()

# Function takes an input dtb file and input rootfs file and creates a new dtb with
# updated initrd-start and initrd-end fields. These fields reflect the size of the
# input rootfs file.
function(
    UpdateDtbFromInitrd
    input_dtb_file
    input_rootfs_file
    initrd_start_location
    output_dtb_target
    output_dtb_file
)
    get_filename_component(dtb_basename ${input_dtb_file} NAME)
    cmake_parse_arguments(PARSE_ARGV 5 INITRD_DTB "" "" "DEPENDS")
    set(output_dtb_filename "gen_dtb_${dtb_basename}")
    add_custom_command(
        OUTPUT ${output_dtb_filename}
        COMMAND
            python3 "${UPDATE_INITRD_ROOTFS_PATH}"
            --dtb "${input_dtb_file}"
            --output_dtb "${CMAKE_CURRENT_BINARY_DIR}/${output_dtb_filename}"
            --initrd "${input_rootfs_file}"
            --initrd_start "${initrd_start_location}"
        VERBATIM
        DEPENDS ${input_dtb_file} ${input_rootfs_file} ${INITRD_DTB_DEPENDS}
    )
    add_custom_target(
        ${output_dtb_target}
        DEPENDS "${CMAKE_CURRENT_BINARY_DIR}/${output_dtb_filename}"
    )
    set(${output_dtb_file} "${CMAKE_CURRENT_BINARY_DIR}/${output_dtb_filename}" PARENT_SCOPE)
endfunction(UpdateDtbFromInitrd)

# Function for getting the default location of the Linux guest kernel provided
# by the vm project
# dest_file: caller variable which is set with the kernel location
function(GetDefaultLinuxKernelFile dest_file)
    set(${dest_file} ${VM_LINUX_PROJECT_DIR}/images/kernel/default_bzimage_4.8.16 PARENT_SCOPE)
endfunction(GetDefaultLinuxKernelFile)

# Function for getting the default location of the Linux guest rootfs provided
# by the vm project
# dest_file: caller variable which is set with the rootfs location
function(GetDefaultLinuxRootfsFile dest_file)
    set(
        ${dest_file} ${VM_LINUX_PROJECT_DIR}/images/rootfs/default_buildroot_rootfs.cpio
        PARENT_SCOPE
    )
endfunction(GetDefaultLinuxRootfsFile)
