# LMAUMAN.TCL - Setup procedures for implementing the auto/manual choice page
#
# Copyright 2003 Wind River Systems, Inc
#
# modification history
# --------------------
# 01a,14feb03,bjl  written.
#

############################################################################
#
# pageCreate(lmAutoManChoice) - displays choice of auto or manual license
#                               configuration
#                        
#
# This page will give the user the choice between the automated and manual 
# license configurations.  
#
# SYNOPSIS
# .tS
# pageCreate(lmAutoManChoice)
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc pageCreate(lmAutoManChoice) {} {
    global ctrlVals env setupVals lmVals

    if { [isGUImode] } {
        set ctrlVals(volatileFrm) [list \
                    [list label -name message1 \
                                -title [strTableGet LM_AUMAN_MSG_1] \
                                -x 100 -y 10 -w 190 -h 36] \
                    [list choice -name autoChoice -newgroup -auto \
                                -title [strTableGet LM_AUMAN_BTN_1] \
                                -x 102 -y 46 -w 190 -h 15 \
                                -callback onAuto] \
                    [list label -name autoLabel \
                                -title \
                                 [strTableGet LM_AUMAN_BTN_1_DESC] \
                                -x 114 -y 60 -w 180 -h 25] \
                    [list choice -name manualChoice -auto \
                                -title [strTableGet LM_AUMAN_BTN_2] \
                                -x 102 -y 88 -w 190 -h 15 \
                                -callback onManual] \
                    [list label -name manualLabel  \
                                -title [strTableGet LM_AUMAN_BTN_2_DESC] \
                                -x 114 -y 103 -w 180 -h 25]                    
                    ]

        set w [dlgFrmCreate [strTableGet LM_AUMAN_TITLE]]


        if { $setupVals(evaluation) == 1 } {
            controlEnable $w.autoChoice 0
            controlCheckSet $w.manualChoice 1            
        }

        # unhide the help button - no use during copying
        controlEnable $w.helpButt 1

        if { [isTornadoProduct] } {
            controlEnable $w.helpButt 1
        } else {
            controlEnable $w.helpButt 0
        }

        switch $setupVals(lmAutoManChoice) {
            onAuto   { controlCheckSet $w.autoChoice 1 }
            onManual { controlCheckSet $w.manualChoice 1 }
            default  { controlCheckSet $w.autoChoice 1 }
        }

                
        controlValuesSet $w.nextButt "&Next >"
        if {$setupVals(lmError) != "" || [instTypeGet] == "license"} {
            controlEnable $w.backButt 1
        } else {
            controlEnable $w.backButt 0
        }
        controlEnable $w.nextButt 1
        controlEnable $w.cancelButt 1

        # test automation

        if { $ctrlVals(useInputScript) } {
            autoSetupLog "LM Auto/Man page: Skipped"
            autoSetupLog "\tLM Option: $setupVals(lmAutoManChoice)"
            nextCallback
        }

    } else { # TEXT mode

        printPageTitle [strTableGet LM_AUMAN_TITLE]
        puts [strTableGet LM_AUMAN_MSG_1_TEXT]
        puts "1 - [strTableGet LM_AUMAN_BTN_1]"
        puts "[strTableGet LM_AUMAN_BTN_1_DESC_TEXT]\n"
        puts "2 - [strTableGet LM_AUMAN_BTN_2]"
        puts "[strTableGet LM_AUMAN_BTN_2_DESC]\n"

        while (1) {
            puts "Please enter the number of your selection. \[1\]"
            set ret [prompt]
            switch -regexp -- $ret {
                "^$" -
                "^1$" { 
                    onAuto
                    nextCallback
                    return 0
                }
                "^2$" { 
                    onManual                    
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
# pageProcess(lmAutoManChoice) - process inputs from lmAutoManChoice page 
#
# This procedure will process inputs from the lmAutoManChoice page
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

proc pageProcess(lmAutoManChoice) {} {
    global setupPageList setupVals ctrlVals lmVals
    set retVal 1

    switch $setupVals(lmAutoManChoice) {
        onAuto {     
            set setupVals(lmManual) 0       
            pageListAdd dbQuery
        }
        onManual {
            set setupVals(lmManual) 1
            pageListAdd lmOptions                       
        }
    }    
    dbgputs "lmAutoManChoice: $ctrlVals(pageList)"

    return $retVal
}

#############################################################################
#
# onAuto - set up to configure user to use floating licenses
#
# This procedure is a callback which allows the user to configure tornado for
# floating licensing
#
# SYNOPSIS
# .tS
# onAuto
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc onAuto {} {
    global setupVals ctrlVals
    global LMHelpPath

    set setupVals(lmAutoManChoice) onAuto
    set lmVals(reloadExistingLicense) 0
    set LMHelpPath "float"

    if {[isGUImode]} {
        set w $ctrlVals(mainWindow)
    }
}


#############################################################################
#
# onManual - setup to configure user for node locked licensing
#
# This procedure is a callback which allows the user to configure tornado for
# node locked licensing.
#
# SYNOPSIS
# .tS
# onManual
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc onManual {} {
    global setupVals ctrlVals

    set setupVals(lmAutoManChoice) onManual

    if {[isGUImode]} {
        set w $ctrlVals(mainWindow)
    }
}

######################################################################
# Dialog Text Messages
######################################################################

set strTable(LM_AUMAN_TITLE) "License Management Auto/Manual Choice"

set strTable(LM_AUMAN_MSG_1) \
    "SETUP has detected that one or more products\
    are license managed.  Choose one of the options below."

set strTable(LM_AUMAN_MSG_1_TEXT) \
    "SETUP has detected that one or more products\
    are license managed.\nChoose one of the options below.\n"

set strTable(LM_AUMAN_BTN_1) \
    "Automated License Configuration (Recommended)"

set strTable(LM_AUMAN_BTN_1_DESC) \
    "Contact Wind River to obtain license information.\
     An Internet connection is required."

set strTable(LM_AUMAN_BTN_1_DESC_TEXT) \
    "Contact Wind River to obtain license information.\nAn\
     internet connection is required."

set strTable(LM_AUMAN_BTN_2) \
    "Manual License Configuration"

set strTable(LM_AUMAN_BTN_2_DESC) \
    "Manually configure to use a local license server, or\
     contact Wind River via email or phone to obtain a license\
     file."
