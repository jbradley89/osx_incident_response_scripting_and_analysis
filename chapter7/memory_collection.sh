#collect memory
#requires osxpmem.zip be inside the tools directory
#requires rekall be inside the tools directory

#scenario 1 -> full memory acquisition
#scenario 2 -> collect memory strings and live memory commands
#scenario 3 -> collect only live memory commands

#scenario 1 set by default
scenario=1
IRfolder=collection
rekallOutputFolder=$IRfolder/rekall
memArtifacts=$IRfolder/memory.aff4
mkdir $IRfolder

#if going with the live memory scenario, set Rekall commands here
function runRekallCommands { 
	mkdir $rekallOutputFolder
	tools/rekall/rekal -f /dev/pmem arp --output $rekallOutputFolder/rekall_arp.txt
	tools/rekall/rekal -f /dev/pmem lsmod --output $rekallOutputFolder/rekall_lsmod.txt
	tools/rekall/rekal -f /dev/pmem check_syscalls --output $rekallOutputFolder/rekall_check_syscalls.txt
	tools/rekall/rekal -f /dev/pmem psxview --output $rekallOutputFolder/rekall_psxview.txt
	tools/rekall/rekal -f /dev/pmem pstree --output $rekallOutputFolder/rekall_pstree.txt
	tools/rekall/rekal -f /dev/pmem dead_procs --output $rekallOutputFolder/rekall_dead_procs.txt
	tools/rekall/rekal -f /dev/pmem psaux --output $rekallOutputFolder/rekall_psaux.txt
	tools/rekall/rekal -f /dev/pmem route --output $rekallOutputFolder/rekall_route.txt
	tools/rekall/rekal -f /dev/pmem sessions --output $rekallOutputFolder/rekall_sessions.txt
	tools/rekall/rekal -f /dev/pmem netstat --output $rekallOutputFolder/rekall_netstat.txt
	#add any additional Rekall commands you want to run here
}

function collectSwap {
	#Check if swap files are encrpyted and collect if they're not
	if ! sysctl vm.swapusage | grep -q encrypted; then
		echo "Collecting swap memory..."
		osxpmem.app/osxpmem -i /private/var/vm/sleepimage -o $memArtifacts
		osxpmem.app/osxpmem -i /private/var/vm/swapfile* -o $memArtifacts
	else
		echo "Swapfiles encrypted. Skipping..."
	fi
}

echo "Starting memory collection..."

#unzip osxpmem app to current directory
unzip tools/osxpmem.zip > /dev/null

#modify permissionbs on kext file so we can load it
chown -R root:wheel osxpmem.app/MacPmem.kext

#try to load kext
if kextload osxpmem.app/MacPmem.kext; then
	echo "MacPmem Kext loaded"
else
	echo "ERROR: MacPmem Kext failed to load. Can not collect memory."
fi

case $scenario in
	1)
		#scenario 1 -> full memory acquisition
		osxpmem.app/osxpmem -o $memArtifacts > /dev/null
		collectSwap
		;;
	2)
		#scenario 2 -> collect memory strings and live memory commands
		osxpmem.app/osxpmem -o $memArtifacts > /dev/null
		osxpmem.app/osxpmem --export /dev/pmem --output memory.dmp $memArtifacts
		echo "Running strings on memory dump..."
		strings memory.dmp > $IRfolder/memory.strings

		#run Recall commands
		runRekallCommands
		
		#clean up since these files may take up a lot of hard drive space
		rm $memArtifacts
		rm memory.dmp
		#test
		;;
	3)
		#scenario 3 -> collect only live memory commands
		runRekallCommands
		;;
esac

echo "Unloading MacPmem.kext"
kextunload osxpmem.app/MacPmem.kext
