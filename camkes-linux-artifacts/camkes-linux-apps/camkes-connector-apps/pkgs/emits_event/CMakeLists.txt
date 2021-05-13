#
# Copyright 2018, Data61, CSIRO (ABN 41 687 119 230)
#
# SPDX-License-Identifier: BSD-2-Clause
#

cmake_minimum_required(VERSION 3.8.2)

project(emits-event C)

add_executable(emits_event_emit emit.c)
target_link_libraries(emits_event_emit -static-libgcc -static)
