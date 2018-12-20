# PRVLEGE.TCL - Setup procedures for implementing privilege wizard page
#
# Copyright 1999 Wind River Systems, Inc
#
# modification history
# --------------------
# 03a,12jun01,j_w  Modified for Tornado 2.2
# 02a,30Sep99,j_w  Modified for T3
# 01b,21jul99,j_w  added text messages
# 01a,26jan99,tcy  extracted from INSTW32.TCL.
#

#############################################################################
#
# pageCreate(privilege) - warn users of non-administrator privileges
#
# This procedure will warn users of non-administrator privileges
#
# SYNOPSIS
# .tS
# pageCreate(privilege)
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc pageCreate(privilege) {} {
    global ctrlVals

    set ctrlVals(volatileFrm) [list \
            [list label -name message \
                        -title [strTableGet PRIVILEGE_ROOT_WARN]\
                        -x 100 -y 10 -w 193 -h 100] \
    ]

    set w [dlgFrmCreate [strTableGet PRIVILEGE_TITLE]]

    # test automation

    if { $ctrlVals(useInputScript) } {
        autoSetupLog "Privilege page:"
        autoSetupLog "\tWarning: Installation continues\
        without System Administrator privileges."
        nextCallback
    }

}

#############################################################################
#
# pageProcess(privilege) - process inputs from privilege page if any
#
# This procedure will process inputs from privilege page if any
#
# SYNOPSIS
# .tS
# pageProcess(privilege)
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: 1 when successful
#
# ERRORS: N/A
#

proc pageProcess(privilege) {} {
    return 1
}


######################################################################
# Dialog Text Messages
######################################################################

set strTable(PRIVILEGE_TITLE) "Warning"

set strTable(PRIVILEGE_ROOT_WARN) \
    "format %s \"Installing \[cdromDescGet\] without System Administrator\
    privileges is not recommended.  Under your present privileges,\
    SETUP will not offer certain installation options, such as \
    the installation of some services, etc.  Also, the software\
    will be installed as a personal copy and will not be visible\
    to other users on this machine.\
    \n\nTo install \[cdromDescGet\] with access to all its\
    installation features and options, we suggest that you exit\
    the installation now and rerun it later with System\
    Administrator\'s privileges.\n\nClick <Next> to continue with\
    SETUP anyway.\""

