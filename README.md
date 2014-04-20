How to install Touch on your device
===================================

1. Download the generic tar.gz and the device-specific zip-files above.
2. If you don't have unlocked your bootloader yet, go to unlockbootloader.sonymobile.com and unlock it while you are waiting for the downloads to finish. (This will make a factory reset, so make a backup of your data first)
3. The generic ubuntu-part is installed onto a second partition on the SD-Card (ext4), that you have to create first. You can do this with a linux computer, but make a backup of your data first. The partition has to be at least 2GB, better more.
3a. If you don't have linux, you can download another kernel for your device, which contains a non-modified version of CWM and flash it with "fasboot flash boot /path/to/boot.img. Then under advanced -> partition sd-card you can create a new ext4 partition, but use 2048M or 4096M, because ubuntu takes a lot of space. !WARNING!, using this method deletes all data you have on your sd-card, make a backup first.
4. unpack the boot.img from your downloaded zip containing the device-specific part and flash it using fastboot: type in terminal "fastboot flash boot /path/to/extracted/boot.img" and then "sudo fastboot reboot", the device should boot and during boot when the led turns on click volume up several times to get into the recovery mode. Choose "mounts and storage" and in the next menu "mount data". Don't try to turn off the device now.
5. Connect your device to computer through usb and install/download adb tool if you don't have it.
6. Download the script to deploy the image, type "git clone <TODO: DANWIN YOU HAVE TO PASTE HERE THE URL OF THE REPO>", then after it's done type "cd image-installer" and then "./install.sh <path to downloaded tar.gz> <path to extracted system.img from device-specific zip>". This script will prepare and push the system image into the sdcard using adb tool. Pushing the image can take a long time, for me it was about 20 minutes.
7. When the script is done, you can reboot your device.

But not everything is working so you'll have a black screen. 

Of course any developers are welcome, that can help to get this port really booting.

Source changes are uploaded to https://github.com/DanWin
