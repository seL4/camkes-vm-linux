/*
 * Copyright 2019, Data61
 * Commonwealth Scientific and Industrial Research Organisation (CSIRO)
 * ABN 41 687 119 230.
 *
 * This software may be distributed and modified according to the terms of
 * the GNU General Public License version 2. Note that NO WARRANTY is provided.
 * See "LICENSE_GPLv2.txt" for details.
 *
 * @TAG(DATA61_GPL)
 */

/* Linux kernel module for cross vm dataports.
 * This allows the parsing of cross vm dataports advertised as a PCI device.
 * Cross vm dataports being shared memory regions between linux processes and
 * camkes components). This module utilises userspace io to allow linux
 * processes to mmap the dataports.
 */

#include <linux/device.h>
#include <linux/module.h>
#include <linux/pci.h>
#include <linux/pci_ids.h>
#include <linux/uio_driver.h>
#include <asm/io.h>

/* This is an 'abitrary' custom device id we use to match on our dataports
 * pci driver */
#define PCI_DATAPORT_DEVICE_ID 0xa111

typedef struct dataports {
	struct pci_dev *dev;
    struct uio_info *uio;
} dataports_t;

dataports_t *dataports;

static int dataports_pci_probe(struct pci_dev *dev,
					const struct pci_device_id *id)
{
    struct uio_info *uio;
    int num_bars;
    int err = 0;
    int unmap = 0;
    int i = 0;

	dataports = kzalloc(sizeof(dataports_t), GFP_KERNEL);
	if (!dataports) {
        printk("Failed to initalize dataports\n");
		return -ENOMEM;
	}

    uio = kzalloc(sizeof(struct uio_info), GFP_KERNEL);
	if (!uio) {
		printk("Failed to initialize uio information\n");
		kfree(dataports);
        return -ENOMEM;
    }

	if (pci_enable_device(dev)) {
        goto free_alloc;
    }

	if (pci_request_regions(dev, "dataports")) {
        goto disable_pci;
    }

    for (i = 0; i < MAX_UIO_MAPS; i++) {
        uio->mem[i].addr = pci_resource_start(dev, i);
        if (!uio->mem[i].addr) {
            /* We assume the first NULL bar is the end
             * Implying that all dataports are passed sequentially (i.e. no gaps) */
            break;
        }

        uio->mem[i].internal_addr = ioremap_cache(pci_resource_start(dev, i),
                         pci_resource_len(dev, i));
        if (!uio->mem[i].internal_addr) {
            err = 1;
            break;
        }
        uio->mem[i].size = pci_resource_len(dev, i);
        uio->mem[i].memtype = UIO_MEM_PHYS;
    }
    num_bars = i;
	if (err) {
        goto unmap_bars;
    }
    printk("%d Dataports initalised\n", num_bars);

    dataports->uio = uio;
	dataports->dev = dev;

	uio->irq = -1;
	uio->name = "dataports";
	uio->version = "0.0.1";

	if (uio_register_device(&dev->dev, uio)) {
        goto unmap_bars;
    }

	pci_set_drvdata(dev, uio);

	return 0;
unmap_bars:
    for (unmap = 0; unmap < num_bars; unmap++) {
	    iounmap(uio->mem[unmap].internal_addr);
    }
	pci_release_regions(dev);
disable_pci:
	pci_disable_device(dev);
free_alloc:
	kfree(uio);
    kfree(dataports);
    return -ENODEV;
}

static void dataports_pci_remove(struct pci_dev *dev)
{
	struct uio_info *uio = pci_get_drvdata(dev);
	uio_unregister_device(uio);
	pci_release_regions(dev);
	pci_disable_device(dev);
    kfree(uio);
    kfree(dataports);
}

static struct pci_device_id dataports_pci_ids[] = {
	{
		.vendor =	    PCI_VENDOR_ID_REDHAT_QUMRANET,
		.device =	    PCI_DATAPORT_DEVICE_ID,
		.subvendor =	PCI_ANY_ID,
		.subdevice =	PCI_ANY_ID,
	},
	{0,}
};

static struct pci_driver dataports_pci_driver = {
	.name = "dataports",
	.id_table = dataports_pci_ids,
	.probe = dataports_pci_probe,
	.remove = dataports_pci_remove,
};

module_pci_driver(dataports_pci_driver);
MODULE_DEVICE_TABLE(pci, dataports_pci_ids);
MODULE_LICENSE("GPL v2");
