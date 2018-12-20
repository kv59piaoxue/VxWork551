# LMEXIT.TCL  - Setup procedures for implementing install LM finish 
#                 wizard page
#
# Copyright 1999 Wind River Systems, Inc
#
# modification history
# --------------------
# 02c,08mar02,bwd  Added instructions for Windows XP
# 02b,05mar02,bwd  Modified SETUP to be non-tornado centric
# 02a,12jun01,j_w  Modified for Tornado 2.2
# 01i,20oct00,j_w  Fixed instructions for settting LM_LICENSE_FILE variable
#                  for win2000
# 01h,18oct00,j_w  Added instructions for setting LM_LICENSE_FILE environment
#                  variable in win2000
# 01g,27sep00,bwd  Disabled HELP for this page
# 01f,05jun00,bwd  SPR 31565: removed the section that tells user to set the
#                  env variable using regedit for Windows
# 01e,25may00,wmd  Added strong warning for use of regedit.
# 01e,12may00,wmd  Fixed SPR 31201 some typos and reword some text.
# 01d,10may00,bwd  Fixed SPR 31031 - change exit message to be more for End
#                  User licensing
# 01c,06jan00,bwd  No test automation for command line SETUP
# 01b,30nov99,clc  add text mode
# 01a,29Oct99,wmd  written.
#

#############################################################################
#
# pageCreate(lmExit) - license exit page for end user or node locked license
#       installation
#
# This procedure will create a exit page to provide information to users
#       that are exiting license management setup prematurely.
#
# SYNOPSIS
# .tS
# pageCreate(lmExit)
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc pageCreate(lmExit) {} {
    global ctrlVals setupVals env 

    if { [isGUImode] } {
        set ctrlVals(volatileFrm) [list \
	        [list text -name exitText \
                       -readonly -vscroll -multiline\
	                   -x 100 -y 10 -w 200 -h 150] \
        ]

        set w [dlgFrmCreate [strTableGet LMEXIT_TITLE]]

        controlTextSet $w.exitText \
            "[strTableGet LMEXIT_MSG1]\r\n\r\n[strTableGet LMEXIT_MSG2]\
             \r\n\r\n[strTableGet LMEXIT_ENV_SET]"


        controlValuesSet $w.nextButt "Exit"
        controlEnable $w.backButt 1
        controlEnable $w.nextButt 1
        controlEnable $w.cancelButt 0
        controlEnable $w.helpButt 0

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
            autoSetupLog "LM Exit page:"
            autoSetupLog "\t[strTableGet LMEXIT_MSG1]"
            autoSetupLog "\t[strTableGet LMEXIT_MSG2]"
            autoSetupLog "\t[strTableGet LMEXIT_ENV_SET]"
            nextCallback
        }

    } else { 

        # text mode 

        printPageTitle [strTableGet LMEXIT_TITLE]       
        puts "[strTableGet LMEXIT_MSG1]\n"
        puts "[strTableGet LMEXIT_MSG2_TEXT]\n"
        puts "[strTableGet LMEXIT_ENV_SET]\n"

        set msg "Press <Enter> to exit SETUP or type `-` to backup."
        set ret [prompt $msg]

        while (1) {
            switch -regexp -- $ret {
                "^-$" { 
                    backCallback
                    return 0
                }
                default {
                    return 0
                }
            }
        }
    }
}

#############################################################################
#
# pageProcess(lmExit) - exits end user license management setup.
#
# This procedure will exit the Setup program without finishing LM configuration.
#
# SYNOPSIS
# .tS
# pageProcess(lmExit)
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: 1 when successful
#
# ERRORS: N/A
#

proc pageProcess(lmExit) {} {

    applicationExit
    return 1
}

global setupVals

# dummy values - for testing
set strTable(LMEXIT_TITLE) "License Management Exit"

set strTable(LMEXIT_MSG1) \
    "License Management configuration is not yet complete! \
     If you exit at this point you may not be able to run\
     your [getProdInfo name] tools."

set strTable(LMEXIT_MSG2) \
    "However if you choose to exit, you will be able to\
     complete license management installation when you first\
     run any [getProdInfo name] tool that is under license management.\
     Just follow the instructions when the License Management\
     Setup screens pop up."

set strTable(LMEXIT_MSG2_TEXT) \
	"However if you choose to exit, you will be able to\
     complete license management installation when you first\
     run any [getProdInfo name] tool that is under license management.\
     Just follow the instructions when the License Management\
     Setup begins."

set strTable(LMEXIT_ENV_SET) \
    "If you desire to configure license management manually,\
    Please follow these instructions:\r\n\r\n\An environment\
    variable, LM_LICENSE_FILE, needs to be set\
    to the name of the license server host. At this time, you\
    may not know the license server's\
    name. Please ask your system administrator for the server\
    name and set the environment variable to it.\r\n\r\n\The\
    format of LM_LICENSE_FILE is:\r\n\port@server\r\n\where:\
    \t\"port\" is the port which is set by your\r\n\
    \t system administrator. Port number can be left\r\n\
    \t blank if using the default port.\r\n\
    \t \"server\" is the license server name.\r\n\r\n\
    On Unix add the following line(s) to your startup script:\r\n\
    \tc shell: setenv LM_LICENSE_FILE port@server\r\n\r\n\
    \tsh, bash: LM_LICENSE_FILE=port@server\r\n\
    \t\ \ \ \ \ \ \ \ \ \ \ \ \ \ \ export LM_LICENSE_FILE\r\n\r\n\
    On Windows NT:\r\n\
    \tGo to Control Panel->System, click on the\r\n\
    \tEnvironment tab and in the edit box set\r\n\
    \tLM_LICENSE_FILE=port@server.\r\n\r\n\
	On Windows 2000/XP:\r\n\
	\t- Go to Control Panel->System\r\n\
    \t- Click on the Advanced tab\r\n\
    \t- Click on the Environment Variables button\r\n\
    \t- Under the System variables section,\r\n\
	\t  click on the \"New...\" button\r\n\
    \t- In the Variable Name edit box,\r\n\
	\t  type in LM_LICENSE_FILE\r\n\
    \t- In the Variable Value edit box,\r\n\
	\t  type in <port>@<server>.\r\n"
    
        
