# WELCOME.TCL - Setup procedures for implementing welcome wizard page
#
# Copyright 1999-2003 Wind River Systems, Inc
#
# modification history
# --------------------
# 03c,29apr03,bjl  text rewording.
# 03b,17may02,wmd  Make text formatting, grammar changes recommended by tech
#                  pubs.
# 03a,12jun01,j_w  Modified for Tornado 2.2
# 02m,07may01,j_w  Update text messages
# 02l,15dec00,wmd  Fix typos.
# 02k,15dec00,wmd  Correct grammatical and punctuation errors in pages.
# 02j,05dec00,wmd  Fix "Back >" to say "< Back".
# 02i,10mar00,j_w  Fixed wording. Removed unused messages
# 02h,24jan00,bwd  Changed codes to use new proc "isGUImode" and deleted
#                  redundant codes
# 02g,17dec99,clc  change  switch patterns
# 02f,03dec99,j_w  Disable help button
# 02e,24nov99,bwd  Modified message displayed in autoSetupLog
# 02d,16nov99,clc  change text mode variable to setupVals(cmdMode)
# 02c,21oct99,clc  change text mode variable to instType
# 02b,07oct99,clc  adding text mode
# 02a,30Sep99,j_w  Modified for T3
# 01e,21jul99,j_w  added text messages
# 01d,26apr99,bjl  removed icon for Unix to aid refresh problem.
# 01c,22mar99,wmd  Rename file from .CD_STATUS to CD_STATUS.
# 01b,19mar99,wmd  Add debug code to warn user that CD may have defects.
# 01a,26jan99,tcy  extracted from INSTW32.TCL.
#

#############################################################################
#
# pageCreate(welcome) - displays CD title, welcome and warning statements
#
# This procedure will display CD title, welcome and warning statements
#
# SYNOPSIS
# .tS
# pageCreate(welcome)
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc pageCreate(welcome) {} {
    global ctrlVals
    global setupVals

    # chop off the string if it is too long

    if {[string length $setupVals(CDdescription)] > 45} {
        set cdTitle [cdromDescGet]
    } else {
        set cdTitle [strTableGet WELCOME_CD_DESC]
    }

    if { [isGUImode] } {
        if {[isUnix]} {
            # move the first welcome messages to the left since
            # the icon is removed.

            set topmsgx 101
            set msg1w 204
        } else {
            set topmsgx 135
            set msg1w 169
        }

        if {[isUnix]} {
            # do not display message about exiting all programs.

            set ctrlVals(volatileFrm) [list \
                        [list bitmap -name bmp -stretch -title \
                                    [cdFileNameGet \
                                    [file join RESOURCE BITMAPS SETUPICO.BMP]] \
                                    -x 101 -y 10 -w 24 -h 24] \
                        [list label -name msg0 \
                                    -title $cdTitle\
                                    -x $topmsgx -y 10 -w 173 -h 8] \
                        [list label -name msg1 \
                                    -title [strTableGet WELCOME_P1]\
                                    -x $topmsgx -y 20 -w $msg1w -h 18] \
                        [list label -name msg3 \
                                    -title [strTableGet WELCOME_P3]\
                                    -x 101 -y 49 -w 204 -h 40] \
                        [list label -name msg4 \
                                    -title [strTableGet WELCOME_P4]\
                                    -x 100 -y 95 -w 205 -h 62]
            ]
        } else {
            set ctrlVals(volatileFrm) [list \
                        [list bitmap -name bmp -stretch -title \
                                    [cdFileNameGet \
                                    [file join RESOURCE BITMAPS SETUPICO.BMP]] \
                                    -x 101 -y 10 -w 24 -h 24] \
                        [list label -name msg0 \
                                    -title $cdTitle\
                                    -x $topmsgx -y 10 -w 173 -h 8] \
                        [list label -name msg1 \
                                    -title [strTableGet WELCOME_P1]\
                                    -x $topmsgx -y 20 -w $msg1w -h 18] \
                        [list label -name msg2 \
                                    -title [strTableGet WELCOME_P2]\
                                    -x 101 -y 40 -w 204 -h 24] \
                        [list label -name msg3 \
                                    -title [strTableGet WELCOME_P3]\
                                    -x 101 -y 69 -w 204 -h 40] \
                        [list label -name msg4 \
                                    -title [strTableGet WELCOME_P4]\
                                    -x 100 -y 119 -w 205 -h 50]
            ]
        }

        if {[isUnix]} {
            # remove the setup icon, it has a different color palette and may
            # appear incorrectly.  In the latest version of UITclSh it also
            # appears to contribute to an overlapping window refresh problem.

            set ctrlVals(volatileFrm) [lrange $ctrlVals(volatileFrm) 1 \
                                [expr [llength $$ctrlVals(volatileFrm)] - 1]]
        }

        set w [dlgFrmCreate [strTableGet WELCOME_TITLE]]

        # Disable the Help and Back button since this is the first page

        controlEnable $w.helpButt 0
        controlEnable $w.backButt 0
        controlEnable $w.nextButt 1
        controlFocusSet $w.nextButt
        controlPropertySet $w.msg0 -bold 1

        if {![isUnix]} {
            controlPropertySet $w.msg2 -bold 1
        }

        controlHide $ctrlVals(mainWindow).bitmap 0

        # test automation

        if { $ctrlVals(useInputScript) } {
            autoSetupLog "Welcome page: Skipped"
            pageRemove readme
            nextCallback
        }

    } else { # TEXT mode
        printPageTitle [strTableGet WELCOME_TITLE]
        puts "[strTableGet WELCOME_P1]\n"
        puts "[strTableGet WELCOME_P2]\n"
        puts "[strTableGet 3020_WELCOME3]\n"
        puts "[strTableGet WELCOME_P4]\n"
        puts "[strTableGet WELCOME_P5]\n"

        while (1) {
            switch -regexp -- [prompt [strTableGet 3000_RETURN_QUESTION]] {
                "^-$"   { return 0 }
                "^$"    { nextCallback; return 0 }
                "[eE][xX][iI][tT]"  { return 0 }
                default { }
            }
        }
    }
}

#############################################################################
#
# pageProcess(welcome) - process inputs from welcome wizard page
#
# This procedure will process inputs from welcome wizard page
#
# SYNOPSIS
# .tS
# pageProcess(welcome)
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: 1 if successful
#
# ERRORS: N/A
#

proc pageProcess(welcome) {} {
    global ctrlVals
    global setupVals

    if {[debug]} {
        if {![catch {open [cdromRootDirGet]/CD_STATUS "r"} fd]} {
            gets $fd cdStatus
            close $fd
            if {[string compare $cdStatus "SUCCESS"] != 0} {
                if { [isGUImode] } {
                    if { $ctrlVals(useInputScript) } {
                        autoSetupLog "Warning: This CD may contain zero-length\
                                      files, or may be missing files!"
                    } else {
                        messageBox -ok -exclamationicon \
                                   "This CD may contain zero-length \
                                    files, or may be missing files!"
                    }
                } else { # TEXT mode
                    puts "Warning: This CD may contain zero-length files,\
                          or may be missing files!"

                    while {[prompt "Press <Enter> to continue."] != "" } {
                    }
                } 
            }
        }
    }

    if { [isGUImode] } {
        controlEnable $ctrlVals(mainWindow).backButt 1
    }
    return 1
}

######################################################################
# Dialog Text Messages
######################################################################

set strTable(WELCOME_TITLE) "Welcome"

set strTable(WELCOME_CD_DESC) \
    "format %s \"[cdNameGet description]\""

set strTable(WELCOME_P1) \
    "format %s \"Welcome to the SETUP program.  This program will\
                 install \[cdromDescGet\] on your computer.\""

set strTable(WELCOME_P2) \
    "It is strongly recommended that you exit all programs and disable\
    any virus scanning program before running this SETUP program."

set strTable(WELCOME_P3) \
    "At any time, you can quit the SETUP program by clicking the Cancel\
     button. You also can go back to previous dialog boxes by clicking the\
     Back button. To accept the current settings for a dialog box\
     and proceed with the installation process, click the Next button."

set strTable(WELCOME_P4) \
    "WARNING: This program is protected by copyright law and international\
     treaties. Unauthorized reproduction or distribution of this program,\
     or any portion of it, may result in severe civil and criminal penalties,\
     and will be prosecuted to the maximum extent possible under law."

set strTable(3020_WELCOME3) \
    "format %s \"At any prompt, you can cancel installation \[cdromDescGet\]\
                 by typing \'exit\'.  You can also go to the previous question\
                 by typing \'-\'.  To accept current settings and go on with\
                 the installation process, press <Return>.\""

