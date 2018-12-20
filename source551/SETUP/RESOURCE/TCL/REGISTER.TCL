# REGISTER.TCL - Setup procedures for implementing user registration wizard 
#                page
#
# Copyright 1999-2003 Wind River Systems, Inc
#
# modification history
# --------------------
# 03q,29apr03,bjl  text rewording.
# 03p,11oct02,wmd  Fix the dimensions of the frame and label for the
#                  information section.
# 03o,29jul02,wmd  Modified to add condition to check for LM error, if so
#                  skip call to setupInit.
# 03n,25jul02,wmd  Remove updating the windows register for projInfo - it
#                  clears the info.
# 03m,22jul02,wmd  Remove setting project values to null or 0.
# 03l,19jul02,wmd  Fix the text for patches to say "root of the directory".
# 03k,12jul02,wmd  Modify to allow patch user to type PATCH=<pathTopatch> as
#                  installation key, skip the path dialog, set instkey=none.
# 03j,27jun02,bwd  SPR 74406: don't save install key if license number is 0
#                  for non-BSP CDs only
# 03i,22may02,bwd  SPR 77766: use setupVals(WRS) variable for company name
# 03h,02may02,bwd  SPR 72883: more fix on infinite loop on BSP CD
# 03g,15mar02,bwd  SPR 74406: don't save install key if license number is 0
# 03f,12mar02,bwd  SPR 72883: fixed infinite loop problems on BSP CD.
# 03e,05mar02,bwd  Rename regValues.. to registrationValues..
# 03d,05mar02,bwd  Modified SETUP to be non-tornado centric
# 03c,05feb02,wmd  Fix the warning message about the install key.
# 03b,21dec01,bwd  Added codes to handle BSP CD installation
# 03a,12jun01,j_w  Modified for Tornado 2.2
# 02t,07may01,j_w  Update error messages
# 02s,08jan01,bwd  SPR 63373: error message stored in the registries after
#                  using ALT+f functionality
# 02r,13nov00,wmd  Modify error message to be clear about need to exit.
# 02q,07nov00,bwd  Increased the size of CD description box to fit new
#                  description
# 02p,30oct00,j_w  SPR 35775: read setup.log for CD description if no DISK_ID
#                  is found when running setup /L from an installed tree
# 02o,14aug00,bwd  SPR 33171: added a check to display error if the key
#                  entered exceed max key length (45)
# 02n,07jun00,bwd  SPR 31613: skip displaying error message on NO_ZIP_FILE if
#                  running SETUP due to License Management errors
# 02m,20mar00,bwd  Fixed TEXT mode to default the installation key value if
#                  there's only one key
# 02l,09feb00,bwd  Removed double quote at the end of product descriptions and
#                  part descriptions
# 02k,07feb00,bwd  Fixed TEXT mode to use instKeyDataGet to display
#                  installation key from the register
# 02j,03feb00,wmd  Need to add a REGISTRATION_WARN_4_TEXT string.
# 02i,31jan00,bwd  Replaced setupVals(cmdMode) with isGUImode and removed redundant codes
# 02h,25jan00,wmd  Product names changed, need to alter how we detect Tornado
#                  products.
# 02g,06jan00,bwd  No test automation for command line SETUP
# 02f,17dec99,clc  testing
# 02e,03dec99,j_w  Enable the help button
# 02d,16nov99,j_w  Fixed return value if no or invalid user inputs
# 02c,16nov99,clc  change text mode variable to setupVals(cmdMode)
# 02b,14oct99,bjl  catch controlDestroy of noKeyText in case control
#                  was not previously created.
# 02b,12oct99,clc  add command-line setup
# 02a,30Sep99,j_w  Modified for T3
# 01i,22jul99,j_w  added text messages
# 01h,15apr99,wmd  If ALT-F is used, remove the corresponding key if it exists
#                  in the registry.
# 01g,15apr99,wmd  Need to destroy the "nokey" control created when no
#                  installation key is required.
# 01f,12apr99,wmd  Need to add full simulator product to the tornadoIndex in 
#                  the setupVals array.
# 01e,31mar99,wmd  Fix spr# 26130, blank components page.
# 01d,24mar99,bjl  turn off inf write to registry after queueExecute.
# 01c,19mar99,wmd  Output to a file any debug messages.
# 01b,01feb99,tcy  moved procs from INSTALL.TCL.
# 01a,26jan99,tcy  extracted from INSTW32.TCL.
#

#############################################################################
#
# onClickFaeBox - prompt FAEs to save the installation key
#
# This procedure will prompt FAEs to save the installation key
#
# SYNOPSIS
# .tS
# onClickFaeBox
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc onClickFaeBox {} {
    global setupVals

    if {![dialog yes_no "Setup" [strTableGet REGISTRATION_FAE_WARN_1]]} {
         set setupVals(instKeyNotSaved) 1
    } elseif [info exists setupVals(instKeyNotSaved)] {
         unset setupVals(instKeyNotSaved)
    }
}

#############################################################################
#
# pageCreate(registration) - displays CD information and prompt users for
#                            registration information
#
# This procedure will display CD information and prompt users for
# registration information such as user name, company name and installation key
#
# SYNOPSIS
# .tS
# pageCreate(registration)
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc pageCreate(registration) {} {
    global ctrlVals
    global setupVals

    # WRS products: read user's information from registries
    if { ![isStandAlone] } {
        registrationValuesReadFromRegistry
    }

    if { "$setupVals(keyList)" == "" } {
        set numKeys 0
    } else {
        set numKeys [llength $setupVals(keyList)]
    }


    if {[string length $setupVals(CDdescription)] > 45} {
        set cdDesc [cdromDescGet]
    } else {
        set cdDesc [strTableGet WELCOME_CD_DESC]
    }

    # use the user key as default; otherwise use the first key as default

    set index 0
    if { [instKeyGet] != "" } {
        set keyList [split [instKeyDataGet]]
        set index [lsearch -exact $keyList [instKeyGet]]
        if {$index == -1} {
            set index 0
        }
    }

    set headerText ""
    if { [isBSPcd] } {
        set headerText [strTableGet REGISTRATION_MSG_1_BSP]
    } else {
        set headerText [strTableGet REGISTRATION_MSG_1]
    }

    if { [isGUImode] } {
        set ctrlVals(volatileFrm) [list \
                    [list label -name message1 \
                                -title $headerText \
                                -x 99 -y 10 -w 206 -h 37] \
                    [list label -name message2 \
                                -title [strTableGet REGISTRATION_MSG_2] \
                                -x 99 -y 56 -w 32 -h 10] \
                    [list label -name message3 \
                                -title [strTableGet REGISTRATION_MSG_3] \
                                -x 99 -y 80 -w 35 -h 10] \
                    [list label -name message4 \
                                -title [strTableGet REGISTRATION_MSG_4] \
                                -x 99 -y 104 -w 35 -h 8] \
                    [list text -name nameText -border \
                               -x 139 -y 56 -w 166 -h 13 \
                               -callback {onTextChange nameText name}] \
                    [list text -name companyText -border \
                               -x 139 -y 79 -w 166 -h 13 \
                               -callback {onTextChange companyText company}] \
                    [list combo -name keyText -x 139 -y 102 -w 166 \
                               -h [expr 13 * ($numKeys + 1)] \
                               -editable \
                               -callback {onTextChange keyText instKey}]\
                    [list label -name Information \
                                -title [strTableGet REGISTRATION_MSG_5] \
                                -x 105 -y 125 -w 40 -h 8] \
                    [list frame -name frm1 \
                               -xpos 100 -ypos 135 -width 207 -height 35] \
                    [list label -name cdInfo \
                                -x 106 -y 140 -w 200 -h 30] \
                    [list button -name fae -title "&f" \
                                 -x 280 -y 35 -w 1 -h 1 \
                                 -callback {onClickFaeBox} ] \
        ]

        set w [dlgFrmCreate [strTableGet REGISTRATION_TITLE]]

        if { [isTornadoProduct] } {
  	        # Enable the help button for Tornado
            controlEnable $w.helpButt 1
        } else {
  	        # non-tornado prod - no help
            controlEnable $w.helpButt 0
        }

        controlHide $w.fae 1
        controlValuesSet $w.companyText [companyNameGet]
        controlValuesSet $w.nameText [userNameGet]
        controlValuesSet $w.keyText [instKeyDataGet]

    
        controlValuesSet $w.cdInfo "CD number      :  $setupVals(CDnumber)\
                                  \nCD description :  $cdDesc"

        # overwrite keyText
        # test automation

        if { $ctrlVals(useInputScript) } {
            controlValuesSet $w.keyText $setupVals(instKey2)
        }

        if {[string compare "none" [instKeyGet]] == 0} {
              
            # if the key "none" works, set the value and hide 
                        # the key edit text box
  
            instKeySet "none"
            controlHide $w.keyText 1
            controlHide $w.message4 1

            # shows message informing user that no key is required for 
                        # installation

            controlCreate $w [list label -name noKeyText \
                               -title [strTableGet REGISTRATION_WARN_1] \
                               -x 99 -y 102 -w 206 \
                               -h [expr 24 * ($numKeys + 1)]]

        } else {
            controlSelectionSet $w.keyText $index
        }

        if {"[userNameGet]" == ""} {
            controlFocusSet $w.nameText
        } elseif {"[companyNameGet]" == ""} {
            controlFocusSet $w.companyText
        } else {
            controlFocusSet $w.keyText
        }

        # test automation

        if { $ctrlVals(useInputScript) } {
            autoSetupLog "Registration page:"
            autoSetupLog "\tUser name:    [userNameGet]"
            autoSetupLog "\tCompany Name: [companyNameGet]"
            autoSetupLog "\tInstall Key:  $setupVals(instKey2)"
            if {[isUnix]} { pageRemove projectInfo }
            nextCallback
        }

    } else { # TEXT mode
        printPageTitle [strTableGet REGISTRATION_TITLE]
        puts "$headerText\n"
        
        set question "name"
        while {[string compare $question "done"] != 0} {
            switch -exact $question {
                "name"  {                
                    # get user name
                    if { "[userNameGet]" == "" } {
                        set msg "Enter your name:"
                    } else {
                        set msg "Enter your name: \[[userNameGet]\]"
                    }
                    set ret [prompt "$msg"]
                    switch -regexp -- $ret {
                        "^-$" { 
                            backCallback
                            return 0 
                        }
                        "^$" { 
                            if { "[userNameGet]" != "" } {
                                set question "company" 
                            } 
                        }
                        "[eE][xX][iI][tT]"  { return 0 }
                        default { 
                            userNameSet $ret
                            set question "company" 
                        }
                    }
                }
                "company" {
                    # get company name
                    if { "[companyNameGet]" == "" } {
                        set msg "Enter your company:" 
                    } else {
                        set msg "Enter your company: \[[companyNameGet]\]"
                    }
                    set ret [prompt "$msg"]
                    switch -regexp -- $ret {
                        "^-$"   { set question "name" }
                        "^$" { 
                            if { "[companyNameGet]" != "" } {
                                set question "key" 
                            }
                        } 
                        "[eE][xX][iI][tT]"  { return 0 }
                        default { 
                            companyNameSet $ret
                            if { [string compare "none" [instKeyGet]] == 0 } {
              
                                                    # if the key "none" works, 
                                                    # set the value

                                instKeySet "none"
                                puts "[strTableGet REGISTRATION_WARN_1]\n"
                                set question "done" 
                            } else { 
                                set question "key" 
                            }
                        }
                    }
                }
                "key" {
                    # get registration key

                    set length [llength [instKeyDataGet]]

                    if { $length > 0 } {

                        if { $length == 1 } {
                            puts "Enter your key: \[[lindex [instKeyDataGet] 0]\]\n"
                        } else {
                            puts "Please enter the item number to choose one\
                                  of the following keys or enter a new key: \[1\]\n"
                        }

                        if { $length > 1 } {
                            set ix 1
                            foreach k [instKeyDataGet] {
                                puts "$ix - $k\n"
                                incr ix
                            }
                        }

                        set ret [prompt]
                        switch -regexp -- $ret {
                            "^-$"   { set question "company" }
                            "^$" {
                                instKeySet [lindex [instKeyDataGet] 0]
                                set question "done"
                            }
                            "^[0-9]+" {
                                if { $ret > 0 && $ret <= $length } {
                                    set index [expr $ret - 1]
                                    instKeySet [lindex [instKeyDataGet] $index] 
                                    set question "done" 
                                } else {
                                    puts "Error: Invalid input: $ret\n"
                                    set question "key"
                                }
                            }
                            "[eE][xX][iI][tT]"  { return 0 }
                            default { 
                                instKeySet $ret 
                                set question "done" 
                            }
                        }
                    } else {

                        set ret [prompt "Enter your key:"]
                        switch -regexp -- $ret {
                            "^-$"   { set question "company" }
                            "[eE][xX][iI][tT]"  { return 0 }
                            default { 
                                if { $ret == "" } {
                                    set question "key" 
                                } else {
                                    instKeySet $ret 
                                    set question "done" 
                                }
                            }
                        }
                    }
                }
            }
        }
        nextCallback
        return 0
    }
}

#############################################################################
#
# onFindZipFileDlgCancel - close the findZipFileDlg dialog box
#
# This procedure will close the findZipFileDlg dialog box when the cancel
# button is pushed
#
# SYNOPSIS
# .tS
# onFindZipFileDlgCancel
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc onFindZipFileDlgCancel {} {

     if [catch {windowClose findZipFileDlgHnd} error] {
         puts "Error: $error"
     }

}

#############################################################################
#
# onFindZipFileDlgOK - close the findZipFileDlg dialog box
#
# This procedure will save the zip directory and close the findZipFileDlg
# dialog box when the cancel button is pushed
#
# SYNOPSIS
# .tS
# onFindZipFileDlgOK
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc onFindZipFileDlgOK {} {

    set dir [string trim [controlValuesGet findZipFileDlgHnd.zipDirText]]
    cdromZipDirSet [file join $dir WIND]

    windowClose findZipFileDlgHnd

}

#############################################################################
#
# findZipFileDlgInit - place default zip directory in zipDirText edit box
#
# This procedure will place default zip directory in zipDirText edit box
#
# SYNOPSIS
# .tS
# findZipFileDlgInit
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc findZipFileDlgInit {} {

    controlValuesSet findZipFileDlgHnd.zipDirText [cdromZipDirGet]
    controlFocusSet findZipFileDlgHnd.zipDirText

}

#############################################################################
#
# findZipFileDlg - create dialog box for finding WIND zip files
#
# This procedure will create dialog box for finding WIND zip files
#
# SYNOPSIS
# .tS
# findZipFileDlg
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc findZipFileDlg {} {
    global ctrlVals
    global setupVals

    if { [isGUImode] } {
        set controls [list \
                     [list label -title \
                                 [strTableGet REGISTRATION_NO_ZIP_FILE] \
                                 -name zipDirLabel \
                                 -xpos 7 -ypos 10 -width 186 -height 80] \
                     [list label -name windLabel \
                                 -title "archive directory" \
                                 -xpos 12 -ypos 134 -w 100 -h 8] \
                     [list frame -name zipDirFrame \
                                 -xpos 7 -ypos 144 -width 198 -height 24] \
                     [list text -name zipDirText -border \
                                 -xpos 11 -ypos 149 -width 133 -height 14 ] \
                     [list button -title "&Browse" -name browse \
                                 -xpos 150 -ypos 149 -width 50 -height 14 \
                                 -callback {onFindZipFileBrowse zipDirText} ] \
                     [list button -title "&Cancel" -name cancelButt \
                                 -xpos 150 -ypos 173 -width 50 -height 14  \
                                 -callback onFindZipFileDlgCancel ] \
                     [list button -title "&OK" -name okButt -default \
                                 -xpos 94 -ypos 173 -width 50 -height 14 \
                                 -callback onFindZipFileDlgOK] \
        ]
        dialogCreate \
            -name findZipFileDlgHnd \
            -title "Locating archive files" \
            -width 212 -height 195 \
            -parent $ctrlVals(mainWindow) \
            -init findZipFileDlgInit \
            -controls $controls \
            -helpfile $setupVals(setupHelp)
    }

}


#############################################################################
#
# pageProcess(registration) - process inputs from registration page
#
# This procedure will process inputs from registration page
#
# SYNOPSIS
# .tS
# pageProcess(registration)
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc pageProcess(registration) {} {
    global setupVals
    global ctrlVals
    global infVals
    global patchPath skipInstalloverCheck
    global env TORNADO_PRODUCT
    global projLic
    global projName
    global projLicUsers

    set MAX_KEY_LENGTH 45

    if { [isStandAlone] } { pageRemove projectInfo }

    if { [isGUImode] } {
        beginWaitCursor

        if {[string compare "none" [instKeyGet]] != 0} {
            instKeySet [controlValuesGet $ctrlVals(mainWindow).keyText -edit]
        }
    }

    # parse to find if patch 

    if {[string first "PATCH" [instKeyGet]] == 0} {
        set patchPath [string range [instKeyGet] 6 end]
        set patchPath [string trim $patchPath]
        instKeySet none
    } elseif { [string length [instKeyGet]] > $MAX_KEY_LENGTH } {
        if { [isGUImode] } {
            messageBox "[strTableGet REGISTRATION_WARN_6]"
        } else {
            puts "[strTableGet REGISTRATION_WARN_6]"
        }
        return 0
    }

    set retVal 1

    if {![catch {setupKeyValidate [instKeyGet]} error]} {

        set setupVals(WRSLicense) [setupLicenseNumGet]
        set projLic $setupVals(WRSLicense)

        # For NON-BSP CD ONLY:
        # DO NOT save install key containing license number 0

        if { $setupVals(WRSLicense) == 0 && ![isBSPcd] } {
            set setupVals(instKeyNotSaved) 1
            dbgputs "Non-BSP CD with license 0: install key NOT saved"
        } else {
            if { [info exists setupVals(instKeyNotSaved)] } {
                unset setupVals(instKeyNotSaved)
            }
        }

        if { [isGUImode] } {    
            companyNameSet [controlValuesGet $ctrlVals(mainWindow).companyText]
            userNameSet [controlValuesGet $ctrlVals(mainWindow).nameText]
        }

        if {![regexp {^[ ]*$} [companyNameGet] junk] && \
            ![regexp {^[ ]*$} [userNameGet] junk]} {

            # change dir to avoid pwd being a UNC directory which
            # fails under Win95
 
            catch {cd c:/}

            if {[instTypeGet] != "licenseError"} {
              if ![catch {setupInit [cdromZipDirGet]} error] {
   
                # user has a new location for ZIP files, and
                # installation key may not match the CD id in DISK_ID
                # so we don't write the key to registry

                if ![info exists setupVals(noZipDir)] {
                    # do not write to the registry if hidden box is checked
                    # for WRS products only

                    if { ![isStandAlone] } {
                        if { ![info exists setupVals(instKeyNotSaved)] } {
                            # Set keyData to be written to the registry.
                            setKeyDataRegistryValue
                        } else {
                            # remove the key if found in registry
                            modKeyDataRegistryValue
                        }
                    }
                }
              } else {
                
                if { [isGUImode] } {
    
                    # test automation
                    
                    if { $ctrlVals(useInputScript) } {
                        autoSetupLog "\tError in CD: $error\n"
                        autoSetupLog "Application Exit\n"
                        set setupVals(cancel) 1
                        applicationExit
                        return 0
                    }

                    switch -exact -- $error {
                        BAD_CD_KEY {
                            messageBox [strTableGet REGISTRATION_WARN_2]
                            return 0
                        }
                        BAD_CD_REVISION {
                            #messageBox [strTableGet REGISTRATION_WARN_4]
                        
                            # do not write to the registry if hidden box 
                                                        # is checked
                            # for WRS products only
                            if { ![isStandAlone] } {
                                if ![info exists setupVals(instKeyNotSaved)] {
                                    setKeyDataRegistryValue
                                } else {
                                    # remove the key if found in registry
                                    modKeyDataRegistryValue
                                }
                            }

                            set retVal 1
                        }
                        BAD_CD_VENDOR_ID {
                            messageBox [strTableGet REGISTRATION_WARN_3]
                            return 0
                        }
                        NO_ZIP_FILE {
                            # if NO LM error, display NO_ZIP error message
                            # First check to see if patch path present
                            if {$patchPath != ""} {
                                set env(CD_ROOT) $patchPath
                                cdromZipDirSet [file join $patchPath WIND]
                                checkBSPcd
                                set skipInstalloverCheck 1
                                if [catch {setupInit [cdromZipDirGet]} error] {
                                    return 0
                                }
                            } elseif {$setupVals(lmError) == "" && [instTypeGet] != "licenseSetup"} {
                                set setupVals(noZipDir) 1
                                findZipFileDlg
                                set env(CD_ROOT) [file dirname [cdromZipDirGet]]
                                checkBSPcd
                                set skipInstalloverCheck 1

                                # avoid calling objectConstruct by returning 0 here
                                # user will return to the registration page

                                return 0
                            }
                        }
                        default {
                            exitWithMessage [strTableGet REGISTRATION_WARN_5 $error]
                        }
                    }
                } else { # TEXT MODE

                    switch -exact -- $error {
                        BAD_CD_KEY {
                            puts "Error: [strTableGet REGISTRATION_WARN_2]\n"
                            set ret [prompt "Enter your key:"]
                            switch -regexp -- $ret {
                                "^-$"   { backCallback; return 0 }
                                "[eE][xX][iI][tT]"  { return 0 }
                                default { 
                                    return [pageProcess(registration)] 
                                }
                            }
                        }
                        BAD_CD_REVISION {
                            puts [strTableGet REGISTRATION_WARN_4_TEXT]
                            set ret [prompt]
                            switch -regexp -- $ret {
                                "^-$"   { backCallback; return 0 }
                                "^$"    { }
                                "[eE][xX][iI][tT]"  { return 0 }
                                default { 
                                    return [pageProcess(registration)] 
                                }
                            }
                        }
                        
                        # do not write to the registry if hidden box is checked

                        BAD_CD_VENDOR_ID {                           
                            puts "Error: [strTableGet REGISTRATION_WARN_3]"
                            return 0
                        }
                        NO_ZIP_FILE {

                            # if NO LM error, display NO_ZIP error message
 
                            if {$setupVals(lmError) == "" && [instTypeGet] != "licenseSetup"} {
                                set setupVals(noZipDir) 1

                                printPageTitle [strTableGet REGISTRATION_NO_ZIP_FILE_TITLE]
                                set ret ""
                                while { $ret == "" } {
                                    puts [strTableGet REGISTRATION_NO_ZIP_FILE_TEXT]
                                    set ret [prompt]
                                }
                                switch -regexp -- $ret {
                                    "^-$" { pageCreate(registration); return 0 }
                                    "[eE][xX][iI][tT]" { return 0 }
                                    default { 
                                        cdromZipDirSet [file join [string trim $ret] WIND]
                                        return [pageProcess(registration)]
                                    }
                                }
                            }
                        }
                        default {
                            puts [strTableGet REGISTRATION_WARN_5 $error]
                            return 0
                        }
                    }                                                
                }
            }
          }
        } else {
            if { [isGUImode] } {
                messageBox [strTableGet REGISTRATION_WARN_7]
                return 0
            }
        }
    } else {

        if { [isGUImode] } {

            # test automation

            if { $ctrlVals(useInputScript) } {
                autoSetupLog "[strTableGet REGISTRATION_WARN_6]"
                autoSetupLog "Application Exit\n"
                set setupVals(cancel) 1
                applicationExit
                return 0
            } else {
                messageBox [strTableGet REGISTRATION_WARN_6]
                return 0
            }
        } else { # TEXT MODE
            puts "Error: [strTableGet REGISTRATION_WARN_6]\n"
            set ret [prompt "Enter your key:"]

            switch -regexp -- $ret {
                "^-$"   { backCallback; return 0}
                "^$"    { }
                "[eE][xX][iI][tT]"  { return 0 }
                default { instKeySet $ret }
            }
            return [pageProcess(registration)]
        }
    }

    objectConstruct

    set prod [string toupper [getProdInfo name]]
    set infVals(addRegistration) 1
    searchAndProcessSection AddRegistry [cdFileNameGet [file join RESOURCE \
                                         INF $prod.INF]]
    queueExecute
    set infVals(addRegistration) 0
    set infVals(addRegKeyData) 0

    if { [isGUImode] } {

        endWaitCursor

        # if nokey is required, destroy the control that was created earlier
        if {[string compare "none" [instKeyGet]] == 0} {
            catch { controlDestroy $ctrlVals(mainWindow).noKeyText }
        }
    }

    # For BSP CD installation:
    # skip Installation Options page - no need
    # add full-installation page list
    # skip project info page because this is for BSP

    if { [isBSPcd] } {
        pageRemove installChoice
        instTypeSet "core"
        if {[isUnix]} {     
            pageListAdd "unixFullInstPages"
        } else {
            pageListAdd "winFullInstPages"
        }
        pageRemove projectInfo
    }

    dbgputs "current pagelist: $ctrlVals(pageList)"

    return $retVal
}

#############################################################################
#
# modKeyDataRegistryValue - modifies installation key information in the 
#                           Windows registry
#
# This procedure will set installation key information in the Windows
# registry
#
#
# SYNOPSIS
# .tS
# modKeyDataRegistryValue
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc modKeyDataRegistryValue {} {
    global setupVals
    global infVals

    if {[instKeyGet] != "none"} {
        set HKCU HKEY_CURRENT_USER
        set infVals(addRegKeyData) 1
        set key [instKeyGet]

        if {![catch {sysRegistryValueRead $HKCU \
            "Software\\$setupVals(WRS)" "keyData"} setupVals(keyString)]} {

            set foundCD 0
            for {set idx 0} \
                {$idx < [llength $setupVals(keyString)]} \
                {incr idx} {
                set combo [lindex $setupVals(keyString) $idx]

                if {[lsearch $combo $setupVals(CDnumber)] != -1} {
                    set foundCD 1
                            set tgtKeyIdx [lsearch $combo $key]
                    if {$tgtKeyIdx != -1} {
                        # installation key has been found

                        set setupVals(keyString) \
                        [lreplace $setupVals(keyString) $idx $idx \
                                  [lreplace $combo $tgtKeyIdx $tgtKeyIdx]]
                        dbgputs "CD found, new key: \
                            setupVals(keyString) = $setupVals(keyString)"
                    }
                }
            }
        } else {
            set setupVals(keyString) $setupVals(CDnumber)
        }
    }
}



#############################################################################
#
# setKeyDataRegistryValue - set installation key information in the Windows
#                           registry
#
# This procedure will set installation key information in the Windows
# registry
#
#
# SYNOPSIS
# .tS
# setKeyDataRegistryValue
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc setKeyDataRegistryValue {} {
    global ctrlVals
    global setupVals
    global infVals

    if {[instKeyGet] != "none"} {
        set infVals(addRegKeyData) 1
        set key [instKeyGet]

        if {![catch {sysRegistryValueRead HKEY_CURRENT_USER \
            "Software\\$setupVals(WRS)" "keyData"} setupVals(keyString)]} {

            set foundCD 0
            for {set idx 0} \
                {$idx < [llength $setupVals(keyString)]} \
                {incr idx} {
                set combo [lindex $setupVals(keyString) $idx]

                if {[lsearch $combo $setupVals(CDnumber)] != -1} {
                    set foundCD 1
                    if {[lsearch $combo $key] == -1} {
                        # installation key is not found
                        set setupVals(keyString) \
                        [lreplace $setupVals(keyString) $idx $idx \
                                  [linsert $combo 1 $key]]

                        dbgputs "CD found, new key: \
                            setupVals(keyString) = $setupVals(keyString)"
                    }
                }
            }

            if !{$foundCD} {
                set setupVals(keyString) \
                    "\{$setupVals(CDnumber) $key\} $setupVals(keyString)"

                dbgputs "new CD, new key: \
                        setupVals(keyString) = $setupVals(keyString)"
            }

        } else {
            set setupVals(keyString) "\{$setupVals(CDnumber) $key\}"

            dbgputs "new keyData registry: \
                    setupVals(keyString) = $setupVals(keyString)"
        }
    }

}

#############################################################################
#
# onFindZipFileBrowse - set the value in edit box when a directory is selected
#                       from the browse window
#
# This procedure will set the value in edit box when a directory is selected
# from the browse window
#
# This procedure
#
# SYNOPSIS
# .tS
# onFindZipFileBrowse <ctrlName>
# .tE
#
# PARAMETERS:
# .IP ctrlName
# control name which will have the new value
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc onFindZipFileBrowse {ctrlName} {
    global ctrlVals

    set retDir [dirBrowseDialogCreate \
                    -title "WIND Directory" \
                    -initialDir [cdromZipDirGet] ]
    if {"$retDir" != ""} {
        controlValuesSet findZipFileDlgHnd.$ctrlName $retDir
    }
}

#############################################################################
#
# registrationValuesReadFromRegistry - fetch user registration values from
#                                      the Windows registry
#
# This procedure will fetch user registration values from the Windows
# registry
#
# SYNOPSIS
# .tS
# registrationValuesReadFromRegistry
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc registrationValuesReadFromRegistry {} {
    global setupVals


    # Load user name from the previous installation if any

    if {"[userNameGet]" == ""} {
        if {![catch {sysRegistryValueRead HKEY_CURRENT_USER \
                 "Software\\$setupVals(WRS)" "name"} name]} {

            userNameSet $name

        } elseif {![catch {sysRegistryValueRead HKEY_LOCAL_MACHINE \
                 "SOFTWARE\\$setupVals(WRS)" "name"} name]} {

            userNameSet $name
        } else {
            userNameSet ""
        }
    }

    # Load company name from the previous installation if any

    if {"[companyNameGet]" == ""} {
        if {![catch {sysRegistryValueRead HKEY_CURRENT_USER \
                 "Software\\$setupVals(WRS)" "company"} company]} {

            companyNameSet $company

        } elseif {![catch {sysRegistryValueRead HKEY_LOCAL_MACHINE \
                 "SOFTWARE\\$setupVals(WRS)" "company"} company]} {

            companyNameSet $company
        } else {
            companyNameSet ""
        }
    }

    # Load installation key from the previous installation if any

    if {![catch {sysRegistryValueRead HKEY_CURRENT_USER \
                     "Software\\$setupVals(WRS)" "keyData"} keyString]} {
        instKeyDataSet [getKeyData $keyString $setupVals(CDnumber) list]

    } elseif {![catch {sysRegistryValueRead HKEY_LOCAL_MACHINE \
                     "SOFTWARE\\$setupVals(WRS)" "keyData"} keyString]} {
        instKeyDataSet [getKeyData $keyString $setupVals(CDnumber) list]

    } else {
        instKeyDataSet ""
    }
}

#############################################################################
#
# getKeyData - search for the requested CD number in string of keys and
#              CD numbers and return either the installation key or the
#              combination of key and the CD number
#
# This procedure will search for the requested CD number in string of keys and
# CD numbers and return either the installation key or the combination of
# key and the CD number
#
# SYNOPSIS
# .tS
# getKeyData <keyString> <CDnumber> <data>
# .tE
#
# PARAMETERS:
# .IP keyString
# the entire list of keys and CD number read from the registry
# .IP CDnumber
# the CD number (TDK-XXXXX-XX-XX) to look for in keyString
# .IP data
# data to be fetched - key  -- installation key
#                    - list -- combination of key and CD number
#
# RETURNS: either the installation key or the combination of
#          key and the CD number
#
# ERRORS: N/A
#

proc getKeyData {keyString CDnumber {data {key list}}} {


    for {set idx 0} {$idx < [llength $keyString]} {incr idx} {
        set combo [lindex $keyString $idx]
        set found [lsearch $combo $CDnumber]
        if {$found != -1} {
            switch -exact $data {
                key     { return [lindex $combo 1]}
                list    { return [lrange $combo 1 end]}
                default { dbgputs "getKeyData: bad argument: $data"
                          return ""
                }
            }
        }
    }

    return ""
}

##############################################################################
#
# objectConstruct - creates objects to store all information about the unlocked
#                   products.
#
# This function must be called prior to the following functions: cdInfoGet/Set
# SYNOPSIS
# objectConstruct
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc objectConstruct {} {
    global productObj partObj featureObj cdObj
    global constructed
    global setupVals


    if {![info exists constructed([instKeyGet])]} {

        catch {
            unset constructed
            unset productObj
            unset partObj
            unset featureObj
            unset setupVals(tornadoIndex)
            unset setupVals(drvIndex)
        }

        set constructed([instKeyGet]) 1
        set productDescList {}
        set setupVals(drvIndex) -1

        foreach prodIndex [setupProductIndexListGet] {

            set productObj($prodIndex,instFlag) 0
            set productObj($prodIndex,prevInstFlag) 0
            set productObj($prodIndex,partIndexList) {}

            set partIndexList [setupPartIndexListGet $prodIndex]

            foreach partIndex $partIndexList {

                set infoList [setupPartInfoGet $partIndex]

                set productNum    [lindex $infoList 0]
                set productName   [lindex $infoList 1]
                set productDesc   [lindex $infoList 2]
                set partName      [lindex $infoList 3]
                set partDesc      [lindex $infoList 4]
                set productIndex  [lindex $infoList 5]
                set defInstFlag   [lindex $infoList 6]
                set totalFile     [lindex $infoList 7]
                set featureDesc   [lindex $infoList 8]
                set featureId     [lindex $infoList 9]
                set size          [lindex $infoList 10]
                set coreProd      [lindex $infoList 12]

                # WORKAROUND to solve the problem of the double
                # quote at the end of product and part descriptions

                set productDesc [string trimright $productDesc \"]
                set partDesc [string trimright $partDesc \"]

                # record the prodIndex of the drivers product

                if {[string compare $productName "tornado-comp-drv"] == 0} {
                    if {[lindex $setupVals(drvIndex) 0] == -1} {
                        set setupVals(drvIndex) \
                            [lreplace $setupVals(drvIndex) 0 0]
                    }
                    set lineIx [string last ":" $productDesc]
                    set lineLen [string length $productDesc]
                    set arch [string range $productDesc \
                             [expr $lineIx+2] $lineLen]
                    lappend setupVals(drvIndex) [list $prodIndex $arch]
                }

                if {[string compare $productName "tornado"] == 0} {
                    set lineIx [string last "x" $productDesc]
                    set lineLen [string length $productDesc]
                    set arch [string range $productDesc \
                             [expr $lineIx+2] $lineLen]
                    lappend setupVals(tornadoIndex) [list $prodIndex $arch]
                }


                if {[string compare $productName "tornado-vxsim"] == 0 } {
                    set lineIx [string last ":" $productDesc]
                    set lineLen [string length $productDesc]
                    set arch [string range $productDesc \
                             [expr $lineIx+2] $lineLen]
                    switch -exact -- $arch {
                        hp9700          { set arch simhppa }
                        x86-winNT       { set arch simnt }
                        solaris         { set arch simsolaris }
                    }
                    lappend setupVals(tornadoIndex) [list $prodIndex $arch]
                }

                # construct CD object

                if {![info exists cdObj(number)]} {
                    set cdObj(number) [lindex $infoList 11]
                }

                # construct product objects

                set productObj($prodIndex,number) $productNum
                set productObj($prodIndex,name) $productName
                set productObj($prodIndex,desc) $productDesc
                set productObj($prodIndex,featureId) $featureId
                set productObj($prodIndex,coreProd) $coreProd
                lappend productObj($prodIndex,partIndexList) $partIndex
 
                # construct part objects

                set partObj($partIndex,instFlag) $defInstFlag
                set partObj($partIndex,prevInstFlag) $defInstFlag
                set partObj($partIndex,desc) $partDesc
                set partObj($partIndex,size) $size
                set partObj($partIndex,totalFile) $totalFile
                set partObj($partIndex,parent) $prodIndex
                set partObj($partIndex,coreProd) $coreProd

                set featureObj($featureId) $featureDesc

                if {"$defInstFlag" == "1"} {
                    set productObj($prodIndex,instFlag) 1
                    set productObj($prodIndex,prevInstFlag) 1
                }
            }

            if {[llength $partIndexList] == 1} {
                set partObj([lindex $partIndexList 0],instFlag) 1
                set partObj([lindex $partIndexList 0],prevInstFlag) 1
            }

            lappend productDescList \
                    [list $productObj($prodIndex,desc) $prodIndex]
        }

        set cdObj(productIndexList) {}
        foreach pair [lsort $productDescList] {
            lappend cdObj(productIndexList) [lindex $pair 1]
        }
    } 

    # make the list of tornado indices unique

    if {[info exists setupVals(tornadoIndex)]} {
        set setupVals(tornadoIndex) [lunique $setupVals(tornadoIndex)]
    }

    dbgputs "finish constructing the products array"


}

######################################################################
# Dialog Text Messages
######################################################################

set strTable(REGISTRATION_TITLE) "User Registration"

set strTable(REGISTRATION_FAE_WARN_1) \
    "The installation key you are about to enter will NOT\
     be saved in the system registry.\nIs this what you want?"

set strTable(REGISTRATION_MSG_1) \
    "Your installation key is provided on the\
     [string toupper [getProdInfo name]] Installation Keys sheet\
     that accompanies your product CDs.  If you have already installed\
     other products from the same CD, you can select the key from the\
     drop-down list."

set strTable(REGISTRATION_MSG_1_BSP) \
    "Below, type your name, the name of your company, and the BSP\
     installation key."

set strTable(REGISTRATION_MSG_2) "Name"

set strTable(REGISTRATION_MSG_3) "Company"

set strTable(REGISTRATION_MSG_4) "Install Key"

set strTable(REGISTRATION_MSG_5) "Information"

set strTable(REGISTRATION_NO_ZIP_FILE_TITLE) \
    "Locating Archive Files"

set strTable(REGISTRATION_NO_ZIP_FILE) \
    "format %s \"SETUP cannot find the ZIP files for installing\
    \[cdromDescGet\] in the default directory.\n\n\
    Please type the root of the\
    path containing the ZIP files.\n\nClick the\
    <Browse> button to choose the directory interactively.\""

set strTable(REGISTRATION_NO_ZIP_FILE_TEXT) \
    "format %s \"SETUP cannot find the ZIP files for installing\
    \[cdromDescGet\] in the default directory.\n\n\
    Please type the root of the\
    path containing the ZIP files.\n\""

set strTable(REGISTRATION_WARN_1) \
    "This CD-ROM does not require an installation key.  Click the \"Next\"\
     button to continue the installation."

set strTable(REGISTRATION_WARN_2) \
    "You entered a key that was not created for this CD-ROM.  Please verify\
     that you are using the appropriate key.  If this problem persists, contact\
     Wind River Systems Sales department for help."

set strTable(REGISTRATION_WARN_3) \
    "The installation key you entered is meant for other vendor's CD-ROM.\
     Please contact the vendor who issued the CD-ROM for a proper key."

set strTable(REGISTRATION_WARN_4) \
    "This CD-ROM does not require an installation key.  Click the \"Next\"\
     button to continue the installation."

set strTable(REGISTRATION_WARN_4_TEXT) \
    "This CD-ROM does not require an installation key.  Click the \"Next\"\n\
     button to continue the installation."

set strTable(REGISTRATION_WARN_5) \
    "format %s \"Can\'t initiate SETUP: \[lindex \$args 0\].  Please correct\
                 the problem then run SETUP again, exit SETUP when prompted.\""

set strTable(REGISTRATION_WARN_6) \
    "The installation key you entered is invalid - please re-check it.\
     Note that the key must be entered exactly as shown, including\
     capitalization and dashes."

set strTable(REGISTRATION_WARN_7) \
    "Please enter the requested information."

# DELETE? no longer used
set strTable(4030_NO_ZIP_FILE) \
    "format %s \"SETUP cannot find the ZIP files for installing\
               \[cdromDescGet\] in the default directory.\n\n\
               Please type the root of the\
               path containing the ZIP files.\n\nClick the\
               <Browse> button to choose the directory interactively.\""
