# LICPHONE.TCL - Displays License file and WRS Contact information
#
# Copyright 1998 Wind River Systems, Inc.
#
# modification history
# --------------------
# 02b,18jun02,bwd  Update registry to store LM_LICENSE_FILE value
# 02a,12jun01,j_w  Added for Tornado 2.2
# 01o,02may01,j_w  Removed alternative host Id 
# 01n,09jan01,bwd  SPR 63370: added line for alternative host id (ethernet
#                  card serial #)
# 01m,01jun00,bwd  Modified text to indicate the type of license
#                  (floating/nodelocked). Modified codes to write text in
#                  different files for floating and nodelocked.
# 01l,30may00,bwd  Removed licManual page if reload when user click Back.
#                  Modified message for reload
# 01k,12may00,bwd  SPR 31204 - increase text slot on dialog to display URL for
#                  contact info.
# 01j,14feb00,wmd  Change all references to prodCode to featureId.
# 01i,02feb00,bwd  Changed codes to use isGUImode
# 01h,18jan00,bwd  Added codes to display this page for TEXT MODE
# 01g,06jan00,bwd  Deleted debug lines
# 01f,06jan00,bwd  Modified the summary of licensed product feature to include
#                  the no. of licenses requested by users
# 01e,28dec99,bwd  Changed "Licensed Product Feature(s)" to display actual
#                  product name(s) and code(s) of the licensed product(s)
# 01d,15dec99,bwd  Added codes to write out file lmPhoneInfo.txt to hold LM
#                  information
# 01c,04oct99,j_w  Fixed back button
# 01b,30Sep99,j_w  remove steps to get hostId
# 01a,16Jul99,j_w  written


global outFileName
set outFileName ""

#############################################################################
#
# pageCreate(licPhone) - Create a page to display license request and 
#                        WRS contact information
#
# This procedure creates and displays license request and WRS contact information
#
# SYNOPSIS
# .tS
# pageCreate(licPhone)
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc pageCreate(licPhone) {} {
    global setupVals ctrlVals lmVals
    global env outFileName

    set setupVals(WRSlicense) [setupLicenseNumGet]

    if { $lmVals(reload) } {
        pageRemove licManual
    }

    if { $setupVals(lmInstType) == "nodeLocked" } {
        set outFileName "lmPhoneNL.txt"
    } else {
        set outFileName "lmPhoneFT.txt"
    }

    if {[isUnix]} {
        set outFileName "[destDirGet]/$outFileName"
    } else {
        set outFileName "[destDirGet]\\$outFileName"
    }

    if { [isGUImode] } {

        set ctrlVals(volatileFrm) [list \
                [list label -name msg \
                            -title [strTableGet 1350_LICENSE_CALL] \
                            -x 100 -y 10 -w 205 -h 35] \
                [list label -name lmPhoneText \
                            -title "[strTableGet LMPHONE_MSG] $outFileName\
                                    for your convenience." \
                            -x 100 -y 45 -w 200 -h 20] \
                [list text  -name callInfo \
                            -multiline -hscroll -vscroll \
                            -readonly \
                            -x 100 -y 65 -w 205 -h 105] ]
    }

    set callMsg "[strTableGet 1340_LICENSE_MAIL_HEADER_LINE7 \
                              $setupVals(hostName)]\
             \r\n[strTableGet 1340_LICENSE_MAIL_HEADER_LINE8 \
                              $setupVals(hostId)]\
             \r\n[strTableGet 1340_LICENSE_MAIL_HEADER_LINE6 \
                              $setupVals(WRSlicense)]"

    set fileMsg "[strTableGet 1340_LICENSE_MAIL_HEADER_LINE7 \
                              $setupVals(hostName)]\
               \n[strTableGet 1340_LICENSE_MAIL_HEADER_LINE8 \
                              $setupVals(hostId)]\
               \n[strTableGet 1340_LICENSE_MAIL_HEADER_LINE6 \
                              $setupVals(WRSlicense)]"

    if { $setupVals(lmInstType) == "nodeLocked" } {
        append callMsg "\r\n\r\nNode Locked License Request:"
        append fileMsg "\n\nNode Locked License Request:"
    } else {
        append callMsg "\r\n\r\nFloating License Request:"
        append fileMsg "\n\nFloating License Request:"
    }

    if { $lmVals(reload) } {
        append callMsg "\r\n[strTableGet 1340_LICENSE_MAIL_HEADER_LINE10a]"
        append fileMsg "\n[strTableGet 1340_LICENSE_MAIL_HEADER_LINE10a]"

    } else {
        append callMsg "\r\n[strTableGet 1340_LICENSE_MAIL_HEADER_LINE10b]\
                        \r\n\r\n[strTableGet 1340_LICENSE_MAIL_HEADER_LINE11]\r\n"

        append fileMsg "\n[strTableGet 1340_LICENSE_MAIL_HEADER_LINE10b]\
                        \n\n[strTableGet 1340_LICENSE_MAIL_HEADER_LINE11]\n"

        for {set ix 0} {$ix < [llength $lmVals(lmLicensedProductNames)]} {incr ix} {
            set feature [lindex $lmVals(lmLicensedProductNames) $ix]
            set featureId [lindex $lmVals(lmLicensedFeatureIds) $ix]
            set licCount [lindex $lmVals(lmFeaturesRequested) $ix]

            append callMsg "\r\nProduct Name: $feature\r\nFeature ID: $featureId\
                            \r\nNo. of licenses requested: $licCount\r\n"
            append fileMsg "\nProduct Name: $feature\nFeature ID: $featureId\
                            \nNo. of licenses requested: $licCount\n"
        }
    }

    set setupVals(callMsg) $callMsg
    set setupVals(fileMsg) $fileMsg

    if { [isGUImode] } {   
        set w [dlgFrmCreate [strTableGet 1540_TITLE_LICENSE_CALL]]    
        controlValuesSet $w.callInfo $callMsg
    
        controlValuesSet $w.nextButt "Finish"
        controlEnable $w.nextButt 1
        controlEnable $w.backButt 1
        controlEnable $w.cancelButt 0
    } else { # TEXT MODE
        printPageTitle [strTableGet 1540_TITLE_LICENSE_CALL]
        puts [strTableGet 1350_LICENSE_CALL]
        puts "[strTableGet LMPHONE_MSG] $outFileName for your convenience.\n\n"
        puts "$setupVals(fileMsg)\n\n"

        puts "Press \<Return\> to finish SETUP"
        while (1) {
            switch -regexp --  [prompt] {
                "^-$" {  backCallback ; return 0  }
                "^$"  {  nextCallback ; return 0  }
                "^[eE][xX][iI][tT]$" {  return 0  }
                default { }
            }
        }
    }
}

#############################################################################
#
# pageProcess(licPhone) - write all information to a text file
#
# This procedure will write contact information and License file information
# to a text file
#
# SYNOPSIS
# .tS
# pageProcess(licPhone)
# .tE
#
# PARAMETERS: N/A
#
# RETURNS:  1 if successful
#
# ERRORS: N/A
#

proc pageProcess(licPhone) {} {
    global setupVals outFileName lmLicEnvVar

    if { [isGUImode] } {
        if {[catch {open $outFileName w} fd]} {
            messageBox "Error opening output filename: $outFileName"
            return
        } else {
            puts $fd [string trimleft $setupVals(fileMsg)]
            if {[catch {close $fd} err]} {
                messageBox "Error closing file $outFileName"
            }
         }

    } else { # text mode
        if {[catch {open $outFileName w} fd]} {
            puts "Error opening output filename: $outFileName"
            while { [prompt "Press <Enter> to Continue"] != "" } {
            }
            return
        } else {
            puts $fd [string trimleft $setupVals(fileMsg)]
            if {[catch {close $fd} err]} {
                puts "Error closing file $outFileName"
                while { [prompt "Press <Enter> to Continue"] != "" } {
                }
            }
        }
    }

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

######################################################################
# Dialog Text Messages
######################################################################

set strTable(LMPHONE_MSG) \
        "This information will be written to"
