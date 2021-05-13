/*
 * Copyright 2020, Data61, CSIRO (ABN 41 687 119 230)
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdint.h>
#include <assert.h>
#include <unistd.h>

#define PAGESIZE 0x1000
#define N 10

typedef struct {
    uint64_t pfn : 55;
    unsigned int soft_dirty : 1;
    unsigned int file_page : 1;
    unsigned int swapped : 1;
    unsigned int present : 1;
} PagemapEntry;

int pagemap_get_entry(PagemapEntry *entry, int pagemap_fd, uintptr_t vaddr)
{
    size_t nread;
    ssize_t ret;
    uint64_t data;
    uintptr_t vpn;

    vpn = vaddr / sysconf(_SC_PAGE_SIZE);
    nread = 0;
    while (nread < sizeof(data)) {
        ret = pread(pagemap_fd, ((uint8_t *)&data) + nread, sizeof(data) - nread,
                    vpn * sizeof(data) + nread);
        nread += ret;
        if (ret <= 0) {
            return 1;
        }
    }
    entry->pfn = data & (((uint64_t)1 << 55) - 1);
    entry->soft_dirty = (data >> 55) & 1;
    entry->file_page = (data >> 61) & 1;
    entry->swapped = (data >> 62) & 1;
    entry->present = (data >> 63) & 1;
    return 0;
}

int main(int argc, char *argv[])
{

    //map some memory
    uint32_t *fib = mmap(NULL, N * sizeof(uint32_t), (PROT_READ | PROT_WRITE), (MAP_PRIVATE | MAP_ANONYMOUS), 0, 0);
    if (fib == MAP_FAILED) {
        perror("mmap failed");
        return 1;
    }

    uintptr_t vaddr = (uintptr_t)fib;

    //put some data in
    fib[0] = 1;
    fib[1] = 1;

    for (int i = 2; i < N; i++) {
        fib[i] = fib[i - 1] + fib[i - 2];
    }

    for (int i = 0; i < 10; i++) {
        printf("linux_fib[%d]@%p = %d, ", i, fib + i, fib[i]);
    }

    printf("\n");

    int pagemap = open("/proc/self/pagemap", (O_RDWR));
    assert(pagemap >= 0);
    //get physical address of fib
    PagemapEntry pe;
    if (pagemap_get_entry(&pe, pagemap, vaddr) != 0) {
        printf("pagemap entry failed \n");
        return 1;
    }

    uintptr_t paddr = (pe.pfn * sysconf(_SC_PAGE_SIZE)) + (vaddr % sysconf(_SC_PAGE_SIZE));
    printf("paddr is %x\n", paddr);

    int component = open("/dev/uio0", (O_RDWR));
    if (component == -1) {
        perror("open dataport");
        munmap(fib, N * sizeof(unsigned));
        return 1;
    }

    int done = open("/dev/uio1", O_RDWR);

    //mmap dataport
    void *dataport = mmap(NULL, PAGESIZE, (PROT_READ | PROT_WRITE), MAP_SHARED, component, 1 * getpagesize());
    if (dataport == (void *) -1) {
        perror("mmap dataport");
        close(component);
        munmap(fib, N * sizeof(unsigned));
        return 1;
    }

    //map emit event
    char *emit = mmap(NULL, 0x1000, (PROT_READ | PROT_WRITE), MAP_SHARED, component, 0 * getpagesize());
    if (emit == (void *) -1) {
        perror("mmap dataport");
        close(component);
        munmap(fib, N * sizeof(unsigned));
        return 1;
    }

    //send addr through to component to print
    for (int i = 0;  i < 4; i++) {
        *(uintptr_t *)dataport = paddr;
    }

    //signal we have sent the address
    emit[0] = 1;

    //wait for camkes
    int val;
    int result = read(done, &val, sizeof(val));

    close(component);
    close(pagemap);
    close(done);

    munmap(dataport, PAGESIZE);
    munmap(fib, N * sizeof(uint32_t));
    munmap(emit, PAGESIZE);

    return 0;
}
