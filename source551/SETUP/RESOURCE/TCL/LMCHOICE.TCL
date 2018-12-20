# LMCHOICE.TCL - Setup procedures for selecting license management options for 
# 	       end users 
#
# Copyright 1999 Wind River Systems, Inc
#
# modification history
# --------------------
# 02b,05mar02,bwd  Modified SETUP to be non-tornado centric
# 02a,12jun01,j_w  Modified for Tornado 2.2
# 01f,01may00,j_w  Renamed "nodeLock" to "nodeLocked" for
#                  setupVals(lmInstType)
# 01e,20mar00,bwd  Fixed TEXT mode to default a choice to Floating license
#                  option
# 01d,07jan00,wmd  Need to rename procedures so that they don't clash.
# 01c,06jan00,bwd  No test automation for command line SETUP
# 01b,14dec99,wmd  Fix the spacing for controls.
# 01a,14dec99,wmd  created.
#

#############################################################################
#
# pageCreate(lmChoice) - displays choices for LM installation
#
# This procedure will display choices for LM installation such as:
#  Floating - to configure floating licenses OR
#  Node Locked - to configure tornado tools to be bound to the user's host
#
# SYNOPSIS
# .tS
# pageCreate(lmChoice)
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#


proc pageCreate(lmChoice) {} {
    global ctrlVals env setupVals

    if { [isGUImode] } {
        set ctrlVals(volatileFrm) [list \
                    [list label -name message1 \
                                -title [strTableGet LM_CHOICES_MSG_1] \
                                -x 100 -y 10 -w 190 -h 30] \
                    [list choice -name floatingChoice -newgroup -auto \
                                -title [strTableGet LM_CHOICES_BTN_1] \
                                -x 102 -y 39 -w 190 -h 12 \
                                -callback onLMCFloating] \
                    [list label -name floatingLabel \
                                -title \
	   		        [strTableGet LM_CHOICES_BTN_1_DESC] \
                                -x 114 -y 51 -w 180 -h 22] \
                    [list choice -name nodeLockChoice -auto \
                                -title [strTableGet LM_CHOICES_BTN_2] \
                                -x 102 -y 73 -w 190 -h 12 \
                                -callback onLMCNodeLock] \
		    [list label -name nodeLockLabel  \
                                -title \
			        [strTableGet LM_CHOICES_BTN_2_DESC] \
                                -x 114 -y 86 -w 180 -h 15] \
                    ]
        set w [dlgFrmCreate [strTableGet LM_CHOICES_TITLE]]

        switch $setupVals(lmChoice) {
            onLMCFloating  { controlCheckSet $w.floatingChoice 1 }
            onLMCNodeLock  { controlCheckSet $w.nodeLockChoice 1 }
            default     { controlCheckSet $w.floatingChoice 1 }
        }

        controlEnable $w.backButt 0
        controlEnable $w.nextButt 1
        controlEnable $w.cancelButt 1

        # test automation

        if { $ctrlVals(useInputScript) } {
            autoSetupLog "LM Option page: Skipped"
            autoSetupLog "\tLM Option: $setupVals(lmChoice)"
            nextCallback
        }

    } else { # TEXT mode

        printPageTitle [strTableGet LM_CHOICES_TITLE]
        puts [strTableGet LM_CHOICES_MSG_1_TEXT]
        puts "1 - [strTableGet LM_CHOICES_BTN_1]"
        puts "[strTableGet LM_CHOICES_BTN_1_DESC]\n"
        puts "2 - [strTableGet LM_CHOICES_BTN_2]"
        puts "[strTableGet LM_CHOICES_BTN_2_DESC]\n"

        while (1) {
            set ret [prompt "Please enter your selection. \[1\]"]
            switch -regexp -exact -- $ret {
                "^$" -
                "1" { 
                    onLMCFloating
                    nextCallback
                    return 0
                }
                "2" { 
                    onLMCNodeLock
                    nextCallback
                    return 0
                }
                "[eE][xX][iI][tT]" {
                    return 0
                }
                default { 
                    puts "Error: The number you have entered is invalid."
                }
            }
        }
    }
}

#############################################################################
#
# pageProcess(lmChoice) - process inputs from lmChoice page if any
#
# This procedure will process inputs from lmChoice page if any
#
# SYNOPSIS
# .tS
# pageProcess(lmChoice)
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: 1 when successful
#
# ERRORS: N/A
#

proc pageProcess(lmChoice) {} {
    global setupPageList setupVals ctrlVals tornadoInstalled

    #initPageList

    switch $setupVals(lmChoice) {
	onLMCFloating {
            pageListAdd autoInst
	    set setupVals(lmInstType) "floating"
	}
	onLMCNodeLock {
	    pageListAdd nodeLock
	    set setupVals(lmInstType) "nodeLocked"
	}
    }
    
    dbgputs "lmChoice: $ctrlVals(pageList)"

    return 1
}

#############################################################################
#
# onLMCFloating - set up to configure user to use floating licenses
#
# This procedure is a callback which allows the user to configure tornado for
# floating licensing
#
# SYNOPSIS
# .tS
# onLMCFloating
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc onLMCFloating {} {
    global setupVals

    set setupVals(lmChoice) onLMCFloating
}


#############################################################################
#
# onLMCNodeLock - setup to configure user for node locked licensing
#
# This procedure is a callback which allows the user to configure tornado for
# node locked licensing.
#
# SYNOPSIS
# .tS
# onLMCNodeLock
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc onLMCNodeLock {} {
    global setupVals

    set setupVals(lmChoice) onLMCNodeLock
}


######################################################################
# Dialog Text Messages
######################################################################

set strTable(LM_CHOICES_TITLE) "License Management Configuration Options"

set strTable(LM_CHOICES_MSG_1) \
        "Choose one of the options below to select the type of license\
        management you want to configure your host for.  Then click on\
        the <Next> button to continue:"

set strTable(LM_CHOICES_MSG_1_TEXT) \
        "Choose one of the options below to select the type of license\
        management you want to configure your host for.  Then click on\
        the <Next> button to continue:\n"

set strTable(LM_CHOICES_BTN_1) \
	"Floating License Configuration"

set strTable(LM_CHOICES_BTN_1_DESC) \
        "Confgure this host to serve licenses for [getProdInfo name] products\
        over your local area network."

set strTable(LM_CHOICES_BTN_2) \
	"Node Locked License Configuration."

set strTable(LM_CHOICES_BTN_2_DESC) \
        "Configure to use licensed [getProdInfo name] products only on this\
        host (or node)."
