# LMCONFIRM.TCL  - Setup procedures for implementing install LM confirm 
#                 wizard page
#
# Copyright 1999 Wind River Systems, Inc
#
# modification history
# --------------------
# 02a,12jun01,j_w  Modified for Tornado 2.2
# 01m,08dec00,bwd  Remove writing LM_LICENSE_FILE for end user license 
#                  config - this is done in FINISH page
# 01l,30oct00,j_w  Added queueExecute at the end of pageProcess
# 01k,23oct00,j_w  Fixed typo
# 01j,10apr00,bwd  Changed the name of the registry key for license management
#                  to LM_LICENSE_FILE
# 01i,07apr00,bwd  Added codes to write license info to registry
#                  WRSD_LICENSE_FILE
# 01h,06jan00,bwd  No test automation for command line SETUP
# 01g,02dec99,clc  add text mode
# 01f,30nov99,wmd  Fix so that duplicate strings are eliminated from
#                  LM_LICENSE_FILE.
# 01e,29nov99,wmd  Fix typos.
# 01d,24nov99,bwd  Added sections for automatic LM Installation
# 01c,23nov99,wmd  Add code to set LM_LICENSE_FILE in the registry for
#                  windows.
# 01b,22nov99,wmd  Add logic to implement this page.
# 01a,29Oct99,wmd  written.
#

#############################################################################
#
# pageCreate(lmRegister) - confirm floating license server for end user license
#
# This procedure will create a page to provide information to users which
# license server(s) has been selected for floating license
#
# SYNOPSIS
# .tS
# pageCreate(lmRegister)
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc pageCreate(lmRegister) {} {
    global ctrlVals setupVals lmVals

    if { [isGUImode] } {
        set serverList ""
        for {set ix 0} {$ix < [llength $lmVals(lmHostOrder)]} {incr ix} {
            append serverList [format "\t%s\r\n" [lindex $lmVals(lmHostOrder) $ix]]
        }
        set ctrlVals(volatileFrm) [list \
            [list label -name lmRegisterText \
                -title [strTableGet LMREGIST_MSG1] \
                -x 100 -y 10 -w 200 -h 24] \
            [list label -name lmRegisterText2 \
                -title [strTableGet LMREGIST_MSG2] \
                -x 100 -y 38 -w 200 -h 12] \
            [list label -name lmRegisterText3 \
                -title $serverList \
                -x 100 -y 50 -w 200 -h 80] \
            ]

        set w [dlgFrmCreate [strTableGet LMREGIST_TITLE_WINDOWS]]

        # the following is to workaround a bug in UITclSh: 
        # if the user presses Return for the OK button, 
        # UITclSh does not exit.

        if {[isUnix]} {
            controlPropertySet $w.nextButt -defaultbutton 0
            controlFocusSet $w.cancelButt
        } else {
            controlFocusSet $w.nextButt
        }

        # test automation

        if { $ctrlVals(useInputScript) } {
            autoSetupLog "License Management Registration Page: skipped"
            autoSetupLog "[strTableGet LMREGIST_MSG1]"
            autoSetupLog "\t[strTableGet LMREGIST_MSG2] $lmVals(lmHostOrder)"
            nextCallback
        }

    } else { # text mode

        set serverList ""
        for {set ix 0} {$ix < [llength $lmVals(lmHostOrder)]} {incr ix} {
            append serverList [format "\t%s\r\n" [lindex $lmVals(lmHostOrder) $ix]]
        }

        # display page header and selected servers

        printPageTitle [strTableGet LMREGIST_TITLE_WINDOWS]
        puts "[strTableGet LMREGIST_MSG1]\n"
        puts [strTableGet LMREGIST_MSG2]
        foreach server $serverList {
            puts $server
        }

		puts "\n"

        # prompt to continue

        set msg "Press <Enter> to continue."
        while { [prompt $msg] != "" } {
        }
        nextCallback
        return 0
   }
}

#############################################################################
#
# pageProcess(lmRegister) - proceed to the next page with selected server(s)
#
# This procedure will proceed with selected server(s) for end user license
#
# SYNOPSIS
# .tS
# pageProcess(lmRegister)
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: 1 when successful
#
# ERRORS: N/A
#

proc pageProcess(lmRegister) {} {
    return 1
}


######################################################################
# Dialog Text Messages
######################################################################

set strTable(LMREGIST_TITLE_WINDOWS) "License Management Registration"

        
set strTable(LMREGIST_MSG1) \
	"Setup will now write the license configuration into the\
        windows registry on this host."

set strTable(LMREGIST_MSG2) \
        "Selected Server(s): "
