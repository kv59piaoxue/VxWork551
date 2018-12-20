# SUMMARY.TCL  - Setup procedures for implementing summary wizard page
#
# Copyright 1999-2003 Wind River Systems, Inc
#
# modification history
# --------------------
# 03i,29apr03,bjl  text rewording.
# 03h,18feb03,bjl  remove lmAutoManChoice instead of lmOptions if no licensed
#                  products.
# 03g,23may02,bwd  SPR 77578: created setup.log after installation is finished
# 03f,05jan02,bwd  Modified NOTE about running BSP CD
# 03e,04jan02,bwd  For core CD, remind user to run BSP CD if user has
#                  installed VxWorks
# 03d,21dec01,bwd  Don't open Windows Program Group folder for BSP
#                  installation
# 03c,13sep01,bwd  SPR 27165: added "&" for exec explorer to avoid TCL hanging
# 03b,15jun01,j_w  Display OK button at the end
# 03a,12jun01,j_w  Added for Tornado 2.2
# 02o,31oct00,bwd  SPR 35597: Add HELP button back
# 02n,24aug00,bwd  Increased the height of dialog box if there're errors from
#                  installation
# 02m,02jun00,bwd  SPR 31577: modified codes to use different dialog sizes
#                  depending on whether or not installation errors occur.
# 02l,30may00,j_w  Removed the finish button reference in text mode in 
#                  pageProcess
# 02k,19may00,j_w  Fixed SPR 31007 - do not remove tornado folder if
#                  non-licensed tornado product is installed
# 02j,10feb00,j_w  Rename Ok button to Finish if no licensed products are
#                  installed
# 02i,09feb00,j_w  Remove dbQuery page if no licensed product is installed
# 02h,04feb00,j_w  Rename finsih page to summary page
# 02g,01feb00,bwd  Deleted redundant codes
# 02f,11jan00,bwd  Removed test automations from command line SETUP
# 02e,06dec99,j_w  Delete setup.log.abort
# 02d,06dec99,j_w  Remove lmOptions page if no licensed products are installed
# 02d,23nov99,clc  add text mode
# 02c,12nov99,bwd  Corrected log message for auto setup
# 02b,11nov99,bwd  Auto setup: do not display product summary on explorer
# 02a,30Sep99,j_w  Modified for T3
# 01e,11aug99,j_w  Added messages
# 01d,27apr99,bjl  workaround to allow user to press Return to exit 
#                  on Unix (spr 27072).
# 01c,24mar99,tcy  moved code to open program folder here
# 01b,28jan99,tcy  moved system configuration code to SYSCONFG.TCL.
# 01a,26jan99,tcy  extracted from INSTW32.TCL.
#

#############################################################################
#
# pageCreate(summary) - display list of installed products
#
# This procedure will display list of installed products and serve as
# the summary wizard page
#
# SYNOPSIS
# .tS
# pageCreate(summary)
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc pageCreate(summary) {} {
    global ctrlVals
    global setupVals
    global tornadoInstalled
    global env

    exitMsgSet "[strTableGet SUMMARY_EXIT_MSG]"

    # Warn the user in case of error during the setup

    if {[errorCountGet] > 0} {
        exitMsgSet "[exitMsgGet]  [strTableGet SUMMARY_WARN]"
        set HIGH1 40
        set HIGH2 120
        set YPOS 50
    } else {
        set HIGH1 15
        set HIGH2 145
        set YPOS 25
    }

    set vxworksSelected 0

    if { [isGUImode] } {

        set title ""
        if [info exists setupVals(confirmation)] {
            foreach product $setupVals(confirmation) {
               append title [format "%s\r\n" $product]
               if { [regexp {^VxWorks: .+} $product] } {
                   set vxworksSelected 1
               }
            }
        }
        if { $vxworksSelected } {
            append title [strTableGet SUMMARY_BSP_CD_REMINDER]
        }
        set ctrlVals(volatileFrm) [list \
                [list label -name summaryText \
                            -title [exitMsgGet]\
                            -x 100 -y 10 -w 206 -h $HIGH1] \
                [list text -name productList -border -vscroll \
                           -multiline -readonly \
                           -x 100 -y $YPOS -width 206 -height $HIGH2] ]

        set w [dlgFrmCreate [strTableGet SUMMARY_TITLE]]

        controlTextSet $w.productList $title

        controlValuesSet $w.nextButt "OK"
        controlEnable $w.backButt 0
        controlEnable $w.nextButt 1
        controlEnable $w.cancelButt 0
        controlHide $w.helpButt 0
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
    } else { # TEXT MODE

        printPageTitle [strTableGet SUMMARY_TITLE]
        puts [exitMsgGet]

        if [info exists setupVals(confirmation)] {
            foreach product $setupVals(confirmation) {
               puts [format "%s\r\n" $product]
               if { [regexp {^VxWorks: .+} $product] } {
                   set vxworksSelected 1
               }
            }
        }
        if { $vxworksSelected } {
            puts [strTableGet SUMMARY_BSP_CD_REMINDER]
        }
    }

    # No licensed products are installed -- make this the final page
    if { $setupVals(licensedProdInstalled) == 0 } {
        pageRemove "lmAutoManChoice"
    }

    if { [isGUImode] } {
        # test automation

        if { $ctrlVals(useInputScript) } {
            autoSetupLog "Summary page:"
            autoSetupLog "\t[exitMsgGet]"
            nextCallback
        }
    } else { # TEXT mode
        nextCallback
        return 0
    }
}

#############################################################################
#
# pageProcess(summary) - process inputs from summary page if any
#
# This procedure will process inputs from SUMMARY page if any
#
# SYNOPSIS
# .tS
# pageProcess(summary)
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: 1 when successful
#
# ERRORS: N/A
#

proc pageProcess(summary) {} {

    global ctrlVals setupVals

    # add call to open up program group for windows only

    if {![isUnix]} {
        # display common program group

        set prgGrp [programPathGet 1]
        if {$prgGrp == "" || $ctrlVals(admin) != "1"} {
            # display common user group

            set prgGrp [programPathGet 0]
        }
        if {$prgGrp != ""} {
            set path [file join $prgGrp [defGroupGet]]
            set path [unixToDos $path]

            if { $ctrlVals(useInputScript) } { 
                autoSetupLog "Icons Summary Explorer Page: skipped"
            } elseif { [isBSPcd] } {
                #don't display folder for BSP installation
            } else {
                catch {exec explorer $path &} err
            }
        }
    }

    # remove setup.log.abort

    catch {file delete [destDirGet]/setup.log.abort}

    # installation completed - create setup.log then
    set tmpLog [file join [tempDirGet] setup.log.tmp]
    fileAppend $tmpLog [file join [destDirGet] setup.log]

    # delete and recreate setup.log.tmp to empty out contents
    catch { close $setupVals(fSetupLog) } err
    catch { file delete -force $tmpLog } err
    set setupVals(fSetupLog) \
          [open [file join [tempDirGet] setup.log.tmp] "w"]

    return 1
}

######################################################################
# Dialog Text Messages
######################################################################

set strTable(SUMMARY_TITLE) "Summary"

set strTable(SUMMARY_WARN) \
    "format %s \"However, there were \[errorCountGet\] error(s)\
    which occured during the process.  Please review the log file\
    \[destDirDispGet\]/setup.log for more information.\""

set strTable(SUMMARY_EXIT_MSG) \
    "format %s \"SETUP has installed the following product(s):\""

set strTable(SUMMARY_BSP_CD_REMINDER) \
    "\r\nWARNING: You have installed the core elements of VxWorks,\
     but your target software installation will not be complete until\
     you have installed the appropriate BSPs and drivers from the\
     companion \"BSPs/Drivers\" CD."
