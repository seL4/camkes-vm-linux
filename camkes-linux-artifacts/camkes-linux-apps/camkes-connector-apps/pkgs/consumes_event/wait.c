/*
 * Copyright 2018, Data61, CSIRO (ABN 41 687 119 230)
 *
 * SPDX-License-Identifier: GPL-2.0-only
 */

#include <stdio.h>
#include <fcntl.h>
#include <unistd.h>
#include <assert.h>
#include <poll.h>
#include <errno.h>
#include <string.h>

#include <sys/types.h>
#include <sys/stat.h>
#include <sys/mman.h>

int main(int argc, char *argv[])
{

    if (argc != 2) {
        printf("Usage: %s eventfile\n", argv[0]);
        return 1;
    }

    char *filename = argv[1];

    int fd = open(filename, O_RDWR);

    int val;
    int result = read(fd, &val, sizeof(val));

    if (result < 0) {
        printf("Error: %s\n", strerror(errno));
        return -1;
    } else {
        printf("Back from waiting with val: %d\n", val);
    }

    close(fd);

    return 0;
}
