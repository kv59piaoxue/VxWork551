# COMPSELCT.TCL - Setup procedures for implementing component-selection
#                 wizard page
#
# Copyright 1999-2003 Wind River Systems, Inc
#
# modification history
# --------------------
# 04u,20jun30,bjl  changed preventInstallion dialog to allow choice and 
#                  changed dialog message.
# 04t,27feb03,bjl  moved lunique to GLOBAL.TCL.
# 04s,22oct02,wmd  Add condition for Unix to remove remote Reg and compatiblity
#                  pages.
# 04r,03oct02,bjl  display error dialog if BSP_ARCH.TXT is missing for
#                  bsp cd only (spr 82811), allow install over tree with
#                  SETUP-1.x patch (spr 82815).  
# 04q,14jun02,wmd  Fix SPR# 78583, add text to say documentation and Setup
#                  files will take up xxx MBytes"
# 04p,17may02,wmd  Fix text formatting, grammatical problems.
# 04o,09may02,wmd  Fix SPR 77138, allow setupVals(compList) = {ALL} to mean
#                  install everything for test automation.
# 04o,07may02,bwd  Added message to Driver install warning
# 04n,05mar02,bwd  Modified SETUP to be non-tornado centric
# 04m,05feb02,bwd  Changed driver-obj-check to a warning, not hard-stop
# 04l,17jan02,wmd  Add test automation logic to avoid dialog popups
# 04k,15jan02,bwd  Skip DLL registration for BSP cd
# 04j,08jan02,bwd  Modified warning message when BSP_ARCH.txt file or its
#                  entries are not found
# 04i,03jan02,bwd  Removed folderSelect and appConfig pages if BSP CD.
#                  Spec changes on product-dependency checking.
# 04h,03jan02,bwd  Minor changes on product-dependency checking.
# 04g,02jan02,bwd  Added checks to disallow installing non-tornado products
#                  into an empty tree.
# 04f,21dec01,bwd  Added codes to check dependencies for core and
#                  Drv/BSP installation
# 04e,05dec01,j_w  Fixed hostVerGet{} not to break down specific OS for
#                  windows; Fixed prodHostTypeGet{} to add a generic 
#                  windows type
# 04d,30oct01,bwd  SPR 62997: fixed bitmap problem when user selects no
#                  products
# 04c,27sep01,j_w  Fixed the previousTornadoInstalled procedure
# 04b,18jun01,j_w  Returned the correct value in prodHostTypeGet() and 
#                  hostVerGet() 
# 04a,12jun01,j_w  Modified for Tornado 2.2
# 03x,19apr01,j_w  Fixed a typo
# 03w,21mar01,j_w  Added BSP/toolchain checking (spr 65277)
# 03v,08mar01,j_w  remove checking for simulator
# 03u,20dec00,bwd  Changed product name: VxWorks PAL to VxWorks AE PAL
# 03t,15dec00,wmd  Fix choice of words.
# 03s,08dec00,bwd  SPR 62832: fixed proc lunique to return list in original
#                  order
# 03r,27nov00,bwd  SPR 34811: to prevent TCL errors, disable "Next" to allow
#                  page creation to finish before letting user click "Next"
# 03q,20nov00,bwd  Fixed TEXT mode in checkProductDependency
# 03p,20nov00,bwd  Fixed isCoreTorSelected due to part name change
# 03o,31oct00,bwd  Add check for PAL dependency check for MIPS CD. Change name
#                  isTornadoSelected to isCoreTorSelected. Modified the proc.
# 03n,20oct00,j_w  Unchecked Tornado Intergated Simulator if linux (spr 35410)
# 03m,04oct00,bwd  Fixed messageBox option
# 03l,25sep00,bwd  Changed check for description "Tornado Target" to "VxWorks
#                  AE"
# 03k,18sep00,j_w  renamed libExtract to libUpdate
# 03j,18aug00,bwd  Re-enable Next button if grayed out in FOLDER page
# 03i,21jul00,bwd  Fixed typo - to display $msg not msg
# 03h,22jun00,bwd  Moved writing to setup.log the list of licensed products to
#                  FILECOPY page
# 03g,09jun00,bwd  Added another host type check for x86-linux2
# 03f,08jun00,bwd  SPR 31050: hide SETUP bitmap and enlarge the product
#                  selection box
# 03e,07jun00,bwd  SPR 31613: add additional line in setup.log that contain
#                  info about licensed products
# 03d,02jun00,bwd  Changed all "dialog ok" to use "dialog ok_with_title"
# 03c,24apr00,bwd  Fixed bugs in checkProductDependency to correctly
#                  check/skip checking for architecture
# 03b,19apr00,bwd  Modified the call to licensedProductCheck to take in
#                  featureID of the product
# 03a,13apr00,bwd  Added codes to make sure the Tornado target and Drv Obj are
#                  selected if Tornado Host is selected, and warn user if
#                  different archs are selected for each of them. Removed
#                  drvCheck and modified checkProductDependency for T3 products
# 02z,20mar00,bwd  Modified the message/error message for TEXT mode to clarify
#                  how user can select/deselect components of a product
# 02y,17mar00,j_w  Fixed typo
# 02x,14mar00,bwd  Fixed codes to correctly check only the native products and
#                  prompt warning when non-native products are selected
# 02w,10mar00,bwd  Added codes to check that at least one driver object is
#                  selected if Tornado product is selected. Removed calls to
#                  drvCheck and checkProductDependency. Removed temporary 
#                  solutions for EAR2 release.
# 02v,09feb00,bwd  Removed the string trimright for product descriptions since
#                  this is done in REGISTER.TCL
# 02u,08feb00,wmd  Disable check for driver/objects for EAR2. FIX for BETA/FCS
# 02t,07feb00,bwd  Fixed error message for test automation
# 02s,31jan00,bwd  Fixed error handling for test automation. Deleted redundant
#                  codes. Replaced setupVals(cmdMode) with isGUImode
# 02r,27jan00,wmd  Add code to check correctly for windows2000.
# 02q,25jan00,wmd  Use tornadoProductCheck to check if product is Tornado
#                  object in isTornadoSelected.
# 02p,20jan00,j_w  Remove remoteRegistryHost reference
# 02o,11jan00,bwd  TEXT MODE: fixed prompt to force users to make selection
#                  (To continue or To select products)
# 02n,11jan00,bwd  TEXT MODE: fixed codes to correctly handle duplicate core
#                  installation
# 02m,06jan00,bwd  No test automation for command line SETUP
# 02l,17dec99,clc  change  switch patterns
# 02k,17dec99,clc  edit message for duplicate products
# 02j,06dec99,j_w  Added licensedProductCheck
# 02i,23nov99,clc  prompt user of COMPSELECT_WARN_1 warning
# 02h,02nov99,clc  add text mode
# 02g,29oct99,wmd  To skip to finish page for testing if env var
#                  SETUP_SKIP_INSTALL is set.
# 02f,22oct99,j_w  Fixed typo
# 02e,22oct99,j_w  Added previousTornadoInstalled procedure
# 02d,21oct99,bjl  removed parisc-hpux support.
# 02c,13oct99,bjl  replaced tornado productName checks with tornadoProductCheck.
# 02b,06oct99,j_w  move calcPage to UTILW32.TCL
# 02a,30Sep99,j_w  Modified for T3
# 01u,23jul99,j_w  added text messages
# 01t,21apr99,wmd  Fix spr #26372 - Unselecting "non-native" products should
#                  not display the warning message.
# 01s,12apr99,wmd  Need to make sure that "Tornado Simulator" product installs
#                  the drivers product as well.
# 01r,31mar99,wmd  Add another name to check for arch wise: SIMHPPA.
# 01q,25mar99,wmd  Fix cpu identification for simulator products.
# 01p,24mar99,wmd  Try to fix so that x86-winXX products are recognized as
#                  such.
# 01o,22mar99,bjl  remove compatibility page for Unix if tornado not
#                  installed, added endWaitCursor.
# 01n,19mar99,wmd  Output to a file any debug messages.
# 01m,18mar99,tcy  added further checking for deselecting non-native products
# 01m,17mar99,wmd  Fix the width of the line to display "Grey box..."
#                  completely.
# 01l,11mar99,wmd  Move the tristate checkbox before the code to uncheck
#                  non-native hosts. Fix prodHostTypeGet.
# 01k,11mar99,wmd  For single part products, indicate 1/1 selected, and add
#                  check to 'foreign' hosts into part select OK proc.
# 01j,10mar99,wmd  Use the tri-state check box for the selected products.
# 01i,08mar99,tcy  fixed bug with code filtering non-native hostnames
# 01h,03mar99,tcy  Show correct size SETUP/ takes based on platform
#                  (fix for SPR 25228)
# 01g,22feb99,wmd  Fix so that unselected products show 0 out of XXX products.
# 01f,17feb99,tcy  Added proc installedProdDescGet() to return a list
#                  of products (fix for SPR 24897)
#                  fix bug in installedProdGet() when checking dest. directory
# 01e,11feb99,wmd  Remove the apostrophes around the '*' so that it is more
#                  visible.
# 01d,29jan99,wmd  Fix spr #24559, show which products have components.
# 01c,28jan99,wmd  Fix spr # 24523, warn users of non-native installations,
#                  and initially uncheck those products not meant for the host.
# 01b,29jan99,tcy  moved byteToMbyte() and kbyteToMbyte() from INSTALL.TCL
# 01a,26jan99,tcy  extracted from INSTW32.TCL.
#

#############################################################################
#
# pageCreate(compSelect) - display products for users to install
#
# This procedure will display products for users to install
#
# SYNOPSIS
# .tS
# pageCreate(compSelect)
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#
global bspArchVals

proc pageCreate(compSelect) {} {
    global ctrlVals
    global setupVals
    global indexList

    if { [isTornadoProduct] } {          
        if { [isBSPcd] } {
            readBSPArchFiles  
        }
    }

    if { [isGUImode] } {
        endWaitCursor
             
        # hide the setup bitmap to allow more space on the page
        controlHide wizardDialog.bitmap 1

        set ctrlVals(volatileFrm) [list \
            [list label -name msg \
                        -title [strTableGet COMPSELECT_LABEL_1]\
                        -x 10 -y 9 -w 295 -h 26] \
            [list label -name message2 \
                        -title [strTableGet COMPSELECT_LABEL_2]\
                        -x 10 -y 37 -w 295 -h 8] \
            [list checklist -name optionList \
                        -callback onClickProdCheckList \
                        -x 10 -y 46 -w 295 -h 80] \
            [list label -name reqText \
                        -title "Space Required:" \
                        -x 18 -y 124 -w 55 -h 8] \
            [list label -name reqSpace \
                        -title "Unknown" \
                        -x 256 -y 124 -w 43 -h 8] \
            [list label -name availText \
                        -title "Space Available:" \
                        -x 18 -y 134 -w 55 -h 8] \
            [list label -name availSpace \
                        -title "Unknown" \
                        -x 256 -y 134 -w 43 -h 8] \
            [list frame -name frm1 \
                        -xpos 10 -ypos 148 -width 295 -height 25] \
            [list label -name compSelected \
                        -x 18 -y 153 -w 150 -h 18] \
            [list button -title "&Details..." -name partDetailButt  \
                        -xpos 245 -ypos 153 -width 50 -height 14  \
                        -callback partListDlg] \
        ]

        set w [dlgFrmCreate [strTableGet COMPSELECT_TITLE]]

        # First, disable "Next" until all info on the page is updated
        # to prevent TCL errors caused by user clicking "Next" too fast
        controlEnable $ctrlVals(mainWindow).nextButt 0

        productGuiChkLstCreate
        productGuiSizeUpdate

        # re-enable "Next" button
        controlEnable $ctrlVals(mainWindow).nextButt 1
        controlFocusSet $ctrlVals(mainWindow).nextButt

        # test automation

        if { $ctrlVals(useInputScript) } {
            autoSetupLog "Products Selection page:"
            autoSetupLog "\tInstalled products specified by the key"
            nextCallback
        }
    } else { # TEXT mode

        set indexList ""

        while (1) {
            printPageTitle [strTableGet COMPSELECT_TITLE]
            puts "[strTableGet COMPSELECT_LABEL_1_TEXT]\n"
            productTextListUpdate
            productTextSizeUpdate 
  
            set ret [prompt [strTableGet 3145_COMP_SELECT_CHANGE]]
            switch -regexp -- $ret {
                "^-$"   { backCallback 
                          return 0 }
                "^$"    { nextCallback
                          return 0 }
                "[eE][xX][iI][tT]"  { return 0 }
                "^[0-9]+([ ][0-9]+)*$" { 
                    productChange $ret 
                }
                default { }
            }
        }
    }
}

#############################################################################
#
# preventInstallation - prevents users from continuing with installation
#
# This procedure will invoke a dialog box to stop users from continuing
# will installation
#
# SYNOPSIS
# .tS
# preventInstallation <ver>
# .tE
#
# PARAMETERS:
# .IP ver
# version of Tornado
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc preventInstallation {ver} {
    global setupVals ctrlVals

    if { [isGUImode] } {

        if { $ctrlVals(useInputScript) } {
            autoSetupLog "Error: attempting to install over an existing\
                          $ver tree. Please choose a new installation path."
            autoSetupLog "Application Exit\n"
            set setupVals(cancel) 1                
            applicationExit
            return 0
        } else {
            set message \
            "You may be attempting to install over an existing $ver\
             tree, or you may have previously installed a product with an\
             incompatible version of Setup. This is not recommended\
             and may cause incompatibilities which will render the product\
             unusable.\n\nDo you want to continue with installation? Click\
             yes to proceed or click no to re-enter the destination\
             directory."

            return [dialog yes_no Setup $message]
        }
    } else { # TEXT mode

        set msg "You are attempting to install over an existing $ver tree.\n\
                This is not recommended and will cause incompatibilities\
                which will render the product unusable.\n\
                Press <Enter> to choose a new installation path."
        
        while { [prompt $msg] != "" } {
        }
    }
}

#############################################################################
#
# installedProdDescGet - return a list of installed product descriptions
#                   that were installed irrespective of the pool Id
#
# This procedure returns a list of installed product descriptions that were
# installed irrespective of the pool Id
#
# SYNOPSIS
# .tS
# installedProdDescGet <pool>
# .tE
#
# PARAMETERS:
#
# RETURNS:
# The variable setupVals(instProdDescList) will be set after invoking
# the procedure. The variable will be set to NULL if Setup does not detect any
# products in the destination directory
#
# ERRORS: N/A
#

proc installedProdDescGet {} {
    global setupVals


    # open the setup.log file and determine if there are any installed products
    # from the specified CD pool

    set logfile [file join [destDirGet] setup.log]
    if [catch {open $logfile r} logfd] {
        return ""
    } else {
        set text [split [read $logfd] \n]
        set nlines [llength $text]
        close $logfd

        for {set ix 0} {$ix < $nlines} {incr ix} {
            # iterate each line and search for the pool ID passed in

            set textLine [split [lindex $text $ix ]]
            # check to see if destination dir is same

            set instDir [lindex $textLine 3]
            # make sure case is not an issue when doing comparison

            if {[string tolower $instDir] == [string tolower [destDirGet]]} {
                incr ix
                # accumulate product numbers that are in this group

                set line [split [lindex $text $ix]]
                while {$ix < $nlines} {
                    if {[string range [lindex $line 1] 0 3] == "100-"} {
                        lappend prodDescList "[lrange $line 2 end]"
                    }
                    incr ix
                    set line [split [lindex $text $ix]]
                    if {[lsearch -regexp $line "TDK-"] == 1} {
                        break
                    }
                }
            }
        }
   }

   set setupVals(instProdDescList) $prodDescList
   dbgputs "Products installed: $setupVals(instProdDescList)"
}

#############################################################################
#
# installedProdGet - return a list of installed products that were installed
#                    from the same pool
#
# This procedure returns a list of installed products that were installed
# from the same pool
#
# SYNOPSIS
# .tS
# installedProdGet <pool>
# .tE
#
# PARAMETERS:
# .IP pool
# pool ID in the form of TDK-XXXXX-XX-XX
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc installedProdGet {pool} {
    global setupVals

    set prodList ""
    set poolID [string range $pool 0 [expr [string first "ZC" $pool] -1]]
    if {$poolID == ""} {
        set poolID $pool
    }

    # open the setup.log file and determine if there are any installed products
    # from the specified CD pool

    set logfile [file join [destDirGet] setup.log]
    if [catch {open $logfile r} logfd] {
        return ""
    } else {
        set text [split [read $logfd] \n]
        set nlines [llength $text]
        close $logfd

        for {set ix 0} {$ix < $nlines} {incr ix} {

            # iterate each line and search for the pool ID passed in

            set textLine [split [lindex $text $ix ]]
            if {[lsearch $textLine $poolID*] != -1} {

                # check to see if destination dir is same

                set instDir [lindex $textLine 3]

                # make sure case is not an issue when doing comparison

                if {[string tolower $instDir] == \
                    [string tolower [destDirGet]]} {
                    incr ix

                    # accumulate product numbers that are in this group

                    set line [split [lindex $text $ix]]
                    while {$ix < $nlines} {
                        if {[string range [lindex $line 1] 0 3] == "100-"} {
                            lappend prodList [lindex $line 1]
                        }
                        incr ix
                        set line [split [lindex $text $ix]]
                        if {[lsearch -regexp $line "TDK-"] == 1} {
                            break
                        }
                    }
                }
            }
        }
    }

    # make the list unique

    set prodList [lunique $prodList]
    set setupVals(instProdList) $prodList

}

#############################################################################
#
# analyzeInstFiles - check if any selected products are already installed
#
# This procedure will check if any selected products are already installed.
#
# SYNOPSIS
# .tS
# analyzeInstFiles
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc analyzeInstFiles {} {
    global ctrlVals
    global setupVals

    set setupVals(instProdList) ""
    set setupVals(dupCoreInstall) 0
    set setupVals(duplicateProducts) ""

    if { [isGUImode] } {
        windowTimerCallbackSet analyzing_setup_files 0 ""
        beginWaitCursor
    }

    # check and setup list of installed products if any
    installedProdGet $setupVals(CDnumber)

    foreach prodIndex [cdInfoGet selectedProdIndexList] {

        if { [isGUImode] } {
            uiEventProcess
        }
 
        # if there are installed products in the destDir

        if {$setupVals(instProdList) != ""} {
            set prodNum [productInfoGet number $prodIndex]
            if {[lsearch $setupVals(instProdList) $prodNum] != -1} {

                # check for existence of a core product in the selected list

                set productName [productInfoGet name $prodIndex]
                set productDesc [productInfoGet desc $prodIndex]
                if {[tornadoProductCheck $productName $productDesc]} {
                    set setupVals(dupCoreInstall) 1
                } elseif {[productInfoGet coreProd $prodIndex] == "core"} {
                    set setupVals(dupCoreInstall) 1
                }
                lappend setupVals(duplicateProducts) \
                        [productInfoGet desc $prodIndex]
            }
        }
    }

    if { [isGUImode] } {
        endWaitCursor
        windowClose analyzing_setup_files
    }
}

#############################################################################
#
# checkForPreviouslyInstalledProds - create dialog box for checking whether
#                                    any selected products have been
#                                    previously installed
#
# SYNOPSIS
# .tS
# checkForPreviouslyInstalledProds
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc checkForPreviouslyInstalledProds {} {
    global ctrlVals
    global setupVals

    set setupVals(coreInstallation) 0

    if { [isGUImode] } {
    dialogCreate \
        -name analyzing_setup_files \
        -notitle \
        -parent $ctrlVals(parentDialog) \
        -helpfile $setupVals(setupHelp) \
        -width 200 -height 32 \
        -init {
            controlPropertySet analyzing_setup_files.analyze_ctrl -bold 1; \
            windowTimerCallbackSet analyzing_setup_files \
                        -milliseconds 200 analyzeInstFiles
        } \
        -controls [list \
                [list label -name "analyze_ctrl" -center \
                -title [strTableGet COMPSELECT_ANALYZING_BANNER] \
                -x 15 -y 12 -w 170 -h 10 ]
        ]
    } else { 
        # TEXT mode
        analyzeInstFiles
    }

}

#############################################################################
#
# onDupProdContinue - set dupRetVal to 0 and close the duplicate product
#                     dialog box
#
# This procedure will set dupRetVal to 0 and close the duplicate product
# dialog box
#
# SYNOPSIS
# .tS
# onDupProdContinue
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc onDupProdContinue {} {
    global dupRetVal

    set dupRetVal 0
    windowClose duplicate_products_warn

}

#############################################################################
#
# onDupProdSelComp - set dupRetVal to 1 and close the duplicate product
#                     dialog box
#
# This procedure will set dupRetVal to 1 and close the duplicate product
# dialog box
#
# SYNOPSIS
# .tS
# onDupProdSelComp
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc onDupProdSelComp {} {
    global dupRetVal

    set dupRetVal 1
    windowClose duplicate_products_warn

}

#############################################################################
#
# dupProdDlgInit - initialize values for dupProdDlg dialog box
#
# This procedure will initialize values for dupProdDlg dialog box
#
# SYNOPSIS
# .tS
# dupProdDlgInit
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc dupProdDlgInit {} {
    global setupVals

    foreach item $setupVals(duplicateProducts) {
        set lst [format %s\r\n $item]
        append prodList $lst
    }
    controlTextSet duplicate_products_warn.dupProdText $prodList
    controlSelectionSet duplicate_products_warn.dupProdText 0 0

}

#############################################################################
#
# dupProdDlg - display warnings if products are being re-installed
#
# This procedure will display warnings if products are being re-installed
#
# SYNOPSIS
# .tS
# dupProdDlg
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: dupRetVal which is set to 1 by onDupProdSelComp or
#                                    0 by onDupProdContinue
#
# ERRORS: N/A
#

proc dupProdDlg {} {
    global setupVals
    global ctrlVals
    global dupRetVal

    if { [isGUImode] } {
        set controls [list \
             [list label -title \
                    "Setup has detected that the following products \
                     were previously installed in [destDirGet] \
                     and you are about to re-install them:" \
                     -name dupProdLabel \
                     -xpos 7 -ypos 9 -width 186 -height 30] \
             [list text -name dupProdText -border \
                    -xpos 7 -ypos 37 -width 185 -height 40 \
                    -readonly -multiline -vscroll] \
             [list label -title [strTableGet COMPSELECT_DUP_PRODUCT_WARN] \
                     -name dupProdLabel2 \
                     -xpos 7 -ypos 84 -width 186 -height 40] \
             [list button -title "&Continue" -name continue -default \
                          -xpos 8 -ypos 129 -width 67 -height 14 \
                          -callback onDupProdContinue] \
             [list button -title "&Select Products" -name cancelButt \
                          -xpos 127 -ypos 129 -width 67 -height 14  \
                          -callback onDupProdSelComp ] \
        ]

        dialogCreate \
            -name duplicate_products_warn \
            -title Setup\
            -init dupProdDlgInit \
            -parent $ctrlVals(parentDialog) \
            -helpfile $setupVals(setupHelp) \
            -width 200 -height 150 \
            -controls $controls
    
        return $dupRetVal

    } else { # TEXT mode
        printPageTitle "Setup"
        puts "Setup has detected that the following products\
              were previously install in [destDirGet] and you\
              are about to re-install them:\n"
        foreach item $setupVals(duplicateProducts) {
            puts [format %s\r\n $item]
        }

        puts [strTableGet COMPSELECT_DUP_PRODUCT_WARN_TEXT]
        puts "1 - To Continue, 2 - To Select Products"

        while (1) {       
            set ret [prompt]
            switch -regexp -- $ret {
                "1" { set dupRetVal 0 ; break }
                "2" { set dupRetVal 1 ; break }
                default { }
            }    
        }
        return $dupRetVal
    }
}


#############################################################################
#
# previousTornadoInstalled - check for existing T1 
#
# This procedure will check if T1 tree exists or not
#
# SYNOPSIS
# .tS
# prevousTornadoInstalled
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: 0 if no T1 tree installed
#          1 if T1 tree installed
#
# ERRORS: N/A
#
proc previousTornadoInstalled {} {
    global ctrlVals setupVals

    set installVal 0

    # check for SETUP version in setup.log
    if { [file exists [destDirGet]/setup.log] } {

        if { ![catch {open [destDirGet]/setup.log r} fileId] } {
            # read each line and search for SETUP-1.x
            while {[gets $fileId line] >= 0} {
                set i [split $line]
                if {[regexp {SETUP-1\.*} $i]} {
		    if {[regexp {patch-*} $i] == 0} {
                        set installVal 1
                        #dbgputs "setup.log: $i"
                        break
                    }
                }
            }
        } else {
            # error in open setup.log
            puts "Error in open setup.log"
        }

        close $fileId

    } else {
        # no setup.log
        dbgputs "setup.log does not exists"

        # check for existing T101
        set t101File "host/resource/tcl/app-config/Tornado/01WindCFG.win32.tcl"
        set t101File [file join [destDirGet] $t101File]
        if {[file exists $t101File]} {
            set installVal 1
        }
    }

    return $installVal
}

#############################################################################
#
# pageProcess(compSelect) - process inputs from compSelect page
#
# This procedure will process inputs from compSelect page
#
# SYNOPSIS
# .tS
# pageProcess(compSelect)
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: 0 if the user needs to re-select the products
#          1 if the user is allowed to continue with installation
#          2 if user decides to quit
#
# ERRORS: N/A
#

proc pageProcess(compSelect) {} {
    global tornadoInstalled
    global ctrlVals setupVals env

    set retVal 1

    if { [isTornadoProduct] } {
        # initialize tornadoInstalled
        set tornadoInstalled 0
        set torVer "Tornado 2.x or 1.x"
    }

    set setupVals(licensedProdInstalled) 0
    foreach prodIndex [cdInfoGet selectedProdIndexList] {
        set featureID [productInfoGet featureId $prodIndex]
        set productName [productInfoGet name $prodIndex]
        set productDesc [productInfoGet desc $prodIndex]

        if {[licensedProductCheck $featureID] && $ctrlVals(useInputScript) == 0} {
            set setupVals(licensedProdInstalled) 1
            dbgputs "licensed prod: $productName - $productDesc\
                     \(feature ID: $featureID\)"
        }
    }
    dbgputs ""

    if { [isTornadoProduct] } {
   
        if { [isBSPcd] } {
            # read BSP_ARCH.TXT - hard-coded table to
            # get matching proc family for BSP and Driver

            if { [readBSPArchFiles] } {            
                # check Driver and BSP dependency
                # if BSP_ARCH.txt file exists and is valid

                set retVal [checkDrvBSPDependency]
            }
        } else {
            set retVal [checkCoreProductDependency]
        }

        #if dependency check fails, redisplay the page
        if { !$retVal } {  return 0  }

        # check to see if installing over a T101 or T2 tree and prevent it.
        if { [previousTornadoInstalled] } {

            # don't want the user to overwrite existing t1 or t2 tree

            # warn and prevent the user from proceeding with installation
            if { [preventInstallation $torVer] } {

                # pop the user back to the destination path screen
                return [calcPage destDir]
            }
        }

        # check for a core installation and previously installed products
 
        checkForPreviouslyInstalledProds

        if {$setupVals(dupCoreInstall)} {

            # overwrite existing directory automatically in autoInstall mode

            if { [isGUImode] } {

                # test automation

                if { $ctrlVals(useInputScript) } {
                    set retVal 1
                } else {
                    messageBeep
                    catch {dialog base_install_warn "Setup" \
                              [strTableGet COMPSELECT_BASE_INSTALL_WARN] \
                              question 0} result

                    if {$result == 1 || $result == ""} {
                        return [calcPage destDir]
                    } else {
                        set retVal 1
                    }
                }
            } else { # TEXT MODE

                puts [strTableGet COMPSELECT_BASE_INSTALL_WARN]
                puts [strTableGet COMPSELECT_BASE_INSTALL_WARN_PROMPT]
      
                while (1) {
                    set ret [prompt]
                    switch -regexp -- $ret {
                        "^[Yy]" { set retVal 1 ; break }
                        "^[Nn]" { return [calcPage destDir] }
                        "[eE][xX][iI][tT]" { return 0 }
                        default { }
                    }
                }
            }
        }

        set dupProds $setupVals(duplicateProducts)
        if {[lindex $dupProds 0] != ""} {

            # present dialog to request permission to overwrite existing products

            if { [isGUImode] } {

                # test automation

                if { $ctrlVals(useInputScript) } {
                    autoSetupLog "\tAllowing overwrite of existing products."
                } else {
                    messageBeep
                    if {[dupProdDlg] == 1} {
                        return 0
                    }
                }
            } else { # TEXT MODE
                if {[dupProdDlg] == 1} {
                    # go back to 'Select Products' page
                    # did not use return 0 because that causes textmode SETUP to exit
                    pageCreate(compSelect)
                    return 0
                }
            }
        }
    # end codes for Tornado product
    }

    if { [isGUImode] } {

        set reqSpace [controlValuesGet $ctrlVals(mainWindow).reqSpace]
        set availSpace [controlValuesGet $ctrlVals(mainWindow).availSpace]

        if {[llength [cdInfoGet selectedProdIndexList]] == 0} {

            if { $ctrlVals(useInputScript) } {
                autoSetupLog "[strTableGet COMPSELECT_WARN_1]"
                autoSetupLog "Application Exit\n"
                set setupVals(cancel) 1                
                applicationExit
                return 0
            } else { 
                messageBox [strTableGet COMPSELECT_WARN_1]
                set retVal 0
                return $retVal
            }
        }
    } else { # TEXT MODE
        set reqSpace $setupVals(totalSize)
        set availSpace $setupVals(availDiskSpace)

        # check that at least one component has been selected for installation
        if {[llength [cdInfoGet selectedProdIndexList]] == 0} {
            puts "Warning: [strTableGet COMPSELECT_WARN_1]"
            while { [prompt "Press <Enter> to continue."] != "" } {
            }
            pageCreate(compSelect)
            return 0
        }
    }

    # display the warnings file for each selected product

    foreach prodIndex [cdInfoGet selectedProdIndexList] {
        searchAndProcessSection WarningsFile [chooseInfFile $prodIndex]
    }

    if {$reqSpace > $availSpace} {
  
        if { [isGUImode] } {

            # test automation
  
            if { $ctrlVals(useInputScript) } {
                autoSetupLog "\tWarning: not enough disk space."
                set i 1
            } else {
                messageBeep
                set i [dialog ok_proceed_exit "Setup" \
                      [strTableGet COMPSELECT_WARN_2]]
            }

            switch $i {
                0 { set retVal [calcPage destDir] }
                1 { set retVal 1 }
                2 { quitCallback }
            }
        } else { # TEXT MODE
 
            set msg "Warning: [strTableGet COMPSELECT_WARN_2]\n \
                               \[Y|N|exit\]"
            set i [prompt $msg]

            switch -regexp -- $i {
                "^[Yy]" { set retVal [calcPage destDir] }
                "^[Nn]" { set retVal 1 }
                "^-$" { 
                    backCallback 
                    return 0
                }
                "exit" { return 0 }
                default { set retVal [calcPage destDir] }
            }
        }
    }

    if { [isTornadoProduct] } {
        # this is done now for unix since the folderSelect page 
        # is not used for unix
 
        if {[isUnix]} {
            foreach prodIndex [cdInfoGet selectedProdIndexList] {
                set productName [productInfoGet name $prodIndex]
                set productDesc [productInfoGet desc $prodIndex]
                if {[tornadoProductCheck $productName $productDesc]} {
                    set tornadoInstalled 1
                }
            }
            if { ![info exists tornadoInstalled] || !$tornadoInstalled } {
                pageRemove remoteRegistryHost
                pageRemove compatibility
                pageRemove howTo
            }
        }

        # for BSP CD installation, remove pages
        if { [isBSPcd] } {
            pageRemove remoteRegistryHost
            pageRemove compatibility
            pageRemove howTo

            if { ![isUnix] } {
                pageRemove folderSelect
                pageRemove torRegistry
                pageRemove appConfig
                pageRemove regTornado
            }
        }
    }

    # for testing only
  
    if { [info exists env(SETUP_SKIP_INSTALL)] &&\
         $env(SETUP_SKIP_INSTALL) == 1 } {

        if {[isUnix]} {
            pageRemove filesCopy 
            pageRemove libUpdate 
            pageRemove systemConfig
        } else {
            pageRemove filesCopy 
            pageRemove libUpdate 
            pageRemove systemConfig
        }
    }

    if { [isGUImode] } {            
        # re-enable the setup bitmap for next pages
        controlHide wizardDialog.bitmap 0
    }

    return $retVal
}


#############################################################################
#
# partListDlg - create dialog box for displaying parts within each product
#
# This procedure will create dialog box for displaying parts within each
# product
#
# SYNOPSIS
# .tS
# partListDlg
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc partListDlg {} {
    global ctrlVals
    global setupVals

    dialogCreate \
        -name partListDlgHnd \
        -title "Select Parts" \
        -width 263 -height 195 \
        -helpfile $setupVals(setupHelp) \
        -init partListDlgInit \
        -parent $ctrlVals(mainWindow) \
        -controls { \
                { button -title "Cancel" -name cancelButt \
                        -xpos 206 -ypos 173 -width 50 -height 14  \
                        -callback onPartListDlgCancel \
                }
                { button -title "OK" -name okButt -default \
                        -xpos 150 -ypos 173 -width 50 -height 14  \
                        -callback onPartListDlgOk \
                }
                { checklist -name optionList  \
                        -xpos 7 -ypos 45 -width 249 -height 83  \
                        -callback onClickPartCheckList \
                }
                { label -title "Information" -name Information \
                        -xpos 12 -ypos 130 -w 50 -height 8 \
                }
                { frame -name frm1 \
                        -xpos 7 -ypos 140 -width 249 -height 27 \
                }
                { label -title "Space Required:" -name spaceRequireLabel  \
                        -xpos 16 -ypos 149 -width 170 -height 8  \
                }
                { label -title "To select or clear a part for\
                                installation, click the item's\
                                checkbox." \
                        -name label3  \
                        -xpos 7 -ypos 7 -width 249 -height 18  \
                }
                { label -title "Parts:" -name label2  \
                        -xpos 8 -ypos 31 -width 86 -height 8  \
                }
        }

}

#############################################################################
#
# partListDlgInit - initialize partListDlg by calling partGuiUpdate
#
# This procedure will initialize partListDlg by calling partGuiUpdate
#
# SYNOPSIS
# .tS
# partListDlgInit
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc partListDlgInit {} {

    partGuiUpdate 0

}

#############################################################################
#
# currSelProdIndexSet - save the index of a product in a global array ctrlVals
#
# This procedure will  save the index of a product in a global array ctrlVals
#
# SYNOPSIS
# .tS
# currSelProdIndexSet <index>
# .tE
#
# PARAMETERS:
# .IP index
# a indexing number to the product list
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc currSelProdIndexSet {index} {
    global ctrlVals

    set ctrlVals(currSelProdIndex) $index

}

#############################################################################
#
# currSelProdIndexGet - obtain the current selected product's index
#
# This procedure will obtain the current selected product's index
#
# SYNOPSIS
# .tS
# currSelProdIndexGet <info>
# .tE
#
# PARAMETERS:
# .IP info
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc currSelProdIndexGet {{info obj}} {
    global objGuiMap ctrlVals 
    global prodToListMap 
    global setupVals

    if { [isGUImode] } {
        if {"$info" != "obj"} {
            set retVal $ctrlVals(currSelProdIndex)
        } else {
            set retVal $objGuiMap(gui2prod,$ctrlVals(currSelProdIndex))
        }
    } else { # TEXT mode
       set retVal $prodToListMap($info)
    }

    return $retVal
}

#############################################################################
#
# onClickPartCheckList -  is invoked when a part is selected from the
#                         partListDlg dialog box and it calls helper
#                         procedures to update the GUI and the object
#
# This procedure is a callback when a part is selected from the partListDlg
# dialog box and it calls helper procedures to update the GUI and the object
#
#
# SYNOPSIS
# .tS
# onClickPartCheckList
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc onClickPartCheckList {} {

    partObjUpdate
    partGuiSizeUpdate

}

#############################################################################
#
# partObjUpdate - update the part object of the product
#
# This procedure will update the part object of the product when the part
# is selected/deselected
#
# SYNOPSIS
# .tS
# partObjUpdate
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc partObjUpdate {} {
    global ctrlVals objGuiMap

    set i 0
    foreach itemState \
                [controlItemPropertyGet partListDlgHnd.optionList -checkstate] {

        partInfoSet instFlag $objGuiMap(gui2part,$i) $itemState
        incr i
    }

}

#############################################################################
#
# partGuiUpdate - update the partListDlg GUI
#
# This procedure will update the partListDlg GUI
#
# SYNOPSIS
# .tS
# partGuiUpdate <guiPartIndex>
# .tE
#
# PARAMETERS:
# .IP guiPartIndex
# the index of selected part
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc partGuiUpdate {guiPartIndex} {

    partGuiChkLstUpdate $guiPartIndex
    partGuiSizeUpdate

}

#############################################################################
#
# partGuiChkLstUpdate - update the partListDlg GUI
#
# This procedure will update the partListDlg GUI
#
# SYNOPSIS
# .tS
# partGuiChkLstUpdate <guiPartIndex>
# .tE
#
# PARAMETERS:
# .IP guiPartIndex
# the index of selected part
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc partGuiChkLstUpdate {guiPartIndex} {
    global objGuiMap
    global ctrlVals

    set prodIndex [currSelProdIndexGet]

    if {"$prodIndex" == ""} {
        windowClose partListDlgHnd
        messageBox "Please select a product first"
    } else {
        set chkList {}
        set i 0

        foreach partIndex [productInfoGet partIndexList $prodIndex] {
            set objGuiMap(gui2part,$i) $partIndex
            set objGuiMap(part2gui,$partIndex) $i
            set size [partInfoGet size $partIndex]
            set formatMbSize [format "%7s MB" [byteToMbyte $size]]
            set desc " [partInfoGet desc $partIndex]\t$formatMbSize "
            lappend chkList [list $desc [partInfoGet instFlag $partIndex]]
            incr i
        }

        controlValuesSet partListDlgHnd.optionList $chkList
        controlFocusSet partListDlgHnd.optionList
        controlSelectionSet partListDlgHnd.optionList -noevent $guiPartIndex
    }
}

#############################################################################
#
# partGuiSizeUpdate - update the size of each product's part
#
# This procedure will update the size of each product's part when user
# selects/deselects a part
#
# SYNOPSIS
# .tS
# partGuiSizeUpdate
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc partGuiSizeUpdate {} {

    set totalSize [byteToMbyte [productInfoGet size [currSelProdIndexGet]]]

    controlValuesSet partListDlgHnd.spaceRequireLabel \
           "Space Required:  $totalSize MB"

}

#############################################################################
#
# onPartListDlgOk - callback when OK button is pushed and close partListDlg
#                   dialog box and save changes
#
# This procedure is a callback whne OK button is pushed and
# close partListDlg dialog box and save changes
#
# SYNOPSIS
# .tS
# onPartListDlgOk
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc onPartListDlgOk {} {
    global objGuiMap ctrlVals

    set prodIndex [currSelProdIndexGet]
    windowClose partListDlgHnd

    switch [productInfoGet stateInfo $prodIndex] {
        changedIncr {
            productInfoSet instFlag \
                    [partInfoGet parent $objGuiMap(gui2part,0)] 1
            set desc [productInfoGet desc $prodIndex]
            
            set hostType [hostVerGet]
            
            set prodHostType [prodHostTypeGet $desc]
            if {[productInfoGet instFlag $prodIndex]} {
                if {$hostType != $prodHostType && $prodHostType != "unknown"} {
                    set msg "The product, $desc, is not meant for installation \
                        on this host type of $hostType.\nContinuing with the \
                        installation may lead to an incomplete installation \
                        due to missing host tools."

                    if { $ctrlVals(useInputScript) } {
                        autoSetupLog "$msg"
                        autoSetupLog "Please re-select the component\(s\)."
                        autoSetupLog "Application Exit\n"
                        set setupVals(cancel) 1                
                        applicationExit
                        return 0
                    } else {
                        dialog ok_with_title "WARNING: Product Installation" $msg
                    }
                }
            }
        }

        changedToNone {
            productInfoSet instFlag \
                    [partInfoGet parent $objGuiMap(gui2part,0)] 0
        }
    }

    productGuiChkLstUpdate [currSelProdIndexGet gui]
    productInfoSet stateCommit [currSelProdIndexGet]
    productInfoSet childStateCommit [currSelProdIndexGet]
    productGuiSizeUpdate

}

#############################################################################
#
# onPartListDlgCancel - callback when cancel button is pushed and restore
#                       the previous settings
#
# This procedure
#
# SYNOPSIS
# .tS
# onPartListDlgCancel
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc onPartListDlgCancel {} {

    windowClose partListDlgHnd
    productInfoSet childStateRestore [currSelProdIndexGet]

}

#############################################################################
#
# detailShow - enable detail button if the product has subparts
#
# This procedure will enable detail button if the product has subparts
#
# SYNOPSIS
# .tS
# detailShow
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc detailShow {} {
    global productObj
    global ctrlVals


    set hasSubPart [expr [llength [productInfoGet partIndexList \
                                                  [currSelProdIndexGet]]] > 1]
    set numSubPart \
        [llength [productInfoGet partIndexList [currSelProdIndexGet]]]
    if {$hasSubPart} {

        # add an indication of components/product selected

        set nCompSel 0
        set totComps 0
        foreach partIndex $productObj([currSelProdIndexGet],partIndexList) {
            if {"[partInfoGet instFlag $partIndex]" == "1"} {
                incr nCompSel
            }
            incr totComps
        }

        if {[productInfoGet instFlag [currSelProdIndexGet]] == 1} {
            controlValuesSet $ctrlVals(mainWindow).compSelected "There\
               are $nCompSel out of $totComps components selected for\
               [productInfoGet desc [currSelProdIndexGet]]."
        } else {
            controlValuesSet $ctrlVals(mainWindow).compSelected "There\
               are 0 out of $totComps components selected for\
               [productInfoGet desc [currSelProdIndexGet]]."
        }
        controlEnable $ctrlVals(mainWindow).partDetailButt 1
    } else {

       # This is a single part product

        if {[productInfoGet instFlag [currSelProdIndexGet]] == 1} {
            controlValuesSet $ctrlVals(mainWindow).compSelected "There\
               are 1 out of 1 components selected for\
               [productInfoGet desc [currSelProdIndexGet]]."
        } else {
            controlValuesSet $ctrlVals(mainWindow).compSelected "There\
               are 0 out of 1 components selected for\
               [productInfoGet desc [currSelProdIndexGet]]."
        }
        controlEnable $ctrlVals(mainWindow).partDetailButt 0
    }

    return $hasSubPart
}

#############################################################################
#
# drvIndexGet - return the driverObjects/Header product index if it exists
#               on the CD.
#
# This procedure will returns the driverObjects/Header product index
# if it exists on the CD.
#
# SYNOPSIS
# .tS
# drvIndexGet
# .tE
#
# PARAMETERS:
# .IP currentProdIndex
# the current product index being selected or deselected
#
# RETURNS: Returns the index of the driverObjects product if the index of the
#          driverObjec is same as that of the current selected product
#          else returns -1
#
# ERRORS: N/A
#
proc drvIndexGet {currProdIndex} {
    global setupVals

    if {$setupVals(drvIndex) == -1} {
        return -1
    }

    foreach drvObj $setupVals(drvIndex) {
        set index [lindex $drvObj 0]
        if {$index == $currProdIndex} {
            return $index
        }
    }

    return -1
}

#############################################################################
#
# drvArchGet - return the driverObjects/Header product arch if it exists
#              on the CD.
#
# This procedure will return the driverObjects/Header product arch if it exists
# on the CD.
#
# SYNOPSIS
# .tS
# drvArchGet
# .tE
#
# PARAMETERS:
# .IP currentProdIndex
# the current product index being selected
#
# RETURNS: Returns the arch of the driverObjects product if the index of the
#          driverObjec is same as that of the current selected product
#          else returns -1
#
# ERRORS: N/A
#

proc drvArchGet {currProdIndex} {
    global setupVals

    if {$setupVals(drvIndex) == -1} {
        return -1
    }

    foreach drvObj $setupVals(drvIndex) {
        set index [lindex $drvObj 0]
        if {$index == $currProdIndex} {
            return [lindex $drvObj 1]
        }
    }

    return -1
}

#############################################################################
#
# prodHostTypeGet - proc to return a host type string
#
# SYNOPSIS
# .tS
# prodHostTypeGet
# .tE
#
# PARAMETERS: description
#   Description in the format <prod name>: <host>[ x <arch>]
#   e.g. Tornado Object: WindowsNT x ppc
#   e.g  Wind Navigator: solaris 
#
# RETURNS: the hos type (a string) if it exists, else "unknown"
#
# ERRORS: N/A
#
proc prodHostTypeGet {desc} {
        
    set prodHostType "unknown"
                                                                      
    switch -regexp $desc {
        ".*[W|w]indows.*" {set prodHostType x86-win32}
        ".*x86-win32.*"   {set prodHostType x86-win32}
        ".*[S|s]olaris.*"   {set prodHostType sun4-solaris2}
        ".*sun4-solaris2.*" {set prodHostType sun4-solaris2}
        ".*simsolaris.*"  {set prodHostType sun4-solaris2}
        ".*Windows2000.*" {set prodHostType Windows2000}
        ".*WindowsNT.*"   {set prodHostType WindowsNT}
        ".*Windows95.*"   {set prodHostType Windows95}
        ".*Windows98.*"   {set prodHostType Windows98}
        ".*hp9700.*"      {set prodHostType parisc-hpux10}
        ".*simhppa.*"     {set prodHostType parisc-hpux10}
        ".*SIMHPPA.*"     {set prodHostType parisc-hpux10}
        #"^x86-linux2"    {set prodHostType x86-linux2}
        default           {set prodHostType unknown}
    }

    #dbgputs "prodHostTypeGet - prodHostType: $prodHostType"
    
    return $prodHostType
}

#############################################################################
#
# onClickProdCheckList - callback procedure invoked when product is checked
#                        on compSelect page
#
# This procedure is a callback procedure invoked when product is checked
# on compSelect page
#
# SYNOPSIS
# .tS
# onClickProdCheckList
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc onClickProdCheckList {} {
    global ctrlVals
    global setupVals

    currSelProdIndexSet [controlSelectionGet $ctrlVals(mainWindow).optionList]
    set hasSubPart [detailShow]
    set currProdIndex [currSelProdIndexGet]
    
    if {[lindex [controlEventGet $ctrlVals(mainWindow).optionList] 0] == \
        "chkchange"} {
        set newState [lindex \
                [controlItemPropertyGet $ctrlVals(mainWindow).optionList \
                -checkstate] [currSelProdIndexGet gui]]

        # determine if customer is trying to uncheck a driverObject/Header prod

        set drvIndex [drvIndexGet $currProdIndex]
        set drvArch [drvArchGet $currProdIndex]
        set drvObjRestored 0

        #dbgputs "drvArch: $drvArch"
                    
        if {[info exists setupVals(tornadoIndex)] && $drvIndex != -1} {
            foreach torObj $setupVals(tornadoIndex) {
                set tornadoSelected  [isCoreTorSelected [lindex $torObj 0]]
                
                #dbgputs "tornadoSelected: $tornadoSelected"     
                #dbgputs "torObj: $torObj"                                             
                #dbgputs "arch: [lindex $torObj 1]"
                
                if {$tornadoSelected && [lindex $torObj 1] == $drvArch} {                    
                    set savedProdIndex -1
                    messageBox [strTableGet 5010_DRIVERS_INFO] -informationicon
                    set index [guiMapCtrlIndexGet $drvIndex]
                    controlItemPropertySet $ctrlVals(mainWindow).optionList \
                        -index $index -checkstate 1
                    set drvObjRestored 1
                    break
                }
            }
        }


        # warn user about non-native installations

        set desc [productInfoGet desc $currProdIndex]
        
        set hostType [hostVerGet]
        
        set prodHostType [prodHostTypeGet $desc]

        if {![productInfoGet instFlag $currProdIndex]} {
            if {$hostType != $prodHostType && $prodHostType != "unknown"} {
                set msg "The product, $desc, is not meant for installation \
                        on this host type of $hostType.\nContinuing with the \
                        installation may lead to an incomplete installation \
                        due to missing host tools."

                if { $ctrlVals(useInputScript) } {
                    autoSetupLog "$msg"
                    autoSetupLog "Please re-select the component\(s\)."
                    autoSetupLog "Application Exit\n"
                    set setupVals(cancel) 1                
                    applicationExit
                    return 0
                } else {
                    dialog ok_with_title "WARNING: Product Installation" $msg
                }
            }
        }

        # commit the user's selection

        if {!$drvObjRestored} {
            set savedProdIndex $currProdIndex
            productInfoSet instFlag $currProdIndex $newState
            if {$newState && $hasSubPart} {
                productGuiChkLstUpdate [currSelProdIndexGet gui]
            }

            productGuiSizeUpdate $newState
            productInfoSet stateCommit $currProdIndex
            productInfoSet childStateCommit $currProdIndex
        }
        
        # check if product just selected is tornado-obj, if so we must
        # re-select the driver object products

        set drvObjRestored 0
        if {[info exists setupVals(tornadoIndex)]} {
            foreach torObj $setupVals(tornadoIndex) {
                
                set tornadoSelected [isCoreTorSelected [lindex $torObj 0]]
                set torIndex [lindex $torObj 0]
                set torArch [lindex $torObj 1]
                
                #dbgputs "tornadoSelected: $tornadoSelected"
                #dbgputs "torIndex: $torIndex"
                #dbgputs "torArch:  $torArch"
                      
                if {$setupVals(drvIndex) != -1 && $tornadoSelected && \
                    [expr $currProdIndex == $torIndex || \
                     $savedProdIndex == $torIndex] } {
                     
                   foreach  drvObj $setupVals(drvIndex) {
                        set index [lindex $drvObj 0]
                        set arch [lindex $drvObj 1]
                        set drvObjSelected [productInfoGet instFlag $index]
                        
                        #dbgputs "drvObjSelected: $drvObjSelected"
                        #dbgputs "arch: $arch"
                        
                        if {!$drvObjSelected && $torArch == $arch} {
                            messageBox [strTableGet 5010_DRIVERS_INFO] \
                                -informationicon
                            productInfoSet instFlag $index 1
                            productGuiSizeUpdate 1
                            productInfoSet stateCommit $index
                            productInfoSet childStateCommit $index
                            set guiIndex [guiMapCtrlIndexGet $index]
                            controlItemPropertySet \
                                $ctrlVals(mainWindow).optionList \
                                -index $guiIndex -checkstate 1
                            set drvObjRestored 1
                            break
                        }
                    }
                }
                if {$drvObjRestored} {
                    break
                }
            }
        }
    }
}

#############################################################################
#
# guiMapCtrlIndexGet - return the GUI index of the selected product index
#
# This procedure will return the GUI index of the selected product index
#
# SYPSIS
# .tS
# guiMapCtrlIndexGet <prodIndex>
# .tE
#
# PARAMETERS:
# .IP prodIndex
# product index
#
# RETURNS: GUI mapped index of the product index
#
# ERRORS: N/A
#

proc guiMapCtrlIndexGet {prodIndex} {
    global objGuiMap ctrlVals


    set retVal $objGuiMap(prod2gui,$prodIndex)

    return $retVal
}

#############################################################################
#
# productGuiChkLstCreate - create the check list of products in compSelect page
#
# This procedure will create the check list of products in compSelect page
#
# SYNOPSIS
# .tS
# productGuiChkLstCreate
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc productGuiChkLstCreate {} {
    global objGuiMap
    global ctrlVals
    global setupVals
    global productObj

    # populate the list of check button.

    set i 0
    set chkList ""
    set totalSize 0

    catch {
        unset objGuiMap
    }

    foreach prodIndex [cdInfoGet productIndexList] {

        # test automation
        # setupVals(compList) in the instCfg.tcl script must be seeded
        # with the product descripts, parts with WTX are auto-selected

        if { $ctrlVals(useInputScript) } {
            set desc [productInfoGet desc $prodIndex]
            if {[lsearch $setupVals(compList) "$desc"] < 0 &&
                $setupVals(compList) != "ALL" } {
                productInfoSet instFlag $prodIndex 0
            }
            foreach part [productInfoGet partIndexList $prodIndex] {
                set descp "[partInfoGet desc $part]"
                if [regexp WTX $descp] {
                    partInfoSet instFlag $part 1
                }
            }
        }
        set objGuiMap(gui2prod,$i) $prodIndex
        set objGuiMap(prod2gui,$prodIndex) $i
        set size [productInfoGet size $prodIndex]
        set formatMbSize [format "%7s MB" [byteToMbyte $size]]

        set desc " [productInfoGet desc $prodIndex]\t$formatMbSize "

        lappend chkList [list $desc [productInfoGet instFlag $prodIndex]]
        incr i
    }

    controlValuesSet $ctrlVals(mainWindow).optionList $chkList
    controlSelectionSet  $ctrlVals(mainWindow).optionList -noevent 0
    currSelProdIndexSet 0

    # use the tri-state checkbox

    for {set ix 0} {$ix < $i} {incr ix} {
        set prodIndex $objGuiMap(gui2prod,$ix)
        set nCompSel 0
        set totComps 0
        foreach partIndex $productObj($prodIndex,partIndexList) {
            if {"[partInfoGet instFlag $partIndex]" == "1"} {
                incr nCompSel
            }
            incr totComps
        }

        if {[productInfoGet instFlag $prodIndex]} {
            if {$totComps != $nCompSel} {
                controlItemPropertySet $ctrlVals(mainWindow).optionList \
                    -index $objGuiMap(prod2gui,$prodIndex) -checkstate 2
            }
        }
    }

    # uncheck the products not meant for this host type

    set hostType [hostVerGet]    
    
    for {set ix 0} {$ix < $i} {incr ix} {
        set prodIndex $objGuiMap(gui2prod,$ix)
        set desc [productInfoGet desc $prodIndex]
        set prodHostType [prodHostTypeGet $desc]
        
        if {$hostType != $prodHostType && $prodHostType != "unknown"} {
            productInfoSet instFlag $prodIndex 0
            controlItemPropertySet $ctrlVals(mainWindow).optionList \
                -index $ix -checkstate 0
        }       

    }

    # test automation

    if { $ctrlVals(useInputScript) } {
        autoSetupLog "\tInstalled product(s):"

        # retrieve product name from the product list

        foreach i $chkList {
            autoSetupLog "\t  $i"
        }
    }
}

#############################################################################
#
# productGuiChkLstUpdate - update the check list of products in the compSelect
#                          page
#
# This procedure will update the check list of products in the compSelect page
#
# SYNOPSIS
# .tS
# productGuiChkLstUpdate <index>
# .tE
#
# PARAMETERS:
# .IP index
# product index
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc productGuiChkLstUpdate {index} {
    global objGuiMap
    global ctrlVals
    global productObj

    set prodIndex [currSelProdIndexGet]
    set size [productInfoGet size $prodIndex]
    set formatMbSize [format "%7s MB" [byteToMbyte $size]]

    # add in indication of components/product selected
    # remove this section if a UITcl tristate button list is created

    set nCompSel 0
    set totComps 0
    foreach partIndex $productObj($prodIndex,partIndexList) {
        if {"[partInfoGet instFlag $partIndex]" == "1"} {
            incr nCompSel
        }
        incr totComps
    }

    set desc " [productInfoGet desc $prodIndex]\t$formatMbSize "

    set chkButt [list [list "$desc" [productInfoGet instFlag $prodIndex]]]

    controlValuesSet $ctrlVals(mainWindow).optionList -insert $index $chkButt
    controlValuesSet $ctrlVals(mainWindow).optionList -delete [expr $index + 1]
    controlSelectionSet  $ctrlVals(mainWindow).optionList -noevent $index
    if {$totComps != $nCompSel} {
        if {[productInfoGet instFlag $prodIndex]} {
            set index $objGuiMap(prod2gui,$prodIndex)
            controlItemPropertySet $ctrlVals(mainWindow).optionList \
                        -index $index -checkstate 2
        }
    }
}

#############################################################################
#
# productguisizeupdate - update the size of products in the compSelect page
#
# This procedure will update the size of products in the compSelect page
#
# SYNOPSIS
# .tS
# productGuiSizeUpdate [state]
# .tE
#
# PARAMETERS:
# .IP state
# init -- first time the sizes of products are updated
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc productGuiSizeUpdate {{state "init"}} {
    global ctrlVals
    global setupVals

    uiEventProcess


    set setupVals(availDiskSpace) "Unknown"
    if {[isUnix]} {
        set free [fspace [destDirGet]]

        if [regexp {^[0-9]+$} $free] {
            set setupVals(availDiskSpace) \
                [format "%3.1f" [expr $free / 1024.0]]
        }
    } else {
        if {![catch {setupDiskSpaceGet [destDirGet]} diskSpace] &&
             $diskSpace >= 0} {
             set setupVals(availDiskSpace) [kbyteToMbyte $diskSpace]
        }
    }

    set setupVals(reqDiskSpace) [cdInfoGet size]

    # add size of SETUP directory to total required space only if SETUP
    # directory is not present in destination directory

    if [file exists [file join [destDirGet] SETUP RESOURCE TCL INSTW32.TCL]] {
        set totalSize [byteToMbyte $setupVals(reqDiskSpace)]
    } else {
        set totalSize [expr [setupSizeGet] + \
                            [byteToMbyte $setupVals(reqDiskSpace)]]
    }

    detailShow

    controlValuesSet $ctrlVals(mainWindow).reqSpace \
                     [format "%7s MB" $totalSize]
    controlValuesSet $ctrlVals(mainWindow).availSpace \
                     [format "%7s MB" $setupVals(availDiskSpace)]

}

#############################################################################
#
# checkCoreProductDependency - check to see if dependencies for core 
#                              products installation are OK
#
# This procedure is called in pageProcess during core products installation
# to see if any dependencies are violated.  If so, give warning or error
#
# For core-CD installation, check:
#  - Check/warn if tornado is selected but a VxWorks is not selected.
#  - Check/give error is user attempts to install non-tornado products
#    such as optional products (i.e. WindView) over an empty tree. 
#
# SYNOPSIS
# .tS
# checkCoreProductDependency
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: 1 if continue with installation
#          0 if user needs to re-select the products
#
# ERRORS: N/A
#

proc checkCoreProductDependency {} {
    global ctrlVals setupVals

    set tornadoSelected 0

    # for core CD:
    # check both tornado and VxWorks are selected

    if { [info exists setupVals(tornadoIndex)] } {
        set tornadoSelected 0
        foreach torObj $setupVals(tornadoIndex) {
            set tornadoSelected  [isCoreTorSelected [lindex $torObj 0]]
            if { $tornadoSelected } { break }
        }

        # If tornado selected, check for VxWorks
        if { $tornadoSelected } {
            set vxworksSelected 0
            foreach prodIndex [cdInfoGet selectedProdIndexList] {
                set productName [productInfoGet name $prodIndex]
                set productDesc [productInfoGet desc $prodIndex]

                # check for VxWorks
                if { [string match "vxworks-procfamily" $productName] && \
	                 [regexp {^VxWorks: (.+)?} $productDesc match type] } {
                    set vxworksSelected 1
                }
            }
            if { !$vxworksSelected } {
                # ERROR if missing VxWorks
                if { [isGUImode] } {
                    messageBeep
                    messageBox -informationicon \
                            [strTableGet COMPSELECT_CORE_DEPENDENCY_ERROR]
                    return 0
                } else {
                    puts "\nError: [strTableGet COMPSELECT_CORE_DEPENDENCY_ERROR_TEXT]\n"
                    while { [prompt "Press <Enter> to Continue"] != "" } {
                    }
                    pageCreate(compSelect)
                    return 0
                }
            }
        } else {
            # if select non-tornado products -> check for a Tornado tree
            set logFileError 0
            set TornadoInstalled 0
            set logfile [file join [destDirGet] setup.log]

            if ![file exist $logfile] {
                set logFileError 1
            }
            if [catch {open $logfile r} logfd] {
                set logFileError 1
            } else {
                while {[gets $logfd line] >= 0} {
                    if { [regexp {.+Tornado Tools: (.+)?} $line match type] } {
                        set TornadoInstalled 1
                        break
                    }
                }
                close $logfd
            }

            # test automation

            if { ($logFileError || !$TornadoInstalled) && 
               !$ctrlVals(useInputScript) } {
                set msg "[strTableGet COMPSELECT_NON-CORE_INSTALL_ERROR]\
                         \n\nClick Proceed to continue with the installation\
                         anyway or click Cancel to re-enter the path or\
                         re-select the products"
                if { [dialog proceed_cancel "WARNING!" $msg] } {
                    # cancel to re-select the products
                    return 0
                }
            }
        }
    }
    return 1
}

#############################################################################
#
# checkDrvBSPDependency - check dependencies for Driver/BSP installation
#
# This procedure is called in pageProcess during Driver/BSP installation
# to see if any dependencies are violated.  If so, give warning or error
#
# For BSP-CD installation, check:
#  - Check/give error if Driver is not selected
#  - Check/warn if processor family not match for a selected BSP
#    and a VxWorks installed from the core CD
#
# ** checking is case-insensitive; SETUP converts everything to lower case **
#
# SYNOPSIS
# .tS
# checkDrvBSPDependency
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: 1 if continue with installation
#          0 if user needs to re-select the products
#
# ERRORS: N/A
#

proc checkDrvBSPDependency {} {
    global ctrlVals setupVals bspArchVals

    set bspSelectedList ""         ;# selected BPSs
    set vxworksInstalledList ""    ;# installed VxWorks proc families

    # for BSP CD:
    # 1. Check/give error if Driver is not selected
		
    set drvSelectedOnce 0
    foreach prodIndex [cdInfoGet selectedProdIndexList] {
        set productName [productInfoGet name $prodIndex]
        set productDesc [productInfoGet desc $prodIndex]
        set drvIndex [drvIndexGet $prodIndex]

        if { $drvIndex != -1 } {
            set drvSelectedOnce 1
        }
        # check for BSP
        if { [string match "tornado-bsp" $productName] && \
             [regexp {^VxWorks BSP: (.+)?} $productDesc match type] } {
            lappend bspSelectedList [string tolower $type]
        }
    }

    # error if no Driver Object selected
    if { !$drvSelectedOnce } {
        set msg "[strTableGet COMPSELECT_DRIVER_ERROR]\n\n"
        if {[isGUImode]} {
            append msg [strTableGet COMPSELECT_WARN_GUI]
            messageBeep
            if { [dialog proceed_cancel "WARNING!" $msg] } {
                # cancel to re-select the products
                return 0
            }
        } else {
            puts $msg
            puts "Enter 1 to proceed with installation\
                  \nEnter 2 to re-select the products."

            while (1) {
                switch -regexp -- [prompt $msg] {
                    "^1$" {} ;#continue with installation
                    "^2$" {  
                        pageCreate(compSelect)
                        return 0  
                    }
                }
            }
        }
    }

    dbgputs "bspSelectedList: $bspSelectedList"
    if { $bspSelectedList == "" } {
        # if BSP is not selected, skip checking
        dbgputs "No BSP selected - skip checking against VxWorks"
        return 1

    } else {

    # 2. Check processor family for all selected BSPs and
    # installed VxWorks. If not match, warn user

        #open setup.log to get proc family of installed vxworks
        set logfile [file join [destDirGet] setup.log]
        if ![catch {open $logfile r} logfd] {
            while {[gets $logfd line] >= 0} {
                if { [regexp {.+VxWorks: (.+)?} $line match type] } {
                     lappend vxworksInstalledList [string tolower $type]
                }
            }
            close $logfd
        }
        dbgputs "vxworksInstalledList: $vxworksInstalledList"

        # skip the bsp if it is not listed in BSP_ARCH.TXT
        foreach bsp $bspSelectedList {
			if {[lsearch -exact [array get bspArchVals] $bsp] == -1} {
                set msg "**** unlisted BSP: $bsp.\
                         Skip dependency checking for this BSP"
			    dbgputs $msg
                uninstLog setupLog $msg
				continue
            }
            
            set warningMsg ""
            set bspLibList [split [lindex $bspArchVals($bsp) 0] ":"]

            if { [llength $bspLibList] > 1 } {

                # if more than one compatible vxworks, check for at least one.
                set matchOnce 0
                foreach bspLib $bspLibList {
                    if {[lsearch -exact $vxworksInstalledList $bspLib] != -1} {
                        set matchOnce 1
                    }
                }
                if { $matchOnce } { 
                    # if match at least one, OK
                    # proceed to check next BSP
                    continue 
                } else {
                    # if match none, give a list of compatible proc families

                    set warningMsg "WARNING: \"VxWorks BSP: $bsp\" you\
                             have selected requires VxWorks for one of the\
                             following processor families: $bspLibList\
                             \n\nPlease remember to install VxWorks for\
                             one of the processor families listed above\
                             from the Tornado Architecture CD.\n\n"
                }
            } else {
                # appropriate message when require ONE proc family
                set bspLibList [string trim $bspLibList]
                if {[lsearch -exact $vxworksInstalledList $bspLibList] == -1} {
                    set warningMsg "WARNING: \"VxWorks BSP: $bsp\" you have\
                          selected requires \"VxWorks: $bspLibList\"\n\nPlease\
                          remember to install VxWorks for this processor\
                          family from the Tornado Architecture CD.\n\n"
                }
            }

            if { $warningMsg != "" } {
                if { [isGUImode] } {
                    messageBeep

                    # if user choose to re-select products, re-display the page
                    # Otherwise, proceed with installation
                    append warningMsg [strTableGet COMPSELECT_WARN_GUI]
                    if { [dialog proceed_cancel "WARNING!" $warningMsg] } {
                        # cancel to re-select the products
                        return 0
                    }
                } else {
                    puts $warningMsg
                    set msg "Enter 1 to proceed with installation\
                             \nEnter 2 to re-select the products."

                    while (1) {
                        switch -regexp -- [prompt $msg] {
                            "^1$" {  return 1  }
                            "^2$" {  
                                pageCreate(compSelect)
                                return 0  
                            }
                        }
                    }
                }
            }
        }
    }
    return 1
}

#############################################################################
#
# isCoreTorSelected - checks to see if core tornado product is selected
#
# This procedure checks to see if the tornado product is selected by the
# customer.  If the product "Tornado Tools" with at least the part 
# "Tornado Tools" is selected, then 1 is returned, else 0 is returned.
#
# SYNOPSIS
# .tS
# isCoreTorSelected <prodIndex>
# .tE
#
# PARAMETERS: prodIndex - the product index of the Tornado product
#
# RETURNS: 1 if "Tornado Tools" with at least the part "Tornado Tools" is selected
#          0 otherwise
#
# ERRORS: N/A
#

proc isCoreTorSelected {prodIndex} {

    set retVal 0

    # first check to see if the tornado product has been selected

    if {[productInfoGet instFlag $prodIndex]} {
        foreach part [productInfoGet partIndexList $prodIndex] {
            set desc [partInfoGet desc $part]

            # check if the Tornado part is selected

            if {[string first "Tornado Tools" $desc] != -1} {
                if {[partInfoGet instFlag $part] == 1} {
                    return 1
                }
            }
        }
    }

    return $retVal
}

#############################################################################
#
# kbyteToMbyte - converts kilo bytes to mega bytes
#
# SYNOPSIS
# kbyteToMbyte <size>
#
# PARAMETERS:
#    <kbyte> : number in kilo bytes
#
# RETURNS: number in mega bytes
#
# ERRORS: N/A
#

proc kbyteToMbyte {size} {

    return [format "%3.1f" [expr $size / 1024.0]]
}

##############################################################################
#
# byteToMbyte - converts bytes to Mbytes
#
# SYNOPSIS
# byteToMbyte <size>
#
# PARAMETERS:
#    <byte> : number in bytes
#
# RETURNS: number in mega bytes
#
# ERRORS: N/A
#

proc byteToMbyte {size} {

    return [format "%3.1f" [expr $size / 1048576.0]]
}

##############################################################################
#
# hostVerGet - Get host version
#
# SYNOPSIS
# hostVerGet
#
# PARAMETERS: n/a
#    
# RETURNS: host version
# if x86-win32
#    Windows95, Windows98, WindowsNT, Windows2000, 
# else
#    sun4-solaris2 or parisc-hpux10
#
# ERRORS: N/A
#
proc hostVerGet {} {
    global ctrlVals
    
    set hostVer [windHostTypeGet]
    
    #if {$hostVer == "x86-win32"} {       
    #    if {$ctrlVals(version) == "NT5x"} {
    #        set hostVer "Windows2000"
    #    } elseif {$ctrlVals(version) == "NT4x"} {
    #        set hostVer "WindowsNT"
    #    } elseif {$ctrlVals(version) == "WIN95"} {
    #        set hostVer "Windows95"
    #    } else {
    #        set hostVer "Windows98"
    #    } 
    #}

    return $hostVer
}    


##############################################################################
#
# productTextListUpdate - prints product list
#
# This procedure prints the products available on the CD and indicates those
# which have been selected for installation.
#
# SYNOPSIS
# .tS
# productTextListUpdate
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc productTextListUpdate {} {
    global ctrlVals  
    global setupVals
    global prodToListMap
    global indexList

    puts [format "%4s %-8s %-40s %-8s" \
         item selected descriptions size(MB) ] 
    puts [format "%4s %-8s %-40s %-8s" \
         ---- -------- ---------------------------------------- -------- ] 
    set count 1 
    foreach prodIndex [cdInfoGet productIndexList] {
        set prodToListMap($count) $prodIndex

        # select all products unlocked by the key

        set selected ""
        if {[productInfoGet instFlag $prodIndex] == 1} {
            set selected "x"   
        }

        # deselect if the product is not meant for this host type

        set hostType [hostVerGet]
        set desc [productInfoGet desc $prodIndex]
        set prodHostType [prodHostTypeGet $desc]
                
        if {$hostType != $prodHostType && $prodHostType != "unknown"} {
            if { [lsearch -exact $indexList $prodIndex] == -1 } {
                productInfoSet instFlag $prodIndex 0
                set selected ""
            }
        }

        # get product size
        set mbSize [byteToMbyte [productInfoGet size $prodIndex]]

        puts [format "%4s %2s %2s %2s %-40s %8s" "  $count" \
              "" $selected "" [productInfoGet desc $prodIndex] $mbSize]
        incr count
    }
    puts ""

    return 1
}

##############################################################################
#
# productTextSizeUpdate - prints space required and space available
#
# This procedure prints the space required by selected products and the space
# available on the destination drive
#
# SYNOPSIS
# .tS
# productTextSizeUpdate
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc productTextSizeUpdate {} {

    global setupVals

    set setupVals(totalSize) [expr [byteToMbyte [cdInfoGet size]] + \
                                   [setupSizeGet]]

    set setupVals(availDiskSpace) "unknown"
    if { [isUnix] } {
        set free [fspace [destDirGet]]
        if [regexp {^[0-9]+$} $free] {
            set setupVals(availDiskSpace) [format "%3.1f" [expr $free / 1024.0]]
        } 
    } else {
        if { ![catch { setupDiskSpaceGet [destDirGet]} diskSpace] &&
              $diskSpace >= 0 } {
            set setupVals(availDiskSpace) [kbyteToMbyte $diskSpace] 
        }
    }

    puts -nonewline "Space Required:  "
    puts [format "%15s MB" $setupVals(totalSize) ]
    puts -nonewline "Space Available: "
    if { $setupVals(availDiskSpace) < $setupVals(totalSize) } {
        puts [format "%15s MB" "***$setupVals(availDiskSpace)***" ]
    } else { 
        puts [format "%15s MB" $setupVals(availDiskSpace) ]
    }
    puts ""
}


##############################################################################
#
# productChange - handles changes made to product installation selection
#
# This procedure toggles instFlag and prompts for part selection if applicable
#
# SYNOPSIS
# .tS
# productChange
# .tE
#
# PARAMETERS: 
# idList - list of product index values
#
# RETURNS:
# 0 - if an invalid list of products is entered or driver is being deselected
#     when tornado simulator/object is to be installed
# 1 - if a valid list of products is processed
#
# ERRORS: N/A
#

proc productChange { idList } {
    global ctrlVals
    global prodToListMap
    global indexList

# debug clc commented this out
#    set idList [lsort -integer $idList]

           
    foreach id $idList {
        if {[regexp {^[0-9][0-9][0-9][0-9]+$} $id]} {
            puts  "Error: [strTableGet 3145_COMP_SELECT_CHANGE_INVALID]"
            while { [prompt "Press <Return> to Continue"] != "" } {
            }
            return 0
        } elseif { [array size prodToListMap] < $id || $id == 0 } { 
            puts "Error: [strTableGet 3145_COMP_SELECT_CHANGE_INVALID]"
            while { [prompt "Press <Return> to Continue"] != "" } {
            }
            return 0
        } 
    }

    foreach id $idList {

        if {[llength $prodToListMap($id)] == 1} {
            set prodIndex [lindex $prodToListMap($id) 0]

            if {[productInfoGet instFlag $prodIndex] == 0} {

                # warn user if non-native product is selected

                set hostType [hostVerGet]
                
                set desc [productInfoGet desc $prodIndex]
                set prodHostType [prodHostTypeGet $desc]
                
                if {$hostType != $prodHostType && $prodHostType != "unknown"} {
                    puts "The product, $desc, is not meant for installation \
                          on this host type of $hostType.\nContinuing with the \
                          installation may lead to an incomplete installation \
                          due to missing host tools.\n\n"

                    while { [prompt "Press <Enter> to Continue"] != "" } {
                    }

                    # update indexList: this non-native product is selected
                    lappend indexList $prodIndex
                }
            }

            if {[llength [productInfoGet partIndexList $prodIndex]] == 1} {
                # length is 1; i.e. the item is a product
        
                if {[productInfoGet instFlag $prodIndex] == 1} {
                    productInfoSet instFlag $prodIndex 0
                } else {
                    productInfoSet instFlag $prodIndex 1
                }
            } else {

                # the item is a product containing parts
                # no detail of the product if it is deselected

                if {[productInfoGet instFlag $prodIndex] == 1} {
                    productInfoSet instFlag $prodIndex 0
                } else {
                    puts "The product \"[productInfoGet desc $prodIndex]\"\
                           contains the following parts:"
                    puts ""
                    partTextListUpdate $prodIndex
                    while (1) {
                        set ret [prompt [strTableGet 3145_COMP_SELECT_CHANGE]]
                        switch -regexp -- $ret {
                            "^-$" { 
                                backCallback
                                return 0 }
                            "^$" { 
                                productInstFlagSet $prodIndex
                                break 
                            }
                            "[eE][xX][iI][tT]" { return 0 }
                            "^[0-9]+([ ][0-9]+)*$" { 
                                partChange $ret
                                partTextListUpdate $prodIndex 
                            }
                            default { }
                        } 
                    }
                }
            }
        } else { 
            puts "Error: variable prodToListMap contains incorrect data" 
        }
    }
    return 1
}

##############################################################################
#
# partChange - handles changes made to product part installation selection 
#
# This procedure toggles instFlag, 1 when installing, 0 when not installing
#
# SYNOPSIS
# .tS
# partChange
# .tE
#
# PARAMETERS: 
# idList - list of part index values
#
# RETURNS: 
# 0 - if an invalid parts list is entered
# 1 - if a valid parts list is parsed.
#
# ERRORS: N/A
#
proc partChange {idList} {

    global partToListMap

    set idList [lsort -integer $idList]
 
    foreach id $idList {
        if {[regexp {^[0-9][0-9][0-9][0-9]+$} $id]} {
            puts "Error: [strTableGet 3145_COMP_SELECT_CHANGE_INVALID]"
            while { [prompt "Press <Return> to Continue"] != "" } {
            }
            return 0
        } elseif { [array size partToListMap] < $id || $id == 0 } {
            puts "Error: [strTableGet 3145_COMP_SELECT_CHANGE_INVALID]"
            while { [prompt "Press <Return> to Continue"] != "" } {
            }
            return 0
        }
    }
 
    foreach id $idList {
        if {[llength $partToListMap($id)] == 2} {
            set prodIndex [lindex $partToListMap($id) 0]
            set partIndex [lindex $partToListMap($id) 1]
            if {[partInfoGet instFlag $partIndex] == 1} {
                partInfoSet instFlag $partIndex 0
            } {
                partInfoSet instFlag $partIndex 1
            }
        } else {
            puts "Error: variable parToListMap contains incorrect data" 
        }
    }

    switch [productInfoGet stateInfo $prodIndex] {
        changedIncr {
            productInfoSet instFlag $prodIndex 1 
        }
        changedToNone {
            productInfoSet instFlag $prodIndex 0 
        }
        unchanged {
        }
        changedDecr {
        }
    }
    productInfoSet stateCommit $prodIndex
    productInfoSet childStateCommit $prodIndex

    return 1 
}

##############################################################################
#
# partTextListUpdate - prints part list to text console
#
# This procedure prints the part list for a particular product
#
# SYNOPSIS
# .tS
# partTextListUpdate 
# .tE
#
# PARAMETERS: 
# prodIndex - product index of the product
#
# RETURNS: 
#
# ERRORS: N/A
#

proc partTextListUpdate {prodIndex} {

    global partToListMap

    puts [format "%4s %-8s %-40s %-8s" \
         item selected descriptions size(MB) ] 
    puts [format "%4s %-8s %-40s %-8s" \
         ---- -------- ---------------------------------------- -------- ] 
    set count 1
    foreach partIndex [productInfoGet partIndexList $prodIndex] {
        set partToListMap($count) [list $prodIndex $partIndex]
        set selected ""
        if {[partInfoGet instFlag $partIndex] == 1} {
             set selected "x"   
        }
        set mbSize [byteToMbyte [partInfoGet size $partIndex]]
        puts [format "%4s %2s %2s %2s %-40s %8s" "  $count" \
                     "" $selected "" [partInfoGet desc $partIndex] $mbSize]
        incr count
    }
    puts ""


    return 1
}

##############################################################################
#
# productInstFlagSet - Set instFlag of product 
#
# This procedure turns on the instFlag of a product if at least one of its 
# parts has been chosen for installation 
#
# SYNOPSIS
# .tS
# productInstFlagSet <prodIndex>
# .tE
#
# PARAMETERS: 
# prodIndex - product index of the product
#
# RETURNS: 
# 1 - if product is to be installed
#
# ERRORS: N/A
#

proc productInstFlagSet {prodIndex} {


    if {[llength [productInfoGet partIndexList $prodIndex]] == 1} {
        puts "Error: product $prodIndex does not contain parts!"
    } else {
        foreach partIndex [productInfoGet partIndexList $prodIndex] {
            if {[partInfoGet instFlag $partIndex] == 1} {
                productInfoSet instFlag $prodIndex 1
                return 1
            }
        }
        productInfoSet instFlag $prodIndex 0 
    }

}

##############################################################################
#
# readBSPArchFiles - Read the BSP/toolchain mapping table 
#
# This procedure reads the BSP_ARCH.TXT file. This file maps BSPs to their
# corresponding toolchain. The information is used for checking the 
# necessary toolchains for the selected BSPs
#
# SYNOPSIS
# .tS
# readBSPArchFiles
# .tE
#
# PARAMETERS: N/A 
# 
# RETURNS: 0 if reading BSP file not successful
#          1 if retrieving BSP/toolchain info successfully
# 
# ERRORS: N/A
#

proc readBSPArchFiles {} {
    global bspArchVals

    # read BSP_ARCH.TXT to map BSP to ARCH
    set bspArchFile [file join [cdromRootDirGet] RESOURCE BSP_ARCH.TXT]

    # If missing BSP_ARCH.TXT file, it's our fault
    # Warn user, log in setup.log and proceed.
    if { ![file exists $bspArchFile] } {
        set msg "Missing File: $bspArchFile\nSETUP is unable to find\
                 the Drivers/BSPs validation rules for this CD"

        messageBox "WARNING: Missing File" $msg
        uninstLog setupLog $msg
        return 0
    }

    if [catch {open $bspArchFile "r"} f] {

        # If cannot open/read BSP_ARCH.txt file, it's our fault
        # Warn user, log in setup.log and proceed.

        set msg "Error in reading $bspArchFile\nSETUP is unable to\
                 find the Drivers/BSPs validation rules for this CD"

        dialog ok_with_title "Error Reading File" $msg
        uninstLog setupLog $msg
        return 0
    }

    # process each line
    while {[gets $f line] >= 0} {

        # skip comment line
        if {[regexp {^#} [string trimleft $line] ]} {
            continue
        }

        set str [split $line]
                
        # remove empty elements
        while {[set ndex [lsearch -exact $str {}]] != -1} {
            set str [lreplace $str $ndex $ndex]
        }

        #store bsp name and proc family
        set bsp [string tolower [string trimleft [lindex $str 0]]]
        set procFamily [string tolower [string trimleft [lindex $str 1]]]

        set bspArchVals($bsp) $procFamily

        #dbgputs "$bsp: $bspArchVals($bsp)"
    }
    close $f
    return 1
}

######################################################################
# Dialog Text Messages
######################################################################

set strTable(COMPSELECT_TITLE) "Select Products"

set strTable(COMPSELECT_LABEL_1) \
    "format %s \"To select or clear an item for installation, click the item's\
     checkbox. SETUP files and documentation will be copied to your\
     destination directory taking up \[setupSizeGet\] MB of disk space.\n\""

set strTable(COMPSELECT_LABEL_1_TEXT) \
    "format %s \"In the option list below, select the item(s) you want\
     to install.  If the product contains more than one components, SETUP\
     will display COMPONENT SELECT page upon selecting that product.\
     If the product is already selected, you must first deselect the\
     product and then re-select it to view its components.\n\nSETUP\
     files will be copied to your selected directory and take up\
     \[setupSizeGet\] MB of disk space.\""

set strTable(COMPSELECT_LABEL_2) \
   "&Products (Grey box indicates subcomponents that are selectable.)"

set strTable(COMPSELECT_WARN_1) \
    "At least one component must be selected to continue installation."

set strTable(COMPSELECT_WARN_2) \
    "There is not enough disk space to install the selected component(s).\
     \n\nDo you want to go back and specify a directory on a bigger disk or\
     partition?"

set strTable(COMPSELECT_WARN_GUI) \
      "Click \"Proceed\" to continue with the installation or\
       \"Cancel\" to re-select the products."

set strTable(COMPSELECT_CORE_DEPENDENCY_ERROR) \
    "The installation of at least one of the VxWorks components is required\
    because you have selected the basic Tornado product for installation.\
    \n\nIf you do not wish to select a VxWorks component, you must uncheck the\
	product \"Tornado Tools\" or go to the 'Details' button for Tornado\
	and uncheck the \"Tornado Tools\" part.\n\nPlease click \"OK\" to\
	re-select the products."

set strTable(COMPSELECT_CORE_DEPENDENCY_ERROR_TEXT) \
    "The installation of at least one of the VxWorks components is required\
     because you have selected the basic Tornado product for installation.\n\n\
     You may proceed with one of the following actions:\
     \nIf you wish to deselect VxWorks, you must first deselect the product\
     \"Tornado Tools\".\
     \nIf you wish to deselect VxWorks and keep basic Tornado product, you must\
     deselect \"Tornado Tools\" PART/COMPONENT.\nTo deselect this component,\
     you must first deselect the basic Tornado product (i.e. \"Tornado Tools\")\
     and then re-select that product. Upon re-selecting the product, SETUP will\
     bring up a list of components that belong to that product.\nThen deselect\
     that part/component.\nOtherwise, please select at least one of the VxWorks."

set strTable(COMPSELECT_DRIVER_ERROR) \
    "WARNING: SETUP has detected that \"Driver Objects/Headers\" is not selected.\
     You must install the Driver Objects/Headers for Tornado to work properly\
     even if previously installed from an earlier release of the BSP's CD, as\
     important files may have been updated."

set strTable(COMPSELECT_NON-CORE_INSTALL_ERROR) \
    "WARNING: SETUP has detected that \"Tornado Tools\" is not installed and you\
     have not selected it for installation. Installation of other products\
     requires that \"Tornado Tools\" be installed.\n\nPlease return to the previous\
     page to select the path in which \"Tornado Tools\" is already installed or\
     select \"Tornado Tools\" as part of this installation."

set strTable(COMPSELECT_DUP_PRODUCT_WARN) \
    "format %s \"Reinstalling products may potentially destroy any\
     modifications you may have made to previously installed files.\
     Do you wish to continue with the installation or go back to the\
     '\[strTableGet COMPSELECT_TITLE\]' page to reconsider your choices?\""

set strTable(COMPSELECT_DUP_PRODUCT_WARN_TEXT) \
    "format %s \"Reinstalling products may potentially destroy any\
     modifications you may have made to previously installed files.\n\
     Do you wish to continue with the installation or go back to the\
     '\[strTableGet COMPSELECT_TITLE\]' page to reconsider your choices?\""

set strTable(COMPSELECT_BASE_INSTALL_WARN) \
      "format %s \"Warning! Re-installing \[getProdInfo name\] over an existing \
      tree will overwrite any installed patches. \
      If you proceed with the installation, please \
      re-install patches if any.\""

set strTable(COMPSELECT_ANALYZING_BANNER) \
    "Analyzing installation files, please wait..."

set strTable(COMPSELECT_BASE_INSTALL_WARN_PROMPT) \
    "Proceed? \[Y|N\]"

