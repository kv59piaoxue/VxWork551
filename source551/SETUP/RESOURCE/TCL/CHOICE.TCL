# CHOICE.TCL - Setup procedures for implementing installation-choice wizard 
#              page
#
# Copyright 1999-2003 Wind River Systems, Inc
#
# modification history
# --------------------
# 03i,29apr03,bjl  text rewording.
# 03h,20feb03,bjl  sysadmin license server wording modifications for ELM.
# 03g,14feb03,bjl  modified floating license server wording. 
# 03f,03oct02,bjl  modified message text to use core product name rather
#                  than cdrom description (spr 77983).  
# 03e,15jul02,wmd  Modify the shortcuts explanation to say "already
#                  installed".
# 03d,17may02,wmd  Change format of text.
# 03c,05mar02,bwd  Modified SETUP to be non-tornado centric
# 03b,24jan02,wmd  Add check for evaluation, then disable licAdmin
#                  path.
# 03a,12jun01,j_w  Modified for Tornado 2.2
# 03a,07may01,j_w  Update text messages
# 02z,15dec00,wmd  Fix test placement.
# 02y,02nov00,j_w  Name change - Tornado AE
# 02x,19oct00,bwd  If no tornado or windview products on CD, grey out program
#                  group and LM Inst options
# 02w,02oct00,bwd  Changed to update LMHelpPath in pageProcess
# 02v,02oct00,bwd   Set LMHelpPath global variable to sysadmin upon choosing
#                  LM Installation choice
# 02u,23may00,j_w  set setupVals(lmInstType) to "floating" if user selected LM
#                  installation
# 02t,10may00,j_w  Removed non-debug messages
# 02s,27mar00,bwd  Created a dialog box "LM HOST CONFIRMATION" to prompt 
#                  users for the right host for LM Installation
# 02r,20mar00,bwd  Fixed TEXT mode to default a choice to Full Installation
# 02q,10mar00,j_w  Fixed Wording
# 02p,26jan00,j_w  Fixed spacing
# 02o,25jan00,bwd  Deleted redundant codes and fixed deleting pages manually
# 02n,12jan00,bwd  Added License Management Installation option for TEXT MODE
# 02m,17dec99,clc  change  switch patterns
# 02l,30nov99,j_w  Update LM install option messages
# 02k,16nov99,clc  change text mode variable to setupVals(cmdMode)
# 02j,12nov99,j_w  Add instTypeSet license
# 02i,10nov99,j_w  Fixed test automation
# 02h,05nov99,j_w  added setupVals in pageCreate
# 02g,02nov99,bwd  Auto setup: changed log file to display installChoice
# 02f,01nov99,bwd  Added the section for automatic setup
# 02f,19oct99,clc  add text mode
# 02e,14oct99,bjl  catch controlDestroy of noKeyText in case control
#                  was not previously created.
# 02d,06oct99,j_w  Addedd group box
# 02c,04oct99,j_w  Fixed radio button selection
# 02b,01oct99,j_w  Fixed layout
# 02a,30Sep99,j_w  Modified for T3
# 01b,17feb99,tcy  added new variable setupVals(iconInstallation) to denote
#                  program group installation
# 01a,26jan99,tcy  extracted from INSTW32.TCL.
#

#############################################################################
#
# pageCreate(installChoice) - displays choices of installation
#
# This procedure will display choices of installation such as:
# Full Install  - install all or selected number of Tornado products
# License Management - License Management options
# Program Group - install the Tornado program group and icons only
#
# SYNOPSIS
# .tS
# pageCreate(installChoice)
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc pageCreate(installChoice) {} {
    global ctrlVals setupVals LMHelpPath

    set fullInstDesc ""
    if { [isTornadoProduct] } {
        set fullInstDesc [strTableGet INSTALLCHOICE_TOR_FULL_INSTALL_DESC]
    } else {
        set fullInstDesc [strTableGet INSTALLCHOICE_FULL_INSTALL_DESC]
    }

    if { [isGUImode] } {
        set LMHelpPath ""

        set ctrlVals(volatileFrm) [list \
                [list label -name message1 \
                            -title [strTableGet INSTALLCHOICE_MSG_1] \
                            -x 100 -y 10 -w 160 -h 15] \
                [list choice -name fullInstallChoice -newgroup -auto \
                             -title [strTableGet INSTALLCHOICE_FULL_INSTALL] \
                             -x 102 -y 35 -w 190 -h 15 \
                             -callback onFullInstall] \
                [list label -name fullLabel \
                             -title $fullInstDesc \
                             -x 114 -y 50 -w 190 -h 25] ]
        if {![isUnix]} {
            lappend ctrlVals(volatileFrm) \
                [list choice -name prgGrpChoice -auto \
                             -title [strTableGet INSTALLCHOICE_PROG_GROUP] \
                             -x 102 -y 70 -w 100 -h 15 \
                             -callback onPrgGrpInstall] \
                [list label -name prgGrpLabel \
                             -title [strTableGet INSTALLCHOICE_PROG_GROUP_DESC] \
                             -x 114 -y 85 -w 190 -h 25] \
                [list choice -name licMgntChoice -auto \
                             -title [strTableGet INSTALLCHOICE_LIC_MGNT] \
                             -x 102 -y 125 -w 190 -h 15 \
                             -callback onLicMgnt] \
                [list label -name licMgntLabel \
                            -title [strTableGet INSTALLCHOICE_LIC_MGNT_DESC] \
                            -x 114 -y 140 -w 180 -h 25] \
                [list group -name group1 \
                            -title [strTableGet INSTALLCHOICE_GRP_1] \
                            -x 98 -y 25 -w 210 -h 85 ] \
                [list group -name group2 \
                            -title [strTableGet INSTALLCHOICE_GRP_2] \
                            -x 98 -y 115 -w 210 -h 52]    
        } else {
            lappend  ctrlVals(volatileFrm) \
                [list choice -name licMgntChoice -auto \
                             -title [strTableGet INSTALLCHOICE_LIC_MGNT] \
                             -x 102 -y 93 -w 200 -h 15 \
                             -callback onLicMgnt] \
                [list label -name licMgntLabel \
                            -title [strTableGet INSTALLCHOICE_LIC_MGNT_DESC] \
                            -x 114 -y 108 -w 180 -h 17] \
                [list group -name group1 \
                            -title [strTableGet INSTALLCHOICE_GRP_1] \
                            -x 98 -y 25 -w 210 -h 52 ] \
                [list group -name group2 \
                            -title [strTableGet INSTALLCHOICE_GRP_2] \
                            -x 98 -y 85 -w 210 -h 42]
        }

        set w [dlgFrmCreate [strTableGet INSTALLCHOICE_TITLE]]

        # rename the next button to "Send" (in case of UNIX)
        controlValuesSet $w.nextButt "&Next >"

        # if launch from Tornado GUI for get/install license,
        # disable full and program installation
        if { [info exists env(SETUP_LICMGNT)] && $env(SETUP_LICMGNT) == 1} {
            controlEnable $w.fullInstallChoice 0
            controlEnable $w.fullLabel 0
            controlCheckSet $w.licMgntChoice 1
            #controlCheckSet $w.fullInstallChoice 0
                        
            if {![isUnix]} {
                controlEnable $w.prgGrpChoice 0
                controlEnable $w.prgGrpLabel 0
            }
        } else {
            # select the choice
            if { $setupVals(installChoice) == "" } {
                controlCheckSet $w.fullInstallChoice 1
            } else {
                switch $setupVals(installChoice) {
                    onFullInstall   { controlCheckSet $w.fullInstallChoice 1 }
                    onPrgGrpInstall { controlCheckSet $w.prgGrpChoice 1 }
                    onLicMgnt       { controlCheckSet $w.licMgntChoice 1 }
                    default         { controlCheckSet $w.fullInstallChoice 1 }
                }
            }
        }   

        if { $setupVals(evaluation) == 1 } {
            controlEnable $w.licMgntChoice 0
            }

        # check if any licensed product exists   
        set licProdFlag 0
        foreach index [cdInfoGet productIndexList] {
            set featureId [productInfoGet featureId $index]
            if { $featureId > 0 } {
                set licProdFlag 1
            }
        }
                
        # If no licensed products on CD, grey out program
        # group and LM Inst options
        if { $licProdFlag != 1 } {
            controlCheckSet $w.fullInstallChoice 1
            controlEnable $w.licMgntChoice 0
            controlEnable $w.licMgntLabel 0
            if { ![isUnix] } {
                controlEnable $w.prgGrpChoice 0
                controlEnable $w.prgGrpLabel 0
            }
            controlEnable $w.group2 0
        }

        # test automation
        if { $ctrlVals(useInputScript) } {
            autoSetupLog "Installation Option page: skipped"
            autoSetupLog "\tInstallChoice: $setupVals(installChoice)"
            nextCallback
        }

    } else { # TEXT mode

        printPageTitle [strTableGet INSTALLCHOICE_TITLE]
        puts "[strTableGet INSTALLCHOICE_MSG_1]\n"
        puts "1 - [strTableGet INSTALLCHOICE_FULL_INSTALL]"
        puts "$fullInstDesc\n"
        puts "2 - [strTableGet INSTALLCHOICE_LIC_MGNT]"
        puts "[strTableGet INSTALLCHOICE_LIC_MGNT_DESC]\n\n"

        puts "Please enter the number of your selection. \[1\]"
        while (1) {
            set ret [prompt]
            switch -regexp -- $ret {
                "^$" -
                "^1$" { 
                    onFullInstall
                    nextCallback
                    return 0
                } 
                "^2$" { 
                    onLicMgnt
                    nextCallback
                    return 0
                }
                "^[eE][xX][iI][tT]$" {
                    return 0
                } 
                "^-$" {
                    backCallback
                    return 0
                }
                default { 
                    puts "Error: Invalid input."
                }
            }
        }
    }
}

#############################################################################
#
# pageProcess(installChoice) - process inputs from installChoice page if any
#
# This procedure will process inputs from installChoice page if any
#
# SYNOPSIS
# .tS
# pageProcess(installChoice)
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: 1 when successful
#
# ERRORS: N/A
#

proc pageProcess(installChoice) {} {
    global setupPageList setupVals ctrlVals tornadoInstalled
    global LMHelpPath

    if { [isGUImode] } {
        switch $setupVals(installChoice) {
            onFullInstall {
                instTypeSet "core"
                if {[isUnix]} {     
                    pageListAdd "unixFullInstPages"
                } else {
                    pageListAdd "winFullInstPages"
                }
                if { [isStandAlone] } { pageRemove projectInfo }              

                if { [string compare [instKeyGet] "none"] == 0} {
                    # the install key is "none" remove the project info page
                    catch {controlDestroy  $ctrlVals(mainWindow).noKeyText}
                }
            }
            onLicMgnt {
                if { ![catch {exec hostname} hostName] } {

                    if { $ctrlVals(useInputScript) } {
                        autoSetupLog "Proceed with LM Installation on host: $hostName"
                        onProceed
                    } else {

                        dialogCreate \
                            -name onLicMgnt_prompt \
                            -title "LM HOST CONFIRMATION" \
                            -width 200 -height 145 \
                            -init {
                                controlPropertySet onLicMgnt_prompt.host_name -bold 1;
                            } \
                            -controls \
                             [list [list label -name host_name \
                                               -title "Current host: $hostName" \
                                               -x 15 -y 10 -w 100 -h 20] \
                                   [list label -name msg_text \
                                               -title \
                                                "[strTableGet ONLICMGNT_HOST_CONFIRM]\
                                                 [strTableGet ONLICMGNT_HOST_PROMPT]" \
                                               -x 15 -y 30 -w 170 -h 90] \
                                   [list button -name proceed -title "Proceed" \
                                                -callback onProceed \
                                                -x 100 -y 120 -w 40 -h 15] \
                                   [list button -name exit -title "Exit" \
                                                -callback onExit \
                                                -x 150 -y 120 -w 30 -h 15] ]
                    }
                }
                set LMHelpPath "sysadmin"
            }
            onPrgGrpInstall {
                instTypeSet "icon"
                if { [isTornadoProduct] } {  set tornadoInstalled 1  }

                # Denote program group installation; used in proc regTornado()

                set setupVals(iconInstallation) 1
                                
                if {![isUnix]} {
                    pageListAdd "winPrgGrpPages"
                }
            }
        }
    } else { # TEXT mode
                
        switch $setupVals(installChoice) {
            onFullInstall {
                instTypeSet "core"
                if {[isUnix]} {
                    pageListAdd "unixFullInstPages"
                } else {
                    pageListAdd "winFullInstPages"
                }
            }
            onLicMgnt {
                if { ![catch {exec hostname} hostName] } {
                    puts "\nCurrent host: $hostName\n"
                    puts "[strTableGet ONLICMGNT_HOST_CONFIRM]\n"

                    set msg "\nSelect: 1 - To proceed with LM\
                             Installation on this host.\
                             \n        2 - To exit this SETUP sesstion."

                    while (1) {
                        switch -regexp -- [prompt $msg] {
                            "^-$" {  return [pageCreate(installChoice)]  }
                            "^1$" {  onProceed  ;  break     }
                            "^2$" {  onExit     ;  return 0  }
                        }
                    }
                }
            }
            default { 
                puts -nonewline "Error: $setupVals(installChoice)"
                puts " is not available in text mode\n"
                return 0
            }
        }
    }
    
    dbgputs "installChoice: $ctrlVals(pageList)"        

        # debug         
        set currPageIndex [lsearch $ctrlVals(pageList) $ctrlVals(currPage)]
        set nextPageIndex [expr $currPageIndex + 1]
        set nextPage [lindex $ctrlVals(pageList) $nextPageIndex]
        dbgputs "nextPage = $nextPage"

    return 1
}

#############################################################################
#
# onFullInstall - set up wizard pages when full installation option is selected
#
# This procedure is a callback which sets up wizard pages when full \
# installation is selected
#
# SYNOPSIS
# .tS
# onFullInstall
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc onFullInstall {} {
    global setupVals

    set setupVals(installChoice) "onFullInstall"
}

#############################################################################
#
# onLicMgnt - set up wizard pages when License Management Installation 
#             option is selected
#
# This procedure is a callback which sets up wizard pages when LM Installation
# is selected
#
# SYNOPSIS
# .tS
# onLicMgnt 
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc onLicMgnt {} {
    global setupVals

    set setupVals(installChoice) "onLicMgnt"
    set setupVals(lmInstType) "floating"
}


#############################################################################
#
# onPrgGrpInstall - set up wizard pages when program group option is selected
#
# This procedure is a callback which sets up wizard pages when program \
# group is selected
#
# SYNOPSIS
# .tS
# onPrgGrpInstall
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc onPrgGrpInstall {} {
    global setupVals

    set setupVals(installChoice) "onPrgGrpInstall"
}


#############################################################################
#
# CALL BACK ROUTINE: for "On License Management Installation" prompt dialog
#
#############################################################################

proc onProceed {} { # user clicks "Proceed"
    global setupVals ctrlVals

    instTypeSet "license"
    set setupVals(lmInstType) "floating"
    pageListAdd "floatLicInst"

    if { [isGUImode] && !$ctrlVals(useInputScript) } {
        windowClose onLicMgnt_prompt  
    }
}

proc onExit {} { # user clicks "Exit"
    global setupVals

    if { [isGUImode] } {
        set setupVals(cancel) 1         
        quitCallback
        windowClose onLicMgnt_prompt
    }
    return 0
}


######################################################################
# Dialog Text Messages
######################################################################

set strTable(INSTALLCHOICE_TITLE) "Installation Options"

set strTable(INSTALLCHOICE_MSG_1) "Choose the type of installation:"

set strTable(INSTALLCHOICE_FULL_INSTALL) "Install Product"

set strTable(INSTALLCHOICE_LIC_MGNT) \
                "Install license server (system administrator)"

set strTable(INSTALLCHOICE_PROG_GROUP) "Shortcuts installation"

set strTable(INSTALLCHOICE_TOR_FULL_INSTALL_DESC) \
        "Installs the [getProdInfo name] products, tools, compilers, and other\
        optional components that you may have purchased."

set strTable(INSTALLCHOICE_FULL_INSTALL_DESC) \
        "Installs the [getProdInfo name] products and other\
        optional components that you may have purchased."

set strTable(INSTALLCHOICE_LIC_MGNT_DESC) \
        "Installs and configures a license server on the local host.  It is not\
	 part of standard product installation."

set strTable(INSTALLCHOICE_PROG_GROUP_DESC) \
        "Installs only the [getProdInfo name] tools icons to provide\
        access to a [getProdInfo name] installation on another host system."

set strTable(INSTALLCHOICE_GRP_1) "[getProdInfo name] Installation"
 
set strTable(INSTALLCHOICE_GRP_2) "License Server Installation"

set strTable(ONLICMGNT_HOST_CONFIRM) \
    "SETUP will proceed to install and configure a license server on this\
     host. Please make sure that this is the right host to be configured.\
     If this is not the desired host, please exit this SETUP session and\
     run SETUP and License Management Server installation on the desired host."

set strTable(ONLICMGNT_HOST_PROMPT) \
     "\n\nTo proceed with License Management Server installation on this host,\
     click \"Proceed\". Otherwise, please click \"Exit\" to exit SETUP."
