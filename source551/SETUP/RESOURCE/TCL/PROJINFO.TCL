# PROJINFO.TCL - Setup procedures for implementing project-information 
#                wizard page
#
# Copyright 1999 Wind River Systems, Inc
#
# modification history
# --------------------
# 03c,17may02,wmd  Fix text formatting, grammatical problems.
# 03b,05mar02,bwd  Modified SETUP to be non-tornado centric
# 03a,12jun01,j_w  Modified for Tornado 2.2
# 02l,15dec00,wmd  Fix puntuation and typos.
# 02k,31jul00,bwd  Modified codes in projInfoGet to be more concise
# 02j,31jan00,bwd  Fixed error handling for test automation. Deleted redundant
#                  codes. Replaced setupVals(cmdMode) with isGUImode
# 02i,13jan00,bwd  Fixed typo: "nextCallback" to "backCallback" in TEXT MODE
# 02h,06jan00,bwd  No test automation for command line SETUP
# 02g,17dec99,clc  change  switch statement patterns
# 02f,16dec99,clc  edit default text mode values
# 02e,09nov99,clc  modify text mode
# 02d,07nov99,clc  edit text mode return to previous page
# 02c,07nov99,clc  edit text mode exit
# 02b,01nov99,bwd  Added sections for automatic setup
# 02b,21oct99,clc  add text mode
# 02a,30Sep99,j_w  Modified for T3
# 01d,22jul99,j_w  added text messages
# 01c,24mar99,bjl  turn off inf write to registry after queueExecute.
# 01b,08feb99,wmd  Need to validate that the number of licenses field is
#                  numeric.
# 01a,26jan99,tcy  extracted from INSTW32.TCL.
#

#############################################################################
#
# pageCreate(projectInfo) - prompts users for project information
#
# This procedure will prompt user for project information such as project name
# and number of Tornado seats
#
# SYNOPSIS
# .tS
# pageCreate(projectInfo)
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc pageCreate(projectInfo) {} {
    global ctrlVals
    global setupVals
    global projLic
    global projName
    global projLicUsers
    global projInfoTempVar

    if { [isGUImode] } {
        set ctrlVals(volatileFrm) [list \
                [list label -name message1 \
                            -title [strTableGet PROJECTINFO_MSG_1] \
                            -x 99 -y 10 -w 206 -h 35] \
                [list label -name message2 \
                            -title [strTableGet PROJECTINFO_MSG_2] \
                            -x 99 -y 56 -w 75 -h 10] \
                [list label -name message3 \
                            -title [strTableGet PROJECTINFO_MSG_3] \
                            -x 99 -y 80 -w 75 -h 10] \
                [list label -name message4 \
                            -title [strTableGet PROJECTINFO_MSG_4] \
                            -x 99 -y 104 -w 99 -h 8] \
                [list text -name WRSLicText -border -x 187 -y 56 -w 120 \
                            -h 13 -readonly ] \
                [list text -name projNameText -border -x 187 -y 79 -w 120 \
                           -h 13 -callback \
                           {onTextChange projNameText projName}] \
                [list text -name numUsersText -border -x 187 -y 102 -w 120 \
                           -h 13 -callback \
                           {onTextChange numUsersText numUsers}] \
        ]

        set w [dlgFrmCreate [strTableGet PROJECTINFO_TITLE]]

        # initialize values in controls if they exist in the registry
 
        controlValuesSet $w.WRSLicText [projInfoGet WRSLic]

        #if automatic setup, use values from SETUP_ANS_FILE file
        #if not, use values from projInfoGet

        if {$ctrlVals(useInputScript)} {
            controlValuesSet $w.projNameText $setupVals(projName)
            controlValuesSet $w.numUsersText $setupVals(projLicUsers)
        } else {
            controlValuesSet $w.projNameText [projInfoGet projName]
            controlValuesSet $w.numUsersText [projInfoGet numUsers]
        }
        controlFocusSet $w.nextButt

        if {$projLic != "" && $projName != "" && $projLicUsers != "" } {
            controlValuesSet $w.WRSLicText $projLic
            controlValuesSet $w.projNameText $projName
            controlValuesSet $w.numUsersText $projLicUsers
        }

        # test automation

        if {$ctrlVals(useInputScript)} {
            autoSetupLog "Project Information page:"
            autoSetupLog "\tWRS License  : [projInfoGet WRSLic]"
            autoSetupLog "\tProject Name : $setupVals(projName)"
            autoSetupLog "\t[getProdInfo name] seats: $setupVals(projLicUsers)"
            nextCallback
        }

    } else { # TEXT mode

        printPageTitle [strTableGet PROJECTINFO_TITLE]
        puts "[strTableGet PROJECTINFO_MSG_1_TEXT]\n"
        puts "[strTableGet PROJECTINFO_MSG_2]: [projInfoGet WRSLic]\n"

        # this temporary variable is used to return to the regist. page
        set projInfoTempVar 0

        if { ![info exists setupVals(projName)] || 
             ![info exists setupVals(numUsers)] } {
            set setupVals(projName) [projInfoGet projName]
            set setupVals(numUsers) [projInfoGet numUsers]
        }
        set question "projName"
        while {[string compare $question "done"] != 0} {
            switch $question {
                "projName" { 
                    # get project name

                    set msg "Enter the [strTableGet PROJECTINFO_MSG_3]: \
                             \[$setupVals(projName)\]"
                    set ret [prompt "$msg"]

                    switch -regexp -- $ret {
                        "^-$" { 
                            set projInfoTempVar 1
                            backCallback
                            return 0
                        }
                        "^$" { 
                            if { $setupVals(projName) != "" } {
                                 set question "seats"
                            }
                        } 
                        "[eE][xX][iI][tT]"  { return 0 }
                        default { 
                            set setupVals(projName) $ret
                            set question "seats" }
                        }
                    }
                "seats"   { 
                    # get registration key
                    set msg "Enter the [strTableGet PROJECTINFO_MSG_4]: \
                                \[$setupVals(numUsers)\]"
                    set ret [prompt "$msg"]
                    switch -regexp -- $ret {
                        "^-$" { set question "projName" }
                        "^$" { 
                            if { $setupVals(numUsers) != "" } {
                                set question done
                            } 
                        }
                        "[eE][xX][iI][tT]"  { return 0 }
                        default { 
                            if {[regexp {[^0-9]+} $ret var]} {
                                puts [strTableGet PROJECTINFO_MSG_6]
                            } else {
                            set setupVals(numUsers) $ret
                            set question "done" 
                            }
                        }
                    }    
                }
            }
        }
        nextCallback
        return 0
   }        
}

#############################################################################
#
# pageProcess(projectInfo) - process inputs from projectInfo page
#
# This procedure will process inputs from projectInfo page
#
# SYNOPSIS
# .tS
# pageProcess(projectInfo)
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: 0 if procedure onProjLicRecordOK returns 0
#          1 if procedure onProjLicRecordOK returns 1
#
# ERRORS: N/A
#

proc pageProcess(projectInfo) {} {
    global infVals
    global setupVals
    global projInfoTempVar 1
    
    set retVal 1

    if { ![isGUImode] } { # TEXT MODE
        if { $projInfoTempVar == 1 } {
             # go back to registration page
             return [calcPage registration]
        }
    }

    set infVals(addProjectInfo) 1
    set retVal [onProjLicRecordOK]
    set prod [string toupper [getProdInfo name]]
    searchAndProcessSection AddRegistry [cdFileNameGet [file join RESOURCE \
                                         INF $prod.INF]]
    queueExecute
    set infVals(addProjectInfo) 0

    return $retVal
}

#############################################################################
#
# projInfoGet - initialize licenseAgreement page
#
# This procedure will initialize licenseAgreement page
#
# SYNOPSIS
# .tS
# projInfoGet <info>
# .tE
#
# PARAMETERS:
# .IP <info> information needed for project. It can be one of the following:
#  WRSLic   - WRS license number assigned to vendor
#  projName - project name
#  numUsers - numbers of registered users
#
# RETURNS: registry value of requested info
#
# ERRORS: N/A
#

proc projInfoGet {info} {
    global setupVals

    if {$info == "WRSLic"} {
        if {![catch {setupLicenseNumGet} lic]} {
            return $lic
        }
    }

    set root ""
    set sp "SOFTWARE\\$setupVals(WRS)"

    if {![catch {sysRegistryValueRead HKEY_LOCAL_MACHINE $sp "WRSLicense"} value]} {
        set root "HKEY_LOCAL_MACHINE"
    } elseif {![catch {sysRegistryValueRead HKEY_CURRENT_USER $sp "WRSLicense"} value]} {
        set root "HKEY_CURRENT_USER"
    } else {
        dbgputs "ERROR registry reading: $value"
        return ""
    }

    if {$root != ""} {
        switch -exact -- $info {
            WRSLic {
                if {![catch {sysRegistryValueRead \
                           $root $sp "WRSLicense"} value]} {
                    return $value
                } else { return ""}
            }
            projName {
                if {![catch {sysRegistryValueRead \
                           $root $sp "projectName"} value]} {
                    return $value
                } else { return ""}
            }
            numUsers {
                if {![catch {sysRegistryValueRead \
                           $root $sp "nLicensedUsers"} value]} {
                    return $value
                } else { return ""}
            }
        }
    }
}

#############################################################################
#
# onProjLicRecordOK - process inputs from projectInfo page
#
# This procedure is a helper which processes inputs ffrom projectInfo page
#
# SYNOPSIS
# .tS
# onProjLicRecordOK
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: 0 if project information is not completely filled
#          1 if project information is completely filled
#
# ERRORS: N/A
#

proc onProjLicRecordOK {} {
    global setupVals
    global projLic
    global projName
    global projLicUsers
    global ctrlVals

    # query the user with the info he has entered

    if [catch {setupLicenseNumGet} error] {
        puts "Error: $error"
    } else {
        set projLic $error
    }

    set projName $setupVals(projName)
    set projLicUsers [string trim $setupVals(numUsers)]

    if { [isGUImode] } {
        if {$projLic == "" || $projName == "" || $projLicUsers == "" } {
            if { $ctrlVals(useInputScript) } {
                autoSetupLog "[strTableGet PROJECTINFO_MSG_5]"
                autoSetupLog "Application Exit\n"
                set setupVals(cancel) 1                
                applicationExit
            } else {
                messageBox -ok -exclamationicon \
                    [strTableGet PROJECTINFO_MSG_5]
            }
            return 0
        }

        if { [regexp {[^0-9]+} $projLicUsers var]} {
            if { $ctrlVals(useInputScript) } {
                autoSetupLog "Error: invalid input for \"Number of [getProdInfo name] Seats\""
                autoSetupLog "Application Exit\n"
                set setupVals(cancel) 1                
                applicationExit
            } else {
                messageBox -ok -exclamationicon \
                    [strTableGet PROJECTINFO_MSG_6]
            }
            return 0
        }
    }

    # record the license record in the registry under "WIND RIVER SYSTEMS",
    # done in <$productName>.INF

    return 1

}

######################################################################
# Dialog Text Messages
######################################################################

set strTable(PROJECTINFO_TITLE) "Project Information"

set strTable(PROJECTINFO_MSG_1) \
    "Please enter your project name and the number of licensed\
    users on the project in the spaces below.  The information\
    can be found on the [getProdInfo name] Installation Keys form\
    shipped with this product."

set strTable(PROJECTINFO_MSG_1_TEXT) \
    "Please enter your project name and the number of licensed\
    users on the project.  The information can be found on the\
    [getProdInfo name] Installation Keys form shipped with this product."

set strTable(PROJECTINFO_MSG_2) "WRS License Number"

set strTable(PROJECTINFO_MSG_3) "Project Name"

set strTable(PROJECTINFO_MSG_4) "Number of [getProdInfo name] Seats"

set strTable(PROJECTINFO_MSG_5) \
        "You have not completely entered your\
        project information."

set strTable(PROJECTINFO_MSG_6) \
        "The value you entered for the \"Number of [getProdInfo name] Seats\"\
        field is non-numeric, please re-enter it."

