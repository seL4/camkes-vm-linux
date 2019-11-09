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

/* Linux kernel module for cross vm connection.
 * This allows the parsing of cross vm connections advertised as a PCI device.
 * Cross vm connections being a combination of events and shared memory regions
 * between linux processes and camkes components). This module utilises userspace io
 * to allow linux processes to mmap the pci bars.
 */

#include <linux/device.h>
#include <linux/module.h>
#include <linux/pci.h>
#include <linux/pci_ids.h>
#include <linux/uio_driver.h>
#include <asm/io.h>

/* This is an 'abitrary' custom device id we use to match on our dataports
 * pci driver */
#define PCI_CONNECTOR_DEVICE_ID 0xa111
#define MAX_CONNECTOR_DEVICES 32

typedef struct connector_dev_node {
    struct pci_dev *dev;
    struct uio_info *uio;
} connector_dev_node_t;

connector_dev_node_t *devices[MAX_CONNECTOR_DEVICES];
unsigned int current_free_dev = 0;

static irqreturn_t connector_event_handler(int irq, struct uio_info *dev_info)
{
    uint32_t *event_bar = dev_info->mem[0].internal_addr;
    u32 val;
    val = readl(&event_bar[1]);
    if (val == 0) {
        /* No event - IRQ wasn't for us */
        return IRQ_NONE;
    }
    /* Clear the register and return IRQ
     * TODO: Currently avoiding IRQ count value - we might want to use it? */
    writel(0, &event_bar[1]);
    return IRQ_HANDLED;
}


static int connector_pci_probe(struct pci_dev *dev,
                               const struct pci_device_id *id)
{
    connector_dev_node_t *connector;
    struct uio_info *uio;
    int num_bars;
    int err = 0;
    int unmap = 0;
    int i = 0;

    if (current_free_dev >= MAX_CONNECTOR_DEVICES) {
        printk("Failed to initialize connector: Managing maximum number of devices\n");
        return -ENODEV;
    }

    connector = kzalloc(sizeof(connector_dev_node_t), GFP_KERNEL);
    if (!connector) {
        printk("Failed to initalize connector\n");
        return -ENOMEM;
    }

    uio = kzalloc(sizeof(struct uio_info), GFP_KERNEL);
    if (!uio) {
        printk("Failed to initialize uio information\n");
        kfree(connector);
        return -ENOMEM;
    }

    if (pci_enable_device(dev)) {
        goto free_alloc;
    }

    if (pci_request_regions(dev, "connector")) {
        goto disable_pci;
    }

    /* Set up the event bar - We assume the event bar is always BAR0
     * even if the PCI device does not use events */
    uio->mem[0].addr = pci_resource_start(dev, 0);
    if (!uio->mem[0].addr) {
        goto disable_pci;
    }
    uio->mem[0].size = pci_resource_len(dev, 0);
    uio->mem[0].internal_addr = pci_ioremap_bar(dev, 0);
    if (!uio->mem[0].internal_addr) {
        goto disable_pci;
    }
    uio->mem[0].memtype = UIO_MEM_PHYS;
    printk("Event Bar (dev-%d) initalised\n", current_free_dev);

    for (i = 1; i < MAX_UIO_MAPS; i++) {
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

    /* Register our IRQ handler */
    uio->irq = dev->irq;
    uio->irq_flags = IRQF_SHARED;
    uio->handler = connector_event_handler;

    connector->uio = uio;
    connector->dev = dev;

    uio->name = "connector";
    uio->version = "0.0.1";

    if (uio_register_device(&dev->dev, uio)) {
        goto unmap_bars;
    }

    printk("%d Dataports (dev-%d) initalised\n", num_bars, current_free_dev);
    pci_set_drvdata(dev, uio);
    devices[current_free_dev++] = connector;

    return 0;
unmap_bars:
    iounmap(uio->mem[0].internal_addr);
    for (unmap = 1; unmap < num_bars; unmap++) {
        iounmap(uio->mem[unmap].internal_addr);
    }
    pci_release_regions(dev);
disable_pci:
    pci_disable_device(dev);
free_alloc:
    kfree(uio);
    kfree(connector);
    return -ENODEV;
}

static void connector_pci_remove(struct pci_dev *dev)
{
    struct uio_info *uio = pci_get_drvdata(dev);
    uio_unregister_device(uio);
    pci_release_regions(dev);
    pci_disable_device(dev);
    kfree(uio);
}

static struct pci_device_id connector_pci_ids[] = {
    {
        .vendor =       PCI_VENDOR_ID_REDHAT_QUMRANET,
        .device =       PCI_CONNECTOR_DEVICE_ID,
        .subvendor =    PCI_ANY_ID,
        .subdevice =    PCI_ANY_ID,
    },
    {0,}
};

static struct pci_driver connector_pci_driver = {
    .name = "connector",
    .id_table = connector_pci_ids,
    .probe = connector_pci_probe,
    .remove = connector_pci_remove,
};

module_pci_driver(connector_pci_driver);
MODULE_DEVICE_TABLE(pci, connector_pci_ids);
MODULE_LICENSE("GPL v2");
