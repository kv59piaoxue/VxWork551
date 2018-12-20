# install.tcl - Installation program for Unix/Windows platforms.
#
# Copyright 1984-1997 Wind River Systems, Inc
#
# Modification history
# --------------------
# 03b,05mar02,bwd  Modified SETUP to be non-tornado centric
# 03a,12jun01,j_w  Modified for Tornado 2.2
# 05w,30oct00,j_w  SPR 35775: skip the zip file not found error checking
#                  and set WIND_BASE correctly if running setup /L from the 
#                  installed tree (spr 35775, 35778)
# 05v,13oct00,bwd  setupSDK: modified cdNameGet to check for and allow
#                  CDdescription containing quotes.
# 05u,26jun00,bwd  Initialized CD description from setup.log when not running
#                  SETUP from CD image
# 05t,23jun00,bwd  SPR 31612: initialize CD information using setup.log when
#                  lauching SETUP due to LM errors
# 05s,08jun00,j_w  Backup files one at a time instead of queuing up 32 files
#                  before backing up - SPR 31184
# 05r,02jun00,bwd  Changed all "dialog ok" to use "dialog ok_with_title"
# 05q,08may00,bwd  Fixed SPR 31061. Added "catch" when flushing fSetupLog to
#                  Temp directory (in uninstLog procedure) in case Temp
#                  directory is full
# 05p,02feb00,bwd  Modified codes to log messages in autoSetupLog file and not
#                  display messageBox for test automation
# 05o,17dec99,clc  Add path to ZIP invocation.
# 05n,28oct99,bjl  added disk space check in backup procedures. 
# 05m,19oct99,j_w  Fixed uninstHome to use unix path format. This fixed the
#                  uninstall problem if Tornado is installed 2 directories deep
# 05l,18oct99,bjl  prepend cd directory to ZIP path for backup.
# 05k,14oct99,j_w  Add paramenters to uninstStop
# 05j,19mar99,wmd  Output to a file any debug messages.
# 05i,03mar99,tcy  create installCDnumber file in data.XXX for About-Box usage
# 05h,01feb99,tcy  moved most procedures to wizard files
# 05g,30jan99,bjl  added setExecutePermissions procedure for Unix.
# 05f,27jan99,tcy  moved fileNameAbbreviate() to INCLUDE.TCL
# 05e,27jan99,wmd  Need to remove the continue statements in the new proc
#                  processInstall.
# 05d,21jan99,wmd  Need to remove comment line after uninstallInitWin32
#                  invocation, causing problems.
# 05c,13jan99,wmd  Update the file using WRS coding conventions.
# 05b,15dec98,tcy  copy UNINST and SETUP to bin and user setup directories
#                  respectively
# 05a,03dec98,tcy  do not copy setup engine files to bin directory
# 04z,25nov98,tcy  added kbyteToMyte () to calculate disk space on Windows
# 04y,24nov98,tcy  removed "/" from rawfile variable in setupCopy
#                  for all hosts
# 04x,20nov98,bjl  return from setupCopy if user chooses to exit Setup.
# 04w,19nov98,wmd  display path/filename in a shorthand form if it's too long.
# 04v,19nov98,tcy  remove forward slash so file join could work on UNIX
# 04u,12nov98,tcy  fixed regsub expression to correctly copy SETUP files
# 04t,11nov98,tcy  use floating point to calculate part size
# 04s,11nov98,wmd  reinitialize setupVals(drvIndex) after resetting it.
# 04r,10nov98,tcy  do not copy files to temp directory before backing up
#                  (fix for SPR 23131)
# 04q,07nov98,tcy  used setupClusterSizeGet() to get correct cluster size
#                  on Windows and added rootDirGet() (fix for SPR 22931)
# 04o,07nov98,wmd  need to make setupVals(drvIndex) and array of indices.
# 04n,05nov98,tcy  added CD manufacturing time to setup.log (fix for SPR 22930)
# 04m,29oct98,tcy  fixed backup bug which removes backup files from installation
# 04l,25oct98,tcy  backup files in groups rather than one at a time
# 04k,22oct98,bjl  changed removeBackground check back to limitColors for bbrd.
# 04j,21oct98,tcy  fixed librariesUpdate() to correctly update the meter
# 04i,21oct98,wmd  fixed bad english for non-existing file in MULTIPLE_VERSION.
# 04h,20oct98,wmd  make setupVals(tornadoIndex) a list of indices.
# 04g,19oct98,bjl  changed limitColors check to removeBackground for bbrd.
# 04f,16oct98,wmd  set setupVals(driverIndex) for the driver product.
# 04e,09oct98,bjl  do not update billboards in filesCopy if color limiting
#                  is set.
# 04d,07oct98,bjl  cd out of tempdir in uninstStop so that tempdir can be
#                  removed when setup exists, added queueExecute to uninstStop
#                  for Unix machines.
# 04c,07oct98,tcy  fixed "overwritten" sentence in setup.log
# 04b,06oct98,tcy  added CD description to DISK_ID
# 04a,30sep98,tcy  fixed bmp path on UNIX and fixed env(PATH)
# 03z,30sep98,tcy  change text to "Preparing to copy files ..."
# 03y,30sep98,tcy  fix hang on UNINST and adjust uninstBinCopy for unix UNINST
# 03x,25sep98,bjl  flush setup.log.tmp to [destDirGet]/setup.log.abort.
# 03w,25sep98,tcy  overwrite windows system files even for same file versions
# 03v,17sep98,bjl  set setupVals(diskfull) if user exits when disk is full.
# 03u,14sep98,tcy  added setupVals(confirmation) for showing list of products
# 03t,11sep98,tcy  added checkVersion option to fileDup()
# 03s,08sep98,tcy  DISK_ID is not copied to user's SETUP directory now
# 03r,03sep98,bjl  changed setupVals(regHost) to setupVals(registry) for
#                  Unix torVarsCreate.
# 03q,01sep98,wmd  changed "fixing up filenames" to "resolving version..."
# 03p,01sep98,tcy  fixed librariesUpdate() to remove relative paths from archive
# 03o,25aug98,tcy  fixed listDir() to use glob instead of cmd.exe
# 03n,20aug98,wmd  modify to add write out of destination dir to setup.log.
# 03m,17aug98,j_w  modified filesCopy() for automated installation
# 03l,14aug98,tcy  SETUP copied onto user's $WIND_BASE/SETUP directory
# 03k,04aug98,tcy  fixed meter in libariesUpdate()
# 03j,04aug98,bjl  fixed overwritten typo.
# 03i,04aug98,bjl  added ability to install product last through inf file.
# 03h,31jul98,wmd  added coreProd as flag to fetch for prodObj.
# 03g,30jul98,bjl  added inf file processing of arflags.
# 03f,29jul98,wmd  added messageBeep to create audio warning for overwrite case.
# 03e,27jul98,wmd  added default case for EXIST_AND_NEWER, EXIST_AND_OLDER.
# 03d,24jul98,wmd  set current_file global val in filesCopy.
# 03c,23jul98,tcy  added CDnumberGet()
# 03b,23jul98,wmd   add dialog to get user policy on overwriting of files.
#                  Also added fix for SPR #21090.
# 03a,21jul98,tcy  archive objects by AR flags and library archives
# 02v,17mar98,pdn  fixed MULTIPLE_VERSION logic to conform to the design spec.
# 02u,02mar98,pdn  moved the feature Id/Desc from part to product level.
# 02t,14nov97,pdn  added a list of overwriten files to the setup.log
# 02s,12aug97,pdn  moved version string to VERSION.TCL
# 02r,04aug97,pdn  merged fixed from qms1_0_x branch.
# 02q,20jun97,pdn  allowed native $(AR), and $(RANLIB) to be defined.
# 02p,13jun97,pdn  changed to use setup APIs as a DLL.
# 02o,19may97,pdn  fixed fileNameAbbreviate() to handle the case that regexp
#                  fails to match.
# 02n,02may97,pdn  added comments.
# 02m,08apr97,pdn  fixed fileDup() to handle file permission accordingly
# 02l,28mar97,pdn  added code to support correct uninstall
# 02k,10mar97,pdn  fixed library update routine.
# 02j,08mar97,tcy  undo last mod
# 02i,07mar97,tcy  moved needUpdateWlmd() from INSTTK.TCL to here
# 02h,07mar97,pdn  fixed uninstStart to allow patch uninstallation.
# 02g,05mar97,pdn  sorted the product list.
# 02f,04mar97,pdn  copy ZIP utility to bin directory.
#                  added hook for patch installation.
# 02e,25feb97,pdn  added function byteToMbyte()
# 02d,24feb97,pdn  modified fileDup() to allow update/overwrite.
# 02c,09feb97,pdn  fixed cdInfoGet to return correct selected feature Id list
# 02b,04feb97,pdn  fixed library updating problem.
# 02a,24jan97,pdn  rounded up the product size upto 0.1 MB where needed
# 01z,24jan97,pdn  returned to the calling function when user hit cancel
# 01y,22jan97,pdn  fixed the ar so that console windows in Windows 95 won't
#                  show up.
# 01x,21jan97,pdn  fixed fileDup(), and execute().
# 01w,20jan97,pdn  fixed replicated feature id/name, better error hanlding
# 01v,14jan97,pdn  updated uninstBinCopy() to support Windows, fixed indentation
# 01u,07jan97,pdn  updated the pre/post install
#                  implemented billboard cycling from product dir
# 01t,18dec96,sks  changed location of TCL and BITMAP files; renamed
#                  TEXT.TCL to MESSAGES.TCL
# 01s,13dec96,pdn  updated postInstall()
# 01r,12dec96,pdn  added productName to the productObj
# 01r,11dec96,pdn  fixed cdInfoGet and productInfoGet to return correct
#                  featureId list
# 01q,09dec96,pdn  added hierachy selection option
# 01p,23nov96,sj   incorporated post and presinstall mechanisms
# 01o,18nov96,sj   caught user removing CDROM when files are being
#                  copied over and included the check for backuped
#                  files into backup().
# 01m,11nov96,pdn  centralized all strings to TEXT.TCL
# 01l,08nov96,pdn  backup newer files in the same manner as older files.
# 01k,06nov96,pdn  added retry option for fileDup()
# 01j,05nov96,pdn  fixed the uninstall logging
# 01i,24oct96,pdn  added uninstLog()
# 01h,21oct96,pdn  added pageRemove()
# 01g,18oct96,pdn  updated uninstStart() to use new uninst dir, and added
#                  uninstBinCopy()
# 01f,01oct96,tcy  moved umaskGet(), umaskSet(), getSelection() here
# 01e,29aug96,pdn  allowed non-tk specific installation
# 01d,27aug96,pdn  handle messages return from zip.
# 01c,02jul96,pdn  added directory creation, and implement lib update.
# 01b,25jun96,pdn  modified the GUI to meet the specification.
# 01a,11jun96,jco  translated to tk from the uitcl/Windows.
#

##############################################################################
#
# backup - save the specified file into a zip file.
#
# This procedure stores files in a queue and invokes backupFileQueueFlush()
# to zip files in the queue.  If the file is previously backed up,
# nothing will be done.
#
# SYNOPSIS
# backup <fileName>
#
# PARAMETERS:
#    fileName : a path filename
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc backup {fileName} {
    global backupFileQueue
    global backupFileArray
    global backupFileArraySize
    global setupVals

    if {![info exists setupVals(cancelBackup)]} {
        set setupVals(cancelBackup) 0
    } else {
        if {$setupVals(cancelBackup) == 1} {
            return
        }
    }

    if {![info exists backupFileArraySize]} {
        set backupFileArraySize 0
    }

    set fileSize [file size [destDirGet]/$fileName]

    # file size returns the value in bytes.  Change this
    # to kbytes, since setupDiskSpaceGet or fspace returns its
    # value in kbytes (used in backupFileQueueFlush).  

    set fileSize [expr $fileSize / 1024]

    set backupFileArraySize [expr $backupFileArraySize + $fileSize] 


    # backupFileArray contains all files that have been backed up so far

    if ![info exists backupFileArray($fileName)] {

        # only interested in the existence of the array element,
        # not the content

        set backupFileQueue($fileName) ""
        set backupFileArray($fileName) ""

        # backup the file each time
        backupFileQueueFlush
        
        #if {[array size backupFileQueue] > 32} {
        #    backupFileQueueFlush
        #}
    }
}

##############################################################################
#
# backupFileQueueFlush - zip all files in the file queue
#
# This procedure zips the specified file into a zip file.
#
# SYNOPSIS
# backupFileQueueFlush <fileName>
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc backupFileQueueFlush {} {
    global backupFileQueue 
    global setupVals
    global backupFileArraySize
    global diskSpace
   
    # simply return if the user chose to skip backups.

    if {![info exists setupVals(cancelBackup)]} {
        set setupVals(cancelBackup) 0
    } else {
        if {$setupVals(cancelBackup) == 1} {
            return
        }
    }

    if {![info exists backupFileArraySize]} {
        set backupFileArraySize 0
    }

    # check for available disk space.

    if {[isUnix]} {
        set diskSpace [fspace [destDirGet]]
    } else {
        set diskSpace [setupDiskSpaceGet [destDirGet]]
    }

    # allow some extra temp space for the zip file.

    set spaceRequired [expr 2 * $backupFileArraySize]

    set msg [strTableGet BACKUP_DISK_FULL_WARN]

    # pop up a dialog box if not enough space available
    # to perform the backup.

    while {$spaceRequired > $diskSpace && \
           $setupVals(cancelBackup) != 1} {
        switch [dialog ok_cancel "Setup" $msg question 0] {
            0 {
                # user freed some space.  Check to make sure
                # enough space is now available.

                if {[isUnix]} {
                    set diskSpace [fspace [destDirGet]]
                } else {
                    set diskSpace [setupDiskSpaceGet [destDirGet]]
                }
            }
            1 {
                # user chooses to cancel backups due to lack of
                # disk space.

                set setupVals(cancelBackup) 1
            }
        }
    }
   
    if {$setupVals(cancelBackup) == 1} {
        return
    }
 
    set backupFileArraySize 0

    if [array exists backupFileQueue] {

        set saveDir [pwd]
        cd [destDirGet]

        set backupList [join [array names backupFileQueue]]
        set setupVals(uninstFile) [dosToUnix $setupVals(uninstFile)]
        set cmd "exec [file join [cdromBinDirGet] ZIP] $setupVals(uninstFile) -g -q -1 $backupList"

        if [catch {eval $cmd} error] {
            dbgputs "warning: backup fails with : $error"
            dbgputs "backupList = $backupList"
        } else {

            foreach file [array names backupFileQueue] {
                dbgputs [format "%20s\t%s" BACKED_UP $file]
                uninstLog backup "wind_base\t$file"
            }
        }

        # clean up queue
        unset backupFileQueue
        cd $saveDir

    }
}

##############################################################################
#
# uninstStart - obtains a zip filename
#
# This procedure obtains a zip filename for use in sub-sequence calls to zip,
# creates $WIND_BASE/.wind/uninst if not exist.  Must be called prior any zip
# function call.
#
# SYNOPSIS
# uninstStart [type]
#
# PARAMETERS:
#    [type] : if 'license' is specified, zip filename w/ extension 001 returns.
#
# RETURNS: zip filename.
#
# ERRORS: N/A
#

proc uninstStart {{type Software}} {
    global setupVals

    uninstHomeDirSet [destDirGet]/.wind/uninst

    if ![file isdirectory [uninstHomeDirGet]] {
        catch {file mkdir [uninstHomeDirGet]}
    }

    set uninstHome [dosToUnix [uninstHomeDirGet]]

    if {"$type" == "license"} {
        set setupVals(uninstFile) "$uninstHome/data.001"
    } else {
        set setupVals(uninstFile) \
            "$uninstHome/data.[format "%03d" [expr 1 + \
             [llength [glob -nocomplain $uninstHome/data.*]]]]"
    }

}

##############################################################################
#
# uninstFileClose - close uninstall file descriptions.
#
# This procedure closes uninstall file descriptions if they are still opened.
#
# SYNOPSIS
# uninstFileClose
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc uninstFileClose {} {
    global setupVals

    if {"$setupVals(uninstFileOpen)" == "opened"} {
        catch { close $setupVals(fInstallFile) } err
        catch { close $setupVals(fInstallInfo) } err
        catch { close $setupVals(fInstallBackup) } err
        catch { close $setupVals(fInstallResource) } err
        catch { close $setupVals(fInstallCDnumber) } err
        puts $setupVals(fSetupLog) ""
        catch { close $setupVals(fSetupLog) } err
        set setupVals(uninstFileOpen) closed
    }
}

##############################################################################
#
# uninstFileOpen - opens files for recording uninstall info.
#
# This procedure opens disk files for writing the temporary uninstall records.
# These files will be closed by calling uninstFileClose()
#
# SYNOPSIS
# uninstFileOpen
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

set setupVals(uninstFileOpen) ""

proc uninstFileOpen {} {
    global setupVals

    if {"$setupVals(uninstFileOpen)" != "opened"} {
        set setupLog [tempDirGet]/setup.log.tmp
        set uninstFile [tempDirGet]/installFile.tmp
        set uninstResource [tempDirGet]/installResource.tmp
        set uninstCDnumber [tempDirGet]/installCDnumber.tmp
        set uninstBackup [tempDirGet]/installBackup.tmp
        set uninstInfo [tempDirGet]/installInfo.tmp

        set setupVals(fSetupLog) [open $setupLog "w"]
        set setupVals(fInstallFile) [open $uninstFile "w"]
        set setupVals(fInstallInfo) [open $uninstInfo "w"]
        set setupVals(fInstallBackup) [open $uninstBackup "w"]
        set setupVals(fInstallResource) [open $uninstResource "w"]
        set setupVals(fInstallCDnumber) [open $uninstCDnumber "w"]

        set setupVals(uninstFileOpen) opened
    }
}

##############################################################################
#
# uninstBinCopy - copies uninstall agent
#
# This procedure copies neccessary files from CDROM to the destination
# directory for the uninstall program to work.  No-op if patch installation
# is detected.
#
# SYNOPSIS
# uninstBinCopy
#
# PARAMETERS:  N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc uninstBinCopy {} {
    global env

    if {[instTypeGet] == "patch"} {
        return

    } elseif {[windHostTypeGet] == "x86-win32"} {
        # all the required binary files are copied by setupCopy
        fileDup [file join [cdromRootDirGet] RESOURCE BITMAPS UNINST.BMP] \
                [file join [uninstHomeDirGet] UNINST.BMP] update
        fileDup [file join [cdromRootDirGet] RESOURCE TCL UNINST.TCL] \
                [file join [uninstHomeDirGet] UNINST.TCL] update
        fileDup [file join [cdromRootDirGet] RESOURCE TCL INCLUDE.TCL] \
                [file join [uninstHomeDirGet] INCLUDE.TCL] update
    } else {
        # Other shared libraries are copied by the UNINST shell script
        # because those are untarred from MWUITCL.TAR

        set usrBinDir [file join [destDirGet] host [windHostTypeGet] bin]
        set usrSetupDir [file join [destDirGet] SETUP]
        set env(PATH) $usrBinDir:$env(PATH)

        fileDup [file join [cdromRootDirGet] RESOURCE TCL UNINST.TCL] \
                [file join [uninstHomeDirGet] UNINST.TCL] update
        fileDup [file join [cdromRootDirGet] RESOURCE TCL INCLUDE.TCL] \
                [file join [uninstHomeDirGet] INCLUDE.TCL] update
        fileDup [file join [cdromRootDirGet] RESOURCE BITMAPS/UNINST.BMP] \
                [file join [uninstHomeDirGet] UNINST.BMP] update
        fileDup [file join [cdromRootDirGet] UNINST] \
                [file join $usrBinDir UNINST] update
        fileDup [file join [cdromRootDirGet] SETUP] \
                [file join $usrSetupDir SETUP] update
        fileDup [file join [cdromBinDirGet] ZIP] \
                [file join $usrBinDir ZIP] update
        fileDup [file join [cdromBinDirGet] SETUPTCL[string toupper \
                                           [info sharedlibextension]]] \
                [file join $usrBinDir setuptcl[info sharedlibextension]] update
    }
}

##############################################################################
#
# uninstStop - wraps up the uninstall process.
#
# This procedure copies uninstall agent, executes all queued commands, closes
# all tempfiles, saves the temporary uninstall records into a zip file.
#
# SYNOPSIS
# uninstStop
#
# PARAMETERS:
#       prodName - Product Name e.g. Tornado
#       prodVer - Product Version e.g. 3.0
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc uninstStop {prodName prodVer} {
    global setupVals

    if {"$setupVals(uninstLog)" > "0"} {
        uninstBinCopy

        if {[windHostTypeGet] == "x86-win32"} {

            # For Windows hosts, create registry entries and uninstall icon
            # uninstallInitWin32 was previously called uninstallSetup

            uninstallInitWin32 $prodName $prodVer
            queueExecute
        } else {
            queueExecute
        }

        uninstFileClose

        if [file exists $setupVals(uninstFile)] {
            catch {setupUnzip -o -qq $setupVals(uninstFile) \
                  -d [tempDirGet] "install*"}
        }

        fileAppend [file join [tempDirGet] installFile.tmp] \
                [file join [tempDirGet] installFile]
        fileAppend [file join [tempDirGet] installResource.tmp] \
                [file join [tempDirGet] installResource]
        fileAppend [file join [tempDirGet] installCDnumber.tmp] \
                [file join [tempDirGet] installCDnumber]
        fileAppend [file join [tempDirGet] installBackup.tmp] \
                [file join [tempDirGet] installBackup]
        fileAppend [file join [tempDirGet] installInfo.tmp] \
                [file join [tempDirGet] installInfo]
        fileAppend [file join [tempDirGet] setup.log.tmp] \
                [file join [destDirGet] setup.log]

        cd [tempDirGet]

        if [catch {exec [cdromBinDirGet]/ZIP $setupVals(uninstFile) -g -q -1 -m \
                            "installFile" "installInfo" "installBackup"\
                            "installResource" "installCDnumber"} error] {
             puts "$error"
        }

        cd [cdromRootDirGet]

    } else {
        uninstFileClose
    }
}

##############################################################################
#
# fileAppend - appends the content of the source to the destination file.
#
# This procedure takes the content of the source file and appends it to the
# destination file.
#
# SYNOPSIS
# fileAppend <srcFilePath> <destFilePath>
#
# PARAMETERS:
#    srcFilePath : a path to the source filename
#    destFilePath : a path to the destination filename
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc fileAppend {srcFilePath destFilePath} {

    set ftmp [open $srcFilePath "r"]
    set f [open $destFilePath "a+"]

    while {[gets $ftmp line] != "-1"} {
        puts $f $line
    }

    catch { close $ftmp } err
    catch { close $f } err
}

##############################################################################
#
# uninstLog - stores the specified string into the appropriate disk file.
#
# SYNOPSIS
# uninstLog <key> <string>
#
# PARAMETERS:
#    key : a string that long enough to differentiate between disk filenames,
#          <r>esource, <b>ackup, <f>ileNew, <i>nfo, <s>etupLog, <c>dNumber
#    string : string to be stored.
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc uninstLog {key string} {
     global setupVals
     set exitSetup 0

     uninstFileOpen

     if [catch { switch -glob $key {
                     c* {
                         puts $setupVals(fInstallCDnumber) $string
                     }
                     r* {
                         puts $setupVals(fInstallResource) $string
                         incr setupVals(uninstLog)
                     }
                     b* {
                         puts $setupVals(fInstallBackup) $string
                         incr setupVals(uninstLog)
                     }
                     f* {
                         puts $setupVals(fInstallFile) $string
                         incr setupVals(uninstLog)
                     }
                     i* {
                         puts $setupVals(fInstallInfo) $string
                     }
                     s* {
                         puts $setupVals(fSetupLog) "[installDate]\t$string"
                         if {[destDirGet] != ""} {

                             if [catch {flush $setupVals(fSetupLog)} result] {
                                 set msg "SETUP detected error\(s\)\n$result\
                                          \n\n[strTableGet TEMP_DISK_FULL_WARN]"
                                 dialog ok_with_title "ERROR: Installation" $msg
                                 set exitSetup 1
                             }
                                  
                             catch {file copy -force \
                                         [tempDirGet]/setup.log.tmp \
                                         [destDirGet]/setup.log.abort}
                         }
                     }
                     default {
                         puts "uninstLog error: $key does not exist"
                     }
                 }
             } error] {

         puts "cannot record \"$string\": $error"
     }

     if { $exitSetup } {
         set setupVals(cancel) 1
         applicationExit
         dialog ok_with_title "Setup" "Setup will terminate now"
         return 0
     }
}

##############################################################################
#
# installDate - forms a simple date string
#
# SYNOPSIS
# installDate
#
# PARAMETERS: N/A
#
# RETURNS: a date string (i.e, 08-Apr-97.18:30)
#
# ERRORS: N/A
#

proc installDate {} {
    return [clock format [clock second] -format "%d-%b-%y.%H:%M"]
}

##############################################################################
#
# fileDup - copies a file
#
# This routine copies srcFile to destFile.  The default option flag is 'none'
# which means doing nothing if destFile exists, update: if srcFile is newer,
# backup destFile then copies, overwrite: backup then copies.  In case of
# failure, a message will be displayed, and user has a chance to decide next
# action.  All successful copied filename will be logged for later uninstall.
#
# SYNOPSIS
# fileDup <srcFile> <destFile> [option]
#
# PARAMETERS:
#    <srcFile> : an absolute path filename
#    <destFile> : an absolute path filename
#    [option] : none | update | overwrite
#
# RETURNS: True or False bases on success or failure.
#
# ERRORS: N/A
#

proc fileDup {sourceFilePath destFilePath {option none}} {
    global ctrlVals setupVals

    if ![file exists $sourceFilePath] {
        dbgputs "$sourceFilePath not found"
        return 0
    }

    regsub -all {\\} $destFilePath {/} destFilePathUnixStyle
    regsub -all {\\} [destDirGet] {/} destDir
    regsub "$destDir/" $destFilePathUnixStyle "" relDestFilePathUnix

    switch $option {
        none {
            if [file exists $destFilePath] {return 1}
        }
        checkVersion {
            # this option is mainly used for checking version of DLLs in
            # the Windows System directory; we don't backup the file and
            # we don't keep track of the file for uninstall purpose

            if [catch {setupFileVersionInfoGet $sourceFilePath} wrsVersion] {
                dbgputs "Cannot get file version of $sourceFilePath: $wrsVersion"
            }
            if {[file exists $destFilePath] &&
               [catch {setupFileVersionInfoGet $destFilePath} userVersion]} {
               dbgputs "Cannot get file version of $destFilePath: $userVersion"
            }
            if {[file exists $destFilePath] && $wrsVersion < $userVersion} {
                return 1
            }
            # if we reach this, we need to overwrite the old file
            # no backup here because we'd like to keep the new version
            set noLog 1
        }
        update {
            if {[file exists $destFilePath] &&
                [file mtime $sourceFilePath] <= [file mtime $destFilePath]} {
                return 1
            } elseif {[file exists $destFilePath]} {
                backup $relDestFilePathUnix
            }
        }
        overwrite {
            if {[file exists $destFilePath]} {
                backup $relDestFilePathUnix
            }
        }
        default {
            puts "fileDup $sourceFilePath $destFilePath $option"
            puts "unknown option: $option"
        }
    }

    set destDir [file dirname $destFilePath]

    if {![file isdirectory $destDir] && [catch {file mkdir $destDir} error]} {
        puts "$error"
        return 0
    }

    if [catch {file copy -force $sourceFilePath $destFilePath} error] {
        set msg [strTableGet 1370_FILE_ACCESS_ERROR $destFilePath $error]

        if { $ctrlVals(useInputScript) } {
            autoSetupLog "$msg"
            autoSetupLog "Application Exit\n"
            set setupVals(cancel) 1                
            applicationExit
            return 0
        } else {    

            switch [dialog re_ig_cancel "Setup" $msg question 0] {
                0 {return [fileDup $sourceFilePath $destFilePath $option]}
                1 {
                    set msg "\tcannot create $destFilePath: $error"
                    lastErrorSet $msg
                    uninstLog setup $msg
                    return 0
                }
                default {quitCallback}
            }
        }
    }

    if {[info exists setupVals(fileMode)] && [windHostTypeGet] != "x86-win32"} {
        catch {exec chmod $setupVals(fileMode) $destFilePath}
    }

    # logging for later uninstall

    if ![info exists noLog] {
        uninstLog file "wind_base\t$relDestFilePathUnix"
    }
    return 1
}

##############################################################################
#
# pageRemove - removes an installation step
#
# This routine removes an element from the pageList which control the flow of
# the setup script.  Once an element is removed from the list, their associate
# functions, pageCreate() and pageProcess() will be skipped.
#
# SYNOPSIS
# pageRemove <pageName>
#
# PARAMETERS:
#    <pageName> : an element in the pageList
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc pageRemove {page} {
    global ctrlVals

    if {[lsearch $ctrlVals(pageList) $page] == "-1"} {
        dbgputs "cannot find page $page to remove"
    } else {
        set tempList ""

        foreach p $ctrlVals(pageList) {
            if {"$p" != "$page"} {
                lappend tempList $p
            }
        }
        set ctrlVals(pageList) $tempList
    }
}

##############################################################################
#
# cdInfoGet - returns the requested information
#
# Following is the list of available commands:
#
# Command                 Meaning
# -------                 -------
# number                  the name of the CDROM
# size                    the total size of unlocked products
# totalFile               the total files of unlocked products
# stateInfo               the global selection information
# featureIdList           the feature list of unlocked products
# productIndexList        the index list of unlocked products
# selectedProdIndexList   the selected products index list
# selectedProdNameList    the selected products name list
# installedFeatureIdList  the selected feature id list
#
# SYNOPSIS
# cdInfoGet <command>
#
# PARAMETERS:
#    <command> : one of the above commands
#
# RETURNS: the requested information
#
# ERRORS: N/A
#

proc cdInfoGet {info} {
    global cdObj

    switch $info {
        number { return $cdObj(number) }

        productIndexList { return $cdObj(productIndexList) }

        selectedProdIndexList {
            set retVal {}

            foreach prodIndex $cdObj(productIndexList) {
                if {[productInfoGet instFlag $prodIndex]} {
                    lappend retVal $prodIndex
                }
            }

            return $retVal
        }

        selectedProdNameList {
            set retVal {}

            foreach prodIndex [cdInfoGet selectedProdIndexList] {
                set prodName [productInfoGet name $prodIndex]

                if {[lsearch $retVal "$prodName"] == "-1"} {
                    lappend retVal $prodName
                }
            }

            return $retVal
        }

        size {
            set retVal 0

            foreach selProdIndex [cdInfoGet selectedProdIndexList] {
                incr retVal [productInfoGet size $selProdIndex]
            }

            return $retVal
        }

        totalFile {
            set retVal 0

            foreach selProdIndex [cdInfoGet selectedProdIndexList] {
                incr retVal [productInfoGet totalFile $selProdIndex]
            }

            return $retVal
        }

        installedFeatureIdList {
            set retVal {}

            foreach selProdIndex [cdInfoGet selectedProdIndexList] {
                set fId [productInfoGet featureId $selProdIndex]

                if {($fId > 0) && ([lsearch $retVal $fId] == -1)} {
                    lappend retVal $fId
                }
            }
            return $retVal
        }

        featureIdList {
            set retVal {}

            foreach prodIndex [cdInfoGet productIndexList] {
                set fId [productInfoGet featureId $prodIndex]

                if {($fId > 0) && ([lsearch $retVal $fId] == -1)} {
                    lappend retVal $fId
                }
            }

            return $retVal
        }

        stateInfo {
            set totalPrev 0
            set totalCurr 0
            set state "unchanged"

            foreach prodIndex [cdInfoGet productIndexList] {

                set prev [productInfoGet prevInstFlag $prodIndex]
                set curr [productInfoGet instFlag  $prodIndex]

                incr totalPrev $prev
                incr totalCurr $curr

                if {"$prev" != "$curr"} {
                    set state "changed"
                }
            }

            return [stateInfoHelper $state $totalCurr $totalPrev]
        }

        default { puts "cdInfoGet: unknown command: $info" }
    }
}

##############################################################################
#
# featureDescGet - returns the feature name given the feature id
#
# SYNOPSIS
# featureDescGet <featureId>
#
# PARAMETERS:
#    <featureId> : an integer
#
# RETURNS: the associated feature description or unknown if not exists.
#
# ERRORS: N/A
#

proc featureDescGet {featureId} {
    global featureObj

    if [info exists featureObj($featureId)] {
        return $featureObj($featureId)
    } else {
        return "unknown"
    }
}

##############################################################################
#
# productInfoGet - returns the requested info of a product.
#
# Attribute               Meaning
# ---------               -------
# partIndexList           a list of integer indentifies parts
# number                  a string that represents a product, sale perpective
# name                    a string that represents a product, mfg perpective
# desc                    a string that describes a product
# instFlag                a toggle flag that tells if a product is selected
# prevInstFlag            a previous stage of the above flag
# size                    a total size of a product
# totalFile               a total files of a product
# selectedPartIndexList   a list of selected part of a product
# featureId               a feature id of a product
# stateInfo               a selection state of a product
# coreProd                a product is a core product flag
#
# SYNOPSIS
# productInfoGet <attrib> <productId>
#
# PARAMETERS:
#    <attrib> : one of the above attributes
#    <productId> : a uniq integer that identifies the product.
#
# RETURNS: the requested information.
#
# ERRORS: N/A
#

proc productInfoGet {info prodIndex} {
    global productObj

    switch $info {
        partIndexList { return $productObj($prodIndex,partIndexList) }

        number { return $productObj($prodIndex,number) }

        name { return $productObj($prodIndex,name) }

        desc { return $productObj($prodIndex,desc) }

        instFlag { return $productObj($prodIndex,instFlag) }

        prevInstFlag { return $productObj($prodIndex,prevInstFlag) }

        size {
            set retVal 0

            foreach partIndex [productInfoGet selectedPartIndexList $prodIndex] {
                incr retVal [partInfoGet size $partIndex]
            }

            if {($retVal < 104858) && ($retVal > 0)} { set retVal 104858 }

            return $retVal
        }

        totalFile {
            set retVal 0

            foreach partIndex [productInfoGet selectedPartIndexList $prodIndex] {
                incr retVal [partInfoGet totalFile $partIndex]
            }

            return $retVal
        }

        selectedPartIndexList {
            set retVal {}

            foreach partIndex $productObj($prodIndex,partIndexList) {

                if {"[partInfoGet instFlag $partIndex]" == "1"} {
                    lappend retVal $partIndex
                }
            }

            return $retVal
        }

        featureId {
            return $productObj($prodIndex,featureId)
        }

        coreProd {
            return $productObj($prodIndex,coreProd)
        }

        stateInfo {
            set totalPrev 0
            set totalCurr 0
            set state "unchanged"

            foreach partIndex $productObj($prodIndex,partIndexList) {

                set prev [partInfoGet prevInstFlag $partIndex]
                set curr [partInfoGet instFlag  $partIndex]

                incr totalPrev $prev
                incr totalCurr $curr

                if {"$prev" != "$curr"} {
                    set state "changed"
                }
            }

            return [stateInfoHelper $state $totalCurr $totalPrev]
        }

        default { puts "productInfoGet: unknown info: $info" }
    }
}

##############################################################################
#
# productInfoSet - changes the product object attributes
#
# see productInfoGet() for available products attributes.
#
# SYNOPSIS
# productInfoSet <attrib> <prodIndex> [value]
#
# PARAMETERS:
#    <attrib> : a product attribute
#    <prodIndex> : an integer identifies a product
#    [value] : new value of an attribute
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc productInfoSet {info prodIndex {value ""}} {
    global productObj pickList

    switch $info {
        partIndexList { set productObj($prodIndex,partIndexList) $value }

        number { set productObj($prodIndex,number) $value }

        desc { set productObj($prodIndex,desc) $value }

        instFlag {
            if {"$productObj($prodIndex,instFlag)" == "0" && \
                "$value" == "1"} {

                set setAllFlag 1
                set productObj($prodIndex,instFlag) $value

                foreach partIndex [productInfoGet partIndexList $prodIndex] {
                    if {"[partInfoGet instFlag $partIndex]" == "1"} {
                        set setAllFlag 0
                        break
                    }
                }

                if {"$setAllFlag" == "1"} {
                    foreach partIndex [productInfoGet partIndexList $prodIndex] {
                        partInfoSet instFlag $partIndex 1
                        set pickList(part,$partIndex) 1
                    }
                }

            } else {
                set productObj($prodIndex,instFlag) $value
            }
        }

        stateCommit {
            set productObj($prodIndex,prevInstFlag) \
            $productObj($prodIndex,instFlag)
            }

        stateRestore {
            set productObj($prodIndex,instFlag) \
            $productObj($prodIndex,prevInstFlag)
            }

        childStateCommit {
            foreach partIndex $productObj($prodIndex,partIndexList) {
                partInfoSet stateCommit $partIndex
            }
        }

        childStateRestore {
            foreach partIndex $productObj($prodIndex,partIndexList) {
                partInfoSet stateRestore $partIndex
            }
        }

        default { puts "productInfoSet: unknown info: $info" }
    }
}

##############################################################################
#
# partInfoGet - returns the requested attribute of a part object.
#
# Attribute      Meaning
# ---------      -------
# instFlag       a toggle flags that indicate a selection state of a part
# prevInstFlag   a previous state of the above flag
# desc           a part description
# parent         an integer that identifies the parent product
# size           a total size of a part
# totalFile      a total number of files of a part
#
# SYNOPSIS
# partInfoGet <attrib> <partIndex>
#
# PARAMETERS:
#    <attrib> : a part object's attribute
#    <partIndex> : an integer indentifies a part
#
# RETURNS: requested attribute
#
# ERRORS: N/A
#

proc partInfoGet {info partIndex} {
    global partObj

    switch $info {
        instFlag { return $partObj($partIndex,instFlag) }

        prevInstFlag { return $partObj($partIndex,prevInstFlag) }

        desc { return $partObj($partIndex,desc) }

        parent { return $partObj($partIndex,parent) }

        size {
            if [isUnix] {
                return $partObj($partIndex,size)
            } else {

            # this option returns the estimated size of a part takes up
            # on a Windows file system. A file with 10 bytes can take up to
            # 32768 bytes on a FAT system.
            # On average, each file in tornado wastes 78% of one block.
            # For each file in the part, it adds 78% of the system's
            # block size to the file size to account for the extra bytes

            return  [format %.f [expr $partObj($partIndex,totalFile) * \
                    [setupClusterSizeGet [rootDirGet [destDirGet]]] * \
                    0.78 + $partObj($partIndex,size)]]
            }
        }

        totalFile { return $partObj($partIndex,totalFile) }

        coreProd { return $partObj($partIndex,coreProd) }

        default { puts "partInfoGet: unknown info: $info" }
    }
}

##############################################################################
#
# rootDirGet - returns the root directory or the drive letter for
#              a specified path on Windows machines.
#
# SYNOPSIS
# partInfoSet <path>
#
# PARAMETERS:
#    <path> : a directory pathes
#
# RETURNS: root directory
#
# ERRORS: N/A
#

proc rootDirGet {path} {

    regexp {^(.*)\:(.*)$} $path junk root dir
    if { [info exists root] && "$root" != "" } {
        return "$root:\\"
    } else {
        return "c:\\"
    }
}

##############################################################################
#
# partInfoSet - changes an attribute of a part object
#
# see partInfoGet() for available attribute of a part object
#
# SYNOPSIS
# partInfoSet <attrib> <partIndex> [value]
#
# PARAMETERS:
#    <attrib> : an attribute of a part object
#    <partIndex> : an integer that identifies a part
#    [value] : new attribute value
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc partInfoSet {info partIndex {value ""}} {
    global partObj pickList

    switch $info {
        instFlag { set partObj($partIndex,instFlag) $value }

        desc { set partObj($partIndex,desc) $value }

        parent { set partObj($partIndex,parent) $value }

        stateCommit {
            set partObj($partIndex,prevInstFlag) \
            $partObj($partIndex,instFlag)
            }

        stateRestore {
            set partObj($partIndex,instFlag) $partObj($partIndex,prevInstFlag)
            set pickList(part,$partIndex) $partObj($partIndex,prevInstFlag)
        }

        default { puts "partInfoSet: unknown info: $info" }
    }
}

##############################################################################
#
# stateInfoHelper -  determents if a selection state is changing
#
# By comparing the total size of the current and previous selection state, this
# function helps reduce unnesscessary GUI updating.
#
# SYNOPSIS
# stateInfoHelper <state> <totalCurr> <totalPrev>
#
# PARAMETERS:
#    <state> : curent state
#    <totalCurr> : total size in current state
#    <totalPrev> : total size in previous state
#
# RETURNS: new state.
#
# ERRORS: N/A
#

proc stateInfoHelper {state totalCurr totalPrev} {
    set retVal $state

    if {"$state" != "unchanged"} {

        if {"$totalCurr" == "0"} {
            set retVal "${state}ToNone"

        } elseif {"$totalCurr" >= "$totalPrev"} {
            set retVal "${state}Incr"

        } elseif {"$totalCurr" < "$totalPrev"} {
             set retVal "${state}Decr"
        }
    }

    return $retVal
}

##############################################################################
#
# objectDump - dumps out to stdout all object information
#
# SYNOPSIS
# objectDump
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc objectDump {} {
    global objGuiMap partObj productObj

    puts ""

    foreach elem [lsort [array names objGuiMap]] {
        puts "objGuiMap($elem) = $objGuiMap($elem)"
    }

    foreach elem [lsort [array names partObj]] {
        puts "partObj($elem) = $partObj($elem)"
    }

    foreach elem [lsort [array names productObj]] {
        puts "productObj($elem) = $productObj($elem)"
    }
}

##############################################################################
#
# cdNameGet - read CD part number from DISK_ID file written to by mfg
#
# SYNOPSIS
# cdNameGet
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc cdNameGet {{mode number}} {
    global setupVals env

    set setupVals(runFromCD) 1

    set file [cdromRootDirGet]/DISK_ID

    if {[file exists "$file"] && ![catch {open "$file" "r"} f]} {
        gets $f setupVals(CDnumber)
        gets $f setupVals(CDdescription)
        gets $f setupVals(CDManufacturingTime)
        catch { close $f } err

        # preceed quotes with escape characters
        regsub -all {\"} $setupVals(CDdescription) {\\"} setupVals(CDdescription)

        switch $mode {
            number { return $setupVals(CDnumber) }
            description { return $setupVals(CDdescription) }
            time { return $setupVals(CDManufacturingTime) }
            default { return "" }
        }

    } else {
        # here, no DISK_ID found. Must be running from the tree.

        set setupVals(runFromCD) 0

        if { [isTornadoProduct] } {
            # set wind base
            set env(WIND_BASE) [file dirname [cdromRootDirGet]]
            dbgputs "run from the installed tree. WIND_BASE is $env(WIND_BASE)"

        } else {
            destDirSet [file dirname [cdromRootDirGet]]
            dbgputs "run from the installed tree. Destination directory is [destDirGet]"
        }

        if { $setupVals(lmError) != "" || [instTypeGet] == "licenseSetup"} {

            if { [isTornadoProduct] } {
                destDirSet $env(WIND_BASE)
            } else {
                destDirSet [file dirname [cdromRootDirGet]]
                dbgputs "run from the installed tree"
            }

            # if in lmError page, use CD info from setup.log

            set setupVals(CDnumber) ""

            # get WIND_BASE

            if { [isTornadoProduct] } {
                if { [info exist env(WIND_BASE)] } {
                    set setupLog [file join $env(WIND_BASE) setup.log]
                } else {
                    messageBox "Error: WIND_BASE variable is not set!"
                    return ""
                }
            } else {
                set setupLog [file join [destDirGet] setup.log]
            }

            # try opening setup.log file

            if [catch {open $setupLog r} logfd] {
                messageBox "Error: cannot open file $setupLog!"
                return ""
            } else {
                set text [split [read $logfd] \n]
                set nlines [llength $text]
                close $logfd
                                
                for {set ix 0} {$ix < $nlines} {incr ix} {
                                        
                    # iterate each line and search for CD info
                    set textLine [split [lindex $text $ix]]
                                        
                    # search for line that begins with "TDK"
                    if { [lsearch -regexp $textLine "TDK-"] == 1} {
                                                
                        # get CD number
                        set setupVals(CDnumber) [split [lindex $textLine 1]]
                                                
                        # get CD description (next line)
                        set nextLine [split [lindex $text [expr $ix + 1]]]
                        set endB [expr [llength $nextLine] - 1]
                        set setupVals(CDdescription) [split [lrange $nextLine 1 $endB]]
                    }
                }
            }
                        
            switch $mode {
                number { return $setupVals(CDnumber) }
                description { return $setupVals(CDdescription) }
                default { return "" }
            }
        } else {
            return ""
        }
    }
}

######################################################################
# Dialog Text Messages
######################################################################

set strTable(BACKUP_DISK_FULL_WARN) \
    "SETUP is attempting to backup previously installed files, but\
     no disk space is available.  Free some disk space and press OK\
     to continue, or press Cancel to skip backing up files.\n\n\
     NOTE: If you cancel backup of files, performing an Uninstall to\
     the previous session will be invalid."

set strTable(TEMP_DISK_FULL_WARN) \
    "There may not be enough space available under temporary directory.\
     Please click \"OK\" to exit SETUP, clear temporary directory, and \
     try running SETUP again."

#
# initialize globals
#

source [cdromRootDirGet]/RESOURCE/TCL/VERSION.TCL
global overwritePolicy
catch {unset overwritePolicy}
set overwritePolicy(ALL) 0
set setupVals(uninstLog) 0

#
# loading setup agent
#
load  [cdromBinDirGet]/SETUPTCL[string toupper [info sharedlibextension]]
