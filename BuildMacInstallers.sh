#!/bin/bash

# This is a script for creating dual-booting OS X installer USB sticks, so you can
# install either Sierra or High Sierra as needed. This requires a 16GB or larger drive.
# It will create three partitions: "Sierra", "High Sierra", and "Scratch". Scratch will
# fill the remaining available space on the disk after the two installers, which use over
# 10GB together.
#
# The volumes will be renamed 'Sierra' and 'High Sierra', and given custom icons. Finally,
# The newly-created installers will be re-blessed so the changes to names and icons are
# properly reflected in the EFI bootloader.
#
# This will, of course, erase the entire drive!

sierrapath=/Applications/Install\ macOS\ Sierra.app
highsierrapath=/Applications/Install\ macOS\ High\ Sierra.app

function printUsage {
	echo '
Usage:
    BuildMacInstallers.sh <device>
    BuildMacInstallers.sh <volume>
    
The first form takes a device such as /dev/diskN, where N is the number of the drive. 
The second form takes a volume, such as /Volumes/Untitled.

Both forms will erase the ENTIRE drive, then create two new partitions.

This script requires that the Sierra and High Sierra installer apps be located in 
/Applications.

Note: you can either run this script as root (sudo BuildMacInstallers.sh ...) or not. If
not, you will need to enter your password multiple times since creating the installers
requires root and takes long enough for sudo authentication to time out.
'
	exit 2
}
if [ "$1" == '' ]; then
	printUsage
fi

if [[ "$1" == '/dev/disk'* ]]; then
	devicename="$1"
elif [[ "$1" == /Volumes/* ]]; then
	volname="$1"
	devicename=$(mount | grep '^/dev/disk[^[:space:]]* on \Q'"$volname"'\E (' | awk '{print $1}')
fi
#strip partition number from device name
devicename=$(echo "$devicename" | grep -o '^/dev/disk[[:digit:]]*')

# Verify valid device name format
if [[ ! "$devicename" == '/dev/disk'* ]]; then
	echo "Error: $1 does not appear to be a valid device or volume path."
	exit 1
fi

diskutil list "$devicename"
if [ "$?" != 0 ]; then # disk not found
	exit $?
fi
echo "All partitions will be permanently erased. This cannot be undone!"
read -p "Erase drive? y/n:" answer
if [ "$answer" == 'yes' -o "$answer" == 'y' ]; then
	echo "Erasing $devicename..."
else
	echo 'Aborted.'
	exit 1
fi 
echo "$answer"

# Create new partition map. This wipes the entire drive!
sudo diskutil partitionDisk $devicename 3 GPT jhfs+ Sierra 5300M jhfs+ 'High Sierra' 5500M jhfs+ 'Scratch' R
# Get mount points for new volumes (e.g. '/Volumes/Sierra').
mountpoint1=$(diskutil info "$devicename"s2 | grep '^   Mount Point:' | cut -c 30-)
mountpoint2=$(diskutil info "$devicename"s3 | grep '^   Mount Point:' | cut -c 30-)

# Install Sierra on partition 1
sudo "$sierrapath/Contents/Resources/createinstallmedia" --applicationpath "$sierrapath/" --volume "$mountpoint1" 

# Install High Sierra on partition 2
sudo "$highsierrapath/Contents/Resources/createinstallmedia" --applicationpath "$highsierrapath/" --volume "$mountpoint2"

# Rename volumes to be more concise
sudo diskutil rename "${devicename}s2" Sierra
sudo diskutil rename "${devicename}s3" High\ Sierra

# Get mount points again, since they might have changed
mountpoint1=$(diskutil info "$devicename"s2 | grep '^   Mount Point:' | cut -c 30-)
mountpoint2=$(diskutil info "$devicename"s3 | grep '^   Mount Point:' | cut -c 30-)

# Set icons of volumes to the slick product images from the installer.
# There's no terminal or AppleScript command, so we'll use Python's Cocoa bindings.
function setIcon {
	cp "$1" "$2/.VolumeIcon.icns"
	python -c 'import Cocoa; import sys; Cocoa.NSWorkspace.sharedWorkspace().setIcon_forFile_options_(Cocoa.NSImage.alloc().initWithContentsOfFile_(sys.argv[1].decode("utf-8")), sys.argv[2].decode("utf-8"), 0)' "$1" "$2"
}
setIcon "$sierrapath/Contents/Resources/ProductPageIcon.icns" "$mountpoint1"
setIcon "$highsierrapath/Contents/Resources/ProductPageIcon.icns" "$mountpoint2"

# Re-bless the boot volume, which update the name in the EFI bootloader. Otherwise it will
# still show as e.g. "Install macOS High Sierra" in the bootloader.
sudo bless --folder "$mountpoint1/.IABootFiles" --label Sierra
sudo bless --folder "$mountpoint2/.IABootFiles" --label 'High Sierra'