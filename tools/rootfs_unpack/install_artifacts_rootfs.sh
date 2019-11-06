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
    printf "Usage ./install_artifacts_rootfs.sh --mode=[overlay|fs_install|rootfs_install] --image=<path to rootfs/initrd file> \
--distro=[debian|buildroot] --root-install=<location of artifacts to install in rootfs> \
[--splitgz | --custom-init=<path to custom root init script> --output-image-name=<name of output image> --output-dir=<directory to output files to>]"
    exit 1
}

error_exit() {
    printf "$1\n">&2
    exit 1
}

gzip_rootfs_cpio() {
    printf "$(tput setaf 6)$(tput bold)Gzipping rootfs cpio image$(tput sgr0)\n"
    pushd ${OUTPUT_DIR}
    gzip -kf ${OUTPUT_NAME}
    popd
}

split_initrd() {
    printf "$(tput setaf 6)$(tput bold)Extracting gz image from initrd$(tput sgr0)\n"
    start=`grep -a -b -m 1 --only-matching '070701' $1 | head -1 | cut -f 1 -d :`
    end=`grep -a -b -m 1 --only-matching 'TRAILER!!!' $1 | head -1 | cut -f 1 -d :`
    # We assume the rootfs gzip file is found after the trailer
    # We round up to the next 512 byte multiple. ASSUMES the image was written in 512 byte multiples
    filename=$(basename $1)
    bs=$((end + 512 - (end % 512)))
    dd if=$1 bs=${bs} skip=1 of=${OUTPUT_DIR}/${filename}.gz
    dd if=$1 of=${OUTPUT_DIR}/header.cpio count=${bs} ibs=1
    gunzip -f ${OUTPUT_DIR}/${filename}.gz || error_exit "$(tput setaf 1)$(tput bold)Unable to unzip gz image$(tput sgr0)\n"
}

unpack_rootfs_cpio() {
    printf "$(tput setaf 6)$(tput bold)Unpacking rootfs cpio image: $1$(tput sgr0)\n"
    UNPACK_FILE=$1
    if [[ "$UNPACK_FILE" = *.gz ]]; then
        GUNZIP_FILE=${UNPACK_FILE##*/}
        gunzip -c ${UNPACK_FILE} > ${OUTPUT_DIR}/${GUNZIP_FILE::-3}
        UNPACK_FILE="../${GUNZIP_FILE%.gz}"
        printf "$(tput setaf 6)$(tput bold)Unzipped gz image to ${GUNZIP_FILE}$(tput sgr0)\n"
    fi
    mkdir -p ${OUTPUT_DIR}/unpack
    pushd ${OUTPUT_DIR}/unpack
    fakeroot cpio -id --no-preserve-owner --preserve-modification-time < ${UNPACK_FILE} || error_exit "$(tput setaf 1)$(tput bold)Unpacking CPIO failed$(tput sgr0)\n"
    popd
}

repack_rootfs_cpio() {
    printf "$(tput setaf 6)$(tput bold)Repacking rootfs cpio image$(tput sgr0)\n"
    pushd ${OUTPUT_DIR}/unpack
    find . -print0 | fakeroot cpio --null -H newc -o > ../${OUTPUT_NAME}
    printf "$(tput setaf 6)$(tput bold)Cleaning unpack directory: ${OUTPUT_DIR}/unpack$(tput sgr0)\n"
    rm -r ${OUTPUT_DIR}/unpack
    popd
}

build_initrd() {
    printf "$(tput setaf 6)$(tput bold)Rebuild initrd image$(tput sgr0)\n"
    gzip ${OUTPUT_DIR}/${OUTPUT_NAME} || error_exit "$(tput setaf 1)$(tput bold)Unable to gzip cpio image$(tput sgr0)\n"
    cat ${OUTPUT_DIR}/header.cpio ${OUTPUT_DIR}/${OUTPUT_NAME}.gz > ${OUTPUT_DIR}/${OUTPUT_NAME}
}

debian_setup() {
    printf "$(tput setaf 6)$(tput bold)Configuring Debian/Ubuntu rootfs$(tput sgr0)\n"
    if [ $MODE == "rootfs_install" ]; then
        install_rootfs_artifacts
    elif [ $MODE == "overlay" ]; then
        install_fs_artifacts
        cp ${SCRIPT_DIR}/init_install_scripts/debian/overlay ${OUTPUT_DIR}/unpack/scripts/overlay || error_exit "$(tput setaf 1)$(tput bold)Installing overlay failed$(tput sgr0)\n"
    else
        install_fs_artifacts
        cp ${SCRIPT_DIR}/init_install_scripts/debian/fs_install ${OUTPUT_DIR}/unpack/scripts/fs_install || error_exit "$(tput setaf 1)$(tput bold)Installing fs_install failed$(tput sgr0)\n"
    fi
}

buildroot_setup() {
    printf "$(tput setaf 6)$(tput bold)Configuring Buildroot rootfs$(tput sgr0)\n"
    if  [ "$MODE" != "rootfs_install" ]; then
        printf "${MODE} is unsupported for buildroot. Only 'rootfs_install' is supported"
        exit 1
    fi
    install_rootfs_artifacts
}

install_fs_artifacts() {
    printf "$(tput setaf 6)$(tput bold)Installing build artifacts$(tput sgr0)\n"
    mkdir -p ${OUTPUT_DIR}/unpack/sel4_vm_artifacts
    if [[ -d $ROOT_INSTALL ]]; then
        cp -r ${ROOT_INSTALL}/* ${OUTPUT_DIR}/unpack/sel4_vm_artifacts/.
    else
        cp -r ${ROOT_INSTALL} ${OUTPUT_DIR}/unpack/sel4_vm_artifacts/.
    fi
    if [ -n "$CUSTOM_INIT" ]; then
        cp ${CUSTOM_INIT} ${OUTPUT_DIR}/unpack/init
    fi
}

install_rootfs_artifacts() {
    printf "$(tput setaf 6)$(tput bold)Installing/Syncing build artifacts into rootfs$(tput sgr0)\n"
    if [[ ! -d $ROOT_INSTALL ]]; then
        printf "root-install needs to be a directory"
    fi
    rsync -a ${ROOT_INSTALL}/ ${OUTPUT_DIR}/unpack
}

for arg in "$@"
do
    case $arg in
        -m=*|--mode=*)
        MODE="${arg#*=}"
        if [ "$MODE" != "overlay" ] && [ "$MODE" != "fs_install" ] && [ "$MODE" != "rootfs_install" ]; then
            printf "Mode '${arg#*=}' is not supported\n"
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
            printf "Distro '${arg#*=}' is not supported\n"
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
            printf "Unknown argument: ${arg}\n"
            usage
        ;;
    esac
done

if [ -z "$MODE" ] || [ -z "$IMAGE" ] || [ -z "$DISTRO" ] || [ -z "$ROOT_INSTALL" ]; then
    usage
fi

printf "MODE=${MODE}\n"
printf "IMAGE=${IMAGE}\n"
printf "DISTRO=${DISTRO}\n"
printf "CUSTOM-INIT=${CUSTOM_INIT}\n"

mkdir -p ${OUTPUT_DIR}

if [ -n "$SPLIT" ]; then
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

if [ -n "$SPLIT" ]; then
    build_initrd
fi

if [ -n "$ZIP" ]; then
    gzip_rootfs_cpio
fi

OUTPUT=`pwd`/${OUTPUT_DIR}/rootfs_out.cpio

printf ${OUTPUT}
