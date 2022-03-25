/*
 * Copyright 2019, Data61, CSIRO (ABN 41 687 119 230)
 *
 * SPDX-License-Identifier: GPL-2.0-only
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

#define DEVICE_NAME_REGISTER_OFFSET 2
#define DEVICE_NAME_MAX_LEN 50
typedef struct connector_dev_node {
    struct pci_dev *dev;
    struct uio_info *uio;
    char dev_name[DEVICE_NAME_MAX_LEN];
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
    uint32_t *event_bar;
    int last_bar = -1;
    int err = 0;
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
        uio->mem[i].memtype = UIO_MEM_IOVA;

        last_bar = i;
    }

    /* We assume the event bar BAR0 always exists, even if the PCI device does
     * not use events. */
    if (err || last_bar < 0) {
        goto unmap_bars;
    }

    printk("Event Bar (dev-%d) initialized\n", current_free_dev);

    /* Register our IRQ handler */
    uio->irq = dev->irq;
    uio->irq_flags = IRQF_SHARED;
    uio->handler = connector_event_handler;

    connector->uio = uio;
    connector->dev = dev;
    event_bar = uio->mem[0].internal_addr;
    strncpy(connector->dev_name, (char *)&event_bar[DEVICE_NAME_REGISTER_OFFSET], DEVICE_NAME_MAX_LEN);
    uio->name = connector->dev_name;
    uio->version = "0.0.1";

    if (uio_register_device(&dev->dev, uio)) {
        goto unmap_bars;
    }

    printk("%d Dataports (dev-%d) initialized\n", last_bar, current_free_dev);
    pci_set_drvdata(dev, uio);
    devices[current_free_dev++] = connector;

    return 0;
unmap_bars:
    for (i = 0; i <= last_bar; i++) {
        iounmap(uio->mem[i].internal_addr);
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
