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

project(virt C)

add_executable(vmm_manager_tests vmm_manager_tests.c)
target_link_libraries(vmm_manager_tests vchanlinux)

add_executable(vm_guest_manip vm_guest_manip.c)
target_link_libraries(vm_guest_manip vchanlinux)

add_executable(sel4_vchan_testsuite sel4_vchan_testsuite.c)
target_link_libraries(sel4_vchan_testsuite vchanlinux)

add_executable(vchan_test_prog vchan_test_prog.c)
target_link_libraries(vchan_test_prog vchanlinux)
