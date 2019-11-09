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
#include <errno.h>
#include <string.h>
#include <unistd.h>
#include <assert.h>

#include <sys/types.h>
#include <sys/stat.h>
#include <sys/mman.h>

int main(int argc, char *argv[])
{

    if (argc != 2) {
        printf("Usage: %s file\n\n"
               "Emits an event on a given device connection\n",
               argv[0]);
        return 1;
    }

    char *connection_name = argv[1];

    int fd = open(connection_name, O_RDWR);
    assert(fd >= 0);

    char *connection;
    if ((connection = mmap(NULL, 0x1000, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0 * getpagesize())) == (void *) -1) {
        printf("mmap failed\n");
        close(fd);
    }

    /* Write at register address 0 to trigger an emit signal */
    connection[0] = 1;

    munmap(connection, 0x1000);
    close(fd);

    return 0;
}
