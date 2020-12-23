#!/usr/bin/env python
#
# Copyright 2019, Data61, CSIRO (ABN 41 687 119 230)
#
# SPDX-License-Identifier: GPL-2.0-only
#

import os
import argparse
import pyfdt.pyfdt
import logging


def update_node_property(node, property_name, property_value):
    try:
        # Check if the property exists, if so, remove it and re-insert it
        start_index = node.index(property_name)
        node.remove(property_name)
        node.add_subnode(pyfdt.pyfdt.FdtPropertyWords(property_name, property_value))
    except ValueError:
        # Property doesn't exist, just insert it
        node.add_subnode(pyfdt.pyfdt.FdtPropertyWords(property_name, property_value))

# Update chosen node with new initrd-start and initrd-end values


def update_chosen(node, initrd_start, initrd_size):
    # DTS Protocol dictates >32-bit values be represented in pairs. ie, 0x800000000 -> 0x8 0x0
    initrd_end = initrd_start + initrd_size

    update_start = [initrd_start] if initrd_start <= 0xFFFFFFFF \
        else [initrd_start >> 32, initrd_start & 0xFFFFFFFF]

    update_end = [initrd_end] if initrd_end <= 0xFFFFFFFF \
        else [initrd_end >> 32, initrd_end & 0xFFFFFFFF]

    # Update initrd start
    update_node_property(node, "linux,initrd-start", update_start)
    # Update initrd end
    update_node_property(node, "linux,initrd-end", update_end)


def update_dtb(dtb_path, initrd_path, initrd_start):
    fdt = pyfdt.pyfdt.FdtBlobParse(args.dtb).to_fdt()
    root = fdt.get_rootnode()
    updated_chosen = False
    initrd_size = os.stat(initrd_path.name).st_size
    for node in root.walk():
        if node[0] == '/chosen':
            update_chosen(node[1], initrd_start, initrd_size)
            updated_chosen = True
            break
    # No chosen node found, add one to insert our initrd values
    if not updated_chosen:
        chosen_node = pyfdt.pyfdt.FdtNode("chosen")
        chosen_node.set_parent_node(root)
        update_chosen(chosen_node, initrd_start, initrd_size)
        root.add_subnode(chosen_node)
    return fdt


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--dtb', help='Path to the device tree',
                        required=True, type=argparse.FileType('rb'))
    parser.add_argument('--output_dtb', help='Output path to the updated device tree',
                        required=True, type=argparse.FileType('wb'))
    parser.add_argument('--initrd', help='Path to the initrd image the dtb will be bundled with when booting the guest',
                        required=True, type=argparse.FileType('rb'))
    parser.add_argument('--initrd_start', help='Starting location of initrd image in guest kernel memory (hexdecimal)',
                        required=True, type=lambda x: int(x, 0))
    args = parser.parse_args()
    fdt = update_dtb(args.dtb, args.initrd, args.initrd_start)
    args.output_dtb.write(fdt.to_dtb())
    logging.info("Updated dtb location: " + args.output_dtb.name)
