# HELPW32.TCL - Automated help support for UITcl-created widgets
#
# Copyright (C) 1995-98 Wind River Systems, Inc.
#
# modification history
# --------------------
# 01d,13jan99,wmd  Update the file to WRS coding conventions.
# 01c,08oct98,tcy  fixed file case
# 01b,30sep98,tcy  changed SETUP.hh to SETUP.HH for UNIX
# 01a,26aug98,tcy  originally from host/resource/tcl/help.win32.tcl
#

##############################################################################
#
# Code to automate help for UITcl-created dialogs, windows, controls and
# toolbars follows
#

#
# Flag to enable debugging mode, wherein controls w/o help ids
# get logged to the console 
#

set nonExistentIdsLog 0

#
# Sub-classing the following functions:
#

rename controlCreate controlCreateOrig
rename dialogCreate dialogCreateOrig
rename windowCreate windowCreateOrig
rename toolbarCreate toolbarCreateOrig

##############################################################################
#
# shouldHaveHelp - determine if a control should have a helpid associated
#
# The following function determines if a control should have
# a helpid associated with it
#
# SYNOPSIS
# shouldHaveHelp <controlType>
#
# PARAMETERS:
#
# RETURNS:
#
# ERRORS:
#

proc shouldHaveHelp {controlType} {
    set noHelpControls [list frame rectangle group label]

    if {[lsearch $noHelpControls $controlType] == -1} {
        return 1
    } else {
        return 0
    }
}

##############################################################################
#
# getFileContents - get contents of a help file
# 
# This proc returns a list of symbolic and numeric IDs for a specified
#       help file
#
# SYNOPSIS
# getFileContents <helpFile>
#
#
# PARAMETERS:
#       helpFile : a helpfile path
#
# RETURNS: The contents of a helpfile.HH file or the NULL string if the file
#       doesn't exists.
#
# ERRORS:
#


proc getFileContents {helpFile} {
    set symbolicNumericHelpIdMap ""
    set dicFile [file join [cdromRootDirGet] RESOURCE HELP $helpFile.HH]

    if {[file exists $dicFile]} {
        set dicFileHandle [open $dicFile r]
        while {[gets $dicFileHandle line] >= 0} {
            if {$line != ""} {
                set symbolicNumericHelpIdMap "$symbolicNumericHelpIdMap $line"
            }
        }
        close $dicFileHandle
    } {
        puts "Can't find $dicFile"
    }

    return $symbolicNumericHelpIdMap
}

#
# Set the symbolicNumericHelpIDMap global variable only once for later symbolic
# and numeric mapping
#

set symbolicNumericHelpIdMap 	[getFileContents SETUP]

##############################################################################
#
# controlCreate - subclassed proc which looks for helpids
# 
# SYNOPSIS
# This function appends the "-helpid <id>" string to the control, and calls 
#       the real controlCreate function to complete the job.
#
# PARAMETERS:
#
# RETURNS: N/A
#
# ERRORS: N/A
# 

proc controlCreate {args} {
    global symbolicNumericHelpIdMap nonExistentIdsLog

    set controlIndex [expr [lsearch [lindex $args 1] "-name"] +1]	
    set controlName ""
    set controlType [lindex [lindex $args 1] 0]

    # Control has to be named and cannot be frame, etc.
    if {$controlIndex != 0 && [shouldHaveHelp $controlType]} {
        set controlName [lindex [lindex $args 1] $controlIndex]
    } 
    set windowName [lindex $args 0]

    set cmd ""
    if {$controlName != ""} {
        set symbolicHelpId [format "HIDC_%s_%s" $windowName $controlName]
        set idIndex [expr \
                    [lsearch $symbolicNumericHelpIdMap $symbolicHelpId] +1]
        if {$idIndex != 0} {
            set cmd [linsert [lindex $args 1] 1 -helpid \
                    [format "%d" [lindex $symbolicNumericHelpIdMap $idIndex]]]
        } else {
           if {$nonExistentIdsLog == "1"} {
               puts [format "No helpid for control %s.%s" $windowName \
                             $controlName]
           }
        }
    }

    if {$cmd == ""} {
        set cmd [lindex $args 1]
    }

    controlCreateOrig [lindex $args 0] $cmd
}


##############################################################################
#
# toolbarCreate - subclassed proc to append helpids to the toolbar
# 
# This procedure appends the "-helpid <id>" string to the toolbar
# control, and calls the real toolbarCreate function to complete the job.
#
# SYNOPSIS
# toolbarCreate <args>
#
#
# PARAMETERS:
#   args : arguments passed to the orignal toolbarCreate proc.
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc toolbarCreate {args} {
    global nextNumericHelpId symbolicNumericHelpIdMap nonExistentIdsLog

    set index [expr [lsearch $args "-name"] +1]
    set windowName ""
    set helpStr ""

    if {$index != 0 } {
        set windowName [lindex $args $index]
    }

    if {$windowName != ""} {
        set symbolicHelpId [format "HIDW_%s" $windowName]
        set idIndex [expr \
                    [lsearch $symbolicNumericHelpIdMap $symbolicHelpId] +1]

        if {$idIndex != 0} {
            set helpStr [format "-helpid %d" \
                [expr [lindex $symbolicNumericHelpIdMap $idIndex] - 0x50000]]
        } else {
            if {$nonExistentIdsLog == "1"} {
                puts [format "No helpid for toolbar %s" $windowName]
            }
        }
    }

    set cmd [format "toolbarCreateOrig %s %s" $helpStr $args]

    eval "$cmd"
}


##############################################################################
#
# dialogCreate - subclassed procedure to handle help ids.
# 
# This function appends the "-helpid <id>" string to the control,and calls
# the real dialogCreate function to complete the job.
#
# SYNOPSIS
# dialogCreate <args>
#
# PARAMETERS: The orignal args sent passed to dialogCreate
#
# RETURNS: N/A
#
# ERRORS: N/A
# 

proc dialogCreate {args} {
    global symbolicNumericHelpIdMap nonExistentIdsLog

    set cmd ""
    set helpStr ""
    set index [expr [lsearch $args "-name"] +1]
    set windowName ""

    if {$index != 0} {
        set windowName [lindex $args $index]
    }

    if {$windowName != ""} {
	set symbolicHelpId [format "HIDD_%s" $windowName]
        set index [expr [lsearch $symbolicNumericHelpIdMap $symbolicHelpId] +1]

        if {$index != 0} {
            set helpStr [format "-helpid %d" \
                [expr [lindex $symbolicNumericHelpIdMap $index] - 0x20000]]
        } else {
            if {$nonExistentIdsLog == "1"} {
                puts [format "No helpid for dialog %s" $windowName]
            }
        }
    }

    # If there is a -controls option, process all the controls as well
    set ctrlIndex [expr [lsearch $args "-controls"] +1]
    set newCtrlsData ""
	
    if {$ctrlIndex != 0} {
        set ctrlsData [lindex $args $ctrlIndex]
        set newCtrlsData [controlProcess $ctrlsData $windowName]
        set args [lreplace $args $ctrlIndex $ctrlIndex $newCtrlsData]
    } 

    set cmd [format "dialogCreateOrig %s %s" $helpStr $args]

    eval "$cmd"
}


##############################################################################
#
# windowCreate - procedure to append help ids
# 
# This function append the "-helpid <id>" string to the control, and calls
# the real windowCreate function to complete the job.
#
# SYNOPSIS
# windowCreate <args>
#
# PARAMETERS: 
#   args : the orignal args passed to windowCreate
#
# RETURNS: N/A
#
# ERRORS: N/A
# 

proc windowCreate {args} {
    global symbolicNumericHelpIdMap nonExistentIdsLog

    set cmd ""
    set index [expr [lsearch $args "-name"] +1]
    set windowName ""
    set helpStr ""

    if {$index != 0} {
        set windowName [lindex $args $index]
    }

    if {$windowName != ""} {
        set symbolicHelpId [format "HIDW_%s" $windowName]
        set index [expr [lsearch $symbolicNumericHelpIdMap $symbolicHelpId] +1]

        if {$index != 0} {
            set helpStr [format "-helpid %d" \
                        [expr [lindex $symbolicNumericHelpIdMap \
                         $index] - 0x50000]]
        } else {
            if {$nonExistentIdsLog == "1"} {
                puts [format "No helpid for window %s" $windowName]
            }
        }
    }

    # If there is a -controls option, process all the controls as well
    set ctrlIndex [expr [lsearch $args "-controls"] +1]
    set newCtrlsData ""

    if {$ctrlIndex != 0} {
        set ctrlsData [lindex $args $ctrlIndex]
        set newCtrlsData [controlProcess $ctrlsData $windowName]
        set args [lreplace $args $ctrlIndex $ctrlIndex $newCtrlsData]
    }

    set cmd [format "windowCreateOrig %s %s" $helpStr $args]

    eval "$cmd"
}


##############################################################################
#
# controlProcess -
# 
# This procedure takes a list of list, appends the "-helpid <id>" string to 
# each sublist, and returns the modified list of lists.
#
# SYNOPSIS
# controlProcess <args>
#
# PARAMETERS: 
#    args : the orginal arguments passed to the control
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc controlProcess {args} {
    global symbolicNumericHelpIdMap nonExistentIdsLog

    set windowName [lindex $args 1]

    foreach ctrlData [lindex $args 0] {
        set index [expr [lsearch $ctrlData "-name"] +1]
        set ctrlName ""
        set controlType [lindex $ctrlData 0]
		
        # Control has to be named and cannot be frame, etc.
        if {$index != 0 && [shouldHaveHelp $controlType]} {
            set ctrlName [lindex $ctrlData $index]
        }

        set newCtrlData ""
        if {$ctrlName != ""} {
            set symbolicHelpId [format "HIDC_%s_%s" $windowName $ctrlName]
            set idIndex [expr \
                        [lsearch $symbolicNumericHelpIdMap $symbolicHelpId] +1]

            if {$idIndex != 0} {
                set newCtrlData [linsert $ctrlData 1 "-helpid" \
  		    [format "%d" [lindex $symbolicNumericHelpIdMap $idIndex]]]
                lappend newCtrlsData $newCtrlData
            } else {
                if {$nonExistentIdsLog == "1"} {
                    puts [format "No helpid for %s.%s" $windowName $ctrlName]
                }
            }
        }
        if {$newCtrlData == ""} {
            lappend newCtrlsData $ctrlData
        }
    }
    return $newCtrlsData
}
