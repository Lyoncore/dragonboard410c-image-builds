#!/bin/bash
#
# Copyright (C) 2017 Canonical Ltd
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 3 as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
set -ex

if [ "$(id -u)" -ne 0 ] ; then
    echo "ERROR: needs to be executed as root"
    exit 1
fi

if [ -z "$3" ]; then
    echo "usage: $0 <kernel snap> <core snap name> <kernel snap name>"
    echo "For instance: $0 link-sbc-apq8064-kernel_3.4.0_armhf.snap core_2111.snap link-sbc-apq8064-kernel_x1.snap"
    echo "Core and kernel snap names must be the same as the filename in the userdata image"
    exit 1
fi

# $1 -> core snap name
# $2 -> kernel snap name
# $3 -> image name
# $4 -> additional content for kernel command line
create_image()
{
    local core_snap_cmdline=$1
    local kernel_snap_cmdline=$2
    local img=$3
    local add_cmdline=$4

    local boot_cmdline="snap_core=$core_snap_cmdline snap_kernel=$kernel_snap_cmdline debug=vc root=LABEL=writable init=/lib/systemd/systemd panic=-1 apparmor=0 security= rw rootwait console=tty0 console=ttyMSM0,115200n8 $add_cmdline"

    skales-mkbootimg --kernel="$workdir"/zImage --ramdisk="$workdir"/initrd.img --base=0x80000000 --output="$workdir/$img.img" --cmdline="$boot_cmdline" --ramdisk_base='0x84000000' --dt="$workdir"/dt.img

    cp "$workdir/$img.img" "$output/dragonboard-$img-$(date --utc +%Y%m%d%H%M).img"
}

# $1 -> core snap name
# $2 -> kernel snap name
# $3 -> image name
create_systemboot_image()
{
    local core_snap_cmdline=$1
    local kernel_snap_cmdline=$2
    local img=$3
    local img_size=256M

    truncate -s $img_size "$workdir/$img.img"
    mkfs.fat "$workdir/$img.img"
    mkdir -p "$workdir/system-boot"
    mount "$workdir/$img.img" "$workdir/system-boot"

    # copy kernel snap
    mkdir -p "$workdir/system-boot/$kernel_snap_cmdline"
    cp "$workdir"/initrd.img "$workdir/system-boot/$kernel_snap_cmdline"
    cp "$workdir"/snap/kernel.img "$workdir/system-boot/$kernel_snap_cmdline"
    cp -R "$workdir"/snap/dtbs "$workdir/system-boot/$kernel_snap_cmdline"

    # preserve a orig kernel snap
    orig_kernel_snap_cmdline=$(echo $kernel_snap_cmdline | sed 's/\.[^.]*$/_orig&/')
    mkdir -p "$workdir/system-boot/$orig_kernel_snap_cmdline"
    cp "$workdir"/initrd.img "$workdir/system-boot/$orig_kernel_snap_cmdline"
    cp "$workdir"/snap/kernel.img "$workdir/system-boot/$orig_kernel_snap_cmdline"
    cp -R "$workdir"/snap/dtbs "$workdir/system-boot/$orig_kernel_snap_cmdline"

    # generate uboot env
    sed -i "s/snap_core=[[:alnum:]_.-]*[^\$]/snap_core=$core_snap_cmdline/" "$datadir"/gadget/uboot.env.in
    sed -i "s/snap_orig_core=[[:alnum:]_.-]*[^\$]/snap_orig_core=$core_snap_cmdline/" "$datadir"/gadget/uboot.env.in
    sed -i "s/snap_kernel=[[:alnum:]_.-]*[^\$]/snap_kernel=$kernel_snap_cmdline/" "$datadir"/gadget/uboot.env.in
    sed -i "s/snap_orig_kernel=[[:alnum:]_.-]*[^\$]/snap_orig_kernel=$orig_kernel_snap_cmdline/" "$datadir"/gadget/uboot.env.in
    mkenvimage -r -s 131072  -o "$workdir/system-boot/uboot.env" "$datadir"/gadget/uboot.env.in

    umount "$workdir/system-boot"

    fatlabel "$workdir/$img.img" "system-boot"

    cp "$workdir/$img.img" "$output/dragonboard-$img-$(date --utc +%Y%m%d%H%M).img"
}

datadir=$(pwd)
workdir=$(mktemp -d)
output=$(pwd)

core_snap="$2"
kernel_snap="$3"

cp "$1" "$workdir/$kernel_snap"

# Get explicitly core snap version as an argument for the moment
#channel="edge"
#core_snap_revision=`curl -H "X-Ubuntu-Series: 16" -H "X-Ubuntu-Architecture: armhf" https://search.apps.ubuntu.com/api/v1/snaps/details/ubuntu-core?channel=$channel | jq .revision`
#core_snap_revision=$2

mkdir "$workdir"/snap
mount -o loop "$workdir/$kernel_snap" "$workdir"/snap

cp "$workdir"/snap/kernel.img "$workdir"/zImage

mkdir "$workdir"/initrd
# Expect kernel initrd compressed by lz
(cd "$workdir"/initrd ; lzcat "$workdir"/snap/initrd.img | cpio -i)

# Copy new files
cp "$datadir"/scripts/bootloader-script "$workdir"/initrd/scripts/
cp "$datadir"/bin/* "$workdir"/initrd/usr/bin/
cp "$datadir"/etc/fw_env.config "$workdir"/initrd/etc/

(cd "$workdir"/initrd ; find . -print0 | sudo cpio --null -ov --format=newc \
     | gzip -9 > "$workdir"/initrd.img)

# Create device tree image by skales tool
skales-dtbtool -v -o "$workdir"/dt.img "$workdir"/snap/dtbs

# Create recovery image, which boots to Ubuntu Core (no extra kernel cmdline in this case)
create_image "$core_snap" "$kernel_snap" recovery ""

# Create system-boot image (use for upgrade/revert recovery partition)
create_systemboot_image "$core_snap" "$kernel_snap" systemboot

umount "$workdir"/snap
rm -rf "$workdir"