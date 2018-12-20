# FLEXCOPY.TCL  - Setup procedures for implementing LM file-copying 
#                 wizard page
#
# Copyright 1999 Wind River Systems, Inc
#
# modification history
# --------------------
# 03f,13jan03,wmd  Fix SPR #85621, Setup declares a license file invalid, fix
#                  so license file check always returns valid.
# 03e,07jun02,wmd  Need to fix SPR 78461, skip over proprietary information in
#                  license file.
# 03d,03apr02,wmd  Fix SPR #75050, no need to call Authorize Pin request if
#                  PIN = 0, and add new Flexlm key words to validate license
#                  file.
# 03c,05mar02,bwd  Modified SETUP to be non-tornado centric
# 03b,17sep01,bwd  Fixed spr 69435 and 69699
# 03a,12jun01,j_w  Modified for Tornado 2.2
# 01u,20nov00,bwd  Fixed TCL error for TEXT mode
# 01t,01nov00,bwd  SPR 35597: hide HELP button. Disable all other buttons
#                  because they cannot be used during flexLM copying
# 01s,09oct00,j_w  Added the -F option (copy FlexLM files)
# 01r,27sep00,bwd  Set LMHelpPath global variable to "sysadmin" to identify
#                  which help IDs set to use
# 01q,07jul00,j_w  Set lmVals(reload) to 1 if lmVals(reloadExistingLicense) is
#                  set to 1
# 01p,28jun00,bwd  Changed host checking to use windHostTypeGet instead of
#                  env(WIND_HOST_TYPE)
# 01o,23jun00,wmd  Fix a typo.
# 01n,20jun00,wmd  remove displaying of setup icon in banner for linux.
# 01m,26apr00,j_w  Defined ctrlVals in flexlmFilesCopyCallBack
# 01l,10feb00,j_w  Fix logging to setup.log for LM files
# 01k,09feb00,j_w  Copy flexlm.cpl only if timestamp is newer than the
#                  existing one
# 01j,01feb00,bwd  Fixed error handling for test automation
# 01i,13jan00,bwd  Added codes to display this page for TEXT MODE
# 01h,24nov99,j_w  Copy FLEXlm File Manager files onto NT system32 directory
#                  and remove "after 2000"
# 01g,22nov99,j_w  Fixed destination directory
# 01f,16nov99,j_w  Fixed license file validation
# 01e,16nov99,bwd  Corrected destDir info for autoSetup.log
# 01d,16nov99,j_w  Fixed flexLM files copying on unix
# 01c,16nov99,j_w  Made the page invisible during files copying
# 01b,10nov99,j_w  Add Procedures for copying flexlm files and validate 
#                  existing license file
# 01a,16Sep99,j_w  written
#

#############################################################################
#
# pageCreate(lmFilesCopy) - install files onto user's destination directory 
#
# This procedures copies FLEXlm related files onto WIND_BASE/<hostType>/bin
# directory
#
# SYNOPSIS
# .tS
# pageCreate(lmFilesCopy)
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc pageCreate(lmFilesCopy) {} {
    global ctrlVals lmVals setupVals

    set lmVals(lmLicenseFile) "[destDirGet]/.wind/license/WRSLicense.lic"
    set lmVals(lmLicenseFile) [dosToUnix $lmVals(lmLicenseFile)]

    dbgputs $lmVals(lmLicenseFile)

    if { [isGUImode] } {
        set ctrlVals(volatileFrm) ""
        set w [dlgFrmCreate "Copy License Management Files"]

        controlEnable $w.backButt 0
        controlEnable $w.nextButt 0
        controlEnable $w.cancelButt 0

        if { [isTornadoProduct] } {
            controlEnable wizardDialog.helpButt 1
        } else {
            controlEnable wizardDialog.helpButt 0
        }

        # test automation

        if { $ctrlVals(useInputScript) } {
            autoSetupLog "LM Files copy page:"
            autoSetupLog "\tLM Files Directory:\
                [file join [dosToUnix [destDirGet]] host [windHostTypeGet] bin]"
        }
    } else { # TEXT mode
        printPageTitle "Copy License Management Files"
    }

    nextCallback
}

#############################################################################
#
# pageProcess(lmFilesCopy) - process inputs from lmFilesCopy page
#
# This procedure will process inputs from filesCopy page
#
# SYNOPSIS
# .tS
# pageProcess(lmFilesCopy)
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: 1 or non-zero number if success; 0 if failed
#
# ERRORS: N/A
#

proc pageProcess(lmFilesCopy) {} {
    global setupVals ctrlVals lmVals
    global tmpWindow
    global LMHelpPath
    set retVal 1
        
    # copy flexLM files 
    flexlmFilesCopy
        
    # check if license file exists
    if { ![licFileExists] } {
        # lic file not exists, skip current license info page
        pageRemove currLicInfo
        dbgputs "\npageRemove currLicInfo"

        if {$lmVals(reloadExistingLicense) == 1} {
            set lmVals(reload) 1
        } else {
            set lmVals(reload) 0
        }

        set retVal 1
    } else { 
        dbgputs "license file exists!"
        set retVal [licFileValidCheck] 
    }

    set LMHelpPath "sysadmin"

    if { [isGUImode] } {
        controlHide wizardDialog.helpButt 0
        controlEnable wizardDialog.helpButt 1
        controlEnable wizardDialog.backButt 0
        controlEnable wizardDialog.nextButt 1
        controlEnable wizardDialog.cancelButt 1
    }

    return $retVal
}

#############################################################################
#
# flexlmFilesCopy - Copy flexLM files onto the user's tree
#
# SYNOPSIS
# .tS
# flexlmFilesCopy
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc flexlmFilesCopy {} {
    global ctrlVals setupVals env

    if { [isGUImode] } {    
        if { [windHostTypeGet] == "x86-linux2" } {
            dialogCreate \
                -name flexlmFilesCopyDlg \
                -notitle \
                -parent $ctrlVals(parentDialog) \
                -helpfile $setupVals(setupHelp) \
                -width 250 -height 32 \
                -init {
                    controlPropertySet flexlmFilesCopyDlg.message1 -bold 1; \
                    windowTimerCallbackSet flexlmFilesCopyDlg \
                    -milliseconds 200 flexlmFilesCopyCallBack \
                } \
                -controls [list \
                    [list label -name "message1" \
                                -title [strTableGet LM_FILESCOPY_BANNER] \
                                -x 40 -y 12 -w 200 -h 10] ]
        } else {
            dialogCreate \
                -name flexlmFilesCopyDlg \
                -notitle \
                -parent $ctrlVals(parentDialog) \
                -helpfile $setupVals(setupHelp) \
                -width 250 -height 32 \
                -init {
                    controlPropertySet flexlmFilesCopyDlg.message1 -bold 1; \
                    windowTimerCallbackSet flexlmFilesCopyDlg \
                    -milliseconds 200 flexlmFilesCopyCallBack \
                } \
                -controls [list \
                    [list bitmap -name bmp -stretch \
                                 -title "[cdFileNameGet \
                                      [file join RESOURCE BITMAPS SETUPICO.BMP]]" \
                                 -x 10 -y 5 -w 20 -h 20] \
                    [list label -name "message1" \
                                -title [strTableGet LM_FILESCOPY_BANNER] \
                                -x 40 -y 12 -w 200 -h 10] ]
        }

    } else { # TEXT mode
        puts "[strTableGet LM_FILESCOPY_BANNER]\n"
        flexlmFilesCopyCallBack
    }
}

#############################################################################
#
# flexlmFilesCopyCallBack - call back function of flexlmFilesCopyDlg
#
# This routine copies the flexLM files to the user's tree
# 
# SYNOPSIS
# .tS
# flexlmFilesCopyCallBack
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#
proc flexlmFilesCopyCallBack {} {
    global setupVals lmVals ctrlVals
        
    if { [isGUImode] } {    
        windowTimerCallbackSet flexlmFilesCopyDlg 0 ""
        beginWaitCursor
    }

    uninstLog setup "CD manufacturing time: [cdNameGet time]"

    if {[instTypeGet] == "flexInst"} {
        uninstLog setup \
                    "FlexLM Installation\t$setupVals(version)\t[destDirGet]"
    } else {
        uninstLog setup \
                    "[cdInfoGet number]\t$setupVals(version)\t[destDirGet]" 
    }

    # Append CD Info to the uninstall record
    uninstLog cdNumber "$setupVals(CDnumber)"

    # Add host OS to setup log
    uninstLog setup "[hostOSGet]"

    # copy flexLM Files
    # need to call dosToUnix first otherwise glob will not work

    if {[isUnix]} {
        set fileList [glob -nocomplain \
            [dosToUnix [cdromBinDirGet]]/lm* \
            [dosToUnix [cdromBinDirGet]]/wrsd ]
    } else {
        set fileList [glob -nocomplain \
            [dosToUnix [cdromBinDirGet]]/lm*.exe \
            [dosToUnix [cdromBinDirGet]]/wrsd.exe ]
    }

    if { "$fileList" == "" } {

        if { [isGUImode] } {
            if { $ctrlVals(useInputScript) } {
                autoSetupLog "Error: No FlexLM files are copied"
                autoSetupLog "Application Exit\n"
                set setupVals(cancel) 1                
                applicationExit
                return 0
            } else {
                messageBox "Error: No FlexLM files are copied"
            }
        } else {
            puts "Error: No FlexLM files are copied"
            while { [prompt "Press <Enter> to continue."] != "" } {
            }
        }

    } else {

        set binDir [file join \
                       [dosToUnix [destDirGet]] host [windHostTypeGet] bin]

        uninstLog setup "Installed License Management Files:"

        foreach file "$fileList" {
            set f [file tail $file]
            set destFile [file join $binDir $f]
                        
            # copy the file to windHostType/bin
            fileDup $file $destFile update

            dbgputs $destFile
            uninstLog setup "\t$destFile"

            if {![isUnix]} {
                file attributes $destFile -readonly 0
            }
        }
    }

    # Copy FLEXlm File Manager files onto NT system32 directory
    if {![isUnix]} {
        set ntSysDir [dosToUnix [sysDirGet]]
        
        set fileList [glob -nocomplain \
                         [dosToUnix [cdromBinDirGet]]/lmgr*.dll \
                         [dosToUnix [cdromBinDirGet]]/flexlm.cpl ]

        foreach file "$fileList" {
            set f [file tail $file]
            set destFile [file join $ntSysDir $f]

            set doCopy 0

            # validate time stamp
            if {[file exists $destFile]} {
                if {[file mtime $file] > [file mtime $destFile]} {
                    # src file newer then current file
                    set doCopy 1
                }
            } else {
                set doCopy 1
            }
        
            # copy the file to NT system32
            if {$doCopy} {
                if {[catch {file copy -force $file $destFile} err]} {

                    if { $ctrlVals(useInputScript) } {
                        autoSetupLog "$err"
                        autoSetupLog "Application Exit\n"
                        set setupVals(cancel) 1                
                        applicationExit
                        return 0
                    } else {
                        dialog ok_with_title "Copy Error" "$err"
                        uninstLog setup "Copy Error: $err"
                    }

                }
                dbgputs $destFile
                uninstLog setup "\t$destFile"

                file attributes $destFile -readonly 0
            }
        }
    }

    if { [isGUImode] } {    
        endWaitCursor
        windowClose flexlmFilesCopyDlg
    }
}

#############################################################################
#
# licFileExists - Check if an license file exists
#
# This routine check if an license file exists 
# 
# SYNOPSIS
# .tS
# licFileExists
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: 1 if exists, 0 if not
#
# ERRORS: N/A
#
proc licFileExists {} {
    global lmVals

    if {[file exists $lmVals(lmLicenseFile)] } {
        set retVal 1
    } else {
        set retVal 0
    }

    return $retVal
}

#############################################################################
#
# licFileValidCheck - validate the license file
#
# This routine validate the existing license file
# 
# SYNOPSIS
# .tS
# licFileValidCheck
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: 0 if failed, non-zero if success. Return num is the setup page to
#          jump to
#
# ERRORS: N/A
#
proc licFileValidCheck {} {
    global ctrlVals setupVals lmRetVal env

    if { [isGUImode] } {
        if { [windHostTypeGet] == "x86-linux2"} {
            dialogCreate \
                -name licFileValidCheckDlg \
                -notitle \
                -parent $ctrlVals(parentDialog) \
                -width 230 -height 32 \
                -init {
                    controlPropertySet licFileValidCheckDlg.message1 -bold 1; \
                    windowTimerCallbackSet licFileValidCheckDlg \
                    -milliseconds 200 licFileValidCheckCallback \
                } \
                -controls [list \
                    [list label -name "message1" \
                                -title [strTableGet LM_ANALYSIS_BANNER] \
                                -x 40 -y 12 -w 180 -h 10] ]
        } else {
            dialogCreate \
                -name licFileValidCheckDlg \
                -notitle \
                -parent $ctrlVals(parentDialog) \
                -width 230 -height 32 \
                -init {
                    controlPropertySet licFileValidCheckDlg.message1 -bold 1; \
                    windowTimerCallbackSet licFileValidCheckDlg \
                    -milliseconds 200 licFileValidCheckCallback \
                } \
                -controls [list \
                    [list bitmap -name bmp -stretch \
                                 -title "[cdFileNameGet \
                                  [file join RESOURCE BITMAPS SETUPICO.BMP]]" \
                                 -x 10 -y 5 -w 20 -h 20] \
                    [list label -name "message1" \
                                -title [strTableGet LM_ANALYSIS_BANNER] \
                                -x 40 -y 12 -w 180 -h 10] ]
        }
    } else { # TEXT mode       
        puts "[strTableGet LM_ANALYSIS_BANNER]\n"
        licFileValidCheckCallback
    }

    # lmRetVal is set in licFileValidCheckCallBack
    return $lmRetVal

}

#############################################################################
#
# licFileValidCheckCallback - Call back function for licFileValidCheck
#
# This routine validate the existing license file
# 
# SYNOPSIS
# .tS
# licFileValidCheckCallback
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: 0 if failed, non-zero if success. Return num is the setup page to
#          jump to
#
# ERRORS: N/A
#
proc licFileValidCheckCallback {} {
    global setupVals ctrlVals lmVals lmRetVal
    set retVal 1
    set errMsg ""
    set cannotOpen 0

    if { [isGUImode] } {
        windowTimerCallbackSet licFileValidCheckDlg 0 ""
        beginWaitCursor
    }

    # check file opening and syntex

    if { [catch {open $lmVals(lmLicenseFile) r} fileId] } { 
        dbgputs "FLEXCOPY: Cannot open license file"

        set cannotOpen 1
        set errMsg "Cannot open license file: $lmVals(lmLicenseFile)\
                    \nfor analysis."
        uninstLog setup "FLEXCOPY: Detected license file opening error."

    } else {
        while { [gets $fileId line] >= 0 } {
            set line [string trim $line]

	    if { "$line" != "" && \
		 [regexp {^%.*} $line] } {
		 # found start of WR proprietary info, no more licensefile lines
		 break;
             }

            # check if the line has correct format
            if { "$line" != "" && \
                 [regexp {^[SERVER|USE_SERVER|FEATURE|VENDOR|HOSTID|DUP|BORROW|PACKAGE|SIGN].*} $line] } {
                dbgputs "FLEXCOPY: License file can be opened and has a key word."

                uninstLog setup "FLEXCOPY: Setup has detected that your license \
			file can be opened for analysis."

                if { $ctrlVals(useInputScript) } {
                    autoSetupLog "FLEXCOPY - SETUP has detected that your\
                                  license file can be opened for analysis."
                }
                break
            }
        }
        close $fileId
    }

    if { $cannotOpen == 1 } {
        # error with license file, skip current license info page
        pageRemove currLicInfo

    }

    set lmRetVal $retVal

    if { [isGUImode] } {
        endWaitCursor
        windowClose licFileValidCheckDlg
    }
}


######################################################################
# Dialog Text Messages
######################################################################

set strTable(FLEXCOPY_LM_FILE_INVALID) \
	"SETUP has detected that your license file has an invalid format.\
     SETUP will overwrite the file."

set strTable(LM_FILESCOPY_BANNER) \
    "Copying License Management Files. Please wait..."

set strTable(LM_ANALYSIS_BANNER) \
    "Analyzing License File. Please wait..."

