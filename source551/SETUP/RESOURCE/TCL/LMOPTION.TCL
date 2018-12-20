# LMOPTION.TCL - Setup procedures for selecting license management options 
#                    for end users 
#
# Copyright 1999-2003 Wind River Systems, Inc
#
# modification history
# --------------------
# 02m,14feb03,bjl  modified for manual and ELM page sequences, modified
#                  license wording for ELM.  
# 02l,13Jan03,wmd  Fix SPR# 85621, make valid license file always pass.
# 02k,07jun02,wmd  Fix SPR# 78461, need to prepare for ALI 2.0- analyze license
#                  file and skip proprietary info.
# 02j,18may02,wmd  Fix SPR#77292, make node-locked the default choice, per
#                  Sean Hogan.
# 02i,17may02,wmd  Fix text formatting, grammatical problems.
# 02h,08may02,j_w  Wording change
# 02g,25apr02,j_w  Revised the wording in the floating choice
# 02f,23apr02,wmd  Need to add new FLEXlm key words to check, spr 76185.
# 02e,05mar02,bwd  Modified SETUP to be non-tornado centric
# 02d,04feb02,bwd  Modifying wordings
# 02c,24jan02,wmd  Add check for evaluation, if so disable end-user choice,
#                  only nodelocked available.
# 02b,17sep01,bwd  Fixed spr 69435 and 69699
# 02a,12jun01,j_w  Modified for Tornado 2.2
# 01t,30oct00,j_w  Enabled the back button for setup /L
# 01s,25oct00,bwd  SPR 35597: add HELP button back
# 01r,02oct00,bwd  Changed to update LMHelpPath variable upon clicking on a
#                  choice
# 01q,21sep00,bwd  Modified the wordings/descriptions of each choice. Set 
#                  LMHelpPath global variable to "float" or "nodelock" to 
#                  identify which help IDs set to use
# 01p,11jul00,j_w  Added lic file reload option for nodelocked
# 01o,31may00,bwd  SPR 31564: remove currLicInfo page if license file already
#                  exists. Added new procedures to check if a license file
#                  exists and is valid.
# 01n,17may00,bwd  SPR 31030 - add lmInstOptions page on nodelock to allow
#                  users email/phone options
# 01m,01may00,j_w  Renamed "nodeLock" to "nodeLocked" for
#                  setupVals(lmInstType)
# 01l,20mar00,bwd  Fixed TEXT mode to default a choice to EndUser
# 01k,17mar00,j_w  Fixed typo and re-wording displayed messages
# 01j,08feb00,j_w  Rename page title
# 01i,03feb00,j_w  Replace nodelock with nodeLock
# 01h,03feb00,j_w  Remove the pageListAdd call
# 01g,27jan00,j_w  Rename OK to Next
# 01f,11jan00,bwd  Fixed "exit" option for text mode
# 01e,06jan00,bwd  No test automation for command line SETUP
# 01d,17dec99,clc  testing
# 01c,30nov99,j_w  Update LM_OPTIONS_BTN_1_DESC message
# 01c,23nov99,clc  add text mode
# 01b,11nov99,bwd  Added sections for automatic setup installation
# 01a,29oct99,wmd  created.
#

#############################################################################
#
# pageCreate(lmOptions) - displays choices for LM installation
#
# This procedure will display choices for LM installation such as:
#  End User License Management - for floating license end user configuration 
#  Node Locked - to configure the software to be accessible only on this host.
#
# SYNOPSIS
# .tS
# pageCreate(lmOptions)
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#


proc pageCreate(lmOptions) {} {
    global ctrlVals env setupVals lmVals

    set lmVals(lmLicenseFile) "[destDirGet]/.wind/license/WRSLicense.lic"
    set lmVals(lmLicenseFile) [dosToUnix $lmVals(lmLicenseFile)]

    if { [isGUImode] } {
        # unhide the setup bitmap
        controlHide $ctrlVals(mainWindow).bitmap 0

        if {$setupVals(lmManual) == 0} {
            set ctrlVals(volatileFrm) [list \
                [list label -name message1 \
                    -title [strTableGet LM_OPTIONS_MSG_1] \
                    -x 100 -y 10 -w 190 -h 41] \
                [list choice -name endUserChoice -newgroup -auto \
                    -title [strTableGet LM_OPTIONS_BTN_1] \
                    -x 102 -y 54 -w 190 -h 15 \
                    -callback onEndUser] \
                [list label -name endUserLabel \
                    -title \
                    [strTableGet LM_OPTIONS_BTN_1_DESC] \
                    -x 114 -y 68 -w 180 -h 25] \
                [list choice -name nodeLockChoice -auto \
                    -title [strTableGet LM_OPTIONS_BTN_2] \
                    -x 102 -y 96 -w 190 -h 15 \
                    -callback onNodeLock] \
                [list label -name nodeLockLabel  \
                    -title \
                     [strTableGet LM_OPTIONS_BTN_2_DESC] \
                    -x 114 -y 111 -w 180 -h 20] \
                [list boolean -name reloadCkbox -newgroup -auto \
                    -title [strTableGet LM_OPTIONS_BTN_3] \
                    -x 102 -y 140 -w 200 -h 15 \
                    -callback onReloadLicNL] \
                ]
        } else {
            set ctrlVals(volatileFrm) [list \
                [list label -name message1 \
                    -title [strTableGet LM_OPTIONS_MSG_1_MANUAL] \
                    -x 100 -y 10 -w 190 -h 41] \
                [list choice -name endUserChoice -newgroup -auto \
                    -title [strTableGet LM_OPTIONS_BTN_1_MANUAL] \
                    -x 102 -y 50 -w 190 -h 15 \
                    -callback onEndUser] \
                [list label -name endUserLabel \
                    -title \
                    [strTableGet LM_OPTIONS_BTN_1_DESC_MANUAL] \
                    -x 114 -y 64 -w 180 -h 25] \
                [list choice -name nodeLockChoice -auto \
                    -title [strTableGet LM_OPTIONS_BTN_2_MANUAL] \
                    -x 102 -y 100 -w 190 -h 15 \
                    -callback onNodeLock] \
                [list label -name nodeLockLabel  \
                    -title \
                     [strTableGet LM_OPTIONS_BTN_2_DESC_MANUAL] \
                    -x 114 -y 115 -w 180 -h 20] \
                [list boolean -name reloadCkbox -newgroup -auto \
                    -title [strTableGet LM_OPTIONS_BTN_3] \
                    -x 102 -y 140 -w 200 -h 15 \
                    -callback onReloadLicNL] \
                ]
        }

        set w [dlgFrmCreate [strTableGet LM_OPTIONS_TITLE]]


        if { $setupVals(evaluation) == 1 } {
            controlEnable $w.endUserChoice 0
            controlCheckSet $w.nodeLockChoice 1
            controlEnable $w.reloadCkbox 0
            controlHide $w.reloadCkbox 1
        }

        # unhide the help button - no use during copying
        controlEnable $w.helpButt 1

        if { [isTornadoProduct] } {
            controlEnable $w.helpButt 1
        } else {
            controlEnable $w.helpButt 0
        }

        switch $setupVals(lmOptions) {
            onEndUser   { controlCheckSet $w.endUserChoice 1 }
            onNodeLock  { controlCheckSet $w.nodeLockChoice 1 }
            default     { controlCheckSet $w.nodeLockChoice 1 }
        }

                if {$lmVals(reloadExistingLicense) == 1} {
                        controlCheckSet $w.reloadCkbox 1
                } else {
                        controlCheckSet $w.reloadCkbox 0
                }
                
                controlValuesSet $w.nextButt "&Next >"
        
        controlEnable $w.nextButt 1
        controlEnable $w.backButt 1
        controlEnable $w.cancelButt 1

        # test automation

        if { $ctrlVals(useInputScript) } {
            autoSetupLog "LM Option page: Skipped"
            autoSetupLog "\tLM Option: $setupVals(lmOptions)"
            nextCallback
        }

    } else { # TEXT mode

        printPageTitle [strTableGet LM_OPTIONS_TITLE]
        puts [strTableGet LM_OPTIONS_MSG_1_TEXT]
        puts "1 - [strTableGet LM_OPTIONS_BTN_1]"
        puts "[strTableGet LM_OPTIONS_BTN_1_DESC]\n"
        puts "2 - [strTableGet LM_OPTIONS_BTN_2]"
        puts "[strTableGet LM_OPTIONS_BTN_2_DESC]\n"

        while (1) {
            puts "Please enter the number of your selection. \[1\]"
            set ret [prompt]
            switch -regexp -- $ret {
                "^$" -
                "^1$" { 
                    onEndUser
                    nextCallback
                    return 0
                }
                "^2$" { 
                    onNodeLock
                                onReloadLicNL
                    nextCallback
                    return 0
                }
                "^[eE][xX][iI][tT]$" {
                    return 0
                }
                default { 
                    puts "Error: Invalid input."
                }
            }
        }
    }
}

#############################################################################
#
# pageProcess(lmOptions) - process inputs from lmOptions page if any
#
# This procedure will process inputs from lmOptions page if any
#
# SYNOPSIS
# .tS
# pageProcess(lmOptions)
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: 1 when successful
#
# ERRORS: N/A
#

proc pageProcess(lmOptions) {} {
    global setupPageList setupVals ctrlVals lmVals
    set retVal 1

    switch $setupVals(lmOptions) {
        onEndUser {
            #pageListRemove lmInstOptions
            set setupVals(lmInstType) "endUser"

            if {$setupVals(lmManual) == 0} {
                pageListAdd endUser
            } else {
                if {[isUnix]} {
                    pageListAdd endUserManualUnix               
                } else {
                    pageListAdd endUserManual
                }
                return [licServerDialog]
            }                                   
        }
        onNodeLock {
            if {$setupVals(lmManual) == 1} {
                pageListAdd lmInstOptions
            } else {
                pageListAdd nodeLock
            }
            
            # check if license file exists
            if { ![NLlicFileExists] } {
                # lic file not exists, skip current license info page
                pageRemove currLicInfo
                dbgputs "\npageRemove currLicInfo"

                set retVal 1
            } else { 
                dbgputs "license file exists!"
                set retVal [NLlicFileValidCheck] 
            }
            
            set setupVals(lmInstType) "nodeLocked"

            if { $lmVals(reloadExistingLicense) == 1 } {
                set lmVals(reload) 1
                set setupVals(licUpdateAction) "onReload"
            } else {
                set lmVals(reload) 0
                set setupVals(licUpdateAction) "onUpdate"
            }
            
            # clear old value if one exists
            
            if { [info exists setupVals(lmInstOptions)] } {
                set setupVals(lmInstOptions) ""
            }
        }
    }    
    dbgputs "lmOption: $ctrlVals(pageList)"

    return $retVal
}

#############################################################################
#
# onEndUser - set up to configure user to use floating licenses
#
# This procedure is a callback which allows the user to configure tornado for
# floating licensing
#
# SYNOPSIS
# .tS
# onEndUser
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc onEndUser {} {
    global setupVals ctrlVals
    global LMHelpPath

    set setupVals(lmOptions) onEndUser
    set lmVals(reloadExistingLicense) 0
    set LMHelpPath "float"

    if {[isGUImode]} {
        set w $ctrlVals(mainWindow)

        controlEnable $w.reloadCkbox 0
        controlCheckSet $w.reloadCkbox 0
    }
}


#############################################################################
#
# onNodeLock - setup to configure user for node locked licensing
#
# This procedure is a callback which allows the user to configure tornado for
# node locked licensing.
#
# SYNOPSIS
# .tS
# onNodeLock
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc onNodeLock {} {
    global setupVals ctrlVals
    global LMHelpPath

    set setupVals(lmOptions) onNodeLock
    set LMHelpPath "nodelock"

    if {[isGUImode]} {
        set w $ctrlVals(mainWindow)

        controlEnable $w.reloadCkbox 1
        #controlCheckSet $w.reloadCkbox 1
    }
}

#############################################################################
#
# NLlicFileExists - Check if an license file exists
#
# This routine check if an license file exists 
# 
# SYNOPSIS
# .tS
# NLlicFileExists
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: 1 if exists, 0 if not
#
# ERRORS: N/A
#
proc NLlicFileExists {} {
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
# NLlicFileValidCheck - validate the license file
#
# This routine validate the existing license file
# 
# SYNOPSIS
# .tS
# NLlicFileValidCheck
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: 0 if failed, non-zero if success. Return num is the setup page to
#          jump to
#
# ERRORS: N/A
#
proc NLlicFileValidCheck {} {
    global ctrlVals setupVals lmRetVal 

    if { [isGUImode] } {
        dialogCreate \
            -name NLlicFileValidCheckDlg \
            -notitle \
            -parent $ctrlVals(parentDialog) \
            -width 230 -height 32 \
            -init {
                controlPropertySet NLlicFileValidCheckDlg.message1 -bold 1; \
                windowTimerCallbackSet NLlicFileValidCheckDlg \
                -milliseconds 200 NLlicFileValidCheckCallback \
            } \
            -controls [list \
                [list bitmap -name bmp -stretch \
                             -title "[cdFileNameGet \
                                     [file join RESOURCE BITMAPS SETUPICO.BMP]]" \
                             -x 10 -y 5 -w 20 -h 20] \
                [list label -name "message1" \
                            -title [strTableGet LM_ANALYSIS_BANNER] \
                            -x 40 -y 12 -w 180 -h 10] ]
    } else { # TEXT mode       
        puts "[strTableGet LM_ANALYSIS_BANNER]\n"
        NLlicFileValidCheckCallback
    }

    # lmRetVal is set in NLlicFileValidCheckCallBack
    return $lmRetVal

}

#############################################################################
#
# NLlicFileValidCheckCallback - Call back function for NLlicFileValidCheck
#
# This routine validate the existing license file
# 
# SYNOPSIS
# .tS
# NLlicFileValidCheckCallback
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: 0 if failed, non-zero if success. Return num is the setup page to
#          jump to
#
# ERRORS: N/A
#
proc NLlicFileValidCheckCallback {} {
    global setupVals ctrlVals lmVals lmRetVal

    set retVal 1
    set errMsg ""
    set cannotOpen 0

    if { [isGUImode] } {
        windowTimerCallbackSet NLlicFileValidCheckDlg 0 ""
        beginWaitCursor
    }

    # check file opening and syntax

    if { [catch {open $lmVals(lmLicenseFile) r} fileId] } { 
        dbgputs "Cannot open license file"

        set cannotOpen 1
        set errMsg "Cannot open license file: $lmVals(lmLicenseFile)\
                    \nfor analysis." 
        uninstLog setup "Detected license file opening error."

        if { $ctrlVals(useInputScript) } {
            autoSetupLog "Cannot open license file: $lmVals(lmLicenseFile)."
        }
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
                 [regexp {[SERVER|USE_SERVER|FEATURE|INCREMENT|BORROW|SIGN|VENDOR|HOSTID|DUP|PACKAGE].*} $line] } {
                dbgputs "License file can be opened and has a key word."

                uninstLog setup "License file can be opened and has a key word."

                if { $ctrlVals(useInputScript) } {
                    autoSetupLog "SETUP has detected that your license file \
                                  can be opened for analysis."
                }
                break
            } 
	        
        }
        close $fileId
    }

    if { $cannotOpen == 1} {
        # error with license file, skip current license info page
        pageRemove currLicInfo

    }

    set lmRetVal $retVal

    if { [isGUImode] } {
        endWaitCursor
        windowClose NLlicFileValidCheckDlg
    }
}

proc onReloadLicNL {} {
    global lmVals ctrlVals

    if {[isGUImode]} {
        set w $ctrlVals(mainWindow)

        if {[controlChecked $w.reloadCkbox]} {
            set lmVals(reloadExistingLicense) 1
            set lmVals(reload) 1
        } else {
            set lmVals(reloadExistingLicense) 0
            set lmVals(reload) 0
        }
    } else {
        puts "Do you want to recapture your existing license file? (y/n) \[n\] "
        set ret [prompt]
        if {$ret == "y"} {
            set lmVals(reloadExistingLicense) 1
            set lmVals(reload) 1
        } else {
            set lmVals(reloadExistingLicense) 0
            set lmVals(reload) 0
        }
    }
    dbgputs "reloadExistingLicense: $lmVals(reloadExistingLicense)"
}


#############################################################################
#
# licServerDialog() - create "License Server Information" dialog for GUI mode
#
# This procedure will create the "License Server Information" dialog for
# the manual page sequence, that allows the user to to enter the license
# server and port number. 
#
# SYNOPSIS
# .tS
# licServerDialog()
# .tE
#
# PARAMETERS: N/A
#
# RETURNS:  1 if successful
#
# ERRORS: N/A
#

proc licServerDialog {} {
    global ctrlVals
    global setupVals

    dialogCreate -nocontexthelp \
        -name licServerDlg \
        -parent $ctrlVals(mainWindow) \
        -title "Enter License Server Information" \
        -width 181 -height 133 \
        -controls [list \
            [list text -name serverNameEdit \
                   -xpos 82 -ypos 68 -width 64 -height 12 ] \
            [list text -name portNumberEdit  \
                   -xpos 82 -ypos 88 -width 64 -height 12 ] \
            [list button -title "OK" -name okButt -default \
	             -xpos 30 -ypos 112 -width 50 -height 14  \
                     -callback onLicServerOK ] \
            [list button -title "Cancel" -name cancelButt  \
                     -xpos 104 -ypos 112 -width 50 -height 14  \
                     -callback onLicServerCancel ] \
            [list label -title "Port number:" -name portNumberLabel  \
                    -xpos 30 -ypos 88 -width 48 -height 8 ] \
            [list label -title "Server name:" -name serverNameLabel  \
                    -xpos 30 -ypos 68 -width 48 -height 8 ] \
            [list label -title [strTableGet LM_OPTIONS_DIALOG_MANUAL] \
                   -name licInfoLabel -xpos 8 -ypos 4 -width 165 \
                   -height 60 ]
            ]	    
    return $setupVals(licDlgRet)
}

#############################################################################
#
# onLicServerOK() - OK callback for licServerDialog
#
# This procedure is the OK callback for the license server information 
# dialog.  The dialog values are read and verified to be valid, and
# the global lm manual variables are set to those values.  
#
# SYNOPSIS
# .tS
# onLicServerOK()
# .tE
#
# PARAMETERS: N/A
#
# RETURNS:  1 if successful, 0 otherwise.
#
# ERRORS: N/A
#

proc onLicServerOK {} {
    global setupVals lmVals
    
    set lmVals(lmPortManual) ""
    set lmVals(lmHostManual) ""    

    set lmVals(lmPortManual) [controlValuesGet licServerDlg.portNumberEdit]
    set lmVals(lmHostManual) [controlValuesGet licServerDlg.serverNameEdit]

    if {$lmVals(lmPortManual) == ""} {
        messageBox "Please enter a port number."
        controlFocusSet licServerDlg.portNumberEdit
        return 0
    }

    if {$lmVals(lmHostManual) == ""} {
        messageBox "Please enter a server name."
        controlFocusSet licServerDlg.serverNameEdit
        return 0
    }

    # check port number, should be numbers only

    if {[regexp {[^0-9]} $lmVals(lmPortManual)] == 1} {
        messageBox "Please enter a valid port number."
        controlFocusSet licServerDlg.portNumberEdit
        return 0
    } 

    # check server name, should have no spaces

    if {[regexp {[ ]} $lmVals(lmHostManual)] == 1} {
        messageBox "Please enter a valid server name."
        controlFocusSet licServerDlg.serverNameEdit
        return 0
    }
    
    set lmVals(lmHostOrder) $lmVals(lmHostManual)
    windowClose licServerDlg
    set setupVals(licDlgRet) 1    
}

#############################################################################
#
# onLicServerCancel() - cancel callback for licServerDialog
#
# This procedure is the cancel callback for the license server information 
# dialog.  
#
# SYNOPSIS
# .tS
# onLicServerCancel()
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A 
#
# ERRORS: N/A
#

proc onLicServerCancel {} {
    global setupVals

    windowClose licServerDlg

    # have to remove endUser pages in case user switches to 
    # nodelock

    pageListRemove endUser

    set setupVals(licDlgRet) 0
}

######################################################################
# Dialog Text Messages
######################################################################

set strTable(LM_OPTIONS_TITLE) "License Management Configuration"

set strTable(LM_OPTIONS_MSG_1) \
    "SETUP has detected that one or more products are\
    license managed.\
    Choose one of the license management configuration\
    options listed below, then click the Next button to\
    continue the installation:"

set strTable(LM_OPTIONS_MSG_1_TEXT) \
    "Setup has detected that one or more products require\
    license management configuration.\
    Choose one of the license management configuration\
    options listed below to continue the installation:\n"

set strTable(LM_OPTIONS_MSG_1_MANUAL) \
    "Setup has detected that one or more products are\
     license managed. A license server name must be provided,\
     or a node-locked license file must be obtained from\
     Wind River."

set strTable(LM_OPTIONS_BTN_1) \
    "Configure to use a floating license"

set strTable(LM_OPTIONS_BTN_1_MANUAL) \
    "Configure to use a local license server"

set strTable(LM_OPTIONS_BTN_1_DESC) \
    "Configure this machine to use a license from an\
     existing license server on the network."

set strTable(LM_OPTIONS_BTN_1_DESC_MANUAL) \
    "Configure this machine to use a license from an existing\
     license server on your local network.  The name of this\
     license server must be provided."  

set strTable(LM_OPTIONS_BTN_2) \
    "Request a node-locked license file"

set strTable(LM_OPTIONS_BTN_2_MANUAL) \
    "Request a node-locked license file"

set strTable(LM_OPTIONS_BTN_3) \
        "Recapture license previously configured for this machine."

set strTable(LM_OPTIONS_BTN_2_DESC) \
    "Request a node-locked license file for use by this machine only."

set strTable(LM_OPTIONS_BTN_2_DESC_MANUAL) \
    "Request a node-locked license file for use by this machine only."

set strTable(LM_OPTIONS_DIALOG_MANUAL) \
    "Enter the license server name and port number (default\
     value is 27000). Please check with your system administrator\
     for the correct values before you enter them."

set strTable(LM_ANALYSIS_BANNER) \
    "Analyzing License File. Please wait..."

set strTable(LM_FILE_INVALID) \
    "SETUP has detected that your license file has an invalid format.\
    Would you like to replace it?"

set strTable(LM_LIC_FILE_NOT_REPLACE) \
    "You have choosen not to replace your license file.\nPlease select another\
    License Management options."
