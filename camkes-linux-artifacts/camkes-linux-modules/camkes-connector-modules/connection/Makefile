#
# Copyright 2019, Data61
# Commonwealth Scientific and Industrial Research Organisation (CSIRO)
# ABN 41 687 119 230.
#
# This software may be distributed and modified according to the terms of
# the GNU General Public License version 2. Note that NO WARRANTY is provided.
# See "LICENSE_GPLv2.txt" for details.
#
# @TAG(DATA61_GPL)
#

obj-m += connection.o

ifneq ($(MODULE_INCLUDES),)
	CFLAGS_connection.o = $(MODULE_INCLUDES)
endif

all:
	make -C $(KHEAD) M=$(PWD) modules

clean:
	make -C $(KHEAD) M=$(PWD) clean
