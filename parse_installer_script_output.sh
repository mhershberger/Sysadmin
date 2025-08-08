#!/bin/zsh

# Usage: parse_installer_script_output.sh [log_path]
# If log_path is not specified, the default path of /var/log/install.log will be used.

LOGPATH=/var/log/install.log
if [[ "$1" != '' ]]; then
	if [[ -f "$1" ]]; then
		LOGPATH="$1"
	else
		echo "Error: file '$1' does not exist" >&2
		exit 1
	fi
fi

zgrep -E '.*installer.*: Product archive.*' "$LOGPATH" | while read starting_line; do
	pkg_path=$(echo "$starting_line" | awk -F'Product archive ' '{print $2}' | awk -F' trustLevel' '{print $1}')
	echo "Output from $pkg_path:"
	pkg_name=$(grep --only-matching '[^/]*\.pkg' <<< "$pkg_path")

	installer_log_data=$(
		tail -r "$LOGPATH" | 
		fgrep -m 1 -B 99999 -i "$starting_line" |
		tail -r
	)
	
	installer_pid=$(
		echo ${installer_log_data} | 
		head -n 1 | 
		sed -E 's/.*installer\[([0-9]+)\].*/\1/'
	)
	
	temporary_directory=$(
		echo ${installer_log_data} | 
		grep -m 1 --only-matching "installer\[$installer_pid\]: Create temporary directory .*" |
		cut -d \" -f 2
	)
	
	installd_pid=$(
		echo ${installer_log_data} | 
		fgrep -m 1 "PKInstallDaemonClient pid=${installer_pid}," | 
		sed -E 's/.*installd\[([0-9]+)\].*/\1/'
	)
	
	installer_log_data=$(echo $installer_log_data |
		fgrep -m 1 -B 99999 "installer[$installer_pid]: Removing temporary directory \"$temporary_directory\""
	)
	
	sandbox_path=$(
		echo ${installer_log_data} | 
		fgrep -m 1 "installd[${installd_pid}]: PackageKit (package_script_service): Preparing to execute script" | 
		awk '{print $NF}' |
		sed 's|/private||'
	)
	
	package_script_service_pid=$(
		echo ${installer_log_data} | 
		grep -E 'package_script_service\[\d+\]: PackageKit: Preparing to execute script' |
		fgrep -m 1 "${sandbox_path}" | 
		sed -E 's/.*package_script_service\[([0-9]+)\].*/\1/'
	)
	
	pss="package_script_service[${package_script_service_pid}]:"
	echo ${installer_log_data} | \
		fgrep "$pss" | \
		fgrep -e "$pss PackageKit: Executing script " -e "$pss ./" | \
		sed -E "s|.*package_script_service[^[:space:]]+: \./||"
	
	echo ''
	echo ''
done
