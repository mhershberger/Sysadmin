# Sysadmin
Scripts for system administration, mostly Mac.

**Spectre-Meltdown-status.sh** is a Casper/Jamf Pro extension attribute to show the Meltdown/Spectre patch status of macOS, Safari, Firefox, and Chrome. It will return, for example, "OS Patched, Safari Patched, Firefox Mainline Vulnerable, Chrome Vulnerable". It looks in /Applications for the presence of Firefox and Chrome, and checks whether Firefox is ESR (Extended Support Release) or mainline, comparing the version numbers with the patched versions.

**BuildMacInstallers.sh** is a shell script to automate creation of dual-booting USB sticks with both the Sierra and High Sierra installers. It takes either a device name (/dev/diskN) or volume name (/Volumes/something), then partitions the drive with `diskutil`, runs the `createinstallmedia` command, renames the created volumes, applies pretty icons to them using Cocoa APIs via Python, and properly blesses them so they look right in the EFI bootloader on Macs.
