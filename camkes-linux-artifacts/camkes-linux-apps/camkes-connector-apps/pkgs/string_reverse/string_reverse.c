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

#include <sys/stat.h>
#include <sys/mman.h>

#include "consumes_event.h"
#include "emits_event.h"

#define READY "/dev/camkes_reverse_ready"
#define DONE "/dev/camkes_reverse_done"
#define DATAPORTS_NAME "/dev/uio0"

#define BUFSIZE 2048
char buf[BUFSIZE];

int main(int argc, char *argv[]) {

    int ready = open(READY, O_RDWR);
    int done = open(DONE, O_RDWR);

    int dataport_fd = open(DATAPORTS_NAME, O_RDWR);
    assert(dataport_fd >= 0);

    volatile char *src_data;
    if ((src_data = mmap(NULL, BUFSIZE, PROT_READ|PROT_WRITE, MAP_SHARED, dataport_fd, 0 * getpagesize())) == (__caddr_t)-1) {
        printf("mmap src (index 0) failed\n");
        close(dataport_fd);
        return -1;
    }
    volatile char *dest_data;
    if ((dest_data = mmap(NULL, BUFSIZE, PROT_READ|PROT_WRITE, MAP_SHARED, dataport_fd, 1 * getpagesize())) == (__caddr_t)-1) {
        printf("mmap dest (index 1) failed\n");
        munmap(src_data, BUFSIZE);
        close(dataport_fd);
        return -1;
    }

    while (fgets(buf, BUFSIZE, stdin)) {
        int last_idx = strnlen(buf, BUFSIZE - 1) - 1;
        if (buf[last_idx] == '\n') {
            buf[last_idx] = '\0';
        }

        // copy buf to src_data
        int i;
        for (i = 0; buf[i]; i++) {
            src_data[i] = buf[i];
        }
        src_data[i] = '\0';

        // signal that we're ready for camkes component to reverse string
        int error = emits_event_emit(ready);
        assert(error == 0);

        // wait for camkes to signal that the string is reversed
        error = consumes_event_wait(done);
        assert(error > 0);

        // read the result out of dest_data
        strncpy(buf, (char*)dest_data, BUFSIZE);

        printf("%s\n", buf);
    }

    close(ready);
    close(done);
    close(dataport_fd);

    munmap(src_data, BUFSIZE);
    munmap(dest_data, BUFSIZE);

    return 0;
}
