#!/bin/bash

# Get major and minor revision from build number. 
# This is how we'll determine OS patch status.
buildver=$(/usr/bin/sw_vers -buildVersion)
major=${buildver:0:3}
minor=${buildver:3}

# Get Safari build number.
safariBuild=$(defaults read /Applications/Safari.app/Contents/Info.plist CFBundleVersion)

# Initialize result variables

osPatched=0
osHalfPatched_meltdown=0
safariPatched=0
firefoxPatched=0
chromePatched=0

firefoxInstalled=0
chromeInstalled=0

# Create a function to compare version components numerically (as opposed to alphabetically).
# e.g. 10.2 will come before 10.10. Usage: versionCompare x y 
# Returns -1 if x<y, 0 if x=0, and 1 if x>y
function versionCompare {
	python -c 'import sys, re; versionNum = lambda text: [int(s) if s.isdigit() else s for s in re.split("([0-9]+)", text)]; print cmp(versionNum(sys.argv[1]), versionNum(sys.argv[2]))' "$1" "$2"
}

# 17C205 *10.13.2 supplemental) and newer are patched. For 10.12 and 10.11, check Safari
if [[ "$major" > "17C" ]] || ( [[ "$major" = "17C" ]] && [ "$minor" -ge 204 ] ); then
	osPatched=1
	safariPatched=1
elif [[ "$(/usr/bin/sw_vers -productVersion)" == "10.12"* ]]; then
	system_profiler SPInstallHistoryDataType | grep 'Security Update 2018-001' > /dev/null
	if [ "$?" == 0 ]; then
		osHalfPatched_meltdown=1
	fi
	if [ $(versionCompare '12604.4.7.1.6' $safariBuild) -lt 1 ]; then
		safariPatched=1
	fi
elif [[ "$(/usr/bin/sw_vers -productVersion)" == "10.11"* ]]; then
	system_profiler SPInstallHistoryDataType | grep 'Security Update 2018-001' > /dev/null
	if [ "$?" == 0 ]; then
		osHalfPatched_meltdown=1
	fi
	if [ $(versionCompare '11604.4.7.1.6' $safariBuild) -lt 1 ]; then
		safariPatched=1
	fi
fi

# check Firefox version and whether it's ESR or Mainline.
# Note that this will only look in /Applications, not in the user's home folder.
if [ -d "/Applications/Firefox.app" ]; then
	firefoxInstalled=1
    Type=$(awk -F'-' '/SourceRepository/{print $NF}' /Applications/Firefox.app/Contents/Resources/application.ini)
fi
case "$Type" in
    esr*)
    ff="ESR" ;;
    release)
    ff="Mainline" ;;
    *)
    ff="Unknown" ;;
esac
ffversion=`defaults read /Applications/Firefox.app/Contents/Info.plist CFBundleShortVersionString`
if [ $ff = 'ESR' ]; then
	if [ $(versionCompare '52.6.0' "$ffversion") -lt 1 ]; then
		firefoxPatched=1
	fi
elif [ $ff = 'Mainline' ]; then
	if [ $(versionCompare '57.0.4' "$ffversion") -lt 1 ]; then
		firefoxPatched=1
	fi
fi

# check Chrome
if [ -d "/Applications/Google Chrome.app" ]; then
	chromeInstalled=1
	chromeVersion=`defaults read /Applications/Google\ Chrome.app/Contents/Info.plist CFBundleShortVersionString`
	if [ $(versionCompare 64 "$chromeVersion") -lt 1 ]; then
		chromePatched=1
	fi
fi

# Spit out results for all installed components.
echo -n '<result>'
if [ $osPatched = 1 ]; then
	echo -n "${prefix}OS Patched"
elif [ $osHalfPatched_meltdown = 1 ]; then
	echo -n "${prefix}OS Meltdown-Patched, OS Spectre-Vulnerable"
else
	echo -n "${prefix}OS Vulnerable"
fi
prefix=', '
if [ $safariPatched = 1 ]; then
	echo -n "${prefix}Safari Patched"
else
	echo -n "${prefix}Safari Vulnerable"
fi
if [ $firefoxPatched = 1 ]; then
	echo -n "${prefix}Firefox $ff Patched"
elif [ "$firefoxInstalled" = 1 ]; then
	echo -n "${prefix}Firefox $ff Vulnerable"
fi
if [ $chromePatched = 1 ]; then
	echo -n "${prefix}Chrome Patched"
elif [ "$chromeInstalled" = 1 ]; then
	echo -n "${prefix}Chrome Vulnerable"
fi

echo '</result>'

