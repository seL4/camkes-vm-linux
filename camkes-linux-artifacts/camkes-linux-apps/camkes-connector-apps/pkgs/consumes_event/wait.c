/*
 * Copyright 2018, Data61
 * Commonwealth Scientific and Industrial Research Organisation (CSIRO)
 * ABN 41 687 119 230.
 *
 * This software may be distributed and modified according to the terms of
 * the GNU General Public License version 2. Note that NO WARRANTY is provided.
 * See "LICENSE_GPLv2.txt" for details.
 *
 * @TAG(DATA61_GPL)
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
