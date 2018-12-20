# LMERROR.TCL - Setup procedures application license management errors
#
# Copyright 1999-2003 Wind River Systems, Inc
#
# modification history
# --------------------
# 02b,14feb03,bjl  fixed error message typo.
# 02a,12jun01,j_w  Modified for Tornado 2.2
# 01l,06dec00,wmd  Need to clarify error for "U" to include the fact that your
#                  license daemon may be down.
# 01k,30oct00,j_w  enable the back button for the next page
# 01j,30oct00,j_w  removed destDir page if connection error
# 01i,20oct00,j_w  Do not continue LM installation if connection errors
#                  occurred (spr 35535)
# 01h,18may00,wmd  Fix eol to eliminate unprintable characters.
# 01g,06apr00,bwd  Removed contact info to use URL instead.
# 01f,25jan00,bwd  Changed error message and contact information
# 01e,25jan00,bwd  Added codes for command line SETUP (TEXT mode)
# 01d,04jan00,bwd  Corrected contact information for Sales Inquiries and
#                  License Administrators
# 01c,23dec99,bwd  Modified the error dialog to display with a scrollbar to
#                  accommodate long message/information
# 01b,07dec99,wmd  Make the next button -> Done for those errors that are
#                  not repairable.
# 01a,05dec99,wmd  written
#


####################################################################################
#
# pageCreate(lmError) - Informs user of application license management error
#
# The page may or may not advance to another page depending on the nature of
# the error.
#
# SYNOPSIS
# .tS
# pageCreate(lmError)
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc pageCreate(lmError) {} {
    global ctrlVals setupVals lmVals
	set connectError 0

    set messageText ""

    if { [isGUImode] } {
        set ctrlVals(volatileFrm) [list \
                [list text -name message -vscroll -readonly -multiline \
                           -x 99 -y 10 -w 200 -h 160] ]
    }

    set messageText [strTableGet LMERROR_MSG]

    switch $setupVals(lmError) {
        \-U -
        /U {
            # license file is corrupted

            if { [isGUImode] } {  
                append messageText [strTableGet LMERROR_U]  
            } else {  
                append messageText [strTableGet LMERROR_U_TEXT]  
            }
        }

        \-M -
        /M {
            # no licenses are available (they're all in use)
            append messageText [strTableGet LMERROR_M]
        }

        \-C -
        /C {
            # no license server is detected
			
			if {![isConnectError]} {
				if { [isGUImode] } {  
					append messageText [strTableGet LMERROR_C]  
				} else {  
					append messageText [strTableGet LMERROR_C_TEXT]  
				}
			} else {
				append messageText [strTableGet LMERROR_CONNECT_FAILED]

				# remove the rest of the pages
				pageRemove privilege
				pageRemove registration 
				pageRemove destDir
				pageRemove lmOptions
				pageRemove dbQuery
			}
        }

        \-E -
        /E {
            # license has expired or date in license file is bad
            append messageText [strTableGet LMERROR_E]
        }
    }

    if { [isGUImode] } {
        set w [dlgFrmCreate [strTableGet LMERROR_TITLE]]

        switch $setupVals(lmError) {
            \-M -
            /M -
            \-E -
            /E { 
				controlValuesSet $w.nextButt "&Done"
            }
			\-C -
			/C {
				if {[isConnectError]} {
					controlValuesSet $w.nextButt "&Done"
				}
			}
				
        }

        controlTextSet $w.message $messageText
		controlEnable $w.backButt 0
        controlEnable $w.cancelButt 1

    } else { # TEXT MODE

        printPageTitle [strTableGet LMERROR_TITLE]
        puts "$messageText\n"

        switch $setupVals(lmError) {
            \-U -
            /U -
            \-C -
            /C {
				if {[isConnectError]} {
					set prompt_msg "Please press \<Return\> to exit SETUP"
				} else {
					set prompt_msg "Please press \<Return\> to continue"
				}
            }

            \-M -
            /M -
            \-E -
            /E { 
                set prompt_msg "Please press \<Return\> to exit SETUP"
            }
        }

        while (1) {
            switch -regexp -- [prompt $prompt_msg] {
                "^$"  {  nextCallback ; return 0  }
                "^[eE][xX][iI][tT]$" {  return 0  }
                "^-$" {  
                    puts "Cannot go back any further\n"
                }
                default {
                    puts "Error: Invalid input."
                }
            }
        }
    }
}

proc isConnectError {} {
	global setupVals

	switch -- $setupVals(lmRcStr) {
		-14 -
		-52 {
			# -14 LM_BADHOST - cannot find SERVER hostname in network db
			# -52 LM_NOSERVRESP - Server did not respond to message
			return 1
		}
		default {
			return 0
		}
	}

}


#############################################################################
#
# pageProcess(lmError) - process inputs from lmError page
#
# This procedure will process inputs from the lmError page
#
# SYNOPSIS
# .tS
# pageProcess(lmError)
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: 1 when successful, else 0
#
# ERRORS: N/A
#

proc pageProcess(lmError) {} {
	global ctrlVals

	# enable the back button 
	controlEnable $ctrlVals(mainWindow).backButt 1
	
    return 1
}



######################################################################
# Dialog Text Messages
######################################################################
global setupVals

set strTable(SALE_CONTACT_INFO) \
        "\r\n\r\nPlease contact Wind River Systems Sales to purchase\
		additional licenses or to extend your tempoary license:\r\n\r\n\
		\thttp://www.windriver.com/sales_offices"

set strTable(LICENSE_CONTACT_INFO) \
        "\r\n\r\nIf you need additional help with license management,\
        please contact license administration:\r\n\r\n\
		\thttp://www.windriver.com/license_admin"

set strTable(LMERROR_TITLE) "License Management Error"

set strTable(LMERROR_MSG) \
	"The application is unable to obtain a license for the feature\
        $setupVals(lmFeatureName). The error is: \r\n\r\n\t\
        \"$setupVals(lmErrString).\" \r\n\t\
		Error Code: \($setupVals(lmRcStr)\)\r\n\r\n"

set strTable(LMERROR_E) \
        "Your license(s) for the product $setupVals(lmFeatureName)\
        has expired.[strTableGet SALE_CONTACT_INFO]"

set strTable(LMERROR_C) \
        "This error indicates that there is no response from the license\
        server.  Either the license server is not running, or the license\
        management software has not been installed on the server.  Please\
        contact your system administrator to check if license management\
        has been installed and that the server is running.  If the server\
        is indeed running, please click on the <Next> button to correctly\
        setup up your machine for license management as an end user.\
        [strTableGet LICENSE_CONTACT_INFO]"

set strTable(LMERROR_C_TEXT) \
        "This error indicates that there is no response from the license\
        server.  Either the license server is not running, or the license\
        management software has not been installed on the server.  Please\
        contact your system administrator to check if license management\
        has been installed and that the server is running.  If the server\
        is indeed running, please press \<Return\> to correctly\
        setup up your machine for license management as an end user.\
        [strTableGet LICENSE_CONTACT_INFO]"

set strTable(LMERROR_U) \
        "This indicates that the license file installed on your server\
        \(for floating licenses\) or on your current host \(for node-locked\
        licenses\) is either corrupted or you have not purchased this product.\
	Or this error may also indicate that the Wind River license daemon\
	is down and some other license server is responding that it\
	is unable to find the feature that you are requesting.\
	If this is the case, please exit this program and have your system\
	administrator restart the daemon. Otherwise click on the <next> button\
	to correctly set up your machine for license management as an end user.\
        [strTableGet LICENSE_CONTACT_INFO]"

set strTable(LMERROR_U_TEXT) \
        "This indicates that the license file installed on your server\
        \(for floating licenses\) or on your current host \(for node-locked\
        licenses\) is either corrupted or you have not purchased this product.\
	Or this error may also indicate that the Wind River license daemon\
	is down and some other license server is responding that it\
	is unable to find the feature that you are requesting.\
	If this is the case, please exit this program and have your system\
	administrator restart the daemon. Otherwise please press \<Return\> to\
        correctly set up your machine for license management as an end user.\
        [strTableGet LICENSE_CONTACT_INFO]"

set strTable(LMERROR_M) \
        "There are no more licenses available for the product\
        $setupVals(lmFeatureName).[strTableGet SALE_CONTACT_INFO]"

set strTable(LMERROR_CONNECT_FAILED) \
		"This indicates that either the license server is down or a\
		problem has occurred in your network connection. Please contact\
		your system administrator to check if the license server is up\
		and running or to check if the network cables are connected.\
		[strTableGet LICENSE_CONTACT_INFO]"
