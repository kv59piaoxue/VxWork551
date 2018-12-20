# LMSTARTUP.TCL - Setup procedures for implementing LM Startup choice 
#              wizard page
#
# Copyright 1999 Wind River Systems, Inc
#
# modification history
# --------------------
# 02b,05mar02,bwd  Modified SETUP to be non-tornado centric
# 02a,12jun01,j_w  Modified for Tornado 2.2
# 01o,07mar00,j_w  Made NT Service as the default choice
# 01n,02feb00,j_w  Execute queueExecute procedure once only
# 01m,21jan00,j_w  Read saved LM startup option from the registry
# 01l,19jan00,j_w  Restore the manual choice (version main/tor3_x/10)
# 01k,10jan00,j_w  Remove the manual choice
# 01j,30nov99,j_w  Added descriptions for each option
# 01i,29nov99,j_w  Add more FLEXlm Registries
# 01h,24nov99,j_w  Add FLEXlm Registries
# 01g,24nov99,j_w  Remove comments
# 01f,23nov99,bwd  Added sections for automatic LM Installation
# 01e,23nov99,j_w  Implement NT Service option
# 01d,23nov99,j_w  Enable the next button if doing automation
# 01c,22nov99,j_w  Added license Daemon to the Startup group
# 01b,13nov99,wmd  Need to disable the Back button on this page.
# 01a,01Oct99,j_w  written
#

#############################################################################
#
# pageCreate(lmStartupOptions) - displays choices of LM Startup options
#
# This procedure will display choices of LM Startup such as:
#  -- local startup group 
#  -- manually
#  -- NT Service
#
# SYNOPSIS
# .tS
# pageCreate(lmStartupOptions)
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#


proc pageCreate(lmStartupOptions) {} {
    global ctrlVals env setupVals

    set ctrlVals(volatileFrm) [list \
                [list label -name message1 \
                            -title [strTableGet LM_STARTUP_MSG_1] \
                            -x 100 -y 10 -w 190 -h 20] \
                [list choice -name serviceChoice -newgroup -auto \
                            -title [strTableGet LM_STARTUP_SERVICE] \
                            -x 100 -y 35 -w 208 -h 15 \
                            -callback onService] \
				[list label -name label1 \
				            -title [strTableGet LM_STARTUP_SERVICE_DESC] \
							-x 112 -y 50 -w 190 -h 25] \
				[list choice -name startupChoice -auto \
		                    -title [strTableGet LM_STARTUP_LOCAL] \
							-x 100 -y 75 -w 190 -h 15 \
							-callback onStartup] \
				[list label -name label2 \
				            -title [strTableGet LM_STARTUP_LOCAL_DESC] \
							-x 112 -y 90 -w 190 -h 25] \
                [list choice -name manualChoice -auto \
                            -title [strTableGet LM_STARTUP_MANUAL] \
                            -x 100 -y 115 -w 190 -h 15 \
                            -callback onManual] \
				[list label -name label3 \
				            -title [strTableGet LM_STARTUP_MANUAL_DESC] \
							-x 112 -y 130 -w 190 -h 25] ]


    set w [dlgFrmCreate [strTableGet LM_STARTUP_TITLE]]

	controlEnable $w.nextButt 1
    controlEnable $w.backButt 0
    controlEnable $w.cancelButt 1

	# check for previous LM startup option
    if { [lmStartupRegValueRead] == "" } {
		controlCheckSet $w.serviceChoice 1
    } else {
		switch $setupVals(lmStartupOption) {
			onStartup   { controlCheckSet $w.startupChoice 1 }
			onManual  { controlCheckSet $w.manualChoice 1 }
			onService { controlCheckSet $w.serviceChoice 1 }
			default   { controlCheckSet $w.startupChoice 1 }
		}
    }    

    if {$ctrlVals(useInputScript)} {
        autoSetupLog "License Management Startup Page: skipped"
        autoSetupLog "\tStartup Option: $setupVals(lmStartupOption)"
        nextCallback
    } 
}

#############################################################################
#
# pageProcess(lmStartupOptions) - process inputs from lmStartupOptions page 
#                                 if any
#
# This procedure will process inputs from lmInstOptions page if any
#
# SYNOPSIS
# .tS
# pageProcess(lmStartupOptions)
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: 1 when successful
#
# ERRORS: N/A
#

proc pageProcess(lmStartupOptions) {} {
    global setupVals infVals lmVals

	# Initialize 
	set infVals(lmStartup) 0
	set infVals(lmNTServ) 0
	set infVals(lmManual) 0

	beginWaitCursor

    switch $setupVals(lmStartupOption) {
		onStartup {
			set infVals(lmStartup) 1
		}
		onService {
			set infVals(lmNTServ) 1
		}
		onManual {
			# do nothing
			set infVals(lmManual) 1
		}
		default {
			puts "License Daemon process: unknown option: \
					$setupVals(lmStartupOption)"
		}
    }

    dbgputs "lmStartupOption: $setupVals(lmStartupOption)"
	
	set infFile [cdFileNameGet [file join RESOURCE INF LICMGNT.INF]]

	# registry values for FLEXlm
	global regLicense regLmgrd regLmgrd_log_file
	set regLicense $lmVals(lmLicenseFile)
	
	# convert "/" to "\" 
	regsub -all {/} $regLicense {\\} regLicense

	set regLmgrd "[destDirGet]\\host\\x86-win32\\bin\\lmgrd.exe"
	set regLmgrd_log_file "[destDirGet]\\.wind\\license\\lmgrd.log"

	# Add Registries and log the lmStartupOptions
	set infVals(addLMOption) 1
    searchAndProcessSection AddRegistry $infFile
    set infVals(addLMOption) 0

	# Add icon if any
	searchAndProcessSection AddIcon $infFile

	# Add NT Service if any
	searchAndProcessSection AddService $infFile
    
	# Write values to the registry
	queueExecute

	set infVals(lmStartup) 0
	set infVals(lmNTServ) 0
	set infVals(lmManual) 0
	

    endWaitCursor

    return 1
}

#############################################################################
#
# onStartup - set up wizard pages when local startup option is selected
#
# This procedure is a callback which sets up wizard pages when local startup
# is selected
#
# SYNOPSIS
# .tS
# onStartup
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc onStartup {} {
    global setupVals 

    set setupVals(lmStartupOption) "onStartup"
    
}

#############################################################################
#
# onManual - set up wizard pages when manual option is selected
#
# This procedure is a callback which sets up wizard pages when manual
# is selected
#
# SYNOPSIS
# .tS
# onManual
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc onManual {} {
    global setupVals

    set setupVals(lmStartupOption) "onManual"
}


#############################################################################
#
# onService - set up wizard pages when the NT Service option is selected
#
# This procedure is a callback which sets up wizard pages when NT Service
# is selected
#
# SYNOPSIS
# .tS
# onService
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc onService {} {
    global setupVals

    set setupVals(lmStartupOption) "onService"
}

#############################################################################
#
# lmStartupRegValueRead - load LM Startup option from the previous
#                         installation if any
#
# This procedure will load LM Startup option from the previous
# installation if any
#
# SYNOPSIS
# .tS
# lmStartupOptionRegValueRead
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: last saved LM startup selection
#
# ERRORS: N/A
#

proc lmStartupRegValueRead {} {
    global setupVals
    global ctrlVals

    # Load LM startup option from the previous installation if any

	if { $setupVals(lmStartupOption) == "" } {

        if {![catch {sysRegistryValueRead HKEY_CURRENT_USER \
                "Software\\$setupVals(WRS)" \
                lmStartupOption} retVal]} {

            set setupVals(lmStartupOption) $retVal

        } elseif {![catch {sysRegistryValueRead HKEY_LOCAL_MACHINE \
                "SOFTWARE\\$setupVals(WRS)" \
                lmStartupOption} retVal]} {

            set setupVals(lmStartupOption) $retVal
        }
    }

    return $setupVals(lmStartupOption)
}




######################################################################
# Dialog Text Messages
######################################################################

set strTable(LM_STARTUP_TITLE) "License Management Startup Options"

set strTable(LM_STARTUP_MSG_1) \
	"Choose one of the options below, then\
	click the <Next> button to continue the installation."

set strTable(LM_STARTUP_LOCAL) \
	"Install License Manager in the Startup Group"

set strTable(LM_STARTUP_MANUAL) \
	"Install License Manager to be run manually"

set strTable(LM_STARTUP_SERVICE) \
	"Install License Manager as an NT Service (Recommended)"


set strTable(LM_STARTUP_LOCAL_DESC) \
	"Choose this option if you would like to launch the [getProdInfo name] License\
	 Manager automatically during startup."

set strTable(LM_STARTUP_MANUAL_DESC) \
	"Choose this option if you would like to launch the [getProdInfo name] License\
	Manager by yourself in the Control Panel."

set strTable(LM_STARTUP_SERVICE_DESC) \
	"Choose this option if you would like to run the [getProdInfo name] License\
	Manager in the background once your machine is booted."


