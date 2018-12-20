# LMINST.TCL - Setup procedures for implementing LM installation-choice 
#              wizard page
#
# Copyright 1999-2003 Wind River Systems, Inc
#
# modification history
# --------------------
# 02d,29apr03,bjl  do not reset values for manual if successful db query
#                  for elm user (spr 88068).  
# 02c,14feb03,bjl  added controls for manual page sequence, differentiate
#                  between license server and manual/nodelocked sequences.  
# 02b,25apr02,j_w  fixed a typo 
# 02a,12jun01,j_w  Modified for Tornado 2.2
# 02c,08jan01,bwd  SPR 63370: added additional header for alternative host id.
# 02b,01nov00,j_w  Fixed page list for autoInst in proc onNoOutsideAccess
# 02a,12sep00,j_w  fixed URL for web form
# 01z,26may00,bwd  Enable Back button if the previous page is currLicInfo
# 01y,23may00,bwd  Fixed message
# 01x,19may00,bwd  SPR 31032 - do not skip lmInstOption page on reload to fix
#                  errors
# 01w,18may00,bwd  SPR 31030 - design change: lmInstOptions page before
#                  DBQUERY and added a check to add nodelock page list
# 01v,15may00,bwd  SPR 31030 - enable Back button to go back to DBQUERY page
#                  for Node Locked licensing
# 01u,12may00,bwd  SPR 31204 - added URL for contact information and fax
#                  number for LICPHONE page
# 01t,25apr00,j_w  Replaced the value of strTable(1220_MAIL_TO) to
#                  license@windriver.com
# 01s,20mar00,bwd  Fixed TEXT mode to prevent going back to previous page
# 01r,20mar00,bwd  Fixed TEXT mode to default a choice to Automatic License
#                  Installation
# 01q,17mar00,j_w  Renamed WRS to Wind River
# 01p,09feb00,j_w  Called onPhone if no outside network access is selected
# 01o,24jan00,bwd  Fixed codes for "RELOAD" option to skip this page properly
# 01n,21jan00,bwd  Removed code that resets lmVals(reload) to 0 for TEXT MODE
# 01m,20jan00,j_w  Remove the line that reset lmVals(reload) to 0
# 01l,14jan00,bwd  Added codes to display this page for TEXT MODE
# 01k,11jan00,j_w  Fixed radio button selection
# 01j,10dec99,j_w  Unset lmVals(reload) to 0
# 01i,30nov99,j_w  Added a check box for no outside access
# 01h,23nov99,j_w  Fixed typo
# 01g,17nov99,j_w  Skip the page if lmVals(reload) is set to 1
# 01f,15nov99,j_w  Fixed indent spacing
# 01e,15nov99,wmd  Add line to unhide the setup bitmap incase it is hidden on
#                  subsequent pages.
# 01d,12nov99,bwd  Added sections for automatic setup installation
# 01c,05nov99,wmd  Add code to make sure back and next buttons are enabled.
# 01b,04oct99,j_w  Fix radio buttons
# 01a,15Sep99,j_w  written
#

#############################################################################
#
# pageCreate(lmInstOptions) - displays choices of LM installation
#
# This procedure will display choices of LM installation such as:
# Auto Install  - license file auto installation
# Email - email wrs for license file
# phone or fax - contact wrs for license file by phone or fax
#
# SYNOPSIS
# .tS
# pageCreate(lmInstOptions)
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#


proc pageCreate(lmInstOptions) {} {
    global ctrlVals env setupVals lmVals

    if { [isGUImode] } {
        # unhide the setup bitmap
        controlHide $ctrlVals(mainWindow).bitmap 0

        if {[instTypeGet] == "license"} {
            set ctrlVals(volatileFrm) [list \
                [list label -name message1 \
                            -title [strTableGet LM_INSTALLOPTIONS_MSG_1] \
                            -x 99 -y 10 -w 190 -h 20] \
                [list choice -name autoInstChoice -newgroup -auto \
                          -title [strTableGet LM_INSTALLOPTIONS_AUTO_INSTALL] \
                          -x 99 -y 35 -w 190 -h 15 \
                          -callback onAutoInst] \
                [list label -name autoInstLabel \
                            -title \
                             [strTableGet LM_INSTALLOPTIONS_AUTO_INSTALL_DESC] \
                            -x 111 -y 50 -w 198 -h 15] \
                [list choice -name emailChoice -auto \
                             -title [strTableGet LM_INSTALLOPTIONS_EMAIL] \
                             -x 99 -y 65 -w 100 -h 15 \
                             -callback onEmail] \
                [list label -name emailLabel \
                            -title \
                             [strTableGet LM_INSTALLOPTIONS_EMAIL_DESC] \
                            -x 111 -y 80 -w 198 -h 15 ] \
                [list choice -name phoneChoice -auto \
                            -title [strTableGet LM_INSTALLOPTIONS_PHONE] \
                            -x 99 -y 95 -w 190 -h 15 \
                            -callback onPhone] \
                [list label -name phoneLabel \
                            -title \
                             [strTableGet LM_INSTALLOPTIONS_PHONE_DESC] \
                            -x 111 -y 110 -w 198 -h 15] \
                [list boolean -name noOutsideAccessCkbox -newgroup -auto \
                              -title [strTableGet LM_CKBOX_1] \
                              -x 99 -y 140 -w 170 -h 15 \
                              -callback onNoOutsideAccess]]
        } else {
            # controls for manual node-locked page
            
            set ctrlVals(volatileFrm) [list \
                [list choice -name emailChoice -auto \
                             -title [strTableGet LM_INSTALLOPTIONS_EMAIL] \
                             -x 99 -y 29 -w 100 -h 15 \
                             -callback onEmail] \
                [list label -name emailLabel \
                            -title \
                             [strTableGet LM_INSTALLOPTIONS_EMAIL_DESC] \
                            -x 111 -y 44 -w 198 -h 15 ] \
                [list choice -name phoneChoice -auto \
                            -title [strTableGet LM_INSTALLOPTIONS_PHONE] \
                            -x 99 -y 67 -w 190 -h 15 \
                            -callback onPhone] \
                [list label -name phoneLabel \
                            -title \
                             [strTableGet LM_INSTALLOPTIONS_PHONE_DESC] \
                            -x 111 -y 82 -w 198 -h 15] ]
        }
        set w [dlgFrmCreate [strTableGet LM_INSTALLOPTIONS_TITLE]]

        # rename the next button to "Send" (in case of UNIX)
        controlValuesSet $w.nextButt "&Next >"

        # set default setting
        controlEnable $w.nextButt 1
        controlEnable $w.cancelButt 1

        if { $setupVals(lmInstType) == "nodeLocked" } {
            controlEnable $w.backButt 1
        } else { 
            set currPageIndex [lsearch $ctrlVals(pageList) $ctrlVals(currPage)]
            set prevPageIndex [expr $currPageIndex - 1]
            set prevPage [lindex $ctrlVals(pageList) $prevPageIndex]

            if { $prevPage == "currLicInfo" } {
                controlEnable $w.backButt 1
            } else {
                controlEnable $w.backButt 0
            }
        }

        if { $setupVals(lmInstOptions) == "" } {
            if {[instTypeGet] == "license" } {    
                controlCheckSet $w.autoInstChoice 1
            } else {
                # manual, node-locked 

                controlCheckSet $w.emailChoice 1
            }        
        } else {
            switch $setupVals(lmInstOptions) {
                onAutoInst { controlCheckSet $w.autoInstChoice 1 }
                onEmail    { controlCheckSet $w.emailChoice 1 }
                onPhone    { controlCheckSet $w.phoneChoice 1 }
                default    { controlCheckSet $w.autoInstChoice 1 }
            }
        }

        # test automation
	
        if { $ctrlVals(useInputScript) } {
            autoSetupLog "LM Installation Option Page: skipped"
            autoSetupLog "\tInstallation Option: $setupVals(lmInstOptions)" 
            nextCallback
        }
    } else { # TEXT mode

        printPageTitle [strTableGet LM_INSTALLOPTIONS_TITLE]
        puts "[strTableGet LM_INSTALLOPTIONS_MSG_1_TEXT]\n"

        puts "1 - [strTableGet LM_INSTALLOPTIONS_AUTO_INSTALL]"
        puts "    [strTableGet LM_INSTALLOPTIONS_AUTO_INSTALL_DESC]"
        puts "2 - [strTableGet LM_INSTALLOPTIONS_EMAIL]"
        puts "    [strTableGet LM_INSTALLOPTIONS_EMAIL_DESC]"
        puts "3 - [strTableGet LM_INSTALLOPTIONS_PHONE]"
        puts "    [strTableGet LM_INSTALLOPTIONS_PHONE_DESC]"
        puts "4 - Have no access to the outside network.\n\n"
 
        while (1) {
            puts "Please enter your selection. \[1\]\n"
            set ret [prompt]
            switch -regexp -- $ret {
                "^$" -
                "^1$" {  onAutoInst ; nextCallback ; return 0  }
                "^2$" {  onEmail    ; nextCallback ; return 0  }
                "^3$" {  onPhone    ; nextCallback ; return 0  }
                "^4$" {  
                    set setupVals(noOutsideAccess) 1
                    onNoOutsideAccess
                    return [pageCreate(lmInstOptions)]
                }
                "^-$" {  
                    if { $setupVals(lmInstType) == "nodeLocked" } {
                        backCallback
                        return 0
                    } else {
                        set currPageIndex [lsearch $ctrlVals(pageList) $ctrlVals(currPage)]
                        set prevPageIndex [expr $currPageIndex - 1]
                        set prevPage [lindex $ctrlVals(pageList) $prevPageIndex]

                        if { $prevPage == "currLicInfo" } {
                            backCallback
                            return 0
                        } else {
                            puts "Error: Cannot go back any further"
                            while { [prompt "Press <Enter> to continue."] != "" } {
                            }
                            return [pageCreate(lmInstOptions)]
                        }
                    }
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
# pageProcess(lmInstOptions) - process inputs from lmInstOptions page if any
#
# This procedure will process inputs from lmInstOptions page if any
#
# SYNOPSIS
# .tS
# pageProcess(lmInstOptions)
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: 1 when successful
#
# ERRORS: N/A
#

proc pageProcess(lmInstOptions) {} {
    global setupVals ctrlVals lmVals
    global valuesReset

    # valuesReset is a global variable used in LICMANUAL
    # to see if lmVals needs to be initialized

    set choice $setupVals(lmInstOptions)

    switch $choice {
        onAutoInst {  
            if { $setupVals(lmInstType) == "nodeLocked" } {
                pageListAdd nodeLock
            } else {
                pageListAdd autoInst  
            }
        }
        onEmail {
            pageListAdd email
            if {$lmVals(successfulDbQuery) && $setupVals(ELMUser) &&
                [instTypeGet] == "license"} {
                set valuesReset 0
            } else {      
                set valuesReset 1            
            }
        }
        onPhone {  
            pageListAdd phone
            if {$lmVals(successfulDbQuery) && $setupVals(ELMUser) &&
                [instTypeGet] == "license"} {
                set valuesReset 0
            } else {
                set valuesReset 1
            }
        }            
    }

    dbgputs "lmInstOptions: $ctrlVals(pageList)"
    dbgputs "lmInstOptions choice: $setupVals(lmInstOptions)"

    return 1
}

#############################################################################
#
# onAutoInst - set up wizard pages when auto lic install option is selected
#
# This procedure is a callback which sets up wizard pages when auto lic
# installation is selected
#
# SYNOPSIS
# .tS
# onAutoInst
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc onAutoInst {} {
    global setupVals 

    set setupVals(lmInstOptions) "onAutoInst"
}

#############################################################################
#
# onEmail - set up wizard pages when email option is selected
#
# This procedure is a callback which sets up wizard pages when email
# is selected
#
# SYNOPSIS
# .tS
# onEmail
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc onEmail {} {
    global setupVals

    set setupVals(lmInstOptions) "onEmail"
}


#############################################################################
#
# onPhone - set up wizard pages when the phone option is selected
#
# This procedure is a callback which sets up wizard pages when phone
# is selected
#
# SYNOPSIS
# .tS
# onPhone
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc onPhone {} {
    global setupVals

    set setupVals(lmInstOptions) "onPhone"
}


#############################################################################
#
# onNoOutsideAccess - Check box for no outside network access
#
# This procedure is a callback when the no outside access check box 
# is selected. "Phone or Fax" option will be selected if it is checked.
#
# SYNOPSIS
# .tS
# onNoOutsideAccess
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc onNoOutsideAccess {} {
    global setupVals ctrlVals

    if { [isGUImode] } {
        set w $ctrlVals(mainWindow)

        if {[controlChecked $w.noOutsideAccessCkbox]} {
            controlEnable $w.autoInstChoice 0
            controlEnable $w.autoInstLabel 0            
            controlEnable $w.emailChoice 0
            controlEnable $w.emailLabel 0

            controlCheckSet $w.phoneChoice 1
            if {[instTypeGet] == "license"} {
                controlCheckSet $w.autoInstChoice 0
            }
            controlCheckSet $w.emailChoice 0
            set setupVals(noOutsideAccess) 1

            dialog ok_with_title "No Outside Network Access"\
                   [strTableGet LM_INSTALLOPTIONS_NO_OUTSIDE_ACCESS]

            controlFocusSet $w.phoneChoice
			onPhone
        } else {
            controlEnable $w.autoInstChoice 1
            controlEnable $w.autoInstLabel 1
            controlEnable $w.emailChoice 1
            controlEnable $w.emailLabel 1

            controlCheckSet $w.autoInstChoice 1
            controlCheckSet $w.emailChoice 0
            controlCheckSet $w.phoneChoice 0
            
            if {[instTypeGet] == "license"} {
                controlFocusSet $w.autoInstChoice
            } else {
                controlFocusSet $w.emailChoice
            }
		
            set setupVals(noOutsideAccess) 0
			onAutoInst
        }
    } else { # TEXT mode

        if { $setupVals(noOutsideAccess) } {
            puts [strTableGet LM_INSTALLOPTIONS_NO_OUTSIDE_ACCESS]
            puts "Press \<Return\> to continue..."
            while (1) {
                switch -regexp -- [prompt] {
                    "^$" { break }
                    default { }
                }
            }
        }
    }
}


######################################################################
# Dialog Text Messages
######################################################################

set strTable(LM_INSTALLOPTIONS_TITLE) \
		"License Management Installation Options"

set strTable(LM_INSTALLOPTIONS_MSG_1) \
	"Choose one of the options below to request a license file, then\
	click the Next button to continue the installation."

set strTable(LM_INSTALLOPTIONS_MSG_1_TEXT) \
        "Choose one of the options below to request a license file."

set strTable(LM_INSTALLOPTIONS_AUTO_INSTALL) \
	"Automatic License Installation (Recommended)"

set strTable(LM_INSTALLOPTIONS_EMAIL) "Email"

set strTable(LM_INSTALLOPTIONS_PHONE) "Phone or Fax"

set strTable(LM_INSTALLOPTIONS_AUTO_INSTALL_DESC) \
	"Contact Wind River via TCP/IP to obtain a license file."

set strTable(LM_INSTALLOPTIONS_EMAIL_DESC) \
	"Contact Wind River via email to obtain a license file."

set strTable(LM_INSTALLOPTIONS_PHONE_DESC) \
	"Contact Wind River to obtain a license file."

set strTable(LM_CKBOX_1) \
		"Check here if no access to an outside network"

set strTable(LM_INSTALLOPTIONS_NO_OUTSIDE_ACCESS) \
		"If you wish to perform automatic license installation,\
		visit http://www.windriver.com/ali on a machine which has access\
		to an outside network. Otherwise, choose the \"Phone and Fax\"\
		option to continue."

set strTable(1220_MAIL_TO) "license@windriver.com"

set strTable(1230_MAIL_SUBJECT) "License Key Request"

set strTable(1240_MAIL_ERROR) \
		"Cannot send mail.  Please contact Wind River instead."

set strTable(1541_MAIL_SERVER) "Please enter a valid server name."

set strTable(1250_MAIL_OK) \
    "Your request for the License Key has been sent to\
     [strTableGet 1220_MAIL_TO].  Please allow us one business day for\
     processing your request."

set strTable(3356_LICENSE_WARN) \
    "You must enter the return email address"


set strTable(1330_LICENSE_MAIL) \
    "The following message will be sent to [strTableGet 1220_MAIL_TO]."

set strTable(1340_LICENSE_MAIL_HEADER_LINE1) "To Wind River Systems,"

set strTable(1340_LICENSE_MAIL_HEADER_LINE2) \
    "This is a request for a License Key:"

set strTable(1340_LICENSE_MAIL_HEADER_LINE3) \
    "format %s \"Customer Name\t :  \[lindex \$args 0\]\""

set strTable(1340_LICENSE_MAIL_HEADER_LINE4) \
    "format %s \"Company Name\t :  \[lindex \$args 0\]\""

set strTable(1340_LICENSE_MAIL_HEADER_LINE5) \
    "format %s \"Installation Key :  \[lindex \$args 0\]\""

set strTable(1340_LICENSE_MAIL_HEADER_LINE5a) \
    "format %s \"Installation Key\t :  \[lindex \$args 0\]\""

set strTable(1340_LICENSE_MAIL_HEADER_LINE6) \
    "format %s \"License Number\t :  \[lindex \$args 0\]\""

set strTable(1340_LICENSE_MAIL_HEADER_LINE7) \
    "format %s \"Host Name\t :  \[lindex \$args 0\]\""

set strTable(1340_LICENSE_MAIL_HEADER_LINE8) \
    "format %s \"Host Id\t\t :  \[lindex \$args 0\]\""

set strTable(1340_LICENSE_MAIL_HEADER_LINE9) \
    "format %s \"Alternate Host Id:  \[lindex \$args 0\]\""

set strTable(1340_LICENSE_MAIL_HEADER_LINE9a) \
    "format %s \"Alternate Host Id\t :  \[lindex \$args 0\]\""

set strTable(1340_LICENSE_MAIL_HEADER_LINE10a) \
    "Request to re-issue the existing license file for this customer"

set strTable(1340_LICENSE_MAIL_HEADER_LINE10b) \
    "Request to update the license file with the following\
     configuration for this customer"

set strTable(1340_LICENSE_MAIL_HEADER_LINE11) \
    "Licensed product feature(s):"

set strTable(1530_TITLE_LICENSE_MAIL) "Email License"

set strTable(1350_LICENSE_CALL) \
    "To obtain a license key, call 1-800-545-9463 with the\
     information listed below. You can also fax your license\
     request to 1-510-749-2538. For further contact information,\
     please visit http://www.windriver.com/license_admin"

set strTable(1540_TITLE_LICENSE_CALL) "Contact Wind River"
