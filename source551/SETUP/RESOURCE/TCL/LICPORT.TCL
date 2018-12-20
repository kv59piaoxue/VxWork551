# LICPORT.TCL  - Setup procedures for implementing licServerPort
#                 wizard page
#
# Copyright 1999 Wind River Systems, Inc
#
# modification history
# --------------------
# 02a,12jun01,j_w  Added for Tornado 2.2
# 01d,02feb00,j_w  Updated display messages
# 01c,01feb00,bwd  Added codes for TEXT MODE
# 01b,25jan00,j_w  Added more controls and procedures
# 01a,21Jan00,j_w  written
#

global licServPort

#############################################################################
#
# pageCreate(licServerPort) - Prompt user for license Server port number
#
# This procedure prompts the user for a port number for FLEXlm license
# daemon. The default port number is 27000. The range of the valid port number
# is from 27000 to 27009
#
# SYNOPSIS
# .tS
# pageCreate(licServerPort)
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#
proc pageCreate(licServerPort) {} {
	global ctrlVals setupVals lmVals
    global licServPort

    if {$lmVals(lmPort) == ""} {
        set lmVals(lmPort) $lmVals(defaultServPort)
        set licServPort $lmVals(lmPort)
        dbgputs "using default port"
    }

    if { [isGUImode] } {
		controlHide $ctrlVals(mainWindow).bitmap 0

        set ctrlVals(volatileFrm) [list \
				[list label -name label1 \
				         -title "[strTableGet LICPORT_MSG1] $licServPort."\
				         -x 100 -y 10 -w 195 -h 30] \
				[list label -name label2 -title [strTableGet LICPORT_MSG2] \
				            -x 100 -y 40 -w 195 -h 30] \
				[list label -name label3 -title "Port Number:" \
				            -x 100 -y 80 -w 50 -h 12] \
				[list text -name portNum -border -callback onPortNum \
				           -x 150 -y 78 -w 60 -h 12] ]

        set w [dlgFrmCreate [strTableGet LICPORT_TITLE]]

		controlEnable $w.backButt 1
        controlEnable $w.cancelButt 1
        controlEnable $w.nextButt 1
		
		controlValuesSet $w.portNum $lmVals(lmPort)
		controlFocusSet $w.portNum
		onPortNum

        # test automation

        if { $ctrlVals(useInputScript) } {
			# cannot define lmVals(lmPort) in setupCfg.tcl because lmVals will
			# be populated in dbQuery page, use another var to hold user input
			#
			#set lmVals(lmPort) $lmVals(userDefinePort)
            autoSetupLog "[strTableGet LICPORT_TITLE] page: skipped"
			autoSetupLog "\tLicense Server port used: $lmVals(lmPort)"
			nextCallback
        }
    } else { # TEXT mode
        printPageTitle [strTableGet LICPORT_TITLE]
        puts "[strTableGet LICPORT_MSG1] $licServPort.\n"
        puts "[strTableGet LICPORT_MSG2_TEXT] \[$lmVals(lmPort)\]\n"

        set ret [prompt]        

        switch -regexp -- $ret {
            "^$"  {  nextCallback ; return 0  }
            "^-$" {  backCallback ; return 0  }
            "^[eE][xX][iI][tT]$" {  return 0  }
            "[0-9]+" {  
                if { $ret < $lmVals(defaultServPort) || \
			         $ret > $lmVals(lastServPort) } {

                    puts "Error: Port number must be between \
                          $lmVals(defaultServPort) and \
                          $lmVals(lastServPort).\n"

                    while {[prompt "Press <Enter> to continue."] != "" } {
                    }
                    pageCreate(licServerPort)

                } else {
                    set lmVals(lmPort) $ret
                    nextCallback
                    return 0  
                }
            }
            default {
                puts "Error: Invalid input.\n"
                while {[prompt "Press <Enter> to continue."] != "" } {
                }
                pageCreate(licServerPort)
            }
        }
    }
}

#############################################################################
#
# onPortNum - callback for portNum text box
#
# This procedure validates that the entry is all numeric and stores the
# value in lmVals(lmPort)
#
# SYNOPSIS
# .tS
# onPortNum()
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc onPortNum {} {
    global lmVals

    isNumeric [controlValuesGet wizardDialog.portNum] \
			  "[strTableGet LICPORT_TITLE]" wizardDialog.portNum
}

#############################################################################
#
# pageProcess(licServerPort) - process inputs from licServerPort page
#
# This procedure will process inputs from the lmPortVal page
#
# SYNOPSIS
# .tS
# pageProcess(licServerPort)
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: 1 or non-zero number if success; 0 if failed
#
# ERRORS: N/A
#
proc pageProcess(licServerPort) {} {
	global lmVals
	set minPortNum 1024
	set retVal 1

    if { [isGUImode] } {

        set portNumber [controlValuesGet wizardDialog.portNum]

	    # check the range of the port number
	    if { $portNumber < $minPortNum } {

		    dialog ok_with_title "[strTableGet LICPORT_TITLE]" \
			 	   "Port number must be greater than $minPortNum.\n"

		    controlFocusSet wizardDialog.portNum
		    set retVal 0

        } else {
            set lmVals(lmPort) $portNumber
        }

    } else { # TEXT MODE
	    # check the range of the port number
	    if { $lmVals(lmPort) < $minPortNum } {

            puts "Error: Port number must be greater than $minPortNum.\n"
            while {[prompt "Press <Enter> to continue."] != "" } {
            }
            pageCreate(licServerPort)
        }
    }

    dbgputs "Port number: $lmVals(lmPort)"

	return $retVal
}



######################################################################
# Dialog Text Messages
######################################################################
global lmVals

set strTable(LICPORT_TITLE) \
		"License Server Port"

set strTable(LICPORT_MSG1) \
		"SETUP will use the port number below to configure the\
		License Server on this host. The current License Server port on this\
		host is "

set strTable(LICPORT_MSG2) \
		"If you wish to change the port, please enter a port number\
		greater than 1024. Otherwise, click <Next> to continue."

set strTable(LICPORT_MSG2_TEXT) \
		"If you wish to change the port, please enter a port number\
		greater than 1024. Otherwise, \
        press \<Return\> to continue with this port."
