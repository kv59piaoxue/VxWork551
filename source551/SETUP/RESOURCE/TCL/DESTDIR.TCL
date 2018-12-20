# DESTDIR.TCL - Setup procedures for implementing destination-directory
#               wizard page
#
# Copyright 1999-2003 Wind River Systems, Inc
#
# modification history
# --------------------
# 03q,29apr03,bjl  text rewording.
# 03p,14jan03,wmd  Fix SPR #85387, set WIND_BASE here so that archiving will
#                  work for Setup.
# 03o,23aug02,bjl  fixed checkInstallover return line (spr 80894).
# 03n,12jul02,wmd  Prevent installover warning message for a BSP installation.
# 03m,03may02,bwd  SPR 74983: Modified checkInstallOver to check ALL previous
#                  installation records
# 03l,03may02,bjl  prevent destdir with special tcl characters (spr 75147).
# 03k,05mar02,bwd  Modified SETUP to be non-tornado centric
# 03j,18jan02,wmd  Fix so installover check doesn't affect useInputScript
#                  mode.
# 03i,09jan02,bwd  Fixed typo
# 03h,09jan02,bwd  For BSP CD, warn if install in fresh or non-tornado tree
# 03g,09jan02,bwd  Modified warning message
# 03f,07jan02,bwd  Updated/added more comments for checkInstallover
# 03e,04jan02,bwd  INSTALLOVER: redesigned to use hard-coded table.
# 03d,21dec01,bwd  Added codes to handle BSP CD installation
# 03c,03dec01,bwd  INSTALLOVER: added a case to check for empty setup.log
# 03b,01nov01,bwd  Modified codes to allow or prevent installation over an
#                  existing directory
# 03a,12jun01,j_w  Modified for Tornado 2.2
# 02z,07may01,wmd  Fix bug, instname NOT found when installing over existing
#                  tree.
# 02y,25apr01,wmd  Need to add more modifications for spr 66729.
# 02x,23apr01,wmd  Fix spr #66729, should not check other products for
#                  previous install.
# 02w,15mar01,wmd  Fix spr 64156, modify Setup's behaviour with respect to
#                  versions.
# 02v,15dec00,wmd  Fix punctuation.
# 02u,15dec00,wmd  Fix punctuation error.
# 02t,02nov00,j_w  Name change - Tornado AE
# 02s,18aug00,bwd  SPR 32628: if T1/T2 prev installed set dest dir and 
#                  folder name to default values
# 02r,18aug00,bwd  Fixed Typo: SPR 32628 - do NOT display destination
#                  directory field if T1 or T2 has been previously installed.
# 02q,17aug00,bwd  SPR 32628: clear out dest dir field if T1 or T2 tree has
#                  been installed. Added searchAndProcessSection to write
#                  destDir to registry
# 02p,09aug00,bwd  Removed searchAndProcessSection - this is done in
#                  APPCONFG.TCL. SPR 32140: remove workaround for
#                  bootrom problem in Beta 1
# 02o,08jun00,bwd  Re-display SETUP bitmap
# 02n,02jun00,bwd  Changed all "dialog ok" to use "dialog ok_with_title"
# 02m,03may00,j_w  Change the 18 characters limits to 17
# 02l,01may00,j_w  Removed trailing slashes from the destination path
# 02k,26apr00,j_w  Gave a warning if WIND_BASE greater than 18 characters
#                  (due to bootrom path problem in beta-1)
# 02j,20mar00,bwd  Fixed TEXT mode to default YES to create a directory upon
#                  prompting user
# 02i,31jan00,bwd  Fixed error handling for test automation. Deleted
#                  redundant codes. Replaced setupVals(cmdMode) with isGUImode
# 02h,13jan00,bwd  Fixed error handling for TEXT MODE when prompting for a
#                  directory
# 02g,06jan00,bwd  No test automation for command line SETUP
# 02f,17dec99,clc  change  switch patterns
# 02e,16nov99,clc  change text mode variable to setupVals(cmdMode)
# 02d,07nov99,clc  add exit for text mode
# 02c,28oct99,clc  add text mode
# 02b,14oct99,j_w  Added more comments
# 02a,30Sep99,j_w  Modified for T3
# 01e,23jul99,j_w  added text messages
# 01d,31mar99,bjl  set infVals(addWinFile) for Windows hosts (spr 26136, 26205).
# 01c,24mar99,bjl  turn off inf write to registry after queueExecute.
# 01b,22mar99,bjl  added beginWaitCursor for page processing.
# 01a,26jan99,tcy  extracted from INSTW32.TCL.
#

global setupVals
global installRules

#############################################################################
#
# pageCreate(destDir) - prompt users for destination directory
#
# This procedure will prompt users for destination directory
#
# SYNOPSIS
# .tS
# pageCreate(destDir)
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc pageCreate(destDir) {} {
    global ctrlVals
    global setupVals

    if { [isBSPcd] } {
        set msg [strTableGet DESTDIR_LABEL_6]
        set labelText [strTableGet DESTDIR_LABEL_5]
    } elseif { $setupVals(cmdMode) == "icon"} {
        set msg [strTableGet DESTDIR_LABEL_1]
        set labelText [strTableGet DESTDIR_LABEL_2]
    } elseif { $setupVals(installChoice) == "onPrgGrpInstall" } {
	set msg [strTableGet DESTDIR_LABEL_SHORTCUTS]
        set labelText [strTableGet DESTDIR_LABEL_2]
    } else {
        set msg [strTableGet DESTDIR_LABEL_3]
        set labelText [strTableGet DESTDIR_LABEL_4]
    }

    windBaseReadFromRegistry

    if {$setupVals(installChoice) == "onPrgGrpInstall"} {
        destDirSet ""
    }

    if { [isTornadoProduct] } {

        # if tornado 1 or 2 is previously installed, do not
        # display the old WIND_BASE (destination directory) and
        # folder name values.

        if { [previousTornadoInstalled] } {
            if {[windHostTypeGet] == "x86-win32"} {
                destDirSet $setupVals(defDestDirWin32)
            } else {
                destDirSet $setupVals(defDestDirUnix)
            }
            defGroupSet $setupVals(defGroup)
            set infVals(addFolder) 1
        }
    }

    if { [isGUImode] } {

        # unhide the setup bitmap
        controlHide wizardDialog.bitmap 0

        set ctrlVals(volatileFrm) [list \
                    [list label -name dirLabel \
                                -title $msg \
                                -x 100 -y 10 \
                                -w 186 -h 80] \
                    [list label -name dirLabelText \
                                -title $labelText \
                                -x 105 -y 136 -w 150 -h 8] \
                    [list frame -name dirFrame \
                                -x 100 -y 146 -w 205 -h 24] \
                    [list text -name dirText -border \
                                -x 104 -y 151 \
                                -w 140 -h 14] \
                    [list button -name browse -title "B&rowse" \
                                -callback {onBrowse dirText} \
                                -x 249 -y 151 -w 50 -h 14] \
        ]
    
        set w [dlgFrmCreate [strTableGet DESTDIR_TITLE]]

        controlValuesSet $w.dirText [destDirGet]
        controlFocusSet $w.dirText
 
        # test automation
 
        if { $ctrlVals(useInputScript) } {
            autoSetupLog "Destination page:"
            autoSetupLog "\tDestination Directory: [destDirGet]"
            nextCallback
        }
    } else { # TEXT mode
        printPageTitle [strTableGet DESTDIR_TITLE]
       
        if { [isBSPcd] } {
            puts [strTableGet DESTDIR_LABEL_3_BSP_TEXT]
        } else {
            puts [strTableGet DESTDIR_LABEL_3_TEXT]
        }
        puts "\[[destDirGet]\]\n"

        while (1) {
            set ret [prompt]
            switch -regexp -- $ret {
                "^-$" { 
                    backCallback 
                    return 0 
                }
                "^$" { 
                    nextCallback 
                    return 0 
                }
                "[eE][xX][iI][tT]" { return 0 }
                default { 
                    if [regexp {~} $ret ] {
                        puts "Error: Invalid directory specified\n" 
                    } else {
                        destDirSet $ret
                        nextCallback
                        return 0 
                    }
                }
            }
        }    
    }
}

#############################################################################
#
# pageProcess(destDir) - process inputs from destDir page
#
# This procedure will process inputs from destDir page
#
# SYNOPSIS
# .tS
# pageProcess(destDir)
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: 0 if destination directory is unacceptable
#          1 if destination directory is acceptable
#
# ERRORS: N/A
#

proc pageProcess(destDir) {} {
    global setupVals
    global ctrlVals
    global infVals
    global overwritePolicy
    global skipInstalloverCheck
    global env

    set retVal 1
    set changeDir 0

    if { [isGUImode] } { 
    
        #beginWaitCursor

        set destDir [controlValuesGet $ctrlVals(mainWindow).dirText]

        # convert all Unix style slashes to backslashes for Windows
        # and remove trailing slashes
        if {[isUnix]} {
            set dpath  [string trim $destDir " "]
            set dirname [file dirname $dpath]
            set tail [file tail $dpath]
            destDirSet "[file join $dirname $tail]"
        } else {
            set dpath [unixToDos [string trim $destDir " "]]
            set dirname [file dirname $dpath]
            set tail [file tail $dpath]
            destDirSet "[unixToDos [file join $dirname $tail]]"
        }

        dbgputs "destDir = [destDirGet]"
 
        # check for white spaces
        if {[regexp {[ ]+} [destDirGet]]} {
            if { $ctrlVals(useInputScript) } {
                autoSetupLog "[strTableGet DESTDIR_WARN_1]"
                autoSetupLog "Application Exit\n"
                set setupVals(cancel) 1                
                applicationExit
                return 0
            } else {       
                dialog ok_with_title "ERROR: Destination Directory" [strTableGet DESTDIR_WARN_1]
                set retVal 0
            }
        }

        # check for special tcl regexp characters
	# one or more instances of ][$^?+*()|{}
        # the following regular expression means [special characters]+
        if {[regexp "\[\]\[\$\^\?\+\*\(\)\|\{\}\]\+" [destDirGet]]} {
            if { $ctrlVals(useInputScript) } {
                autoSetupLog "[strTableGet DESTDIR_WARN_10]"
                autoSetupLog "Application Exit\n"
                set setupVals(cancel) 1                
                applicationExit
                return 0
            } else {       
                dialog ok_with_title "ERROR: Destination Directory" [strTableGet DESTDIR_WARN_10]
                set retVal 0
            }
        }

        # ' and ~ reported to cause problems on Japanese Windows NT
        if ![isUnix] {
            if {[regexp "\['~\]\+" [destDirGet]]} {
                if { $ctrlVals(useInputScript) } {
                    autoSetupLog "[strTableGet DESTDIR_WARN_11]"
                    autoSetupLog "Application Exit\n"
                    set setupVals(cancel) 1                
                    applicationExit
                    return 0
                } else {       
                    dialog ok_with_title "ERROR: Destination Directory" [strTableGet DESTDIR_WARN_11]
                    set retVal 0
                }
            }
        }

        if ![isUnix] {

            # check if installed in root directory
            if {[regexp {^[a-zA-Z]:[\\|\/]*$} [destDirGet] junk]} {

                if { $ctrlVals(useInputScript) } {
                    autoSetupLog "[strTableGet DESTDIR_WARN_2]"
                    autoSetupLog "Application Exit\n"
                    set setupVals(cancel) 1                
                    applicationExit
                    return 0
                } else {        
                    if {![dialog yes_no "Setup" [strTableGet DESTDIR_WARN_2]]} {
                        set retVal 0
                    }
                }
            }

            # make sure directory has drive name and path
            if {![regexp {^[a-zA-Z]:[\\|\/]*.+$} [destDirGet] junk]} {
                if { $ctrlVals(useInputScript) } {
                    autoSetupLog "[strTableGet DESTDIR_WARN_7]"
                    autoSetupLog "Application Exit\n"
                    set setupVals(cancel) 1                
                    applicationExit
                    return 0
                } else {       
                    dialog ok_with_title "ERROR: Destination Directory" \
                                         [strTableGet DESTDIR_WARN_7]
                    set retVal 0
                }
            }

            # make sure no directory in path starts with a number
            # check the first name in the directory path.
            if {[regexp {^[a-zA-Z]:[\\|\/]*[0-9]+} [destDirGet] junk]} {
                if { $ctrlVals(useInputScript) } {
                    autoSetupLog "[strTableGet DESTDIR_WARN_8]"
                    autoSetupLog "Application Exit\n"
                    set setupVals(cancel) 1                
                    applicationExit
                    return 0
                } else {       
                    dialog ok_with_title "ERROR: Destination Directory" \
                                         [strTableGet DESTDIR_WARN_8]
                    set retVal 0
                }

            # then check the rest of the directory names.  
            } elseif {[regsub -all {\\[0-9]+} [destDirGet] {} ignore]} {
                if { $ctrlVals(useInputScript) } {
                    autoSetupLog "[strTableGet DESTDIR_WARN_9]"
                    autoSetupLog "Application Exit\n"
                    set setupVals(cancel) 1                
                    applicationExit
                    return 0
                } else {       
                    dialog ok_with_title "ERROR: Destination Directory" \
                                         [strTableGet DESTDIR_WARN_9]
                    set retVal 0
                }
            }
        }

    } else { # TEXT mode
        set exitVal 0
        set retVal 1

        # convert all Unix style slashes to backslashes for Windows
        if {[isUnix]} {
            destDirSet \
                    [string trim [destDirGet] " "]
        } else {
            destDirSet [unixToDos \
                    [string trim [destDirGet] " "]]
        }

        # check for null directory
        if { [destDirGet] == "" } {
            return [dirPrompt]
        }

        # check for white spaces
        if {[regexp {[ ]+} [destDirGet]]} {
            puts "Error: [strTableGet DESTDIR_WARN_1]\n"
            return [dirPrompt]
        }


        # check for special tcl regexp characters
	# one or more instances of ][$^?+*()|{}
        # the following regular expression means [special characters]+
        if {[regexp "\[\]\[\$\^\?\+\*\(\)\|\{\}\]\+" [destDirGet]]} {
            puts "Error: [strTableGet DESTDIR_WARN_10]\n"
            return [dirPrompt]
        }

        # ' and ~ reported to cause problems on Japanese Windows NT
        if ![isUnix] {
            if {[regexp "\['~\]\+" [destDirGet]]} {
                puts "Error: [strTableGet DESTDIR_WARN_11]\n"
                return [dirPrompt]
            }
        }

        if ![isUnix] {

            # check if installed in root directory
            if {[regexp {^[a-zA-Z]:[\\|\/]*$} [destDirGet] junk]} {
                puts "[strTableGet DESTDIR_WARN_2_TEXT]\n"
                puts "Press: 1 to proceed , 2 to choose different directory"
                while (1) {
                    set ret [prompt]
                    switch -regexp -- $ret {
                        "^1$" {
                            set retVal 1
                            break
                        }
                        "^2$" {
                            destDirSet $ret
                            set retVal [pageProcess(destDir)]
                            break
                        }
                        default { }
                    }
                }
            }

            # make sure directory has drive name and path
            if {![regexp {^[a-zA-Z]:[\\|\/]*.+$} [destDirGet] junk]} {
                puts "Error: [strTableGet DESTDIR_WARN_7]\n"
                return [dirPrompt]
            }

            # make sure no directory in path starts with a number
            # check the first name in the directory path.

            if {[regexp {^[a-zA-Z]:[\\|\/]*[0-9]+} [destDirGet] junk]} {
                puts "Error: [strTableGet DESTDIR_WARN_8]\n"
                return [dirPrompt]

                # then check the rest of the directory names.

            } elseif {[regsub -all {\\[0-9]+} [destDirGet] {} ignore]} {
                puts "Error: [strTableGet DESTDIR_WARN_9]\n"
                return [dirPrompt]
            }
        }
    }

    if { [isTornadoProduct] } {
        # check if installation over existing tree is ok
        # skip checking if run SETUP for a license or if because of errors
        if { [string compare [instTypeGet] "licenseError"] != 0 && \
             [string compare [instTypeGet] "licenseSetup"] != 0 } {

            # bypass checking if run with OVERRIDE option
            if { [info exist skipInstalloverCheck] && \
                 $skipInstalloverCheck != 0 } {
                 dbgputs "SKIPPED checkInstallover"
            } else {
                if { ![checkInstallover] } { return 0 }
            }
        }
    }

    if {![file isdirectory [destDirGet]] && "$retVal" == "1"} {
        # test automation

        if { [isGUImode] } {
            if { $ctrlVals(useInputScript) } {
                # yes = 0 ; no = 1
                set doNotCreateDirectory 0 

            } else {
                if { [instTypeGet] == "icon" } {
                    dialog ok "SETUP" \
                        "You have selected Program Group Installation.\
                         However, SETUP detected that the directory you entered\
                         does not exist. [strTableGet DESTDIR_LABEL_1]"
                    return 0
                }
                set doNotCreateDirectory \
                    [dialog yes_no "Setup" [strTableGet DESTDIR_WARN_3]]
            }
        } else { # TEXT mode
            # yes = 0 ; no = 1
            puts "Warning: [strTableGet DESTDIR_WARN_3] \[Y\]"

            while (1) {
                switch -regexp -- [prompt] {
                    "^$" -
                    "^[Y|y]" {  set doNotCreateDirectory 0 ; break  }
                    "^-$"    {  backCallback  }
                    "^[N|n]" {  return [dirPrompt]  }
                    default  { }
                }
            }
        }

        switch $doNotCreateDirectory {
            0 {
                # create directory

                if {![file exists [destDirGet]]} {

                    # workaround for: overWritePolicy dialog box appears
                    # even if user installs to a new directory

                    set overwritePolicy(ALL) 1

                    if {[catch {file mkdir [destDirGet]} error]} {

                        if { $ctrlVals(useInputScript) } {
                            autoSetupLog "Error in creating new directory: [destDirGet]"
                            autoSetupLog "Application Exit"
                            set setupVals(cancel) 1                
                            applicationExit
                            return 0
                        } else {
                            if {![file writable [destDirGet]]} {
                                if { [isGUImode] } {
                                    messageBox [strTableGet DESTDIR_WARN_4]
                                } else {
                                    puts "Error: [strTableGet DESTDIR_WARN_4]"
                                    return [dirPrompt]
                                }
                            } else {
                                if { [isGUImode] } {
                                    messageBox [strTableGet DESTDIR_WARN_5]
                                } else {
                                    puts "Error: [strTableGet DESTDIR_WARN_5]"
                                    return [dirPrompt]
                                }
                            }
                        }
                        set retVal 0
                    }
                    # test automation

                    if { $ctrlVals(useInputScript) } {
                        autoSetupLog "\tCreating new directory: [destDirGet]"
                    }
                } else {
                    if { ![isGUImode] } {
                        puts "Error: [strTableGet DESTDIR_WARN_6]"
                        return [dirPrompt]
                    } else {
                        if { $ctrlVals(useInputScript) } {
                            autoSetupLog "[strTableGet DESTDIR_WARN_6]"
                        } else {
                            messageBox [strTableGet DESTDIR_WARN_6]
                        }
                    }
                    set retVal 0
                }
            }
            1 {
                # do not create directory
                if { [isGUImode] } {
                    set retVal 0
                } else {
                    return [dirPrompt]
                }
            }
        }
    } else {

        # test automation
        if { $ctrlVals(useInputScript) } {
            autoSetupLog "\tOverwrite existing directory: [destDirGet]"
        } 
    }

    # Initiate the logging process

    if {"$retVal" == "1"} {
        if {[instTypeGet] != ""} {
            uninstStart [instTypeGet]
        } else {
            uninstStart
        }
    }

    if { [isTornadoProduct] } {  set infVals(addDestDir) 1  }

    set prod [string toupper [getProdInfo name]]
    searchAndProcessSection AddRegistry [cdFileNameGet [file join RESOURCE \
                                         INF $prod.INF]]

    queueExecute
    if { [isTornadoProduct] } {  
        set infVals(addFolder) 0 
        set infVals(addDestDir) 0  
    }

    # set WIND_BASE to destDir so that archiving will succeed for SETUP

    set env(WIND_BASE) [destDirGet]

    return $retVal
}

#############################################################################
#
# dirPrompt - creates a prompt loop for getting the destination directory
#
# This procedure will loop until a valid destination directory is entered or
# the user exits
#
# SYNOPSIS
# .tS
# dirPrompt
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: return value of nested call to pageProcess(destDir)
#
# ERRORS: N/A
#

proc dirPrompt { } {

    puts [strTableGet DESTDIR_LABEL_3_TEXT]
    set ret [prompt]
    while { $ret == "" } { 
        set ret [prompt]
    }
    switch -regexp -- $ret {
        "^-$" { 
            backCallback 
        }
        "[eE][xX][iI][tT]" { 
            return 0 
        }
        default { 
            destDirSet $ret
            set retVal [pageProcess(destDir)]
        }
    }
    return $retVal
}
 
#############################################################################
#
# onBrowse - set the value in edit box when a directory is selected
#            from the browse window
#
# This procedure will set the value in edit box when a directory is selected
# from the browse window
#
# SYNOPSIS
# .tS
# onBrowse <ctrlName>
# .tE
#
# PARAMETERS:
# .IP ctrlName
# control name which will have the new value
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc onBrowse {ctrlName} {
    global ctrlVals

    set retDir [dirBrowseDialogCreate -title "Directory"]

    if {"$retDir" != ""} {
        controlValuesSet $ctrlVals(mainWindow).$ctrlName $retDir
    }
}

#############################################################################
#
# checkInstallover - check INSTALLOVER.INF file for installation regulations
# 
# This procedure checks INSTALLOVER.INF file for installation validation
# rules (for Tornado product only). This procedure is called when SETUP 
# detects that user is trying to install the CD over an existing Tornado tree.
#
# SETUP warns, logs error, and allows to proceed:
# - if setup.log or INSTALLOVER.INF files not found or cannot be opened/read
# - if missing rule (no "CD-TDK" that matches this CD image)
# - if installed tree is incompatible, when "compatible-TDKs" does not
#   match with the one found in setup.log
#
# SYNOPSIS
# .tS
# checkInstallover
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: 0 = NO - installation over the existing tree is NOT allowed
#          1 = YES - installation over the existing tree is allowed
#
# ERRORS: N/A
#

proc checkInstallover {} {
    global env setupVals
    global installRules
    global ctrlVals

    set instFile [file join $env(CD_ROOT) RESOURCE INF INSTALLOVER.INF]
    set setupFile [file join [destDirGet] setup.log]
    set invalidTree 0
    set treePoolIdList ""
    set tornadoInstalled 0

    # if no setup.log...
    if { ![file exists $setupFile] } {
        dbgputs "setup.log does not exist"
        if { [isBSPcd] } {
            set invalidTree 1
        } else {
            # For CORE CD: new tree -> allow installation
            return 1
        }
    }

    # get previous installations information (TDK#s) from setup.log
    # SETUP uses this info to check against validation table
    # (INSTALLOVER.INF) to see if this tree will be compatible
    # with the current installation of the CD.

    if { ![catch {open $setupFile "r"} setupFd] } {

        # loop through and check EVERY record in setup.log

        while { [gets $setupFd line] >= 0 } {
            if {[regexp {(TDK-[0-9]+-[a-zA-Z]+-[0-9]+)} $line id]} {
                lappend treePoolIdList $id
            } elseif { [regexp {.+Tornado Tools: .+} $line] } {
                if { [isBSPcd] } {
                    # BSP CD: check if tree contains Tornado Tools
                    set tornadoInstalled 1
                }
            } else {
                continue
            }
        }
        close $setupFd
    }

    dbgputs "current CD poolId: $setupVals(CDnumber)"
    dbgputs "installed tree poolId list: $treePoolIdList"

    # empty setup.log = prev installation didn't get pass 
    # copying SETUP files...
    if { [string match $treePoolIdList ""] } {
        dbgputs "Empty setup.log"
        if { [isBSPcd] } {
            set invalidTree 1
        } else {
            # For CORE CD: new tree -> allow installation
            return 1
        }
    }

    # For BSP CD: give warning for invalid tree
    if { $invalidTree && !$tornadoInstalled } {
        if { [dialog yes_no "WARNING: Invalid Tree" \
                             [strTableGet DESTDIR_INVALID_TOR_TREE]] } {
            # user chooses "no" to re-enter directory
            return 0
        } else {
            uninstLog setupLog "BSP/Drivers CD installation: user chose\
                                to install in an invalid Tornado tree."
        }
    }

    # If this installation is of the same CD as the previous
    # one (same TDK#), then allow installover
    if {[lsearch $treePoolIdList $setupVals(CDnumber)] != -1} {
        dbgputs "Same CD as previous install - OK"
        return 1
    }

    # If missing INSTALLOVER.INF file, it's our fault
    # Warn user, log in setup.log and proceed.
    if { ![file exists $instFile]} {
        set msg "Missing File: $instFile\nSETUP is unable to find\
                 the installation validation rules for this CD"

        # test automation

        if { $ctrlVals(useInputScript) } {
            autoSetupLog "Destination Directory page:"
            autoSetupLog "WARNING: Missing File $msg"
        } else {
            dialog ok_with_title "WARNING: Missing File" $msg
            uninstLog setupLog $msg
        }
        return 1
    }

    if { [catch {open $instFile "r"} instFd] } {

        # If cannot open/read INSTALLOVER.INF file, it's our fault
        # Warn user, log in setup.log and proceed.

        set msg "Error in reading $instFile\nSETUP is unable to\
                 find the installation validation rules for this CD"

        # test automation
        
        if { $ctrlVals(useInputScript) } {
            autoSetupLog "Destination Directory page:"
            autoSetupLog "Error Reading File $msg"
        } else {
                dialog ok_with_title "Error Reading File" $msg
                uninstLog setupLog $msg
        }
        return 1

    } else {
        # This block of codes reads INSTALLOVER.INF each line
        # and do checking to see if the current installation of this
        # this CD will be compatible with the existing tree user.

        # variable used to check if the current CD's poolId is
        # found in an entry (in 1st column)
        set matchRuleOnce 0

        # reading INSTALLOVER.INF file
        while { [gets $instFd line] >= 0 } {

            # skip comment line
            if {[regexp {^#} [string trimleft $line] ]} {
                continue
            }

            # skip empty line
            if {[regexp {^$} [string trimleft $line] ]} {
                continue
            }

            # remove empty elements due to white spaces between 2 columns
            set str [split $line]           
            while {[set ndex [lsearch -exact $str {}]] != -1} {
                set str [lreplace $str $ndex $ndex]
            }

            # get rule:
            # cd-tdk and compatible installed-tdk
            set ruleCdTdk [string trimleft [lindex $str 0]]
            set ruleInstTdk [string trimleft [lindex $str 1]]

            # find the right rule for this current CD
            # (i.e. matching a rule with the CD Number (TDK#))
            if { [string match $ruleCdTdk $setupVals(CDnumber)] } {

                # find rule for this CD
                set matchRuleOnce 1

                # find rule: now check if installed tree is compatible

                # if more than one compatible TDKs, seperate them by space 
                set ruleInstTdk [split $ruleInstTdk ":"]

                # Loop through all compatible TDKs to match at least one.
                # Compare each "compatible-tdk" from the rule table to 
                # match one of the TDK numbers obtained from setup.log
                # If the existing tree is compatible with the current
                # installation of this CD, log Rule matched
                # and proceed with installation

                foreach iTdk $ruleInstTdk {
                    if {[lsearch $treePoolIdList $iTdk] != -1} {
                        set msg "Match Installation Validation Rule:\
                                 $ruleCdTdk\t$iTdk"
                        dbgputs $msg
                        uninstLog setupLog $msg
                        return 1
                    }
                }

                # If poolId of the existing tree does not match with
                # any of the compatible TDKs in the table, give error

                set msg "Installation validation FAILED - no match"
                dbgputs $msg
                set displayMsg \
                      "You appear to be installing this CD into an\
                       incompatible tree. The installation tree must match the\
                       following(s): $setupVals(CDnumber) $ruleInstTdk\n\nIf you\
                       choose to continue, you may corrupt your existing tree."
 
                # For BSP/Drivers CD, only give warnings and log in setup.log -
                #   allow user to install multiple-arch BSPs/Drivers in one tree.
                # BUT for core CD, error - must install in a tree with same arch

                if { [isBSPcd] } {
                    set choice "Do you want to continue with installation?\
                                Click yes to proceed or click no to re-enter\
                                the destination directory."

                    # swap the return value from procedure "dialog"
                    # to match the return value for this procedure
                    set answer [dialog yes_no "WARNING: BSP Installation" \
                                       "WARNING: $displayMsg\n\n$choice"]

                    if { $answer } {
                        # user chooses "no"
                        return 0
                    } else { 
                        uninstLog setupLog "$msg, and installation\
                                            was continued (BSP CD)"
                        return 1 
                    }
                } else {
                    set msg "ERROR: $displayMsg SETUP will not allow this\
                             installation. Please choose another directory."
                    dialog ok_with_title "Error: Installation Not Allowed" $msg
                    return 0
                }
            }
         }

         # Rule for this CD's poolId is not listed in INSTALLOVER.INF
         # Our fault - missing an entry. Inform user, log it, and proceed
         if { !$matchRuleOnce && [isBSPcd]} {
            set msg "Rules not found.\nSETUP is unable to find the\
                     installation validation rules for this CD"

            # test automation

            if { $ctrlVals(useInputScript) } {
                autoSetupLog "Destination Directory page:"
                autoSetupLog "WARNING: Rules not found $msg"
            } else {
                dialog ok_with_title "WARNING: Rules not found" $msg
                uninstLog setupLog $msg
            }
        }
        return 1
    }
}

######################################################################
# Dialog Text Messages
######################################################################

set strTable(DESTDIR_TITLE) "Installation Directory"

set strTable(DESTDIR_LABEL_1) \
        "format %s \"Please enter the directory path where\n\[cdromDescGet]\
        has already been installed.\
        \n\nClick the Browse button to choose the directory\
        interactively.\""

set strTable(DESTDIR_LABEL_SHORTCUTS) \
        "format %s \"Please enter the directory path where\n\[cdNameGet description]\
        has already been installed on your\
        network, or click the Browse button to choose the directory\
        interactively.\""

set strTable(DESTDIR_LABEL_2) "Remote Directory"

set strTable(DESTDIR_LABEL_3) \
        "format %s \"[getProdInfo name] and its related products are\
        designed to be installed in a single directory tree.  Specify the\
        base directory for that tree below.\n\nWARNING: Do not install\
        Tornado in the same directory as any previous installation of\
        Tornado, or in the same directory as versions of Tornado for\
        other target operating systems. Unpredictable behavior may result.\""

set strTable(DESTDIR_LABEL_3_TEXT) \
        "format %s \"Please enter the directory path where you\
        want SETUP to install [cdromDescGet].\""

set strTable(DESTDIR_LABEL_3_BSP_TEXT) \
       "format %s \"Please enter the directory path of the installed\
        Tornado tree where you wish to install BSP/Driver products\
        from this CD.\""

set strTable(DESTDIR_LABEL_4) "Installation Directory"

set strTable(DESTDIR_LABEL_5) "Tornado Directory"

set strTable(DESTDIR_LABEL_6) \
        "format %s \"The BSP/Driver products must be installed in the same\
         directory as the products from the companion Tornado Core CD.\
         Specify the Tornado installation directory below.\""

set strTable(DESTDIR_WARN_1) \
        "format %s \"The installation directory you entered contains white\
        space(s). Please select another directory.\""

set strTable(DESTDIR_WARN_2) \
        "format %s \"Installing \[cdromDescGet\] in the root directory\
        is not recommended.\nClick Yes to select another directory.\""

set strTable(DESTDIR_WARN_2_TEXT) \
        "format %s \"Installing \[cdromDescGet\] in the root directory\
        is not recommended.\""

set strTable(DESTDIR_WARN_3) \
        "The installation directory you entered does not exist.\
        \nDo you want to create it now?"

set strTable(DESTDIR_WARN_4) \
        "You do not have permission to write files into the installation\
        directory you entered.\
        \n\nPlease choose a writable directory."

set strTable(DESTDIR_WARN_5) \
        "format %s \"Unable to create [destDirGet].\""

set strTable(DESTDIR_WARN_6) \
        "format %s \"Creating [destDirGet] failed: file exists.\""

set strTable(DESTDIR_WARN_7) \
        "Please provide a directory path starting with a drive name."

set strTable(DESTDIR_WARN_8) \
        "Please provide a directory path starting with a letter character."

set strTable(DESTDIR_WARN_9) \
        "Please provide directory path starting with letter characters."

set strTable(DESTDIR_WARN_10) \
        "Please provide a directory path without these special characters:\
	 \]\[\$\^\?\+\*\(\)\|\{\}."

set strTable(DESTDIR_WARN_11) \
        "Please provide a directory path without these special characters:\
	 \]\[\$\^\?\+\*\(\)\|\{\}'~."

set strTable(DESTDIR_INVALID_TOR_TREE) \
        "The directory path you have entered is not a valid\
         Tornado tree.\n\n\"BSPs/Drivers\" CD must be installed over\
         a tree which contains Tornado Tools.\n\nDo you want to continue\
         with installation? Click yes to proceed or click no to\
         re-enter the destination directory."
