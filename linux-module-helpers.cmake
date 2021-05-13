#
# Copyright 2018, Data61, CSIRO (ABN 41 687 119 230)
#
# SPDX-License-Identifier: BSD-2-Clause
#

cmake_minimum_required(VERSION 3.8.2)

# Function to define a linux kernel module. Given the directory to the
# kernel module
# module_dir: Directory to linux kernel module
# output_module_dir: Location to compiled linux kernel module
# output_module_target: Target name to be used for compiled linux kernel module
function(DefineLinuxModule module_dir output_module_location output_module_target)
    cmake_parse_arguments(
        PARSE_ARGV
        1
        DEFINE_LINUX_MODULE
        ""
        "KERNEL_DIR;ARCH;CROSS_COMPILE"
        "DEPENDS;INCLUDES"
    )
    # Check that the linux kerenl directory has been passed
    if(NOT DEFINE_LINUX_MODULE_KERNEL_DIR)
        message(
            FATAL_ERROR
                "LINUX_KERNEL_DIR has not been defined. This is needed to compile our module source"
        )
    endif()
    set(compile_flags "")
    if(NOT "${DEFINE_LINUX_MODULE_ARCH}" STREQUAL "")
        set(compile_flags "ARCH=${DEFINE_LINUX_MODULE_ARCH}")
    endif()
    if(NOT "${DEFINE_LINUX_MODULE_CROSS_COMPILE}" STREQUAL "")
        set(compile_flags "${compile_flags} CROSS_COMPILE=${DEFINE_LINUX_MODULE_CROSS_COMPILE}")
    endif()
    get_filename_component(module_name ${module_dir} NAME)
    # Build Linux Module
    set(module_includes "")
    foreach(inc IN LISTS DEFINE_LINUX_MODULE_INCLUDES)
        if(module_includes STREQUAL "")
            set(module_includes "-I${inc}")
        else()
            set(module_includes "${module_includes} -I${inc}")
        endif()
    endforeach()

    # Re-copy the files into the build directory whenever they are updated
    file(GLOB_RECURSE ${module_name}_files ${module_dir}/**/* ${module_dir}/*)

    add_custom_command(
        OUTPUT ${module_name}.ko
        COMMAND bash -c "cp -a ${module_dir} ${CMAKE_CURRENT_BINARY_DIR}"
        COMMAND cd ${CMAKE_CURRENT_BINARY_DIR}/${module_name}
        COMMAND
            bash -c
            "make ${compile_flags} MODULE_INCLUDES=\"${module_includes}\" KHEAD=${DEFINE_LINUX_MODULE_KERNEL_DIR}"
        COMMAND
            ${CMAKE_COMMAND} -E copy "${CMAKE_CURRENT_BINARY_DIR}/${module_name}/${module_name}.ko"
            "${CMAKE_CURRENT_BINARY_DIR}/${module_name}.ko"
        VERBATIM
        WORKING_DIRECTORY ${module_dir}
        DEPENDS ${DEFINE_LINUX_MODULE_DEPENDS} ${${module_name}_files}
    )
    # Add target for linux module
    add_custom_target(
        ${output_module_target} ALL
        DEPENDS "${CMAKE_CURRENT_BINARY_DIR}/${module_name}.ko"
    )
    set(${output_module_location} "${CMAKE_CURRENT_BINARY_DIR}/${module_name}.ko" PARENT_SCOPE)
endfunction(DefineLinuxModule)
