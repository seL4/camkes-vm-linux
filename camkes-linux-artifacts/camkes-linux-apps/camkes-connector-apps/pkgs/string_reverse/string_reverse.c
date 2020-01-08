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
#include <string.h>
#include <assert.h>
#include <stdlib.h>

#include <sys/stat.h>
#include <sys/mman.h>

#define READY "/dev/uio0"
#define DONE "/dev/uio1"

#define BUFSIZE 2048
char buf[BUFSIZE];

int main(int argc, char *argv[])
{

    int ready = open(READY, O_RDWR);
    int done = open(DONE, O_RDWR);

    char *src_data;
    if ((src_data = mmap(NULL, BUFSIZE, PROT_READ | PROT_WRITE, MAP_SHARED, ready, 1 * getpagesize())) == (void *) -1) {
        printf("mmap src (index 1) failed\n");
        close(ready);
        close(done);
        return -1;
    }
    char *emit;
    if ((emit = mmap(NULL, 0x1000, PROT_READ | PROT_WRITE, MAP_SHARED, ready, 0 * getpagesize())) == (void *) -1) {
        printf("mmap failed\n");
        close(ready);
        close(done);
    }

    char *dest_data;
    if ((dest_data = mmap(NULL, BUFSIZE, PROT_READ | PROT_WRITE, MAP_SHARED, done, 1 * getpagesize())) == (void *) -1) {
        printf("mmap dest (index 1) failed\n");
        munmap(src_data, BUFSIZE);
        close(ready);
        close(done);
        return -1;
    }

    while (fgets(buf, BUFSIZE, stdin)) {
        int last_idx = strnlen(buf, BUFSIZE - 1) - 1;
        if (buf[last_idx] == '\n') {
            buf[last_idx] = '\0';
        }

        /* copy buf to src_data */
        int i;
        for (i = 0; buf[i]; i++) {
            src_data[i] = buf[i];
        }
        src_data[i] = '\0';

        /* Signal that we're ready for camkes component to reverse string by writing
         * at register address 0 to trigger an emit signal */
        emit[0] = 1;

        /* wait for camkes to signal that the string is reversed */
        int val;
        int result = read(done, &val, sizeof(val));

        if (result < 0) {
            printf("Error: %s\n", strerror(result));
            munmap(src_data, BUFSIZE);
            munmap(dest_data, BUFSIZE);
            close(ready);
            close(done);
            return -1;
        }
        // read the result out of dest_data
        strncpy(buf, (char *)dest_data, BUFSIZE);

        printf("%s\n", buf);
    }

    munmap(src_data, BUFSIZE);
    munmap(dest_data, BUFSIZE);
    close(ready);
    close(done);

    return 0;
}
