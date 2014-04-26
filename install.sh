#!/bin/sh
#
#  Copyright (c) 2014 Tomasz Kuczak
#
#  Author: Tomasz Kuczak <tomasz.ks9@gmail.com>
#  Original author: Oliver Grawert <ogra@canonical.com>
#
#  This program is free software; you can redistribute it and/or
#  modify it under the terms of the GNU General Public License as
#  published by the Free Software Foundation; either version 2 of the
#  License, or (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307
#  USA
#

DATAPART="/dev/block/mmcblk0p2" # Path to data partition on the device. You may want to change it if you use custom partitioning.

set -e

check_prereq()
{
	if [ ! $(which make_ext4fs) ] || [ ! -x $(which simg2img) ] || \
		[ ! -x $(which adb) ]; then
		echo "please install the android-tools-fsutils and android-tools-adb packages" && exit 1
	fi
}

do_shell()
{
	adb shell "$@"
}

convert_android_img()
{
	simg2img $SYSIMG $WORKDIR/system.img.raw
	mkdir $TMPMOUNT
	mount -t ext4 -o loop $WORKDIR/system.img.raw $TMPMOUNT
	make_ext4fs -l 120M $WORKDIR/system.img $TMPMOUNT >/dev/null 2>&1
}

prepare_ubuntu_system()
{
	mkdir $DATAPATH
	dd if=/dev/zero of=$DATAPATH/system.img seek=400K bs=4096 count=0 >/dev/null 2>&1
	mkfs.ext2 -F $DATAPATH/system.img >/dev/null 2>&1
	mkdir -p $WORKDIR/system
	mount -o loop $DATAPATH/system.img $WORKDIR/system/
}

cleanup()
{
	mount | grep -q $TMPMOUNT 2>/dev/null && umount $TMPMOUNT
	#cleanup_device
	rm -rf $WORKDIR
	echo
}

cleanup_device()
{
	[ -e $WORKDIR/device-clean ] && return
	cd $DIR # Without it the script is inside the image which prevents from unmounting it
	umount $WORKDIR/system/ 2>/dev/null && rm -rf $WORKDIR/system 2>/dev/null
	[ -e $WORKDIR ] && touch $WORKDIR/device-clean 2>/dev/null || true
}

trap cleanup 0 1 2 3 9 15

usage()
{
	echo "usage: $(basename $0) <path to rootfs tarball> <path to android system image> [options]\n
	options:
	-h|--help		this message"
	exit 1
}

if [ ! -z "$1" ]; then
	TARPATH=$1
else
	echo "missing rootfs tarball path"
	usage
fi
if [ ! -z "$2" ]; then
	SYSIMG=$(cd $(dirname $2); pwd)/$(basename $2)
else
	echo "missing path to android system image"
	usage
fi
DIR=$(cd -P -- "$(dirname -- "$0")" && pwd -P)

SUDOARGS="$@"

while [ $# -gt 0 ]; do
	case "$1" in
		-h|--help)
			usage
			;;
	esac
	shift
done

TARBALL=$(basename $TARPATH)

if [ -z "$TARBALL" ]; then
    echo "need valid rootfs tarball path"
    usage
fi

TARTYPE=$(file --mime-type $TARPATH|sed 's/^.* //')
case ${TARTYPE#application\/} in
    gzip|x-gzip)
	;;
    *)
	echo "Need valid rootfs tarball gzip type"
	usage
	;;
esac

if [ -z "$SYSIMG" ]; then
	echo "need valid path to android system image"
	usage
fi

[ $(id -u) -ne 0 ] && exec sudo $0 $SUDOARGS

check_prereq

adb kill-server # Be sure that adb is root so we can avoid permission problems
if ! adb devices | grep -q recovery; then
	echo "please make sure the device is attched via USB in recovery mode with Ubuntu Touch kernel installed"
	exit 1
fi

WORKDIR=$(mktemp -d /tmp/rootstock-touch-install.XXXXX)
TMPMOUNT="$WORKDIR/tmpmount"
DATAPATH="$WORKDIR/data"

echo -n "preparing system-image ... "
prepare_ubuntu_system
echo "[done]"

echo -n "unpacking rootfs tarball to system-image ... "
cd $WORKDIR/system && zcat $TARPATH | tar xf -
mkdir -p $WORKDIR/system/android/firmware
mkdir -p $WORKDIR/system/android/persist
mkdir -p $WORKDIR/system/userdata
[ -e $WORKDIR/system/SWAP.swap ] && mv $WORKDIR/system/SWAP.swap $DATAPATH/SWAP.img
for link in cache data factory firmware persist system; do
	cd $WORKDIR/system && ln -s /android/$link $link
done
cd $WORKDIR/system/lib && ln -s $WORKDIR/lib/modules modules
cd $WORKDIR/system && ln -s /android/system/vendor vendor
[ -e $WORKDIR/system/etc/mtab ] && rm $WORKDIR/system/etc/mtab
cd $WORKDIR/system/etc && ln -s /proc/mounts mtab
echo "[done]"

echo -n "copying modifications ... "
cp -r $DIR/modifications/* $WORKDIR/system/ >/dev/null 2>&1
echo "[done]"

echo -n "adding android system image to installation ... "
convert_android_img
ANDROID_DIR="$WORKDIR/system/var/lib/lxc/android/"
cp $WORKDIR/system.img $ANDROID_DIR >/dev/null 2>&1
echo "[done]"

echo -n "enabling Mir ... "
touch $WORKDIR/system/home/phablet/.display-mir
echo "[done]"

echo -n "Deploying the image ... "
cd $DIR
umount $WORKDIR/system
do_shell "mount -o loop -t ext4 $DATAPART /data"
do_shell "rm -f /data/system.img" >/dev/null 2>&1
for data in system android data user; do
	do_shell "rm -rf /data/$data-data" >/dev/null 2>&1
done
[ ! -z $DATAPATH/SWAP.img ] && adb push $DATAPATH/SWAP.img /data/
adb push $DATAPATH/system.img /data/ >/dev/null 2>&1
echo -n "[done]"

echo -n "cleaning up ... "
cleanup_device
echo "[done]"
