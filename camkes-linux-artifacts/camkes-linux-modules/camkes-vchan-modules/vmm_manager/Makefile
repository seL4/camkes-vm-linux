#
# Copyright 2018, Data61
# Commonwealth Scientific and Industrial Research Organisation (CSIRO)
# ABN 41 687 119 230.
#
# This software may be distributed and modified according to the terms of
# the GNU General Public License version 2. Note that NO WARRANTY is provided.
# See "LICENSE_GPLv2.txt" for details.
#
# @TAG(DATA61_GPL)
#

obj-m += vmm_manager.o
vmm_manager-objs += sel4_vmm_manager_driver.o event_thread.o

ifneq ($(MODULE_INCLUDES),)
	CFLAGS_sel4_vmm_manager_driver.o = $(MODULE_INCLUDES)
	CFLAGS_event_thread.o = $(MODULE_INCLUDES)
endif

all:
	make -C $(KHEAD) M=$(PWD) modules

clean:
	make -C $(KHEAD) M=$(PWD) clean
