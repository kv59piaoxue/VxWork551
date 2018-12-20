# LICEMAIL.TCL - UITcl script for sending email.  
#    For TEXT MODE, this is the last page for LM Installation via Email
#
# Copyright 1998 Wind River Systems, Inc.
#
# modification history
# --------------------
# 03a,12jun01,j_w  Added for Tornado 2.2
# 02u,02may01,j_w  Removed alternative host Id 
# 02t,08jan01,bwd  SPR 63370: added line for alternative host id (ethernet
#                  card serial #).
# 02s,01jun00,bwd  Modified email text to indicate the type of license
#                  (floating/nodelocked). Modified codes to write email text
#                  in different files for floating and nodelocked.
# 02r,26may00,bwd  Removed licManual page if reload when user click Back.
#                  Modified email message
# 02q,23may00,bwd  Modified codes to allow email address beginning with
#                  numbers
# 02p,18may00,j_w  Replaced WRS to Wind River (spr 31004)
# 02o,12may00,bwd  Fixed the size of the dialog box
# 02n,12may00,bwd  SPR 31204 - added URL for contact information
# 02m,14feb00,wmd  Change all references to prodCode to featureId.
# 02l,03feb00,bwd  Added codes to check that email addresses are in correct
#                  format
# 02k,02feb00,bwd  Changed setupVals(cmdMode) to use isGUImode
# 02j,14jan00,bwd  Added codes to display this page for TEXT MODE
# 02i,06jan00,bwd  Modified the summary of licensed product feature to include
#                  the no. of licenses requested by users
# 02h,28dec99,bwd  Changed "Licensed Product Feature(s)" to display actual
#                  product name(s) and code(s)
# 02g,21dec99,bwd  Fixed codes to allow Mail Confirmation dialog to also
#                  display on UNIX
# 02f,16dec99,bwd  Fix the display of lmEmailInfo path for UNIX
# 02e,15dec99,bwd  Added codes to write out file lmEmailInfo.txt to hold
#                  license information.
# 02d,15nov99,bwd  Removed sections for auto setup installation. No automation
#                  for LM via Email
# 02c,15nov99,bwd  Removed messageBox lines used for debugging
# 02b,15nov99,bwd  Added setions for automatic setup installation
# 02a,30Sep99,j_w  Modified for T3
# 01a,01Jul99,j_w  extracted from LICW32.TCL


global outFileName
set outFileName ""

#############################################################################
#
# pageCreate(licEmail) - Create a page to display license request information
#
# This procedure will display license request information
#
# SYNOPSIS
# .tS
# pageCreate(licEmail)
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc pageCreate(licEmail) {} {
    global setupVals ctrlVals lmVals
    global env outFileName

    set setupVals(WRSLicense) [setupLicenseNumGet]

    if { $lmVals(reload) } {
        pageRemove licManual
    }

    if { $setupVals(lmInstType) == "nodeLocked" } {
        set outFileName "lmEmailNL.txt"
    } else {
        set outFileName "lmEmailFT.txt"
    }

    if {[isUnix]} {
        set outFileName "[destDirGet]/$outFileName"
    } else {
        set outFileName "[destDirGet]\\$outFileName"
    }

    if { [isGUImode] } {

        set ctrlVals(volatileFrm) [list \
                [list label -name msg \
                            -title [strTableGet 1330_LICENSE_MAIL] \
                            -x 100 -y 10 -w 205 -h 10] \
                [list label -name lmEmailText \
                            -title "[strTableGet LICEMAIL_MSG] $outFileName\
                                    for your convenience. \
                                    [strTableGet LICEMAIL_CONTACT_INFO]" \
                            -x 100 -y 20 -w 200 -h 32] \
                [list text  -name licenseInfo \
                            -multiline -hscroll \
                            -vscroll -readonly \
                            -x 100 -y 52 -w 205 -h 120] ]
    }
    
    set mailMsg "[strTableGet 1340_LICENSE_MAIL_HEADER_LINE1]\
         \r\n\r\n[strTableGet 1340_LICENSE_MAIL_HEADER_LINE2]\
         \r\n\r\n[strTableGet 1340_LICENSE_MAIL_HEADER_LINE3 [userNameGet]]\
             \r\n[strTableGet 1340_LICENSE_MAIL_HEADER_LINE4 [companyNameGet]]\
             \r\n[strTableGet 1340_LICENSE_MAIL_HEADER_LINE5a [instKeyGet]]\
             \r\n[strTableGet 1340_LICENSE_MAIL_HEADER_LINE6 \
                              $setupVals(WRSLicense)]\
             \r\n[strTableGet 1340_LICENSE_MAIL_HEADER_LINE7 \
                              $setupVals(hostName)]\
             \r\n[strTableGet 1340_LICENSE_MAIL_HEADER_LINE8 \
                              $setupVals(hostId)]"

    set fileMsg "[strTableGet 1340_LICENSE_MAIL_HEADER_LINE1]\
             \n\n[strTableGet 1340_LICENSE_MAIL_HEADER_LINE2]\
             \n\n[strTableGet 1340_LICENSE_MAIL_HEADER_LINE3 [userNameGet]]\
               \n[strTableGet 1340_LICENSE_MAIL_HEADER_LINE4 [companyNameGet]]\
               \n[strTableGet 1340_LICENSE_MAIL_HEADER_LINE5 [instKeyGet]]\
               \n[strTableGet 1340_LICENSE_MAIL_HEADER_LINE6 \
                              $setupVals(WRSLicense)]\
               \n[strTableGet 1340_LICENSE_MAIL_HEADER_LINE7 \
                              $setupVals(hostName)]\
               \n[strTableGet 1340_LICENSE_MAIL_HEADER_LINE8 \
                              $setupVals(hostId)]"

    if { $setupVals(lmInstType) == "nodeLocked" } {
        append mailMsg "\r\n\r\nNode Locked License Request:"
        append fileMsg "\n\nNode Locked License Request:"
    } else {
        append mailMsg "\r\n\r\nFloating License Request:"
        append fileMsg "\n\nFloating License Request:"
    }

    if { $lmVals(reload) } {
        append mailMsg "\r\n[strTableGet 1340_LICENSE_MAIL_HEADER_LINE10a]"
        append fileMsg "\n[strTableGet 1340_LICENSE_MAIL_HEADER_LINE10a]"

    } else {
        append mailMsg "\r\n[strTableGet 1340_LICENSE_MAIL_HEADER_LINE10b]\
                        \r\n\r\n[strTableGet 1340_LICENSE_MAIL_HEADER_LINE11]\r\n"

        append fileMsg "\n[strTableGet 1340_LICENSE_MAIL_HEADER_LINE10b]\
                        \n\n[strTableGet 1340_LICENSE_MAIL_HEADER_LINE11]\n"

        for {set ix 0} {$ix < [llength $lmVals(lmLicensedProductNames)]} {incr ix} {
            set feature [lindex $lmVals(lmLicensedProductNames) $ix]
            set featureId [lindex $lmVals(lmLicensedFeatureIds) $ix]
            set licCount [lindex $lmVals(lmFeaturesRequested) $ix]

            append mailMsg "\r\nProduct Name: $feature\r\nFeature ID: $featureId\
                            \r\nNo. of licenses requested: $licCount\r\n"
            append fileMsg "\nProduct Name: $feature\nFeature ID: $featureId\
                            \nNo. of licenses requested: $licCount\n"
        }
    }

    set setupVals(mailMsg) $mailMsg
    set setupVals(fileMsg) $fileMsg

    if { [isGUImode] } {
        set w [dlgFrmCreate [strTableGet 1530_TITLE_LICENSE_MAIL]]

        controlValuesSet $w.licenseInfo "$setupVals(mailMsg)"
        controlEnable $w.backButt 1

        if {[isUnix]} {
	    controlValuesSet $w.nextButt "Send"
        }
    } else { # TEXT mode
        printPageTitle [strTableGet 1530_TITLE_LICENSE_MAIL]
        puts [strTableGet 1330_LICENSE_MAIL]
        puts "[strTableGet LICEMAIL_MSG] $outFileName for your convenience.\n\n"
        puts "$setupVals(fileMsg)\n\n"

        while (1) {
            puts "Press \<Return\> to Continue"
            switch -regexp -- [prompt] {
                "^-$" {  backCallback ; return 0  }
                "^$"  {  nextCallback ; return 0  }
                "^[eE][xX][iI][tT]$" {  return 0  }
                default {  }
            }
        }
    }
}

#############################################################################
#
# pageProcess(licEmail) - write all information to a text file and make a 
#                         call to send email
#
# This procedure will write License file information to a text file and
# make a call to send email
#
# SYNOPSIS
# .tS
# pageProcess(licEmail)
# .tE
#
# PARAMETERS: N/A
#
# RETURNS:  1 if successful
#
# ERRORS: N/A
#

proc pageProcess(licEmail) {} {
    global setupVals ctrlVals outFileName

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
        return [mailSend]

    } else { # TEXT MODE -- this is the last page for LM Installation via Email
        if {[catch {open $outFileName w} fd]} {
            puts "Error opening output filename: $outFileName"
            while { [prompt "Press <Enter> to Continue"] != "" } {
            }
            return 0
        } else {
            puts $fd [string trimleft $setupVals(fileMsg)]
            if {[catch {close $fd} err]} {
                puts "Error closing file $outFileName"
                while { [prompt "Press <Enter> to Continue"] != "" } {
                }
            }
        }
        onMailSend
        return 0
    }
}

#############################################################################
#
# mailSend() - create "Mail Confirmation" dialog for GUI mode
#
# This procedure will create "Mail Confirmation" dialog for GUI mode
#
# SYNOPSIS
# .tS
# mailSend()
# .tE
#
# PARAMETERS: N/A
#
# RETURNS:  1 if successful
#
# ERRORS: N/A
#

proc mailSend {} {
    global ctrlVals
    global setupVals

    dialogCreate \
        -name mailConfirmDlg \
        -parent $ctrlVals(mainWindow) \
        -title "Mail Confirmation" \
        -width 181 -height 133 \
        -init mailSendInit \
        -controls { \
            { button -title "Send" -name sendButt -default \
	             -xpos 66 -ypos 112 -width 50 -height 14  \
                     -callback onMailSend }
            { button -title "Cancel" -name cancelButt  \
                     -xpos 124 -ypos 112 -width 50 -height 14  \
                     -callback onMailCancel }
            { label -title "Subject:" -name subjectLabel  \
                    -xpos 7 -ypos 41 -width 33 -height 8 }
            { text -name toEdit -readonly \
                   -xpos 47 -ypos 6 -width 126 -height 12 }
            { label -title "To:" -name toLabel  \
                    -xpos 7 -ypos 8 -width 19 -height 8 }
            { label -title "From:" -name fromLabel  \
                    -xpos 7 -ypos 25 -width 18 -height 8 }
            { text -name fromEdit  \
                   -xpos 47 -ypos 23 -width 126 -height 12 }
            { text -name subjectEdit  -readonly \
                   -xpos 47 -ypos 39 -width 126 -height 12 }
            { group -title "Mail Protocol" -name group1  \
                    -xpos 7 -ypos 56 -width 166 -height 47 }
            { choice -title "SMTP host:" -name smtpButt  \
                     -newgroup -auto \
                     -xpos 16 -ypos 74 -width 56 -height 10  \
                     -callback onSmtp }
            { choice -title "MAPI" -name mapiButt  \
                     -auto \
                     -xpos 16 -ypos 86 -width 33 -height 10  \
                     -callback onMapi }
            { text -name smtpEdit  \
                   -xpos 72 -ypos 73 -width 90 -height 13 }
	    }
    return $setupVals(mailDlgRet)
}

#############################################################################
#
# onMailCancel() - a callback function when Cancel button on Mail
#                  Confirmation dialog is pressed
#
# This procedure closes the dialog and brings user back to licEmail page
#
# SYNOPSIS
# .tS
# onMailCancel()
# .tE
#
# PARAMETERS: N/A
#
# RETURNS:  1 if successful
#
# ERRORS: N/A
#

proc onMailCancel {} {
    global setupVals

    windowClose mailConfirmDlg
    set setupVals(mailDlgRet) 0
}

#############################################################################
#
# onMailSend() - a callback function when Send button on Mail
#                Confirmation dialog is pressed
#
# For GUI mode:  This procedure reads input from confirmation dialog, performs
#                error checkings, initializes variables and prepares to email.
# For TEXT mode: This procedure prompts user for email information, initializes
#                variables and prepares to email.
#
# SYNOPSIS
# .tS
# onMailSend()
# .tE
#
# PARAMETERS: N/A
#
# RETURNS:  1 if successful
#
# ERRORS: N/A
#

proc onMailSend {} {
    global setupVals outFileName

    #initialize everything

    set retVal 1
    set attachments ""
    set bccList ""
    set server ""
    set toList ""
    set sender ""
    set ccList ""
    set subject ""
    set msgContents "$setupVals(mailMsg)"
    set mailDate [clock format [clock second] -format "%a, %d %h %Y %X"]

    if { [isGUImode] } {

        set server [controlValuesGet mailConfirmDlg.smtpEdit]
        set toList [controlValuesGet mailConfirmDlg.toEdit]
        set sender [controlValuesGet mailConfirmDlg.fromEdit]
        set ccList $sender
        set subject [controlValuesGet mailConfirmDlg.subjectEdit]

        # sender address must be entered

        if {$sender == ""} {
            messageBox [strTableGet 3356_LICENSE_WARN]
            controlFocusSet mailConfirmDlg.fromEdit
            return 0
        }

        # check email address(es) format

        set isValid 1
        set badEmail ""

        foreach email $sender {
            if { ![regexp {^[a-zA-Z0-9].*@.*} $email] } {
                append badEmail "$email "
                set isValid 0
                set sender ""
            }
        }

        if { ! $isValid } {
            messageBox "Error: Invalid email address(es) format: $badEmail\n"
            controlFocusSet mailConfirmDlg.fromEdit
            return 0
        }

        # server name must be entered if SMTP

        if {$server == "" &&  [controlValuesGet mailConfirmDlg.smtpButt] == "1"} {
            messageBox [strTableGet 1541_MAIL_SERVER]
            set retVal 0
        }

    } else { #TEXT MODE  

        puts "\n\n*******************"
        puts "Mail Confirmation"
        puts "*******************\n\n"

        set isSMTP 0
        set question "sender"
        while {[string compare $question "done"] != 0} {
            switch $question {
                "sender" {
                    puts [strTableGet LICEMAIL_SENDMAIL_SENDER]
                    set ret [prompt]
                    switch -regexp -- $ret {
                        "^-$" {
                            pageCreate(licEmail)
                            return 0
                        }
                        "^$" {
                            puts "Error: [strTableGet 3356_LICENSE_WARN]"
                            while {[prompt "Press <Enter> to continue."] != "" } {
                            }
                        }
                        "^[eE][xX][iI][tT]$" {
                            return 0
                        }
                        default {

                            set isValid 1
                            set badEmail ""

                            foreach email $ret {
                                if { ![regexp {^[a-zA-Z0-9].*@.*} $email] } {
                                    append badEmail "$email "
                                    set isValid 0
                                }
                            }

                            if { $isValid } {
                                set sender $ret
                                set question "server"
                            } else {
                                puts "Error: Invalid email address(es) format: $badEmail\n"
                                set question "sender"
                            }
                        }
                    }
                }
                "server" {
                    puts [strTableGet LICEMAIL_SENDMAIL_SERVER]
                    set ret [prompt]
                    switch -regexp -- $ret {
                        "^-$" {
                            set question "sender"
                        }
                        "^1$" {
                            set server $ret
                            set isSMTP 1
                            set question "host"
                        }
                        "^2$" {
                            set server ""
                            set question "confirm"
                        }
                        "^[eE][xX][iI][tT]$" {
                            return 0
                        }
                        default {
                            puts "Error: Invalid input."
                            while {[prompt "Press <Enter> to continue."] != "" } {
                            }
                        }                
                    }
                }
                "host" {
                    puts [strTableGet LICEMAIL_SENDMAIL_HOST]
                    set ret [prompt]
                    switch -regexp -- $ret {
                        "^-$" {
                            set question "server"
                        }
                        "^$" {
                            set server "mailhost"
                            set question "confirm"
                        }
                        "^[eE][xX][iI][tT]$" {
                            return 0
                        }
                        default {
                            set server $ret
                            set question "confirm"
                        }
                    }
                }
                "confirm" {
                    puts [strTableGet LICEMAIL_SENDMAIL_CONFIRM]
                    set ret [prompt]
                    switch -regexp -- $ret {
                        "^-$" {  
                            if { $isSMTP } {
                                set isSMTP 0
                                set question "host"
                            } else {
                                set question "server"
                            }
                        }
                        "^$"  {  set question "done"    }
                        "^[eE][xX][iI][tT]$" {  return 0  }
                        default {  }
                    }    
                }
                "done" {
                    set retVal 1
                }
            }
        }

        set toList [strTableGet 1220_MAIL_TO]
        set ccList $sender
        set subject [strTableGet 1230_MAIL_SUBJECT]
    }

    if {[isUnix]} {
        set recipients [concat $toList $ccList $bccList]
        
	if [catch {exec mail -s $subject $recipients < $outFileName} error] {
	    if [catch {exec mail $recipients < $outFileName} e] {
                if { [isGUImode] } {
                    messageBox [strTableGet 1240_MAIL_ERROR]
                } else {
                    puts "Error: [strTableGet 1240_MAIL_ERROR]"
                }
                return 0
            }
        }

        if { [isGUImode] } {
            messageBox [strTableGet 1250_MAIL_OK]
            windowClose mailConfirmDlg
        } else {
            puts "[strTableGet 1250_MAIL_OK]\n"
        }
        
        set setupVals(mailDlgRet) $retVal
        return $retVal

    } else {

        beginWaitCursor
	
        if {[controlValuesGet mailConfirmDlg.smtpButt] == "0"} {
            set mailCommand {mapiMailSend $toList $ccList $bccList \
		    $subject $msgContents $attachments}
        } {
            set mailCommand {smtpMailSend $mailDate $sender $toList $ccList \
		    $bccList $subject $msgContents $server $attachments}
            set msgContents [split $msgContents \n]
        }

        if [catch $mailCommand error] {
	    endWaitCursor
	    messageBox -stop [strTableGet 1240_MAIL_ERROR]
	    #messageBox -stop $error
        } {
	    endWaitCursor
	    messageBox -info  [strTableGet 1250_MAIL_OK]
	    windowClose mailConfirmDlg
        }    
   }
   set setupVals(mailDlgRet) $retVal
   return $retVal
}

#############################################################################
#
# mailSendInit() - initialize "Mail Confirmation" dialog
#
# This procedure initializes "Mail Confirmation" dialog
#
# SYNOPSIS
# .tS
# mailSendInit()
# .tE
#
# PARAMETERS: N/A
#
# RETURNS:  N/A
#
# ERRORS: N/A
#

proc mailSendInit {} {
    
    controlValuesSet mailConfirmDlg.toEdit [strTableGet 1220_MAIL_TO]
    controlValuesSet mailConfirmDlg.subjectEdit [strTableGet 1230_MAIL_SUBJECT]
    controlValuesSet mailConfirmDlg.smtpEdit "mailhost"
    #controlValuesSet mailConfirmDlg.smtpButt 1
    controlCheckSet mailConfirmDlg.smtpButt 1
}

#############################################################################
#
# onSmtp() - a callback function when SMTP radio button is selected
#
# This procedure is a callback function when SMTP radio button is selected
#
# SYNOPSIS
# .tS
# onSmtp()
# .tE
#
# PARAMETERS: N/A
#
# RETURNS:  N/A
#
# ERRORS: N/A
#

proc onSmtp {} {
    controlEnable mailConfirmDlg.smtpEdit 1
}

#############################################################################
#
# onMapi() - a callback function when MAPI radio button is selected
#
# This procedure is a callback function when MAPI radio button is selected
#
# SYNOPSIS
# .tS
# onMapi()
# .tE
#
# PARAMETERS: N/A
#
# RETURNS:  N/A
#
# ERRORS: N/A
#

proc onMapi {} {
    controlEnable mailConfirmDlg.smtpEdit 0
}


######################################################################
# Dialog Text Messages
######################################################################

set strTable(LICEMAIL_MSG) \
        "This information will be written to"

set strTable(LICEMAIL_SENDMAIL_SENDER) \
        "Please enter the return email address.  If you wish to enter\
        additional email addresses, please separate them by white spaces"

set strTable(LICEMAIL_CONTACT_INFO) \
        "For further contact information, please visit\
         http://www.windriver.com/license_admin"

set strTable(LICEMAIL_SENDMAIL_SERVER) \
        "Please select Mail Protocol\n1 - SMTP ; 2 - MAPI"

set strTable(LICEMAIL_SENDMAIL_HOST) \
        "Please enter SMTP host. \[mailhost\]"

set strTable(LICEMAIL_SENDMAIL_CONFIRM) \
        "Press \<Return\> to send license request information to Wind River\
        or enter \"-\" to go back to make changes."
