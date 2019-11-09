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

if(NOT MODULE_HELPERS_FILE)
    message(FATAL_ERROR "MODULE_HELPERS_FILE is not defined")
endif()

include("${MODULE_HELPERS_FILE}")

if(NOT LINUX_KERNEL_DIR)
    message(FATAL_ERROR "LINUX_KERNEL_DIR is not defined")
endif()

DefineLinuxModule(
    ${CMAKE_CURRENT_SOURCE_DIR}/connection
    connection_output
    connection_target
    INCLUDES
    KERNEL_DIR
    ${LINUX_KERNEL_DIR}
)
