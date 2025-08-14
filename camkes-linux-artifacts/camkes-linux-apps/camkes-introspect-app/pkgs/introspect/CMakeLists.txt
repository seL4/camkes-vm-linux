#
# Copyright 2020, Data61, CSIRO (ABN 41 687 119 230)
#
# SPDX-License-Identifier: BSD-2-Clause
#

cmake_minimum_required(VERSION 3.16.0)

project(introspect C)

add_executable(introspect introspect.c)
target_link_libraries(introspect -static-libgcc -static)
