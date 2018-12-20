# LMINFO.TCL - Setup procedures for implementing license information
#              wizard page
#
# Copyright 2003 Wind River Systems, Inc
#
# modification history
# --------------------
# 01a,18feb03,bjl  written.
#

#############################################################################
#
# pageCreate(lmInfo) - display license information
#
# This procedure will display helpful license information after a database
# query, based on whether the user is an ELM or PUF user.  
#
# SYNOPSIS
# .tS
# pageCreate(lmInfo)
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc pageCreate(lmInfo) {} {
    global ctrlVals
    global setupVals

    if {$setupVals(ELMUser) == 1} {
        set infoText [strTableGet LICINFO_ELM_TEXT]
    } else {
        set infoText [strTableGet LICINFO_PUF_TEXT]
    }

    if { [isGUImode] } {        
        set ctrlVals(volatileFrm) [list \
            [list label -name licenseInfo \
                        -xpos 100 -ypos 10 -width 190 -height 100] \
        ]

        set w [dlgFrmCreate [strTableGet LICINFO_TITLE]]

        # initialize the text box

        controlTextSet $w.licenseInfo $infoText
        
        # test automation

        if { $ctrlVals(useInputScript) } {
            autoSetupLog "License Information page: skipped"
            nextCallback
        }
    } else {
        printPageTitle [strTableGet LICINFO_TITLE]
        puts $infoText

        while {1} {
            switch -regexp -- [prompt [strTableGet 3000_RETURN_QUESTION]] {
                "^-$"   { backCallback; return 0 }
                "^$"    { nextCallback; return 0 }
                "[eE][xX][iI][tT]"  { return 0 }
                default { }
            }
        }
    }
}

#############################################################################
#
# pageProcess(lmInfo) - process inputs from lmInfo page if any
#
# This procedure will process inputs from lmInfo page if any
#
# SYNOPSIS
# .tS
# pageProcess(lmInfo)
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: 1 when successful
#
# ERRORS: N/A
#

proc pageProcess(lmInfo) {} {
    global setupVals

    if {$setupVals(ELMUser) == 1} {
        pageListAdd ELM
    } else {
        pageListAdd lmOptions		       
    }

    return 1
}

######################################################################
# Dialog Text Messages
######################################################################

set strTable(LICINFO_TITLE) "License Information"

set strTable(LICINFO_ELM_TEXT) \
    "You or your system administrator have previously set up a license\
     server in order for you to use the licensed products that you have\
     installed.\n\nThe next screen will allow you to select from the\
     available license servers."

set strTable(LICINFO_PUF_TEXT) \
    "The product you are installing requires license management. The\
     next screen will ask you to configure this machine for license\
     management.\n\nIf you select floating, you or your system\
     administrator must have previously set up a license server\
     on your network in order for you to use the licensed products\
     that you have installed on this machine."
     
