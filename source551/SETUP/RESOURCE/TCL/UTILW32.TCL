# UTILW32.TCL - Utility functions for win32 installation
#
# Copyright 1996-2003 Wind River Systems, Inc.
#
# modification history
# --------------------
# 04s,08oct03,s_l  Revert DB host setting to real test DB.
# 04r,22sep03,s_l  Need to uncoment the port line.
# 04q,05sep03,s_l  Rever change to the port var done earlier.
# 04p,02sep03,s_l  Temporarly change to the host nad port settings.
# 04o,29apr03,bjl  modified help callback to always open top of help file.  
# 04n,27jan03,wmd  Modify to use licInfoGetAll2 for ALI.
# 04m,16jan03,wmd  Fix SPR #85761, better error message than Unknown database
#                  error.
# 04l,03oct02,bjl  fixed uninstall icon link to use core product name rather
#                  than cdromDesc (spr 77983).  
# 04k,31jul02,wmd  Modify LM error return strings for clarity.
# 04j,23may02,bwd  SPR 77766: remove setup.log.abort after LM configuration
#                  finish
# 04i,23may02,bwd  SPR 77766: allow optional tornado products CD to read dest
#                  dir value from registries
# 04h,17may02,j_w  Fixed parsing of tgsg.hm
# 04g,01may02,j_w  Add yesnocancel option in messageBox; Fixed SPR 76685:
#                  translate error code into meaningful message
# 04f,30apr02,wmd  Fix spr 76136 - remove fade from slideshow.
# 04e,05mar02,bwd  Modified SETUP to be non-tornado centric
# 04d,22jan02,bwd  Skip adding Uninstall icon for BSP CD
# 04c,03jan02,bwd  Added proceed-cancel dialog
# 04b,26oct01,bwd  Removed old windows 95/98 system check.
#                  SPR 70033: modified dialog file_exists_older_warn
# 04a,12jun01,j_w  Modified for Tornado 2.2
# 03y,02may01,j_w  No need to resend licFileConfig request due to 
#                  duplicate hostId (Vol. Serial).
# 03x,13mar01,j_w  update version 3.0 to 3.1
# 03w,17jan01,bwd  SPR 63555: added \\ at the end of CD_ROOT to prevent
#                  invalid path name
# 03v,22nov00,bwd  SPR 62562: modified quitCallback to display different
#                  cancel message for LM Installation path
# 03u,07nov00,wmd  Fix dialog re_ig_cancel as part of spr #35911..
# 03t,07nov00,wmd  Fix XPR #35574, SETUP failed to work with FVWM on Linux.
# 03s,02nov00,j_w  Name change - Tornado AE
# 03r,25oct00,j_w  Fixed typo
# 03q,19oct00,wmd  Correct error messages.
# 03p,19oct00,j_w  Added new ALI error types -- 11, 48, 51, 53
# 03o,10oct00,bwd  SPR 34462: also use ethernet card serial number for hostID
#                  when encountering error code *4045 in sendToALD
# 03n,04oct00,bwd  SPR 34732: messageBox arg passing
# 03m,29sep00,bwd  Add check if LMHelpPath exists before using it
# 03l,20sep00,bwd  Modified HELP on Windows to use default internet browser.
#                  Modified helpCallback to recognize duplicate pages and 
#                  to choose the right help IDs set
# 03k,20sep00,j_w  Fixed linkCreateLog and setupLinkCreateLog
# 03k,20sep00,bwd  Added codes to read in a file with all the anchors for HELP
#                  pages to display correct HELP page for each SETUP page.
# 03j,15sep00,bwd  SPR 34462: use ethernet card serial number for hostID when
#                  encountering error code *4041 in sendToALD
# 03i,11Sep00,j_w  Updated ALD error code and error messages. Removed "?" icon
#                  in dlgFrmCreate and other dialogs. Added messageBox() 
#                  procedure
# 03i,24aug00,bwd  SPR 32263: add string trim to remove possible extra semi
#                  colons at the end of the paths for internet browsers
# 03h,28jun00,bwd  Changed host checking to use windHostTypeGet instead of
#                  env(WIND_HOST_TYPE)
# 03g,22jun00,bwd  SPR 32061: changed the size of the message in meterCreate
#                  procedure to vary, depending on the length of the message.
#                  Removed fade for bitmap if linux.
# 03f,21jun00,bjl  Added regIntValueWriteLog functions.
# 03e,06jun00,bwd  Added new page lists to lmPages in procedure quiteCallback
# 03d,30may00,bwd  Modified reconstructPageList to handle special case when
#                  the page lead get removed (in case of reloading a license
#                  file via email/phone request).
# 03c,23may00,j_w  Added default error handling (SPR 31160)
# 03b,19may00,wmd  SPR 31003 - use lmVals(httpToken) to hold tranaction token.
# 03a,10may00,j_w  Replaced "WRS" to "Wind River"(SPR 31004). Added error 
#                                  handling for error code -25 and -26 (SPR 31153)
# 02z,05may00,bwd  Fixed SPR 31061. Declared ctrlVals variable in
#                  linkCreateLog procedure
# 02y,26apr00,bwd  Fixed Windows HELP in helpCallback to retrieve PATH for
#                  Netscape and Iexplorer from system registries
# 02x,19apr00,bwd  Fixed netscape lauching for windows in helpCallback
# 02w,19apr00,bwd  Change SETUP HELP to assume that user has either internet
#                  explorer (Windows) or/and netscape. Workaround for Beta -
#                  use only 1 default help page.
# 02v,19apr00,bwd  Change SETUP HELP (helpCallback) to use HTML pages for both
#                  windows and UNIX
# 02u,18apr00,bwd  Added calls to display error messages for CGI_ERROR_32,
#                  ALD_ERROR_51, ALD_ERROR_52.
# 02t,13apr00,j_w  fixed typo
# 02s,13apr00,j_w  fix VersionNumber
# 02r,10apr00,j_w  Updated parameter list for sendToALD
# 02q,06apr00,bwd  Removed contact info to use URL instead.
# 02p,15mar00,bwd  Added additional message in quitCallback to prompt user
#                  that LM configuration/installation is not yet complete if
#                  user quits during LM pages. Increased the height of 
#                  resume_exit dialog box to fit new message.
# 02o,10feb00,j_w  Fix spacing
# 02n,04feb00,wmd  Add error messages for db error -23, transaction cannot be
#                  automated.
# 02n,04feb00,j_w  Fix parameter list for commit request
# 02m,03feb00,j_w  Remove commit command in the parameter list of commit
#                  request call
# 02l,02feb00,bwd  Fixed queueExecute to reset setupVals(commandQueue) after
#                  each execution
# 02k,01feb00,j_w  Removed error dlg box for error code -31 -- return 1
#                  instead
# 02j,01feb00,bwd  Fixed error handling for test automation
# 02i,25jan00,bwd  Added codes for error handling and displaying contact
#                  information in TEXT mode
# 02h,24jan00,bwd  Deleted redundant codes
# 02g,21jan00,j_w  Update licInfoGetAllRequest in sendToALD procedure and
#                  remove redundant code
# 02f,19jan00,wmd  Modify ok_with_title dialog box to check for \n.
# 02e,11jan00,j_w  Updated CGI_ERROR_30 error message
# 02d,07jan00,j_w  Tested network connection to Wind River Server and 
#                  updated CGI_ERROR_30 error message
# 02c,04jan00,bwd  Corrected contact information for License Administrator
# 02b,23dec99,bwd  Modified the error dialog to display with a scrollbar to
#                  accommodate long message/information
# 02a,17dec99,clc  remove debug code from testing
# 01z,16dec99,clc  add uninstStop to textmode nextCallback
# 01y,10dec99,j_w  Add error checking in sendToALD if CGI is down
# 01x,09dec99,j_w  Update serverErrorDlg
# 01w,08dec99,j_w  Added error checking in helpCallback
# 01v,08dec99,j_w  Replace hh viewer from modal to modeless 
# 01u,07dec99,wmd  Add license admin email/phone number to help customers.
# 01t,07dec99,j_w  catch error for hh
# 01s,04dec99,wmd  Add error pages for sendToALD.
# 01r,01dec99,j_w  Add helpCallback procedure
# 01r,30nov99,clc  add text mode for sendToALD procedure
# 01q,30nov99,wmd  Add endWaitCursor to the default case.
# 01p,30nov99,j_w  Add a Help button
# 01o,23nov99,clc  add text mode to meterUpdate
# 01n,23nov99,j_w  Add error handling for Server Error inside sendToALD proc.
# 01m,15nov99,wmd  Fix debug messages.
# 01l,10nov99,wmd  Add error handling switch to sendToALD proc.
# 01k,05nov99,wmd  Add a new dialog proc ok_with_title.
# 01j,04nov99,j_w  added more case statements in sendToALD
# 01i,03nov99,j_w  Added sendToALD
# 01h,30oct99,wmd  Add a pageExists procedure.
# 01g,27oct99,bwd  Moved autoSetupLog to INSTW32.TCL
# 01f,22oct99,j_w  Added comments and remove debug messages
# 01e,18oct99,j_w  Update error messages in linkCreateLog
# 01d,15oct99,bjl  removed DCOM update for Win95 from windowsSystemCheck.
# 01c,14oct99,j_w  Add paramenters to uninstallInitWin32
# 01b,06oct99,j_w  added calcPage procedure
# 01a,09Sep99,j_w  written
#
# DESCRIPTION
# This module is the Tcl code for the Setup program. It contains procedures for
# the wizard pages.
#

global errorReturnVal

#############################################################################
#
# removeBackground - determine whether environment variable
#                    SETUP_REMOVEBACKGROUND is set
#
# This procedure will determine whether environment variable
# SETUP_REMOVEBACKGROUND is set
#
# SYNOPSIS
# .tS
# removeBackground
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: 0 if enviroment variable SETUP_REMOVEBACKGROUND is not set
#          1 if enviroment variable SETUP_REMOVEBACKGROUND is set
#
# ERRORS: N/A
#

proc removeBackground {} {
    global env

    if {[info exists env(SETUP_REMOVEBACKGROUND)]} {
        if {$env(SETUP_REMOVEBACKGROUND)==1} {
            return 1
        }
    }

    return 0
}

#############################################################################
#
# setupFolderCreate - create folder for the product (ex: Tornado)
#
# This procedure will create folder for the product
#
# SYNOPSIS
# .tS
# setupFolderCreate <folder> <mode>
# .tE
#
# PARAMETERS:
# .IP folder
# folder name to be created
# .IP mode
# 0 -- install the product in the user program group
# 1 -- install the product in the common program group
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc setupFolderCreate {folder mode} {

    set path [programPathGet $mode]

    if [catch {file mkdir "$path\\$folder"} err] {
        dbgputs "cannot create folder, $folder, $mode: $err"
    }
}

#############################################################################
#
# folderCreateLog - create the product's folders and log the actions
#
# This procedure will create the product's folders and log the actions
# for uninstall to use later
#
# SYNOPSIS
# .tS
# folderCreateLog <folder> <mode> [log]
# .tE
#
# PARAMETERS:
# .IP folder
#  folder name to be created
# .IP mode
# 0 -- install the product in the user program group
# 1 -- install the product in the common program group
# .IP log
# true -- log the actions (default)
# false -- do not log the actions
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc folderCreateLog {folder mode {log true}} {
    global ctrlVals

    setupFolderCreate $folder $mode

    if {[lsearch $ctrlVals(folders) $folder] == "-1" && $log == "true"} {
        lappend ctrlVals(folders) $folder
        uninstLog resource "folder\t$folder\t$mode"
    }
}


#############################################################################
#
# setupLinkDelete - create the product program links
#
# This procedure will create the product program links
#
# SYNOPSIS
# .tS
# setupLinkDelete <folder> <linkName> <mode>
# .tE
#
# PARAMETERS:
# .IP folder
# folder name containing the program links
# .IP linkName
# string name of program links
# .IP mode
# 0 -- install the product in the user program group
# 1 -- install the product in the common program group
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc setupLinkDelete {folder linkName mode} {

    set programPath [programPathGet $mode]

    if { "$folder" == "" } {
        puts "Error: folder name is null"
        return
    }

    if {"$linkName" == "" } {
        puts "Error: link name is null"
        return
    }

    if [catch {file delete "$programPath\\$folder\\$linkName.lnk"} err] {
        dbgputs "cannot delete icon, $linkName: $err"
    } else {
        dbgputs "deleted icon: $linkName"
    }
}

#############################################################################
#
# linkCreateLog - create the product program links and log the actions
#
# This procedure will create the product program links and log the actions for
# uninstall use later
#
# SYNOPSIS
# .tS
# linkCreateLog <folder> <item> <exe> [args] [dir] [mode] [fMin] [iconIndex]
#               [iconPath]
# .tE
#
# PARAMETERS:
# .IP folder
# folder name containing the program links
# .IP item
# icon name; eg "Tornado Registry", "VxWorks COM1"
# .IP exe
# path to the executable file; eg "host\x86-win32\bin\wtxregd.exe"
# .IP args
# arguments passed to the executable; eg "-V"
# .IP dir
# directory that the executable resides
# .IP mode
# 0 -- install the product in the user program group
# 1 -- install the product in the common program group
# .IP fMin
# run in minimized state
# .IP iconIndex
# icon index
# .IP iconPath
# path to the icon file; eg host\resource\bitmaps\WindView\evtRecv.ico
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc linkCreateLog {folder item exe args dir mode {fMin 0} {iconIndex 0}\
                {iconPath ""}} {

    global ctrlVals
    set added 0
    set new 0

    if {![catch {setupLinkDelete $folder $item $mode} error]} {
        set new 1
    }

    if {$iconPath == "" && ![catch {setupLinkCreate $folder \
                                    $item \
                                    $exe \
                                    $args \
                                    $dir \
                                    $mode \
                                    $fMin} error]} {
        set added 1

    } elseif {![catch {setupLinkCreate $folder \
                                    $item \
                                    $exe \
                                    $args \
                                    $dir \
                                    $mode \
                                    $fMin \
                                    $iconIndex \
                                    $iconPath} error]} {
        set added 1
    } else {
        dbgputs "error when creating item $item in $folder: $error"
        set hasError 1
    }

    if {$new && $added} {
        dbgputs "Added to uninstLog: icon\t$folder\t$item\t$mode"
        uninstLog resource "icon\t$folder\t$item\t$mode"
    }

    if [info exists hasError] {

        set msg "Cannot create icons(s): $error\nPlease run \"SETUP\" \
                 and select Program Group installation option to install \
                 icons at a later time."

        if { $ctrlVals(useInputScript) } {
            autoSetupLog "$msg"
            autoSetupLog "Application Exit\n"
            set setupVals(cancel) 1                
            applicationExit
            return 0
        } else {
            messageBox "$msg"
        }
    }
}

#############################################################################
#
# regKeyCreateLog - create registry key and log the actions
#
# This procedure will create registry key and log the actions
#
# SYNOPSIS
# .tS
# regKeyCreateLog <rootKey> <subKey> <key> [log]
# .tE
#
# PARAMETERS:
# .IP rootKey
# root of registry key hierarchy; eg HKEY_LOCAL_MACHINE
# .IP subKey
# path to the registry key; eg SOFTWARE\\Microsoft\\Windows\\CurrentVersion
# .IP key
# key name; eg "Uninstall", "TornadoV2.0"
# .IP log
# true -- log the actions (default)
# false -- do not log the actions
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc regKeyCreateLog {rootKey subKey key {log true}} {
    global setupVals

    lappend setupVals(commandQueue) \
        [list regKeyCreateLogHelper $rootKey $subKey $key $log]
}

#############################################################################
#
# regKeyCreateLogHelper - helper procedure to create registry key and
#                         save the actions
#
# This procedure is a helper procedure to create registry key and save the
# actions
#
# SYNOPSIS
# .tS
# regKeyCreateLogHelper <rootKey> <subKey> <key> [log]
# .tE
#
# PARAMETERS:
# .IP rootKey
# root of registry key hierarchy; eg HKEY_LOCAL_MACHINE
# .IP subKey
# path to the registry key; eg SOFTWARE\\Microsoft\\Windows\\CurrentVersion
# .IP key
# key name; eg "Uninstall", "TornadoV2.0"
# .IP log
# true -- log the actions (default)
# false -- do not log the actions
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc regKeyCreateLogHelper {rootKey subKey key log} {

    if {[catch {setupRegKeyExists $rootKey "$subKey\\$key"} error] &&
       ![catch {sysRegistryKeyCreate $rootKey $subKey $key} error] &&
       "$log" == "true"} {
         uninstLog resource "regkey\t$rootKey\t$subKey\\$key"
    }
}

#############################################################################
#
# regValueExists - test if registry key exists
#
# This procedure will test if registry key exists
#
# SYNOPSIS
# .tS
# regValueExists <rootKey> <subKey> <value>
# .tE
#
# PARAMETERS:
# .IP rootKey
# root of registry key hierarchy; eg HKEY_LOCAL_MACHINE
# .IP subKey
# path to the registry key; eg SOFTWARE\\Microsoft\\Windows\\CurrentVersion
# .IP key
# key name; eg "Uninstall", "TornadoV2.0"
#
# RETURNS: retVal - 0 -- registry key does not exist
#                 - 1 -- registry key exists
#
# ERRORS: N/A
#

proc regValueExists {rootKey subKey value} {
    set retVal 0
    if {[lsearch [setupRegValueEnum $rootKey $subKey] $value] != -1} {
        set retVal 1
    }
    return $retVal
}

#############################################################################
#
# regValueWriteLog - write registry key to the Windows registry and save
#                    the actions for uninstall use later
#
# This procedure will write registry key to the Windows registry and save
# the actions for uninstall use later
#
# SYNOPSIS
# .tS
# regValueWriteLog <rootKey> <key> <valueName> <value> [log]
# .tE
#
# PARAMETERS:
# .IP rootKey
# root of registry key hierarchy; eg HKEY_LOCAL_MACHINE
# .IP key
# path to the registry key; eg SOFTWARE\\Microsoft\\Windows\\CurrentVersion
# .IP valueName
# key name; eg "Uninstall", "TornadoV2.0"
# .IP value
# value associated with the key
# .IP log
# true -- log the actions (default)
# false -- do not log the actions
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc regValueWriteLog {rootKey key valueName value {log true}} {
    global setupVals

    lappend setupVals(commandQueue) \
        [list regValueWriteLogHelper $rootKey $key $valueName $value $log]
}

#############################################################################
#
# regValueWriteLogHelper - helper procedure to regValueWriteLog
#
# This procedure is a helper procedure to regValueWriteLog
#
# SYNOPSIS
# .tS
# regValueWriteLogHelper <rootKey> <key> <valueName> <value> [log]
# .tE
#
# PARAMETERS:
# .IP rootKey
# root of registry key hierarchy; eg HKEY_LOCAL_MACHINE
# .IP key
# path to the registry key; eg SOFTWARE\\Microsoft\\Windows\\CurrentVersion
# .IP valueName
# key name; eg "Uninstall", "TornadoV2.0"
# .IP value
# value associated with the key
# .IP log
# true -- log the actions (default)
# false -- do not log the actions
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc regValueWriteLogHelper {rootKey key valueName value log} {

    if {[catch {sysRegistryValueWrite $rootKey $key $valueName $value} error]} {
        puts "error when writing value $valueName: $error"

    } elseif {"$log" == "true" && ![regValueExists $rootKey $key $valueName]} {
        uninstLog resource "regValue\t$rootKey\t$key\t$valueName"
    }
}

#############################################################################
#
# regIntValueWriteLog - write registry key to the Windows registry and save
#                       the actions for uninstall use later
#
# This procedure will write registry key to the Windows registry and save
# the actions for uninstall use later.  Value is an integer.  
#
# SYNOPSIS
# .tS
# regIntValueWriteLog <rootKey> <key> <valueName> <value> [log]
# .tE
#
# PARAMETERS:
# .IP rootKey
# root of registry key hierarchy; eg HKEY_LOCAL_MACHINE
# .IP key
# path to the registry key; eg SOFTWARE\\Microsoft\\Windows\\CurrentVersion
# .IP valueName
# key name; eg "Uninstall", "TornadoV2.0"
# .IP value
# value associated with the key
# .IP log
# true -- log the actions (default)
# false -- do not log the actions
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc regIntValueWriteLog {rootKey key valueName value {log true}} {
    global setupVals

    lappend setupVals(commandQueue) \
        [list regIntValueWriteLogHelper $rootKey $key $valueName $value $log]
}

#############################################################################
#
# regIntValueWriteLogHelper - helper procedure to regIntValueWriteLog
#
# This procedure is a helper procedure to regIntValueWriteLog
#
# SYNOPSIS
# .tS
# regIntValueWriteLogHelper <rootKey> <key> <valueName> <value> [log]
# .tE
#
# PARAMETERS:
# .IP rootKey
# root of registry key hierarchy; eg HKEY_LOCAL_MACHINE
# .IP key
# path to the registry key; eg SOFTWARE\\Microsoft\\Windows\\CurrentVersion
# .IP valueName
# key name; eg "Uninstall", "TornadoV2.0"
# .IP value
# value associated with the key
# .IP log
# true -- log the actions (default)
# false -- do not log the actions
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc regIntValueWriteLogHelper {rootKey key valueName value log} {

    if {[catch {sysRegistryValueWrite -int $rootKey $key $valueName $value} error]} {
        puts "error when writing value $valueName: $error"

    } elseif {"$log" == "true" && ![regValueExists $rootKey $key $valueName]} {
        uninstLog resource "regValue\t$rootKey\t$key\t$valueName"
    }
}

#############################################################################
#
# queueExecute - execute commands in the queue
#
# This procedure will execute commands in the queue. The purpose is to store
# a list of commands in case if users decide to exit the setup program, these
# commands can all be executed at once.
#
# SYNOPSIS
# .tS
# queueExecute
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc queueExecute {} {
    global setupVals

    foreach command $setupVals(commandQueue) {
        eval $command
    }

    # reset the list
    set setupVals(commandQueue) ""
}

#############################################################################
#
# windRegValueRead - load WIND_REGISTRY registry value from the previous
#                    installation if any
#
# This procedure will load WIND_REGISTRY registry value from the previous
# installation if any
#
# SYNOPSIS
# .tS
# windRegValueRead
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: WIND_REGISTRY value
#
# ERRORS: N/A
#

proc windRegValueRead {} {
    global setupVals
    global ctrlVals

    # Load WIND_REGISTRY from the previous installation if any

    if ![info exists setupVals(registry)] {
        set setupVals(registry) ""

        if {![catch {sysRegistryValueRead HKEY_CURRENT_USER \
                "Software\\$setupVals(WRS)\\$setupVals(prodRegEntry)" \
                WIND_REGISTRY} retVal]} {

            set setupVals(registry) $retVal

        } elseif {![catch {sysRegistryValueRead HKEY_LOCAL_MACHINE \
                "SOFTWARE\\$setupVals(WRS)\\$setupVals(prodRegEntry)" \
                WIND_REGISTRY} retVal]} {

            set setupVals(registry) $retVal
        }
    }

    return $setupVals(registry)
}

#############################################################################
#
# dlgFrmCreate - create wizard page
#
# This procedure will create wizard page
#
# SYNOPSIS
# .tS
# dlgFrmCreate <title>
# .tE
#
# PARAMETERS:
# .IP title
# name of the wizard page
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc dlgFrmCreate {title} {
    global ctrlVals
    global setupVals
    global env

    if {[removeBackground]} {
        set title "$title"
    }

    if {[windHostTypeGet]=="x86-win32"} {
        set backButtXPos 147
                set helpButtXPos 87
    } else {
        set backButtXPos 143
                set helpButtXPos 83
    }

    if {[windowExists $ctrlVals(mainWindow)] != 1 } {
        set controls [list \
                [list bitmap -name bitmap \
                             -title $ctrlVals(dlgImage) -stretch \
                             -x 10 -y 10 -w 80 -h 160] \
                [list frame -gray -name frm2 -x 10 -y 178 -w 295 -h 2] \
                [list button -name backButt -title "< &Back" \
                             -callback backCallback \
                             -disable -x $backButtXPos -y 185 -w 50 -h 14] \
                [list button -name nextButt -title "&Next >" \
                             -default -callback nextCallback \
                              -x 197 -y 185 -w 50 -h 14] \
                [list button -name cancelButt -title "&Cancel" \
                             -callback quitCallback \
                              -x 255 -y 185 -w 50 -h 14] \
                                [list button -name helpButt -title "&Help" \
                                             -callback helpCallback \
                                                         -x $helpButtXPos -y 185 -w 50 -h 14] \
        ]
        if {[removeBackground] && ![info exists env(SETUP_USEKDE)]} {
        # add a minimize box to the dialog form since
        # there is no background to minimize.

        # create the dialog with initial size of 1 1, then
        # resize and reposition the dialog after.  This is
        # to workaround a UITclSh bug which does not allow
        # the window to shrink below its original size for
        # the billboard dialogs.

            dialogCreate -name $ctrlVals(mainWindow) \
                         -title $title -w 315 -h 204 \
                         -nocontexthelp \
                         -parent $ctrlVals(parentDialog) \
                         -modeless \
                         -controls $controls

            windowSizeSet $ctrlVals(mainWindow) 315 204

        } elseif {[removeBackground] && [info exists env(SETUP_USEKDE)]} {

        # Sizing and positioning a window causes
        # KDE to crash.  Initialize window for KDE at
        # full size, and later keep the same size
        # in the file copying billboard page.

            dialogCreate -name $ctrlVals(mainWindow) \
                         -title $title \
                         -nocontexthelp \
                         -parent $ctrlVals(mainWindow) \
                         -modeless \
                         -controls $controls -w 315 -h 204
    } else {
            dialogCreate -name $ctrlVals(mainWindow) \
                         -title $title -w 315 -h 204 \
                         -nocontexthelp \
                         -parent $ctrlVals(parentDialog) \
                         -modeless \
                         -controls $controls
    }

        set ctrlVals(parentDialog) $ctrlVals(mainWindow)
        windowQueryCloseCallbackSet $ctrlVals(mainWindow) quitCallback
    }

    customizeMainWindow $title
    return $ctrlVals(mainWindow)
}

#############################################################################
#
# customizeMainWindow - set the title of the wizard page
#
# This procedure will set the title of the wizard page
#
# SYNOPSIS
# .tS
# customizeMainWindow
# .tE
#
# PARAMETERS:
# .IP title
# title of the wizard page
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc customizeMainWindow {title} {
    global ctrlVals

    windowTitleSet $ctrlVals(mainWindow) $title

    foreach ctrl $ctrlVals(volatileFrm) {
        controlCreate $ctrlVals(mainWindow) $ctrl
    }

    set ctrlVals(jumpBack) 1
}

#############################################################################
#
# destroyVolatileFrm - close the wizard page
#
# This procedure will close the wizard page
#
# SYNOPSIS
# .tS
# destroyVolatileFrm
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc destroyVolatileFrm {} {
    global ctrlVals

    # First hide the controls to make it 'invisible', mainwin may be slow in
    # how it implements refresh logic on unix.

    foreach ctrl $ctrlVals(volatileFrm) {
        set pos [lsearch $ctrl "-name"]

        if {$pos != "-1"} {
            controlHide \
                $ctrlVals(mainWindow).[lindex $ctrl [expr $pos + 1]] 1
        }
    }

    # Then we destroy the controls

    foreach ctrl $ctrlVals(volatileFrm) {
        set pos [lsearch $ctrl "-name"]

        if {$pos != "-1"} {
            controlDestroy \
                $ctrlVals(mainWindow).[lindex $ctrl [expr $pos + 1]]
        }
    }
    set ctrlVals(volatileFrm) ""
}


#############################################################################
#
# helpCallback - display html help
#
# This procedure will display html help for that particular page
#
# SYNOPSIS
# .tS
# helpCallback
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc helpCallback {} {
    global ctrlVals
    global LMHelpPath

    set anchor c-install.html

    if { [isUnix] } {
        set helpFile [file join [cdromRootDirGet] RESOURCE HELP $anchor]
    } else {
        set rootDir "[cdromRootDirGet]\\"
        set helpFile [unixToDos [file join $rootDir RESOURCE HELP $anchor]]
    }

    dbgputs "Help file: $helpFile"

        if { [isUnix] } {

        if { [catch {exec ps | grep netscape} result] } {
            # if no Netscape browser currently open, try launching it

            if { [catch {exec netscape $helpFile &} result] } {
                # if no Netscape installed, warn user

                dialog ok_with_title "Online Help: Error!" \
                      "Cannot locate Netscape Navigator on this machine!\
                      \nNetscape Navigator 4.0 or higher is required\
                      for SETUP Help pages. Please be sure to\
                      install Netscape in order to access Help pages."
            }
        } else {
            # if Netscape is currently running, use same session
            catch {exec netscape -remote openURL($helpFile) &} result
        }

        } else { # windows

        # search for default internet browser

        foreach fExt ".htm .html" {

            if { ![catch {sysRegistryValueRead HKEY_CLASSES_ROOT $fExt ""} path] } {
                set path "$path\\shell\\open\\command"
 
                if { ![catch {sysRegistryValueRead HKEY_CLASSES_ROOT $path ""} browserPath] } {
                    regsub -all {\"} $browserPath "" browserPath
                    regsub -all {%.*} $browserPath "" browserPath
                    regsub -all { -.*} $browserPath "" browserPath
                    dbgputs "browser path: $browserPath"

                    if { [catch {exec $browserPath $helpFile &} result] } {
                        if { $fExt == ".html" } {
                            dialog ok_with_title "Online Help: Error!" \
                                "Cannot locate any local internet browser on this machine!\nPlease\
                                 be sure to install a browser in order to access Help pages."
                        }
                    } else {
                        # no error launching
                        break
                    }
                }
            }
        }
    }
}


#############################################################################
#
# backCallback - close the current wizard page and return to the previous
#                wizard page
#
# This procedure will close the current wizard page and return to the previous
# wizard page
#
# SYNOPSIS
# .tS
# backCallback
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc backCallback {} {
    global ctrlVals
    global setupVals

    # decrement the dialog index and re-create previous page

    set currPageIndex [lsearch $ctrlVals(pageList) $ctrlVals(currPage)]
    set prevPageIndex [expr $currPageIndex - 1]

    if {"$prevPageIndex" >= "0"} {
        set ctrlVals(lastPage) $ctrlVals(currPage)
        set ctrlVals(currPage) [lindex $ctrlVals(pageList) $prevPageIndex]
        reconstructPageList

        if { $setupVals(cmdMode) != "text" } {  destroyVolatileFrm  }

        pageCreate($ctrlVals(currPage))

    } else {
        if { $setupVals(cmdMode) != "text" } {        
            messageBox "Cannot go back further!"
        } else {
            puts "Cannot go back further!"
        }
    }
}

#############################################################################
#
# reconstructPageList - reconstruct the setup page list
#
# This procedure will reconstruct the page list. It detects the current page
# group  and if the current page is the first elemet in the group,
# it will remove the page list
#
# SYNOPSIS
# .tS
# reconstructPageList
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#
proc reconstructPageList {} {
    global setupPageList ctrlVals

    set pg $setupPageList(currPageGrp)

    set index [eval lsearch {$setupPageList($pg)} $ctrlVals(lastPage)]
    if {$index == 0} {
        # match the fist element in the list
        pageListRemove $pg
    } elseif { $index == 1 } {
        # in case lmReload -> Email/Phone (page lead was removed),
        # check if page lead of that group is in current page list
        set firstPage [lindex $setupPageList($pg) 0]
        set firstIndex [lsearch $ctrlVals(pageList) $firstPage]

        if { $firstIndex == -1 } {
            # if page lead is not there and current page is 
            # the 2nd page from the group, remove pg group

            pageListRemove $pg
        }
    }
    dbgputs "reconstruct: $ctrlVals(pageList)"

}

#############################################################################
#
# pageListAdd - Add a new page list
#
# This procedure will append a page group to the existing page list
#
# SYNOPSIS
# .tS
# pageListAdd
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#
proc pageListAdd {pageGrpName} {
    global ctrlVals setupPageList

    set ctrlVals(pageList) [eval concat $ctrlVals(pageList) \
        $setupPageList($pageGrpName)]

    # add new page group
    set setupPageList(currPageGrp) $pageGrpName
    set setupPageList(pageGroupList) \
        [concat $setupPageList(pageGroupList) $pageGrpName]

}

#############################################################################
#
# pageExists - Checks for existance of a page in ctrlVals(pageList)
#
# This procedure will remove a page group of the existing page list
#
# SYNOPSIS
# .tS
# pageExists page
# .tE
#
# PARAMETERS: page:  the page to check for in the ctrlVals(pageList)
#
# RETURNS: N/A
#
# ERRORS: N/A
#
proc pageExists {page} {
    global ctrlVals

    if {[lsearch $ctrlVals(pageList) $page] == "-1"} {
        return 0
    } else {
        return 1
    }       
}

#############################################################################
#
# pageListRemove - Remove a page list
#
# This procedure will remove a page group of the existing page list
#
# SYNOPSIS
# .tS
# pageListRemove
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#
proc pageListRemove {group} {
    global setupPageList

    foreach i $setupPageList($group) {
        pageRemove $i
    }

    # remove the page group
    # pageGroupRemove
    set ix [llength $setupPageList(pageGroupList)]
    set ix [expr $ix - 1]
    set setupPageList(pageGroupList) \
        [lreplace $setupPageList(pageGroupList) $ix $ix]
    set setupPageList(currPageGrp) \
        [lindex $setupPageList(pageGroupList) end]

    dbgputs "removed pagegroup: $group"
    dbgputs "currentPageGrp: $setupPageList(currPageGrp)"
}



#############################################################################
#
# nextCallback - go to the next wizard page
#
# This procedure will take Setup to the next wizard page as if next button
# is pushed
#
# SYNOPSIS
# .tS
# nextCallback
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc nextCallback {} {
    global ctrlVals
    global setupVals

    if { $setupVals(cmdMode) != "text" } {
        set guimode 1
    } else {
        set guimode 0
    }

    set retVal 0
    if {"$ctrlVals(currPage)" == ""} {  return $retVal }

    set processRetVal [pageProcess($ctrlVals(currPage))]
    if {$processRetVal == "1"} {

        set currPageIndex [lsearch $ctrlVals(pageList) $ctrlVals(currPage)]

        if {"$currPageIndex" != "-1"} {
            set nextPageIndex [expr $currPageIndex + 1]
            set nextPage [lindex $ctrlVals(pageList) $nextPageIndex]

            if {"$nextPage" != ""} {
                set ctrlVals(currPage) $nextPage

                if { $guimode } {  
                    destroyVolatileFrm

                    if {[info exists ctrlVals(restoredDialog)]} {
                        if {$ctrlVals(restoredDialog) == 0} {
                            restoreOriginalDialog
                        }
                    }
                }

                pageCreate($nextPage)
                set retVal 1

            } else {

                if { $guimode } {

                    # temporary workaround for windowClose exit problem
                    set setupVals(cancel) 1

                    # remove setup.log.abort
                    catch {file delete [destDirGet]/setup.log.abort}

                    applicationExit

                } else {

                   # temporary workaround for exit problem

                   if {[uninstHomeDirGet] != "" && ![info exists setupVals(diskfull)]} {
                       uninstStop [getProdInfo name] [getProdInfo version]
                   }
                   set setupVals(cancel) 1

                   # remove setup.log.abort
                   catch {file delete [destDirGet]/setup.log.abort}

                   return 0              
                }
            }
        } else {
            puts "error: page $ctrlVals(currPage) not found!"
        }

    } elseif {$processRetVal != "0"} {
  
        # calculate the current page based on the return value
 
        set currPageIndex [lsearch $ctrlVals(pageList) $ctrlVals(currPage)]
        set currPageIndex [expr $currPageIndex + $processRetVal]
        set maxVal [llength $ctrlVals(pageList)]

        if {"$currPageIndex" != "-1" && $currPageIndex <= $maxVal} {
            set nextPageIndex $currPageIndex
            set nextPage [lindex $ctrlVals(pageList) $nextPageIndex]

            if {"$nextPage" != ""} {
                set ctrlVals(currPage) $nextPage

                if { $guimode } {  destroyVolatileFrm  }
 
                pageCreate($nextPage)
                set retVal 1

            } else {
                if { $guimode } {  
                    applicationExit  
                } else {  
                    return 0 
                }
            }
        } else {
            puts "error: page $ctrlVals(currPage) not found!"
        }
    }
    return $retVal
}


#############################################################################
#
# restoreOriginalDialog - restore the original dialog size
#
# This procedure will restore the original dialog size
#
# SYNOPSIS
# .tS
# restoreOriginalDialog
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc restoreOriginalDialog {} {
    global ctrlVals
    global env

    set ctrlVals(restoredDialog) 1
    windowShow $ctrlVals(mainWindow) -restore 1
    if {![info exists env(SETUP_USEKDE)]} {
       windowPositionSet $ctrlVals(mainWindow) [expr $ctrlVals(dlg_orig_xpos)] \
                                               [expr $ctrlVals(dlg_orig_ypos)]
    }
    controlHide $ctrlVals(mainWindow).bitmap 0

    # hide the "phony" Next button and restore the original button.
    # See the procedure "resizeBbrdDialog".
    controlHide $ctrlVals(mainWindow).phonynextButt 1
    controlHide $ctrlVals(mainWindow).nextButt 0

    controlPropertySet $ctrlVals(mainWindow).nextButt -defaultbutton 1
    controlSizeSet $ctrlVals(mainWindow).frm2 \
                   [lindex $ctrlVals(dlg_orig_frm2_size) 0] \
                   [lindex $ctrlVals(dlg_orig_frm2_size) 1]
    controlPositionSet $ctrlVals(mainWindow).frm2 \
                   [lindex $ctrlVals(dlg_orig_frm2_pos) 0] \
                   [lindex $ctrlVals(dlg_orig_frm2_pos) 1]
    controlPositionSet $ctrlVals(mainWindow).backButt \
                   [lindex $ctrlVals(dlg_orig_back_pos) 0] \
                   [lindex $ctrlVals(dlg_orig_back_pos) 1]
    controlPositionSet $ctrlVals(mainWindow).nextButt \
                   [lindex $ctrlVals(dlg_orig_next_pos) 0] \
                   [lindex $ctrlVals(dlg_orig_next_pos) 1]
    controlPositionSet $ctrlVals(mainWindow).cancelButt \
                   [lindex $ctrlVals(dlg_orig_cancel_pos) 0] \
                   [lindex $ctrlVals(dlg_orig_cancel_pos) 1]
    if {![info exists env(SETUP_USEKDE)]} {
      windowSizeSet $ctrlVals(mainWindow) [lindex $ctrlVals(dlg_orig_size) 0] \
                                          [lindex $ctrlVals(dlg_orig_size) 1]
    }
}

#############################################################################
#
# fileExistsNewerWarnExit - exit procedure for fileExistsNewerExit dialog box
#
# This procedure is a exit procedure for fileExistsNewerExit dialog box
#
# SYNOPSIS
# .tS
# fileExistsNewerWarnExit
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc fileExistsNewerWarnExit {} {
    global retvalNew

    if {[controlChecked file_exists_newer_warn.overwriteFile]} {
        set retvalNew 0
    }
    if {[controlChecked file_exists_newer_warn.no_overwriteFile]} {
        set retvalNew 1
    }
    if {[controlChecked file_exists_newer_warn.overwriteAll]} {
        set retvalNew 2
    }
    if {[controlChecked file_exists_newer_warn.no_overwriteAny]} {
        set retvalNew 3
    }
}

#############################################################################
#
# fileExistsNewerWarnInit - Init procedure for fileExistsNewerWarn dialog box
#
# This procedure is a init procedure for fileExistsNewerWarn dialog box
#
# SYNOPSIS
# .tS
# fileExistsNewerWarnInit
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc fileExistsNewerWarnInit {} {
    global retvalNew

    set retvalNew 2
    windowExitCallbackSet file_exists_newer_warn fileExistsNewerWarnExit
    controlCheckSet file_exists_newer_warn.overwriteAll 1
    controlFocusSet file_exists_newer_warn.overwriteAll
}

#############################################################################
#
# fileExistsOlderWarnExit - exit procedure for fileExistsOlderExit dialog box
#
# This procedure is a exit procedure for fileExistsOlderExit dialog box
#
# SYNOPSIS
# .tS
# fileExistsOlderWarnExit
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc fileExistsOlderWarnExit {} {
    global retvalOld

    if {[controlChecked file_exists_older_warn.no_overwriteFile]} {
        set retvalOld 0
    }
    if {[controlChecked file_exists_older_warn.overwriteFile]} {
        set retvalOld 1
    }
    if {[controlChecked file_exists_older_warn.overwriteAll]} {
        set retvalOld 2
    }
    if {[controlChecked file_exists_newer_warn.no_overwriteAny]} {
        set retvalNew 3
    }
}

#############################################################################
#
# fileExistsOlderWarnInit - init procedure for fileExistsOlderInit dialog box
#
# This procedure is a init procedure for fileExistsOlderInit dialog box
#
# SYNOPSIS
# .tS
# fileExistsOlderWarnInit
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc fileExistsOlderWarnInit {} {
    global retvalNew

    set retvalNew 2
    windowExitCallbackSet file_exists_older_warn fileExistsOlderWarnExit
    controlCheckSet file_exists_older_warn.overwriteAll 1
    controlFocusSet file_exists_older_warn.overwriteAll
}

#############################################################################
#
# onBaseInstallWarnContinue - callback procedure when continue button is
#                             pushed
#
# This procedure is a callback procedure when continue button is
# pushed and it closes the base_install_warn dialog box
#
# SYNOPSIS
# .tS
# onBaseInstallWarnContinue
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc onBaseInstallWarnContinue {} {
    global returnval

    set returnval 0
    windowClose base_install_warn
}

#############################################################################
#
# onBaseInstallWarnReturn - callback procedure when return button is
#                           pushed
#
# This procedure is a  callback procedure when return button is
# pushed and it closes the base_install_warn dialog box
#
# SYNOPSIS
# .tS
# onBaseInstallWarnReturn
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc onBaseInstallWarnReturn {} {
    global returnval

    set returnval 1
    windowClose base_install_warn
}

#############################################################################
#
# dialog - create a dialog box with buttons and messages based on
#          passed in arguments
#
# This procedure will create a dialog box with buttons and messages based on
# passed in arguments
#
# SYNOPSIS
# .tS
# dialog <dialogType> <title> <message> <args>
# .tE
#
# PARAMETERS:
# dialogType - stop                   -- dialog box with stop button
#              retry_cancel           -- dialog box with retry and cancel
#                                        buttons
#              yes_no                 -- dialog box with yes and no buttons
#              ok_proceed_exit        -- dialog box with ok, proceed and
#                                        exit buttons
#              yes_exit               -- dialog box with yes and exit buttons
#              resume_exit            -- dialog box with resume and
#                                        exit buttons
#              re_ig_cancel           -- dialog box with retry, ignore and
#                                        cancel buttons
#              re_ig_cancel_old       -- dialog box with retry, ignore and
#                                        cancel buttons (old version)
#              base_install_warn      -- dialog box with install and
#                                        "select path" buttons
#              file_exists_older_warn -- dialog box with yes and exit buttons
#              file_exists_newer_warn -- dialog box with ok button
#              ok                     -- dialog box with ok button
#              ok_cancel              -- dialog box with ok and cancel buttons
#              proceed_cancel         -- dialog box with proceed and cancel buttons
#
# title      - title for the dialog box
# message    - message displayed for the dialog box
# args       - XXX not used XXX
#
# RETURNS: 1 if successful
#          0 if failed
#
# ERRORS: N/A
#

proc dialog {dialogType title message args} {
    global ctrlVals
    global setupVals

    switch $dialogType {
        stop {
            switch [messageBox -ok -stopicon $message] {

                ok { return 1 }
            }
        }
        retry_cancel {
            switch [messageBox -retrycancel -questionicon $message] {
                retry  { return 0 }
                cancel { return 1 }
            }
        }
        yes_no {
            switch [messageBox -yesno -questionicon $message] {
                yes { return 0 }
                no  { return 1 }
            }
        }
        yes_no_cancel {
            switch [messageBox -yesnocancel -questionicon $message] {
                yes { return 0 }
                no  { return 1 }
                cancel {return 2}
            }
        }
        ok_proceed_exit {
            global returnval
            set returnval 0

            set controls [list \
                    [list label -name message -title $message \
                                -x 10 -y 10 -w 205 -h 90] \
                    [list button -name Resume -title "&Go back" -default \
                                 -tooltip "Go specify another directory" \
                                 -callback {global returnval;
                        windowClose ok_proceed_exit;
                                            set returnval 0} \
                                 -x 10 -y 78 -w 50 -h 14] \
                    [list button -name Exit -title "&Proceed" \
                                 -tooltip "Continue with installation" \
                                 -callback {global returnval;
                        windowClose ok_proceed_exit;
                                            set returnval 1} \
                                 -x 70 -y 78 -w 50 -h 14] \
                    [list button -name Exit -title "E&xit Setup" \
                                 -tooltip "Stop installation and exit" \
                                 -callback {global returnval;
                        windowClose ok_proceed_exit;
                                            set returnval 2} \
                                 -x 169 -y 78 -w 50 -h 14] \
            ]

            set width 230
            set xpos [expr ($ctrlVals(screenW) / 2) - ($width / 2)]

            set height 100
            set ypos [expr ($ctrlVals(screenH) / 2) - ($height / 2)]

            dialogCreate -name ok_proceed_exit \
                            -nocontexthelp \
                            -title "$title" \
                            -parent $ctrlVals(parentDialog) \
                            -x $xpos -y $ypos \
                            -w $width -h $height \
                            -controls $controls
            return $returnval
        }
        yes_exit {
            global returnval
            set returnval 0

            set controls [list \
                    [list label -name message -title $message \
                                -x 10 -y 10 -w 205 -h 120] \
                    [list button -name Yes -title "&Yes" \
                                 -tooltip "Proceed with installation" \
                                 -callback {global returnVal;
                        windowClose yes_exit;
                                            set returnval 0} \
                                 -x 116 -y 142 -w 50 -h 14] \
                    [list button -name Exit -title "E&xit Setup" \
                                 -tooltip "Stop installation and exit" \
                                 -callback {global returnval;
                        windowClose yes_exit;
                                            set returnval 1} \
                                 -x 169 -y 142 -w 50 -h 14] \
            ]

            set width 230
            set height 160

            dialogCreate -name yes_exit \
                            -title "$title" \
                            -nocontexthelp \
                            -parent $ctrlVals(parentDialog) \
                            -w $width -h $height \
                            -controls $controls
            return $returnval
        }
        resume_exit {
            global returnval
            set returnval 0

            set controls [list \
                    [list label -name message -title $message \
                                -x 10 -y 10 -w 205 -h 80] \
                    [list button -name Resume -title "&Resume" \
                                 -tooltip "Resume installation" \
                                 -callback {global returnVal;
                        windowClose resume_exit;
                                            set returnval 0} \
                                 -x 116 -y 100 -w 50 -h 14] \
                    [list button -name Exit -title "E&xit Setup" \
                                 -tooltip "Stop installation and exit" \
                                 -callback {global returnval;
                        windowClose resume_exit;
                                            set returnval 1} \
                                 -x 169 -y 100 -w 50 -h 14] \
            ]
            set width 230
            set xpos [expr ($ctrlVals(screenW) / 2) - ($width / 2)]

            set height 120
            set ypos [expr ($ctrlVals(screenH) / 2) - ($height / 2)]

            dialogCreate -name resume_exit \
                         -title "$title" \
                         -nocontexthelp \
                         -parent $ctrlVals(parentDialog) \
                         -x $xpos -y $ypos \
                         -w $width -h $height \
                         -controls $controls
            return $returnval
        }
        ok_with_title {
                        set width 200
                        set xpos [expr ($ctrlVals(screenW) / 2) - ($width / 2)]
                        set temp $message
                        set temp [split $temp " "]
                        set numLF 0
                        foreach elem $temp {
                                if {[string first "\n" $elem] != -1} {
                                        incr numLF
                                }
                        }
                        
                        set height [expr 7 + 25 + (10 * [expr [string length $message]/55 + 1])]
                        
                        set height [expr $height + ($numLF * 10)]
                        
                        set ypos [expr ($ctrlVals(screenH) / 2) - ($height / 2)]
                        
                        set controls [list \
                    [list label -name message -title $message \
                                                    -x 10 -y 10 -w 186 \
                                -h [expr ($numLF * 10) + \
                                                        (10 * [expr [string length $message]/55 + 1])]] \
                    [list button -name okWithTitle -title "&OK" \
                                 -callback {windowClose ok_with_title} \
                                 -x 75 -y [expr $height -7 -14] -w 50 -h 14] \
                        ]

                        dialogCreate -name ok_with_title \
                                                -nocontexthelp \
                            -title "$title" \
                            -parent $ctrlVals(parentDialog) \
                            -x $xpos -y $ypos \
                            -w $width -h $height \
                            -controls $controls
                        return 
        }
        re_ig_cancel {
            switch [messageBox -abortretryignore -questionicon $message] {
                abort  { return 2 }
                retry  { return 0 }
                ignore { return 1 }
                default { return 0 }
            }
        }
        re_ig_cancel_old {
            global returnval
            set returnval 0
            set controls [list \
                [list label -name message -title $message \
                            -x 10 -y 7 -w 194 -h 90] \
                [list button -name retry -title "&Retry" \
                             -callback {global returnval; \
                                        windowClose re_ig_cancel; \
                                        set returnval 0} \
                             -x 10 -y 56 -w 50 -h 14] \
                [list button -name ignore -title "&Ignore" \
                             -callback {global returnval; \
                                        windowClose re_ig_cancel; \
                                        set returnval 1} \
                             -x 80 -y 56 -w 50 -h 14] \
                [list button -name cancel -title "&Cancel" \
                             -callback {global returnval; \
                                        windowClose re_ig_cancel; \
                                        set returnval 2} \
                             -x 150 -y 56 -w 50 -h 14] \
            ]

            dialogCreate -name "re_ig_cancel" \
                         -title "$title" \
                         -parent $ctrlVals(parentDialog) \
                         -nocontexthelp \
                         -w 205 -h 76 \
                         -controls $controls
            return $returnval
        }
        base_install_warn {
            global returnval
            set returnval 1

            set controls [list \
                [list frame -white -name baseFrame -x 7 -y 7 -w 1 -h 1 \
                        -w 188 -h 36] \
                [list label -name warn_label \
                        -title " Installing [getProdInfo name] Over an Existing Tree " \
                        -x 20 -y 4 -w 160 -h 8] \
                [list label -name message -title $message \
                        -x 14 -y 14 -w 175 -h 28] \
                [list label -name message2 \
                        -title [strTableGet 4000_BASE_INSTALL_WARN_1] \
                        -x 10 -y 47 -w 184 -h 25] \
                [list button -name continue -title "&Install" \
                        -tooltip "Continue with installation" \
                        -callback onBaseInstallWarnContinue \
                        -x 10 -y 77 -w 50 -h 14] \
                [list button -name return -title "&Select Path" -default \
                        -tooltip "Return to Select Directory page" \
                        -callback onBaseInstallWarnReturn \
                        -x 146 -y 77 -w 50 -h 14] \
                                                ]

                        dialogCreate -name base_install_warn \
                                -title "$title" \
                                -parent $ctrlVals(parentDialog) \
                                -nocontexthelp \
                                -w 205 -h 96 \
                                -init {
                                  controlPropertySet base_install_warn.warn_label -bold 1
                        } \
                                -controls $controls
                        return $returnval
        }
        file_exists_older_warn {
            global retvalOld
            set retvalOld 2
            set controls [list \
                            [list label -name message -title $message \
                              -x 10 -y 7 -w 188 -h 70] \
                            [list choice -name overwriteFile -title \
                              [strTableGet 4010_FILE_EXISTS_WARN_1] \
                              -newgroup -auto \
                              -tooltip "Overwrite one file" \
                              -x 10 -y 55 -w 150 -h 10 ] \
                            [list choice -name no_overwriteFile -title \
                              [strTableGet 4010_FILE_EXISTS_WARN_2] -auto \
                              -tooltip "Do not overwrite file" \
                              -x 10 -y 67 -w 150 -h 10 ] \
                            [list choice -name overwriteAll -title \
                              [strTableGet 4010_FILE_EXISTS_WARN_3] -auto \
                              -tooltip "Overwrite all duplicate files" \
                              -x 10 -y 79 -w 180 -h 10 ] \
                            [list choice -name no_overwriteAny -title \
                              [strTableGet 4010_FILE_EXISTS_WARN_4] -auto \
                              -tooltip "Do not overwrite any duplicate files" \
                              -x 10 -y 91 -w 200 -h 10 ] \
                            [list button -name file_exists_OK -title "&OK" \
                              -callback {windowClose file_exists_older_warn} \
                              -x 77 -y 105 -w 50 -h 14 ]  ]
                        
            dialogCreate -name file_exists_older_warn \
                         -title "$title" \
                         -parent $ctrlVals(parentDialog) \
                         -nocontexthelp \
                         -init fileExistsOlderWarnInit \
                         -w 225 -h 130 \
                         -controls $controls
            return $retvalOld
        }
        file_exists_newer_warn {
            global retvalNew
            set retvalNew 2
            set controls [list \
                            [list label -name message -title $message \
                              -x 10 -y 7 -w 188 -h 70] \
                            [list choice -name overwriteFile -title \
                              [strTableGet 4010_FILE_EXISTS_WARN_1] \
                              -newgroup -auto \
                              -tooltip "Overwrite one file" \
                              -x 10 -y 55 -w 150 -h 10 ] \
                            [list choice -name no_overwriteFile -title \
                              [strTableGet 4010_FILE_EXISTS_WARN_2] -auto \
                               -tooltip "Do not overwrite file" \
                               -x 10 -y 67 -w 150 -h 10 ] \
                            [list choice -name overwriteAll -title \
                              [strTableGet 4010_FILE_EXISTS_WARN_3] -auto \
                               -tooltip "Overwrite all duplicate files" \
                               -x 10 -y 79 -w 180 -h 10 ] \
                            [list choice -name no_overwriteAny -title \
                              [strTableGet 4010_FILE_EXISTS_WARN_4] -auto \
                               -tooltip "Do not overwrite any duplicate files" \
                               -x 10 -y 91 -w 200 -h 10 ] \
                            [list button -name file_exists_OK -title "&OK" \
                               -callback {windowClose file_exists_newer_warn} \
                               -x 77 -y 105 -w 50 -h 14 ]  ]
                        
            dialogCreate -name file_exists_newer_warn \
                         -title "$title" \
                         -parent $ctrlVals(parentDialog) \
                         -nocontexthelp \
                         -init fileExistsNewerWarnInit \
                         -exit fileExistsNewerWarnExit \
                         -w 225 -h 130 \
                         -controls $controls
            return $retvalNew
        }
        ok {
            switch [messageBox -ok -information $message] {
                ok { return 0 }
            }
        }
        ok_cancel {
            switch [messageBox -okcancel -questionicon $message] {
                ok     { return 0 }
                cancel { return 1 }
            }
        }
        proceed_cancel {
            switch [messageBox -proceedcancel -questionicon $message] {
                proceed { return 0 }
                cancel  { return 1 }
            }
        }
    }
}

#############################################################################
#
# messageBox - Display the message box dialog
#
# This procedure is intended to replace the messageBox method from UITclSh.
# The one from UITclSh has problem displaying the button text. This messageBox
# procedure will display NO icon. It only displays text and buttons.
#
# SYNOPSIS
# .tS
# messageBox <option> msg
# .tE
#
# PARAMETERS: 
#        -ok        with OK button
#        -okcancel  with OK and Cancel buttons
#        -yesno     with Yes and No buttons
#        -stop      with OK button (same as -ok)
#        -abortretryignore    with Abort, Retry and Ignore buttons
#        -retrycancel         with Retry and Cancel buttons
#        -proceed_cancel      with Proceed and Cancel buttons
#
# RETURNS: the parameters values
#
# 

proc messageBox {args} {
    global ctrlVals

    set message [lindex $args end]
    set title "Setup"
    set buttons ""
    set msgBoxOption "ok"
    set retVal ""

    # determine option
    foreach var $args {
        switch -exact -- $var {
            -yesnocancel {set msgBoxOption "yesnocancel"}
            -okcancel {set msgBoxOption "okcancel"}  
            -proceedcancel {set msgBoxOption "proceedcancel"}  
            -yesno {set msgBoxOption "yesno"} 
            -stop {set msgBoxOption "stop"} 
            -abortretryignore {set msgBoxOption "abortretryignore"} 
            -retrycancel {set msgBoxOption "retrycancel"} 
            -ok {set msgBoxOption "ok"}
            default {
                if [regexp {^[a-zA-Z0-9]} $var] {
                    set message $var
                }
            }
        }
    }

    dbgputs "option: $msgBoxOption"

    # set dialog size
    set width 200
    set xpos [expr ($ctrlVals(screenW) / 2) - ($width / 2)]
    set temp $message
    set temp [split $temp " "]
    set numLF 0
    foreach elem $temp {
        if {[string first "\n" $elem] != -1} {
            incr numLF
        }
    }
        
    set height [expr 7 + 25 + (10 * [expr [string length $message]/55 + 1])]        
    set height [expr $height + ($numLF * 10)]
    set ypos [expr ($ctrlVals(screenH) / 2) - ($height / 2)]
        

    # set dialog controls
    set controls [list \
        [list label -name message -title $message \
                    -x 10 -y 10 -w 186 \
                    -h [expr ($numLF * 10) + \
                        (10 * [expr [string length $message]/55 + 1])]]
        ]
        
        switch -- $msgBoxOption {
                stop -
                ok {
                    lappend controls \
                            [list button -name ok -title "&OK" \
                                         -callback {windowClose msgBoxDialog; 
                                             set retVal "ok"} \
                                         -x 75 -y [expr $height -5 -14] -w 50 -h 14]
                }
                okcancel {
                    lappend controls \
                            [list button -name ok -title "&OK" \
                                         -callback {windowClose msgBoxDialog; 
                                             set retVal "ok"} \
                                         -x 45 -y [expr $height -5 -14] -w 50 -h 14] \
                            [list button -name cancel -title "&Cancel" \
                                         -callback {windowClose msgBoxDialog;
                                             set retVal "cancel"} \
                                         -x 105 -y [expr $height -5 -14] -w 50 -h 14]
                }                
                proceedcancel {
                    lappend controls \
                            [list button -name proceed -title "&Proceed" \
                                         -callback {windowClose msgBoxDialog; 
                                                    set retVal "proceed"} \
                                         -x 45 -y [expr $height -5 -14] -w 50 -h 14] \
                            [list button -name cancel -title "&Cancel" \
                                         -callback {windowClose msgBoxDialog;
                                                    set retVal "cancel"} \
                                         -x 105 -y [expr $height -5 -14] -w 50 -h 14]
                }
                yesno {
                    lappend controls \
                            [list button -name yes -title "&Yes" \
                                         -callback {windowClose msgBoxDialog; 
                                                    set retVal "yes"} \
                                         -x 45 -y [expr $height -5 -14] -w 50 -h 14] \
                            [list button -name no -title "&No" \
                                         -callback {windowClose msgBoxDialog;
                                                    set retVal "no"} \
                                         -x 105 -y [expr $height -5 -14] -w 50 -h 14]
                }
                retrycancel {
                    lappend controls \
                            [list button -name retry -title "&Retry" \
                                         -callback {windowClose msgBoxDialog; 
                                                    set retVal "retry"} \
                                         -x 45 -y [expr $height -5 -14] -w 50 -h 14] \
                            [list button -name cancel -title "&Cancel" \
                                         -callback {windowClose msgBoxDialog;
                                                    set retVal "cancel"} \
                                         -x 105 -y [expr $height -5 -14] -w 50 -h 14]
                }
                abortretryignore {
                    lappend controls \
                            [list button -name abort -title "&Abort" \
                                         -callback {windowClose msgBoxDialog; 
                                                    set retVal "abort"} \
                                         -x 15 -y [expr $height -5 -14] -w 50 -h 14] \
                            [list button -name retry -title "&Retry" \
                                         -callback {windowClose msgBoxDialog;
                                                    set retVal "cancel"} \
                                         -x 75 -y [expr $height -5 -14] -w 50 -h 14] \
                            [list button -name ignore -title "&Ignore" \
                                         -callback {windowClose msgBoxDialog;
                                                    set retVal "ignore"} \
                                         -x 135 -y [expr $height -5 -14] -w 50 -h 14]
                }
                yesnocancel {
                    lappend controls \
                            [list button -name yes -title "&Yes" \
                                         -callback {windowClose msgBoxDialog; 
                                                    set retVal "yes"} \
                                         -x 15 -y [expr $height -5 -14] -w 50 -h 14] \
                            [list button -name no -title "&No" \
                                         -callback {windowClose msgBoxDialog;
                                                    set retVal "no"} \
                                         -x 75 -y [expr $height -5 -14] -w 50 -h 14] \
                            [list button -name cancel -title "&Cancel" \
                                         -callback {windowClose msgBoxDialog;
                                                    set retVal "cancel"} \
                                         -x 135 -y [expr $height -5 -14] -w 50 -h 14]
                }
        }

    #puts $controls 

    dialogCreate -name msgBoxDialog \
                 -nocontexthelp \
                 -title "$title" \
                 -parent $ctrlVals(parentDialog) \
                 -x $xpos -y $ypos \
                 -w $width -h $height \
                 -controls $controls

    return $retVal
}


#############################################################################
#
# quitCallback - callback procedure invoked when cancel button is pushed
#
# This procedure is a callback procedure invoked when cancel button is pushed
#
# SYNOPSIS
# .tS
# quitCallback
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: 0 if user decides to resume installation
#         1 if user decides to quit
#

proc quitCallback {} {
    global setupVals
    global ctrlVals
    global setupPageList
    global LMHelpPath

    set lmPages [concat {lmOptions}\
                        $setupPageList(lmExit)\
                        $setupPageList(autoInst)\
                        $setupPageList(email)\
                        $setupPageList(phone)\
                        $setupPageList(floatLicInst)\
                        $setupPageList(endUser)\
                        $setupPageList(nodeLock)]

    if { [lsearch -exact $lmPages $ctrlVals(currPage)] != -1 } {
        if { [string match "float" $LMHelpPath] ||
             [string match "nodelock" $LMHelpPath] } {
            set msg [strTableGet 1360_LM_QUIT_CALLBACK]
        } elseif { [string match "sysadmin" $LMHelpPath] } {
            set msg [strTableGet 1360_LMINST_QUIT_CALLBACK]
        }
    } else {
        set msg [strTableGet 1360_QUIT_CALLBACK]
    }

    if {"$setupVals(cancel)" != "1"} {
        switch [dialog resume_exit "Setup" $msg] {
            0 {
                return 0
            }
            1 {
                set setupVals(cancel) 1

                catch {uninstLog setupLog "\tUser aborted!"}

                if {"filesCopy" != "$ctrlVals(currPage)"} {
                    applicationExit
                }

                return 1
            }
        }
    }
}

#############################################################################
#
# onTextChange - set the variable in setupVals when text in edit box is changed
#
# This procedure will  set the variable in setupVals when text in edit box
# is changed
#
# SYNOPSIS
# .tS
# onTextChange <control> <var>
# .tE
#
# PARAMETERS:
# .IP control
# name of the control
# .IP var
# variable to be set
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc onTextChange {control var} {
    global ctrlVals
    global setupVals

    set setupVals($var) [controlValuesGet $ctrlVals(mainWindow).$control]
}

#############################################################################
#
# uninstallInitWin32 - set up the uninstall process
#
# This procedure will copy files to the user directory necessary to run
# uninstall.
#
# SYNOPSIS
# .tS
# uninstallInitWin32
# .tE
#
# PARAMETERS:
#     prodName -- product name e.g. Tornado
#     prodVer -- product version e.g. 3.0
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc uninstallInitWin32 {prodName prodVer} {
    global ctrlVals

    if { [isTornadoProduct] } {
        # e.g. TornadoV3.0
        set keyStr "${prodName}V${prodVer}"
    } else {
        set keyStr "[getProdInfo name]V[getProdInfo version]"
    }

    beginWaitCursor

    set binDir "[destDirGet]\\SETUP\\X86\\WIN32"
    set windBase [dosToUnix "[destDirGet]"]
    set uninstTcl [dosToUnix "[uninstHomeDirGet]\\UNINST.TCL"]

    # On 95 and NT4 create the registry entries for uninstall if they don't
    # already exist, else just increment the value of share count

    if {$ctrlVals(version) != "NT3x"} {
        set subKey "SOFTWARE\\Microsoft\\Windows\\CurrentVersion"
        regKeyCreateLog HKEY_LOCAL_MACHINE $subKey Uninstall noLog

        # Uninstall entries need to be added
        set subKey "SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall"
        regKeyCreateLog HKEY_LOCAL_MACHINE $subKey $keyStr

        regValueWriteLog HKEY_LOCAL_MACHINE "$subKey\\$keyStr" \
                                DisplayName "$prodName Version $prodVer"

        regValueWriteLog HKEY_LOCAL_MACHINE "$subKey\\$keyStr" \
                                UninstallString \
                                "$binDir\\UITCLSH.EXE $uninstTcl \
                                $windBase -seed"
     }

     # create an uninstall icon

     if { ![isBSPcd] } {
         folderCreateLog [defGroupGet] $ctrlVals(admin)

         fileDup "[cdromRootDirGet]\\RESOURCE\\BITMAPS\\REMOVE.ICO" \
                 "[destDirGet]\\.wind\\uninst\\REMOVE.ICO"

         linkCreateLog \
                [defGroupGet] \
                "[getProdInfo name] Uninstall" \
                "$binDir\\UITCLSH.EXE" \
                "$uninstTcl $windBase -seed" \
                $binDir \
                $ctrlVals(admin) 0 0 \
                "[destDirGet]\\.wind\\uninst\\REMOVE.ICO"
     }

     endWaitCursor
}

#############################################################################
#
# meterCreate - create the meter control
#
# This procedure will create the meter control
#
# SYNOPSIS
# .tS
# meterCreate
# .tE
#
# PARAMETERS:
# .IP msg
# message to be printed when meter is running
#
# RETURNS: 1 if successful
#
# ERRORS: N/A
#

proc meterCreate {msg} {
   global ctrlVals
   global setupVals
   global env

   set ctrlVals(meterWg) "meterCtrl"
   set ctrlVals(meterTagWg) "fileName"

   set msgHeight [expr 10 + (10 * [string length $msg]/55)]

   if {$ctrlVals(numBbrd) == "0"} {

       set ctrlVals(volatileFrm) [list \
               [list label -name message -title $msg \
                           -x 100 -y 10 -w 205 -h $msgHeight] \
               [list label -name $ctrlVals(meterTagWg) \
                           -x 100 -y 120 -w 195 -h 10] \
               [list progressmeter -center -name $ctrlVals(meterWg) \
                           -x 100 -y 138 -w 205 -h 10] \
       ]

       set ctrlVals(meterWindow) $ctrlVals(mainWindow)
       set ctrlVals(bbrdElapse)  101
   } elseif {[removeBackground]} {

       set bbrdW $ctrlVals(bbrdW)
       set bbrdH $ctrlVals(bbrdH)

       set dlg_orig_w [lindex $ctrlVals(dlg_orig_size) 0]
       set right_border [expr $dlg_orig_w - 10]

       set dimension [pixelsToDialogUnits $ctrlVals(mainWindow) \
                        [list $bbrdW $bbrdH]]
       set bbrdW [lindex $dimension 0]
       set bbrdH [lindex $dimension 1]


       if {[info exists env(SETUP_USEKDE)]} {
           set bitmap_ypos 10
       } else {
           set bitmap_ypos 40
       }

       # relative to the bitmap position
       set labely [expr $bbrdH + $bitmap_ypos + 10]
       set metery [expr $labely + 12]

       if {[info exists env(SETUP_USEKDE)]} {
           set meterw [expr $right_border - 10]
       } else {
           set meterw $bbrdW
       }

       if {[info exists env(SETUP_USEKDE)]} {
           # center the bitmap

           set bitmap_xpos [expr [expr $dlg_orig_w - $bbrdW] / 2]
           set label_ypos 15
       } else {
           set bitmap_xpos 10
           set label_ypos 10
       }

       # no top directory message for KDE

       if {[info exists env(SETUP_USEKDE)]} {
           if { [windHostTypeGet] == "x86-linux2" } {
               set ctrlVals(volatileFrm) [list \
                   [list bitmap -name bbrd -title [lindex $ctrlVals(bbrdList) 0] \
                    -x $bitmap_xpos -y $bitmap_ypos -stretch -w $bbrdW -h $bbrdH] \
                   [list label -name $ctrlVals(meterTagWg) \
                                   -x 10 -y $labely -w [expr $meterw-10] -h 10] \
                   [list progressmeter -center -name $ctrlVals(meterWg) \
                                   -x 10 -y $metery -w $meterw -h 10] \
               ]
           } else {
               set ctrlVals(volatileFrm) [list \
                   [list bitmap -name bbrd -title [lindex $ctrlVals(bbrdList) 0] \
                    -x $bitmap_xpos -y $bitmap_ypos -stretch -w $bbrdW -h $bbrdH] \
                   [list label -name $ctrlVals(meterTagWg) \
                                   -x 10 -y $labely -w [expr $meterw-10] -h 10] \
                   [list progressmeter -center -name $ctrlVals(meterWg) \
                                   -x 10 -y $metery -w $meterw -h 10] \
               ]
          }
       } else {
           if { [windHostTypeGet] == "x86-linux2" } {
               set ctrlVals(volatileFrm) [list \
                   [list label -name message -title $msg \
                                   -x 10 -y $label_ypos -w 205 -h $msgHeight] \
                   [list bitmap -name bbrd -title [lindex $ctrlVals(bbrdList) 0] \
                    -x $bitmap_xpos -y $bitmap_ypos -stretch -w $bbrdW -h $bbrdH] \
                   [list label -name $ctrlVals(meterTagWg) \
                                   -x 10 -y $labely -w [expr $meterw-10] -h 10] \
                   [list progressmeter -center -name $ctrlVals(meterWg) \
                                   -x 10 -y $metery -w $meterw -h 10] \
               ]
           } else {
               if { [windHostTypeGet] == "x86-linux2" } {
                   set ctrlVals(volatileFrm) [list \
                       [list label -name message -title $msg \
                                   -x 10 -y $label_ypos -w 205 -h $msgHeight] \
                       [list bitmap -name bbrd -title \
                                [lindex $ctrlVals(bbrdList) 0] \
                                -x $bitmap_xpos -y $bitmap_ypos -stretch -w \
                                $bbrdW -h $bbrdH] \
                       [list label -name $ctrlVals(meterTagWg) \
                                -x 10 -y $labely -w [expr $meterw-10] -h 10] \
                       [list progressmeter -center -name $ctrlVals(meterWg) \
                                -x 10 -y $metery -w $meterw -h 10] \
                   ]
               } else {
                   set ctrlVals(volatileFrm) [list \
                       [list label -name message -title $msg \
                                   -x 10 -y $label_ypos -w 205 -h $msgHeight] \
                       [list bitmap -name bbrd -title \
                                [lindex $ctrlVals(bbrdList) 0] \
                                -x $bitmap_xpos -y $bitmap_ypos -stretch -w \
                                $bbrdW -h $bbrdH] \
                       [list label -name $ctrlVals(meterTagWg) \
                                -x 10 -y $labely -w [expr $meterw-10] -h 10] \
                       [list progressmeter -center -name $ctrlVals(meterWg) \
                                -x 10 -y $metery -w $meterw -h 10] \
                   ]
              }
           }
       }

       set ctrlVals(meterWindow) $ctrlVals(mainWindow)
       set ctrlVals(bbrdWindow)  $ctrlVals(mainWindow)
       set ctrlVals(nextBbrd) 0

   } else {
       windowShow $ctrlVals(mainWindow) 0

       for {set i 0} {$i < 1000} {incr i} {
           uiEventProcess
       }

       set ctrlVals(volatileFrm) {}
       set ctrlVals(nextBbrd) 0
       set ctrlVals(meterWindow) "meterWindow"
       set ctrlVals(bbrdWindow)  "bbrdWindow"

       set bbrdW $ctrlVals(bbrdW)
       set bbrdH $ctrlVals(bbrdH)

       set dimension [pixelsToDialogUnits $ctrlVals(backgroundWindow) \
                        [list $bbrdW $bbrdH]]
       set bbrdW [lindex $dimension 0]
       set bxpos [expr ($ctrlVals(screenW) - $bbrdW) / 2]

       set bbrdH [lindex $dimension 1]
       set bypos [expr (($ctrlVals(screenH) - $bbrdH) / 2)]

       set controls(bbrd) [list \
            [list bitmap -name bbrd -title [lindex $ctrlVals(bbrdList) 0] \
                     -x 0 -y 0 -stretch -w $bbrdW -h $bbrdH] \
            ]

       set meterWidth 222
       set xpos [expr $ctrlVals(screenW) - $meterWidth - 10]

       set meterHeight 54
       set ypos [expr $ctrlVals(screenH) - $meterHeight - 25]

       set controls(meter) [list \
            [list label -name $ctrlVals(meterTagWg) \
                        -x 7 -y 5 \
                        -w 195 -h 10] \
            [list progressmeter -center -name $ctrlVals(meterWg) \
                        -x 7 -y 19 \
                        -w 211 -h 13 ] \
            [list button -name cancel -title "&Cancel" \
                        -callback quitCallback \
                        -x 87 -y 36 \
                        -w 50 -h 14] \
       ]

       dialogCreate -name $ctrlVals(meterWindow) \
                    -nocontexthelp \
                    -modeless \
                    -notitle \
                    -parent $ctrlVals(parentDialog) \
                    -x $xpos -y $ypos \
                    -w $meterWidth -h $meterHeight \
                    -controls $controls(meter)

       windowPositionSet $ctrlVals(meterWindow) $xpos $ypos

       set ctrlVals(parentDialog) $ctrlVals(meterWindow)
       windowQueryCloseCallbackSet $ctrlVals(meterWindow) quitCallback

       dialogCreate -name $ctrlVals(bbrdWindow) \
                    -nocontexthelp \
                    -noframe -notitle -modeless \
                    -parent $ctrlVals(parentDialog) \
                    -x $bxpos -y $bypos \
                    -w $bbrdW -h $bbrdH \
                    -controls $controls(bbrd)

       windowPositionSet $ctrlVals(bbrdWindow) $bxpos $bypos
       set ctrlVals(parentDialog) $ctrlVals(bbrdWindow)

       return 1
   }
}

#############################################################################
#
# meterUpdate - update the meter
#
# This procedure will update the meter based on percent and the tag name
#
# SYNOPSIS
# .tS
# meterUpdate <percent> <tag>
# .tE
#
# PARAMETERS:
# .IP percent
# percentage of files that have been installed
# .IP tag
# name of the file being installed
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc meterUpdate {percent tag} {
    global ctrlVals
    global setupVals

    if { $setupVals(cmdMode) != "text" } {

        controlValuesSet $ctrlVals(meterWindow).$ctrlVals(meterWg) $percent
        controlValuesSet $ctrlVals(meterWindow).$ctrlVals(meterTagWg) \
                            [fileNameAbbreviate $tag 40]
        uiEventProcess

    } else { # TEXT mode 

        puts "$percent%\t $tag"

    }        
}

#############################################################################
#
# meterDestroy - remove the meter
#
# This procedure will remove the meter
#
# SYNOPSIS
# .tS
# meterDestroy <meterW>
# .tE
#
# PARAMETERS:
# .IP meterW
# the handle for the meter control
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc meterDestroy {meterW} {
    global ctrlVals

    if {$meterW != $ctrlVals(mainWindow)} {

        if [catch {windowClose $meterW} error] {
            puts "error on closing $meterW: $error"
        }

        if [catch {windowClose $ctrlVals(bbrdWindow)} error] {
            puts "error when closing bbrdWindow: $error"
        }

        set ctrlVals(volatileFrm) {}
        windowShow $ctrlVals(mainWindow) 1
        set ctrlVals(parentDialog) $ctrlVals(mainWindow)
    }
}


#############################################################################
#
# needUpdate - test if patches need to be applied to the user system
#
# This procedure will test if patches need to be applied to the user system
#
# SYNOPSIS
# .tS
# needUpdate <fileName>
# .tE
#
# PARAMETERS:
# .IP fileName
# file to be used for determining whether patches need be applied
#
# RETURNS: 1 if update is needed
#          0 if update is not needed
#
# ERRORS: N/A
#

proc needUpdate {fileName} {

    if { "$fileName" == "COMCTL32.DLL" } {
        set wrsVersion 4.72.3110.9
    } elseif { "$fileName" == "OLE32.DLL" } {
        set wrsVersion 4.71.2618
    }

    set userFile [file join [sysDirGet] $fileName]

    if {[file exists $userFile] &&  \
        [catch {setupFileVersionInfoGet $userFile} userVersion]} {
        set error $userVersion
        dbgputs "Error: Cannot get file version of $userFile"
    } elseif ![file exists $userFile] {
        set error "$fileName is not currently installed on the system"
        dbgputs "Error: $error"
    }

    if {[info exists error] || $userVersion < $wrsVersion} {
        return 1
    } else {
        return 0
    }
}

#############################################################################
#
# windowsSystemCheck - check for Tornado requirements on Windows
#
# This procedure will check if the user's system has the following installed:
# TCP-IP, DCOM95, and 401comupd; otherwise, Setup will ask these patches
# to be installed.
#
# SYNOPSIS
# .tS
# windowsSystemCheck
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: 1 if patches are successfully installed
#          0 if patches are not successfully installed
#
# ERRORS: N/A
#

proc windowsSystemCheck {} {

    global ctrlVals

    # detects if the system has TCP-IP installed

    if {"[info hostname]" == "" } {

        if { $ctrlVals(useInputScript) } {
            autoSetupLog "[strTableGet 1095_WARN_NO_TCPIP]"
            autoSetupLog "Application Exit\n"
            set setupVals(cancel) 1                
            applicationExit
        } else {
            messageBox -ok -stopicon [strTableGet 1095_WARN_NO_TCPIP]
        }
        return 0
    }
    return 1
}

#############################################################################
#
# autoSetupLog - put message in setup log file for test automation
#
# This procedure will put message in setup log file for test automation
#
# SYNOPSIS
# .tS
# autoSetupLog <msg>
# .tE
#
# PARAMETERS:
# .IP msg
# message to be inserted in setup log file for test automation
#
# RETURNS: N/A
#
# ERRORS: -1 if unsuccessful
#
# #### Moved to INSTW32.TCL ####
#
#
#proc autoSetupLog {msg} {
#    global autoSetupLogFile
#
#    if [catch {open $autoSetupLogFile a+} file] {
#       puts "Error in writing $autoSetupLogFile"
#       return -1
#    }
#    puts $file "[getDate]: $msg"
#    close $file
#}


#############################################################################
#
# windBaseReadFromRegistry - read WIND_BASE value from registry and set
#                            it as default installation location
#
# This procedure will read WIND_BASE value from registry and set
# it as default installation location
#
# SYNOPSIS
# .tS
# windBaseReadFromRegistry
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc windBaseReadFromRegistry {} {
    global setupVals

    if { ![isStandAlone] && ![isWRSStandAlone] } {

        # Initialize wind_base from registry 
        if {"[destDirGet]" == ""} {
            if {![catch {sysRegistryValueRead HKEY_CURRENT_USER \
                                   "Software\\$setupVals(WRS)" "WIND_BASE"} destDir]} {
                destDirSet $destDir

            } elseif {![catch {sysRegistryValueRead HKEY_LOCAL_MACHINE \
                                   "Software\\$setupVals(WRS)" "WIND_BASE"} destDir]} {
                destDirSet $destDir
            } else {
                if {[windHostTypeGet] == "x86-win32"} {
                    destDirSet $setupVals(defDestDirWin32)
                } else {
                    destDirSet $setupVals(defDestDirUnix)
                }
            }
        }
    } else {
        if {"[destDirGet]" == ""} {
            if {[windHostTypeGet] == "x86-win32"} {
                destDirSet $setupVals(defDestDirWin32)
            } else {
                destDirSet $setupVals(defDestDirUnix)
            }
        }
    }
}

#############################################################################
#
# calcPage - return the difference in the desired page index and the current
#            page index
#
# This procedure will return the difference in the desired page index and
# the current page index
#
# SYNOPSIS
# .tS
# calcPage <desiredPage>
# .tE
#
# PARAMETERS:
# .IP desiredPage
# page name of wizard to go next
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc calcPage {desiredPage} {
    global ctrlVals

    # jump to the desired page

    set desiredIndex [lsearch $ctrlVals(pageList) $desiredPage]
    set currentPageIndex [lsearch $ctrlVals(pageList) $ctrlVals(currPage)]
    set retval [expr $desiredIndex - $currentPageIndex]
    return $retval
}


#############################################################################
#
# sendToALD - send request to License Daemon 
#
# This routine sends requests to license daemon  and get the 
# requested license information back
#
# SYNOPSIS
# .tS
# sendToALD
# .tE
#
# PARAMETERS: 
#    code - requested code
#    string  - requested string
#
# RETURNS: license Info string body or a code indicating to retry the
# command (0) or use another means other than automated license (1).
#
# ERRORS: N/A
#
proc sendToALD {code string} {
    global setupVals lmVals
    global LicFileConfigRequest

    set retVal ""
    set body ""
    set host monocacy
    set port 5555
    set licGetAllCgi     $lmVals(licGetAllCgi)
    set licFileConfigCgi $lmVals(licFileConfigCgi)
    set ackCommitCgi     $lmVals(ackCommitCgi)
    set authorizePINCgi  $lmVals(authorizePINCgi)

    if { $setupVals(cmdMode) != "text"} {
        set guiMode 1
    } else {
        set guiMode 0
    }

    dbgputs "sendToALD: request is $code $string"
                
    if {$guiMode} {  beginWaitCursor  }

    # test if the connection failed or if the server is down.
    if {[catch {socket $lmVals(cgiHost) $lmVals(cgiHostPort)} s]} {
        set errCode "-40000040"
        set errMsg [processErrorCode $errCode]
        set retVal [errorDlg "Automated License Error" $errMsg]

        if {$guiMode} {  endWaitCursor  }

        return $retVal

    } else {
        flush $s
        
        if {$guiMode} {  endWaitCursor  }

    }

    if {$guiMode} {  beginWaitCursor  }
        
    switch $code {
               
           1 { 
               # 1 - licInfoGetAll
               # set the value passted to the cgi script in key=value format.
               # Using POST to call the cgi script
               # string format: <WRSLicense>|<VersionNumber>
               set tmpStr [split $string "|"]

               set WRSLicense [lindex $tmpStr 0]
               set VersionNumber [lindex $tmpStr 1]

               set data [http_formatQuery \
                            WRSLicense $WRSLicense \
                            VersionNumber $VersionNumber \
                            host $host \
                            port $port]
               set lmVals(httpToken) [http_get $licGetAllCgi -query $data]

           } 2 { 

               # 2 - licFileConfig
               # set the value passted to the cgi script in key=value format.
               # Using POST to call the cgi script
               # string format <wrsLic>|<versionNumber>|<licType>|<hostRec>
               # <hostRec>=host|hostid|port|[feature:prcode:numlic]
               set tmpStr [split $string "|"]
                        
               set WRSLicense [lindex $tmpStr 0]
                           set VersionNumber [lindex $tmpStr 1]
                           set licenseType [lindex $tmpStr 2]
               set hostRec [join [lrange $tmpStr 3 end] "|"]
                        
               set data [http_formatQuery \
                            WRSLicense $WRSLicense \
                            VersionNumber $VersionNumber \
                            licenseType $licenseType \
                            hostRec $hostRec \
                            host $host \
                            port $port]

               set lmVals(httpToken) [http_get $licFileConfigCgi -query $data]

           } 3 {
        
               # 3 - ackCommit
               # set the value passted to the cgi script in key=value format.
               # Using POST to call the cgi script
               # string format <wrsLic>|<versionNumber>|<token>|<userName>|
               #        <userPhone>|<userEmail>|<requestSource>|<licenseType>|
               #    <hostRec>
               set tmpStr [split $string "|"]
                           
               set WRSLicense [lindex $tmpStr 0]
                           set VersionNumber [lindex $tmpStr 1]
               set token [lindex $tmpStr 2]
               set userName [lindex $tmpStr 3]
                           set userPhoneNumber [lindex $tmpStr 4]
                           set userEmailAddress [lindex $tmpStr 5]
                           set requestSource [lindex $tmpStr 6] 
                           set licenseType [lindex $tmpStr 7]
                           set hostRec [join [lrange $tmpStr 8 end] "|"]
                        
               set data [http_formatQuery \
                            WRSLicense $WRSLicense \
                            VersionNumber $VersionNumber \
                            token $token \
                            userName $userName \
                            userPhoneNumber $userPhoneNumber \
                            userEmailAddress $userEmailAddress \
                            requestSource $requestSource \
                            licenseType $licenseType \
                            hostRec $hostRec \
                            host $host \
                            port $port]

               set lmVals(httpToken) [http_get $ackCommitCgi -query $data]

           } 4 {

               # 4 - authorizePIN
               # set the value passted to the cgi script in key=value format.
               # Using POST to call the cgi script
               # string format: <WRSLicense>|<pin>
               set tmpStr [split $string "|"]
                        
               set WRSLicense [lindex $tmpStr 0]
               set pin [lindex $tmpStr 1]
               set token [lindex $tmpStr 2]
                        
               set data [http_formatQuery WRSLicense $WRSLicense \
                           pin $pin token $token \
                           host $host \
                           port $port]

               set lmVals(httpToken) [http_get $authorizePINCgi -query $data]

           } 5 {
               # 5 - licInfoGetAll2
               # set the value passted to the cgi script in key=value format.
               # Using POST to call the cgi script
               # string format: <WRSLicense>|<VersionNumber>
               set tmpStr [split $string "|"]

               set WRSLicense [lindex $tmpStr 0]
               set VersionNumber [lindex $tmpStr 1]

               set data [http_formatQuery \
                            WRSLicense $WRSLicense \
                            VersionNumber $VersionNumber \
                            host $host \
                            port $port]

               set lmVals(httpToken) [http_get $licGetAllCgi -query $data]

           } default {

               if {$guiMode} {  endWaitCursor  }

               return "Error: Unknown requested code"
           }
    }

    set body [http_data $lmVals(httpToken)]
        
    if {$guiMode} {  endWaitCursor  }
        
    dbgputs "sendToALD: reply is $body"
        
    # if the returned value starts with '-', a negative, then handle the 
    # error return either the correct message body or a value indicating
    # retry or choose another means of getting the license. Error code is 8
    # digit long e.g. -12193022
    #
    # if the return value is a block of HTML code containing "Server Error",
    # then return an error. This is a internal server error,
    # (error code 500). That means the web or ALD is down.

    if {[regexp {^Error:*} $body match]} {
        regexp {(-[0-9]*)} $body match errCode

        set errMsg [processErrorCode $errCode]
        set retVal [errorDlg "Automated License Error" $errMsg]
        return $retVal
        
    } elseif { [regexp {Server Error} $body match]} {
        set retVal [serverErrorDlg]
        return $retVal
    }            
    return $body
}

proc processErrorCode {errCode} {
    global setupVals
    
    set category "Unknown"
    set errMsg ""                                                
   
    set cat      [string range [expr abs($errCode)] 0 1]
    set errType  [string range [expr abs($errCode)] 6 7]
    
    dbgputs "errType:  $errType"
    
    switch -regexp -- $cat {
        ^1[0-9]* -
        ^2[0-9]* {
            set category "Database"
            set errMsg [processDbError $errType]
        }
        ^3[0-9]* {
            set category "License Daemon"
            set errMsg [processALDError $errType]
        }
        ^4[0-9]* {
            set category "Web/CGI"
            set errMsg [processCGIError $errType]
        }
        default {
            set category "Unknown"
            set errMsg "Unknown Error"
        } 
    }
   
    set str ""
    append str "WRS License: $setupVals(WRSLicense)"
    append str "\r\n"
    append str "Category: $category"
    append str "\r\n"
    append str "Error code: $errCode"
    append str "\r\n\r\n"
    append str "$errMsg"
    #append str "\r\n\r\n"
    append str "[strTableGet LICENSE_ADMIN_MSG]"
    
    dbgputs $str
    return $str
    
}

proc processDbError {code} {
    set msg ""
    switch -exact $code {
    
        01 {
            set msg "Default license error" 
        }
        02 {
            set msg "Default failed return" 
        }
        10 {
            set msg "Oracle exception"
        }
        11 {
            #set msg "Default nonqualify"
            set msg [strTableGet DB_ERROR_11]
        }
        16 {
            set msg "Missing dates"
        }
        17 {
            set msg "Out of date range"
        }
        20 {
            set msg "Default invalid data"
        }
        21 {
            set msg "Null data found in field"
        }
        22 {
            set msg [strTableGet DB_ERROR_22] 
        }
        23 {
            set msg [strTableGet DB_ERROR_23] 
        }
        25 {
            set msg "Data out of sync"
        }
        30 {
            set msg [strTableGet DB_ERROR_30]
        }
        31 {
            set msg [strTableGet DB_ERROR_31]
        }
        40 {
            set msg "Default duplicate error"
        }
        41 {
            set msg "Mulitiple rows found identical"
        }
        45 {
            set msg [strTableGet DB_ERROR_45]
        }
        47 {
            set msg [strTableGet DB_ERROR_47]
        }
        48 {
            set msg [strTableGet DB_ERROR_48]
        }
        50 {
            set msg "Negative seats added"
        }
        51 {
            set msg [strTableGet DB_ERROR_51]
        }
        52 {
            set msg [strTableGet DB_ERROR_52]
        }
        53 {
            set msg [strTableGet DB_ERROR_53]
        }
        default {set msg [strTableGet DB_ERROR_UNKNOWN]}
    }
    
    return $msg

}

proc processCGIError {code} {
    set msg ""
    switch -exact $code {

        30 { 
            # can't connect to ALD, 30
            set msg "[strTableGet CGI_ERROR_30]"
        }   
        31 { 
            # invalid PIN, 31
            set msg "[strTableGet CGI_ERROR_31]" 
        }
        32 { 
            # invalid parameters, 32
            set msg "[strTableGet CGI_ERROR_32]"
        }
        40 { 
            # can't connect to www.wrs.com
            set msg "[strTableGet CGI_ERROR_40]"
        }

        default {set msg "Unknown Web/CGI Error"}
    }
    
    return $msg

}

proc processALDError {code} {
    set msg ""
    switch -exact $code {

        50 { 
            #invalid parameters, 50
            set msg [strTableGet ALD_ERROR_50]
        }   
        51 { 
            # can't connect to db, 51
            set msg [strTableGet ALD_ERROR_51]
        }
        52 { 
            # invalid data returned from db, 52
            set msg [strTableGet ALD_ERROR_52]
        }
        default {set msg "Unknown ALD Error"}
    }

    return $msg
}

#############################################################################
#
# errorDlg - puts up an common error dialog for user response to 
#            errors
#
# This routine puts up an error dialog to inform the user of an error that
# prevents a transaction from completing.
#
# SYNOPSIS
# .tS
# errorDlg message
# .tE
#
# PARAMETERS: message - the error message to display.
#    
# RETURNS:  0 to retry, 1 to try alternative means of getting the license file
#
# ERRORS: N/A
#

proc errorDlg {title message} {
    global ctrlVals errorRetVal
    global setupVals
    global messageText

    set messageText $message

    if { $setupVals(cmdMode) != "text" } {

        set width 210
        set height 118
        set dlgHeight 180
        set xpos [expr ($ctrlVals(screenW) / 2) - ($width / 2)]
        set ypos [expr ($ctrlVals(screenH) / 2) - ($height / 2)]

        set controls [list \
            [list text  -name message -vscroll -readonly -multiline \
                        -x 10 -y 10 -w 190 -h 103] \
            [list label -name message2 -title [strTableGet ERROR_MSG_COMMON] \
                        -x 10 -y 118 -w 190 -h 34] \
            [list button -name errorRetry -title "&Retry" \
                         -callback {errorDlgReturn 0} \
                         -x 25 -y [expr $dlgHeight -7 -14] -w 50 -h 14] \
            [list button -name errorCancel -title "&Cancel" \
                         -callback {errorDlgReturn 1} \
                         -x 125 -y [expr $dlgHeight -7 -14] -w 50 -h 14] \
        ]

        dialogCreate -name errorDlg \
                     -title "$title" \
                     -nocontexthelp \
                     -init {global messageText 
                            setMessageDlg $messageText} \
                     -parent $ctrlVals(parentDialog) \
                     -w $width -h $dlgHeight \
                     -controls $controls

        return $errorRetVal

    } else { # text mode 
 
        printPageTitle $title
        puts "$message\n"
        puts [strTableGet ERROR_MSG_COMMON_TEXT]
        set ret [prompt]

        if { $ret == "retry" } {
            errorDlgReturn 0
        } else { 
            errorDlgReturn 1
        }

        return $errorRetVal
    }
}

proc errorDlgReturn {value} {
    global errorRetVal
    global setupVals
 
    set errorRetVal $value
    dbgputs "errorDlgReturn: value is $errorRetVal"

    if { $setupVals(cmdMode) != "text" } {
        windowClose errorDlg
    }
}

proc setMessageDlg {message} {
    controlTextInsert errorDlg.message $message
} 


#############################################################################
#
# serverErrorDlg - puts up an error dialog for Server Error
#
# This routine puts up an error dialog to inform the user of a Server
# error during the connection to WRS web server. Most likely the server is down
# The user can choose either to retry or go try alternative means of obtaining
# a license file for Flexlm license management.
#
# SYNOPSIS
# .tS
# serverErrorDlg
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: 0 to retry, 1 to try alternative means of getting the license file
#
# ERRORS: N/A
#

proc serverErrorDlg {} {
    global setupVals
        
    dbgputs "serverErrorDlg"
    return [errorDlg "[strTableGet AUTO_LIC_ERROR_TITLE]" \
            "[strTableGet SERVER_ERROR]"]
}


######################################################################
# Dialog Text Messages
######################################################################

set strTable(ERROR_MSG_COMMON) \
    "If you wish to retry the current transaction please click on the\
    <Retry> button, otherwise click on <Cancel> to re-enter values or\
    to use alternate means of configuring license management."

set strTable(ERROR_MSG_COMMON_TEXT) \
    "If you wish to retry the current transaction please type 'retry',\
    otherwise press <Enter> to re-enter values or\
    to use alternate means of configuring license management."


set strTable(FATAL_ERROR_TITLE) "Fatal Error"

set strTable(AUTO_LIC_ERROR_TITLE) "Automated License Error"
        
set strTable(LICENSE_ADMIN_URL) "http://www.windriver.com/license_admin"

set strTable(LICENSE_ADMIN_MSG) \
    "\r\n\r\nPlease contact Wind River License Administration to complete\
    your license server or Node Locked license setup. License Administration\
    information can be found at [strTableGet LICENSE_ADMIN_URL]."

########## DB errors ##########
set strTable(DB_ERROR_11) \
    "This error indicates all seats purchased for the license products\
    have been allocated."

set strTable(DB_ERROR_22) \
    "This error indicates that your Wind River license is an invalid\
    license type. Only development, eval, subscription, tools, and\
    WindLink partner types qualify for Automated License Installation"

set strTable(DB_ERROR_23) \
    "This error indicates an invalid feature version."
    
set strTable(DB_ERROR_30) \
    "This error indicates that your WRS license has an inactive status"

set strTable(DB_ERROR_31) $strTable(DB_ERROR_30)
                          
set strTable(DB_ERROR_45) \
    "This error indicates that there is a mismatch of host ID or host\
    name. Your host ID or host name does not match with the one in the\
    Wind River license database. This error may be caused by previously\ 
    having configured a license on this machine with a different host\
    name or host ID."

set strTable(DB_ERROR_47) $strTable(DB_ERROR_45)

set strTable(DB_ERROR_48) \
    "This error indicates that the port number for the current host\
    has been changed."

set strTable(DB_ERROR_51) \
    "This error indicates that a Node Locked license for one or\
    more feature(s) you have requested has already been taken by\
    the current host. You are only allowed to have one license seat\
    per feature."
    
set strTable(DB_ERROR_52) \
    "This error indicates that\
    the number of floating seats requested is greater than the number of\
    floating seats available for allocation."
    
set strTable(DB_ERROR_53) \
    "This error indicates that\
    the number of node-locked seats requested is greater than the number of\
    node-locked seats available for allocation."


########## CGI Errors ##########
set strTable(CGI_ERROR_30) \
    "This error indicates connection problems with the Wind River license\
    server (ALD). Either the server is down or a network\
    problem has occurred."  

set strTable(CGI_ERROR_31) \
    "The Authorization Code that you have entered is invalid."

set strTable(CGI_ERROR_32) \
    "This error indicates an invalid data are passed to the license server." 

set strTable(CGI_ERROR_40) \
    "This error indicates that there is a connection problem to the\
    Wind River Web Site. Either the server is down or a network problem\
    has occurred. Please\
    try again later or try an alternate means of configuring license\
    management for this host."

########## ALD Errors ##########
set strTable(ALD_ERROR_50) \
    "This error indicates invalid data are passed to the license server."

set strTable(ALD_ERROR_51) \
    "This error indicates that there is a connection problem to the \
    Wind River database (ALID). Either the server is down or a network\
    problem has occured."

set strTable(ALD_ERROR_52) \
    "This error indicates a problem in retrieving license information\
    from the Wind River database."


############ Server Error ############

set strTable(SERVER_ERROR) \
    "An internal error has occurred in attempting to connect to the Wind \
    River database.\
    Either the server is down or a network problem has occurred. Please\
    try again later or try an alternate means of configuring license\
    management for this host."


####### Unknown Database Error #########

set strTable(DB_ERROR_UNKNOWN) \
     "We received an unknown database error code. This may be caused by\
     by your host having 2 or more NIC cards inserted. If you are a\
     PC user you should press Cancel, re-check Automatic\
     License Installation on the page that appears and then advance\
     to the next screen. There you can select the Use Disk Serial Number\
     for hostId check box and proceed with license configuration.\
     \r\n\r\nOtherwise your only option is to power-off your host,\
     remove all but the one NIC card you wish to register the hostID,\
     power-on the host  re-run Setup as instructed below.\
     If you are an end-user client re-run SETUP with the /L option to\
     configure license management. If your are installing a license\
     management server, re-run SETUP and proceed to the License Management\
     Server Installation page to continue.\
     \r\n\r\nIf this solution fails:"
