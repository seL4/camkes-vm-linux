#
# Copyright 2018, Data61, CSIRO (ABN 41 687 119 230)
#
# SPDX-License-Identifier: BSD-2-Clause
#

cmake_minimum_required(VERSION 3.16.0)

project(dataport C)

add_executable(dataport_read read.c)
target_link_libraries(dataport_read -static-libgcc -static)

add_executable(dataport_write write.c)
target_link_libraries(dataport_write -static-libgcc -static)
