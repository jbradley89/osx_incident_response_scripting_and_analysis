import os
import argparse
import datetime

class Exfiltrator(object):

	def __init__(self, outputFile):
		self.whiteList = ["zip", "jar", "rar", "egg", "package", "plist", "xlsx", "docx", "pptx", "cdt", "xpi", "ots", "ods", "dotm", "apk" ]
		self.enableOutput = False
		self.outputFile = outputFile
		if self.outputFile != None:
			self.enableOutput = True

	def getFileHeader(self, fileLocation):
		try:
			f = open(fileLocation)
			header = f.read(4)
			header = header.encode('hex')
			return header
		except IOError:
			print "\nError reading %s. Skipping..." % (fileLocation)
			return None

	def checkWhiteList(self,fileLocation):
		found = False
		for extension in self.whiteList:
			if fileLocation.endswith(extension):
				found = True
				break
		return found

	def checkFile(self, fileLocation):
		print fileLocation
		isFile = os.path.isfile(fileLocation)
		isWhiteListed = self.checkWhiteList(fileLocation)
		if isFile == False:
			header = None
		else:
			header = self.getFileHeader(fileLocation)

		if header is None or isWhiteListed == True:
			pass
		elif header == "504b0304":
			print "\nPKzip file format found"
			ts = datetime.datetime.fromtimestamp(os.path.getmtime(fileLocation))
			string = "%s %s" % (ts, fileLocation)
			if self.enableOutput == True:
				print fileLocation
				self.writeToFile(string + "\n")
			else:
				print string


	def writeToFile(self, data):
		f = open(self.outputFile, 'a')
		f.write(data)
		f.close()

if __name__ == "__main__":

	parser = argparse.ArgumentParser()
	parser.add_argument("-a", "--all", required=False, action="store_true", help="Scan all files on system")
	parser.add_argument("-s", "--start", required=True, help="Specify a starting directory")
	parser.add_argument("-o", "--output", required=False, default=None, help="Output results to specified file")

	args = parser.parse_args()

	exfiltrator = Exfiltrator(args.output)

	#walk each directory
	for dirname, dirnames, filenames in os.walk(args.start):
		for filename in filenames:
			fileWithPath = os.path.join(dirname, filename)
			#print "scanning %s" % (fileWithPath)
			exfiltrator.checkFile(fileWithPath)
