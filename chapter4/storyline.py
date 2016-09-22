import os
import time
import datetime
import sqlite3
import glob
import gzip

#fix standard log to write UTC timestamps
#fix year timestamp to reflect the year the file was created

def writeToStory(string):
	outputFile = 'storyline.txt'
	f = open(outputFile, 'a')
	f.write(string)
	f.close()

def gunzipFiles(fileLocation):
	fileWildcarded = "%s*" % (fileLocation)
	for fileName in glob.glob(fileWildcarded):
		newFileName = fileName.replace('.gz', '')
		outputFile = open(newFileName, 'wb')
		try:
			inputFile = gzip.open(fileName, 'rb')
			file_content = inputFile.read()
			outputFile.write(file_content)
			outputFile.close()
		except IOError:
			pass


#many logs on OS X store entries with this format so we can re-use this function
def timelineStandardLog(title, fileLocation):
	print fileLocation
	now = datetime.datetime.now()
	gunzipFiles(fileLocation)

	fileWildCarded = "%s*" % (fileLocation)
	for fileName in glob.glob(fileWildCarded):
		with open(fileName) as f:
			for line in f:
				#grab the timestamp
				ts = line.split()[:3]
				ts = ' '.join(ts)
				#add the current year to the syslog becase it does not contain it
				ts = "%s %s" % (now.year, ts)

				#grab the rest of the log
				info = line.split()[4:]
				info = ' '.join (info)
				try:
					t = time.strptime(ts, "%Y %b %d %H:%M:%S")
					logEntry = "%s, %s, %s\n" % (time.strftime("%Y-%m-%dT%H:%M:%S", t), title, info)
					print logEntry
					writeToStory(logEntry)

				except ValueError:
					pass


def timelineQuarantine(fileName):
    conn = sqlite3.connect(fileName)
	c = conn.cursor()
	#EventIdentifier, TimeStamp, AgentBundleIdentifier, Name, DataURLString SenderName SenderAddress TypeNumber OriginTitle OriginURLString LSQuarantineOriginAlias
	for row in c.execute('SELECT * FROM LSQuarantineEvent'):
		ts = time.gmtime(row[1])
		
		ose = (int(time.mktime(datetime.date(2001,1,1).timetuple())) - time.timezone)
		nts = (time.strftime('%Y-%m-%dT%H:%M:%S', time.gmtime(ose+row[1])))
		
		info = row[2:]
		info = "".join(str(info))
		logEntry = "%s, QUARANTINE, %s\n" % (nts, info)
		print logEntry
		writeToStory(logEntry)


if __name__ == '__main__':

	timelineStandardLog('SYSLOG', 'artifacts/system.log')
	timelineStandardLog('APPFirewall', 'artifacts/appfirewall.log')
	timelineStandardLog('INSTALL', 'artifacts/install.log')
	timelineStandardLog('ACCOUNTPOLICY', 'artifacts/accountpolicy.log')
	timelineQuarantine('artifacts/com.apple.LaunchServices.QuarantineEventsV2')