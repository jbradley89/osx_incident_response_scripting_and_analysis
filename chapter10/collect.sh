#!/bin/bash

#ensure that the script is being executed as root
if [[ $EUID -ne 0 ]]; then 
	echo 'Incident Response Script needs to be executed as root!'
	exit 1
fi

originalUser=`sh -c 'echo $SUDO_USER'`
echo "Collecting data as root escalated from the $originalUser account"

#insert company message here explaining the situation
cat << EOF

-----------------------------------------------------------------------
COLLECTING CRITICAL SYSTEM DATA. PLEASE DO NOT TURN OFF YOUR SYSTEM...
-----------------------------------------------------------------------

EOF

echo "Start time-> `date`"

#Create a pf rule to block all network access except for access to file server over ssh
quarentineRule=/etc/activeIr.conf
echo "Writing quarentine rule to $quarentineRule"
serverIP=192.168.1.111
cat > $quarentineRule << EOF
block in all
block out all
pass in proto tcp from $serverIP to any port 22
EOF

#load the pfconf rule and inform the user there is no internet access
pfctl -f $quarentineRule 2>/dev/null
pfctl -e 2>/dev/null
if [ $? -eq 0 ]; then
	echo "Quarentine Enabled. Internet access unavailable"
fi

echo "Running system commands..."

#set up variables
IRfolder=collection
logFile=$IRfolder/collectlog.txt

mkdir $IRfolder
touch $logFile

#redirect errors
exec 2> $logFile

systemCommands=$IRfolder/sysCalls

#create output directory
mkdir $systemCommands

#basic system info
systemInfo=$systemCommands/sysInfo.txt
#create file
touch $systemInfo

#echo ---command name to be used---; use command; append a blank line
echo ---date--- >> $systemInfo; date >> $systemInfo; echo >> $systemInfo
echo ---hostname--- >> $systemInfo; hostname >> $systemInfo; echo >> $systemInfo
echo ---uname -a--- >> $systemInfo; uname -a >> $systemInfo; echo >> $systemInfo
echo ---sw_vers--- >> $systemInfo; sw_vers >> $systemInfo; echo >> $systemInfo
echo ---nvram--- >> $systemInfo; nvram >> $systemInfo; echo >> $systemInfo
echo ---uptime--- >> $systemInfo; uptime >> $systemInfo; echo >> $systemInfo
echo ---spctl --status--- >> $systemInfo; spctl --status >> $systemInfo; echo >> $systemInfo
echo --bash --version--- >> $systemInfo; bash --version >> $systemInfo; echo >> $systemInfo

#collect who-based data
whoInfo=$systemCommands/whoInfo.txt
touch $whoInfo
echo ---ls -la /Users--- >> $whoInfo; ls -la /Users >> $whoInfo; echo >> $whoInfo
echo ---whoami--- >> $whoInfo; whoami >> $whoInfo; echo >> $whoInfo
echo ---who--- >> $whoInfo; who >> $whoInfo; echo >> $whoInfo
echo ---w--- >> $whoInfo; w >> $whoInfo; echo >> $whoInfo
echo ---last--- >> $whoInfo; last >> $whoInfo; echo >> $whoInfo

#collect user info
userInfo=$systemCommands/userInfo.txt
echo ---Users on this system--- >>$userInfo; dscl . -ls /Users >> $userInfo; echo >> $userInfo
#for each user
dscl . -ls /Users | egrep -v ^_ | while read user 
	do 
		echo *****$user***** >> $userInfo
		echo ---id \($user\)--- >>$userInfo; id $user >> $userInfo; echo >> $userInfo
		echo ---groups \($user\)--- >> $userInfo; groups $user >> $userInfo; echo >> $userInfo
		echo ---finger \($user\) --- >> $userInfo; finger -m $user >> $userInfo; echo >> $userInfo
		echo >> $userInfo
		echo >> $userInfo
		# find a way to provide printenv
	done

#Collect network-based info
networkInfo=$systemCommands/networkInfo.txt
touch $networkInfo
echo ---netstat--- >> $networkInfo; netstat >> $networkInfo; echo >> $networkInfo
echo ---netstat -ru--- >> $networkInfo; netstat -ru >> $networkInfo; echo >> $networkInfo
echo ---networksetup -listallhardwareports--- >> $networkInfo; networksetup -listallhardwareports >> $networkInfo; echo >> $networkInfo
echo ---lsof -i--- >> $networkInfo; lsof -i >> $networkInfo; echo >> $networkInfo
echo ---arp -a--- >> $networkInfo; arp -a >> $networkInfo; echo >> $networkInfo
echo security dump-trust-settings >> $networkInfo; security dump-trust-settings >> $networkInfo; echo >> $networkInfo

#collect process-based info
processInfo=$systemCommands/processInfo.txt
touch $processInfo
echo ---ps aux--- >> $processInfo; ps aux >> $processInfo; echo >> $processInfo
echo ---lsof--- >> $processInfo; lsof >> $processInfo; echo >> $processInfo

#collect startup-based info
startupInfo=$systemCommands/startupInfo.txt
touch $startupInfo
echo ---launchctl list--- >> $startupInfo; launchctl list >> $startupInfo; echo >> $startupInfo
echo ---atq--- >> $startupInfo; atq >> $startupInfo; echo >> $startupInfo
#crontab will be collected later from /usr/lib/cron/<usernames>

#collect driver-based info
driverInfo=$systemCommands/driverInfo.txt
touch $driverInfo
echo ---kextstat--- >> $driverInfo; kextstat >> $driverInfo; echo >>$driverInfo


#collect hard drive info
hardDriveInfo=$systemCommands/hardDriveInfo.txt
touch $hardDriveInfo
echo ---diskutil list--- >> $hardDriveInfo; diskutil list >> $hardDriveInfo; echo >>$hardDriveInfo
echo ---df -h--- >> $hardDriveInfo; df -h >> $hardDriveInfo; echo >> $hardDriveInfo
echo ---du -h--- >> $hardDriveInfo; du -h >> $hardDriveInfo; echo >> $hardDriveInfo

#Collecting file system data
#!/bin/bash

#collect artifiacts
mkdir artifacts

#collect the audit logs
#mkdir artifacts/audit
#ditto /var/audit artifacts/audit

declare -a directories=(
	#list dirs to collect here. Don't include a slash at the end of the dir
	"/var/audit"
)

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
	"/etc/kcpassword" 
	"/etc/sudoers"
	"/etc/hosts" 
	"/etc/resolv.conf"
	"/private/var/log/fsck_hfs.log"
	"/private/var/db/launchd.db/com.apple.launchd/overrides.plist" 
	"/Library/Logs/AppleFileService/AppleFileServiceError.log"
	"/var/log/appfirewall.log"

)

declare -a userFiles=(
	#these are user files paths without the ~ at the beginning. The home directories will be concated later
	"Library/Preferences/com.apple.finder.plist"
	"Library/Preferences/com.apple.recentitems.plist"
	"Library/Preferences/com.apple.loginitems.plist"
	"Library/Logs/DiskUtility.log"
	"Library/Preferences/com.apple.LaunchServices.QuarantineEventsV2"
)

#collect files
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

#collect dirs
for x in "${directories[@]}"
do
	dirname=`echo "$x" | awk -F "/" '{print $NF}'`
	echo created "$dirname" from "$x"
	mkdir artifacts/"$dirname"
	ditto "$x" artifacts/"$dirname"
done


#ASEP COLLECTION
echo "Collecting system ASEPS"
#the $IRfolder variable was assigned in our original script
ASEPS=$IRfolder/aseps
mkdir $ASEPS

ditto /System/Library/LaunchDaemons $ASEPS/systemLaunchDaemons
ditto /System/Library/LaunchAgents $ASEPS/systemLaunchAgents
ditto /Library/LaunchDaemons $ASEPS/launchDaemons
ditto /Library/LaunchAgents $ASEPS/launchAgents
#ditto <user entry>

#collect crontabs and set permissions so that the analyst can read the results
ditto /usr/lib/cron/tabs/ $ASEPS/crontabs; 

#collect at tasks
ditto /private/var/at/jobs/ $ASEPS/atTasks

#collect plist overrides
ditto /var/db/launchd.db $ASEPS/overrides;

#collect StartupItems
ditto /etc/rc* $ASEPS/
ditto /Library/StartupItems/ $ASEPS/
ditto /System/Library/StartupItems/ $ASEPS/systemStartupItems

#collect Login/Logout Hooks
ditto /private/var/root/Library/Preferences/com.apple.loginwindow.plist $ASEPS/loginLogouthooks

#collect launchd configs
#file may or may not exist
ditto /etc/launchd.conf $ASEPS/launchdConfs/

#copy user specific data for each user
dscl . -ls /Users | egrep -v ^_ | while read user
do
	ditto /Users/$user/Library/LaunchAgents $ASEPS/$user-launchAgents
	ditto /Users/$user/Library/Preferences/com.apple.loginitems.plist $ASEPS/$user-com.apple.loginitems.plist;
	ditto /Users/$user/.launchd.conf $ASEPS/launchdConfs/$user-launchd.conf
done

#copy kext files in the extension directories
ditto /System/Library/Extensions $ASEPS/systemExtensions
ditto /Library/Extensions $ASEPS/extensions

#create a function that will scan all files in a directory using codesign
codesignDirScan(){
	for filename in $1/*; do
        codesign -vv -d $filename &>tmp.txt;
        if grep -q "not signed" tmp.txt; then
                cat tmp.txt >> $ASEPS/unsignedKexts.txt
        fi
	done
	rm tmp.txt
}

#run a codesign scan on all kext files
codesignDirScan /System/Library/Extensions
codesignDirScan /Library/Extensions

#collect browser history
echo "Copying Web Data..."
dscl . -ls /Users | egrep -v ^_ | while read user 
do 
	#check for and copy Safari data
	#Safari is pretty much garenteed to be installed
	echo "Looking for /Users/$user/Library/Safari"
	if [ -d  "/Users/$user/Library/Safari/" ]; then
		plutil -convert xml1 /Users/$user/Library/Safari/History.plist -o "$user"_safariHistory.plist
		plutil -convert xml1 /Users/$user/Library/Safari/Downloads.plist -o "$user"_safariDownloads.plist
		#plutil -p "/Users/$user/Library/Safari/History.plist" > "$user"_safariHistory.plist
		#plutil -p "/Users/$user/Library/Safari/Downloads.plist" > "$user"_safariDownloads.plist

		#grab the sqlite3 version of the history if you prefer
		ditto "/Users/$user/Library/Safari/Downloads.plist" "$user"_safariDownloads.db
	fi

	#check for and copy Chrome data
	if [ -d  "/Users/$user/Library/Application Support/Google/Chrome/" ]; then
		ditto "/Users/$user/Library/Application Support/Google/Chrome/Default/History" "$user"_chromeHistory.db
	fi

	#check for and copy firefox data
	#there should only be one profile inside the Profiles directory
	if [ -d "/Users/$user/Library/Application Support/Firefox/" ]; then
		for PROFILE in /Users/$user/Library/Application\ Support/Firefox/Profiles/*; do
			ditto "$PROFILE/places.sqlite" "$user"_firefoxHistory.db
		done
	fi

	#check for and copy Opera data
	if [ -d "/Users/$user/Library/Application Support/com.operasoftware.Opera/" ]; then
		ditto "/Users/$user/Library/Application Support/com.operasoftware.Opera/History" "$user"_operaHistory.db
	fi
done

#create a zip file of all the data in the current directory
#this will always be the last thing we do. Do not add code below this section through this book
echo "Archiving Data"
cname=`scutil --get ComputerName | tr ' ' '_'`
now=`date +"_%Y-%m-%d"`
ditto -k --zlibCompressionLevel 5 -c . $cname$now.zip
