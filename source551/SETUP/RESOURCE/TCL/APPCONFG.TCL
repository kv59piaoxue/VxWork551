# APPCONFG.TCL - Setup procedures allowing users to select which file types should use
#                this product (ex: Tornado 2.2) as the default application (for Windows)
#
# Copyright 1999-2003 Wind River Systems, Inc
#
# modification history
# --------------------
# 01p,29apr03,bjl  text rewording.
# 01o,05mar02,bwd  Modified SETUP to be non-tornado centric
# 01n,18jan02,bwd  Added .s files mapping
# 01m,07may01,j_w  Change display layout. Replace 3.1 with
#                  $setupVals(torVersionNum)
# 01l,16mar01,wmd  Need to add code to change next button to Finish.
# 01k,16mar01,wmd  Fix spr 64976, add file association command to Setup.
# 01j,13mar01,j_w  update version 3.0 to 3.1
# 01i,13dec00,bwd  Call appDefaultCallback in pageProcess to prevent the
#                  default selections being saved unintentionally.
# 01h,18oct00,bwd  SPR 31096: modified file types selections
# 01g,09oct00,bwd  SPR 34894: Skip searchAndProcessSection if user has no
#                  ADMIN privileges. SPR 35218: modified to clear out only
#                  the registries that the file associations will be configured
# 01f,03oct00,bwd  SPR 34894: inform user that file association configuration
#                  fails when user has no ADMIN privilege.
# 01e,12sep00,bwd  Changed instructions on the page
# 01d,09aug00,bwd  SPR 31096: add searchAndProcessSection
# 01c,11may00,bwd  Fix SPR 31096 - more work on appConfig page display and
#                  callback function
# 01b,10may00,bwd  Fix SPR 31096 (phase 1)
# 01a,10may00,bwd  Written
#

global typeList
set typeList {proj wksp tcl source windview}

#############################################################################
#
# pageCreate(appConfig) - display options to select file types
#
# This procedure will display options to select which file types should 
# use this product as the default application.
#
# SYNOPSIS
# .tS
# pageCreate(appConfig)
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc pageCreate(appConfig) {} {
    global ctrlVals

    set msg0 [strTableGet APPCONFIG_OPTION_SELECT]
    set msgDesc [strTableGet APPCONFIG_DESC]

    set msg0Ctrl [list label -name msg0 -title $msg0 \
                             -x 100 -y 40 -w 205 -h 25]

    set msgDescCtrl [list label -name msg0 \
                                -title $msgDesc \
                                -x 100 -y 10 -w 205 -h 30]

    set msg1Ctrl [list label -name msg1 \
                         -title [strTableGet APPCONFIG_MSG1] \
                         -x 100 -y 73 -w 100 -h 10]
                         
    set choiceHeight 13
    set radio1_ypos 86
    set radio2_ypos [expr $radio1_ypos + $choiceHeight]
    set radio3_ypos [expr $radio2_ypos + $choiceHeight]
    set radio4_ypos [expr $radio3_ypos + $choiceHeight]
    set radio5_ypos [expr $radio4_ypos + $choiceHeight]
    set radio6_ypos [expr $radio5_ypos + $choiceHeight]

	# Project Type
	set projType [list boolean -name proj -auto \
                               -title [strTableGet APPCONFIG_OPTION1]\
			                   -x 100 -y $radio1_ypos -w 205 -h 10]

    # Workspace Type
	set wkspType [list boolean -name wksp -auto \
                               -title [strTableGet APPCONFIG_OPTION2]\
			                   -x 100 -y $radio2_ypos -w 205 -h 10]

	# TCL Type
    set tclType [list boolean -name tcl -auto \
                              -title [strTableGet APPCONFIG_OPTION3]\
			                  -x 100 -y $radio3_ypos -w 205 -h 10]

	# Source Type (C, C++, Header Files)
    set sourceType [list boolean -name source -auto \
                                 -title [strTableGet APPCONFIG_OPTION4]\
			                     -x 100 -y $radio4_ypos -w 205 -h 10]

	# WindView Type
    set windviewType [list boolean -name windview -auto \
                                   -title [strTableGet APPCONFIG_OPTION5]\
			                       -x 100 -y $radio5_ypos -w 205 -h 10]

	set ctrlVals(volatileFrm) \
			[list $msg0Ctrl $msgDescCtrl $msg1Ctrl \
			$projType $wkspType $tclType $sourceType $windviewType]

    set ctrlVals(fileTypes) [dlgFrmCreate [strTableGet APPCONFIG_TITLE]]

    # default values
    controlCheckSet $ctrlVals(fileTypes).proj 1
    controlCheckSet $ctrlVals(fileTypes).wksp 1
    controlCheckSet $ctrlVals(fileTypes).tcl 0
    controlCheckSet $ctrlVals(fileTypes).source 0
    controlCheckSet $ctrlVals(fileTypes).windview 1

    controlEnable $ctrlVals(fileTypes).backButt 1
    controlEnable $ctrlVals(fileTypes).nextButt 1
    controlFocusSet $ctrlVals(fileTypes).nextButt

    if {[string compare [instTypeGet] "fileAssociation"] == 0} {
        controlEnable $ctrlVals(fileTypes).backButt 0
        controlValuesSet $ctrlVals(fileTypes).nextButt "Finish"
        controlEnable $ctrlVals(fileTypes).nextButt 1
    }

    if { ($ctrlVals(NT) == "1") && ($ctrlVals(admin) != "1") } {
        # if no ADMIN privilege...

        # disable everything,
        controlEnable $ctrlVals(fileTypes).proj 0
        controlEnable $ctrlVals(fileTypes).wksp 0
        controlEnable $ctrlVals(fileTypes).tcl 0
        controlEnable $ctrlVals(fileTypes).source 0
        controlEnable $ctrlVals(fileTypes).windview 0

        # reset to no default values
        controlCheckSet $ctrlVals(fileTypes).proj 0
        controlCheckSet $ctrlVals(fileTypes).wksp 0
        controlCheckSet $ctrlVals(fileTypes).windview 0

        # display message
        dialog ok "SETUP" [strTableGet APPCONFIG_MSG1]
    }

    # test automation

    if { $ctrlVals(useInputScript) } {
        autoSetupLog "Application Configuration Page: skipped"
        if { ($ctrlVals(NT) == "1") && ($ctrlVals(admin) != "1") } {
            autoSetupLog "SETUP detected that you have no Administrative\
                privileges to configure file associations. SETUP will proceed\
                without configuring file associations for these file types."
        }
        nextCallback
    }
}

#############################################################################
#
# pageProcess(appConfig) - process inputs from appConfig page
#
# This procedure will process input from appConfig page
#
# SYNOPSIS
# .tS
# pageProcess(appConfig)
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: 1 when successful
#
# ERRORS: N/A
#

proc pageProcess(appConfig) {} {
    global ctrlVals
    global infVals
    global typeList

    if { ($ctrlVals(NT) == "1") && ($ctrlVals(admin) != "1") } {
        return 1
    }

    # test automation

    if { $ctrlVals(useInputScript) } {
        autoSetupLog "User's selection:"
    }

    set selectedList ""
    foreach type $typeList {
        # test automation

        # set infVals in here, based on
        # what is selected by user
        appDefaultCallback $type

        # file type selected or not (0 or 1)
        set value [controlChecked wizardDialog.$type]

        if { $ctrlVals(useInputScript) } {
            autoSetupLog "infVals($type): $value"
        } else {
            dbgputs "infVals($type): $value"
        }

        # list used to indicate which 
        # registries to clear out
        if { $value == 1 } {
            append selectedList "$type "
        }
    }

    registriesClearOut $selectedList

    set prod [string toupper [getProdInfo name]]
    searchAndProcessSection AddRegistry [cdFileNameGet [file join RESOURCE \
                                         INF $prod.INF]]

    queueExecute

    # reset infVals
    foreach type $typeList {
        set infVals($type) 0
    }

    return 1
}

#############################################################################
#
# appDefaultCallback - set the variable(s) that will be used in 
#                      <$productName>.INF according to user's selection(s)
#
# This procedure will set the variable(s) that will be used in <$productName>.INF
# according to user's selection(s). The variables are the file types that
# should use this product as their default application. This registry writing
# only happens for Windows
#
# SYNOPSIS
# .tS
# appDefaultCallback <opt>
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

proc appDefaultCallback {opt} {
    global infVals

    if { ![isUnix] } {
        if { [controlChecked wizardDialog.$opt] == 1 } {
            set infVals($opt) 1
        } else {
            set infVals($opt) 0
        }
    }
}


#############################################################################
#
# registriesClearOut -- clear out file association registries
#
# This procedure reads in a list of file types that are selected (by user) 
# to be configured for file associations. In HKEY_CLASSES_ROOT, it will delete
# relevant registries of file extensions, file types, its association 
# commands and default icons.
#
# SYNOPSIS
# .tS
# registriesClearOut
# .tE
#
# PARAMETERS: N/A
# .IP selectedList		
# List of file types (selected by user), indicating which registries to be cleared out.
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc registriesClearOut {selectedList} {
    global infVals

    if { ![isUnix] } {

        set regList ""
        foreach type $selectedList {
            switch -exact -- $type {
                proj     { append regList ".wpj [getProdInfo name]ProjectType " }
                wksp     { append regList ".wsp [getProdInfo name]WorkspaceType " }
                tcl      { append regList ".tcl [getProdInfo name]TCLType " }
                source   { append regList ".c .cc .cpp .cxx .h .hpp .hxx .s [getProdInfo name]SourceType " }
                windview { append regList ".wvr [getProdInfo name]WindViewType " }
            }
        }

        dbgputs "regList cleared out: $regList"

        foreach reg $regList {

            if { ![catch {setupRegKeyExists HKEY_CLASSES_ROOT $reg} error] } {
                if { [catch {sysRegistryKeyDelete HKEY_CLASSES_ROOT $reg} err] } {
                    puts "Cannot delete registry key $reg: $err"
                }
			}
        }
    }
}


######################################################################
# Dialog Text Messages
######################################################################

set strTable(APPCONFIG_TITLE) "Tornado File Associations"

set strTable(APPCONFIG_MSG1) \
    "SETUP detected that you have no Administrative privileges to \
     configure file associations. Click \"Next\" to proceed without \
     configuring file associations for these file types."

set strTable(APPCONFIG_DESC) \
    "By default, SETUP registers an association of various file types\
     with the [getProdInfo name] program.  You can change the default\
     association below."

set strTable(APPCONFIG_OPTION_SELECT) \
    "Choose the file type(s) that should use [getProdInfo name] [getProdInfo version]\
     for their default application. Then click the <Next> button to continue\
     the installation."

set strTable(APPCONFIG_MSG1) \
    "File Types"
    
set strTable(APPCONFIG_OPTION1) \
    "Project \(.wpj)"

set strTable(APPCONFIG_OPTION2) \
    "Workspace \(.wsp\)"

set strTable(APPCONFIG_OPTION3) \
    "TCL \(.tcl\)"

set strTable(APPCONFIG_OPTION4) \
    "Source \(.c, .cc, .cpp, .cxx, .h, .hpp, .hxx, .s\)"

set strTable(APPCONFIG_OPTION5) \
    "WindView data\(.wvr\)"
