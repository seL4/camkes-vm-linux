#
# Copyright 2018, Data61, CSIRO (ABN 41 687 119 230)
#
# SPDX-License-Identifier: BSD-2-Clause
#

cmake_minimum_required(VERSION 3.16.0)

project(consumes-event C)

add_executable(consumes_event_wait wait.c)
target_link_libraries(consumes_event_wait -static-libgcc -static)
