#
# Copyright 2018, Data61, CSIRO (ABN 41 687 119 230)
#
# SPDX-License-Identifier: BSD-2-Clause
#

cmake_minimum_required(VERSION 3.16.0)

if(NOT MODULE_HELPERS_FILE)
    message(FATAL_ERROR "MODULE_HELPERS_FILE is not defined")
endif()

include("${MODULE_HELPERS_FILE}")

if(NOT LINUX_KERNEL_DIR)
    message(FATAL_ERROR "LINUX_KERNEL_DIR is not defined")
endif()

DefineLinuxModule(
    ${CMAKE_CURRENT_SOURCE_DIR}/connection connection_output connection_target INCLUDES KERNEL_DIR
    ${LINUX_KERNEL_DIR}
)
