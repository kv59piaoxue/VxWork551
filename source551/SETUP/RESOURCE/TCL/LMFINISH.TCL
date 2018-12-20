# LMFINISH.TCL  - Setup procedures for implementing install LM finish 
#                 wizard page
#
# Copyright 1999 Wind River Systems, Inc
#
# modification history
# --------------------
# 02a,12jun01,j_w  Modified for Tornado 2.2
# 01w,20dec00,bwd  Display license daemon instructions for Linux
# 01v,19jul00,bwd  Fixed TCL error: change else to elseif
# 01u,09jun00,bwd  Added another host type check for x86-linux2
# 01t,01jun00,bwd  SPR 31446: added instructions for license admin to run the
#                  license daemon
# 01s,04feb00,j_w  Make this the License Management Finish page for floating
#                  and nodeLock license configuration
# 01r,31jan00,bwd  Added codes to automate last dialog box and replace
#                  setupVals(cmdMode) with isGUImode
# 01q,21jan00,bwd  Added codes to inform users of lmEnvVar.txt for TEXT MODE
# 01p,19jan00,wmd  Remove the default option for the "Finish" button.
# 01o,17jan00,wmd  Remove display of reboot messages.
# 01n,06jan00,bwd  No test automation for command line SETUP
# 01m,15dec99,bwd  Corrected typo
# 01l,14dec99,wmd  Fix the output to text file not to use \r. On Unix looks
#                  bad.
# 01k,08dec99,j_w  Fixed spacing
# 01j,08dec99,wmd  Fix where the env vars info is stored.  Let's use
#                  setup.log.
# 01i,08dec99,wmd  Fix so Windows side works.
# 01h,07dec99,wmd  Add code to write out file lmEnvVar.txt to hold env. var.
#                  settings for users.
# 01g,03dec99,j_w  Disable the help button
# 01g,02dec99,clc  add text mode
# 01f,29nov99,wmd  Fix bug in height of a label.
# 01e,24nov99,bwd  Made changes for autoSetupLog
# 01d,23nov99,wmd  Need to add windows version of the page.
# 01c,22nov99,wmd  Add real code to display Unix side server info for
#                  LM_LICENSE_FILE env. var.
# 01b,01oct99,j_w  modified lmFinish page
# 01a,08Jul99,j_w  written.
#

#############################################################################
#
# pageCreate(lmFinish) - license finish page for floating and nodeLock 
#                        configuration
#
# This procedure will create a finsh page for License Management installation
# for floating and nodeLock configuration. This page is not for the end user
# configuration finish page. (see FINISH.TCL)
#
# SYNOPSIS
# .tS
# pageCreate(lmFinish)
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc pageCreate(lmFinish) {} {
    global ctrlVals env

    if { [isGUImode] } {
        set ctrlVals(volatileFrm) [list \
				[list label -name finishText \
				            -title [strTableGet LMFINISH_MSG1] \
							-x 100 -y 10 -w 200 -h 15] \
				[list text -name instruction -border\
                           -multiline -vscroll -readonly\
                           -x 100 -y 25 -w 200 -h 145] ]

        set w [dlgFrmCreate [strTableGet LMFINISH_TITLE]]

        controlValuesSet $w.nextButt "Finish"
        controlEnable $w.helpButt 0
        controlEnable $w.backButt 0
        controlEnable $w.nextButt 1
        controlEnable $w.cancelButt 0

		controlFocusSet $w.nextButt

        if { [isUnix] } {
            controlTextSet $w.instruction "[strTableGet LMFINISH_UNIX] \
                                           [strTableGet LMFINISH_MSG2]"
        } else {
            controlTextSet $w.instruction "[strTableGet LMFINISH_WINDOWS] \
                                           [strTableGet LMFINISH_MSG2]"
        }

        # test automation

        if { $ctrlVals(useInputScript) } {
            autoSetupLog "License Management Finish Page: skipped"
            autoSetupLog "[strTableGet LMFINISH_MSG1] Please refer to\
                          http://www.globetrotter.com for more information\
                          about running the license daemon."
		
			nextCallback
		}

    } else { # text mode

        printPageTitle [strTableGet LMFINISH_TITLE]
        puts [strTableGet LMFINISH_MSG1]

        if { [isUnix] } {
            puts [strTableGet LMFINISH_UNIX_TEXT]
        }
    }
}

#############################################################################
#
# pageProcess(lmFinish) - process inputs from LM finish page if any 
#
# This procedure will process inputs from the LM finish page if any
#
# SYNOPSIS
# .tS
# pageProcess(lmFinish)
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: 1 when successful
#
# ERRORS: N/A
#

proc pageProcess(lmFinish) {} {
    return 1
}

######################################################################
# Dialog Text Messages
######################################################################

set strTable(LMFINISH_TITLE) "Finish"

set strTable(LMFINISH_MSG1) \
	"License Management has been successfully configured."

set strTable(LMFINISH_UNIX) \
    "You will need to start the license daemon on this machine. \
     In the \$WIND_BASE/host/sun4-solaris2/bin directory,\
     execute the command\r\n\
     \r\nlmgrd -c \$WIND_BASE/.wind/license/WRSLicense.lic -x lmdown\
     \r\n\r\nFor more information about running the license daemon,\
     please refer to http://www.globetrotter.com."

set strTable(LMFINISH_UNIX_TEXT) \
    "\nYou will need to start the license daemon on this machine. \
     \nIn the \$WIND_BASE/host/sun4-solaris2/bin directory,\
     execute the command\n\
     \nlmgrd -c \$WIND_BASE/.wind/license/WRSLicense.lic -x lmdown\
     \n\nFor more information about running the license daemon,\
     please refer to http://www.globetrotter.com."

set strTable(LMFINISH_WINDOWS) \
    "You will need to start the license daemon on this machine. Please\
     follow the steps below:\r\n\r\n1) You may need to reboot this\
     machine to properly start the daemon.\r\n2) After rebooting the machine,\
     go to Control Panel and double click on \"FLEXlm License Manager\" icon.\
     \r\n3) Click on the \"Setup\" tab. There, you will be able to enter the\
     path to the license file if it has not already been populated with the\
     correct path, which typically would be\
     \"%WIND_BASE%\\.wind\\license\\WRSLicense.lic\".\r\n4) Click on the\
     \"Control\" tab and start the License Server daemon.\r\n\r\nFor more\
     information about running the license daemon, please refer to\
     http://www.globetrotter.com."

set strTable(LMFINISH_MSG2) \
    "For your convenience, you may use copy\/paste keys to copy the\
     information from this page."
