# global.tcl - global Tcl functions for Setup.
#
# Copyright 1996-2003 Wind River Systems, Inc.
#
# modification history
# --------------------
# 04i,27feb03,bjl  added lunique from compselect page and added
#                  lsubstringAppend procedure.                    
# 04h,14feb03,bjl  added wrsLicenseGet procedure.  
# 04g,13jun02,wmd  Need to add in size of DOCS directory if it exists for
#                  setupSizeGet return, SPR #78583.
# 04f,05mar02,bwd  Modified SETUP to be non-tornado centric
# 04e,20dec01,bwd  Added proc isBSPcd to check if user is installing BSP CD
# 04d,03dec01,bwd  Modified licensedProductCheck to check for non-zero
#                  featureId as a licensed product
# 04c,17sep01,bwd  Fixed spr 70204 - removed exit 1
# 04b,13sep01,bwd  Added path conversion for proc destDirGet
# 04a,12jun01,j_w  Modified for Tornado 2.2
# 03a,02may01,j_w  Update hostIdGen to use ether address by default
# 03z,08nov00,j_w  update arFlag to -crus
# 03y,15sep00,bwd  Modified proc hostIdGen to take in an argument to specify
#                  where to get hostID from for Windows
# 03x,31aug00,bwd  First check if file lmhostid exists before executing it
# 03w,28jun00,bwd  Changed the size of SETUP directory for linux to 77 MB
# 03v,09jun00,bwd  Added another host type check for x86-linux2
# 03u,05jun00,bwd  SPR 31449: changed the size of setup directory (in 
#                  setupSizeGet procedure) to match the actual size
# 03t,23may00,bwd  Fixed SPR 31387 - declared ctrlVals variable
# 03s,11may00,wmd  Fix spr # 31178, German version Windows causes Setup to
#                  fail.
# 03r,19apr00,bwd  Modified procedure licensedProductCheck to check using
#                  feature IDs
# 03q,27mar00,bwd  Removed proc licInfoDataParse - no longer used
# 03p,15feb00,j_w  Fix file closing in fileContentGet
# 03o,11feb00,wmd  Fix so that a mild error message is displayed if a file is
#                  missing.
# 03n,02feb00,bwd  Fixed error handling for test automation
# 03m,24jan00,bwd  Added new procedure "isGUImode" to check if SETUP is run in
#                  GUI mode or TEXT mode
# 03l,06dec99,j_w  Added licensedProductCheck
# 03k,12nov99,wmd  lmFeaturesTotals is now an array.
# 03j,11nov99,j_w  Added hostOSGet
# 03i,03nov99,wmd  Add a isNumeric procedure.
# 03h,03nov99,j_w  modified licInfoDataParse to add the PIN required field
# 03g,02nov99,j_w  added licInfoDataParse
# 03f,21oct99,bjl  removed parisc-hpux support.
# 03e,20oct99,j_w  Added lmhostIdGet
# 03d,19oct99,bjl  added tornadoProductCheck procedure.
# 03c,18oct99,j_w  Used setupVals(defGroup) in defGroupSet and defGroupGet
# 03b,05oct99,j_w  Added authCodeGet and authCodeSet
# 03a,30Sep99,j_w  Modified for T3
# 02s,31mar99,wmd  Update the sizes for Setup files in setupSizeGet.
# 02r,29mar99,wmd  Make sure that check for env(SETUP_DEBUG) or env(INF_DEBUG)
#                  are caught.
# 02q,19mar99,wmd  Add proc to write to a file, close the file.
# 02p,03mar99,tcy  Added setupSizeGet() (fix for SPR 25228)
# 02o,24feb99,wmd  Fix so that if exec call returns error, free is still set.
# 02n,02feb99,tcy  modify defGroupSet () to set Tornado2 as default if
#                  folder name selected is a T101 folder
# 02m,28jan99,bjl  added headers and edited for coding conventions.
# 02l,28jan99,wmd  Fix bug in checkPathLen when filename itself is too long.
# 02k,14jan99,wmd  Move procedure debug from INSTALL.TCL to this file.
# 02j,13jan99,wmd  Copy fspace proc from fspace.tcl to this file.
# 02i,18nov98,wmd  added proc checkPathLen
# 02h,16oct98,tcy  added instKeyData[G|S]et()
# 02g,15oct98,tcy  do a unix2dos on filename if win98 host in proc cdFileNameGet
# 02f,13oct98,wmd  do a unix2dos on filename if win95 host in proc cdFileNameGet
# 02e,15sep98,wmd  added cdFileNameGet proc, changed tmpDirGet() to return
#                  /vobs/wpwr/host/<HOST_TYPE>/lib if env var TCL_DEBUG exists.
# 02d,11sep98,tcy  added sysDir[G|S]et ()
# 02c,01sep98,wmd  added destDirDispGet proc.
# 02b,19aug98,wmd  add proc tmpDirGet.
# 02a,22jul98,tcy  moved licenseHomeDirGet/Set () to LICW32.TCL
# 01d,10aug97,pdn  fixed instKeyGet() to trim off white space before return.
# 01c,09feb97,pdn  added exitMsgSet/exitMsgGet functions
# 01b,25nov96,sj   added functions for tempDir, arFlags, currentIndex
# 01a,14nov96,pdn  written
#
# DESCRIPTION
# This file contains the common functions used by the Setup Tcl files.
#
#*/

##############################################################################
#
# userNameGet - returns the name of the user.
#
# This routine returns the name of the user.  If the user name has not been
# set, an empty string is returned.
#
# SYNOPSIS:
# userNameGet
#
# PARAMETERS: N/A
#
# RETURNS: the user name if it exists, else an empty string.
#
# ERRORS: N/A
#

proc userNameGet {} {
    global setupVals

    if {[info exists setupVals(userName)]} {
        return $setupVals(userName)
    } else {
        return ""
    }
}

##############################################################################
#
# userNameSet - sets the name of the user.
#
# Sets the global variable setupVals(userName) to the name of the user.
#
# SYNOPSIS:
# userNameSet val
#
# PARAMETERS:
# <val>
# Contains the name of the user.
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc userNameSet {val} {
    global setupVals

    set setupVals(userName) $val
}

##############################################################################
#
# companyNameGet - returns the company name.
#
# This routine returns the company name.  If the company name has not
# been set, an empty string is returned.
#
# SYNOPSIS:
# companyNameGet
#
# PARAMETERS: N/A
#
# RETURNS: the company name if it exists, else an empty string.
#
# ERRORS: N/A
#

proc companyNameGet {} {
    global setupVals

    if {[info exists setupVals(companyName)]} {
        return $setupVals(companyName)
    } else {
        return ""
    }
}

##############################################################################
#
# companyNameSet - sets the name of the company.
#
# Sets the global variable setupVals(companyName) to the name of the company.
#
# SYNOPSIS:
# companyNameSet val
#
# PARAMETERS:
# <val>
# Contains the name of the company.
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc companyNameSet {val} {
    global setupVals

    set setupVals(companyName) $val
}

##############################################################################
#
# instKeyGet - returns the installation key.
#
# This routine returns the installation key.  If the installation key has not
# been set, an empty string is returned.
#
# SYNOPSIS:
# instKeyGet
#
# PARAMETERS: N/A
#
# RETURNS: the installation key if it exists, else an empty string.
#
# ERRORS: N/A
#

proc instKeyGet {} {
    global setupVals

    if {[info exists setupVals(instKey)]} {
        return [string trim $setupVals(instKey)]
    } else {
        return ""
    }
}

##############################################################################
#
# instKeySet - sets the installation key.
#
# Sets the global variable setupVals(instKey) to the installation key.
#
# SYNOPSIS:
# instKeySet val
#
# PARAMETERS:
# <val>
# Contains the installation key.
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc instKeySet {val} {
    global setupVals

    set setupVals(instKey) $val
}

##############################################################################
#
# instKeyDataGet - returns the installation key data.
#
# This routine returns the installation key data, which includes
# the installation key history for a particular CD.  If the installation key
# data has not been set, an empty string is returned.
#
# SYNOPSIS:
# instKeyDataGet
#
# PARAMETERS: N/A
#
# RETURNS: the installation key data if it exists, else an empty string.
#
# ERRORS: N/A
#

proc instKeyDataGet {} {
    global setupVals

    if {[info exists setupVals(keyList)]} {
        return [string trim $setupVals(keyList)]
    } else {
        return ""
    }
}

##############################################################################
#
# instKeyDataSet - sets the installation key data.
#
# Sets the global variable setupVals(keyList) to the installation key data.
#
# SYNOPSIS:
# instKeyDataSet val
#
# PARAMETERS:
# <val>
# Contains the installation key data.
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc instKeyDataSet {val} {
    global setupVals

    set setupVals(keyList) $val
}

##############################################################################
#
# cdromZipDirGet - returns the directory containing the Setup zip files.
#
# This routine returns the directory containing the Setup zip (WIND) files.
# If the zip directory has not been set, an empty string is returned.
#
# SYNOPSIS:
# cdromZipDirGet
#
# PARAMETERS: N/A
#
# RETURNS: the zip directory if it exists, else an empty string.
#
# ERRORS: N/A
#

proc cdromZipDirGet {} {
    global setupVals

    if {[info exists setupVals(cdromZipDir)]} {
        return $setupVals(cdromZipDir)
    } else {
        return ""
    }
}

##############################################################################
#
# cdromZipDirSet - sets the zip directory.
#
# Sets the global variable setupVals(cdromZipDir) to the directory
# containing the Setup zip (WIND) files.
#
# SYNOPSIS:
# cdromZipDirSet val
#
# PARAMETERS:
# <val>
# Contains the zip directory.
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc cdromZipDirSet {val} {
    global setupVals

    set setupVals(cdromZipDir) $val
}

##############################################################################
#
# cdromRootDirGet - returns the root directory of the CD-ROM.
#
# This routine returns the root directory of the CD-ROM, or the root
# of the Setup tree.  If the root directory has not been set, an empty
# string is returned.
#
# SYNOPSIS:
# cdromRootDirGet
#
# PARAMETERS: N/A
#
# RETURNS: the Setup root directory if it exists, else an empty string.
#
# ERRORS: N/A
#

proc cdromRootDirGet {} {
    global env

    if {[info exists env(CD_ROOT)]} {
        return $env(CD_ROOT)
    } else {
        return ""
    }
}

##############################################################################
#
# cdFileNameGet - returns the root directory of the CD-ROM.
#
# This routine returns the root directory of the CD-ROM, or the root
# of the Setup tree.  If the root directory has not been set, an empty
# string is returned.
#
# SYNOPSIS:
# cdromRootDirGet
#
# PARAMETERS: N/A
#
# RETURNS: the Setup root directory if it exists, else an empty string.
#
# ERRORS: N/A
#

proc cdFileNameGet {fileName} {
    global ctrlVals

    # return only valid all uppercase or all lower case path/fileName

    set fn [string toupper $fileName]

    if {$ctrlVals(version) == "WIN95" || $ctrlVals(version) == "WIN98"} {
        set fn [unixToDos [file join [cdromRootDirGet] $fn]]
    } else {
        set fn [file join [cdromRootDirGet] $fn]
    }
    if {[file exists $fn]} {
        return $fn
    }

    set fn [string tolower $fileName]
    if {$ctrlVals(version) == "WIN95" || $ctrlVals(version) == "WIN98"} {
        set fn [unixToDos [file join [cdromRootDirGet] $fn]]
    } else {
        set fn [file join [cdromRootDirGet] $fn]
    }
    if {[file exists $fn]} {
        return $fn
    }

    if {$ctrlVals(version) == "WIN95" || $ctrlVals(version) == "WIN98"} {
        set fn [unixToDos [file join [cdromRootDirGet] $fileName]]
    } else {
        set fn [file join [cdromRootDirGet] $fileName]
    }
    return $fn
}

##############################################################################
#
# tmpDirGet - returns the temporary directory.
#
# This routine returns the temporary directory set by the environment
# variable TMP.  For debugging purposes and to use the tcl debugger, setting
# the environment variable TCL_DEBUG will return the [windHostType]/lib
# directory in the current view.  If the temp directory has not been set,
# an empty string is returned.
#
# SYNOPSIS:
# tmpDirGet
#
# PARAMETERS: N/A
#
# RETURNS: /vobs/wpwr/host/[windHostTypeGet] if env(TCL_DEBUG) exists,
#          the value set by the environment variable TMP, or the empty
#          string if neither exists.
#
# ERRORS: N/A
#

proc tmpDirGet {} {
    global env

    if {[info exists env(TCL_DEBUG)]} {
        return /vobs/wpwr/host/[windHostTypeGet]/lib
    }

    if {[info exists env(TMP)]} {
        return $env(TMP)
    } else {
        return ""
    }
}

##############################################################################
#
# uninstHomeDirGet - returns the uninstall home directory.
#
# This routine returns the uninstall home directory set by
# setupVals(uninstHomeDir).  If the uninstall home directory has not
# been set, an empty string is returned.
#
# SYNOPSIS:
# uninstHomeDirGet
#
# PARAMETERS: N/A
#
# RETURNS: the installation key if it exists, else an empty string.
#
# ERRORS: N/A
#

proc uninstHomeDirGet {} {
    global setupVals

    if {[info exists setupVals(uninstHomeDir)]} {
        return $setupVals(uninstHomeDir)
    } else {
        return ""
    }
}

##############################################################################
#
# uninstHomeDirSet - sets the uninstall home directory.
#
# Sets the global variable setupVals(uninstHomeDir) to the uninstall
# home directory.
#
# SYNOPSIS:
# uninstHomeDirSet val
#
# PARAMETERS:
# <val>
# Contains the uninstall home directory.
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc uninstHomeDirSet {val} {
    global setupVals

    set setupVals(uninstHomeDir) $val
}

##############################################################################
#
# destDirDispGet - returns the destination directory with slashes displayed
#                  in Unix format.
#
# Returns the destination directory to be displayed to the user.  Slashes
# are converted to Unix format.
#
# SYNOPSIS:
# destDirDispGet
#
# PARAMETERS: N/A
#
# RETURNS: the destination directory with slashes converted to Unix format.
#
# ERRORS: N/A
#

proc destDirDispGet {} {

    set destDir [destDirGet]
    if {$destDir != ""} {
        set destDir [dosToUnix $destDir]
    }
    return $destDir
}

##############################################################################
#
# destDirGet - returns the destination directory.
#
# This routine returns the destination directory location to install
# the files for the product(s).  If the destination directory has not
# been set, an empty string is returned.
#
# SYNOPSIS:
# destDirGet
#
# PARAMETERS: N/A
#
# RETURNS: the destination directory if it exists, else an empty string.
#
# ERRORS: N/A
#

proc destDirGet {} {
    global setupVals

    if {[info exists setupVals(destDir)]} {
        if { [isUnix] } { 
            return [dosToUnix $setupVals(destDir)] 
        } else {
            return [unixToDos $setupVals(destDir)] 
        }
    } else {
        return ""
    }
}

##############################################################################
#
# destDirSet - sets the destination directory.
#
# Sets the global variable setupVals(destDir) to the destination directory.
#
# SYNOPSIS:
# destDirSet val
#
# PARAMETERS:
# <val>
# Contains the destination directory.
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc destDirSet {val} {
    global setupVals

    set setupVals(destDir) $val
}

##############################################################################
#
# sysDirGet - returns the Windows system directory.
#
# This routine returns the Windows system directory.  If the system directory
# has not been set, an empty string is returned.
#
# SYNOPSIS:
# sysDirGet
#
# PARAMETERS: N/A
#
# RETURNS: the system directory if it exists, else an empty string.
#
# ERRORS: N/A
#

proc sysDirGet {} {
    global setupVals

    if {[info exists setupVals(sysDir)]} {
        return $setupVals(sysDir)
    } else {
        return ""
    }
}

##############################################################################
#
# sysDirSet - sets the system directory.
#
# Sets the global variable setupVals(sysDir) to the Windows system directory.
#
# SYNOPSIS:
# sysDirSet val
#
# PARAMETERS:
# <val>
# Contains the system directory.
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc sysDirSet {val} {
    global setupVals

    set setupVals(sysDir) $val
}

##############################################################################
#
# cdromBinDirGet - returns the host-specific CD-ROM executable files.
#
# This routine returns the CD-ROM directory containing the host-specific
# binary and executable files, for example env(CD_ROOT)/SUN4/SOLARIS2, 
# env(CD_ROOT)\X86\WIN32, or env(CD_ROOT)/X86/LINUX2. If the bin directory 
# has not been set an empty string is returned.
#
# SYNOPSIS:
# cdromBinDirGet
#
# PARAMETERS: N/A
#
# RETURNS: the bin directory if it exists, else an empty string.
#
# ERRORS: N/A
#

proc cdromBinDirGet {} {
    global env

    if {[info exists env(CD_BIN)]} {
        return $env(CD_BIN)
    } else {
        return ""
    }
}

##############################################################################
#
# windHostTypeGet - returns the WIND_HOST_TYPE.
#
# This routine returns the WIND_HOST_TYPE set by the global variable
# setupVals(windHostType).  If the WIND_HOST_TYPE has not been set,
# an empty string is returned.
#
# SYNOPSIS:
# windHostTypeGet
#
# PARAMETERS: N/A
#
# RETURNS: the WIND_HOST_TYPE if it exists, else an empty string.
#
# ERRORS: N/A
#

proc windHostTypeGet {} {
    global setupVals

    if {[info exists setupVals(windHostType)]} {
        return $setupVals(windHostType)
    } else {
        return ""
    }
}

##############################################################################
#
# windHostTypeSet - sets the WIND_HOST_TYPE.
#
# Sets the global variable setupVals(windHostType) to the WIND_HOST_TYPE.
#
# SYNOPSIS:
# windHostTypeSet val
#
# PARAMETERS:
# <val>
# Contains the WIND_HOST_TYPE [x86-win32 | sun4-solaris2 | 
#                             parisc-hpux10 | x86-linux2]. 
# RETURNS: N/A
#
# ERRORS: N/A
#

proc windHostTypeSet {val} {
    global setupVals

    set setupVals(windHostType) $val
}

##############################################################################
#
# lastErrorGet - returns the last setup error.
#
# This routine returns the last setup error set by the global variable
# setupVals(lastError).  If the last error has not been set, an empty string
# is returned.
#
# SYNOPSIS:
# lastErrorGet
#
# PARAMETERS: N/A
#
# RETURNS: the last error if it exists, else an empty string.
#
# ERRORS: N/A
#

proc lastErrorGet {} {
    global setupVals

    if {[info exists setupVals(lastError)]} {
        return $setupVals(lastError)
    } else {
        return ""
    }
}

##############################################################################
#
# lastErrorSet - sets the last setup error and increments the error count.
#
# Sets the global variable setupVals(lastError) to the last setup error
# and increments the value of setupVals(errorCount).
#
# SYNOPSIS:
# lastErrorSet val
#
# PARAMETERS:
# <val>
# Contains the last setup error.
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc lastErrorSet {val} {
    global setupVals

    set setupVals(lastError) $val
    incr setupVals(errorCount)
}

##############################################################################
#
# lastErrorMsgSet - sets the last setup error.
#
# Sets the global variable setupVals(lastError) to the last setup error.
# Note that unlike lastErrorSet the errorCount is not incremented.
#
# SYNOPSIS:
# lastErrorMsgSet val
#
# PARAMETERS:
# <val>
# Contains the last setup error.
# RETURNS: N/A
#
# ERRORS: N/A
#

proc lastErrorMsgSet {val} {
    global setupVals

    set setupVals(lastError) $val
}

##############################################################################
#
# errorCountGet - returns the error count.
#
# This routine returns the error count recorded by the global variable
# setupVals(errorCount).
#
# SYNOPSIS:
# errorCountGet
#
# PARAMETERS: N/A
#
# RETURNS: the error count.
#
# ERRORS: N/A
#

proc errorCountGet {} {
    global setupVals

    if {[info exists setupVals(errorCount)]} {
        return $setupVals(errorCount)
    } else {
        return 0
    }
}

##############################################################################
#
# arFlagsSet - sets the arflags for the current product index.
#
# Sets the global variable arFlags([currentIndexGet]) for the current
# product index.
#
# SYNOPSIS:
# arFlagsSet val
#
# PARAMETERS:
# <flags>
# Contains the arflags for the current product index.
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc arFlagsSet {flags} {
    global arFlags

    set arFlags([currentIndexGet]) $flags
}

##############################################################################
#
# arFlagsGet - returns the arFlags given the product index number.
#
# This routine returns the arFlags for the specified index based on the
# value of the global array arFlags($index).  If no value has been set
# the default flags "-crus" are returned.
#
#
# SYNOPSIS:
# cdromDescGet
#
# PARAMETERS:
# <index>
# The product index number.
#
# RETURNS: the arflags for the specified product index, otherwise
#          the default "-crus" if no arflags have been specified.
#
# ERRORS: N/A
#

proc arFlagsGet {index} {
    global arFlags

    if ![info exists arFlags($index)] {
        set arFlags($index) "-crus"
    }
    return $arFlags($index)
}

##############################################################################
#
# currentIndexSet - sets the current product index.
#
# Sets the global variable currentIndex to the specified product
# index.
#
# SYNOPSIS:
# currentIndexSet index
#
# PARAMETERS:
# <index>
# The current product index.
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc currentIndexSet {index} {
    global currentIndex

    set currentIndex $index
}

##############################################################################
#
# currentIndexGet - returns the current product index.
#
# This routine returns the current product index set by the global
# variable currentIndex.  If no value has been set an empty string is
# returned.
#
# SYNOPSIS:
# currentIndexGet
#
# PARAMETERS: N/A
#
# RETURNS: the current product index if it exists, else an empty string.
#
# ERRORS: N/A
#

proc currentIndexGet {} {
    global currentIndex

    if {[info exists currentIndex]} {
        return $currentIndex
    } else {
        return ""
    }
}

##############################################################################
#
# tempDirGet - returns the temporary directory.
#
# This routine returns the temporary directory set by the environment
# variable TMP.
#
# SYNOPSIS:
# tempDirGet
#
# PARAMETERS: N/A
#
# RETURNS: the temporary directory.
#
# ERRORS:
# "Temp dir not set"
#

proc tempDirGet {} {
    global env

    if {[info exists env(TMP)]} {
        return $env(TMP)
    } else {
        error "Temp dir not set"
    }
}

##############################################################################
#
# exitMsgSet - sets the exit message.
#
# Sets the global variable exitMessage to the specified exit message.
#
# SYNOPSIS:
# currentIndexSet msg
#
# PARAMETERS:
# <msg>
# The exit message.
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc exitMsgSet {msg} {
    global exitMessage

    set exitMessage $msg
}

##############################################################################
#
# exitMsgGet - returns the exit message.
#
# This routine returns the exit message.  If it does not exist, it returns
# the message "Installation complete."
#
# SYNOPSIS:
# exitMsgGet
#
# PARAMETERS: N/A
#
# RETURNS: the exit message if it exists, else "Installation complete."
#
# ERRORS: N/A
#

proc exitMsgGet {} {
    global exitMessage

    if {![info exists exitMessage]} {
        set exitMessage "Installation complete."
    }

    return $exitMessage
}

##############################################################################
#
# defGroupSet - sets the default group.
#
# Sets the global variable defGroup to the specified default group.
#
# SYNOPSIS:
# defGroupSet group
#
# PARAMETERS:
# <group>
# The default group.
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc defGroupSet {group} {
    global defGroup setupVals

    if { [isTornadoProduct] } {
        if {[portMapperIconExist $group] == 1} {
            set defGroup $setupVals(defGroup)
        } else {
            set defGroup $group
        }
    } else {
        # non-tornado
        set defGroup $group
    }
}

##############################################################################
#
# defGroupGet - returns the default group.
#
# This routine returns the default group.  If it does not exist an empty
# string is returned.
#
# SYNOPSIS:
# defGroupGet
#
# PARAMETERS: N/A
#
# RETURNS: the default group if it exists, else an empty string.
#
# ERRORS: N/A
#

proc defGroupGet {} {
    global defGroup

    if ![info exists defGroup] {
        set defGroup ""
    }

    return $defGroup
}

##############################################################################
#
# dirSizeGet - returns the size of a directory
#
# This routine returns the size of a directory
#
# SYNOPSIS:
# setupSizeGet
#
# PARAMETERS: path
#
# RETURNS:  the size of given directory or 0 if path is not a directory
#
# ERRORS: N/A
#

proc dirSizeGet {path} {

    if {[file isdirectory $path] == 0} {
        return 0
    }

    set totsz 0
    set list [glob $path/*]

    foreach file $list {
        set totsz [expr $totsz + [file size [file join $path $file]]]
    }
    return $totsz
}


##############################################################################
#
# setupSizeGet - returns the size of setup directory
#
# This routine returns the size of setup directory
#
# SYNOPSIS:
# setupSizeGet
#
# PARAMETERS: N/A
#
# RETURNS:  the size of setup directory
#
# ERRORS: N/A
#

proc setupSizeGet {} {

    set docSize 0
    set path [file join [cdromRootDirGet] DOCS]
    set docSize [byteToMbyte [dirSizeGet $path]]

    switch [windHostTypeGet] {
        x86-win32 {
            return [expr 10.9 + $docSize]
        }
        sun4-solaris2 {
            return [expr 13.0 + $docSize]
        }
        parisc-hpux10 {
            return [expr 14.3 + $docSize]
        }
        default {
            return [expr 10.9 + $docSize]
        }
    }
}

##############################################################################
#
# instTypeSet - sets the installation type.
#
# Sets the global variable instType to the installation type (for example,
# "icon" for an icon-only installation).
#
# SYNOPSIS:
# instTypeSet type
#
# PARAMETERS:
# <type>
# The installation type.
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc instTypeSet {type} {
    global instType

    set instType $type
}

##############################################################################
#
# instTypeGet - returns the installation type.
#
# This routine returns the installation type (for example, "icon" for
# an icon-only installation).  If the installation type has not been
# set, an empty string is returned.
#
# SYNOPSIS:
# userNameGet
#
# PARAMETERS: N/A
#
# RETURNS: the installation type if it exists, else an empty string.
#
# ERRORS: N/A
#

proc instTypeGet {} {
    global instType

    if ![info exists instType] {
        set instType ""
    }

    return $instType
}

##############################################################################
#
# checkPathLen - checks the path length and trims the path if necessary.
#
# This routine checks the length of a given path.  If the length is
# over 50 characters, part of the path is replaced with "..."  This
# allows a long path to fit in a dialog window.
#
# SYNOPSIS:
# checkPathLen path
#
# PARAMETERS:
# <path>
# A directory path.
#
# RETURNS: The original path partially replaced with "..." if over
#          50 characters.
#
# ERRORS: N/A
#

proc checkPathLen {path} {

    if {[string length $path] >= 50} {
        set totLen [string length $path]
        set lastIndex [string last "/" $path]
        if {$lastIndex > [string last "\\" $path]} {
            # Unix type path

            set path2 [string range $path 0 [expr $lastIndex - 1]]
            set fname [string range $path [expr $lastIndex + 1] $totLen]
            set lastIndex2 [string last "/" $path2]
            while {[expr [string length $path2] + [string length $fname] + 5] \
                >= 50} {
                set path2 [string range $path2 0 [expr $lastIndex2 -1]]
                set lastIndex2 [string last "/" $path2]
                if {$lastIndex2 == -1} {
                    break;
                }
            }
           set path [format "%s/.../%s" $path2 $fname]

        } else {
            # DOS type path

            set lastIndex [string last "\\" $path]
            set path2 [string range $path 0 [expr $lastIndex - 1]]
            set fname [string range $path [expr $lastIndex + 1] $totLen]
            set lastIndex2 [string last "\\" $path2]
            while {[expr [string length path2] + [string length $fname] + 5] \
                >= 50} {
                set path2 [string range $path2 0 [expr $lastIndex2 -1]]
                set lastIndex2 [string last "\\" $path2]
                if {$lastIndex2 == -1} {
                    break;
                }
            }
            set $path [format "%s\\...\\%s" $path2 $fname]

        }
    }
    return $path
}

#############################################################################
#
# fspace - returns free space available on Unix hosts
#
# This procedure returns the amount of free space avaiable on the given drive.
#
# SYNOPSIS:
# fspace dir
#
# PARAMETERS:
# <dir>
# a directory path.
#
# RETURNS: the number of free space in kilobytes avaiable
#
# ERRORS: N/A
#

proc fspace {dir} {

    if {![file isdirectory $dir]} {
        return "$dir: bad directory name"
    }

    # get the directory name in extension

    set here [pwd]
    cd $dir
    set dir [pwd]

    set free "unknown"

    switch [windHostTypeGet] {
        sun4-solaris2 -
        x86-linux2 {
            if {![catch {exec /bin/df -k $dir} result]} {
                set free [lindex $result 10]
            } else {
                set free [lindex $result 10]
            }
        }
        parisc-hpux10 {
            set found 0
            set ix 0
            while {$found == 0} {
                incr ix
                if {$ix > 30} {
                    break
                }
                if {[catch "exec /bin/df $dir" res]} {
                    # go backward one step looking for actual mounting
                    # point or device name alias
                    set dir [file dirname $dir]
                } else {
                    set freeSize [lindex [exec /bin/df -k $dir | /bin/sed -e "/total/d" -e "/used/d" ] 0]
                    if {[regexp {[^0-9]+} $freeSize] == 0} {
                        set free $freeSize
                    }
                    set found 1
                }
            }
        }
        default {}
    }
    cd $here
    return $free
}

##############################################################################
#
# debug - turns on debug mode
#
# SYNOPSIS
# debug
#
# PARAMETERS: N/A
#
# RETURNS: true if the environment var SETUP_DEBUG exists, otherwise false
#
# ERRORS: N/A
#

proc debug {} {
    global env
    global setupVals

    if {[info exists env(SETUP_DEBUG)]} {
        return 1
    } else {
        return 0
    }
}

##############################################################################
#
# openSetupDebugLog - open the setup log file
#
# SYNOPSIS
# openSetupDeubgLog
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc openSetupDebugLog {} {
    global env setupVals

    if {[info exists env(SETUP_DEBUG)] && $env(SETUP_DEBUG) != 0} {
        if {[info exists env(SETUP_DBGLOGFILE)]} {
            if {![info exists setupVals(DBGLOG_FD)]} {
                if {[catch {open $env(SETUP_DBGLOGFILE) "w"} setupVals(DBGLOG_FD)]} {
                    puts "Can't open $env(SETUP_DBGLOGFILE)"
                }
            }
        }
    }
    if {[info exists env(INF_DEBUG)] &&  $env(INF_DEBUG) != 0} {
        if {[info exists env(SETUP_DBGLOGFILE)]} {
            if {![info exists setupVals(DBGLOG_FD)]} {
                if {[catch {open $env(SETUP_DBGLOGFILE) "w"} setupVals(DBGLOG_FD)]} {
                    puts "Can't open $env(SETUP_DBGLOGFILE)"
                }
            }
        }
    }
}

##############################################################################
#
# closeSetupDebugLog - close the setup log file
#
# SYNOPSIS
# closeSetupLog
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc closeSetupDebugLog {} {
    global env
    global setupVals

    if {[info exists setupVals(DBGLOG_FD)]} {
        catch {close $setupVals(DBGLOG_FD)}
    }
}

#############################################################################
#
# dbgputs - wrapper for debug puts function.
#
# Wrapper for the puts function.  Only prints out the specified string
# either to the setup debug log file in env(SETUP_DBGLOGFILE) or the console,
# if the environment variable SETUP_DEBUG exists and is set to a nonzero value.
#
# SYNOPSIS
# dbgputs <line>
#
# PARAMETERS:
#   line : string to output.
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc dbgputs {line} {
    global env
    global setupVals

    if {[info exists env(SETUP_DEBUG)]} {
        if {$env(SETUP_DEBUG) != 0 && [info exists setupVals(DBGLOG_FD)]} {
            puts $setupVals(DBGLOG_FD) $line
            flush $setupVals(DBGLOG_FD)
        } else {
            puts $line
        }
    }
}

#############################################################################
#
# fileContentGet - return the content of a file as a string
#
# This procedure opens a file and return the content of the file as a
# string separated by new lines
#
# SYNOPSIS
# .tS
# fileContentGet <file>
# .tE
#
# PARAMETERS:
# .IP file
# file name relative to the root of the CD
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc fileContentGet {file} {

    set file [cdFileNameGet $file]

    if {[file exists $file] == 0} {
        puts "Error: $file does not exists."
        return
    }

    if [catch {open $file r} infile] {
        puts "Error: can't open $file"
        return
    }

    set contents ""
    foreach line  [split [read $infile] \n] {
        string trimright $line
        append contents [format "%s\r\n" $line]
    }
    close $infile

    return $contents
}


proc licFileGet {} {
    global setupVals

    if {[info exists setupVals(licFile)]} {
        return $setupVals(licFile)
    } else {
        return ""
    }
}

proc licFileSet {licFile} {
    global setupVals

    set setupVals(licFile) $licFile

}


##############################################################################
#
# authCodeGet - returns the Authorization Code.
#
# This routine returns the user authorization code to access WRS database
#
# SYNOPSIS:
# authCodeGet
#
# PARAMETERS: N/A
#
# RETURNS: the Authorization Code if it exists, else an empty string.
#
# ERRORS: N/A
#

proc authCodeGet {} {
    global setupVals

    if {[info exists setupVals(authCode)]} {
        return $setupVals(authCode)
    } else {
        return ""
    }
}

##############################################################################
#
# authCodeSet - sets the Authorization Code
#
# Sets the global variable setupVals(authCode) to the authorization code
#
# SYNOPSIS:
# authCodeSet val
#
# PARAMETERS:
# <val>
# Contains the authorization code
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc authCodeSet {val} {
    global setupVals

    set setupVals(authCode) $val
}


##############################################################################
#
# tornadoProductCheck - checks if product name is a Tornado object.
#
# Returns whether the specified product is a Tornado object.  First the name
# of the product is checked that it begins with the word "tornado."  If so,
# it is then compared against the list of product names that are NOT tornado
# objects, such as tornado-bsp.  As a final check, the product description
# is checked to make sure it begins with the description "Tornado."
#
# SYNOPSIS:
# tornadoProductCheck productName productDesc
#
# PARAMETERS:
# <productName>
# Name of the product.
#
# <productDesc>
# Description of the product.
#
# RETURNS: 1 if product is a Tornado object, 0 otherwise.
#
# ERRORS: N/A
#

proc tornadoProductCheck {productName productDesc} {
    if {$productName == "tornado"} {
        return 1
    }
        
    if {[regexp {^tornado(-)?(.+)?} $productName match dash type]} {
                
        # Edit the following list to modify the product names that are
                # not Tornado objects.  For example, tornado-bsp* and
                # tornado-comp* are not Tornado objects.  ^ means
                # "string begins with" in tcl.
                
        switch -regexp $type {
                        ^core.* -
                        ^bsp.* -
                        ^comp.* -
                        ^src.* {
                return 0
                        }
                        default {
                                # make sure also that the product description begins
                                # with "Tornado."
                                
                                if {[regexp {^Tornado.*} $productDesc match]} {
                                        return 1
                                } else {
                    return 0
                                }
                        }
                }
    } else {
        return 0
    }
}

##############################################################################
#
# licensedProductCheck - checks if product name is a licensed product.
#
# This procedure checks if a product is a licensed product, given a 
# featureId. A licensed product has a non-zero featureId.
#
# SYNOPSIS:
# licensedProductCheck featureID
#
# PARAMETERS:
# <featureID>
# Feature ID of the product
#
# RETURNS: 1 if product is a licensed product, 0 otherwise.
#
# ERRORS: N/A
#
proc licensedProductCheck {featureID} {
    if { $featureID > 0 } {
        return 1  
    } else {
        return 0
    }
}


##############################################################################
#
# hostIdGen - Generates the host Id
#
# This routine generates the host Id from flexlm lmhostid call. If there is 
# no NIC card, it will proble for the Volume Serial Number (windows only)
#
# SYNOPSIS:
# hostIdGen
#
# PARAMETERS:
#     For Windows use
#         "vsn":      Retrieve drive c: serial number (for Windows)
#     For UNIX, no argument needed
#
# RETURNS:
#     host id from lmhostid call
#
# ERRORS: N/A
#

proc hostIdGen {{arg ""}} {
    global env setupVals

    set hostId ""
    if {"$arg" == ""} {
        set option ""
    } else {
        set option "-$arg"
    }
    
    if {[isUnix]} {
        if { [file exists $env(CD_BIN)/lmutil] } {
            if { ![catch {exec $env(CD_BIN)/lmutil lmhostid -n} id] } {
                set hostId $id
            } else {
                messageBox "INVALID HOST ID: $id\nSETUP will terminate.\n"
                return -1
            }
        }
    } else { # windows

        if { [file exists $env(CD_BIN)/lmutil.exe] } {           
            
            if { [catch {exec $env(CD_BIN)/lmutil.exe \
                                        lmhostid $option -n} hostId] } { 
                messageBox "Failed retrieving hostID: $hostId"
                set setupVals(cancel) 1                
                applicationExit
                return 0                    
            }
            
            # if no NIC card 
            if {"$hostId" == "ffffffff"} {
                if {[catch {exec $env(CD_BIN)/lmutil.exe \
                                        lmhostid -vsn -n} hostId]} { 
                    messageBox "Failed retrieving hostID (vsn): $hostId"
                    set setupVals(cancel) 1                
                    applicationExit
                    return 0                
                } 
            }
            
        }
    }
    dbgputs "hostID: $hostId"
    return $hostId
}

############################################################################
#
# hostOSGet - return the host OS version
#
# This routine return the host OS version
#
# SYNOPSYS:
# hostOSGet
#
# PARAMETERS: n/a
#
# RETURNS: host OS version in string format or Error
#
# ERRORS: N/A
#
proc hostOSGet {} {
    set hostOS ""

    if {[isUnix]} {
        catch {exec uname -a} hostOS
    } else {
        if [catch {setupWinVerGetEx} hostOS] {
            puts "error: $hostOS"
        }
    }

    return $hostOS
}


#############################################################################
#
# isWRSStandAlone - determine whether the product is a Wind River
#                   stand-alone product
#
# This procedure determines whether the product is a Wind River stand-alone 
# product (i.e. whether this product is installed separate from the Tornado
# tree. If the product is a Wind River stand-alone, then tornado-centric 
# codes will not be executed by SETUP (see more details in CONFIG.TCL)
#
# SYNOPSIS
# .tS
# isWRSStandAlone
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: 0 if not WRS stand-alone
#          1 if WRS stand-alone
#
# ERRORS: N/A
#

proc isWRSStandAlone {} {
    global WRS_STAND_ALONE

    return $WRS_STAND_ALONE
}

#############################################################################
#
# isTornadoProduct - determine whether the CD is a standard Tornado 
#                    installation
#
# This procedure determines whether the product is a standard Tornado
# installation (i.e. whether this product is made for Tornado and is installed 
# into a Tornado tree). Tornado-centric codes will be executed by SETUP.
#
# SYNOPSIS
# .tS
# is
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: 0 if non-Tornado product
#          1 if Tornado product
#
# ERRORS: N/A
#

proc isTornadoProduct {} {
    global TORNADO_PRODUCT

    return $TORNADO_PRODUCT
}

#############################################################################
#
# isStandAlone - determine if the product is FULLY a stand-alone product
#
# This procedure determines if the product is FULLY a stand-alone product
# (i.e. whether this product is installed separate from the Tornado tree) 
# and is NOT part of Wind River products (see more details in CONFIG.TCL).
#
# SYNOPSIS
# .tS
# isStandAlone
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: 0 if not a FULL stand-alone
#          1 if a FULL stand-alone
#
# ERRORS: N/A
#
#
proc isStandAlone {} {
    global STAND_ALONE

    return $STAND_ALONE
}

############################################################################
#
# isNumeric
#
# This routine checks that a value is all numeric
#
# SYNOPSYS:
# isAllNumeric value title control
#
# PARAMETERS:
# the value to be accessed
# an optional title for the message box.
# an optional window.control value to write valid numbers to
#
# RETURNS: 1 if value passed is all numeric, else returns 0
#
# ERRORS: N/A
#

proc isNumeric {value {title "Numeric Input Error"} {control foo}} {
    global ctrlVals

    regexp {[0-9]*} $value match
    set allNums $match
    set lenAllNums [string length $allNums]
    set lenValue [string length $value]

    if {$lenAllNums != $lenValue} {
        if {[controlExists $control]} {

            if { $ctrlVals(useInputScript) } {
                autoSetupLog "Error: This field must be numeric."
                autoSetupLog "Application Exit\n"
                set setupVals(cancel) 1                
                applicationExit
                return 0
            } else {
                dialog ok_with_title $title \
                       "This field must be numeric, please re-enter the number."
                controlValuesSet $control $allNums
            }
        }
        return 0
    } else {
        return 1
    }
}

#############################################################################
#
# isGUImode - determine whether SETUP is run on GUI mode or TEXT mode
#
# This procedure will determine whether  SETUP is run on GUI mode or TEXT mode
#
# SYNOPSIS
# .tS
# isGUImode
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: 0 if SETUP is run on TEXT mode
#          1 if SETUP is run on GUI mode
#
# ERRORS: N/A
#

proc isGUImode {} {
    global setupVals

    if { $setupVals(cmdMode) != "text" } {
        return 1;
    } else {
        return 0;
    }
}

#############################################################################
#
# isBSPcd - determine whether user is installing a BSP CD
#
# This procedure will check the DISK_ID file of the CD image to determine
# whether user is running a BSP CD installation
#
# SYNOPSIS
# .tS
# isBSPcd
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: 1 if SETUP is running a BSP CD installation
#          0 if otherwise (i.e. running a core CD)
#
# ERRORS: N/A
#

proc isBSPcd {} {
    global setupVals

    return $setupVals(BSPcd)
}

##############################################################################
#
# tornadoVersionSet - sets the Tornado Version
#
# Sets the global variable setupVals(torVersionNum) 
#
# SYNOPSIS:
# tornadoVersionSet val
#
# PARAMETERS:
# <val>
# Contains the Tornado Version
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc tornadoVersionSet {val} {
    global setupVals

    set setupVals(torVersionNum) $val
}

##############################################################################
#
# tornadoVersionGet - returns the Tornado Version
#
# This routine returns the Tornado Version.  If it does not exist an empty
# string is returned.
#
# SYNOPSIS:
# tornadoVersionGet
#
# PARAMETERS: N/A
#
# RETURNS: the Tornado Version if it exists, else an empty string.
#
# ERRORS: N/A
#

proc tornadoVersionGet {} {
    global setupVals

    if {[info exists setupVals(torVersionNum)]} {
        set v $setupVals(torVersionNum)
    } else {
                set v ""
    }

    return $v
}

##############################################################################
#
# tornadoDefaultGroupSet - sets the default Tornado Program Group name
#
# Sets the global variable setupVals(torVersionNum)
#
# SYNOPSIS:
# tornadoDefaultGroupSet val
#
# PARAMETERS:
# <val>
# Contains the Tornado Program Group name
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc tornadoDefaultGroupSet {val} {
    global setupVals

    set setupVals(defGroup) $val
}

##############################################################################
#
# tornadoDefaultGroupGet - returns the default Tornado Program Group name
#
# This routine returns the default Tornado Program Group name.  
# If it does not exist an empty string is returned.
#
# SYNOPSIS:
# tornadoDefaultGroupGet
#
# PARAMETERS: N/A
#
# RETURNS: the Tornado Program Group name if it exists, else an empty string.
#
# ERRORS: N/A
#

proc tornadoDefaultGroupGet {} {
    global setupVals

    if {[info exists setupVals(defGroup)]} {
        set v $setupVals(defGroup)
    } else {
        set v ""
    }

    return $v
}

##############################################################################
#
# wrsLicenseGet - returns the customer's WRS license number 
#
# This routine uses the Setup shared library function to return the customer's
# WRS license number.   
#
# SYNOPSIS:
# wrsLicenseGet
#
# PARAMETERS: N/A
#
# RETURNS: the WRS license number, or 0 if error.   
#
# ERRORS: N/A
#

proc wrsLicenseGet {} {
    if [catch {setupLicenseNumGet} lic] {
        dbgputs "wrsLicenseGet error: $lic"
	return 0
    } else {
        return $lic
    }
}

#############################################################################
#
# lunique - return a new list with unique elements of the old list
#
# This procedure will return a new list with unique elements of the old list
#
# SYNOPSIS
# .tS
# lunique
# .tE
#
# PARAMETERS:
# .IP oldList
# a list of elements
#
# RETURNS: a new list with unique elements of the old list
#
# ERRORS: N/A
#

proc lunique {oldList} {

    set newList ""

    foreach item $oldList {
        if { [lsearch -exact $newList $item] == -1} {
            lappend newList $item
        }
    }

    return $newList
}

#############################################################################
#
# lsubstringAppend - inserts a string into a list, its position determined
#                    by whether the string is a substring of an item already
#                    in the list.
#
# This procedure inserts a string into a list of strings.  It checks whether
# the string is a substring of an item in the list.  If so, it inserts
# the substring after the last occurrence of a pattern match.  For example,
# "gnu" is added after "sfgnule sfgnu".  If there is no pattern match, the
# string is added to the front of the list.
#
# This procedure is used by toolsetExtract, which needs to ensure that
# the toolset list orders the tools with unique tool strings coming first,
# e.g. "sfgnule sfgnu gnule gnu".
#
# SYNOPSIS
# .tS
# lsubstringAppend <list> <newitem>
# .tE
#
# PARAMETERS:
#     list: a list of strings
#     newitem: string to be added to the list
#
# RETURNS: a list of strings sorted with substrings coming last
#
# ERRORS: N/A
#

proc lsubstringAppend {list newitem} {  
    if {[llength $list] == 0} {
        set list $newitem
    } else {        
        # check if newitem is a substring of any string in the list

        set stringMatch [string first $newitem $list]

        if {$stringMatch == -1} {
            # no match, just concat the string to the front of the list

            set list [concat $newitem $list]
        } else {
            # find the last string the newitem is a substring of
            # and insert the newitem after that string

            for {set i 0} {$i < [llength $list]} {incr i} {
                set item [lindex $list $i]
                if {[string first $newitem $item] != -1} {
                    set matchPosition [expr $i + 1]
                } 
            }

            set list [linsert $list $matchPosition $newitem]
        } 
    }
    return $list
}

global LicInfoGetAllRequest LicFileConfigRequest CommitRequest AuthorizePinRequest
set LicInfoGetAllRequest 1
set LicFileConfigRequest 2
set CommitRequest        3
set AuthorizePinRequest  4

