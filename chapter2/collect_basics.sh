#!/bin/bash

#create a folder where all collected data will go
IRfolder=collection
#ensure that the script is being executed as root
if [[ $EUID -ne 0 ]]; then 
	echo "Incident Response Script needs to be executed as root!" 
	exit 1
fi

sudo -k

#save which user executed the analysis script as we may need it later
originalUser=`sh -c 'echo $SUDO_USER'`
echo "Collecting data as root escalated from the $originalUser account"

#insert company message here explaining the situation
cat << EOF
-----------------------------------------------------------------------
COLLECTING CRITICAL SYSTEM DATA. PLEASE DO NOT TURN OFF YOUR SYSTEM...
-----------------------------------------------------------------------
EOF

echo "Start time-> `date`"

#we will start tracing connections with dtrace below this line#

#we will collect memory below this line#

#we will collect volatile data using shell below this line#

#Create a pf rule to block all network access except for access to file server over ssh#
quarentineRule=/etc/activeIr.conf
echo "Writing quarentine rule to $quarentineRule"
serverIP=192.168.1.111 #IP of the server you want to stay in contact with this system
cat > $quarentineRule << EOF
block in all
block out all
pass in proto tcp from $serverIP to any port 22
EOF

#load the pfconf rule and inform the user there is no internet access#
pfctl -f $quarentineRule 2>/dev/null
pfctl -e 2>/dev/null
if [ $? -eq 0 ]; then
	echo "Quarentine Enabled. Internet access unavailable"
fi


#we will collect a file listing here#

#we will collect file artifacts here#

#we will collect system startup artificats and ASEPS here#

#we will collect web browser artifacts here#

#create a zip file of all the data in the current directory#
#this will always be the last thing we do. Do not add code below this section through this book
echo "Archiving Data"
cname=`scutil --get ComputerName | tr ' ' '_' | tr -d \’`
now=`date +"_%Y-%m-%d"`
ditto -k --zlibCompressionLevel 5 -c $IRfolder $cname$now.zip
