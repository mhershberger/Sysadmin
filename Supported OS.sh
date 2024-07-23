#!/bin/zsh
version='1.1.3'
# Usage: 'Supported OS.sh' [--verbose ...] [--model <MODEL_ID>] [--device <DEVICE_ID>] [--bridge <BRIDGE_MODEL>] [--board <BOARD_ID]
#
# This script will return the supported OS versions for the local machine, based
# on Apple's data from https://gdmf.apple.com/v2/pmv. By default, it will
# download it with /usr/bin/curl. Optionally, you may provide the JSON data in
# the GDMF_PMV_JSON environment variable, or paste it into the script below.
# 
# Apple's data may include multiple minor versions for each major OS release, 
# but does NOT include all historical minor releases.
# 
# Apple uses four identifiers for hardware models:
# 1. Model ID, e.g. "MacPro1,1". All Macs have model IDs.
# 2. Board ID, e.g. "Mac-F4208DC8". All Intel Macs have board IDs.
# 3. Bridge ID, e.g. "J680AP". T2-equipped Intel Macs have bridge IDs
# 4. Device ID, e.g. "J316cAP". Apple Silicon Macs have Device IDs.
# 
# These different IDs are all used in Apple's compatibility list. Some models
# are listed by multiple ID types.
# 
# Since 3 and 4 are mutually exclusive, they are sometimes considered the same.
# I only make the distinction because the name and location of the IDs are
# different in ioreg.
# 
# All of these values can be returned from the ioreg command. Some can more
# easily be extracted with sysctl as well. Note that `sysctl -a` will NOT
# display all properties, despite what the man page claims. Note also that ioreg
# will return different properties depending on the output format you choose,
# while the documentation makes no indication of this behavior.
# 
# Special shoutout to Pico Mitchell and Joel Bruner, who've made similar scripts
# using slightly different methods. All are useful for reference, and some may
# be better for your needs. See:
# 
# https://gist.github.com/PicoMitchell/877b645b113c9a5db95248ed1d496243#file-get_compatible_macos_versions-asls-sh
# https://gist.github.com/PicoMitchell/877b645b113c9a5db95248ed1d496243#file-get_compatible_macos_versions-sucatalog-sh
# https://www.brunerd.com/blog/2022/12/09/determining-eligible-macos-versions-via-script/
print_help() {
cat <<EOF
SYNOPSIS: 
	zsh 'Supported OS.sh' [--verbose ...] [--model <MODEL_ID>] [--device <DEVICE_ID>] [--bridge <BRIDGE_MODEL>] [--board <BOARD_ID]
EOF
}

# Optionally hardcode JSON data from https://gdmf.apple.com/v2/pmv below.
# Alternatively, pass the data in the GDMF_PMV_JSON environment variable.
# If neither is provided, the script will attempt to download it with /usr/bin/curl
json=${GDMF_PMV_JSON:-''} 

verbosity=0
for ((i = 1 ; i <= ${#@} ; i++ )); do 
	arg="${@[$i]}"
	case "$arg" in
	 --model) 
		shift
		readonly MODEL_ID="${@[$i]}"
		;;
	--device) 
		shift
		readonly DEVICE_ID="${@[$i]}"
		;;
	--bridge) 
		shift
		readonly BRIDGE_MODEL="${@[$i]}"
		;;
	--board) 
		shift
		readonly BOARD_ID="${@[$i]}"
		;;
	--verbose)
		(( verbosity++ ))
		;;
	--help)
		;;
	esac
done
log_output() {
	[[ "$verbosity" -ge "$1" ]] && echo "$(date -Iseconds): ${@:1}" >&3
}
exec 3>&1
trap 'exec 3>&-' EXIT
log_output 1 "Verbosity: $verbosity"

get_supported_os_list() {
current_os=$(sw_vers -productVersion)
log_output 1 "Current OS: $current_os"
if [[ "${current_os%%.*}" < 11 ]]; then
	# Only supported on macOS 11 Big Sur and later
	return 1
fi

# Set constants for comparing against hw.machine value
readonly ARM='arm64'
readonly X86='x86_64'

# Get CPU architecture. Either arm64 (Apple Silicon) or x86_64 (Intel)
[[ -z "$ARCHITECTURE" ]] && readonly ARCHITECTURE=$(sysctl -n hw.machine)
log_output 1 "Architecture: $ARCHITECTURE"

# Retrieve model ID (same on all Macs)
[[ -z "$MODEL_ID" ]] && readonly MODEL_ID="$(sysctl -n hw.model)"
log_output 1 "Model ID: $MODEL_ID"

# Retrieve device ID on Apple Silicon Macs
if [[ $ARCHITECTURE == $ARM ]]; then
	# Retrieve "compatible" field and decode it from base64
	compatible_decoded="$(
		ioreg -a -d1 -r -c IOPlatformExpertDevice | \
		xmllint --xpath '/plist/array/dict/key[text()="compatible"]/following-sibling::data[1]/text()' - 2>/dev/null | \
		base64 -d 
	)"
	# This returns a null-delimited list of strings. Convert that into a zsh array
	compatible_array=(${(ps:\0:)compatible_decoded})
	log_output 2 "Compatible array: $compatible_array"
	
	# extract the first element from the array
	[[ -z "$DEVICE_ID" ]] && readonly DEVICE_ID="${compatible_array[1]}"
	log_output 1 "Device ID: $DEVICE_ID"
fi

# Retrieve board ID and, if present, bridge ID on Intel Macs
if [[ $ARCHITECTURE == $X86 ]]; then
	# Retrieve "IOPlatformExpertDevice" object, then get both the "board-id" and "bridge-model"
	io_platform=$(ioreg -a -d1 -r -c IOPlatformExpertDevice)
	[[ -z "$BOARD_ID" ]] && readonly BOARD_ID="$(
		echo "${io_platform}" | \
		xmllint --xpath '/plist/array/dict/key[text()="board-id"]/following-sibling::data[1]/text()' - 2>/dev/null | \
		base64 -d | tr -d '\0'
	)"
	log_output 1 "Board ID: $BOARD_ID"
	[[ -z "$BRIDGE_MODEL" ]] && readonly BRIDGE_MODEL="$(
		echo "${io_platform}" | \
		xmllint --xpath '/plist/array/dict/key[text()="bridge-model"]/following-sibling::data[1]/text()' - 2>/dev/null | \
		base64 -d | tr -d '\0'
	)"
	log_output 1 "Bridge model: $BRIDGE_MODEL"
fi

if [[ "${json}" == '' ]]; then
	# Download fresh JSON data from https://gdmf.apple.com/v2/pmv
	log_output 2 "Downloading JSON..."
	json=$(/usr/bin/curl --no-progress-meter 'https://gdmf.apple.com/v2/pmv')
	curl_result=$?
	# There are a million reasons curl might fail. Bail if it did.
	log_output 1 "Downloaded JSON length: ${#json}"
	if [[ $curl_result != 0 ]]; then exit $curl_result; fi
fi

ID_LIST=$(print $MODEL_ID $DEVICE_ID $BOARD_ID $BRIDGE_MODEL)
log_output 2 "Collected ID list: $ID_LIST"

# macOS lacks good tools for parsing JSON. Use osascript to parse it using JavaScript.
# Note that Apple does not use consistent capitalization in their IDs within the PMV, so
# it is necessary to compare using toLowerCase() or similar in JavaScript.
js_code="$(cat << EOF 
let args = $.NSProcessInfo.processInfo.arguments; 
let jsonString = ObjC.unwrap(args.objectAtIndex(4)); 
let jsonObject = JSON.parse(jsonString); 
let idList = ObjC.unwrap(args.objectAtIndex(5)).split(' '); 

let matches = jsonObject.AssetSets.macOS.filter(macos => idList.some(localId => macos.SupportedDevices.find(jsonId => localId.toLowerCase() === jsonId.toLowerCase())));
let versions = matches.map(macos => macos.ProductVersion);
versions.join('\n');
EOF
)"
# Pass the JSON and the space-delimited list of IDs. The JS will return a list of 
# version numbers that match at least one of the IDs passed. 
print -r $js_code | osascript -l JavaScript - "$json" "$ID_LIST" | sort -V 
} # end of encompassing get_supported_os_list() function
echo -n '<result>'
get_supported_os_list | sed 's/^/"/; s/$/"/'
echo '</result>'
