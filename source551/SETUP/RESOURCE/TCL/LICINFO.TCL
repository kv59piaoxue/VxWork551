# LICINFO.TCL - Setup procedures for implementing Current License Info 
#               wizard page
#
# Copyright 1999-2003 Wind River Systems, Inc
#
# modification history
# --------------------
# 02d,14feb03,bjl  fixed grammar for licinfo message.
# 02c,23may02,bwd  SPR 77766: grey out HELP button - not needed for this page
# 02b,23apr02,wmd  Add new KEYWORDS, spr 76185.
# 02a,12jun01,j_w  Added for Tornado 2.2
# 01q,21sep00,bwd  Removed update and reload choice button. The choice to
#                  update/reload is made in previous page
# 01p,07jul00,j_w  Default to the "retrieve backup lic file" option if
#                  lmVals(reloadExistingLicense) is 1
# 01o,31may00,bwd  SPR 31564: enable Back button for node locked licensing
# 01n,26may00,bwd  Reset pageList for email/phone when choosing onUpdate
# 01m,18may00,bwd  Removed debug message
# 01l,20mar00,bwd  Fixed TEXT mode to default a choice to onUpdate
# 01k,10feb00,j_w  Fixed typo
# 01j,08feb00,j_w  Rename page title
# 01i,02feb00,bwd  Changed setupVals(cmdMode) to use isGUImode
# 01h,12jan00,bwd  Added codes to display this page for TEXT MODE
# 01g,30nov99,j_w  Updated messages for reloading and fixed license file 
#                  parsing for the server line
# 01f,24nov99,bwd  Added default value for auto setup
# 01e,23nov99,bwd  Added sections for automatic LM Installation
# 01d,17nov99,j_w  Set lmVals(reload) to 1 if onReload is selected
# 01c,16nov99,j_w  Added procedure for parsing the license file
# 01b,10nov99,j_w  Disabled back button so user will not install flexlm files
#                  again
# 01a,16Sep99,j_w   written
#

#############################################################################
#
# pageCreate(currLicInfo) - displays existing license info on current host
#
# This procedure will display existing license info including licensed 
# product names, number of floating and nodelocked licenses for each product
#
# SYNOPSIS
# .tS
# pageCreate(currLicInfo)
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#


proc pageCreate(currLicInfo) {} {
    global ctrlVals lmVals setupVals

    set lmType ""
    if { [info exists setupVals(lmInstType)] &&
         $setupVals(lmInstType) == "nodeLocked" } {
        set lmType "nodeLocked"
    }

    set msg ""
    if {$lmVals(reloadExistingLicense) == 1} {
        set msg [strTableGet LICINFO_MSG_RELOAD]
        set lmVals(reload) 1
        set setupVals(licUpdateAction) "onReload"
    } else {
        set msg [strTableGet LICINFO_MSG_UPDATE]
        set lmVals(reload) 0
        set setupVals(licUpdateAction) "onUpdate"
    }

    if { [isGUImode] } {
        set ctrlVals(volatileFrm) [list \
                [list label -name msg1 \
                            -title [strTableGet LICINFO_MSG_1] \
                            -x 99 -y 10 -w 200 -h 20] \
                [list text -name licenseInfo \
                           -multiline -vscroll -readonly \
                           -x 99 -y 30 -w 200 -h 103] \
                [list label -name msg2 \
                            -title "$msg\n\n[strTableGet LICINFO_MSG_2]"\
                            -x 99 -y 138 -w 200 -h 35] ]

        set w [dlgFrmCreate [strTableGet LICINFO_TITLE]]

        # help not provided and not needed for this page
        controlEnable $w.helpButt 0

        if { $lmType == "nodeLocked" } {
            # OK to enable back button for node locked
            controlEnable $w.backButt 1
        } else {
            # disable back button so user will not install flexlm files twice
            controlEnable $w.backButt 0
        }

        if { $ctrlVals(useInputScript) } { # test automation
            if { ![info exists setupVals(licUpdateAction)] } {
                set setupVals(licUpdateAction) "onUpdate"
                autoSetupLog "License Update Action: unspecified.\
                              Use default action: update."
            }
        }

        # parse the license Info here
        set licStr [licInfoParse "$lmVals(lmLicenseFile)"]

        # display the info
        controlValuesSet $w.licenseInfo "$licStr"    

        if {$ctrlVals(useInputScript)} {
            autoSetupLog "Current License Information Page: skipped"
            autoSetupLog "\tAction taken: $setupVals(licUpdateAction)"
            nextCallback
        }

        controlFocusSet $w.nextButt

    } else { #TEXT mode
        printPageTitle [strTableGet LICINFO_TITLE]
        puts "[strTableGet LICINFO_MSG_1]\n"

        # parse the license Info here
        set licStr [licInfoParse "$lmVals(lmLicenseFile)"]

        puts $licStr
        puts "\n\n$msg\n"
        puts "Press \"Enter\" after finish viewing your existing license file."
        while (1) {
            switch -regexp -- [prompt] {
                "^$"  {  nextCallback ; return 0  }
                "^-$" {
                    if { $lmType == "nodeLocked" } {
                        # OK to go back for node locked
                        backCallback
                        return 0
                    } else {
                        puts "Error: Cannot go back any further"
                        while { [prompt "Press <Enter> to continue."] != "" } {
                        }
                        return [pageCreate(currLicInfo)]
                    }
                }
                "^[eE][xX][iI][tT]$" {
                     return 0
                }
            }
        }
    }
}

#############################################################################
#
# pageProcess(currLicInfo) - process inputs from currLicInfo page if any
#
# This procedure will process inputs from currLicInfo page if any
#
# SYNOPSIS
# .tS
# pageProcess(currLicInfo)
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: 1 when successful
#
# ERRORS: N/A
#

proc pageProcess(currLicInfo) {} {
    global setupVals lmVals

    # reset any prev choice
    set setupVals(lmInstOptions) ""

    switch $setupVals(licUpdateAction) {
        onUpdate {
            set lmVals(reload) 0

            # reset page list
            set setupPageList(email) {licManual licEmail licEmailFinish}
            set setupPageList(phone) {licManual licPhone}
        }
        onReload {
            set lmVals(reload) 1
        }
    }

    # re-enable help button for next pages
    controlEnable wizardDialog.helpButt 1

    dbgputs "licUpdateAction: $setupVals(licUpdateAction)"
    dbgputs "lmVals(reload): $lmVals(reload)"
    return 1
}


#############################################################################
#
# licInfoParse - Obtain the license file information
#
# SYNOPSIS
# .tS
# licInfoParse
# .tE
#
# PARAMETERS: license file
#
# RETURNS: license information in a formatted string
#
# ERRORS: N/A
#

proc licInfoParse {licFile} {
    set str ""

    if { [catch {open $licFile r} fileId] } { 
        puts "Can't open license file"
        return "Cannot open license file:\r\n$licFile"
    } else {
        # parse SERVER line
        while { [gets $fileId line] >= 0 } {
            set line [string trim $line]
            if {[regexp {^SERVER.*} $line] } {
                set x [split $line]
                set server [lindex $x 1]
                set hostId [lindex $x 2]
                append str "Server:  $server\r\n"
                append str "Host ID: $hostId\r\n"
            }
        }
        append str "\r\n"

        # go to the beginning of the file
        seek $fileId 0
		
        # parse FEATURE or INCREMENT line
        while { [gets $fileId line] >= 0 } {
            set line [string trim $line]
            if {[regexp {^FEATURE.*} $line] } {
                set x [split $line]
                set feature [lindex $x 1]
                set vendor [lindex $x 2]
                set ver [lindex $x 3]
                set exp [lindex $x 4]
                set seat [lindex $x 5]
                if { "$vendor" == "wrsd" } {
                    append str "Licensed Feature:\t   $feature $ver\r\n"
                    append str "Number of Licenses:   $seat\r\n"
                    append str "Expiration Date:\t   $exp\r\n"
                }
               append str "\r\n"
            }
            if {[regexp {^INCREMENT.*} $line] } {
                set x [split $line]
                set feature [lindex $x 1]
                set vendor [lindex $x 2]
                set ver [lindex $x 3]
                set exp [lindex $x 4]
                set seat [lindex $x 5]
                if { "$vendor" == "wrsd" } {
                    append str "Licensed Feature:\t   $feature $ver\r\n"
                    append str "Number of Licenses:   $seat\r\n"
                    append str "Expiration Date:\t   $exp\r\n"
                }
              append str "\r\n"
            }
        }
        close $fileId
    }
    return $str
}


######################################################################
# Dialog Text Messages
######################################################################

set strTable(LICINFO_TITLE) "License Information"

set strTable(LICINFO_MSG_1) \
        "SETUP has detected that the following licenses are configured\
        on this host:"

set strTable(LICINFO_MSG_2) \
        "Please click \"Next\" to proceed..."

set strTable(LICINFO_MSG_UPDATE) \
        "You have requested to update the license configuration \
         with additional seats for licensed products on this host."

set strTable(LICINFO_MSG_RELOAD) \
        "You have requested to overwrite an invalid license file\
         or replace a missing\/deleted license file."

