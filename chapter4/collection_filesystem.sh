#!/bin/bash

#collect artifiacts
mkdir artifacts


#list of entire directories you wish to collect
declare -a directories=(
	#list dirs to collect here. Don't include a slash at the end of the dir
	"/var/audit"
)

#list of files you want to collect at the privileged level
declare -a files=(
	"/var/log/system.log"
	"/var/log/accountpolicy.log"
	"/var/log/apache2/access_log"
	"/var/log/apache2/error_log"
	"/var/log/opendirectoryd.log"
	"/var/log/secinitd"
	"/var/log/wifi.log"
	"/var/log/alf.log"
	"/var/log/appstore.log"
	"/var/log/authd.log"
	"/var/log/commerce.log"
	"/var/log/hdiejectd.log"
	"/var/log/install.log"
	"/Library/Preferences/SystemConfiguration/com.apple.airport.preferences.plist"
	"/private/etc/kcpassword" 
	"/private/etc/sudoers"
	"/private/etc/hosts" 
	"/private/etc/resolv.conf"
	"/private/var/log/fsck_hfs.log"
	"/private/var/db/launchd.db/com.apple.launchd/overrides.plist" 
	"/Library/Logs/AppleFileService/AppleFileServiceError.log"
	"/var/log/appfirewall.log"
	"/etc/profile"
	"/etc/bashrc"
)

#list the files at the user level you want to collect here
declare -a userFiles=(
	#these are user files paths without the ~ at the beginning. The home directories will be concated later
	"Library/Preferences/com.apple.finder.plist"
	"Library/Preferences/com.apple.recentitems.plist"
	"Library/Preferences/com.apple.loginitems.plist"
	"Library/Logs/DiskUtility.log"
	"Library/Preferences/com.apple.LaunchServices.QuarantineEventsV2"
	".bash_history"
	".profile"
	".bash_profile"
	".bash_login"
	".bash_logout"
	".bashrc"
)

#Collect parsed Apple System Logs with UTC timestamps
syslog -T UTC > artifacts/appleSystemLogs.txt

#collect dirs
for x in "${directories[@]}"
do
	dirname=`echo "$x" | awk -F "/" '{print $NF}'`
	echo created "$dirname" from "$x"
	mkdir artifacts/"$dirname"
	ditto "$x" artifacts/"$dirname"
done

#collect privileged files
for x in "${files[@]}"
do
	ditto "$x"* artifacts
done

#collect user files for each user
dscl . -ls /Users | egrep -v ^_ | while read user 
do
	for x in "${userFiles[@]}"
	do
		fileLocation="/Users/$user/$x"
		echo "Trying to ditto $fileLocation"
		if [ -f $fileLocation ]; then
			ditto "$fileLocation"* artifacts
		fi
	done
done
