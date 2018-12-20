# FOLDER.TCL  - Setup procedures for implementing folder wizard page
#
# Copyright 1999-2003 Wind River Systems, Inc
#
# modification history
# --------------------
# 03g,29apr03,bjl  text rewording.
# 03f,08oct02,bjl  force folder name only if tornado itself is installed.
# 03e,11jul02,wmd  Force the folder name to be tornado 2.2 by default.
# 03d,23may02,bwd  SPR 77766: allow optional tornado products CD to read
#                  folder value from registries
# 03c,05mar02,bwd  Modified SETUP to be non-tornado centric
# 03b,15jun01,j_w  remove remoteRegistryHost compatibility and howTo pages 
#                  if selected product is not tornado or windview
# 03a,12jun01,j_w  Modified for Tornado 2.2
# 02k,04dec00,bwd  SPR 62727: trim any white spaces before the folder name
# 02j,08feb00,bwd  Fixed codes to disable Next button until the field is
#                  entered
# 02i,02feb00,bwd  Fixed error handling for test automation
# 02h,19jan00,j_w  Remove remoteRegistryHost reference
# 02g,10jan00,bwd  Deleted test automation sections from command line SETUP
# 02f,09nov99,clc  add text mode
# 02e,20oct99,j_w  Removed compatibility and howTo pageRemove call
# 02d,19oct99,bjl  replaced tornado productName check with tornadoProductCheck.
# 02c,18oct99,j_w  Fixed portMapperIconExist
# 02b,12oct99,j_w  Used setupVals(defGroup) as the default folder
# 02a,30Sep99,j_w  Modified for T3
# 01g,23jul99,j_w  added text messages
# 01f,24mar99,bjl  turn off inf write to registry after queueExecute.
# 01e,22mar99,bjl  remove backward compatibility pages if tornado not
#                  installed.
# 01d,19mar99,wmd  Output to a file any debug messages.
# 01c,01feb99,tcy  prevent user from installing T2 into T101 folder
# 01b,27jan99,tcy  changed default folder name to "Tornado2"
# 01a,26jan99,tcy  extracted from INSTW32.TCL.
#

#############################################################################
#
# pageCreate(folderSelect) - display existing folders for Tornado installation
#                            and prompt for Tornado folder name
#
# This procedure will display existing folders for Tornado installation
# and prompt for Tornado folder name
#
# SYNOPSIS
# .tS
# pageCreate(folderSelect)
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc pageCreate(folderSelect) {} {
    global ctrlVals
    global setupVals

    if { [isGUImode] } {
        set ctrlVals(volatileFrm) [list \
                    [list label -name msg1 \
                                -title [strTableGet FOLDERSELECT_MSG_1]\
                                -x 100 -y 10 -w 205 -h 27] \
                    [list label -name msg2 -title "&Program Folder:" \
                                -x 100 -y 43 -w 85 -h 10] \
                    [list text -name folderName -border \
                               -callback onFolderName \
                               -x 100 -y 53 -w 205 -h 12] \
                    [list label -name msg3 -title "E&xisting Folders:" \
                                -x 100 -y 73 -w 85 -h 10] \
                    [list list -name folderList \
                               -callback onFolderSelect \
                               -x 100 -y 83 -w 205 -h 87] \
        ]

        set w [dlgFrmCreate [strTableGet FOLDERSELECT_TITLE]]

        # get folder name from registry - trim off white spaces

	if { [info exists tornadoInstalled] && $tornadoInstalled } {
            controlValuesSet $w.folderName $setupVals(defGroup) 
        } else {
            controlValuesSet $w.folderName [string trim [folderValueReadFromRegistry]]
        }
        controlValuesSet $w.folderList $ctrlVals(folders)
        controlFocusSet $w.folderName

        # test automation

        if { $ctrlVals(useInputScript) } {
            controlValuesSet $w.folderName [string trim $setupVals(folder)]
            autoSetupLog "Folder Selection page:"
            autoSetupLog "\tSelected folder: $setupVals(folder)"
            nextCallback
        }
    } else { 
        
        # TEXT mode

        nextCallback
        return 0
    }
}

#############################################################################
#
# pageProcess(folderSelect) - process inputs from folderSelect page
#
# This procedure will process inputs from folderSelect page
#
# SYNOPSIS
# .tS
# pageProcess(folderSelect)
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: 0 if folder name contains spaces
#          1 if folder name does not contain spaces
#
# ERRORS: N/A
#

proc pageProcess(folderSelect) {} {
    global ctrlVals
    global setupVals
    global tornadoInstalled
    global infVals

    if { [isGUImode] } {
        set retVal 0
        if {[instTypeGet] != "icon"} {
            foreach prodIndex [cdInfoGet selectedProdIndexList] {
                set productName [productInfoGet name $prodIndex]
                set productDesc [productInfoGet desc $prodIndex]
                if {[tornadoProductCheck $productName $productDesc]} {
                    set tornadoInstalled 1
                }
            }
        }

        if { ![info exists tornadoInstalled] || !$tornadoInstalled } {
            pageRemove torRegistry
            pageRemove remoteRegistryHost
            pageRemove compatibility
            pageRemove howTo
            pageRemove appConfig
        }
 
        defGroupSet [string trim [controlValuesGet $ctrlVals(mainWindow).folderName]]

        if {[regexp {^[ ]*$} [defGroupGet] junk]} {
            if { $ctrlVals(useInputScript) } {
                autoSetupLog "Error: Invalid folder name: $setupVals(folder)" 
                autoSetupLog "Application Exit\n"
                set setupVals(cancel) 1                
                applicationExit
                return 0
            } else {
                messageBox [strTableGet FOLDERSELECT_MSG_2]
                set retVal 0
            }
        } else {
            set retVal 1
        }

        if { [isTornadoProduct] } {
            if {[portMapperIconExist \
                [string trim [controlValuesGet $ctrlVals(mainWindow).folderName]]] == 1} {
                if { $ctrlVals(useInputScript) } {
                    autoSetupLog "Error: [strTableGet FOLDERSELECT_MSG_3]"
                    autoSetupLog "Application Exit\n"
                    set setupVals(cancel) 1                
                    applicationExit
                    return 0
                } else {
                    messageBox [strTableGet FOLDERSELECT_MSG_3]
                    set retVal 0
                }
            } else {
                set retVal 1
            }
        }

        if { [isTornadoProduct] } {  set infVals(addFolder) 1  }
        set prod [string toupper [getProdInfo name]]
        searchAndProcessSection AddRegistry [cdFileNameGet [file join RESOURCE \
                                             INF $prod.INF]]
        queueExecute
        if { [isTornadoProduct] } {  set infVals(addFolder) 0  }
        return $retVal

    } else { # TEXT mode

        if { [isTornadoProduct] } {  set infVals(addFolder) 1  }
        set prod [string toupper [getProdInfo name]]
        searchAndProcessSection AddRegistry [cdFileNameGet [file join RESOURCE \
                                             INF $prod.INF]]
        queueExecute
        if { [isTornadoProduct] } {  set infVals(addFolder) 0  }

        return 1
    }
        
}

#############################################################################
#
# onFolderName - set the default folder name when text is changed
#
# This procedure will set the default folder name when text is changed
#
# SYNOPSIS
# .tS
# onFolderName
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc onFolderName {} {
    global ctrlVals
    global setupVals

    set Fname [string trim [controlValuesGet $ctrlVals(mainWindow).folderName]]

    if { $Fname == "" } {
        controlEnable $ctrlVals(mainWindow).nextButt 0
    } else {
        controlEnable $ctrlVals(mainWindow).nextButt 1
        defGroupSet $Fname
    }
}

#############################################################################
#
# onFolderSelect - set the value in edit box when a folder name is selected
#                  from the folder list
#
# This procedure will set the value in edit box when a folder name is selected
# from the folder list
#
# SYNOPSIS
# .tS
# onFolderSelect
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc onFolderSelect {} {
    global ctrlVals

    controlValuesSet $ctrlVals(mainWindow).folderName \
        [string trim [controlSelectionGet $ctrlVals(mainWindow).folderList -string]]
}

#############################################################################
#
# folderValueReadFromRegistry - read folder value from the Windows registry
#
# This procedure will read folder value from the Windows registry
#
# SYNOPSIS
# .tS
# folderValueReadFromRegistry
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc folderValueReadFromRegistry {} {
    global setupVals

    # Load folder from the previous installation if any

    if {"[defGroupGet]" == ""} {

        if { ![isStandAlone] && ![isWRSStandAlone] } {

            if {![catch {sysRegistryValueRead HKEY_CURRENT_USER \
                         "Software\\$setupVals(WRS)" "folder"} folder]} {
                defGroupSet $folder
            } else {
                defGroupSet $setupVals(defGroup)
            }
        } else {
            # non-tornado product: use the product name defined in CONFIG.TCL
            defGroupSet $setupVals(defGroup)
        }
    }

    return [defGroupGet]
}

#############################################################################
#
# portMapperIconExist - determine if the given folder contains portMapper icon
#
# This procedure will determine if the given folder contains portMapper icon
#
# SYNOPSIS
# .tS
# portMapperIconExist
# .tE
#
# PARAMETERS:
# <folder>
# program folder name
#
# RETURNS: 1 if portmapper exists
#          0 if portmapper does not exist
#
# ERRORS: N/A
#

proc portMapperIconExist {folder} {

    # look for portmapper icon to determine if the last
    # installation is of T101

    if ![catch {programPathGet 0} error] {
        set commonProgramPath [programPathGet 0]
    } else {
        dbgputs "$error"
    }
    if ![catch {programPathGet 0} error] {
        set userProgramPath [programPathGet 1]
    } else {
        dbgputs "$error"
    }

    if {[file exists "$commonProgramPath\\$folder\\Portmapper.lnk"] ||\
        [file exists "$userProgramPath\\$folder\\Portmapper.lnk"]} {
        return 1
    } else {
        return 0
    }
}

######################################################################
# Dialog Text Messages
######################################################################

set strTable(FOLDERSELECT_TITLE) "Select Folder"

set strTable(FOLDERSELECT_MSG_1) \
        "SETUP will add entries to the Windows Program folder you\
         select below. You may enter a new folder name, or select\
         from the list of existing folders."

set strTable(FOLDERSELECT_MSG_2) \
        "Please enter a valid folder name."

set strTable(FOLDERSELECT_MSG_3) \
        "Setup has detected that the folder name you selected\
        contains icons belonging to previous version of [getProdInfo name].\
        Please select another folder name."

