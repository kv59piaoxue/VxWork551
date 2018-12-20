# REGHOST.TCL - Setup procedures for implementing remote-registry host 
#               wizard page
#
# Copyright 1999-2003 Wind River Systems, Inc
#
# modification history
# --------------------
# 02c,29apr03,bjl  text rewording.
# 02b,17may02,wmd  Fix text formatting, grammatical problems.
# 02a,12jun01,j_w  Modified for Tornado 2.2
# 01c,24mar99,bjl  turn off inf write to registry after queueExecute.
# 01b,22mar99,bjl  set setupVals(torRegOption) for Unix for compatibility 
#                  page. 
# 01a,26jan99,tcy  extracted from INSTW32.TCL.
#

#############################################################################
#
# pageCreate(remoteRegistryHost) - prompt for host name to install tornado
#                                  registry
#
# This procedure will prompt for host name to install tornado registry
#
# SYNOPSIS
# .tS
# pageCreate(remoteRegistryHost)
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc pageCreate(remoteRegistryHost) {} {
    global ctrlVals
    global setupVals

    if {[isUnix]} {
        set regmsg [strTableGet REMOTEREGHOST_MSG_UNIX]
    } else {
        set regmsg [strTableGet REMOTEREGHOST_MSG_WIN]
    }

    set ctrlVals(volatileFrm) [list \
             [list label -name msg0 \
                         -title $regmsg \
                         -x 100 -y 10 -w 205 -h 74] \
             [list label -name msg1 -title "Host Name:" \
                         -x 100 -y 94 -w 40 -h 10] \
             [list text -name remoteReg -border \
                        -x 150 -y 92 -w 148 -h 13] \
    ]

    set w [dlgFrmCreate [strTableGet REMOTEREGHOST_TITLE]]

    controlValuesSet $w.remoteReg [windRegValueRead]
    controlFocusSet $w.remoteReg
    controlEnable $w.backButt 1

    # test automation

    if { $ctrlVals(useInputScript) } {
        controlValuesSet $w.remoteReg $setupVals(registry)
        autoSetupLog "Tornado Registry page:"
        autoSetupLog "\tRegistry Host: $setupVals(registry)"
        nextCallback
    }
}

#############################################################################
#
# pageProcess(remoteRegistryHost) - process inputs from remoteRegistryHost page
#
# This procedure will process inputs from remoteRegistryHost page
#
# SYNOPSIS
# .tS
# pageProcess(remoteRegistryHost)
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc pageProcess(remoteRegistryHost) {} {
    global ctrlVals
    global setupVals
    global infVals

    set setupVals(registry) [controlValuesGet $ctrlVals(mainWindow).remoteReg]
    
    if {[isUnix]} {

        # need to set this here since torRegistry page is removed for Unix

        set setupVals(torRegOption) torRegRemote
        set infVals(torRegRemote) 1
    }

    if {![regexp {^[ ]*$} "$setupVals(registry)" junk]} {
        searchAndProcessSection AddRegistry [cdFileNameGet [file join RESOURCE \
                                             INF TORNADO.INF]]
        queueExecute
        set infVals(torRegRemote) 0
        return 1
    } else {
        messageBox "Please enter a valid registry name"
        return 0
    }
}

######################################################################
# Dialog Text Messages
######################################################################

set strTable(REMOTEREGHOST_TITLE) "Tornado Registry Location"

set strTable(REMOTEREGHOST_MSG_UNIX) \
    "The Tornado target server registry is a daemon that keeps track\
     of all available targets by name.  Only one registry is required\
     on your network, and it can run on any networked host.  It is\
     recommended that a development site use a single registry for\
     the entire network; this provides maximum flexibility, allowing\
     any Tornado user at the site to connect to any target.\
     \n\nEnter the name of the host on which the Tornado registry\
     will be running."
     
set strTable(REMOTEREGHOST_MSG_WIN) \
    "Please enter the name of the host where the Tornado registry will\
     be running."

