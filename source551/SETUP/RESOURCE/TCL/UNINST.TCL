# UNINST.TCL - Uninstallation program for Unix/Windows platforms.
#
# modification history
# --------------------
# 04i,15may03,bjl  added more instructions to exit tornado apps (spr 87392).
# 04h,03oct02,bjl  fixed text to use core product name rather than cdromDesc
#                  (spr 77983).
# 04g,25jul02,wmd  Fix problem with uninstall icon being deleted before the
#                  last layer of installed products.
# 04f,24jul02,wmd  Fix so unregister button is checked by default, and tcl
#                  error upon exit.
# 04e,23jul02,wmd  Fix SPR 79921 - do not delete program group if not last
#                  layer.
# 04d,11jul02,wmd  Add a checkbox for uninstalling the registry.
# 04c,03may02,bwd  SPR 76643: added backward compatibility support for patches
#                  made pre-veloce setupSDK
# 04b,05mar02,bwd  Modified SETUP to be non-tornado centric
# 04a,12jun01,j_w  Modified for Tornado 2.2
# 03o,13mar01,j_w  update version 3.0 to 3.1
# 03n,13nov00,j_w  remove <install_dir>/host for full uninstallation
# 03m,02nov00,j_w  Name change - Tornado AE
# 03l,30oct00,j_w  catch errors when restoring setup files
# 03k,09oct00,j_w  Removed Tornado Registry Service before removing any
#                  related files (SPR 35049)
# 03j,25sep00,j_w  Do not remove the Uninstall icon for partial uninstall
# 03i,19sep00,j_w  Restored uninstall start files if user aborted during 
#                  uninstallation (spr 34381)
# 03h,07sep00,j_w  removed setup.log.abort
# 03g,31aug00,j_w  Remove the .wind/tornado3.0 directory in HOMEDRIVE 
#                  if performing full uninstallation
# 03f,30aug00,j_w  Fixed SPR 33909
# 03e,28aug00,j_w  Added instructions for removing Tornado Registry.
# 03d,19may00,j_w  Fixed delete icon problem in setupLinkDelete{}
# 03c,11may00,j_w  Removed unregTornado{}
# 03b,17apr00,j_w  Removed ComTcl.dll and WrsDebugger.dll unregistration
# 03a,18oct99,bjl  renamed uitclcontrols to libuitclcontrols for Unix,
#                  do not cd to root dir at end of uninstall for Unix.
# 02z,14oct99,j_w  Update dll loaded in seedUninstall and remove readonly
#                  attribute for uninstall files in the tmp directory
# 02y,02apr99,wmd  Fix a hole where pgr folders get deleted enmass.
# 02x,02apr99,wmd  Install a pause after each unregister of a component or
#                  executable.
# 02w,02apr99,wmd  Add line to delete docs directory.
# 02v,22mar99,tcy  replace batch file with t2UninstallCleanup.exe
# 02u,16mar99,tcy  added saftguard to prevent SETUP from wiping out all
#                  program folders
# 02t,12mar99,wmd  Need to add a new required file: wrsCW.dll.
# 02s,03mar99,tcy  destroy warning messages before starting UNINST process
# 02r,01mar99,tcy  added warning message to advice users to kill any Tornado
#                  applications before running UNINST (fix for SPR 25168)
# 02q,22feb99,tcy  unregister dlls (fix for SPR 23331)
# 02p,27jan99,tcy  renamed meterUpdate() to uninstMeterUpdate();
#                  added sourcing of INCLUDE.TCL
# 02o,26jan99,wmd  Need to add more output to autoUninst log file to monitor
#                  uninstall.
# 02n,26jan99,wmd  Fix a typo, mispelled UNINST for the uninstall log file.
# 02m,19jan99,wmd  Modify so that uninstall can run automatically with a
#                  script file.  Update procs to use WRS coding conventions,
#                  remove all vestiges of TK and TEXT mode, env(UI), etc.
# 02l,03dec98,tcy  copies setup engine from SETUP directory instead
# 02k,17nov98,bjl  made uninstall entire Tornado the default choice, added
#                  warning box after user presses OK (fixes SPR 23274).
# 02j,12nov98,tcy  look for env(TMP) for UNIX
# 02i,12nov98,tcy  do not uninstall resources for UNIX
# 02h,12nov98,tcy  do not set env(UI), env(TMP), and env(PATH) due to
#                  possible lack of environmental space on Win95
# 02g,15oct98,tcy  reduce height of progressmeter
# 02f,01oct98,wmd  added waitcursor to uninstInfoGet
# 02e,16sep98,tcy  added UNIX support
# 02d,16sep98,tcy  msvcp50.dll required for uninstall
# 02c,13aug98,tcy  fixed file for new T2 UITclSh
# 02b,04aug98,tcy  changed meter to progressmeter
# 02a,27jul98,tcy  changed to controlPropertySet in onUITclDialogOk ()
# 01q,11aug97,pdn  fixed uninstFile() to handle case fileList is null.
# 01p,13jun97,pdn  started to use the DLL version of the setup APIs.
# 01o,15apr97,pdn  fixed the logging machanism.
# 01n,28mar97,pdn  stopped removing user private files
# 01m,12mar97,pdn  fixed typo.
# 01l,04feb97,pdn  added retry option for uninstFile(), and fix uninstResource
# 01k,27feb97,pdn  reset the PATH environment variable (Windows 95)
# 01j,24feb97,pdn  reduced the time to switch between uninstall choices.
# 01i,24jan97,pdn  added way to remove files under Windows directory
# 01h,18dec96,sks  changed location of TCL and BITMAP files; renamed
#                  TEXT.TCL to MESSAGES.TCL
# 01g,09dec96,pdn  used tcl 7.6 file utilities
# 01f,27nov96,pdn  used deltree to remove temp dir for Window 95
# 01e,14nov96,pdn  fixed meter bug occurs when totalItem is 0
# 01d,13nov96,pdn  added seedUninstall function.
# 01c,08nov96,pdn  adjusted the binding of the Return key to match the default
#                  button
# 01c,08nov96,pdn  fixed uninstInfoGet() to obtain a completed list
#                  of file when trying to uninstall all.
# 01b,05nov96,pdn  added support for Windows.
# 01a,16oct96,pdn  written.
#

set uninst(WIND_BASE) [lindex $argv 0]


#######################################################################
#
# UNINST.TCL
#
# This file contains implements the uninstall program that is part
# of the setup and installation process.
#
# On Windows hosts, Setup installs the Uninstall icon within the
# program group created by the user.  The command line to execute
# on Windows hosts is:
# $WIND_BASE/SETUP/X86/WIN32/UITCLSH.EXE $WIND_BASE/.wind/uninst/UNINST.TCL
#    $WIND_BASE -seed
#
# On Unix hosts, the user invokes the executable script UNINST that is
# located in the $WIND_BASE/host/<host-type>/bin,
#
# To automate the use of UNINST, set the environment variable
# UNINSTALL_ANS_FILE = <uninstCfg.tcl>
#       where <uninstCfg.tcl> contains the following:
#
#======== Start of Script ==================================================
#
# Auto uninstallation config file for setup
#
# This is a config file used for auto uninstallation by UNINST.
# The env. variables UNINSTALL_ANS_FILE and UNINSTALL_LOG_FILE are required
#
#set UNINSTALL_ANS_FILE=c:setupCfg.tcl
#set UNINSTALL_LOG_FILE=c:autoInst.log
#
#########################################################
# Variable edit section #
#########################################################
#global env
#
# User Name #
#set userName "will"
#
# Company Name #
#set companyName "WIND RIVER SYSTEMS"
#
# uninstallOption: can be "partial" or "all" #
#set uninstallOption partial
#
#########################################################
# End of edit section #
#########################################################
#
#########################################################
# Do not change the following #
#########################################################
# global uninst
#
# end #
#========= End of Script ===================================================
#
# Note:  In the above script, the lines that do not end with # are the actual
# executable lines, remove the '#' from the start of those lines.
# By setting the uninstallOption variable to "all" or "partial," you can
# simulate selection of remove all or remove last installation respectively.
#

##############################################################################
#
# uninstWin32 - puts up the Uninstall dialogue
#
# This procedure displays the Uninstall dialogue.  It is modal unless the
# environment variable UNINSTALL_ANS_FILE contains a filename to a valid
# tcl script which automates uninstall.  In that case the dialog is modeless.
#
# SYNOPSIS
# uninstWin32
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc uninstWin32 {} {
    global string
    global uninst
    global uninstallOption

    set modeLess "-nocontexthelp"
    if {$uninst(useInputScript)} {
        if {$uninstallOption == "partial"} {
            set uninst(mode) part
        } else {
            set uninst(mode) all
        }
        set modeLess "-modeless"
    }

    dialogCreate \
       -name uninstDlg \
       -title "[getProdInfo name] Uninstall" \
       -width 323 -height 218 \
       $modeLess -nocontexthelp \
       -init uninstUITclDialogInit \
       -control [list \
           [list bitmap -name bitmap -title \
                    [file join $uninst(home) UNINST.BMP] -stretch \
                    -xpos 10 -ypos 10 -width 94 -height 170] \
           [list label -name headerMsg \
                   -title $string(header) \
                   -xpos 117 -ypos 11 -width 199 -height 17] \
           [list choice -title $string(button1) \
                    -name uninstAll -newgroup -auto \
                    -xpos 117 -ypos 35 -width 140 -height 10  \
                    -callback {onUninstallAll callback}] \
           [list choice -title $string(button2) \
                   -name uninstPart -auto \
                   -xpos 117 -ypos 47 -width 171 -height 10  \
                   -callback {onUninstallPart callback}] \
           [list boolean \
                   -title "Unregister Tornado Registry Service on this machine" \
                   -name uninstRegSvc -auto \
                   -xpos 117 -ypos 60 -width 180 -height 10 \
                   -callback {onUninstRegSvc callback}] \
           [list label -title "" -name installInfo  \
                   -xpos 130 -ypos 74 -width 186 -height 39] \
           [list label -name warningMessage  \
                   -xpos 117 -ypos 104 -width 199 -height 9] \
           [list label -name message  \
                   -xpos 117 -ypos 113 -width 199 -height 37] \
           [list label -name exitMessage  \
                   -xpos 117 -ypos 150 -width 199 -height 38] \
           [list frame -gray -name separator  \
                   -xpos 7 -ypos 188 -width 309 -height 1] \
           [list button -title "Help" -name helpButt \
                   -xpos 10 -ypos 197 -width 50 -height 14 \
                   -callback onUITclDialogDetails] \
           [list button -title "OK" -name okButt -default \
                   -xpos 207 -ypos 197 -width 50 -height 14  \
                   -callback onUITclDialogOk] \
           [list button -title "Cancel" -name cancelButt  \
                   -xpos 266 -ypos 197 -width 50 -height 14  \
                   -callback {windowClose uninstDlg}]]

    set uninst(regSvc) 1

    if {$uninst(useInputScript)} {
        set message "Uninstall is seeded with the $uninstallOption option"
        autoUninstLog $message
        if {$uninst(mode) == "part"} {
            controlCheckSet uninstDlg.uninstPart 1
        } else {
            controlCheckSet uninstDlg.uninstAll 1
        }
        onUITclDialogOk
    }
}

proc onUITclDialogDetails {} {
    
    set prod [getProdInfo name]
    set msg "Instructions to stop the $prod Registry: \n\n"
    append msg "If started as a Service, go to the\
                Control Panel-->Services, select $prod Registry\
                and hit Stop.\n\n"
    append msg "If started manually or on startup, open\
                $prod Registry from the Taskbar and hit the\
                \"Kill Registry\" button."

    messageBox $msg
    #dialog ok_with_title "[getProdInfo name] Uninstall" $msg "" ""
}


##############################################################################
#
# onUITclDialogOk - call back procedure for the OK button
#
# This procedure begins the process of removing either the last install session
# or all of Tornado depending on the contents of uninst(mode).  If the user
# has chose 'all', he is asked to confirm his choice.
#
# SYNOPSIS
#
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc onUITclDialogOk {} {
    global uninst 
    global env 

    set setupLog ""

    if {$uninst(mode) == "all"} {
        set finalwarning "WARNING: You have chosen to remove [getProdInfo name]\
        entirely.  Are you sure?"
        set messageboxtype -exclamationicon
    } elseif {$uninst(mode) == "part"} {
        set finalwarning \
        "You have chosen to remove your previously installed session.\n\
         \nPlease ensure that no Tornado processes are still running\
        before proceeding.  These include tornado, wtxregd, tgtsvr,\
        gdb, etc.  Refer to your documentation for instructions on\
        how to do this correctly, or use the task manager (Windows).\n\
        \nAre you sure you are ready to proceed?"

        set messageboxtype -questionicon
    }

    if {!$uninst(useInputScript)} {    
        switch [messageBox -yesno $messageboxtype  $finalwarning] {
            no {return}
        }
    }
    
    controlEnable uninstDlg.helpButt 0
    controlEnable uninstDlg.okButt 0
    controlEnable uninstDlg.cancelButt 0
    controlEnable uninstDlg.uninstAll 0
    controlEnable uninstDlg.uninstPart 0
    controlDestroy uninstDlg.message
    controlDestroy uninstDlg.warningMessage
    controlDestroy uninstDlg.exitMessage
        
    controlCreate uninstDlg { label -name progressTag  \
                        -xpos 117 -ypos 151 -width 197 -height 8  \
                }
    controlCreate uninstDlg { progressmeter -center -name progress \
                       -xpos 117 -ypos 164 -width 199 -height 13 \
                  }
    controlPropertySet uninstDlg.progress \
                       -background Blue -foreground Black

    # unregister tornado dlls
    if {"$uninst(mode)" == "all" && ![isUnix]} {
        unregTornado 
    }

    uninstInfoGet

    # remove the service first

    if {$uninst(regSvc)} {
       uninstService
    }

    uninstFile

    print "uninst(errorCount): $uninst(errorCount)"

    uninstResource

    # restore uninstall files for future uninstall if error occurred 
    if {$uninst(errorCount) > 0} {
        set fileList [glob -nocomplain $env(TMP)/*]
        foreach file $fileList {
            print "@@@@ restore uninstall file: $file"
            if [catch {file copy -force $file \
                    $uninst(WIND_BASE)\\SETUP\\X86\\WIN32} err] {
                print "@@@@ file copy failed: $file"
            }
                        
            #file attributes $env(TMP)\\$file -readonly 0
                        
        }
    }
        
    if {$uninst(errorCount) == 0} {
                
        if {"$uninst(mode)" == "part"} {
            uninstBackup
        }

        if {[isUnix]} {
            set homeDir $env(HOME)
        } else {
            set homeDir $env(HOMEDRIVE)
        }

        if {"$uninst(mode)" == "all"} {
            catch {file delete -force $uninst(WIND_BASE)/docs}
            catch {file delete -force $uninst(WIND_BASE)/.wind/uninst}
            catch {file delete -force $uninst(WIND_BASE)/.wind/license}
            catch {file delete -force $uninst(WIND_BASE)/SETUP}
            catch {file delete -force $uninst(WIND_BASE)/.wind}
            catch {file delete -force $uninst(WIND_BASE)/host}
            catch {file delete -force $uninst(WIND_BASE)/setup.log}
            catch {file delete -force $uninst(WIND_BASE)/setup.log.abort}
            if {[catch {file delete $uninst(WIND_BASE)} error]} {
                incr uninst(errorCount)
            }
        } else {
            if [catch {
                    set setupLog [open $uninst(WIND_BASE)/setup.log "a+"]
                    foreach line [split $uninst(info) "\n"] {
                        if {"$line" != ""} {
                            puts $setupLog "[getDate]\tUninst\t$line"
                        }
                    }
                    file delete $uninst(zipFile)
                } error] {
                puts $error
            }
        }
    } 

    controlDestroy uninstDlg.progress
    controlDestroy uninstDlg.progressTag

    if {$uninst(errorCount) > 0} {
        if {"$uninst(mode)" == "part"} {
            set YPOS 114
            set HEIGHT 75

            set msg \
            "Warning: Not all files/directories were able to be removed.\
            You may need to remove them manually.\n\nIf the files that\
            could not be removed were Tornado-related executables (tornado,\
            wtxregd, tgtsvr, various .dll's, etc) you must kill all Tornado-related\
            executables and re-run this uninstall in order to restore your install\
            tree to a functioning state."
        } else {
            set YPOS 153
            set HEIGHT 25
            
            set msg "Warning: Not all files/directories are removed.  You may\
            need to remove them manually.  Press the OK button to exit."
        }


        if {"$setupLog" != ""} {
            puts $setupLog "\tUninstall did not complete successfully."
        }
    } else {
       set YPOS 153
       set HEIGHT 25

       set msg "Uninstall completed successfully.\
                Press the OK button to exit."
    }

    if {"$setupLog" != ""} {
       puts $setupLog ""
       close $setupLog
    }

    controlCreate uninstDlg [list label -name message  \
                        -xpos 117 -ypos $YPOS -width 199 -height $HEIGHT ]

    controlDestroy uninstDlg.helpButt
    controlDestroy uninstDlg.okButt
    controlValuesSet uninstDlg.message "$msg"
    controlValuesSet uninstDlg.cancelButt "OK"
    controlEnable uninstDlg.cancelButt 1
}

##############################################################################
#
# setupFolderDelete - removes the program group folder
#
# SYNOPSIS
# setupFolderDelete
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc setupFolderDelete {folderName mode {force 1}} {
    global uninst

    set programPath [programPathGet $mode]

    if {$folderName == ""} {
        print "folder name $folderName is NULL"
        return
    }

    if {$force} {
       if {[catch {file delete -force "$programPath\\$folderName"} err]} {
           print "cannot delete folder, $folderName: $err"
           if {$uninst(useInputScript)} {
               autoUninstLog "cannot delete folder, $folderName: $err"
           }
       } else {
           print "deleted folder: $folderName"
           if {$uninst(useInputScript)} {
               autoUninstLog "deleted folder: $folderName"
           }
       }
    } else {
       if {[catch {file delete "$programPath\\$folderName"} err]} {
           print "cannot delete folder, $folderName: $err"
           if {$uninst(useInputScript)} {
               autoUninstLog "cannot delete folder, $folderName: $err"
           }
       } else {
           print "deleted folder: $folderName"
           if {$uninst(useInputScript)} {
               autoUninstLog "deleted folder: $folderName"
           }
       }
    }
}

##############################################################################
#
# setupLinkDelete - deletes the icons within a folder
#
#
# SYNOPSIS
# setupLinkDelete
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc setupLinkDelete {folderName linkName mode} {
        global uninst

    set programPath [programPathGet $mode]

    if { "$folderName" == "" } {
        print "Error: folder name is null"
        return
    }

    if { "$linkName" == "" } {
        print "Error: link name is null"
        return
    }

    if {[regexp {.* Uninstall} $linkName match]} {
        if {"$uninst(mode)" == "part"} {
            print "Not deleting $linkName, not the last layer"
            return
        }
    }

    if {[catch {file delete "$programPath\\$folderName\\$linkName.lnk"} err]} {
        print "cannot delete icon, $linkName: $err"
        if {$uninst(useInputScript)} {
           autoUninstLog "cannot delete icon, $linkName: $err"
        }
    } else {
        print "deleted icon: $folderName\\$linkName"
        if {$uninst(useInputScript)} {
           autoUninstLog "deleted icon: $linkName"
        }
    }
}

##############################################################################
#
# uninstService - uninstalls the Tornado Registry Service
#
# This procedure uninstalls the Tornado Registry Service if there is one 
# running
#
# SYNOPSIS
# uninstService
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#
proc uninstService {} {
    global uninst

    set visitedList {}

    foreach line $uninst(resList) {

        if {[lsearch $visitedList $line] == "-1"} {
            lappend visitedList $line
                        
            switch [lindex $line 0] {

                service {
                    if {![isUnix]} {
                        uninstMeterUpdate 0 "Removing" "[lindex $line 0]..."
                        set serviceName [lindex $line 1]
 
                        if {[catch {setupServiceStop $serviceName} err]} {
                            print "cannot stop service, $serviceName: $err"
                            if {$uninst(useInputScript)} {
                                autoUninstLog "cannot stop service, $serviceName: $err"
                            }
                        } else {
                            print "stopped service: $serviceName"
                            if {$uninst(useInputScript)} {
                                autoUninstLog "stopped service: $serviceName"
                            }
                        }
                                                
                        if {[catch {setupServiceRemove $serviceName} err]} {
                            print "cannot delete service: $serviceName: $err"
                            if {$uninst(useInputScript)} {
                                autoUninstLog "cannot delete service: $serviceName: $err"
                            }
                        } else {
                            print "deleted service: $serviceName"
                            if {$uninst(useInputScript)} {
                                autoUninstLog "deleted service: $serviceName"
                            }
                        }
                    }
                }
            }
        }
    }
}

##############################################################################
#
# uninstResource - uninstalls the resources
#
# This procedure uninstalls the list of resources contained in the tcl variable
# uninst(resList).  This list is gathered in the proc uninstInfoGetHelper.
#
# SYNOPSIS
# uninstResource
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc uninstResource {} {
    global uninst

    set folderList {}
    set visitedList {}
    set iconList {}

    foreach line $uninst(resList) {

        incr uninst(currItem)
        set percent [expr ($uninst(currItem) * 99) / $uninst(totalItem)]
        uninstMeterUpdate $percent "Removing" "[lindex $line 0]..."

        if {[lsearch $visitedList $line] == "-1"} {
            lappend visitedList $line

            switch [lindex $line 0] {
                icon {
                    if {![isUnix]} {
                        set folderName [lindex $line 1]
                        set iconName [lindex $line 2]
                        set common [lindex $line 3]

                        lappend iconList $iconName

                        if {$uninst(errorCount) == 0} {
                            if {"$uninst(mode)" == "all"} {
                                print "removed: $folderName $iconName"
                                setupLinkDelete $folderName $iconName $common
                            } else {
                                if {![string match {[getProdInfo name] Uninstall} \
                                                                    $iconName]} {
                                    print "removed: $folderName $iconName"
                                    setupLinkDelete $folderName $iconName \
                                                    $common 
                                }
                            }
                        } else {
                            if {![string match {[getProdInfo name] Uninstall} $iconName]} {
                                print "removed: $folderName $iconName $common"
                                setupLinkDelete $folderName $iconName $common 
                            }
                        }
                   }
               }

               folder {
                   if {![isUnix]} {
                       # Need to remove all the icons first
                       lappend folderList $line
                   }
               }

               regkey {
                   if {![isUnix]} {
                       set rootKey [lindex $line 1]
                       set key [lindex $line 2]

                       if {[catch {sysRegistryKeyDelete $rootKey $key} err]} {
                            print "cannot delete registry key, $key: $err"
                            if {$uninst(useInputScript)} {
                                autoUninstLog "deleted icon: $linkName"
                            }
                       } else {
                            print "deleted registry key: $key"
                            if {$uninst(useInputScript)} {
                                autoUninstLog "deleted registry key: $key"
                            }
                       }
                   }
               }

               regValue {
                   if {![isUnix]} {
                       set rootKey [lindex $line 1]
                       set subKey [lindex $line 2]
                       set value [lindex $line 3]

                       if {[catch {sysRegistryValueDelete \
                                  $rootKey $subKey $value} err]} {
                           print "cannot delete registry value, $value: $err"
                           if {$uninst(useInputScript)} {
                              autoUninstLog "cannot delete registry value, $value: $err"
                           }
                       } else {
                           print "deleted registry value: $value"
                           if {$uninst(useInputScript)} {
                              autoUninstLog "deleted registry value: $value"
                           }
                       }
                   }
               }

               default {}
           }
        }
    }

    if {![isUnix]} {
                
        foreach folder $folderList {
                        
            set folderName [lindex $folder 1]
            set common [lindex $folder 2]
                        
            if {$uninst(errorCount) == 0} {
                if {"$uninst(mode)" != "part"} {
                    print "remove folder: $folderName"
                    setupFolderDelete $folderName $common
                }
            } else {
                # This is a workaround. After the links are deleted in
                # the tornado program group, some how the start menu still
                # shows the deleted links. This is probably a bug in NT.
                # The following will rename the tornado program group. Only 
                # uninstall icon should be shown after the rename

                set programPath [programPathGet $common]
                file rename "$programPath\\$folderName" \
                                "$programPath\\$folderName.bak"
                file rename "$programPath\\$folderName.bak" \
                                "$programPath\\$folderName"
            }
        }
    }
}

##############################################################################
#
# uninstUITclDialogInit - initialization procedure for the uninstall dialog.
#
# This procedure sets the dialog's check boxes based on the contents of the
# uninst(mode) array variable.  This procedure is a no-op if automation is
# turned on.
#
# SYNOPSIS
#
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc uninstUITclDialogInit {} {
    global uninst
    global argv
    global env

    applicationTitleSet "[getProdInfo name] Uninstall"

    if {$uninst(useInputScript)} {
        return
    }

    if {$uninst(mode) == "none"} {
       messageBox -stop "Cannot find the uninstall information."
       windowClose uninstDlg

    } elseif {$uninst(mode) == "all"} {
       controlCheckSet uninstDlg.uninstAll 1
       controlEnable uninstDlg.uninstPart 0
       onUninstallAll
    } else {
       controlCheckSet uninstDlg.uninstAll 1
       onUninstallAll
    }

    # disable this button for Unix, doesn't exist

    controlCheckSet uninstDlg.uninstRegSvc 1
    if {[isUnix]} {
        controlEnable uninstDlg.uninstRegSvc 0
        controlHide uninstDlg.uninstRegSvc 1
    }

}

##############################################################################
#
# dosTempDirGet - returns a unique temporary directory name.
#
#
# This procedure determine a temporary directory name based on the process
# id.
#
# SYNOPSIS
#
#
# PARAMETERS: N/A
#
# RETURNS: a unique string name for a temporary directory path.
#
# ERRORS: N/A
#

proc dosTempDirGet {} {
    global env

    # Determine the "temp" directory

    set uninstTemp "_TMP[pid]"

    foreach elem [array names env] {
       if {[string compare [string tolower $elem] "tmp"] == 0} {
           set env(TMP) $env($elem)
       }
       if {[string compare [string tolower $elem] "temp"] == 0} {
           set env(TEMP) $env($elem)
       }
       if {[string compare [string tolower $elem] "tmpdir"] == 0} {
           set env(TMPDIR) $env($elem)
       }
    }

    if {[info exists env(TEMP)] && [file isdir $env(TEMP)]} {
        set TMP $env(TEMP)\\$uninstTemp

    } elseif {[info exists env(TMP)] && [file isdir $env(TMP)]} {
        set TMP $env(TMP)\\$uninstTemp

    } elseif {[info exists env(TMPDIR)] && [file isdir $env(TMPDIR)]} {
        set TMP $env(TMPDIR)\\$uninstTemp
    } else {
        set TMP "C:\\$uninstTemp"
    }

    return $TMP
}

##############################################################################
#
# seedUninstall -  make a list of required files to delete.
#
#
# This procedure, invoked for Windows based machines, makes a list of required
# files that are used by the Uninstaller.  It also creates a batch file
# that is invoked to create a temporary directory where the uninstall program
# is actually executed so that the directory where uninstall resides itself
# can be deleted as well.
#
# SYNOPSIS
# seedUninstall
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc seedUninstall {} {
    global env argv0 uninst

    set env(TMP) [unixToDos [dosTempDirGet]]

    set uninstDir [unixToDos "$uninst(WIND_BASE)\\.wind\\uninst"]
    set binDir [unixToDos "$uninst(WIND_BASE)\\SETUP\\X86\\WIN32"]

    #set requiredFiles(msvcp60.dll) $binDir
    set requiredFiles(msvcp50.dll) $binDir
    set requiredFiles(mfc42.dll) $binDir
    set requiredFiles(uitclcontrols.dll) $binDir
    set requiredFiles(msvcrt.dll) $binDir
    set requiredFiles(pctree32.dll) $binDir
    set requiredFiles(tcl.dll) $binDir
    set requiredFiles(uitcl.dll) $binDir
    set requiredFiles(setuptcl.dll) $binDir
    set requiredFiles(uitclsh.exe) $binDir
    set requiredFiles(uninst.tcl) $uninstDir
    set requiredFiles(uninst.bmp) $uninstDir
    set requiredFiles(wrsCW.dll) $binDir
    set requiredFiles(t2UninstallCleanup.exe) $binDir

    # create the batch file that will copy required files and invoke uitclsh.exe

    catch {file mkdir $env(TMP)}

    foreach file [array names requiredFiles] {
        file copy -force $requiredFiles($file)\\$file $env(TMP)
        if {![isUnix]} {
            file attributes $env(TMP)\\$file -readonly 0
        }
    }

    set version [setupWinVerGet]

    set flag ""

    if {[info exists env(SETUP_DEBUG)]} {
        set flag "-C"
    }

    if [catch {processCreate \
        "$env(TMP)\\uitclsh.exe $flag  [dosToUnix $env(TMP)\\uninst.tcl] \
         $uninst(WIND_BASE) [dosToUnix $env(TMP)]" $env(TMP)} error] {
        puts $error
    }
}

##############################################################################
#
# print - prints a message to the active console.
#
# SYNOPSIS
# print <nsg>
#
# PARAMETERS: msg - message to be printed.
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc print {msg} {
    global env

    if {[info exists env(SETUP_DEBUG)]} {
        puts "$msg"
    }
}

##############################################################################
#
# uninstMeterUpdate - updates the meter display
#
# This procedure uses the percent passed to update the meter.
#
# SYNOPSIS
# uninstMeterUpdate <percent tag1 tag2>
#
# PARAMETERS:
#     percent - number indicating percentage complete
#     tag 1 - any informational string to display or null
#     tag 2 - a second string to display or null
#
# RETURNS: N/A
#
# ERRORS: N/A
#
#
proc uninstMeterUpdate {percent tag1 tag2} {
    global ctrlVals
    global uninst
    global env

   set shortFileName [fileNameAbbreviate $tag2 30]

   controlValuesSet uninstDlg.progress $percent
   controlValuesSet uninstDlg.progressTag "$tag1 $shortFileName"
   uiEventProcess
}

##############################################################################
#
# message - prints a message
#
# This procedure prints a message either in the form of a message box.
#
# SYNOPSIS
# message <msg>
#
# PARAMETERS: msg - any string
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc message {msg} {
    global uninst
    global env

    messageBox -ok -information $msg
}

##############################################################################
# 
# dialog - display a dialog UI
#
# This procedure
#
# SYNOPSIS
#
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc dialog {type title msg bitmap default} {
    global env 

    switch $type {
        re_ig_cancel {
            switch [messageBox -abortretryignore -questionicon $msg] {
                abort  { return 2 }
                retry  { return 0 }
                ignore { return 1 }
            }
        }        
    }
}

##############################################################################
#
# lastInstSessionInfoGet - retrieves infomation on the last install session
#
# This procedure retrieves and stores into uninst(info) strings which indicate
# what was installed during the last install session.
#
# SYNOPSIS
# lastInstSessionInfoGet
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc lastInstSessionInfoGet {} {
    global uninst env

    set zipFile \
        [lindex [lsort -decreasing \
                       [glob -nocomplain $uninst(home)/data.???]] 0]

    set saveDir [pwd]
    cd $env(TMP)

    catch {setupUnzip -o -qq $zipFile "installInfo"}

    if {[file exists "installInfo"]} {
        set f [open "installInfo" "r"]
        set uninst(info) [read $f]
        close $f
    } else {
        set uninst(info) "No previous install infomation to extract."
    }
}

##############################################################################
#
# uninstInfoGet - unzips the installInfo from the zip files
#
# This procedure unzips previous installation information from the data.???
# file into the appropriate unist() array values.
#
# SYNOPSIS
# uninstInfoGet
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc uninstInfoGet {} {
    global uninst
    global env

    set uninst(currItem) 1
    set uninst(totalItem) 1
    set uninst(resList) ""
    set uninst(fileList) ""
    set uninst(bakList) ""

    beginWaitCursor

    set uninstZipFileList \
        [lsort -decreasing [glob -nocomplain $uninst(home)/data.???]]

    if {"$uninst(mode)" == "part"} {
        set uninst(zipFile) [lindex $uninstZipFileList 0]
        uninstInfoGetHelper $uninst(zipFile)

    } elseif {"$uninst(mode)" == "all"} {
        foreach zipFile $uninstZipFileList {
            uninstInfoGetHelper $zipFile
        }
    }

    endWaitCursor

    print "uninst(resList) = $uninst(resList)"
    print "uninst(totalItem) = $uninst(totalItem)"
    if {$uninst(useInputScript)} {
        autoUninstLog "uninst(resList) = $uninst(resList)"
        autoUninstLog "uninst(totalItem) = $uninst(totalItem)"
    }
}

##############################################################################
#
# uninstInfoGetHelper - helper proc for uninstInfoGet
#
# This procedure is invoked by uninstInfoGet which then does all the work
# of initializing the uninst(fileList), uninst(bakList), and uninst(resList).
#
# SYNOPSIS
# uninstInfoGetHelper <zipFile>
#
# PARAMETERS: zipFile - the zipfile to search through for the information.
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc uninstInfoGetHelper {zipFile} {
    global uninst
    global env

    set saveDir [pwd]
    cd $env(TMP)

    catch {setupUnzip -o -qq $zipFile "install*"}

    # Load the installed file list

    if {[file exists "installFile"]} {
        set f [open "installFile" "r"]

        while {[gets $f line] != "-1"} {
            if {"$line" != ""} {
                lappend uninst(fileList) [split $line "\t"]
            }
        }
        close $f
    }

    # Load the backup file list

    if {[file exists "installBackup"]} {
        set f [open "installBackup" "r"]

        while {[gets $f line] != "-1"} {
            if {"$line" != ""} {
                lappend uninst(bakList) [split $line "\t"]
            }
        }
        close $f
    }

    # Load the resource file list

    if {[file exists "installResource"]} {
        set f [open "installResource" "r"]

        while {[gets $f line] != "-1"} {
            if {"$line" != ""} {
                lappend uninst(resList) [split $line "\t"]
            }
        }
        close $f
    }

    incr uninst(totalItem) [llength $uninst(fileList)]
    incr uninst(totalItem) [llength $uninst(resList)]

    if {"$uninst(mode)" == "part"} {
        incr uninst(totalItem) [llength $uninst(bakList)]
    }

    cd $saveDir
}

##############################################################################
#
# uninstBackup - restores the file in the backup list
#
# This procedure restores the files from the $uninst(zipFile) zipfile.
#
# SYNOPSIS
# uninstBackup
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc uninstBackup {} {
    global uninst
    global env

    foreach line $uninst(bakList) {
       set file [lindex $line 1]

       switch [lindex $line 0] {
           wind_base {
               incr uninst(currItem)
               set percent [expr ($uninst(currItem) * 99) / $uninst(totalItem)]
               uninstMeterUpdate $percent "Restoring " $file
               if {[catch {setupUnzip -o -qq $uninst(zipFile) \
                      -d $uninst(WIND_BASE) $file} error]} {
                   incr uninst(errorCount)
                   message "Cannot restore $file: $error"
               }
           }
           default { puts "unknown rootdir token" }
       }
    }
}

##############################################################################
#
# dirInsert - inserts the head directory of the path into array dirArray().
#
# SYNOPSIS
# dirInsert <pathName>
#
# PARAMETERS: pathname - path from which to extract the head of the tree.
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc dirInsert {pathName} {
    global dirArray

    set dirArray($pathName) ""

    while { 1 } {
        set pathName [file dirname $pathName]
        if {$pathName == "."} {
            break
        } else {
            set dirArray($pathName) ""
        }
    }
}

##############################################################################
#
# dirRemove - removes the directories listed in the tcl array dirArray().
#
# SYNOPSIS
# dirRemove
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc dirRemove {} {
    global dirArray uninst

    # delete the innermost empty directory first

    foreach dir [lsort -decreasing [array names dirArray]] {
        catch {file delete $uninst(WIND_BASE)/$dir}
    }
}

##############################################################################
#
# uninstFile - removes the files and directories to be uninstalled.
#
# This procedure is the main procedure which coordinates the removal of the
# list of files and directories that are to be uninstalled.
#
# SYNOPSIS
# uninstFile
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc uninstFile {} {
    global uninst
    global env

    foreach line $uninst(fileList) {
       set file [lindex $line 1]

       switch [lindex $line 0] {
           wind_base {
               set filePath $uninst(WIND_BASE)/$file
               dirInsert [file dirname $file]
           }
           window {
               if {[file extension $file] == ".CPL"} {
                   catch {setupWindowClose "Control Panel"}
               }
               set filePath [setupWinDirGet]/$file
           }
           default { puts "unknown rootdir [lindex $line 0]" }
       }

       incr uninst(currItem)
       set percent [expr ($uninst(currItem) * 99) / $uninst(totalItem)]

       uninstMeterUpdate $percent "Removing " $file

       if {[file exists $filePath]} {
           while {[catch {file delete $filePath} error]} {
               switch [dialog re_ig_cancel "Uninstall" "$error" question 0] {
                   0 { unset error }
                   1 { incr uninst(errorCount); break }
                   2 { incr uninst(errorCount); return }
               }
           }
       }
    }

    # remove all empty directory
    set percent [expr ($uninst(currItem) * 99) / $uninst(totalItem)]
    uninstMeterUpdate $percent "Removing" "directories..."
    dirRemove
}

##############################################################################
#
# onUninstallPart - callback proc for the uninstall "partial" choice button
#
# This procedure is called as a result of the user checking the partial
# (last install session) uninstall choice button.  It displays for the
# user the list of products to be removed.
#
# SYNOPSIS
#  onUninstallPart <{default direct}>
#
# PARAMETERS: {default direct} - these parameters are used as a debugging aid
#     indicate it invocation to this routine is via choice button (callback
#     is passed) or it was called programmatically (direct being the default).
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc onUninstallPart {{default direct}} {
    global uninst
    global env

    set uninst(mode) part
    lastInstSessionInfoGet

    set message "Uninstall will remove the above component(s) \
                from $uninst(WIND_BASE) and restore the previous state."

    set i 0
    foreach line [split $uninst(info) "\n"] {
       if {$i > 5} {
           append info "..."
           break
       }
       incr i
       if {"$line" != ""} {
           append info "$line\n"
       }
    }

    controlHide uninstDlg.warningMessage 1
    controlHide uninstDlg.installInfo   0
    controlValuesSet uninstDlg.message $message
    controlValuesSet uninstDlg.installInfo $uninst(info)

    if {$uninst(useInputScript)} {
        autoUninstLog $message
        autoUninstLog $info
    }
}


##############################################################################
#
# onUninstallAll - callback proc for the uninstall "all" choice button
#
# This procedure is called as a result of the user checking the remove "all"
# choice button.  It displays for the user a warning of what is about to occur.
#
# SYNOPSIS
# onUninstallAll <{default direct}>
#
# PARAMETERS: {default direct} - these parameters are used as a debugging aid
#     indicate it invocation to this routine is via choice button (callback
#     is passed) or it was called programmatically (direct being the default).
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc onUninstallAll {{default direct}} {
    global uninst
    global env
    global uninstallOption

    if {$uninstallOption == "partial"} {
        return
    } else {
        set uninst(mode) all
    }

    set warningMessage "Warning:"
    set message "Uninstall removes ALL of the standard [getProdInfo name] files\
            under $uninst(WIND_BASE), including files you may have modified. \
            Be sure to backup any modified files before continuing.  Note that\
            user private files are not removed."

    set exitMessage "Note: You must exit all [getProdInfo name] applications, including\
                     the [getProdInfo name] Registry and all target servers,\
                     before proceeding with Uninstall. Click the help button\
                                         for more details."

    controlValuesSet uninstDlg.warningMessage $warningMessage
    controlValuesSet uninstDlg.message $message
    controlValuesSet uninstDlg.exitMessage $exitMessage

    controlValuesSet uninstDlg.installInfo ""

    controlPropertySet uninstDlg.warningMessage -bold 1
    controlPropertySet uninstDlg.exitMessage -bold 1
    controlHide uninstDlg.warningMessage 0
    controlHide uninstDlg.installInfo 1

    if {$uninst(useInputScript)} {
        autoUninstLog $message
        autoUninstLog $exitMessage
    }
}

##############################################################################
#
# onUninstRegSvc - callback proc for the uninstall registry checkbox
#
# This procedure is called as a result of the user checking the uninstall
# Registry Service checkbox.
#
# SYNOPSIS
# onUninstRegSvc <{default checked}>
#
# PARAMETERS: {default checked} - these parameters are used as a debugging aid
#     indicate it invocation to this routine is via choice button (callback
#     is passed) or it was called programmatically (checked being the default).
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc onUninstRegSvc {{default direct}} {
    global uninst
    global env
    global uninstallOption

    if {$uninstallOption == "partial"} {
        return
    }

    if {[controlChecked uninstDlg.uninstRegSvc] == 1} {
       set uninst(regSvc) 1
    } else {
       set uninst(regSvc) 0
    }
}

###################################################################
#
# autoUninstLog - writes log messages to the automated uninstall log file
#
# SYNOPSIS: autoUnistLog <msg>
#
# PARAMETERS:  msg - a quoted string to write to the log file
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc autoUninstLog {msg} {
    global autoUninstLogFile

    if {[catch {open $autoUninstLogFile a+} file]} {
        print "Error in writing $autoUninstLogFile"
        return -1
    }
    puts $file "[getDate]: $msg"
    close $file
}


#############################################################################
#
# addSlash - add extra slashes for eval use later
#
# This procedure will add extra slashes for eval user later
#
# SYNOPSIS
# .tS
# addSlash <path>
# .tE
#
# PARAMETERS:
# .IP path
# path with slashes
#
# RETURNS: new path with extra slashes
#
# ERRORS: N/A
#

proc addSlash {path} {
    regsub -all {\\} $path {\\\\} newpath
    return $newpath
}

#############################################################################
#
# unregTornado - unregister all tornado dlls and executables
#
# This procedure will unregister all tornado dlls and executables
#
# SYNOPSIS
# .tS
# unregTornado
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc unregTornado {} {
    global ctrlVals
    global setupVals
    global uninst

    if {![isUnix]} {
        if ![catch {setupSysDirGet} dir] {
            set sysDirGet $dir
        } else {
            puts "Cannot determine system directory: $dir"
        }
    }

    set regsvr32 "$sysDirGet\\Regsvr32.exe"
    set binFile(ComTcl.dll) \
        "$uninst(WIND_BASE)\\host\\x86-win32\\bin\\ComTcl.dll"
    set binFile(WrsDebugger.dll) \
        "$uninst(WIND_BASE)\\host\\x86-win32\\bin\\WrsDebugger.dll"
    set binFile(Tornado.exe) \
        "$uninst(WIND_BASE)\\host\\x86-win32\\bin\\Tornado.exe"
    set regCommand(ComTcl.dll) "$regsvr32 /u /s /c $binFile(ComTcl.dll)"
    set regCommand(WrsDebugger.dll) "$regsvr32 /u /s /c\
                                     $binFile(WrsDebugger.dll)"
    set regCommand(Tornado.exe) "$binFile(Tornado.exe) /unregserver"

    set gdbFiles [glob -nocomplain [file join $uninst(WIND_BASE) \
                 host x86-win32 bin Cgdb*exe]]

    foreach absFile $gdbFiles {
        set f [file tail $absFile]
        set binFile($f) [unixToDos $absFile]
        set regCommand($f) "$binFile($f) /unregserver"
    }

    # check for file existence
    # Unregister only those files that exist

    foreach f [array names binFile] {
        if [file exists $binFile($f)] {
            set existingBinFile($f) $binFile($f) 
        } else {
            puts "Warning: $binFile($f) not found"
        }
    }

    if ![file exists $regsvr32] {
        puts "Error: $regsvr32 not found"
    }

    set totalCmds [llength [array names existingBinFile]]

    foreach b [array names existingBinFile] {
        if {![catch {eval exec [addSlash $regCommand($b)]} result]} {
            puts "$b unregistration successful!"
        } else {
            puts "$b unregistration failed: $result"
        }
        after 4000
    }
}

###################################################################
#
# start - entry point for the Uninstall program.
#
# SYNOPSYS
# start
#
# PARAMETERS:  N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#


proc start {} {
    global uninst
    global env
    global argv
    global uninstallOption
    global autoUninstLogFile

    foreach elem [array names env] {
       if {[isUnix]} {
           if {[string compare [string tolower $elem] "tmp"] == 0} {
               regsub -all {\\} $env($elem) {/} env(TMP)
           }
       }
    }

    if {![isUnix]} {
        set env(TMP) [lindex $argv 1]
    }

    load $env(TMP)/setuptcl[info sharedlibextension]
    dllLoad $env(TMP)/uitclcontrols[info sharedlibextension] \
            _UITclControls_Init
    
    #if {![isUnix]} {
    #    set tclControlFile uitclcontrols
    #} else {
    #    set tclControlFile libuitclcontrols
    #}
    #dllLoad $env(TMP)/$tclControlFile[info sharedlibextension] \
    #        _UITclControls_Init

    # check to see if there is an automated script file to source

    if { [info exists env(UNINSTALL_ANS_FILE)] } {
        print "Use Uninstall Answer file"

        set uninst(useInputScript) 1
        if { [info exists env(UNINSTALL_LOG_FILE)] } {
            set autoUninstLogFile $env(UNINSTALL_LOG_FILE)
        } else {
            set autoUninstLogFile "c:\\autoUninstall.log"
        }
        print "log file is $autoUninstLogFile"

        if { ![file exists $env(UNINSTALL_ANS_FILE)] } {
            autoUninstLog "Input script $env(UNINSTALL_ANS_FILE) not exists!\n"
            return -1
        }
        if {[catch {source $env(UNINSTALL_ANS_FILE)} e]} {
            puts "Error in sourcing $env(UNINSTALL_ANS_FILE)\n"
            return -1
        }
    } else {
        set uninstallOption 0
        set uninst(useInputScript) 0
    }

    set uninst(errorCount) 0
    set uninst(home) $uninst(WIND_BASE)/.wind/uninst

    switch [llength [glob -nocomplain $uninst(home)/data.???]] {
       "0" {
           set uninst(mode) "none"
       }
       "1" {
           set uninst(mode) "all"
       }
       default {
           set uninst(mode) "part"
       }
    }

    uninstWin32

    # Done here if unix
    if {[isUnix]} {
        return
    }

    set binDir [unixToDos "$uninst(WIND_BASE)\\SETUP\\X86\\WIN32"]
    set uninstallCleanup $env(TMP)\\t2UninstallCleanup.exe

    # cd out of env(TMP) directory so we could actually remove the directory!!

    if {![isUnix]} {
        cd "\\"
    }

    if [catch {processCreate "$uninstallCleanup [pid] $env(TMP)"} error] {
        puts "$error"
    }

}

#########################################################################
#
# initializing code starts here
#
source $uninst(WIND_BASE)/.wind/uninst/INCLUDE.TCL
source $uninst(WIND_BASE)/SETUP/RESOURCE/TCL/CONFIG.TCL

# Added backward compatibility support for patches created by pre-veloce SETUP
# Initialize all variables defined in veloce CONFIG.TCL here if not defined

foreach var {STAND_ALONE WRS_STAND_ALONE TORNADO_PRODUCT} {
    if ![info exist $var] {
        global $var
        set value 0
        if ![string compare $var "WRS_STAND_ALONE"] {
            # default to WRS_STAND_ALONE product since this is
            # not a tornado product but still Wind River product
            set value 1
        }
        set $var $value
    }
}

if ![info exist prodInfo] {
    # for pre-veloce patches, default prod name to cdRom-description 
    # and empty for product version (since we won't know the version
    # or the version number may be a part of cdRom-description
    setProdInfo name [cdromDescGet]
    setProdInfo version ""
}

set string(header) "This program uninstalls [getProdInfo name] software\
                    from this machine.  Please select one of\
                    following choices."

set string(button1) "Uninstall [getProdInfo name] entirely."
set string(button2) "Uninstall the last installed session."

source $uninst(WIND_BASE)/.wind/uninst/INCLUDE.TCL

if {"[lindex $argv 1]" == "-seed"} {
    dllLoad $uninst(WIND_BASE)/SETUP/X86/WIN32/UITCLCONTROLS.DLL \
            _UITclControls_Init
    load $uninst(WIND_BASE)/SETUP/X86/WIN32/setuptcl.dll
    seedUninstall
} {
    start
}
