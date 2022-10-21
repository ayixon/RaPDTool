#! /usr/bin/env python

import os
import time
import argparse
import subprocess
import shutil

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
workInMiCompletePath = ''
workOutMiCompletePath = ''
workOutMashPath = ''
miCompleteResPath = ''
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
miCompleteInputFile = ''
miCompleteOutputFile = ''
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
    # ~ parser.add_argument('-c', '--comment', dest='comment',
                        # ~ help='"comment for this execution"')
    args = parser.parse_args()
    return args # returns Namespace of options found

# set the fmbm root subdirectory
def setRootPath(rootOption):
    userHomePath = subprocess.check_output("pwd", shell = True).rstrip().decode('utf-8') + '/'
    if rootOption is None:
        rootPath = userHomePath + 'rapdtool_results/'
        print('Creating path and commands for Focus/Metabat/Binning_refiner/Mash (fmbm) pipeline..')
        if os.path.isdir(rootPath):
            message = 'Using the existing root path ' + rootPath
        else:
            userSubDirectories = [ usub for usub in os.listdir(userHomePath) \
                if os.path.isdir(userHomePath + usub) ]
            candidate = {'subdir': None, 'tstamp': 0}
            for usub in userSubDirectories:
                maybelog = userHomePath + usub + '/log/logfmbm.txt'
                if os.path.isfile(maybelog):
                    info = os.stat(maybelog)
                    if info.st_mtime > candidate['tstamp']:
                        candidate = {'subdir': usub, 'tstamp': info.st_mtime}
            if candidate['subdir'] is None:
                rootPath = userHomePath + 'rapdtool_results/'
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
        rootPath = rootOption + '/'
        isExist = os.path.exists(rootPath)
        if not isExist:
          # Create a new directory because it does not exist
          os.makedirs(rootPath)
        fullpath = 'readlink -f ' + rootPath
        rootPath = subprocess.check_output(fullpath, shell = True).rstrip().decode('utf-8') + '/'
        print('Creating path and commands for Focus/Metabat/Binning_refiner/Mash (fmbm) pipeline..')
        message = 'Using the appointed existent root path ' + rootPath # karel
    return (rootPath, message) # returns the slash terminated rootPath and explanation

# set the value of the paths used by the script, all of them are globals
def setAbsPaths(rootPath):
    global scriptHomePath, inputPath, profilesPath, genomadbPath, workLogFocusPath, \
        workBinMetabatPath, workLogMetabatPath, workInBinningrefPath, workOutBinningrefPath, \
        workLogBinningrefPath, workInMiCompletePath, workOutMiCompletePath, workOutMashPath, \
        miCompleteResPath, allResultsPath, processedPath
    scriptHomePath = rootPath + 'log/'
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
    workInMiCompletePath = workPath + 'inmicomplete/'
    workOutMiCompletePath = workPath + 'outmicomplete/'
    workOutMashPath = workPath + 'outmash/'
    miCompleteResPath = rootPath + 'miCompleteRes/'
    allResultsPath = rootPath + 'allresultsfmbm/'
    processedPath = rootPath + 'processedfmbm/'
    pathFlag = True
    msgList = []
    try:
        for aPath in (scriptHomePath, inputPath, profilesPath, genomadbPath, workPath, \
            workLogFocusPath, workBinMetabatPath, workLogMetabatPath, workInBinningrefPath, \
            workOutBinningrefPath, workLogBinningrefPath, workInMiCompletePath, \
            workOutMiCompletePath, workOutMashPath, miCompleteResPath, allResultsPath, \
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

# if a fasta type file was given in options, verify it exists and copy it to inputPath
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
                os.system('cp ' + inputOption + ' ' + inputPath)
                if not os.path.isfile(pathtopf):
                    return(None, None, None, 'The appointed input file ' + inputOption +
                        ' could not be copied to ' + inputPath)
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
        binningrefResultRefBinsPath, binningrefLogFile, miCompleteInputFile , miCompleteOutputFile , \
        mashOutPath, resultPath
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
    miCompleteInputFile = workInMiCompletePath + bluntname + '.tab'
    miCompleteOutputFile = workOutMiCompletePath + 'miCompleteOut_' + bluntname + '.tab'
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

def renameBinningrefResults(refinedBinsList):
    messagelist = []
    for refinedBin in refinedBinsList: # Won't assume pathlib is available
        if refinedBin[-4:] == '.fna':
            continue
        pointpos = refinedBin.rfind('.')
        if pointpos < 0:
            newname = refinedBin + '.fna'
        else:
            newname = refinedBin[0:pointpos] + '.fna'
        os.system('mv ' + binningrefResultRefBinsPath + refinedBin + ' ' + \
                          binningrefResultRefBinsPath + newname )
        messagelist.append(refinedBin + ' was renamed to ' + newname)
    renamedRefinedBinsList = os.listdir(binningrefResultRefBinsPath)
    return (renamedRefinedBinsList, messagelist)

def buildMiCompletelistCmd():
    miCompletelistCmd = 'find ' + binningrefResultRefBinsPath + \
        ' -maxdepth 1 -type f -name "*.fna" | miCompletelist.sh > ' + miCompleteInputFile
    return miCompletelistCmd

def miCompletelistResultPeek():
    if os.path.isfile(miCompleteInputFile):
        message = 'miCompletelist - The file ' + miCompleteInputFile + ' was created'
    else:
        message = 'miCompletelist - Warning: The file ' + miCompleteInputFile + ' was not created'
    return message

def buildMiCompleteCmd():
    miCompleteCmd = 'miComplete ' + miCompleteInputFile + ' --hmms Bact105 --threads 8 > ' + \
        miCompleteOutputFile
    return miCompleteCmd

def miCompleteResultPeek():
    if os.path.isfile(miCompleteOutputFile):
        message = 'miComplete - The file ' + miCompleteOutputFile + ' was created'
    else:
        message = 'miComplete - Warning: The file ' + miCompleteOutputFile + ' was not created'
    return message

def buildMashCmd(refinedBin, database):
    mashCmd = 'mash dist ' + binningrefResultRefBinsPath + refinedBin + ' ' + database + \
        ' > ' + mashOutPath + refinedBin + '.txt' + ' 2> /dev/null'
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

def buildmergeCmd():
    mergeCmd = 'rapdtool_results_local.pl'
    return mergeCmd

def buildkronaCmd():
    kronaCmd = 'ktImportText forkrona.txt'
    return kronaCmd

def linkBinrefResults():
    os.system('cp -p -s ' + binningrefResultSandLFile   + ' ' + resultPath)
    os.system('cp -p -s ' + binningrefResultContigsFile + ' ' + resultPath)
    os.system('cp -p -s ' + binningrefResultSkeyCsvFile + ' ' + resultPath)
    if os.path.isfile(binningrefResultSkeyHtmFile):
        os.system('cp -p -s ' + binningrefResultSkeyHtmFile + ' ' + resultPath)
        message = 'Binning_refiner output files were linked in the results subdirectory ' + resultPath
    return message

def copyMiCompleteResults():
    os.system('cp -p ' + miCompleteOutputFile + ' ' + miCompleteResPath)
    message = 'miComplete output file was copied to the miComplete results subdirectory ' + miCompleteResPath
    return message

def moveToProcessed():
    os.system('mv ' + pathtopf + ' ' + processedPath)


# main
options = pickoptions()
# ~ printableComment = '' if options.comment is None else '\nComment: ' + options.comment
if options.input is None:
    print('RaPDTool v2.1.0\nusage:\n  $ rapdtool.py -i <input.fasta> -d database.msh [-r output_dir]\n  the input file should be a metagenome assembly\n\n  optional:\n  output_dir_name (default: rapdtool_results)\n\n  notes: 1- you need to put "rapdtool.py" in your path, otherwise you must give the whole path so that it can be found.\n')
    exit()

launchedFrom = os.getcwd()

(rootPath, rootmessage) = setRootPath(options.root)
if rootPath is None:
    print('Error: ' + message)
    exit()

(pathFlag, pathmessage) = setAbsPaths(rootPath)
if not pathFlag:
    print('Error: ' + message)
    exit()

appendLog('\n* Starting execution ' + time.strftime('%Y-%m-%d %H:%M:%S') ) #+ printableComment)
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
print('Running Focus.. [1/7]')
os.system(focusCmd)
appendLog( focusResultsPeek() )

appendLog('METABAT command')
metabatCmd = buildMetabatCmd(pathtopf)
appendLog(metabatCmd)
print('Running Metabat.. [2/7]')
os.system(metabatCmd)
appendLog( metabatResultsToBinningref() )

appendLog('Binning_refiner command')
binningrefCmd = buildBinningrefCmd(bluntname)
appendLog(binningrefCmd)
print('Running Binning_refiner.. [3/7]')
os.system(binningrefCmd)
(refinedBinsList, message) = binningrefResultsPeek()
appendLog(message)

appendLog('rename Binning_refiner output')
(renamedRefinedBinsList, messagelist) = renameBinningrefResults(refinedBinsList)
for message in messagelist:
    appendLog(message)

appendLog('miCompletelist command')
miCompletelistCmd = buildMiCompletelistCmd()
appendLog(miCompletelistCmd)
print('Running miComplete.. [4/7]')
os.system(miCompletelistCmd)
message = miCompletelistResultPeek()
appendLog(message)

appendLog('miComplete command')
miCompleteCmd = buildMiCompleteCmd()
appendLog(miCompleteCmd)
os.system(miCompleteCmd)
message = miCompleteResultPeek()
appendLog(message)

appendLog('MASH - start cycling')
print('Running Mash.. [5/7]')
for refinedBin in renamedRefinedBinsList:
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
appendLog('Copying miComplete results to results subdirectory')
copyMiCompleteResults()

appendLog('Moving input file to processed subdirectory')
moveToProcessed()

mergeCmd = buildmergeCmd()
print('Copying and merging results.. [6/7]')
print('Writing rapdtools results files (tbl and txt)...')
appendLog('Copying and merging results..')
os.chdir(rootPath)
os.system(mergeCmd)

kronaCmd = buildkronaCmd()
print('Generating interactive metagenomic visualization tool (Krona).. [7/7]')
print('Writing rapdtool_krona.html...')
appendLog('Generating interactive metagenomic visualization tool (Krona)..')
os.chdir(rootPath)
os.system(kronaCmd)
os.system('rm -f profilesfmbm.txt forkrona.txt')

# cleanning directories
appendLog('Removing tmp directories..')
os.system('mv ../miComplete.log assemblyID_annot.txt log/')
os.system('rm -rf ../*.tblout ../*_prodigal.faa miCompleteRes')
shutil.rmtree(inputPath)
shutil.rmtree(processedPath)
shutil.rmtree(genomadbPath)

appendLog('Done - results are in ' + rootPath)
print('Done - your results are in ' + rootPath)

