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

# Function to define a linux kernel module. Given the directory to the
# kernel module
# module_dir: Directory to linux kernel module
function(DefineLinuxModule module_dir)
    cmake_parse_arguments(PARSE_ARGV 1 DEFINE_LINUX_MODULE
        ""
        ""
        "DEPENDS;INCLUDES")
    # Check that the linux kerenl directory has been passed
    if(NOT LINUX_KERNEL_DIR)
        message(FATAL_ERROR "LINUX_KERNEL_DIR has not been defined. This is needed to compile our module source")
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
    add_custom_command(OUTPUT ${module_name}.ko
        COMMAND bash -c "make MODULE_INCLUDES=\"${module_includes}\" KHEAD=${LINUX_KERNEL_DIR}"
        COMMAND ${CMAKE_COMMAND} -E copy "${CMAKE_CURRENT_SOURCE_DIR}/${module_dir}/${module_name}.ko" "${CMAKE_CURRENT_BINARY_DIR}/${module_name}.ko"
        VERBATIM
        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/${module_dir}
        DEPENDS ${DEFINE_LINUX_MODULE_DEPENDS}
    )
    # Add target for linux module
    add_custom_target(build_module_${module_name} ALL DEPENDS "${CMAKE_CURRENT_BINARY_DIR}/${module_name}.ko")
endfunction(DefineLinuxModule)
