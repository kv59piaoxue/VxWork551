# README.TCL - Setup procedures for implementing readme wizard page
#
# Copyright 1999-2003 Wind River Systems, Inc
#
# modification history
# --------------------
# 03c,29apr03,bjl  text rewording.
# 03b,05mar02,bwd  Modified SETUP to be non-tornado centric
# 03a,12jun01,j_w  Modified for Tornado 2.2
# 02i,25jul00,wmd  Fix spr 32983, remove mention of Release Notes being copied
#                  to user's tree.
# 02h,24jan00,bwd  Changed setupVals(cmdMode) to use "isGUImode"
# 02g,17dec99,clc  change  switch patterns
# 02f,03dec99,j_w  Disable the help button
# 02e,16nov99,clc  change text mode variable to setupVals(cmdMode)
# 02d,07nov99,clc  edit text mode exit
# 02c,21oct99,clc  change text mode variable to instTypeGet
# 02b,07oct99,clc  add text mode
# 02a,30Sep99,j_w  Modified for T3
# 01c,21jul99,j_w  added text messages
# 01b,26apr99,bjl  removed icon for Unix to aid refresh problem.
# 01a,26jan99,tcy  extracted from INSTW32.TCL.
#

#############################################################################
#
# pageCreate(readme) - display the readme.txt file
#
# This procedure will display the readme.txt file
#
# SYNOPSIS
# .tS
# pageCreate(readme)
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A

proc pageCreate(readme) {} {
    global ctrlVals
    global setupVals

    if { [isGUImode] } {
        if {[isUnix]} {
           set labelx 10
           set labelw 286
        } else {
           set labelx 90
           set labelw 206
        }

        controlHide $ctrlVals(mainWindow).bitmap 1
        set ctrlVals(volatileFrm) [list \
                    [list bitmap -name bmp -stretch -title \
                                 "[cdFileNameGet \
                                 [file join RESOURCE BITMAPS SETUPICO.BMP]]"\
                                 -x 20 -y 9 -w 36 -h 36] \
                    [list label -name readmeLabel \
                                -title [strTableGet README_TEXT] \
                                -x $labelx -y 10 -w $labelw -h 40] \
                    [list text -name readmeFile -border -vscroll \
                                -multiline -readonly \
                                -x 10 -y 52 -width 295 -height 119] \
        ]

        if {[isUnix]} {
            # remove the setup icon, it has a different color palette and may
            # appear incorrectly
            set ctrlVals(volatileFrm) [lrange $ctrlVals(volatileFrm) 1 \
                [expr [llength $$ctrlVals(volatileFrm)] - 1] ]
        }

        set w [dlgFrmCreate [strTableGet README_TITLE]]

        # initialize the text box

        controlTextSet $w.readmeFile \
                                [fileContentGet [cdFileNameGet README.TXT]]

        controlEnable $w.helpButt 0

        controlEnable $ctrlVals(mainWindow).nextButt 1
        controlFocusSet $ctrlVals(mainWindow).nextButt

    } else { # TEXT mode
        printPageTitle [strTableGet README_TITLE]
        puts "[strTableGet README_TEXT]\n"
        puts "[fileContentGet [cdFileNameGet README.TXT]]"

        while {1} {
            switch -regexp -- [prompt [strTableGet 3000_RETURN_QUESTION]] {
                "^-$"   { backCallback; return 0 }
                "^$"    { nextCallback; return 0 }
                "[eE][xX][iI][tT]"  { return 0 }
                default { }
            }
        }
    }
}

#############################################################################
#
# pageProcess(readme) - process inputs from the readme page
#
# This procedure will process inputs from the readme page
#
# SYNOPSIS
# .tS
# pageProcess(readme)
# .tE
#
# PARAMETERS: N/A
#
# RETURNS:  1 if successful
#
# ERRORS: N/A
#

proc pageProcess(readme) {} {
    global ctrlVals
    global setupVals

    if { [isGUImode] } {
        controlHide $ctrlVals(mainWindow).bitmap 0
    }
    return 1
}

######################################################################
# Dialog Text Messages
######################################################################

set strTable(README_TITLE) "README.TXT"

set strTable(README_TEXT) \
    "Please read the contents of the README.TXT file displayed below.\
     It contains important information that will enable you to successfully\
     install and run the [getProdInfo name] product.  The file is copied\
     to the directory that you will choose for product installation."

