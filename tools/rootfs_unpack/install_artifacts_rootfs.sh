#
# Copyright 2018, Data61
# Commonwealth Scientific and Industrial Research Organisation (CSIRO)
# ABN 41 687 119 230.
#
# This software may be distributed and modified according to the terms of
# the BSD 2-Clause license. Note that NO WARRANTY is provided.
# See "LICENSE_BSD2.txt" for details.
#
# @TAG(DATA61_BSD)
#

#!/bin/bash

OUTPUT_NAME=rootfs_out.cpio
OUTPUT_DIR=out

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

usage() {
    echo "Usage ./install_artifacts_rootfs.sh --mode=[overlay|fs_install|rootfs_install] --image=<path to rootfs/initrd file> \
--distro=[debian|buildroot] --root-install=<location of artifacts to install in rootfs> \
[--splitgz | --custom-init=<path to custom root init script> --output-image-name=<name of output image> --output-dir=<directory to output files to>]"
    exit 1
}

error_exit() {
    echo -e "$1">&2
    exit 1
}

gzip_rootfs_cpio() {
    echo -e "\e[1;96mGzipping rootfs cpio image\e[0m"
    pushd ${OUTPUT_DIR}
    gzip -k ${OUTPUT_NAME}
    popd
}

split_initrd() {
    echo -e "\e[1;96mExtracting gz image from initrd\e[0m"
    start=`grep -a -b -m 1 --only-matching '070701' $1 | head -1 | cut -f 1 -d :`
    end=`grep -a -b -m 1 --only-matching 'TRAILER!!!' $1 | head -1 | cut -f 1 -d :`
    # We assume the rootfs gzip file is found after the trailer
    # We round up to the next 512 byte multiple. ASSUMES the image was written in 512 byte multiples
    filename=$(basename $1)
    bs=$((end + 512 - (end % 512)))
    dd if=$1 bs=${bs} skip=1 of=${OUTPUT_DIR}/${filename}.gz
    dd if=$1 of=${OUTPUT_DIR}/header.cpio count=${bs} ibs=1
    gunzip -f ${OUTPUT_DIR}/${filename}.gz || error_exit "\e[0;31mUnable to unzip gz image\e[0m"
}

unpack_rootfs_cpio() {
    echo -e "\e[1;96mUnpacking rootfs cpio image: $1\e[0m"
    UNPACK_FILE=$1
    if [[ "$UNPACK_FILE" = *.gz ]]; then
        GUNZIP_FILE=${UNPACK_FILE##*/}
        gunzip -c ${UNPACK_FILE} > ${OUTPUT_DIR}/${GUNZIP_FILE::-3}
        UNPACK_FILE="../${GUNZIP_FILE%.gz}"
        echo -e "\e[1;96mUnzipped gz image to ${GUNZIP_FILE}\e[0m"
    fi
    mkdir -p ${OUTPUT_DIR}/unpack
    pushd ${OUTPUT_DIR}/unpack
    fakeroot cpio -id --no-preserve-owner --preserve-modification-time < ${UNPACK_FILE} || error_exit "\e[0;31mUnpacking CPIO failed\e[0m"
    popd
}

repack_rootfs_cpio() {
    echo -e "\e[1;96mRepacking rootfs cpio image\e[0m"
    pushd ${OUTPUT_DIR}/unpack
    find . -print0 | fakeroot cpio --null -H newc -o > ../${OUTPUT_NAME}
    echo -e "\e[1;96mCleaning unpack directory: ${OUTPUT_DIR}/unpack\e[0m"
    rm -r ${OUTPUT_DIR}/unpack
    popd
}

build_initrd() {
    echo -e "\e[1;96mRebuild initrd image\e[0m"
    gzip ${OUTPUT_DIR}/${OUTPUT_NAME} || error_exit "\e[0;31mUnable to gzip cpio image\e[0m"
    cat ${OUTPUT_DIR}/header.cpio ${OUTPUT_DIR}/${OUTPUT_NAME}.gz > ${OUTPUT_DIR}/${OUTPUT_NAME}
}

debian_setup() {
    echo -e "\e[1;96mConfiguring Debian/Ubuntu rootfs\e[0m"
    if [ $MODE == "rootfs_install" ]; then
        install_rootfs_artifacts
    elif [ $MODE == "overlay" ]; then
        install_fs_artifacts
        cp ${SCRIPT_DIR}/init_install_scripts/debian/overlay ${OUTPUT_DIR}/unpack/scripts/overlay || error_exit "\e[0;31mInstalling overlay failed\e[0m"
    else
        install_fs_artifacts
        cp ${SCRIPT_DIR}/init_install_scripts/debian/fs_install ${OUTPUT_DIR}/unpack/scripts/fs_install || error_exit "\e[0;31mInstalling fs_install failed\e[0m"
    fi
}

buildroot_setup() {
    echo -e "\e[1;96mConfiguring Buildroot rootfs\e[0m"
    if  [ "$MODE" != "rootfs_install" ]; then
        echo "${MODE} is unsupported for buildroot. Only 'rootfs_install' is supported"
        exit 1
    fi
    install_rootfs_artifacts
}

install_fs_artifacts() {
    echo -e "\e[1;96mInstalling build artifacts\e[0m"
    mkdir -p ${OUTPUT_DIR}/unpack/sel4_vm_artifacts
    if [[ -d $ROOT_INSTALL ]]; then
        cp -r ${ROOT_INSTALL}/* ${OUTPUT_DIR}/unpack/sel4_vm_artifacts/.
    else
        cp -r ${ROOT_INSTALL} ${OUTPUT_DIR}/unpack/sel4_vm_artifacts/.
    fi
    if [ ${CUSTOM_INIT+x} ]; then
        cp ${CUSTOM_INIT} ${OUTPUT_DIR}/unpack/init
    fi
}

install_rootfs_artifacts() {
    echo -e "\e[1;96mInstalling/Syncing build artifacts into rootfs\e[0m"
    if [[ ! -d $ROOT_INSTALL ]]; then
        echo "root-install needs to be a directory"
    fi
    rsync -a ${ROOT_INSTALL}/ ${OUTPUT_DIR}/unpack
}

for arg in "$@"
do
    case $arg in
        -m=*|--mode=*)
        MODE="${arg#*=}"
        if [ "$MODE" != "overlay" ] && [ "$MODE" != "fs_install" ] && [ "$MODE" != "rootfs_install" ]; then
            echo "Mode '${arg#*=}' is not supported"
            usage
        fi
        shift
        ;;
        -i=*|--image=*)
        IMAGE="${arg#*=}"
        shift
        ;;
        -r=*|--root-install=*)
        ROOT_INSTALL="${arg#*=}"
        shift
        ;;
        -d=*|--distro=*)
        DISTRO="${arg#*=}"
        if [ "$DISTRO" != "debian" ] && [ "$DISTRO" != "buildroot" ]; then
            echo "Distro '${arg#*=}' is not supported"
            usage
        fi
        shift
        ;;
        -c=*|--custom-init=*)
        CUSTOM_INIT="${arg#*=}"
        shift
        ;;
        -s=*|--splitgz)
        SPLIT=YES
        shift
        ;;
        -o=*|--output-image-name=*)
        OUTPUT_NAME="${arg#*=}"
        shift
        ;;
        -p=*|--output-dir=*)
        OUTPUT_DIR="${arg#*=}"
        shift
        ;;
        -z|--gzip)
        ZIP=YES
        shift
        ;;
        *)
            echo "Unknown argument: ${arg}"
            usage
        ;;
    esac
done

if [ -z ${MODE+x} ] || [ -z ${IMAGE+x} ] || [ -z ${DISTRO+x} ] || [ -z ${ROOT_INSTALL+x} ]; then
    usage
fi

echo "MODE=${MODE}"
echo "IMAGE=${IMAGE}"
echo "DISTRO=${DISTRO}"
echo "CUSTOM-INIT=${CUSTOM_INIT}"

mkdir -p ${OUTPUT_DIR}

if [ ${SPLIT+x} ]; then
    split_initrd ${IMAGE}
    CPIO=${OUTPUT_DIR}/`basename ${IMAGE}`
else
    CPIO=${IMAGE}
fi

unpack_rootfs_cpio ${CPIO}

if [ "$DISTRO" == "debian" ]; then
    debian_setup
else
    buildroot_setup
fi

repack_rootfs_cpio

if [ ${SPLIT+x} ]; then
    build_initrd
fi

if [ ${ZIP+x} ]; then
    gzip_rootfs_cpio
fi

OUTPUT=`pwd`/${OUTPUT_DIR}/rootfs_out.cpio

echo ${OUTPUT}
