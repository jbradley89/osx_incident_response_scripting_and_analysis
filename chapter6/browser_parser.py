import sqlite3
import plistlib
import glob
import time
import datetime

dt_lookup = {
    0: 'CLEAN', 
    1: 'DANGEROUS_FILE', 
    2: 'DANGEROUS_URL',
    3: 'DANGEROUS_CONTENT',
    4: 'MAYBE_DANGEROUS_CONTENT',
    5: 'UNCOMMON_CONTENT',
    6: 'USER_VALIDATED',
    7: 'DANGEROUS_HOST',
    8: 'POTENTIALLY_UNWANTED',
    9: 'MAX'
}

def printToFile(string):
    output_file = 'browserHistory.txt'
    with open(output_file, 'a') as fd:
        fd.write(string)

def convertAppleTime(appleFormattedDate):
    ose = (int(time.mktime(datetime.date(2001,1,1).timetuple())) - time.timezone)
    appleFormattedDate = float(appleFormattedDate)
    ts = (time.strftime('%Y-%m-%dT%H:%M:%S', time.gmtime(ose+appleFormattedDate)))
    return ts

def parseSafariHistoryplist(histFile):
    historyData = plistlib.readPlist(histFile)
    for x in historyData['WebHistoryDates']:
        string = "%s, safari_history, %s\n" % (convertAppleTime(x['lastVisitedDate']), x[''])
        printToFile(string)

def parseSafariHistorydb(histFile):
    #need to convert timestamp still.
    print("Parsing Safari")
    conn = sqlite3.connect(histFile)
    c = conn.cursor()
    query = """SELECT 
                    h.visit_time,
                    i.url
                FROM 
                    history_visits h
                INNER JOIN
                    history_items i ON h.history_item = i.id"""
    for visit_t, url in c.execute(query):
        string = "%s, safari_history, %s\n" % (convertAppleTime(visit_t), url)
        printToFile(string)

def parseSafariDownloadsplist(histfile):
    print("Parsing Safari Downloads")
    historyData = plistlib.readPlist(histfile)
    for x in historyData['DownloadHistory']:
        try:
            string = "%s, safari_download, %s, %s\n" % (x['DownloadEntryDateAddedKey'], x['DownloadEntryURL'], x['DownloadEntryPath'])
            printToFile(string)
        except KeyError:
            string = "safari_download, %s, %s\n" % (x['DownloadEntryURL'], x['DownloadEntryPath'])
            printToFile(string)


def parseChromeHistory(histFile):
    print("Parsing Chrome")
    conn = sqlite3.connect(histFile)
    c = conn.cursor()
    query = """SELECT 
                    strftime('%Y-%m-%dT%H:%M:%S', (v.visit_time/1000000)-11644473600, 'unixepoch'),
                    u.url
                FROM
                    visits v 
                INNER JOIN 
                    urls u ON u.id = v.url;"""
    
    for dt, url in c.execute(query):
        string = "%s, chrome_history, %s\n" % (dt, url)
        printToFile(string)

    query = """SELECT 
                    strftime('%Y-%m-%dT%H:%M:%S', (d.start_time/1000000)-11644473600, 'unixepoch'),
                    dc.url,
                    d.target_path,
                    d.danger_type,
                    d.opened
                FROM 
                    downloads d
                INNER JOIN
                    downloads_url_chains dc ON dc.id = d.id;"""

    for dt, referrer, target, danger_type, opened in c.execute(query):
        string = "%s, chrome_download, %s, %s, danger_type:%s, opened:%s\n" % (dt, referrer, target, 
                                                                               dt_lookup[danger_type], opened)
        printToFile(string)

def parseOperaHistory(histFile):
    print("Parsing Opera")
    conn = sqlite3.connect(histFile)
    c = conn.cursor()
    query = """SELECT 
                    strftime('%Y-%m-%dT%H:%M:%S', (v.visit_time/1000000)-11644473600, 'unixepoch'),
                    u.url, 
                    u.title 
                FROM 
                    visits v
                INNER JOIN 
                    urls u ON u.id = v.url;"""

    for row in c.execute(query):
        string = "%s, opera_history, %s\n" % (row[0], row[1])
        printToFile(string)
    
    #parse Opera downloads  
    query = """SELECT 
                    strftime('%Y-%m-%dT%H:%M:%S', (d.start_time/1000000)-11644473600, 'unixepoch'),
                    dc.url,
                    d.target_path,
                    d.danger_type,
                    d.opened
                FROM 
                    downloads d
                INNER JOIN
                    downloads_url_chains dc ON dc.id = d.id;"""
    for row in c.execute(query):
        string = "%s, opera_download, %s, %s, danger_type:%s, opened:%s\n" % (row[0], row[1], row[2], dt_lookup[row[3]], row[4])
        printToFile(string)

def parseFirefoxHistory(histFile):
    print("Parsing Firefox")
    conn = sqlite3.connect(histFile)
    c = conn.cursor()
    query = """SELECT 
                    strftime('%Y-%m-%dT%H:%M:%S',hv.visit_date/1000000, 'unixepoch') as dt, 
                    p.url
                FROM 
                    moz_historyvisits hv
                INNER JOIN
                    moz_places p ON hv.place_id = p.id
                ORDER by dt ASC;"""
    for dt, url in c.execute(query):
        string = "%s, firefox_history, %s\n" % (dt, url)
        printToFile(string)
    
    #FireFox parse firefox downloads
    query = """SELECT 
                    strftime('%Y-%m-%dT%H:%M:%S', a.dateAdded/1000000, 'unixepoch') as dt,
                    a.content, 
                    p.url 
                FROM 
                    moz_annos a 
                INNER JOIN  
                    moz_places p ON p.id = a.place_id
                WHERE
                    a.anno_attribute_id = 6
                ORDER BY dt ASC;"""

    for dt, content, url in c.execute(query):
        string = "%s, firefox_download, %s, %s\n" % (dt, content, url)
        printToFile(string)

if __name__ == '__main__':
    print("Parsing Browser History...")

    safariDBFound = False
    for filename in glob.glob('browserHistory/*.db'):
        if filename.endswith('chromeHistory.db'):
            parseChromeHistory(filename)
        elif filename.endswith('firefoxHistory.db'):
            parseFirefoxHistory(filename)
        elif filename.endswith('operaHistory.db'):
            parseOperaHistory(filename)
        elif filename.endswith('safariHistory.db'):
            parseSafariHistorydb(filename)
            safariDBFound = True 

    for filename in glob.glob('browserHistory/*.plist'):
        if filename.endswith('safariHistory.plist') and safariDBFound == False:
            parseSafariHistoryplist(filename)
        elif filename.endswith('safariDownloads.plist'):
            parseSafariDownloadsplist(filename)

