#! /usr/bin/python3

import os
import time
import argparse

# script level paths, independent of processed file
scriptHomePath = ''
inputPath = ''
profilesPath = ''
genomadbPath = ''
workLogFocusPath = ''
workBinMetabatPath = ''
workLogMetabatPath = ''
workInBinningrefPath = ''
workOutBinningrefPath = ''
workLogBinningrefPath = ''
workOutMashPath = ''
allResultsPath = ''
processedPath = ''

# paths and file names dependent on processed file
focusOutPath = ''
focusLogFile = ''
metabatBinPath = ''
metabatLogFile = ''
binningrefInPath = ''
binningrefInOnePath = ''
binningrefInTwoPath = ''
binningrefOutPath = ''
binningrefResultSandLFile = ''
binningrefResultContigsFile = ''
binningrefResultSkeyCsvFile = ''
binningrefResultSkeyHtmFile = ''
binningrefResultRefBinsPath = ''
binningrefLogFile = ''
mashOutPath = ''
resultPath = ''

# look for command string options
def pickoptions():
    parser = argparse.ArgumentParser(description='Focus/Metabat/Binning_refiner/Mash (fmbm) script')
    parser.add_argument('-i', '--input', dest='input', 
                        help='process this file')
    parser.add_argument('-d', '--database', dest='database', 
                        help='use this database')
    parser.add_argument('-r', '--root', dest='root', 
                        help='fmbm root subdirectory (default: user home)')
    parser.add_argument('-c', '--comment', dest='comment',
                        help='"comment for this execution"')
    args = parser.parse_args()
    return args # returns Namespace of options found

# set the fmbm root subdirectory
def setRootPath(rootOption):
    userHomePath = os.path.expanduser('~') + '/'
    if rootOption is None:
        rootPath = userHomePath + 'fmbmroot/'
        if os.path.isdir(rootPath):
            message = 'Using the existing root path ' + rootPath
        else:
            userSubDirectories = [ usub for usub in os.listdir(userHomePath) \
                if os.path.isdir(userHomePath + usub) ]
            candidate = {'subdir': None, 'tstamp': 0}
            for usub in userSubDirectories:
                maybelog = userHomePath + usub + '/fmbm/logfmbm.txt'
                if os.path.isfile(maybelog):
                    info = os.stat(maybelog)
                    if info.st_mtime > candidate['tstamp']:
                        candidate = {'subdir': usub, 'tstamp': info.st_mtime}
            if candidate['subdir'] is None:
                rootPath = userHomePath + 'fmbmroot/'
                os.system('mkdir ' + rootPath)
                if os.path.isdir(rootPath):
                    message = 'Using the newly created root path ' + rootPath
                else:
                    message = 'The default root path ' + rootPath + ' does not exist and could not be created'
                    rootPath = None
            else:
                rootPath = userHomePath + candidate['subdir'] + '/'
                message = 'The root path ' + rootPath + ' contains the most recently used logfmbm.txt'
    else:
        if '/' in rootOption or rootOption[0] == '.':
            rootPath = None
            message = 'Invalid root path ' + rootOption + ', cannot include "/" or start with "."'
        else:
            rootPath = userHomePath + rootOption + '/'
            if os.path.isdir(rootPath):
                message = 'Using the appointed existent root path ' + rootPath
            else:
                os.system('mkdir ' + rootPath)
                if os.path.exists(rootPath):
                    message = 'Using the newly created root path ' + rootPath
                else:
                    rootPath = None
                    message = 'The provided root option ' + rootOption + ' does not exist and could not be created'
    return (rootPath, message) # returns the slash terminated rootPath and explanation

# set the value of the paths used by the script, all of them are globals
def setAbsPaths(rootPath):
    global scriptHomePath, inputPath, profilesPath, genomadbPath, workLogFocusPath, \
        workBinMetabatPath, workLogMetabatPath, workInBinningrefPath, workOutBinningrefPath, \
        workLogBinningrefPath, workOutMashPath, allResultsPath, processedPath
    scriptHomePath = rootPath + 'fmbm/'
    inputPath = rootPath + 'inputfmbm/'
    profilesPath = rootPath + 'profilesfmbm/'
    genomadbPath = rootPath + 'genomadbfmbm/'
    workPath = rootPath + 'workfmbm/'
    workLogFocusPath = workPath + 'logfocus/'
    workBinMetabatPath = workPath + 'binmetabat/'
    workLogMetabatPath = workPath + 'logmetabat/'
    workInBinningrefPath = workPath + 'inbinningref/'
    workOutBinningrefPath = workPath + 'outbinningref/'
    workLogBinningrefPath = workPath + 'logbinningref/'
    workOutMashPath = workPath + 'outmash/'
    allResultsPath = rootPath + 'allresultsfmbm/'
    processedPath = rootPath + 'processedfmbm/'
    pathFlag = True
    msgList = []
    try:
        for aPath in (scriptHomePath, inputPath, profilesPath, genomadbPath, workPath, \
            workLogFocusPath, workBinMetabatPath, workLogMetabatPath, workInBinningrefPath, \
            workOutBinningrefPath, workLogBinningrefPath, workOutMashPath, allResultsPath, \
            processedPath):
            if not os.path.exists(aPath):
                os.system('mkdir ' + aPath)
                if not os.path.exists(aPath):
                    pathFlag = False
                    msgList.append(aPath + ' does not exist and could not be created')
    except Exception:
        pathFlag = False
        import sys
        msgList.append('Exception: ' + sys.exc_info()[0] + ' ' + sys.exc_info()[1])
    if pathFlag:
        message = 'All paths were verified'
    else:
        message = ', '.join(msgList)
    return (pathFlag, message) # True/False for paths set and they exist, and explanation

def appendLog(message):
    arbit = open(scriptHomePath + 'logfmbm.txt', 'a')
    arbit.write(message + '\n')
    arbit.close()

# if a database was given in options, verify it exists and copy to databases folder
# otherwise find the most recent in the databases folder
def pickDatabase(dbOption):
    if dbOption is None:
        filesindb = os.listdir(genomadbPath)
        if len(filesindb) == 0:
            return (None, 'No databases found in ' + genomadbPath)
        tsrecent = 0
        database = ''
        particulars = ''
        for fname in filesindb:
            info = os.stat(genomadbPath + fname)
            if tsrecent < info.st_mtime:
                tsrecent = info.st_mtime
                database = genomadbPath + fname
                particulars = ' size: ' + str(info.st_size) + ' tstamp: ' + \
                    time.strftime('%Y-%m-%d %H:%M:%S', time.localtime(info.st_mtime))
        message = 'Using the most recent database: ' + database + ' in ' + genomadbPath + particulars
    else:
        fullPathDbOption = os.path.abspath(dbOption)
        dbOpIsFile = os.path.isfile(fullPathDbOption)
        if dbOpIsFile:
            copyTarget = genomadbPath + os.path.basename(dbOption)
            if copyTarget != fullPathDbOption:
                if os.path.exists(copyTarget):
                    database = None
                    message = 'Database conflict: ' + dbOption + ' already exists in ' + genomadbPath
                else:
                    os.system('cp -p ' + dbOption + ' ' + genomadbPath)
                    if not os.path.isfile(copyTarget):
                        database = None
                        message = 'The appointed database ' + dbOption + ' could not be copied to ' + genomadbPath
                    else:
                        database = copyTarget
                        message = 'Using appointed database: ' + dbOption + ', copied to ' + genomadbPath
            else:
                database = dbOption
                message = 'Using appointed database: ' + dbOption + ', existing in ' + genomadbPath
        else:
            database = genomadbPath + dbOption
            if not os.path.exists(database):
                database = None
                message = 'Appointed database ' + dbOption + ' does not exist'
            else:
                message = 'Using option database: ' + database + ', found in ' + genomadbPath
    # returns absolute path to database and comment for logging
    # if database was provided as option, a copy was made to genomadbPath (if it dindn't exist there)
    return (database, message)

# if a fasta type file was given in options, verify it exists and move it to inputPath
# otherwise assert we have one file in inputPath and take it for process
def pickFastaFile(inputOption):
    if inputOption is None:
        candidates = os.listdir(inputPath)
        if len(candidates) == 0:
            return (None, None, None, 'No files found in ' + inputPath)
        if len(candidates) != 1:
            return (None, None, None, 'More than one file found in ' + inputPath)
        filename = candidates[0]
        pathtopf = inputPath + filename
    else:
        if not os.path.isfile(inputOption):
            return (None, None, None, inputOption + ' not found')
        else:
            filename = os.path.basename(inputOption)
            pathtopf = inputPath + filename
            # if inputOption is not in our inputPath
            if os.path.abspath(inputOption) != pathtopf:
                os.system('mv ' + inputOption + ' ' + inputPath)
                if not os.path.isfile(pathtopf):
                    return(None, None, None, 'The appointed input file ' + inputOption +
                        ' could not be moved to ' + inputPath)
    info = os.stat(pathtopf)
    rmp = filename.rfind('.')
    bluntname = filename[:rmp].replace('.','_') if rmp >= 0 else filename
    if    os.path.exists(profilesPath + bluntname + '/') \
       or os.path.exists(workBinMetabatPath + bluntname + '/') \
       or os.path.exists(workInBinningrefPath + bluntname + '/') \
       or os.path.exists(workOutBinningrefPath + bluntname + '_Binning_refiner_outputs/') \
       or os.path.exists(workOutMashPath + bluntname + '/') \
       or os.path.exists(allResultsPath + bluntname + '/'):
       return(None, None, None, 'The blunt name of the input file ' + bluntname +
           ' already exists in previous results')
    # returns from the file to process: name (without path), name without ext and with . -> _,
    # absolute path to target fasta file and comment for logging
    return (filename, bluntname, pathtopf, 'File for process is: ' +
            pathtopf + ', size: ' + str(info.st_size) + ', tstamp: ' +
            time.strftime('%Y-%m-%d %H:%M:%S', time.localtime(info.st_mtime)))

# set processed file dependent paths and filenames, all of them are globals
# paths are deleted if they exist, and then created new
def setFileDepPaths(filename, bluntname):
    global focusOutPath, focusLogFile, metabatBinPath, metabatLogFile, binningrefInPath, \
        binningrefInOnePath, binningrefInTwoPath, binningrefOutPath, binningrefResultSandLFile, \
        binningrefResultContigsFile, binningrefResultSkeyCsvFile, binningrefResultSkeyHtmFile, \
        binningrefResultRefBinsPath, binningrefLogFile, mashOutPath, resultPath
    focusOutPath = profilesPath + bluntname + '/'
    focusLogFile = workLogFocusPath + filename + '.txt'
    metabatBinPath = workBinMetabatPath + bluntname + '/'
    metabatLogFile = workLogMetabatPath + filename + '.txt'
    binningrefInPath = workInBinningrefPath + bluntname + '/'
    binningrefInOnePath = workInBinningrefPath + bluntname + '/one/'
    binningrefInTwoPath = workInBinningrefPath + bluntname + '/two/'

    # created by Binning_refiner, no need to create paths
    binningrefOutPath = workOutBinningrefPath + bluntname + '_Binning_refiner_outputs/'
    binningrefResultSandLFile = binningrefOutPath + bluntname + '_sources_and_length.txt'
    binningrefResultContigsFile = binningrefOutPath + bluntname + '_contigs.txt'
    binningrefResultSkeyCsvFile = binningrefOutPath + bluntname + '_sankey.csv'
    binningrefResultSkeyHtmFile = binningrefOutPath + bluntname + '_sankey.html'
    binningrefResultRefBinsPath = binningrefOutPath + bluntname + '_refined_bins/'

    binningrefLogFile = workLogBinningrefPath + filename + '.txt'
    mashOutPath = workOutMashPath + bluntname + '/'
    resultPath = allResultsPath + bluntname + '/'

    try:
        for path in (focusOutPath, metabatBinPath, binningrefInPath,
            binningrefInOnePath, binningrefInTwoPath, mashOutPath, resultPath):
            if os.path.exists(path):
                os.system('rm -f -R ' + path)
            os.system('mkdir ' + path)
        fdpFlag = True
        message = 'Filenames and paths were initialized'
    except Exception:
        fdpFlag = False
        import sys
        message = 'Exception: ' + sys.exc_info()[0] + ' ' + sys.exc_info()[1]
    return (fdpFlag, message)

def buildFocusCmd():
    focusCmd = 'focus -q ' + inputPath + ' -o ' + focusOutPath + ' -l ' + focusLogFile
    return focusCmd

def focusResultsPeek():
    msgList = []
    if os.path.isfile(focusOutPath + 'output_All_levels.csv'):
        msgList.append('focus - The file ' + focusOutPath + 'output_All_levels.csv was created')
    else:
        msgList.append('focus - Warning: The file ' + focusOutPath + 'output_All_levels.csv was not created')
    profilesCount = len( os.listdir(focusOutPath) ) - 1 # less one because output_All_levels.csv is there
    if profilesCount >= 1:
        msgList.append('focus - ' + str(profilesCount) + ' profile file(s) were created')
    else:
        msgList.append('focus - Warning: No profile files were created')
    return ', '.join(msgList)

def buildMetabatCmd(pathtopf):
    metabatCmd = 'metabat2 -m 1500 -i ' + pathtopf + ' -o ' + metabatBinPath + 'metabat > ' + metabatLogFile 
    return metabatCmd

def metabatResultsToBinningref():
    binCount = len( os.listdir(metabatBinPath) )
    if binCount > 0:
        os.system('cp -p -s ' + metabatBinPath + '* ' + binningrefInOnePath)
        os.system('cp -p -s ' + metabatBinPath + '* ' + binningrefInTwoPath)
        message = 'metabat - ' + str(binCount) + ' bin file(s) were created and copied to Binning_refiner input folders'
    else:
        message = 'metabat - Warning: No bin files were created'
    return message

def buildBinningrefCmd(bluntname):
    binningrefCmd = 'cd ' + workOutBinningrefPath + '; ' + \
        'Binning_refiner -i ' + binningrefInPath + ' -p ' + bluntname + ' -plot > ' + binningrefLogFile 
    return binningrefCmd 

def binningrefResultsPeek():
    if os.path.isdir(binningrefOutPath):
        refinedBinsList = os.listdir(binningrefResultRefBinsPath)
        rbinCount = len(refinedBinsList)
        message = 'Binning_refiner - The output subdirectory and ' + str(rbinCount) + ' refined bin files were created'
    else:
        refinedBinsList = []
        message = 'Binning_refiner - Warning: The output subdirectory ' + binningrefOutPath + ' was not created'
    return (refinedBinsList, message)

def buildMashCmd(refinedBin, database):
    mashCmd = 'mash dist ' + binningrefResultRefBinsPath + refinedBin + ' ' + database + \
        ' > ' + mashOutPath + refinedBin + '.txt'
    return mashCmd

def mashResultsPeek():
    mashTaxoMatchList = os.listdir(mashOutPath)
    if len(mashTaxoMatchList) > 0:
        message = 'mash - ' + str( len(mashTaxoMatchList ) ) + ' taxonomic match reports were generated'
    else:
        message = 'mash - Warning: no taxonomic match reports were generated'
    return (mashTaxoMatchList, message)

def extractMinDistRows(mashTaxoMatchList, printableComment):
    want = 10
    for mtm in mashTaxoMatchList:
        minDistRows = []
        rown = 0
        for line in open(mashOutPath + mtm, 'r'):
            rown += 1
            linitemslist = line.rstrip().split('\t')
            if len(linitemslist) != 5: # ignore lines that don't yield 5 fields
                continue
            distn = float(linitemslist[2]) # distance, string to numeric value
            linitemslist.append( str(rown) ) # [5] 6th item -> the row number
            linitemslist.append(distn) # [6] 7th item, numeric distance
            insidx = len(minDistRows) # comparison starting position (next position beyond end of minDistRows)
            while insidx - 1 >= 0 and distn < minDistRows[insidx - 1][6]:
                insidx -= 1 # distance was less, point to next wpward
            if insidx == len(minDistRows): # didn't advance any place
                if len(minDistRows) == want:
                    continue; # no need to add rows with large distance, the top set is full
                minDistRows.append(linitemslist) # append just to grow the top set
                continue
            minDistRows.insert(insidx, linitemslist) # insert and keep top set ordered
            if len(minDistRows) > want: # if insertion made top set overflow, discard the trailing row
                minDistRows.pop()
        fobj = open(resultPath + mtm + '.out', 'w')
        for row in minDistRows:
            fobj.write('\t'.join(row[:6]) + '\n')
        fobj.write(printableComment + '\n')
        fobj.close()
    message = 'All ' + str(len(mashTaxoMatchList)) + ' files were extracted for the best ' + str(want) + ' distances'
    return (message) 

def linkBinrefResults():
    os.system('cp -p -s ' + binningrefResultSandLFile   + ' ' + resultPath) 
    os.system('cp -p -s ' + binningrefResultContigsFile + ' ' + resultPath)
    os.system('cp -p -s ' + binningrefResultSkeyCsvFile + ' ' + resultPath)
    if os.path.isfile(binningrefResultSkeyHtmFile):
        os.system('cp -p -s ' + binningrefResultSkeyHtmFile + ' ' + resultPath)
    message = 'Binning_refine output files were linked in the results subdirectory ' + resultPath
    return message

def moveToProcessed():
    os.system('mv ' + pathtopf + ' ' + processedPath)


# main
print('fmbm process script')
options = pickoptions()
printableComment = '' if options.comment is None else '\nComment: ' + options.comment

(rootPath, rootmessage) = setRootPath(options.root)
if rootPath is None:
    print('Error: ' + message)
    exit()

(pathFlag, pathmessage) = setAbsPaths(rootPath)
if not pathFlag:
    print('Error: ' + message)
    exit()

appendLog('\n* Starting execution ' + time.strftime('%Y-%m-%d %H:%M:%S') + printableComment)
appendLog(rootmessage)
appendLog(pathmessage)

(database, message) = pickDatabase(options.database)
appendLog(message)
if database is None:
    print('Error: Database')
    exit()

(filename, bluntname, pathtopf, message) = pickFastaFile(options.input)
appendLog(message)
if filename is None:
    print('Error: Input file')
    exit()

(fdpFlag, message) = setFileDepPaths(filename, bluntname)
appendLog(message)
if not fdpFlag:
    print('Error: File dependent paths')
    exit()

appendLog('FOCUS command')
focusCmd = buildFocusCmd()
appendLog(focusCmd)
os.system(focusCmd)
appendLog( focusResultsPeek() )

appendLog('METABAT command')
metabatCmd = buildMetabatCmd(pathtopf)
appendLog(metabatCmd)
os.system(metabatCmd)
appendLog( metabatResultsToBinningref() )

appendLog('Binning_refiner command')
binningrefCmd = buildBinningrefCmd(bluntname)
appendLog(binningrefCmd)
os.system(binningrefCmd)
(refinedBinsList, message) = binningrefResultsPeek()
appendLog(message)

appendLog('MASH - start cycling')
for refinedBin in refinedBinsList:
    mashCmd = buildMashCmd(refinedBin, database)
    appendLog(mashCmd)
    os.system(mashCmd)
(mashTaxoMatchList, message) = mashResultsPeek()
appendLog(message)

appendLog('MinDistance extraction')
message = extractMinDistRows(mashTaxoMatchList, printableComment)
appendLog(message)

appendLog('Linking Binning_refiner results to results subdirectory')
linkBinrefResults()

appendLog('Moving input file to processed subdirectory')
moveToProcessed()

appendLog('Done - results are in ' + resultPath)
print('Done - your results are in ' + resultPath)
