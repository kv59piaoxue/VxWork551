# LMUTIL.TCL - Setup procedures for implementing destination-directory
#               for FLEXlm wizard page
#
# Copyright 1999-2003 Wind River Systems, Inc
#
# modification history
# --------------------
# 02c,14feb03,bjl  framed reload checkbox to make it stand out more.  
# 02b,05mar02,bwd  Modified SETUP to be non-tornado centric
# 02a,12jun01,j_w  Modified for Tornado 2.2
# 01l,15mar01,wmd  Use the correct procedure for getting destination directory.
# 01k,16oct00,j_w  Disabled the reload license checkbox if install type 
#                  is flexInst
# 01j,14aug00,bwd  SPR 32140: remove check for long directory names due to
#                  bootrom problems
# 01i,11jul00,j_w  removed unused procedure
# 01h,07jul00,j_w  Added checkbox to reload existing license file
# 01g,02jun00,bwd  Changed all "dialog ok" to use "dialog ok_with_title"
# 01f,03may00,j_w  Change the 18 characters limits to 17
# 01e,01may00,j_w  Gave a warning if WIND_BASE greater than 18 characters (due
#                  to bootrom path problem in beta-1) and Removed trailing
#                  slashes from the destination path
# 01d,02feb00,bwd  Fixed error handling for test automation
# 01c,13jan00,bwd  Added codes to display this page for TEXT MODE
# 01b,29nov99,wmd  Fix the pairing of WaitCursor calls.
# 01a,14Sep99,j_w  written
#

#############################################################################
#
# pageCreate(lmUtilInst) - prompt users for destination directory for FLEXlm
#                          utilities
#
# This procedure will prompt users for destination directory for FLEXlm util.
#
# SYNOPSIS
# .tS
# pageCreate(lmUtilInst)
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc pageCreate(lmUtilInst) {} {
    global ctrlVals
    global setupVals lmVals

    windBaseReadFromRegistry

    if { [isGUImode] } {

        set msg [strTableGet LM_DESTDIR_LABEL_1]
        set labelText [strTableGet LM_DESTDIR_LABEL_2]

        set ctrlVals(volatileFrm) [list \
                [list label -name dirLabel -title $msg \
                            -x 100 -y 10 -w 186 -h 80] \
                [list label -name dirLabelText -title $labelText \
                            -x 100 -y 104 -w 100 -h 8] \
                [list frame -name dirFrame \
                            -x 100 -y 114 -w 205 -h 24] \
                [list text -name dirText -border \
                           -x 104 -y 119 -w 140 -h 14] \
                [list button -name browse -title "B&rowse" \
                             -callback {onBrowse dirText} \
                             -x 249 -y 119 -w 50 -h 14] \
                [list frame -name reloadFrame \
                            -x 100 -y 146 -w 205 -h 24 ] \
		[list boolean -name reloadCkbox -newgroup -auto \
                              -title [strTableGet LM_DESTDIR_LABEL_3] \
                              -x 104 -y 151 -w 175 -h 14 \
                              -callback onReloadLic] \
        ]

        set w [dlgFrmCreate [strTableGet LM_DESTDIR_TITLE]]

		# disable the check box if installing flexLM files only
		if {[instTypeGet] == "flexInst"} {
			controlEnable $w.reloadCkbox 0
		}

	if {$lmVals(reloadExistingLicense) == 1} {
	    controlCheckSet $w.reloadCkbox 1
	} else {
	    controlCheckSet $w.reloadCkbox 0
	}

        controlValuesSet $w.dirText [destDirGet]
        controlFocusSet $w.dirText

        # test automation

        if { $ctrlVals(useInputScript) } {
            autoSetupLog "LM Destination page:"
            autoSetupLog "\tLM Destination Directory: [destDirGet]"
            nextCallback
        }
    } else { # TEXT mode

        printPageTitle [strTableGet LM_DESTDIR_TITLE]
        puts [strTableGet LM_DESTDIR_LABEL_1_TEXT]
        puts "\[[destDirGet]\]\n"

        while (1) {
            set ret [prompt]
            switch -regexp -- $ret {
                "^-$" { 
                    backCallback 
                    return 0 
                }
                "^$" { 
		    onReloadLic
                    nextCallback 
                    return 0 
                }
                "[eE][xX][iI][tT]" { return 0 }
                default { 
                    if [regexp {~} $ret ] {
                        puts "Error: Invalid directory specified\n" 
                    } else {
                        destDirSet $ret
			onReloadLic
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
# pageProcess(lmUtilInst) - process inputs from lmUtilInst page
#
# This procedure will process inputs from lmUtilInst page
#
# SYNOPSIS
# .tS
# pageProcess(lmUtilInst)
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: 0 if destination directory is unacceptable
#          1 if destination directory is acceptable
#
# ERRORS: N/A
#

proc pageProcess(lmUtilInst) {} {
    global setupVals
    global ctrlVals
    global infVals
    global overwritePolicy

    set retVal 1
    set changeDir 0
 
    if { [isGUImode] } {  
        beginWaitCursor

		# convert all Unix style slashes to backslashes for Windows
        # and remove trailing slashes
        if {[isUnix]} {
            set dpath  [string trim [controlValuesGet \
                        $ctrlVals(mainWindow).dirText] " "]
            set dirname [file dirname $dpath]
            set tail [file tail $dpath]
            destDirSet [file join $dirname $tail]
        } else {
            set dpath [unixToDos [string trim [controlValuesGet \
                        $ctrlVals(mainWindow).dirText] " "]]
            set dirname [file dirname $dpath]
            set tail [file tail $dpath]
            destDirSet [unixToDos [file join $dirname $tail]]

        }

        dbgputs "destDir = [destDirGet]"

        #check for white spaces
        if {[regexp {[ ]+} [destDirGet]]} {
            if { $ctrlVals(useInputScript) } {
                autoSetupLog "[strTableGet LM_DESTDIR_WARN_1]"
                autoSetupLog "Application Exit\n"
                set setupVals(cancel) 1                
                applicationExit
                return 0
            } else {       
                dialog ok_with_title "ERROR: Destination Directory" \
                                     [strTableGet LM_DESTDIR_WARN_1]
                set retVal 0
            }
        }

        if ![isUnix] {

            # check if installed in root directory
            if {[regexp {^[a-zA-Z]:[\\|\/]*$} [destDirGet] junk]} {

                if { $ctrlVals(useInputScript) } {
                    autoSetupLog "[strTableGet LM_DESTDIR_WARN_2]"
                    autoSetupLog "Application Exit\n"
                    set setupVals(cancel) 1                
                    applicationExit
                    return 0
                } else {        
                    if {![dialog yes_no "Setup" [strTableGet LM_DESTDIR_WARN_2]]} {
                        set retVal 0
                    }
                }
            }
            
            # make sure directory has drive name and path
            if {![regexp {^[a-zA-Z]:[\\|\/]*.+$} [destDirGet] junk]} {

               if { $ctrlVals(useInputScript) } {
                    autoSetupLog "[strTableGet LM_DESTDIR_WARN_7]"
                    autoSetupLog "Application Exit\n"
                    set setupVals(cancel) 1                
                    applicationExit
                    return 0
                } else {   
                    dialog ok_with_title "ERROR: Destination Directory" \    
                                         [strTableGet LM_DESTDIR_WARN_7]
                    set retVal 0
                }
            }

            # make sure no directory in path starts with a number
            # check the first name in the directory path.

            if {[regexp {^[a-zA-Z]:[\\|\/]*[0-9]+} [destDirGet] junk]} {

                if { $ctrlVals(useInputScript) } {
                    autoSetupLog "[strTableGet LM_DESTDIR_WARN_8]"
                    autoSetupLog "Application Exit\n"
                    set setupVals(cancel) 1                
                    applicationExit
                    return 0
                } else {       
                    dialog ok_with_title "ERROR: Destination Directory" \
                                         [strTableGet LM_DESTDIR_WARN_8]
                    set retVal 0
                }

                # then check the rest of the directory names.
            } elseif {[regsub -all {\\[0-9]+} [destDirGet] {} ignore]} {
 
                if { $ctrlVals(useInputScript) } {
                    autoSetupLog "[strTableGet LM_DESTDIR_WARN_9]"
                    autoSetupLog "Application Exit\n"
                    set setupVals(cancel) 1                
                    applicationExit
                    return 0
                } else {    
                    dialog ok_with_title "ERROR: Destination Directory" \
                                         [strTableGet LM_DESTDIR_WARN_9]
                    set retVal 0
                }
            }
        }

        if {![file isdirectory [destDirGet]] && "$retVal" == "1"} {
            # test automation

            if { $ctrlVals(useInputScript) } {
                # yes = 0 ; no = 1

                set doNotCreateDirectory 0

            } else {
                set doNotCreateDirectory \
                        [dialog yes_no "Setup" [strTableGet LM_DESTDIR_WARN_3]]
            }

            switch $doNotCreateDirectory {
                0 {
                    # create directory

                    if {![file exists [destDirGet]]} {

                        # workaround for: overWritePolicy dialog box appears
                        # even if user installs to a new directory

                        set overwritePolicy(ALL) 1

                        if {[catch {file mkdir [destDirGet]} error]} {

                            if {![file writable [destDirGet]]} {

                                if { $ctrlVals(useInputScript) } {
                                    autoSetupLog "[strTableGet LM_DESTDIR_WARN_4]"
                                    autoSetupLog "Application Exit\n"
                                    set setupVals(cancel) 1                
                                    applicationExit
                                    return 0
                                } else {
                                    messageBox [strTableGet LM_DESTDIR_WARN_4]
                                }
                            } else {
                                if { $ctrlVals(useInputScript) } {
                                    autoSetupLog "[strTableGet LM_DESTDIR_WARN_5]"
                                    autoSetupLog "Application Exit\n"
                                    set setupVals(cancel) 1                
                                    applicationExit
                                    return 0
                                } else {
                                    messageBox [strTableGet LM_DESTDIR_WARN_5]
                                }
                            }
                            set retVal 0
                        }
                        # test automation

                        if { $ctrlVals(useInputScript) } {
                            autoSetupLog "\tCreating new directory: [destDirGet]"
                        }
                    } else {

                        if { $ctrlVals(useInputScript) } {
                            autoSetupLog "[strTableGet LM_DESTDIR_WARN_6]"
                            autoSetupLog "Application Exit\n"
                            set setupVals(cancel) 1                
                            applicationExit
                            return 0
                        } else {
                            messageBox [strTableGet LM_DESTDIR_WARN_6]
                        }
                        set retVal 0
                    }
                }
                1 {
                    # do not create directory
                    set retVal 0
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

        # register file types only on Windows hosts since MainWin does
        # not show file extensions with file dialogs.   

        if {![isUnix] && $infVals(addDestDir)} {
            set infVals(addWinFile) 1     
        } else {
            set infVals(addWinFile) 0     
        }

        searchAndProcessSection AddRegistry [cdFileNameGet \
                                                [file join RESOURCE INF TORNADO.INF]]
        queueExecute
        if { [isTornadoProduct] } {  set infVals(addDestDir) 0  }
        set infVals(addWinFile) 0

        endWaitCursor

    } else { # TEXT mode

        set exitVal 0
        set retVal 1

        # convert all Unix style slashes to backslashes for Windows
        if {[isUnix]} {
            destDirSet [string trim [destDirGet] " "]
        } else {
            destDirSet [unixToDos [string trim [destDirGet] " "]]
        }

        # check for null directory
        if { [destDirGet] == "" } {
            return [lmDirPrompt]
        }

        # check for white spaces
        if {[regexp {[ ]+} [destDirGet]]} {
            puts "Error: [strTableGet LM_DESTDIR_WARN_1]\n"
            return [lmDirPrompt]
        }

        if ![isUnix] {            

            # check if installed in root directory
            if {[regexp {^[a-zA-Z]:[\\|\/]*$} [destDirGet] junk]} {
                puts "[strTableGet LM_DESTDIR_WARN_2_TEXT]\n"
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
                puts "Error: [strTableGet LM_DESTDIR_WARN_7]\n"
                return [lmDirPrompt]
            }

            # make sure no directory in path starts with a number
            # check the first name in the directory path.

            if {[regexp {^[a-zA-Z]:[\\|\/]*[0-9]+} [destDirGet] junk]} {
                puts [strTableGet LM_DESTDIR_WARN_8]
                return [lmDirPrompt]

                # then check the rest of the directory names.

            } elseif {[regsub -all {\\[0-9]+} [destDirGet] {} ignore]} {
                puts [strTableGet LM_DESTDIR_WARN_9]
                return [lmDirPrompt]
            }
        }

        if {![file isdirectory [destDirGet]]} {

            # yes = 0 ; no = 1
            puts "Warning: [strTableGet LM_DESTDIR_WARN_3]"

            while (1) {
                switch -regexp -- [prompt] {
                    "^-$"    {  backCallback  }
                    "^[N|n]" {  return [lmDirPrompt]  }
                    "^[Y|y]" {  set doNotCreateDirectory 0 ; break  }
                    default  { }
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

                            if {![file writable [destDirGet]]} {
                                puts "Error: [strTableGet LM_DESTDIR_WARN_4]\n"
                                return [lmDirPrompt]
                            } else {
                                puts "Error: [strTableGet LM_DESTDIR_WARN_5]\n"
                                return [lmDirPrompt]
                            }
                        }
                    } else {
                        puts "Error: [strTableGet LM_DESTDIR_WARN_6]\n"
                        return [lmDirPrompt]
                    }
                }
                1 {
                    # do not create directory
                    return [lmDirPrompt]
                }
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

        # register file types only on Windows hosts since MainWin does
        # not show file extensions with file dialogs.   

        if {![isUnix] && $infVals(addDestDir)} {
            set infVals(addWinFile) 1     
        } else {
            set infVals(addWinFile) 0     
        }

        searchAndProcessSection AddRegistry [cdFileNameGet \
                                                [file join RESOURCE INF TORNADO.INF]]
        queueExecute
        if { [isTornadoProduct] } {  set infVals(addDestDir) 0  }
        set infVals(addWinFile) 0
    }

    return $retVal
}

#############################################################################
#
# lmDirPrompt - creates a prompt loop for getting the destination directory
#
# This procedure will loop until a valid destination directory is entered or
# the user exits
#
# SYNOPSIS
# .tS
# lmDirPrompt
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: return value of nested call to pageProcess(destDir)
#
# ERRORS: N/A
#

proc lmDirPrompt { } {

    puts [strTableGet LM_DESTDIR_LABEL_1_TEXT]
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
            set retVal [pageProcess(lmUtilInst)]
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


proc onReloadLic {} {
    global lmVals ctrlVals
	
    if {[isGUImode]} {
		set w $ctrlVals(mainWindow)
		
		if {[controlChecked $w.reloadCkbox]} {
			set lmVals(reloadExistingLicense) 1
		} else {
			set lmVals(reloadExistingLicense) 0
		}
	} else {
		if {[instTypeGet] != "flexInst"} {
		  puts "Do you want to reload your existing license file? (y/n) \[n\] "
			set ret [prompt]
			if {$ret == "y"} {
				set lmVals(reloadExistingLicense) 1
			} else {
				set lmVals(reloadExistingLicense) 0
			}
		}
	}

    dbgputs "reloadExistingLicense: $lmVals(reloadExistingLicense)"
}


######################################################################
# Dialog Text Messages
######################################################################

set strTable(LM_DESTDIR_TITLE) "License Management Utilities Installation"

set strTable(LM_DESTDIR_LABEL_1) \
	"format %s \"Please type the name of the directory path where you\
	want SETUP to install License Management Utilities.\
	\n\nClick the <Browse> button to choose the directory\
	interactively.\""
set strTable(LM_DESTDIR_LABEL_1_TEXT) \
        "format %s \"Please type the name of the directory path where you\
	want SETUP to install License Management Utilities.\""

set strTable(LM_DESTDIR_LABEL_2) "Destination Directory"

set strTable(LM_DESTDIR_LABEL_3) \
	"Check this box to reload your existing license file."

set strTable(LM_DESTDIR_WARN_1) \
	"format %s \"The installation directory you entered contains white\
	space(s). Please select another directory.\""

set strTable(LM_DESTDIR_WARN_2) \
	"format %s \"Installing License Management utilities in the \
	root directory is not recommended.\nClick <Yes> to select \
	another directory.\""

set strTable(LM_DESTDIR_WARN_2_TEXT) \
	"format %s \"Installing License Management utilities in the root\
        directory is not recommended.  Please select another directory.\""

set strTable(LM_DESTDIR_WARN_3) \
	"The installation directory you entered does not exist.\
	\nDo you want to create it now?"

set strTable(LM_DESTDIR_WARN_4) \
	"You do not have permission to write files into the installation\
	directory you entered.\
	\n\nPlease choose a writable directory."

set strTable(LM_DESTDIR_WARN_5) \
	"format %s \"Unable to create \[destDirGet\].\""

set strTable(LM_DESTDIR_WARN_6) \
	"format %s \"Creating \[destDirGet\] failed: file exists.\""

set strTable(LM_DESTDIR_WARN_7) \
	"Please provide a directory path starting with a drive name."

set strTable(LM_DESTDIR_WARN_8) \
	"Please provide a directory path starting with a letter character."

set strTable(LM_DESTDIR_WARN_9) \
	"Please provide directory names starting with letter characters."

