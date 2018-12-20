# COMPTBLE.TCL - Setup procedures for implementing backward compatibility
#                wizard page
#
# Copyright 1999 Wind River Systems, Inc
#
# modification history
# --------------------
# 03a,12jun01,j_w  Modified for Tornado 2.2
# 02b,01feb00,bwd  Fixed error handling for test automation
# 02a,30Sep99,j_w  Modified for T3
# 01f,11aug99,j_w  Added messages
# 01e,20apr99,bjl  added Release Notes message.  
# 01d,24mar99,bjl  set infVals options for portmapper registry.
# 01c,22mar99,bjl  display service message only if NT, added Unix 
#                  torRegRemote message, changed howTo title.  
# 01b,22feb99,tcy  modified to align messages
# 01a,10feb99,tcy  written.
#

#############################################################################
#
# pageCreate(compatibility) - ask user if backward compatibility is requested
#
# This procedure will ask user if backward compatibility is requested
#
# SYNOPSIS
# .tS
# pageCreate(compatibility)
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc pageCreate(compatibility) {} {
    global ctrlVals
    global setupVals
    global infVals

    set yesCtrl [list choice \
                -name yes \
                -title "Install portmapper for use with T1.0.1 tools" \
                -callback {onCompatibilitySel yes}\
                -newgroup -auto \
                -x 100 -y 65 -w 205 -h 10]

    set noCtrl [list choice \
                -name no \
                -title "Don't install portmapper - won't use T1.0.1 tools" \
                -callback {onCompatibilitySel no}\
                -auto \
                -x 100 -y 78 -w 205 -h 10]

    set ctrlVals(volatileFrm) [list \
            [list label -name message \
                        -title [strTableGet COMPATIBILITY_MSG_1]\
                        -x 100 -y 10 -w 193 -h 50] \
            $yesCtrl $noCtrl\
            [list label -name message2 \
                        -title [strTableGet COMPATIBILITY_MSG_2]\
                        -x 100 -y 100 -w 193 -h 20] \
            [list label -name message_service \
                        -title [strTableGet COMPATIBILITY_MSG_3]\
                        -x 100 -y 125 -w 193 -h 50] \
    ]

    set w [dlgFrmCreate [strTableGet COMPATIBILITY_TITLE]]

    set setupVals(compatibilityAction) no

    controlCheckSet $w.$setupVals(compatibilityAction) 1
    controlFocusSet $w.$setupVals(compatibilityAction)

    controlEnable $w.backButt 1
    controlEnable $w.nextButt 1

    # set default icon settings for the inf file

    set infVals(torRegPortmapper) 0
    if {$setupVals(torRegOption) == "torRegStartup"} {
        set infVals(torRegStartup) 1
        set infVals(torRegStartupPortmapper) 0
    }

    # don't display the message about a service if the host is not
    # Windows NT

    if {!$ctrlVals(NT)} {
        controlHide $w.message_service 1
    }

    # test automation

    if { $ctrlVals(useInputScript) } {
        autoSetupLog "Backward Compatilibity page:"
        nextCallback
    }

}

#############################################################################
#
# onCompatibilitySel - set the variable in ctrlVals when option is changed
#
# This procedure will set the variable in ctrlVals when option is changed
#
# SYNOPSIS
# .tS
# onCompatibilitySel <opt>
# .tE
#
# PARAMETERS:
# .IP opt
# option selected
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc onCompatibilitySel {opt} {
    global ctrlVals

    set ctrlVals(compatibilityAction) $opt

    # Currently there is no way to start the registry as a service and
    # retain Tornado 1.0.x backward compatibility

    if { "$opt" == "yes" && $ctrlVals(torRegAction) == "torRegNTServ" } {

        if { $ctrlVals(useInputScript) } {
            autoSetupLog "There is no way to retain backward compatibility if\
                          you have selected to install the Tornado Registry\
                          as a service.  Please choose another option for\
                          starting the Tornado Registry or select \"no\"\
                          for backward compatibility."
            autoSetupLog "Application Exit\n"
            set setupVals(cancel) 1                
            applicationExit
            return 0
        } else {
            messageBox "There is no way to retain backward compatibility if\
                        you have selected to install the Tornado Registry as a\
                        service. Select <Back> to choose another option for\
                        starting the Tornado Registry or select \"no\" for\
                        backward compatibility."
        }

        controlEnable $ctrlVals(mainWindow).nextButt 0
    } else {
        controlEnable $ctrlVals(mainWindow).nextButt 1
    }
}


#############################################################################
#
# pageProcess(compatibility) - process inputs from compatibility page if any
#
# This procedure will process inputs from compatibility page if any
#
# SYNOPSIS
# .tS
# pageProcess(compatibility)
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: 1 when successful
#
# ERRORS: N/A
#

proc pageProcess(compatibility) {} {
    global setupVals
    global ctrlVals
    global infVals
   
    if { "$ctrlVals(compatibilityAction)" == "yes" } {
       
        set infVals(torRegPortmapper) 1

        # setupVals(torRegAction) is the value saved in the registry
        # by regOptionRegValueRead ()

        switch $setupVals(torRegOption)  {
            torRegStartup { 
                set msg1 "into the Startup Group"
                set msg2 "the Target Server"
                set infVals(torRegStartup) 0
                set infVals(torRegStartupPortmapper) 1
            }
            torRegRemote { 
                if {[isUnix]} {
                    set msg1 "on the host $setupVals(registry)"
                } else {
                    set msg1 "on a remote server"
                }
                set msg2 "either a Tornado Registry or a Target Server"
            }
            torRegManual {
                set msg1 "manually"
                set msg2 "either a Tornado Registry or a Target Server"
            }
            default {
                # should not get here!
 
                set error 1
                set setupVals(howToMsg) \
                "You have reached this page on an error, please click\
                 <Back> to go to previous page."
            }
        }

        if {![info exists error]} {
            set setupVals(howToMsg) "You have selected to install the\
            Tornado Registry $msg1. In order to retain Tornado 1.0.x\
            backward compatibility, You must specify the\
            -use_portmapper option when starting $msg2.\
            \n\n\n[strTableGet COMPATIBILITY_MSG_2]"
            
        }

    } else {
        pageRemove howTo
    }

    return 1
}


#############################################################################
#
# pageCreate(howTo) - display users how to configure registry or target
#                     server for backward compatibility 
#
# This procedure will display users how to configure registry or target 
#                     server for backward compatibility
#
# SYNOPSIS
# .tS
# pageCreate(howTo)
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc pageCreate(howTo) {} {
    global ctrlVals
    global setupVals

    set ctrlVals(volatileFrm) [list \
            [list label -name howTo\
                        -title "$setupVals(howToMsg)" \
                        -x 100 -y 10 -w 193 -h 100] \
    ]

    set w [dlgFrmCreate [strTableGet COMPATIBILITY_TITLE]]

    # test automation

    if { $ctrlVals(useInputScript) } {
        autoSetupLog "how to page: skipped"
        nextCallback
    }

}

#############################################################################
#
# pageProcess(howTo) - process inputs from howTo page if any
#
# This procedure will process inputs from howTo page if any
#
# SYNOPSIS
# .tS
# pageProcess(howTo)
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: 1 when successful
#
# ERRORS: N/A
#

proc pageProcess(howTo) {} {
    return 1
}


######################################################################
# Dialog Text Messages
######################################################################

set strTable(COMPATIBILITY_TITLE) "Backward Compatibility"

set strTable(COMPATIBILITY_MSG_1) \
    "To use Tornado 1.0.1 tools with Tornado 2.2, it is necessary\
    to install the portmapper. The portmapper is needed only in this\
    case. Installing the portmapper when it is not needed wastes some\
    memory and CPU time."

set strTable(COMPATIBILITY_MSG_2) \
    "For more information on backward compatibility,\
     please consult the Tornado $setupVals(torVersionNum) Release Notes."

set strTable(COMPATIBILITY_MSG_3) \
    "Note:\
     \n\nIf you have selected to install the Tornado Registry as\
     a service, there is no way to retain backward compatibility\
     with Tornado 1.0.x."
