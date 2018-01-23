# Sysadmin
Scripts for system administration, mostly Mac.

**Spectre-Meltdown-status.sh** is a Casper/Jamf Pro extension attribute to show the Meltdown/Spectre patch status of macOS, Safari, Firefox, and Chrome. It will return, for example, "OS Patched, Safari Patched, Firefox Mainline Vulnerable, Chrome Vulnerable". It looks in /Applications for the presence of Firefox and Chrome, and checks whether Firefox is ESR (Extended Support Release) or mainline, comparing the version numbers with the patched versions.
