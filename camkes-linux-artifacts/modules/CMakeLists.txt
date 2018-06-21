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

include("../linux-artifacts-helpers.cmake")

# We require that CROSSVM is defined in order to build our cross vm camkes modules
if(NOT CROSSVM_SRC)
    message(FATAL_ERROR "CROSSVM_SRC is not defined")
endif()

DefineLinuxModule(consumes_event INCLUDES ${CROSSVM_SRC}/shared_include)
DefineLinuxModule(dataport INCLUDES ${CROSSVM_SRC}/shared_include ${VM_ARTIFACTS_DIR}/libs/camkes/include)
DefineLinuxModule(emits_event INCLUDES ${CROSSVM_SRC}/shared_include ${VM_ARTIFACTS_DIR}/libs/camkes/include)
DefineLinuxModule(vmm_manager INCLUDES ${CROSSVM_SRC}/shared_include ${VM_ARTIFACTS_DIR}/libs/vchan/includes)
