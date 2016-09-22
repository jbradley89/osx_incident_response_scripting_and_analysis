import os
import stat
import argparse
import hashlib
import time


class FileWalker(object):

    def __init__(self, startDir, dumpdir, md5Bool, whitelist):
        if not os.path.isdir(dumpdir):
            os.makedirs(dumpdir)
        self.fileInfo = "%s/fileinfo.txt" % (dumpdir)
        self.fileTimeline = "%s/filetimeline.txt" % (dumpdir)
        self.startDir = startDir
        self.md5Bool = md5Bool
        self.dumpdir = dumpdir
        self.errors = []
        self.fileTypes = {"010":"file", "014":"socket", "012":"link", "060":"block dev", "004":"dir", "020":"char dev", "001":"FIFO"}
        self.specialbits = {"0":"None", "2048":"SETUID", "1024":"SETGID", "512":"STICKYBIT", "3072":"SETUID/SETGID", "2560":"SETUID/STICKYBIT", "1536":"SETGID/STICYKBIT", "3584":"SETUID/SETGIT/STICKYBIT"}
        self.whitelist = whitelist or []

    def getHash(self, fp):
        with open(fp, 'rb') as fh:
            m = hashlib.md5()
            while True:
                data = fh.read(8192)
                if not data:
                    break
                m.update(data)
            return m.hexdigest()

    def formatTime(self, timestamp):
        ts = time.strftime("%Y-%m-%dT%H:%M:%S", time.gmtime(timestamp))
        return ts

    def checkTypeSpecial(self, filePath):
        special = filePath.st_mode & stat.S_ISUID + filePath.st_mode & stat.S_ISGID + filePath.st_mode & stat.S_ISVTX
        return self.specialbits[str(special)]

    def statFile(self,filePath):
            sr = os.stat(filePath)
            return sr, getattr(sr, 'st_birthtime', None)

    def collect(self, fileName, fi_fd, time_fd):
        try:
            (mode, ino, dev, nlink, uid, gid, size, atime, mtime, ctime), btime = self.statFile(fileName)

            #create a string entry for each timestamp
            aString = "%s, accessed, %s\n" % (self.formatTime(atime), fileName)
            mString = "%s, modified, %s\n" % (self.formatTime(mtime), fileName)
            cString = "%s, changed, %s\n" % (self.formatTime(ctime), fileName)
            #add birth time if it exists
            if btime != None: bString = "%s, birth, %s\n" % (self.formatTime(btime), fileName)


            #check for special file bits - stickybit should not be found since we aren't collecting directories
            x = (mode & stat.S_ISUID) + (mode & stat.S_ISGID) + (mode & stat.S_ISVTX)
            special = self.specialbits[str(x)]

            #create file data for seperate file
            filetype = self.fileTypes[str(oct(mode)[:3])]
            if self.md5Bool == True and os.path.isfile(fileName):
                md5 = self.getHash(fileName)
                fileData = "%s, %s, %s, %s, %s, %s, %s, %s\n" % (fileName, oct(mode)[-3:], self.fileTypes[str(oct(mode)[:3])], uid, gid, size, special, md5)
            else:
                fileData = "%s, %s, %s, %s, %s, %s, %s\n" % (fileName, oct(mode)[-3:], self.fileTypes[str(oct(mode)[:3])],uid, gid, size, special)

            #write data to files
            fi_fd.write(fileData)
            time_fd.write(aString)
            time_fd.write(mString)
            time_fd.write(cString)
            if btime!=None:
                time_fd.write(bString)
        except OSError:
            self.errors.append(fileName)

    def run(self):
        print("Collecting file listing...")
        with open(self.fileInfo, 'w+a') as fi_fd, open(self.fileTimeline, 'w+a') as time_fd:
            for dirname, dirnames, filenames in os.walk(self.startDir, topdown=True):
                dirnames[:] = [d for d in dirnames if d not in self.whitelist]
                for filename in filenames:
                    fileWithPath = os.path.join(dirname, filename)
                    self.collect(fileWithPath, fi_fd, time_fd)

if __name__ == '__main__':
    #create script arguments
    parser = argparse.ArgumentParser()
    parser.add_argument("-s", "--start", required=True, help="Specify a starting directory")
    parser.add_argument("-d", "--dumpdir", required=True, help="Specify a directory to store the created files")
    parser.add_argument("-m", "--md5", required=False, action='store_true', help="Collect MD5 Hashes")
    parser.add_argument("-w", "--whitelist", nargs='*', required=False, help="Skip specified directories")
    args = parser.parse_args()

    #create a run filewalker
    fileWalker = FileWalker(args.start, args.dumpdir, args.md5, args.whitelist)
    fileWalker.run()
