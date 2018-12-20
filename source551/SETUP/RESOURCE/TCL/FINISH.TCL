# FINISH.TCL  - Setup procedures for implementing finish page for full
#               installation for end user and nodelocked
#
# Copyright 1999-2003 Wind River Systems, Inc
#
# modification history
# --------------------
# 03g,14feb03,bjl  added manual lmHost handling for reordered ELM pages.
# 03f,20jun02,bjl  modified LM_LICENSE_FILE to check for existing setting
#                  in torVars files, updated unix finish message.
# 03e,17may02,wmd  Fix text formatting and grammatical errors.
# 03d,03may02,bjl  add LM_LICENSE_FILE to torVars files (spr 72884)
# 03c,05mar02,bwd  Modified SETUP to be non-tornado centric
# 03b,07feb02,bwd  SETUP deletes flexlm registries after first layer of
#                  uninstall. Do not log flexlm registries to prevent SETUP
#                  from deleting them.
# 03a,12jun01,j_w  Modified for Tornado 2.2
# 02c,08dec00,bwd  SPR 62832: fixed the order of the license servers list
#                  stored in env var LM_LICENSE_FILE
# 02b,30oct00,j_w  Added queueExecute at the end of pageProcess
# 02a,19may00,bwd  SPR 31068 - check/remove duplicate value for
#                  LM_LICENSE_FILE
# 01z,15may00,bwd  Fixed SPR 31062 - nodelock also displays this page and
#                  sets LM_LICENSE_FILE variable for Windows.
# 01y,01may00,bwd  Fixed/added LM instruction for bash, sh, and ksh
# 01x,26apr00,bwd  for UNIX, add codes to first check for existing
#                  LM_LICENSE_FILE variable before displaying appropriate
#                  finish message
# 01w,07apr00,bwd  Fixed the code: lmLicEnvVarInfo variable is only for UNIX
# 01v,24mar00,bwd  Changed dialog frame for this page to allow copy and paste
#                  the LM Environment Setup information
# 01u,02mar00,bwd  Changed the title of the LM Environment Setup dialog box
#                  for UNIX
# 01t,08feb00,j_w  Rename page title
# 01s,04Feb00,j_w  Made this page the final page for full installation if
#                  end user LM configuration is selected
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

global lmLicEnvVar
global lmLicEnvVarInfo
global outFileName
global modifiedLicenseVar

set outFileName ""

#############################################################################
#
# processTorVarsLine - replaces LM_LICENSE_FILE line
#
# This procedure will replace an LM_LICENSE_FILE line with lmLicEnvVar
# information, and simply reoutputs all other lines.
#
# SYNOPSIS
# processTorVarsLine <line> <fileID> <tmpFileID> <fileType>
#
# PARAMETERS:
#   line : torVars line to be processed
#   fileID : fileID of original torVars file
#   tmpFileID : fileID of temp torVars file
#   fileType: "sh" or "csh"
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc processTorVarsLine {line fileID tmpFileID fileType} {
    global lmLicEnvVar modifiedLicenseVar

    if {[eof $fileID]} {
        return 
    }

    set trimLine [string trimleft $line]

    if {[string first "LM_LICENSE_FILE" $line] != -1} {
        if {$fileType == "sh"} {
            if {[string first "\$LM_LICENSE_FILE" $trimLine] != -1 && 
                [string first "LM_LICENSE_FILE" $trimLine] == 0} { 
                puts $tmpFileID "    LM_LICENSE_FILE=$lmLicEnvVar:\$LM_LICENSE_FILE"
                set modifiedLicenseVar 1 
            } elseif {[string first "LM_LICENSE_FILE" $trimLine] == 0} { 
                puts $tmpFileID "    LM_LICENSE_FILE=$lmLicEnvVar" 
                set modifiedLicenseVar 1 
            } else { 
                puts $tmpFileID $line 
            }
        } elseif {$fileType == "csh"} {
            if {[string first "\$\{LM_LICENSE_FILE\}" $trimLine] != -1} { 
                puts $tmpFileID "    setenv LM_LICENSE_FILE $lmLicEnvVar:\$\{LM_LICENSE_FILE\}"
                set modifiedLicenseVar 1 
            } elseif {[string first "setenv" $trimLine] == 0} { 
                puts $tmpFileID "    setenv LM_LICENSE_FILE $lmLicEnvVar" 
                set modifiedLicenseVar 1 
            } else { 
                puts $tmpFileID $line 
            }
        }
    } else {
        puts $tmpFileID $line
    }
}

#############################################################################
#
# processTorVarsFile - processes a torVars file line by line
#
# This procedure will process a torVars file line by line, and add
# LM_LICENSE_FILE information to the torVars file if previous
# LM_LICENSE_FILE settings did not exist in the file.  
#
# SYNOPSIS
# processTorVarsFile <fileName> <tmpFileName> <fileType>
#
# PARAMETERS:
#   fileName : name of torVars file to be processed
#   tmpFileName : name of tmp file to store new torVars info
#   fileType: "sh" or "csh"
#
# RETURNS: 1 if successful, 0 if error
#
# ERRORS: N/A
#

proc processTorVarsFile {fileName tmpFileName fileType} {
    global modifiedLicenseVar lmLicEnvVar

    if [catch {open $fileName r} fileID] {
        dbgputs "processTorVarsFile: cannot open $fileName"
        return 0
    }

    if [catch {open $tmpFileName w} tmpFileID] {
        dbgputs "processTorVarsFile: cannot open $fileName"
        return 0
    }

    while {[eof $fileID] == 0} {
        gets $fileID line
        processTorVarsLine $line $fileID $tmpFileID $fileType
    }

    # add LM_LICENSE_FILE information if it does not already 
    # exist in the torVars file

    if {$modifiedLicenseVar == 0} { 
        if {$fileType == "sh"} { 
            puts $tmpFileID "if \[ \"\$LM_LICENSE_FILE\" = \"\" \] ; then" 
            puts $tmpFileID "    LM_LICENSE_FILE=$lmLicEnvVar" 
            puts $tmpFileID "else" 
            puts $tmpFileID "    LM_LICENSE_FILE=$lmLicEnvVar:\$LM_LICENSE_FILE" 
            puts $tmpFileID "fi" 
            puts $tmpFileID "export LM_LICENSE_FILE" 
        } elseif {$fileType == "csh"} { 
            puts $tmpFileID "if (\$?LM_LICENSE_FILE) then" 
            puts $tmpFileID "    setenv LM_LICENSE_FILE $lmLicEnvVar:\$\{LM_LICENSE_FILE\}" 
            puts $tmpFileID "else" 
            puts $tmpFileID "    setenv LM_LICENSE_FILE $lmLicEnvVar" 
            puts $tmpFileID "endif"

        }

    }


    close $fileID
    close $tmpFileID
    return 1
}

#############################################################################
#
# updateTorVarsFiles - updates torVars files with LM_LICENSE_FILE
#
# This is the main procedure to update torVars.sh and torVars.csh files
# with LM_LICENSE_FILE information.
#
# SYNOPSIS
# updateTorVarsFiles
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc updateTorVarsFiles {} {
    global modifiedLicenseVar

    set binDir [destDirGet]/host/[windHostTypeGet]/bin
    set torVarsShFile $binDir/torVars.sh
    set torVarsShTmpFile [tempDirGet]/torVars.sh
    set torVarsCshFile $binDir/torVars.csh
    set torVarsCshTmpFile [tempDirGet]/torVars.csh

    set modifiedLicenseVar 0
    if {[processTorVarsFile $torVarsShFile $torVarsShTmpFile "sh"] == 0} {
        return
    }
    set modifiedLicenseVar 0
    if {[processTorVarsFile $torVarsCshFile $torVarsCshTmpFile "csh"] == 0} {
        return
    }
    if [catch {file copy -force $torVarsShTmpFile $torVarsShFile}] {
        dbgputs "updateTorVarsFiles: could not overwrite $torVarsShFile"
    }
    if [catch {file copy -force $torVarsCshTmpFile $torVarsCshFile}] {
        dbgputs "updateTorVarsFiles: could not overwrite $torVarsCshFile"
    }
    if [catch {file delete -force $torVarsShTmpFile}] {
        dbgputs "updateTorVarsFiles: could not delete $torVarsShTmpFile"
    }
    if [catch {file delete -force $torVarsCshTmpFile}] {
        dbgputs "updateTorVarsFiles: could not delete $torVarsCshTmpFile"
    }
}

#############################################################################
#
# pageCreate(finish) - finish page for full installation with end user LM
#                      or nodelocked LM configuration
#
# This procedure will create a finsh page for full installation with 
# end user LM or nodelocked LM configuration (in lmOptions page).
#
# SYNOPSIS
# .tS
# pageCreate(finish)
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc pageCreate(finish) {} {
    global ctrlVals setupVals env lmVals
    global lmLicEnvVar lmLicEnvVarInfo

    windBaseReadFromRegistry
    set outFileName "[destDirGet]/lmEnvVar.txt"

    if { [isGUImode] } {
        set ctrlVals(volatileFrm) [list \
            [list label -name finishText \
                  -title [strTableGet FINISH_MSG1] \
                  -x 100 -y 10 -w 200 -h 15] ]

    } else { # TEXT mode

        printPageTitle [strTableGet FINISH_TITLE]
        puts [strTableGet FINISH_MSG1]
    }

    set lmLicEnvVar ""

    if { $setupVals(lmInstType) == "endUser" } {
        if {$setupVals(lmManual) == 0} {
            if {$lmVals(lmHostOrder) == ""} {
                set lmVals(lmHostOrder) $lmVals(lmHosts)
            }

            for {set ix 0} {$ix < [llength $lmVals(lmHostOrder)]} {incr ix} {
                set hostName [lindex $lmVals(lmHostOrder) $ix]
                set index [lmLicHostIndexGet $hostName]
                set hostPort [lmLicHostInfoGet hostPort $index]
                if {$hostPort == 0} {
                    set hostPort ""
                }
                if {$ix == 0} {
                    set hostInfo [format "%s@%s" $hostPort $hostName]
                } else {
                    if { [isUnix] } {
                        set hostInfo [format ":%s@%s" $hostPort $hostName]
                    } else {
                        set hostInfo [format ";%s@%s" $hostPort $hostName]
                    }
                }
                append lmLicEnvVar $hostInfo
            }
        } else {
            # manual         

            set hostInfo [format "%s@%s" $lmVals(lmPortManual) $lmVals(lmHostManual)]
            append lmLicEnvVar $hostInfo            
        }
    } else {  # nodelocked
        if { [isUnix] } {
            set licPath "[destDirGet]/.wind/license/WRSLicense.lic"
        } else {
            set licPath "[destDirGet]\\.wind\\license\\WRSLicense.lic"
        }

        append lmLicEnvVar $licPath
    }

    if { ![isUnix] } {
        if {![catch {sysRegistryValueRead HKEY_LOCAL_MACHINE \
                 "SOFTWARE\\FLEXlm License Manager"\
                 "LM_LICENSE_FILE"} lmLicFile]} {
            # value exists, append to it and write it back out

            set lmLicEnvVar "$lmLicEnvVar\;$lmLicFile"

            # make sure license entries are unique

            set tmp [split $lmLicEnvVar \;]
            set lmLicEnvVar [lunique $tmp]
            set lmLicEnvVar [join $lmLicEnvVar \;]
        }
    }

    if { [isUnix] } {
        if { [info exists env(LM_LICENSE_FILE)] } {
            set lmLicEnvVarInfo [format "\n\ncsh:\nsetenv LM_LICENSE_FILE %s\
                    \n\nbash/sh/ksh:\nLM_LICENSE_FILE=%s\nexport\
                    LM_LICENSE_FILE\n" $lmLicEnvVar:\$\{LM_LICENSE_FILE\} $lmLicEnvVar:\$LM_LICENSE_FILE]
        } else {
            set lmLicEnvVarInfo [format "\n\ncsh:\nsetenv LM_LICENSE_FILE %s\
                    \n\nbash/sh/ksh:\nLM_LICENSE_FILE=%s\nexport\
                    LM_LICENSE_FILE\n" $lmLicEnvVar $lmLicEnvVar]
        }

        if { [isGUImode] } {

            lappend ctrlVals(volatileFrm) \
                                [list text -name finishTextUnix -border -multiline\
                           -hscroll -vscroll -readonly\
                           -x 100 -y 23 -w 200 -h 150]
        }
    }

    if { [isGUImode] } {

        set w [dlgFrmCreate [strTableGet FINISH_TITLE]]

        controlValuesSet $w.nextButt "Finish"
        controlEnable $w.helpButt 0
        controlEnable $w.backButt 0
        controlEnable $w.nextButt 1
        controlEnable $w.cancelButt 0

        if { [isUnix] } {
            controlTextSet $w.finishTextUnix "[strTableGet FINISH_MSG2]\
                                          \n[destDirGet]/host/[windHostTypeGet]/bin/torVars.csh and\
                                          \n[destDirGet]/host/[windHostTypeGet]/bin/torVars.sh.\
                                          \n\n[string trimleft $lmLicEnvVarInfo]\
                                          \n[strTableGet FINISH_MSG3]\
                                          $outFileName."

            # the following is to workaround a bug in UITclSh: 
            # if the user presses Return for the OK button, 
            # UITclSh does not exit.

            if { !$ctrlVals(useInputScript) } {

                set notice "[strTableGet FINISH_MSG_DIALOG]"
   
                dialog ok_with_title \
                       "LM Environment Variables Setup" $notice
            }

        } else {
            controlFocusSet $w.nextButt
        }

        # test automation

        if { $ctrlVals(useInputScript) } {
            autoSetupLog "License Management Finish Page: skipped"
            autoSetupLog "[strTableGet FINISH_MSG1]"

            if { [isUnix] } {
                autoSetupLog "\n[strTableGet FINISH_MSG_COMMON]\
                              The information will be written to \
                              $outFileName for your convenience.\n"
            }

            nextCallback
        }

    } else { # TEXT mode

        if { [isUnix] } {

            puts "\n[strTableGet FINISH_MSG2]"
	    puts "\n[destDirGet]/host/[windHostTypeGet]/bin/torVars.csh and"
	    puts "\n[destDirGet]/host/[windHostTypeGet]/bin/torVars.sh.\n"
            puts $lmLicEnvVarInfo
            puts "[strTableGet FINISH_MSG3] $outFileName for your convenience.\n"
        }
        nextCallback
    }
}

#############################################################################
#
# pageProcess(finish) - process inputs from LM finish page if any 
#
# This procedure will process inputs from the license install finish page if 
# any.
#
# SYNOPSIS
# .tS
# pageProcess(finish)
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: 1 when successful
#
# ERRORS: N/A
#

proc pageProcess(finish) {} {
    global lmLicEnvVar lmLicEnvVarInfo
    global env outFileName
    global setupVals ctrlVals

    if { [isGUImode] } {
        # write the information to a file lmEnvVar.txt

        if {[isUnix]} {
            set outFileName "[destDirGet]/lmEnvVar.txt"
            if {[catch {open $outFileName w} fd]} {
                messageBox "Error opening output filename: $outFileName"
                return
            } else {
                puts $fd [string trimleft $lmLicEnvVarInfo]
                if {[catch {close $fd} err]} {
                    messageBox "Error closing file $outFileName"
                }
            }

            # update torVars.sh and torVars.csh

            updateTorVarsFiles
        } else {

            # check to see if the value exists: 
            # If not, create it. Otherwise, write to it.

            if { ![catch {sysRegistryValueRead HKEY_LOCAL_MACHINE \
                              "SOFTWARE\\FLEXlm License Manager"\
                              "LM_LICENSE_FILE"} result] } {
                # value exists, write to registry

                regValueWriteLog HKEY_LOCAL_MACHINE \
                    "SOFTWARE\\FLEXlm License Manager" "LM_LICENSE_FILE" $lmLicEnvVar false
                uninstLog setuplog "Wrote \"$lmLicEnvVar\" to \
                    HKEY_LOCAL_MACHINE\\SOFTWARE\\FLEXlm License Manager\\LM_LICENSE_FILE."

            } else {

                # the value doesn't exist, create and set value

                regKeyCreateLog HKEY_LOCAL_MACHINE "SOFTWARE" "FLEXlm License Manager" false

                regValueWriteLog HKEY_LOCAL_MACHINE \
                    "SOFTWARE\\FLEXlm License Manager" "LM_LICENSE_FILE" $lmLicEnvVar false

                uninstLog setuplog "Created and wrote \"$lmLicEnvVar\" to \
                    HKEY_LOCAL_MACHINE\\SOFTWARE\\FLEXlm License Manager\\LM_LICENSE_FILE."
            }
                                
            # flush the regKeyCreateLog and regValueWriteLog commands
            queueExecute
        }
    } else { # text mode

        # write the information to a file lmEnvVar.txt

        if { [isUnix] } {

            set outFileName "[destDirGet]/lmEnvVar.txt"
            if {[catch {open $outFileName w} fd]} {
                puts "Error opening output filename: $outFileName"
                while { [prompt "Press <Enter> to Continue"] != "" } {
                }

                return
            } else {
                puts $fd [string trimleft $lmLicEnvVarInfo]
                if {[catch {close $fd} err]} {
                    puts "Error closing file $outFileName"
                    while { [prompt "Press <Enter> to Continue"] != "" } {
                    }
                }
            }

            # update torVars.sh and torVars.csh

            updateTorVarsFiles
        }
    }
    return 1
}

######################################################################
# Dialog Text Messages
######################################################################

set strTable(FINISH_TITLE) "Finish"

set strTable(FINISH_REBOOT) \
    "You must reboot your machine in order to run [getProdInfo name]."

set strTable(FINISH_MSG_COMMON) \
     "IMPORTANT:\n\
     \nIn order to complete the installation, an environment variable\
     LM_LICENSE_FILE has to be set or appended to the existing one for\
     license management to work properly."

set strTable(FINISH_MSG_INSERT) \
     "IMPORTANT:\n\
     \nTo complete the installation, you must properly set the LM_LICENSE_FILE\
     environment variable."

set strTable(FINISH_MSG_DIALOG) \
        "[strTableGet FINISH_MSG_INSERT] \nPlease see the instructions on\
     the Finish page."

set strTable(FINISH_MSG1) \
        "License management has been successfully configured."

set strTable(FINISH_MSG2) \
     "IMPORTANT:\n\
     \nTo complete the installation, you must properly set the\
     \nLM_LICENSE_FILE environment variable or append it to an\
     \nexisting one. Add the following command to your startup\
     \nscript and either reboot, re-execute the script, or enter the\
     \ncommands manually.\
     \n\nNote: The LM_LICENSE_FILE setting has also been\
     \nadded to the Tornado environment scripts,"

set strTable(FINISH_MSG3) \
    "You can use the copy\/paste keys to\
     \ncopy this information from this page. The information\
     \nis also in "

set strTable(FINISH_MSG4) \
    "Please read the instructions on the Finish wizard page."
