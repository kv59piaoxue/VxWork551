# LMCONFIG.TCL - Setup procedures for implementing user lmConfig wizard page
#
# Copyright 1999-2003 Wind River Systems, Inc
#
# modification history
# --------------------
# 02f,14feb03,bjl  modified for ELM page sequence, modified floating license
#                  server wording.  
# 02e,29jan03,wmd  Implement for ALI 2.0.
# 02d,17may02,wmd  Fix text formatting and grammatical errors.
# 02c,01may02,j_w  Fixed SPR 75403 - modified warning msg if no hosts to 
#                  select 
# 02b,05mar02,bwd  Modified SETUP to be non-tornado centric
# 02a,12jun01,j_w  Modified for Tornado 2.2
# 01p,07may01,j_w  Removed "Feature ID" in the detail box
# 01o,02mar01,wmd  Alphabetize the list of available hosts.
# 01n,22may00,bwd  SPR 31003 - set a variable to return to DBQUERY page if
#                  user click cancel while retrieving data from database
# 01m,17mar00,j_w  Fixed typo
# 01l,14feb00,wmd  Change all references to prodCode to featureId.
# 01k,04feb00,j_w  Enable the next button if at least one host is selected
# 01j,03feb00,wmd  Add dialog box to tell user that license management has not
#                  been configured yet.
# 01i,06jan00,bwd  No test automation for command line SETUP
# 01h,17dec99,clc  change  switch statement patterns
# 01g,30nov99,clc  add text mode
# 01f,30nov99,wmd  Add port information in the details dialog.
# 01e,24nov99,bwd  Added sections for automatic LM Installation
# 01d,23nov99,bwd  Fixed typos
# 01c,22nov99,wmd  Add code to remove lmregister page if on Unix.
# 01b,17nov99,wmd  Add logic to implement the page.
# 01a,29oct99,wmd  written
#

global infoStr

#############################################################################
#
# pageCreate(lmConfig) - displays license management configuration 
#                        information for the user to select
#
# This procedure will display possible license management information and 
# allows the user to modify it to suit his needs
#
# SYNOPSIS
# .tS
# pageCreate(lmConfig)
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc pageCreate(lmConfig) {} {
    global ctrlVals
    global setupVals
    global lmVals lmHostRecs lmHostRecsLen
    global cancelDBQUERY

    # if user clicks Cancel while retrieving data from
    # Wind River database, return to DBQUERY page
    if { $cancelDBQUERY } {
        set cancelDBQUERY 0
        backCallback
        return 1
    }

    # obtain user's LM server information

    if { [isGUImode] } {

        lmConfigValuesGet

        set ctrlVals(volatileFrm) [list \
                [list label -name message1 \
                            -title [strTableGet LMCONFIG_MSG_1] \
                            -x 99 -y 10 -w 206 -h 29] \
                [list label -name availServersLabel \
                            -title [strTableGet LMCONFIG_AVAIL_SERVERS_LABEL] \
                            -x 99 -y 41 -w 66 -h 10] \
                [list label -name selectedServersLabel \
                            -title [strTableGet LMCONFIG_SEL_SERVERS_LABEL] \
                            -x 200 -y 41 -w 66 -h 10] \
                [list list -name lmAvailServers -multisel \
                            -callback onLmAvailServers \
                            -x 99 -y 54 -w 69 -h 90] \
                [list list -name lmSelServers -multisel \
                            -callback onLmSelServers \
                            -x 200 -y 54 -w 69 -h 90] \
                [list button -name lmAddServers -title "-->" \
                            -callback onLmAddServers \
                            -x 173 -y 75 -w 21 -h 14] \
                [list button -name lmRemoveServers -title "<--" \
                            -callback onLmRemoveServers \
                            -x 173 -y 93 -w 21 -h 14] \
                [list button -name lmUp -title "Up" \
                            -callback onLmUp \
                            -x 275 -y 75 -w 25 -h 14] \
                [list button -name lmDown -title "Down" \
                            -callback onLmDown \
                            -x 275 -y 93 -w 25 -h 14] \
                [list button -name lmDetailsButton -title "Details..." \
                            -callback onLmDetails \
                            -x 99 -y 138 -w 48 -h 14] \
                [list label -name message2 \
                            -title [strTableGet LMCONFIG_MSG_2] \
                            -x 99 -y 157 -w 206 -h 13] \
        ]

        set w [dlgFrmCreate [strTableGet LMCONFIG_TITLE]]

        set lmVals(lmHostOrder) {}

        # enable the next button in case it was disabled from below

        controlEnable $w.nextButt 0

        # disable the controls for add/remove, up/down

        controlEnable $w.lmAddServers 0
        controlEnable $w.lmRemoveServers 0
        controlEnable $w.lmUp 0
        controlEnable $w.lmDown 0
        controlEnable $w.lmDetailsButton 0
 
        # fill in the available servers

        controlValuesSet $w.lmAvailServers $lmVals(lmAvailHosts)

        if {[isUnix]} {
             # remove the lmregister page
             pageRemove lmRegister
        }

        # if there are no servers available, warn the user to configure 
        # or exit Setup
      
        if {$lmVals(lmAvailHosts) == ""} {
            notConfigDlg
            controlEnable $w.nextButt 0            
            if {$setupVals(ELMUser) == 1} {
                set setupVals(cancel) 1
                applicationExit
            }
        }

        # test automation
    
        if { $ctrlVals(useInputScript) } {
            for {set ix 0} {$ix < [llength $lmVals(lmAvailHosts)]} {incr ix} {
                lappend lmVals(lmHostOrder) [lindex $lmVals(lmAvailHosts) $ix]
            }
            autoSetupLog "User License Management Configuration Page: skipped"
            autoSetupLog "\tSelected Server(s): $lmVals(lmHostOrder)"
            nextCallback
        }

    } else {

        # text mode 

        lmConfigValuesGet

        if {[isUnix]} {
             # remove the lmregister page
             pageRemove lmRegister
        }
        
        set lmVals(lmHostSelected) {}

        # prompt for list of license servers
        while (1) {
            
            # print page header

            printPageTitle [strTableGet LMCONFIG_TITLE]
            puts "[strTableGet LMCONFIG_MSG_1_TEXT]\n"

            # if available servers is empty, warn user	    

            if {$lmVals(lmAvailHosts) == ""} {
                puts "[strTableGet LMCONFIG_NO_CONFIG_WARNING]"

                while (1) {
                    set ret [prompt [strTableGet LMCONFIG_NO_CONFIG_ACCEPT_MSG]]
                    switch -regexp -- $ret {
                        "^-$" {
                            backCallback
                            return 0
                        }

                        "[eE][xX][iI][tT]" {
                            return 0
                        }

                        default {
                            puts "License Management is not configured, please \
                                backup to the previous page\nor exit Setup.\n"
                        }
                    }
                }
            }

            # display available servers

            puts [strTableGet LMCONFIG_AVAIL_SERVERS_LABEL]
            set i 1
            foreach host $lmVals(lmAvailHosts) {
                puts "$i - $host"
                incr i
            }
            puts ""

            # display selected servers

            puts [strTableGet LMCONFIG_SEL_SERVERS_LABEL]
            if { $lmVals(lmHostSelected) == "" } {
                puts "No server selected"
            } else {
                foreach server $lmVals(lmHostSelected) {
                    puts $server
                }
            }
            puts ""
        
            set ret [prompt [strTableGet LMCONFIG_SERVER_ACCEPT_MSG]]
            switch -regexp -- $ret {
                "^-$" {
                    backCallback
                    return 0
                }
                "^[0-9]+([ ][0-9]+)*$" {
                    selectServers $ret
                }
                "[eE][xX][iI][tT]" {
                    return 0
                }
                "^$" {
                    set lmVals(lmHostOrder) $lmVals(lmHostSelected)
                    nextCallback
                    return 0
                }
                default {
                    puts "The list you have entered is invalid."
                }
            }
        }
    }   
}

#############################################################################
#
# notConfigDlg - dialog to inform user that license management is not 
#       yet configured.
#
#
# SYNOPSIS
# .tS
# notConfigDlg
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#
proc notConfigDlg {} {
    global setupVals

    if {$setupVals(ELMUser) == 1} { 
        dialog ok_with_title "Setup" [strTableGet LMCONFIG_NO_CONFIG_ELM]
    } else {
        dialog ok_with_title "Setup" [strTableGet LMCONFIG_NO_CONFIG]
    }
}

#############################################################################
#
# lmConfigValuesGet - get LM server configuration
#
# This procedure will get the necessary LM server information for this project
#
# SYNOPSIS
# .tS
# lmConfigValuesGet
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc lmConfigValuesGet {} {
    global lmVals lmHostRecs lmHostRecsLen lmHostFeaturesNum

    set lmVals(lmHostSelected) {}
    set lmVals(lmHostOrder) {}
    set lmVals(lmAvailHosts) {}
    for {set ix 0} {$ix < $lmHostRecsLen} {incr ix} {
        set hostRec [split [lindex $lmHostRecs $ix] |]
        set hostName [lindex $hostRec 0]
        set numberOfFeatures [lindex $lmHostFeaturesNum $ix]

        # For each host, see if it has at least 1 floating license
        # then add to list of lmAvailHosts
        
        for {set ixf 0} {$ixf < $numberOfFeatures} {incr ixf} {
            if {[lmLicProdInfoGet licFLAllocated $hostName $ixf] > 0} {
                lappend lmVals(lmAvailHosts) $hostName
                break
            }
        }
    }
    set lmVals(lmAvailHosts) [lsort $lmVals(lmAvailHosts)]
  
}

#############################################################################
#
# selectServers - add servers 
#
# This procedure will get the necessary LM server information for this project
#
# SYNOPSIS
# .tS
# selectServers
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#
proc selectServers {servList} {

    global lmVals

    set lmVals(lmHostSelected) {}

    foreach index $servList {
        lappend lmVals(lmHostSelected) \
                 [lindex $lmVals(lmAvailHosts) [expr $index - 1]]
    }

}
        

#############################################################################
#
# onLmAvailServers - get input from list box control for available servers
#
# This procedure will gather the selected servers chosen by the user.
#
# SYNOPSIS
# .tS
#  onLmAvailServers
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc onLmAvailServers {} {
    global lmVals

    set args [controlEventGet wizardDialog.lmAvailServers]
    set lmVals(lmHostSelected) {}

    set event [lindex $args 0]
    set args [controlSelectionGet wizardDialog.lmAvailServers -string]
    if {[string match $event "selchange"] && $args != ""} {
        set args [split $args]
        for {set ix 0} {$ix < [llength $args]} {incr ix} {
            lappend lmVals(lmHostSelected) [lindex $args $ix]
        }
        controlEnable wizardDialog.lmDetailsButton 1
        controlEnable wizardDialog.lmAddServers 1
    } else {
        set lmVals(lmHostSelected) {}
        controlEnable wizardDialog.lmDetailsButton 0
    }
}

#############################################################################
#
# onLmSelServers - get user selected servers from the list control
#
# This procedure will gather the user selected servers from the list control
#
# SYNOPSIS
# .tS
# onLmSelServers
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc onLmSelServers {} {
    global lmVals

    set args [controlEventGet wizardDialog.lmSelServers]
    set lmVals(lmHostSelected) {}

    set event [lindex $args 0]
    set args [controlSelectionGet wizardDialog.lmSelServers -string]
    if {[string match $event "selchange"] && $args != ""} {
        set args [split $args]
        for {set ix 0} {$ix < [llength $args]} {incr ix} {
            lappend lmVals(lmHostSelected) [lindex $args $ix]
        }
        controlEnable wizardDialog.lmDetailsButton 1
        controlEnable wizardDialog.lmRemoveServers 1
     } else {
        set lmVals(lmHostSelected) {}
        controlEnable wizardDialog.lmDetailsButton 0
    }
}

#############################################################################
#
# licDetailsDlgInit - inits display data
#
# This procedure will display server information for the selected server(s)
#
# SYNOPSIS
# .tS
# licDetailsDlgInit
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc licDetailsDlgInit {} {
    global infoStr

    controlValuesSet licDetailsDlg.hostLicenseInfo $infoStr
    controlFocusSet licDetailsDlg.ok
}


#############################################################################
#
# onLmDetails - callback for details button
#
# This procedure will display server information for the selected server
#
# SYNOPSIS
# .tS
# onLmDetails
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc onLmDetails {} {
    global lmVals setupVals ctrlVals

    set len [llength $lmVals(lmHostSelected)]

    if {$len == 0} {
        return
    }

    # compile the information to be displayed from the lmHostRecs

    compileHostDetails

    # display a dialog with the details of hosts selected

    set controls   [list \
        [list label -name msg1 \
                    -title [strTableGet LMCONFIG_DETAILS_LABEL_1] \
                    -x 10 -y 10 -w 200 -h 20] \
        [list text -name hostLicenseInfo \
                    -multiline -vscroll -readonly \
                    -x 10 -y 40 -w 200 -h 60] \
        [list button -name ok \
                    -title "&OK" -default \
                    -callback {windowClose licDetailsDlg} \
                    -x 85 -y 110 -w 50 -h 14] \
       ]

    dialogCreate \
        -name licDetailsDlg \
        -title [strTableGet LMCONFIG_DETAILS_TITLE] \
        -init licDetailsDlgInit \
        -parent $ctrlVals(parentDialog) \
        -helpfile $setupVals(setupHelp) \
        -width 220 -height 130 \
        -controls $controls
}

#############################################################################
#
# compileHostDetails - get host details to be displayed for selected hosts
#
# This procedure will place the selected servers to the selected colunm
#
# SYNOPSIS
# .tS
# compileHostDetails
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: A string containing the information to be displayed
#   Host: xxx
#           Licensed Product: prodname featureId
#           Number of Licenses: xx
#   ...
#
# ERRORS: N/A
#

proc compileHostDetails {} {
    global lmVals lmHostRecs lmHostRecsLen
    global infoStr lmHostFeaturesNum

    set hostInfo ""
    for {set ix 0} {$ix < [llength $lmVals(lmHostSelected)]} {incr ix} {
        set hostName [lindex $lmVals(lmHostSelected) $ix]
        for {set i 0} {$i < $lmHostRecsLen} {incr i} {
            if {$hostName == [lmLicHostInfoGet hostName $i]} {
                break
            }
        }
        set port [lmLicHostInfoGet hostPort $ix]
        if {$port == 0} {set port "default=27000"}
        append hostInfo [format "%s  %s\r\n" "Host: $hostName" \
                "Port: $port"]
        append hostInfo [format "    %s\r\n" "Licensed Product(s)"]
        for {set pix 0} {$pix < [lindex $lmHostFeaturesNum $i]} {incr pix} {
            if {[lmLicProdInfoGet licFLAllocated $hostName $pix] != 0} {
                append hostInfo [format "\t%s: " \
                    [lmLicProdInfoGet prodName $hostName $pix]]
                append hostInfo [format " %s license(s)\r\n" \
                    [lmLicProdInfoGet licFLAllocated $hostName $pix]]
                }
           }
        append hostInfo [format "\r\n"]
    }
    set infoStr $hostInfo
}

#############################################################################
#
# onLmAddServers - callback for the "-->" button to add servers to selected
#
# This procedure will place the selected servers to the selected colunm
#
# SYNOPSIS
# .tS
# onLmAddServers
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc onLmAddServers {} {
    global lmVals

    for {set ix 0} {$ix < [llength $lmVals(lmHostSelected)]} {incr ix} {
        set index [lsearch $lmVals(lmAvailHosts) [lindex $lmVals(lmHostSelected) $ix]]
        if {[lsearch $lmVals(lmHostOrder) \
                [lindex $lmVals(lmHostSelected) $ix]] == -1} {
            set lmVals(lmAvailHosts) [lreplace $lmVals(lmAvailHosts) $index $index]
            lappend lmVals(lmHostOrder) [lindex $lmVals(lmHostSelected) $ix]
            controlEnable wizardDialog.lmRemoveServers 1
            if {[llength $lmVals(lmHostOrder)] > 1} {
                controlEnable wizardDialog.lmUp 1
                controlEnable wizardDialog.lmDown 1
            }
        }
    }

    controlValuesSet wizardDialog.lmSelServers $lmVals(lmHostOrder)
    controlValuesSet wizardDialog.lmAvailServers $lmVals(lmAvailHosts)

    if {[llength $lmVals(lmAvailHosts)] == 0} {
        controlEnable wizardDialog.lmAddServers 0
        set lmVals(lmAvailHosts) {}
    }
    set lmVals(lmHostSelected) {}
    controlEnable wizardDialog.lmDetailsButton 0

        # enable the next button
        controlEnable wizardDialog.nextButt 1
}

#############################################################################
#
# onLmRemoveServers - callback to remove the selected server from the selected
#                     to the available list.
#
# This procedure will place the selected server(s) to the available server list.
#
# SYNOPSIS
# .tS
# onLmRemoveServers
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc onLmRemoveServers {} {
    global lmVals

    for {set ix 0} {$ix < [llength $lmVals(lmHostSelected)]} {incr ix} {
        set index [lsearch $lmVals(lmHostOrder) [lindex $lmVals(lmHostSelected) $ix]]
        if {[lsearch $lmVals(lmAvailHosts) \
                [lindex $lmVals(lmHostSelected) $ix]] == -1} {
            set lmVals(lmHostOrder) [lreplace $lmVals(lmHostOrder) $index $index]
            lappend lmVals(lmAvailHosts) [lindex $lmVals(lmHostSelected) $ix]
            controlEnable wizardDialog.lmAddServers 1
            if {[llength $lmVals(lmHostOrder)] < 2} {
                controlEnable wizardDialog.lmUp 0
                controlEnable wizardDialog.lmDown 0
            }
        }
    }
    controlValuesSet wizardDialog.lmSelServers $lmVals(lmHostOrder)
    controlValuesSet wizardDialog.lmAvailServers $lmVals(lmAvailHosts)

    if {[llength $lmVals(lmHostOrder)] == 0} {
        controlEnable wizardDialog.lmRemoveServers 0
        controlEnable wizardDialog.lmUp 0
        controlEnable wizardDialog.lmDown 0
        set lmVals(lmHostOrder) {}
                
                # disable the next button
                controlEnable wizardDialog.nextButt 0
    }
    set lmVals(lmHostSelected) {}
    controlEnable wizardDialog.lmDetailsButton 0
}

#############################################################################
#
# onLmUp - callback to handle Up button
#
# This procedure will move the selected server to the next higher position
# in the selected servers list box.
#
# SYNOPSIS
# .tS
# onLmUp
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc onLmUp {} {
    global lmVals

    if {[llength $lmVals(lmHostSelected)] == 0 || \
        [llength $lmVals(lmHostOrder)] == 1} {
        return
    }

    # create an indexed list of hosts

    for {set ix 0} {$ix < [llength $lmVals(lmHostOrder)]} {incr ix} {
        set indexedHosts($ix) [lindex $lmVals(lmHostOrder) $ix]
    }
    set ix 0
    while {$ix < [llength lmVals(lmHostOrder)]} {
      for {set ixs 0} {$ixs < [llength $lmVals(lmHostSelected)]} {incr ixs} {
        foreach {key value} [array get indexedHosts] {
            if {$value == [lindex $lmVals(lmHostSelected) $ixs]} {

                # found a match, delete it from lmHostOrder and reinsert higher

                set lmVals(lmHostOrder) [lreplace $lmVals(lmHostOrder) $key $key]
                set lmVals(lmHostOrder) [linsert $lmVals(lmHostOrder) \
                    [expr $key - 1] $value]
            }
          }
          incr ix
        }
    }

    controlValuesSet wizardDialog.lmSelServers ""
    for {set ix 0} {$ix < [llength $lmVals(lmHostOrder)]} {incr ix} {
        controlValuesSet wizardDialog.lmSelServers -append [lindex $lmVals(lmHostOrder) $ix]
    }
    controlEnable wizardDialog.lmDetailsButton 0
    set lmVals(lmHostSelected) {}    
}

#############################################################################
#
# onLmDown - callback to handle the Down button
#
# This procedure will move the selected server down one position in the 
# selected servers list box.
#
# SYNOPSIS
# .tS
# onLmDown
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc onLmDown {} {
    global lmVals

    if {[llength $lmVals(lmHostSelected)] == 0 || \
        [llength $lmVals(lmHostOrder)] == 1} {
        return
    }

    if {[llength $lmVals(lmHostOrder)] != 0} {
        controlEnable wizardDialog.lmDown 1
    }

    # create an indexed list of hosts

    for {set ix 0} {$ix < [llength $lmVals(lmHostOrder)]} {incr ix} {
        set indexedHosts($ix) [lindex $lmVals(lmHostOrder) $ix]
    }
    set ix 0
    while {$ix < [llength lmVals(lmHostOrder)]} {
      for {set ixs 0} {$ixs < [llength $lmVals(lmHostSelected)]} {incr ixs} {
        foreach {key value} [array get indexedHosts] {
            if {$value == [lindex $lmVals(lmHostSelected) $ixs]} {

                # found a match, insert it higher

                set lmVals(lmHostOrder) [linsert $lmVals(lmHostOrder) \
                    [expr $key + 2] $value]
                set lmVals(lmHostOrder) [lreplace $lmVals(lmHostOrder) $key $key]
            }
          }
          incr ix
        }
    }

    controlValuesSet wizardDialog.lmSelServers ""
    for {set ix 0} {$ix < [llength $lmVals(lmHostOrder)]} {incr ix} {
        controlValuesSet wizardDialog.lmSelServers -append [lindex $lmVals(lmHostOrder) $ix]
    }
    controlEnable wizardDialog.lmDetailsButton 0
    set lmVals(lmHostSelected) {}    
}

#############################################################################
#
# pageProcess(lmConfig) - process inputs from lmConfig page
#
# This procedure will process inputs from lmConfig page
#
# SYNOPSIS
# .tS
# pageProcess(lmConfig)
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc pageProcess(lmConfig) {} {
    global setupVals
    global ctrlVals

    # At this point, lmVals(lmHostOrder) contains the list of servers in the
    # order that the user wants licenses be served

    set retVal 1

    return $retVal
}


######################################################################
# Dialog Text Messages
######################################################################

set strTable(LMCONFIG_TITLE) "User License Management Configuration"

set strTable(LMCONFIG_MSG_1) \
    "Select from the list of available license server(s)\
    on your network below.  Use the Up and Down buttons to change\
    the order in which license servers are searched."

set strTable(LMCONFIG_MSG_1_TEXT) \
    "Select from the list of available license server(s)\
    on your network below." 

set strTable(LMCONFIG_MSG_2) "Details will provide license information\
    for the highlighted host."

set strTable(LMCONFIG_HOST_PING_ERR_1) \
        "Setup cannot establish a connection with host: "

set strTable(LMCONFIG_HOST_PING_ERR_2) \
        "Please check that network routine tables, or network masks\
        are setup correctly for your host."

set strTable(LMCONFIG_AVAIL_SERVERS_LABEL) "Available Server(s):"

set strTable(LMCONFIG_SEL_SERVERS_LABEL) "Selected Server(s):"

set strTable(LMCONFIG_DETAILS_TITLE) "Selected Hosts License Information"

set strTable(LMCONFIG_DETAILS_LABEL_1) \
        "Setup has detected the following license configurations for\
        the following host(s):"

set strTable(LMCONFIG_SERVER_ACCEPT_MSG) \
    "Press <Return> to accept the setting.  To change the setting,\n\
     enter a list of server numbers in the order which license\n\
     servers are to be accessed separated by spaces."

#set strTable(LMCONFIG_NO_CONFIG) \
#   "Setup has determined that [getProdInfo name] License Management has not 
#been\ configured for your site.  Please exit this program and contact\
#    your system administrator to configure license management\
#    with the Setup program, or back up to the \"License Management Options\"\
#    page and configure Node Locked Licensing for this host."

set strTable(LMCONFIG_NO_CONFIG) \
   "Setup has determined that [getProdInfo name] License Management has\
    not been configured for your site. Please exit this program and contact\
    your system administrator to setup a license server on your\
    site, then run Setup -L to continue your License Management\
    configuration.\n\n\If you prefer a Node Locked license, go back to the\
    \"License Management Options\" page and configure Node Locked\
    Licensing for this host."

set strTable(LMCONFIG_NO_CONFIG_ELM) \
   "License Management is incomplete. Setup has detected that there are\
    no license servers configured for this product. Please request that\
    your system administrator set up at least one license server for\
    [getProdInfo name].  Re-run Setup with the option /L to configure\
    license management for your server.  Setup will now exit."
    
set strTable(LMCONFIG_NO_CONFIG_WARNING) \
   " Setup has determined that [getProdInfo name] License Management has not been\n\
   configured for your site.  Please exit this program and contact\n\
   your system administrator to configure license management\n\
   with the Setup program, or back up to the \"License Management Options\"\n\
   page and configure Node Locked Licensing for this host.\n\n"

set strTable(LMCONFIG_NO_CONFIG_ACCEPT_MSG) \
   "Press <-> to backup, or type <exit> to quit Setup."
