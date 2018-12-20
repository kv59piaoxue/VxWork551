# ICONFNSH.TCL  - Setup procedures for implementing icon-finish wizard page
#
# Copyright 1999 Wind River Systems, Inc
#
# modification history
# --------------------
# 03c,05mar02,bwd  Modified SETUP to be non-tornado centric
# 03b,13sep01,bwd  SPR 27165: added & for exec explorer to avoid TCL hanging
# 03a,12jun01,j_w  Added for Tornado 2.2
# 02c,02feb00,bwd  Modified codes to log messages in autoSetupLog file and not
#                  display messageBox for test automation
# 02b,12nov99,bwd  Auto Setup: do not display product summary on explorer
# 02a,30Sep99,j_w  Modified for T3
# 01b,11aug99,j_w  Added messages
# 01a,26jan99,tcy  extracted from INSTW32.TCL.
#

#############################################################################
#
# pageCreate(iconFinish) - display the last finish page if user selects
#                          to install program groups only
#
# This procedure will display the last page if user selects to install program
# groups only and invoke post-installation procedures such as:
# - processing all commands in queue
# - processing INF files
# - creating folders and icons and opening up the folder
# - migrating registry values from T101 to T2 (currently not done)
#
# SYNOPSIS
# .tS
# pageCreate(iconFinish)
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc pageCreate(iconFinish) {} {
    global setupVals
    global ctrlVals
    global infVals

    windowShow $ctrlVals(mainWindow) 0
    set folderCreated 0

    set infVals(programGroupInstall) 1 
    set prod [string toupper [getProdInfo name]]
    searchAndProcessSection AddRegistry [cdFileNameGet [file join RESOURCE \
                                         INF $prod.INF]]
    
    if {![isUnix]} {
        # non-tornado product: program group install
        folderCreateLog [defGroupGet] $ctrlVals(admin)
        if { [lsearch $ctrlVals(folders) [defGroupGet]] != "-1" } {
            set folderCreated 1
        }

        searchAndProcessSection AddIcon [cdFileNameGet [file join \
                                              RESOURCE INF $prod.INF]]
    }
    set infVals(programGroupInstall) 0 
    queueExecute

    # add call to open up program group for windows only

    if {![isUnix]} {
        # display common program group
        set prgGrp [programPathGet 1]
        if {$prgGrp == "" || $ctrlVals(admin) != "1"} {
            # display user program group
            set prgGrp [programPathGet 0]
        }
        if {$prgGrp != ""} {
            set path [file join $prgGrp [defGroupGet]]
            set path [unixToDos $path]

            if { $folderCreated } {
                if { $ctrlVals(useInputScript) } {
                    autoSetupLog "Icons Summary Explorer Page: skipped"
                    autoSetupLog "[strTableGet ICONFINISH_LABEL]"
                } else {
                    messageBox -informationicon [strTableGet ICONFINISH_LABEL]
                    catch {exec explorer $path &} err
                }
            } else {
                if { $ctrlVals(useInputScript) } {
                    autoSetupLog "Failed to create a folder for $path"
                } else {
                    messageBox -informationicon \
                        "SETUP failed to create a folder for $path"
                }
            }
        }

        # source REGSAVE.TCL to migrate registry values from Tornado 1.0 to 2.0
        set regSaveTclFile [cdFileNameGet [file join RESOURCE TCL REGSAVE.TCL]]
        if [file exists $regSaveTclFile] {
           source $regSaveTclFile
        }
    }
    nextCallback
}


#############################################################################
#
# pageProcess(iconFinish) - process inputs from iconFinish page if any
#
# This procedure will process inputs from iconFinish page if any
#
# SYNOPSIS
# .tS
# pageProcess(iconFinish)
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: 1 when successful
#
# ERRORS: N/A
#

proc pageProcess(iconFinish) {} {
    return 1
}

######################################################################
# Dialog Text Messages
######################################################################

set strTable(ICONFINISH_LABEL) \
    "SETUP has completed installing the program folders and icons."
                    
