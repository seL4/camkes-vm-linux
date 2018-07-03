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

# We require that CROSSVM is defined in order to build our cross vm camkes modules
if(NOT CROSSVM_SRC)
    message(FATAL_ERROR "CROSSVM_SRC is not defined")
endif()

if(NOT CONNECTORS_INCLUDE_DIR)
    message(FATAL_ERROR "CONNECTORS_INCLUDE_DIR is not defined")
endif()

DefineLinuxModule(consumes_event INCLUDES ${CROSSVM_SRC}/shared_include)
DefineLinuxModule(dataport INCLUDES ${CROSSVM_SRC}/shared_include ${CONNECTORS_INCLUDE_DIR})
DefineLinuxModule(emits_event INCLUDES ${CROSSVM_SRC}/shared_include ${CONNECTORS_INCLUDE_DIR})
