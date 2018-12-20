# EMFINISH.TCL  - Setup procedures for implementing license email finish 
#                 wizard page
#
# Copyright 1999 Wind River Systems, Inc
#
# modification history
# --------------------
# 02f,18jun02,bwd  Update registry to store LM_LICENSE_FILE value
# 02e,24apr00,j_w  Renamed WRS to Wind River
# 02d,08feb00,j_w  Rename page title
# 02c,18jan00,bwd  Deleted debug lines
# 02b,01oct99,j_w  Changed page name to licEmailFinish
# 02a,30Sep99,j_w  Modified for T3
# 01a,01Jul99,j_w  extracted from LICW32.TCL.
#

#############################################################################
#
# pageCreate(licEmailFinish) - display finish messages
#
# This procedure will display list of installed products and serve as
# the last wizard page
#
# SYNOPSIS
# .tS
# pageCreate(licEmailFinish)
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc pageCreate(licEmailFinish) {} {
    global ctrlVals
    global setupVals
    global tornadoInstalled
    global env

    exitMsgSet "Your license request has been sent to Wind River."

    set ctrlVals(volatileFrm) [list \
                       [list label -name finishText \
                                -title [exitMsgGet]\
                                -x 100 -y 10 -w 206 -h 24] ]

    set w [dlgFrmCreate "Finish"]

    controlValuesSet $w.nextButt "Finish"
    controlEnable $w.backButt 0
    controlEnable $w.nextButt 1
    controlEnable $w.cancelButt 0

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
        autoSetupLog "Get License Finish page:"
        autoSetupLog "\t[exitMsgGet]"
        nextCallback
    }

}

#############################################################################
#
# pageProcess(licEmailFinish) - process inputs from finish page if any
#
# This procedure will process inputs from finish page if any
#
# SYNOPSIS
# .tS
# pageProcess(licEmailFinish)
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: 1 when successful
#
# ERRORS: N/A
#

proc pageProcess(licEmailFinish) {} {
    global lmLicEnvVar

    set lmLicEnvVar ""
    if { [isUnix] } {
        set licPath "[destDirGet]/.wind/license/WRSLicense.lic"
        set separator "\:"
        if { [info exists env(LM_LICENSE_FILE)] } {
            # save original value if exists
            set lmLicEnvVar $env(LM_LICENSE_FILE)
        }

    } else {
        set licPath "[destDirGet]\\.wind\\license\\WRSLicense.lic"
        set separator "\;"
        if {![catch {sysRegistryValueRead HKEY_LOCAL_MACHINE \
                 "SOFTWARE\\FLEXlm License Manager"\
                 "LM_LICENSE_FILE"} result]} {
            # value exists, append to it and write it back out
            set lmLicEnvVar $result
        }
    }

    if { $lmLicEnvVar == "" } {
        set lmLicEnvVar $licPath
    } else {
        set lmLicEnvVar "$lmLicEnvVar$separator$licPath"
        set tmp [split $lmLicEnvVar $separator]
        set lmLicEnvVar [lunique $tmp]
        set lmLicEnvVar [join $lmLicEnvVar $separator]
    }

    if {[isUnix]} {
        # update torVars.sh and torVars.csh
        # procedure in FINISH.TCL
        updateTorVarsFiles
    } else {
   
        # check to see if the value exists: 
        # If not, create it. Otherwise, write to it.

        if { ![catch {sysRegistryValueRead HKEY_LOCAL_MACHINE \
                              "SOFTWARE\\FLEXlm License Manager"\
                              "LM_LICENSE_FILE"} result] } {
            # value exists, write to registry

            regValueWriteLog HKEY_LOCAL_MACHINE \
                    "SOFTWARE\\FLEXlm License Manager" "LM_LICENSE_FILE" $lmLicEnvVar false
            uninstLog setuplog "Wrote \"$lmLicEnvVar\" to \
                    HKEY_LOCAL_MACHINE\\SOFTWARE\\FLEXlm License Manager\\LM_LICENSE_FILE."

        } else {

            # the value doesn't exist, create and set value

            regKeyCreateLog HKEY_LOCAL_MACHINE "SOFTWARE" "FLEXlm License Manager" false

            regValueWriteLog HKEY_LOCAL_MACHINE \
                    "SOFTWARE\\FLEXlm License Manager" "LM_LICENSE_FILE" $lmLicEnvVar false

            uninstLog setuplog "Created and wrote \"$lmLicEnvVar\" to \
                    HKEY_LOCAL_MACHINE\\SOFTWARE\\FLEXlm License Manager\\LM_LICENSE_FILE."
        }
                                
        # flush the regKeyCreateLog and regValueWriteLog commands
        queueExecute
    }
    return 1
}
