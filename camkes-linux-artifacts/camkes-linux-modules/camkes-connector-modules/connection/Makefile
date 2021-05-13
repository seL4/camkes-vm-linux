#
# Copyright 2019, Data61, CSIRO (ABN 41 687 119 230)
#
# SPDX-License-Identifier: GPL-2.0-only
#

obj-m += connection.o

ifneq ($(MODULE_INCLUDES),)
	CFLAGS_connection.o = $(MODULE_INCLUDES)
endif

all:
	make -C $(KHEAD) M=$(PWD) modules

clean:
	make -C $(KHEAD) M=$(PWD) clean
