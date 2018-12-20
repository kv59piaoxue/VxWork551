# REGISTRY.TCL - Setup procedures for implementing tornado registry wizard 
#                page
#
# Copyright 1999-2003 Wind River Systems, Inc
#
# modification history
# --------------------
# 03f,29apr03,bjl  text rewording.
# 03e,25jul02,wmd  Change Installation Guide to Getting Started Guide.
# 03d,15jul02,wmd  Modify instructions to remove NT when talking about service.
# 03c,17may02,wmd  Fix text formatting, grammatical problems.
# 03b,13may02,j_w  Fixed default option to NT service
# 03a,12jun01,j_w  Modified for Tornado 2.2
# 02i,15mar01,j_w  Added manual tornado registry configuration for Setup /R
#                  option
# 02h,14mar01,j_w  Added description for each choice (spr 63960)
# 02g,30oct00,j_w  Added manually startup option for Tornado Registry 
#                  (spr 35781)
# 02f,09oct00,bwd  If user has no ADMIN privileges, default choice to Startup
#                  Group
# 02e,10may00,j_w  Fixed typo
# 02d,01feb00,j_w  Fixed typo
# 02c,20jan00,j_w  Remove remoteRegistryHost, torRegManual and torRegNTServ
#                  references 
# 02b,24nov99,bwd  Added default value for auto setup
# 02a,30Sep99,j_w  Modified for T3
# 01f,11aug99,j_w  Added messages
# 01e,31mar99,bjl  set infVals(torRegManual) for manual registry.  
# 01d,24mar99,bjl  turn off inf write to registry after queueExecute.
# 01c,10feb99,tcy  modified for backward compatibility pages
# 01b,26jan99,tcy  added missing procedure regOptionRegValueRead().
# 01a,26jan99,tcy  extracted from INSTW32.TCL.
#

#############################################################################
#
# pageCreate(torRegistry) - display options to run tornado registry
#
# This procedure will display options to run tornado registry. Options are:
# torRegStartup - runs tornado registry when user logs on
# torRegRemote  - uses a remote server to run tornado registry
# torRegManual  - runs tornado registry manually (nothing is done by Setup)
# torRegNTServ  - runs tornado registry as a service
#
# SYNOPSIS
# .tS
# pageCreate(torRegistry)
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc pageCreate(torRegistry) {} {
    global ctrlVals
    global setupVals 
    
    set msg0 [strTableGet TORREGISTRY_OPTION_SELECT]
    set msgRegDesc [strTableGet TORREGISTRY_DESC]

    set ctrlVals(torRegStartup) [strTableGet TORREGISTRY_OPTION_STARTUP]
    set ctrlVals(torRegRemote)  [strTableGet TORREGISTRY_OPTION_REMOTE]
    set ctrlVals(torRegManual) [strTableGet TORREGISTRY_OPTION_MANUAL]
    set ctrlVals(torRegNTServ) [strTableGet TORREGISTRY_OPTION_SERVICE]

    set msg0Ctrl [list label -name msg0 -title $msg0 \
                             -x 100 -y 40 -w 205 -h 20]

    set msgRegDescCtrl [list label -name msg0 \
                         -title $msgRegDesc \
                         -x 100 -y 10 -w 205 -h 24]
    set radio1_ypos 65
    set radio2_ypos 78
    set radio3_ypos 91
    set radio4_ypos 104
            
    # NT Service choice
    set torRegNTServCtrl [list choice \
                        -name torRegNTServ \
                        -title $ctrlVals(torRegNTServ) \
                        -newgroup \
                        -callback {onTorRegOptSel torRegNTServ} \
                        -auto \
                        -x 100 -y $radio1_ypos -w 205 -h 10]

    # Startup choice
    set torRegStartupCtrl [list choice \
                        -name torRegStartup \
                        -title $ctrlVals(torRegStartup) \
                        -auto \
                        -callback {onTorRegOptSel torRegStartup} \
                        -x 100 -y $radio2_ypos -w 205 -h 10]

    # manually startup choice
    set torRegManualCtrl [list choice \
                        -name torRegManual \
                        -title $ctrlVals(torRegManual) \
                        -callback {onTorRegOptSel torRegManual} \
                        -auto \
                        -x 100 -y $radio3_ypos -w 205 -h 10]

    # remote choice
    set torRegRemoteCtrl [list choice \
                        -name torRegRemote \
                        -title $ctrlVals(torRegRemote) \
                        -callback {onTorRegOptSel torRegRemote} \
                        -auto \
                        -x 100 -y $radio4_ypos -w 205 -h 10]
                 
    # create the controls
    set ctrlVals(volatileFrm) \
                        [list $msg0Ctrl $msgRegDescCtrl \
                        $torRegNTServCtrl $torRegStartupCtrl \
                        $torRegManualCtrl $torRegRemoteCtrl]

    # display NT service info
    if {![isUnix] && $ctrlVals(admin) == 1} {
        set msg1Ctrl [list label -name msg1 \
                                 -title [strTableGet TORREGISTRY_MSG1] \
                                 -x 100 -y 125 -w 205 -h 50]
        lappend ctrlVals(volatileFrm) $msg1Ctrl 
    }  
    
    set w [dlgFrmCreate [strTableGet TORREGISTRY_TITLE]]

    # test automation

    if { $ctrlVals(useInputScript) } {
        autoSetupLog "Tornado Registry Page: skipped"

        # if user does not have admin privileges, default to Startup

        if { ($ctrlVals(NT) == "1") && ($ctrlVals(admin) != "1") } {
            set setupVals(torRegAction) "torRegStartup"
        }

        if {![info exists setupVals(torRegAction)]} {
            set setupVals(torRegAction) "torRegStartup"
            autoSetupLog \
                "\tRegistry Process: unspecified. Default process used."
        }

        onTorRegOptSel $setupVals(torRegAction)
        switch $ctrlVals(torRegAction) {
            torRegStartup {
                autoSetupLog "\t$ctrlVals(torRegStartup)"
            }
            torRegNTServ {
                autoSetupLog "\t$ctrlVals(torRegNTServ)"
            }
            torRegManual {
                autoSetupLog "\t$ctrlVals(torRegManual)"
            }
            orRegRemote {
                autoSetupLog "\t$ctrlVals(torRegRemote)"
            }
            default {
                autoSetupLog \
                    "\tRegistry process unknown: $setupVals(torRegAction)"

                set setupVals(torRegAction) "torRegStartup"
                onTorRegOptSel $setupVals(torRegAction)

                autoSetupLog "\tDefault process used: $ctrlVals(torRegStartup)" }
        }

        nextCallback
    } else {

        if { ($ctrlVals(NT) == "1") && ($ctrlVals(admin) != "1") } {

            # if user does not have admin privileges, do not allow
            # installation of Registry as a service.

            controlEnable $w.torRegNTServ 0
            controlCheckSet $w.torRegNTServ 0
            controlCheckSet $w.torRegStartup 1
            controlFocusSet $w.torRegStartup

            set setupVals(torRegOption) "torRegStartup"
            onTorRegOptSel $setupVals(torRegOption)

            dbgputs "You are not admin -- torRegNTServ is not enabled"

        } else {

            if {[regOptionRegValueRead] == ""} {
                set setupVals(torRegOption) "torRegNTServ"
            }

            controlCheckSet $w.$setupVals(torRegOption) 1
            controlFocusSet $w.$setupVals(torRegOption)
            onTorRegOptSel $setupVals(torRegOption)
        }

        controlEnable $w.backButt 1
        controlEnable $w.nextButt 1

        if {[instTypeGet] == "registryInst"} {
            controlEnable $w.backButt 0
            controlValuesSet $w.nextButt "Finish"
            controlEnable $w.nextButt 1
        }

    }
}

#############################################################################
#
# pageProcess(torRegistry) - process inputs from torRegistry page
#
# This procedure will process input from torRegisry page
#
# SYNOPSIS
# .tS
# pageProcess(torRegistry)
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: 1 when successful
#
# ERRORS: N/A
#

proc pageProcess(torRegistry) {} {
    global ctrlVals
    global setupVals
    global infVals env

    if {"[windRegValueRead]" == ""} {
        set setupVals(registry) localhost
    }

    beginWaitCursor

    switch $ctrlVals(torRegAction) {

        torRegStartup {
            set infVals(torRegStartup) 1

            pageRemove remoteRegistryHost
            set ctrlVals(isRemoteRegHostPageRemoved) 1
        }
        
        torRegRemote {
            # user selected to configure a remote registry

            set infVals(torRegRemote) 1
            set ctrlVals(isRemoteRegHostPageRemoved) 0
        }
        
        torRegManual {
            # user wants to install the registry
            # manually

            set infVals(torRegManual) 1
            
            pageRemove remoteRegistryHost
            set ctrlVals(isRemoteRegHostPageRemoved) 1
        }

        torRegNTServ {
            set infVals(torRegNTServ) 1

            pageRemove remoteRegistryHost
            set ctrlVals(isRemoteRegHostPageRemoved) 1
        }

        default {
            puts "tor registry process: unknown option: \
                $ctrlVals(torRegAction)"
        }
    }

    set infVals(addRegOption) 1

    # added this because we would like to come back to the registry
    # and remember what we selected

    set setupVals(torRegOption) $ctrlVals(torRegAction)

    searchAndProcessSection AddRegistry [cdFileNameGet [file join RESOURCE \
                                         INF TORNADO.INF]]
    queueExecute
    set infVals(addRegOption) 0


    ## for Setup /R option -- Tornado Registry configuration ##

    if {[instTypeGet] == "registryInst"} {

        # get WIND_BASE
        windBaseReadFromRegistry

        switch $ctrlVals(torRegAction) {
            torRegStartup {
                # install tornado registry as NT service and remove startup
                # icon
                if {[torRegistryStartupIconAdd]} {
                    torRegistryServiceRemove "$setupVals(torRegServName)"
                }
            }
            torRegNTServ {
                # install startup icon and remove NT service
                if {[torRegistryServiceAdd "$setupVals(torRegServName)"]} {
                    torRegistryStartupIconRemove
                }
            }
            torRegManual {
                # remove startup icon and service
                torRegistryStartupIconRemove
                torRegistryServiceRemove "$setupVals(torRegServName)"
                messageBox "Tornado registry service has been removed.\
                            \nTornado registry icon in the Startup Group has been\
                            removed."
            }
        }
    }

    ## end ##

    endWaitCursor
    return 1
}

#############################################################################
#
# onTorRegOptSel - set the variable in ctrlVals when option is changed
#
# This procedure will  set the variable in ctrlVals when option is changed
#
# SYNOPSIS
# .tS
# onTorRegOptSel <opt>
# .tE
#
# PARAMETERS:
# .IP opt
# option selected
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc onTorRegOptSel {opt} {
    global ctrlVals

    set ctrlVals(torRegAction) $opt

}

#############################################################################
#
# regOptionRegValueRead - load tornado registry option from the previous
#                         installation if any
#
# This procedure will load tornado registry option from the previous
# installation if any
#
# SYNOPSIS
# .tS
# regOptionRegValueRead
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: last saved tornado registry selection
#
# ERRORS: N/A
#

proc regOptionRegValueRead {} {
    global setupVals
    global ctrlVals

    # Load tornado registry option from the previous installation if any

    if ![info exists setupVals(torRegOption)] {
        set setupVals(torRegOption) ""

        if {![catch {sysRegistryValueRead HKEY_CURRENT_USER \
                "Software\\$setupVals(WRS)" \
                registryOption} retVal]} {

            set setupVals(torRegOption) $retVal

        } elseif {![catch {sysRegistryValueRead HKEY_LOCAL_MACHINE \
                "SOFTWARE\\$setupVals(WRS)" \
                registryOption} retVal]} {

            set setupVals(torRegOption) $retVal
        }
    }

    return $setupVals(torRegOption)
}

#############################################################################
#
# torRegistryServiceAdd - Install Tornado Registry as an NT service
#
# This procedure will install Tornado Registry as an NT service and start it
# if successful. This procedure is used for post-install Tornado Registry 
# configuration. (Setup /R)
#
# SYNOPSIS
# .tS
# torRegistryServiceAdd serviceName
# .tE
#
# PARAMETERS: Service Name
#
# RETURNS: 1 if success, 0 if failed
#
# ERRORS: N/A
#
proc torRegistryServiceAdd {serviceName} {
        global setupVals env

        if {[destDirGet] == "" } {
            if {$env(WIND_BASE) != ""} {
                destDirSet $env(WIND_BASE)
            } else {
                messageBox -stop "Environment variable WIND_BASE is not set or \
                                 found in the windows registry."
            }
        }

        # The following code is copied from INF.TCL

        set servicePath "host\\x86-win32\\bin"
        set serviceExe  "wtxregds.exe"
        set dependency ""
        set rootKey  HKEY_LOCAL_MACHINE
        set key "SYSTEM\\CurrentControlSet\\Services\\$serviceName"
        set valueName ImagePath
        set value [fullPathName $servicePath $serviceExe]

        if {![catch {setupServiceInstall $serviceName \
                        [fullPathName $servicePath $serviceExe] $dependency} err]} {
            dbgputs "service installed: $serviceName"
                
        } else {

            # NT service registry data
                
            # check if "Tornado Registry" exists in the service registry
            # if exists, that means the service has already been installed
            # and we only have to overwrite the wtxregds.exe path and restart
            # the service
                        
            if {[regValueExists $rootKey $key $valueName]} {
                if {![catch {sysRegistryValueWrite \
                             $rootKey $key $valueName $value} error2]} {
                    dbgputs "New registry value written. Service Installed."
                } else {
                    dbgputs "Failed to install $serviceName: $error2"
                }
            } else {
                dbgputs "Unable to install $serviceName"
            }
        }
                
                
        if {[catch {setupServiceStart $serviceName} err]} {
                dbgputs "Failed to start service $serviceName: $err"
                messageBox "Error: Failed to install $serviceName as a service."
                return 0
        } else {
                dbgputs "service started: $serviceName"
                messageBox "$serviceName has been installed as a service."
                return 1
        }
        

}
        
#############################################################################
#
# torRegistryServiceRemove - Remove the Tornado Registry Service
#
# This procedure will remove Tornado Registry as an NT service. This 
# procedure is used for post-install Tornado Registry configuration. 
# (Setup /R)
#
# SYNOPSIS
# .tS
# torRegistryServiceRemove
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: 1 if success, 0 if failed
#
# ERRORS: N/A
#
proc torRegistryServiceRemove {serviceName} {

        if {[catch {setupServiceStop $serviceName} err]} {
                dbgputs "cannot stop service, $serviceName: $err"
        } else {
                dbgputs "stopped service: $serviceName"
        }

        if {[catch {setupServiceRemove $serviceName} err]} {
                dbgputs "cannot delete service: $serviceName: $err"
                return 0
        } else {
                dbgputs "deleted service: $serviceName"
                return 1
        }
}

#############################################################################
#
# torRegistryStartupIconAdd - Install Tornado Registry in the startup group
#
# This procedure will install Tornado Registry in the startup group
# This procedure is used for post-install Tornado Registry 
# configuration. (Setup /R)
#
# SYNOPSIS
# .tS
# torRegistryStartupIconAdd
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: 1 if success, 0 if failed
#
# ERRORS: N/A
#
proc torRegistryStartupIconAdd {} {
        global ctrlVals env

        #destDirSet $env(WIND_BASE)
        
        if {[destDirGet] == "" } {
            if {$env(WIND_BASE) != ""} {
                destDirSet $env(WIND_BASE)
            } else {
                messageBox -stop "Environment variable WIND_BASE is not set or \
                                 found in the windows registry."
                return 0
            }
        }

        set folder "Startup"
        set item   "Tornado Registry"
        set exe    "[destDirGet]\\host\\x86-win32\\bin\\wtxregd.exe"
        set args   "-V"
        set dir    "[destDirGet]\\host\\x86-win32\\bin"
        set mode   "$ctrlVals(admin)"
        set fMin   0

        ### The following code is copied from linkCreateLog{} in UTILW32.TCL

        # create the group
        if {[catch {setupLinkDelete $folder $item $mode} error]} {
                messageBox -stop "Unable to delete $folder. \
                                Failed to add $item icon in the $folder group."
                return 0
        } else {

                if {[catch {setupLinkCreate $folder \
                                $item \
                                $exe \
                                $args \
                                $dir \
                                $mode \
                                $fMin} error]} {
                        
                        messageBox -stop "Error: Failed to install $item icon \
                                        in the $folder group."
                } else {
                        dbgputs "added icon: $item"
                        messageBox "Tornado registry has been installed in the \
                                        Startup Group"
                        return 1
                }
        }
}

#############################################################################
#
# torRegistryStartupIconRemove - Remove Tornado Registry icon  in the 
#                                startup group
#
# This procedure will remove Tornado Registry icon in the startup group
# This procedure is used for post-install Tornado Registry 
# configuration. (Setup /R)
#
# SYNOPSIS
# .tS
# torRegistryStartupIconRemove
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: 1 if success, 0 if failed
#
# ERRORS: N/A
#
proc torRegistryStartupIconRemove {} {
        global ctrlVals env

        set folder "Startup"
        set item   "Tornado Registry"
        set mode   $ctrlVals(admin)

        if {[catch {setupLinkDelete $folder $item $mode} error]} {
                dbgputs "Error: Unable to delete the $item folder."
                return 0
        } else {
                dbgputs "deleted $item in $folder group"
                return 1
        }
} 



######################################################################
# Dialog Text Messages
######################################################################

set strTable(TORREGISTRY_TITLE) "Tornado Registry"

set strTable(TORREGISTRY_DESC) \
    "The Tornado target server registry is a daemon that keeps track\
     of all available targets by name. Only one registry is required on\
     your network, and it can run on any networked host."

set strTable(TORREGISTRY_OPTION_SELECT) \
    "The following configuration options will allow you to define how\
     you will use the Tornado registry:"

set strTable(TORREGISTRY_OPTION_SERVICE) \
    "Run the Tornado registry as a Windows service (typical)"

set strTable(TORREGISTRY_OPTION_SERVICE_DESC) \
        "Select this option to have the Tornado registry started automatically \
        on this machine at boot time."

set strTable(TORREGISTRY_OPTION_STARTUP) \
    "Run the Tornado registry as part of the Startup Group"

set strTable(TORREGISTRY_OPTION_STARTUP_DESC) \
        "Select this option to have the Tornado registry started automatically \
        on this machine when the current user logs on."

set strTable(TORREGISTRY_OPTION_MANUAL) \
        "Start the Tornado registry manually"

set strTable(TORREGISTRY_OPTION_MANUAL_DESC) \
        "Select this option if you want to start the registry manually using \
        the Windows Start menu before running Tornado."
        
set strTable(TORREGISTRY_OPTION_REMOTE) \
        "Use a remote Tornado registry"
        
set strTable(TORREGISTRY_MSG1) \
    "NOTE: If you will be using Tornado outside of a networked development\
     environment (for example, with a notebook computer off-site), we\
     recommend that you select the Windows service or Windows Startup\
     Group option."

        
