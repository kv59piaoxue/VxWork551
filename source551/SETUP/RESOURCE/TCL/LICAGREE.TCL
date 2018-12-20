# LICAGREE.TCL  - Setup procedures for implementing license-agreement
#                 wizard page
#
# Copyright 1999-2003 Wind River Systems, Inc
#
# modification history
# --------------------
# 02p,29apr03,bjl  text rewording.
# 02o,17may02,wmd  Fix text format.
# 02n,15may02,wmd  Change "I accept" to "Accept".
# 02m,15dec00,wmd  Correct grammatical and punctuation errors in pages.
# 02l,02nov00,j_w  Fixed problems in reading LICENSE.TXT
# 02k,07feb00,j_w  Disable the HELP button
# 02j,07feb00,bwd  Catch error when opening LICENSE.TXT and log errors for
#                  test automation
# 02i,24jan00,bwd  Changed setupVals(cmdMode) to use "isGUImode"
# 02h,07jan00,bwd  Deleted test automation for command line SETUP
# 02g,17dec99,clc  edit switch statement for textmode
# 02f,09dec99,clc  change exit for text mode
# 02e,16nov99,clc  change textmode variable to setupVals(cmdMode)
# 02d,07nov99,clc  edit text mode exit
# 02c,21oct99,clc  change text mode variable to instTypeGet
# 02b,12oct99,clc  add command-line
# 02a,30Sep99,j_w  Modified for T3
# 01d,21jul99,j_w  added text messages
# 01c,09apr99,wmd  Jason Anderson will take care of manufacturing the CD with
#                  the correct LICENSE.TXT.  Setup will just read it without
#                  having to determine which file to use.
# 01b,06apr99,wmd  Need to determine if source or Tornado CD.
# 01a,26jan99,tcy  extracted from INSTW32.TCL.
#

#############################################################################
#
# onAcceptButt - set up the wizard buttons after accept button is pushed
#
# This procedure will set up the wizard buttons after accept button is pushed
#
# SYNOPSIS
# .tS
# onAcceptButt
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc onAcceptButt {} {
    global ctrlVals
    global setupVals

    if { [isGUImode] } {
        controlEnable $ctrlVals(mainWindow).nextButt 1
        controlEnable $ctrlVals(mainWindow).acceptButt 0
        controlFocusSet $ctrlVals(mainWindow).nextButt
    }
}

#############################################################################
#
# pageCreate(licAgreement) - display the license agreement file
#
# This procedure will display the license agreement file
#
# SYNOPSIS
# .tS
# pageCreate(licAgreement)
# .tE
#
# PARAMETERS: N/A
        #
# RETURNS: N/A
#
# ERRORS: N/A
#

proc pageCreate(licAgreement) {} {
    global ctrlVals
    global setupVals

    if { [isGUImode] } {
        set ctrlVals(volatileFrm) [list \
                    [list label -name message1 \
                                -title [strTableGet LICAGREEMENT_TEXT ] \
                                -x 99 -y 10 -w 206 -h 35] \
                    [list button -name acceptButt \
                                -title "&Accept" \
                                -callback onAcceptButt \
                                -x 255 -y 45 -w 50 -h 13] \
                    [list text -name licenseFile -border -vscroll \
                                -multiline -readonly \
                                -x 100 -y 60 -width 206 -height 111] \
        ]

        set w [dlgFrmCreate [strTableGet LICAGREEMENT_TITLE]]
        controlFocusSet $w.acceptButt

        # initialize the text box

        controlTextSet $w.licenseFile \
            [fileContentGet [cdFileNameGet LICENSE.TXT]]
        
        controlEnable $w.nextButt 0
        controlEnable $w.helpButt 0

        # test automation

        if { $ctrlVals(useInputScript) } {
            autoSetupLog "License Agreement page: Accepted and skipped"
            onAcceptButt
            nextCallback
        }
    } else {
        printPageTitle [strTableGet LICAGREEMENT_TITLE]
        puts "[fileContentGet [cdFileNameGet LICENSE.TXT]]"

        while (1) {
            puts "[strTableGet LICAGREEMENT_ACCEPT]"
            set ret [prompt]
            switch -regexp -- $ret {
                "^-$"           { backCallback; return 0 }
                "[iI] [aA][cC][cC][eE][pP][tT]" {
                     nextCallback 
                     return 0 
                }
                "[eE][xX][iI][tT]"          { return 0 }
                default         { }
            }
        }
    }
}

#############################################################################
#
# pageProcess(licAgreement) - process inputs from licAgreement page if any
#
# This procedure will process inputs from licAgreement page if any
#
# SYNOPSIS
# .tS
# pageProcess(licAgreement)
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: 1 when successful
#
# ERRORS: N/A
#

proc pageProcess(licAgreement) {} {
    return 1
}

######################################################################
# Dialog Text Messages
######################################################################

set strTable(LICAGREEMENT_TITLE) "License Agreement"

set strTable(LICAGREEMENT_TEXT) \
    "Please read the license agreement displayed below. If you agree\
     to the terms of the agreement, click Accept and then Next.\
     Otherwise, click Cancel and exit the SETUP program."

set strTable(LICAGREEMENT_ACCEPT) \
    "To consent to be bound by the terms of this agreement type \'I\
    accept\' and press <Return> to continue.  If you do not agree to\
    all of the terms, type 'exit' and press <Return> and do not\
    install this software."
