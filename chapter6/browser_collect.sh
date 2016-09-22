echo "Copying browser data..."
browserfolder="browserHistory"
mkdir $browserfolder

dscl . -ls /Users | egrep -v ^_ | while read user 
do 
	#check for and copy Safari data
	#Safari is pretty much garenteed to be installed
	if [ -d  "/Users/$user/Library/Safari/" ]; then
		plutil -convert xml1 /Users/$user/Library/Safari/History.plist -o "$browserfolder/$user"_safariHistory.plist
		plutil -convert xml1 /Users/$user/Library/Safari/Downloads.plist -o "$browserfolder/$user"_safariDownloads.plist

		#grab the sqlite3 version of the history if you prefer
		ditto "/Users/$user/Library/Safari/Downloads.plist" "$browserfolder/$user"_safariDownloads.plist
	fi

	#check for and copy Chrome data
	if [ -d  "/Users/$user/Library/Application Support/Google/Chrome/" ]; then
		ditto "/Users/$user/Library/Application Support/Google/Chrome/Default/History" "$browserfolder/$user"_chromeHistory.db
	fi

	#check for and copy firefox data
	#there should only be one profile inside the Profiles directory
	if [ -d "/Users/$user/Library/Application Support/Firefox/" ]; then
		for PROFILE in /Users/$user/Library/Application\ Support/Firefox/Profiles/*; do
			ditto "$PROFILE/places.sqlite" "$browserfolder/$user"_firefoxHistory.db
		done
	fi

	#check for and copy Opera data
	if [ -d "/Users/$user/Library/Application Support/com.operasoftware.Opera/" ]; then
		ditto "/Users/$user/Library/Application Support/com.operasoftware.Opera/History" "$browserfolder/$user"_operaHistory.db
	fi
done