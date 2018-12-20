# LICMANUAL.TCL - Setup procedures for implementing license configuration page
#                 for manual LM Installation (Email and Phone/Fax)
#
# Copyright 1999-2003 Wind River Systems, Inc
#
# modification history
# --------------------
# 02e,15may03,bjl  changed node locked licensing to use table.
# 02d,29apr03,bjl  changed to table to accomodate more features.
# 02c,05mar02,bwd  Modified SETUP to be non-tornado centric
# 02b,04feb02,bwd  Fixed problem: license info not displayed on phone/email
#                  page on windows 2000
# 02a,12jun01,j_w  Added for Tornado 2.2
# 01l,30oct00,j_w  SPR 35775: read setup.log for CD description if no DISK_ID 
#                  found when running setup /L from an installed tree
# 01k,08jun00,bwd  SPR 31613: added codes to populate lmVals values using info
#                  from setup.log if SETUP is not running from the CD
# 01j,02jun00,bwd  Changed all "dialog ok" to use "dialog ok_with_title"
# 01i,26may00,bwd  SPR 31386 - display warning if user selects 0 license for
#                  all the products. Do not display this page if reload
#                  existing license file
# 01h,23may00,bwd  Fixed message
# 01g,16may00,bwd  SPR 31030 - modified configuration page to display Node
#                  Locked licensing differently
# 01f,14feb00,wmd  Change all references to prodCode to featureId.
# 01e,03feb00,bwd  Fixed codes to display only the licensed products that
#                  belong to this host only
# 01d,02feb00,bwd  Changed setupVals(cmdMode) to use isGUImode
# 01c,20jan00,bwd  Corrected error message
# 01b,14jan00,bwd  Added codes to display this page for TEXT MODE
# 01a,04jan00,bwd  written

#############################################################################
#
# pageCreate(licManual) - Configure licenses on current host
#
# This procedure will configure license on current host
#
# SYNOPSIS
# .tS
# pageCreate(licManual)
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc pageCreate(licManual) {} {
    global ctrlVals setupVals lmVals
    global valuesReset

    # initialize arrays if needed

    if { $valuesReset } {
        set lmVals(lmLicensedProductNames) {}
        set lmVals(lmLicensedFeatureIds) {}
        set lmVals(lmFeaturesRequested) {}   

        lmValsRequestInit
    }

    if { $lmVals(reload) } {
        nextCallback
        return 0
    }

    # reset values that control the table or user input controls

    set ctrlVals(inputUpdate) 0
    set ctrlVals(tableUpdate) 0

    if { [isGUImode] } {
            
        # hide the setup bitmap to allow more space on the page
        controlHide wizardDialog.bitmap 1

        # set up constants to be used for control dimensions and spacing
        set XCOL1 10
        set XCOL2 90
        set XCOL3 234
        set Y     45  
        set WIDTH 75
        set HTHDR 20
        set HT    11
        set TABLEWIDTHS {80 140 40}

        if { $setupVals(lmInstType) == "nodeLocked" } {
            set COL3_HEAD [strTableGet LICMANUAL_NODELOCK]
            set topMSG [strTableGet LICMANUAL_NODELOCK1]
            set bottomMSG [strTableGet LICMANUAL_NODELOCK2]

        } else { # update

            set COL3_HEAD [strTableGet LICMANUAL_COL3]
            set topMSG [strTableGet LICMANUAL_UPDATE1]
            if {$setupVals(ELMUser)} {
                set bottomMSG [strTableGet LICMANUAL_ELM_UPDATE2]
            } else {
                set bottomMSG [strTableGet LICMANUAL_UPDATE2]
            }
        }

        set ctrlVals(volatileFrm) [list \
                [list label -name label_1 \
                            -title $topMSG \
                            -x $XCOL1 -y 15 -w 300 -h 30] \
                [list label -name label_2 \
                            -title $bottomMSG \
                            -x $XCOL1 -y 160 -w 300 -h 15] ]

        lappend ctrlVals(volatileFrm) \
                [list label -name col1 \
                            -title [strTableGet LICMANUAL_COL1] \
                            -x $XCOL1 -y $Y -w $WIDTH -h $HTHDR] \
                [list label -name col2 \
                            -title [strTableGet LICMANUAL_COL2] \
                            -x $XCOL2 -y $Y -w $WIDTH -h $HTHDR] \
                [list label -name col3 \
                            -title $COL3_HEAD\
                            -x $XCOL3 -y $Y -w $WIDTH -h $HTHDR] 

        # Add the edit box controls
	    set newY [expr $Y + $HTHDR + 7]

        for {set ix 0} {$ix < [llength $lmVals(lmLicensedProductNames)]} {incr ix} {
            set feature [lindex $lmVals(lmLicensedProductNames) $ix]
            set featureId [lindex $lmVals(lmLicensedFeatureIds) $ix]

            # set values for the table

            if { $setupVals(lmInstType) == "nodeLocked" } {
                set featureVals [list $feature $featureId "Yes"]
                lappend tableVals $featureVals
            } else {
                set featureVals [list $feature $featureId 0]
                lappend tableVals $featureVals
            }
            
        }
        
        # add table 

        lappend ctrlVals(volatileFrm) \
            [list table -name licManualTable \
                -columns 3 -border \
                -x 10 -y 65 -width 285 -height 52 \
                -callback onTableManualEvent \
                -initial $tableVals ] 

        if { $setupVals(lmInstType) == "floating" } {
            lappend ctrlVals(volatileFrm) \
                [list label -name tableManualLabel \
                    -title [strTableGet LICMANUAL_TABLE_FLOATING] \
                    -x 10 -y 120 -w 295 -h $HT] 
        } else {
            lappend ctrlVals(volatileFrm) \
                [list label -name tableManualLabel \
                    -title [strTableGet LICMANUAL_TABLE_NODELOCKED] \
                    -x 10 -y 120 -w 295 -h $HT]
        }

        lappend ctrlVals(volatileFrm) \
            [list label -name tableManualLabel \
                -title [strTableGet LICMANUAL_TABLE_FLOATING] \
                -x 10 -y 120 -w 295 -h $HT] \
            [list label -name selectedProdLabel \
                -title "Selected Product:" \
                -x $XCOL1 -y 132 -w 59 -h $HT] \
            [list label -name selectedProd \
                 -title "" \
                 -x 72 -y 132 -w 233 -h $HT] 

        # add text entry box for floating licenses, 
        # radio choices for node locked licenses

        if { $setupVals(lmInstType) == "floating" } {
            lappend ctrlVals(volatileFrm) \
                    [list label -name allocateLabel \
                        -title "No. of licenses to be allocated:" \
                        -x $XCOL1 -y 146 -w 100 -h $HT ] \
                    [list text -name textManualRequested  \
                        -callback "floatTextManualCB" \
                        -x [expr $XCOL1 + 102] -y 144 -w 30 -h 12]
        } else {
            lappend ctrlVals(volatileFrm) \
                    [list label -name requestLabel \
                        -title "Request a node locked license:" \
                        -x $XCOL1 -y 146 -w 102 -h $HT ] \
                    [list choice -name yesManualChoice -newgroup -auto \
                        -title "Yes" \
                        -x [expr $XCOL1 + 108] -y 144 -w 30 -h 12 \
                        -callback "nodelockChoiceManualCB"] \
                    [list choice -name noManualChoice -auto \
                        -title "No" \
                        -x [expr $XCOL1 + 138] -y 144 -w 30 -h 12 \
                        -callback "nodelockChoiceManualCB"] 
        }


        # Set title

        if { $setupVals(lmInstOptions) == "onEmail" } {
            set w [dlgFrmCreate [strTableGet LICMANUAL_TITLE_EMAIL]]
        } else {
            set w [dlgFrmCreate [strTableGet LICMANUAL_TITLE_PHONE]]
        }

        for {set ix 0} {$ix < [llength $lmVals(lmLicensedProductNames)]} {incr ix} {

            if { $setupVals(lmInstType) == "nodeLocked" } {
                # get all the values for the current feature

                set featureVals [lindex [controlValuesGet $w.licManualTable] $ix]

                # then get just the first two values, the third value (requested)
                # will be set here

                set featureVals [lrange $featureVals 0 1]

                if { [lindex $lmVals(lmFeaturesRequested) $ix] == 1 } {
                    lappend featureVals "Yes"
                } else {
                    lappend featureVals "No"
                }

                lappend licTableVals $featureVals
            } else {
                # get all the values for the current feature

                set featureVals [lindex [controlValuesGet $w.licManualTable] $ix]

                # then get just the first two values, the third value (requested)
                # will be set here
        
                set featureVals [lrange $featureVals 0 1]

                lappend featureVals [lindex $lmVals(lmFeaturesRequested) $ix]
                lappend licTableVals $featureVals
            }
        }

        controlValuesSet $w.licManualTable $licTableVals

        controlPropertySet $w.licManualTable -columnwidths $TABLEWIDTHS 

        controlSelectionSet $w.licManualTable 0
        controlFocusSet $w.licManualTable

        controlValuesSet $w.nextButt "&Next >"
        controlEnable $w.backButt 1
        controlEnable $w.nextButt 1
        controlEnable $w.cancelButt 1

    } else { # TEXT MODE

        # Set title

        if { $setupVals(lmInstOptions) == "onEmail" } {
            printPageTitle [strTableGet LICMANUAL_TITLE_EMAIL]
        } else {
            printPageTitle [strTableGet LICMANUAL_TITLE_PHONE]
        }

        puts "[strTableGet LICMANUAL_UPDATE1]\n\n"

        # Set header column 3

        if { $setupVals(lmInstType) == "nodeLocked" } {
            set COL3_L1 "Check to request"
            set COL3_L2 "a license"
        } else {
            set COL3_L1 "No. of licenses"
            set COL3_L2 "to be allocated"
        }

        # print column label
        puts [format "%-6s %-25s %-25s %20s" \
              "item" "Licensed Product" "Feature ID" $COL3_L1]
        puts [format "%-6s %-25s %-25s %20s" "" "" "" $COL3_L2]
        for { set i 0 } { $i < 80 } { incr i } {
            puts -nonewline "-"
        }
        puts "\n" 

        # print product names and codes

        for {set ix 0} {$ix < [llength $lmVals(lmLicensedProductNames)]} {incr ix} {
            set name [lindex $lmVals(lmLicensedProductNames) $ix]
            set code [lindex $lmVals(lmLicensedFeatureIds) $ix]

            if { $setupVals(lmInstType) == "nodeLocked" } {
                if { $valuesReset } {
                    # set default values
                    set lmVals(lmFeaturesRequested) \
                            [lreplace $lmVals(lmFeaturesRequested) $ix $ix 1]
                }
            }

            set license [lindex $lmVals(lmFeaturesRequested) $ix]

            if { $setupVals(lmInstType) == "nodeLocked" } {

                if { $license == 1 } { 
                    set license "x" 
                } else { 
                    set license "" 
                }
            }        

            puts [format "%-6s %-25s %-25s %20s" \
                  "[expr $ix + 1]" "$name" "$code" "$license"]
        }

        puts "\n\n[strTableGet LICMANUAL_TEXT]\n"

  	    set totalProd [llength $lmVals(lmLicensedProductNames)]
        set ret [prompt]

        switch -regexp -- $ret {
            "^$"  {  nextCallback ; return 0  }
            "^-$" {  backCallback ; return 0  }
            "^[eE][xX][iI][tT]$"   {  return 0  }
            "[ ]+" {
                puts "Error: please select only one item"
                while {[prompt "Press <Enter> to continue."] != "" } {
                }
                pageCreate(licManual)
            }
            "^[1-9]+" {
                if { $ret > $totalProd } {
                    puts [strTableGet 3145_COMP_SELECT_CHANGE_INVALID]
                    while {[prompt "Press <Enter> to continue."] != "" } {
                    }
                    pageCreate(licManual)
                } else {
                    if { $setupVals(lmInstType) == "nodeLocked" } {
                        manualNodelockChoiceCB [expr $ret - 1]
                    } else {
                        manualLicRequestedUpdate [expr $ret - 1]
                    }
                    set valuesReset 0
                    pageCreate(licManual)
                }
            }
            default {
                puts "Error: Invalid input."
                while {[prompt "Press <Enter> to continue."] != "" } {
                }
                pageCreate(licManual)
            }
        }
    }
}

#############################################################################
#
# pageProcess(licManual) - process inputs from the licManual page
#
# This procedure will process inputs from the licManual page
#
# SYNOPSIS
# .tS
# pageProcess(licManual)
# .tE
#
# PARAMETERS: N/A
#
# RETURNS:  1 if successful
#
# ERRORS: N/A
#

proc pageProcess(licManual) {} {
    global setupVals lmVals ctrVals
    global valuesReset
 
    if { $lmVals(reload) == 0 } { # update
        set isAllZero 1
        foreach req $lmVals(lmFeaturesRequested) {
            if { $req != 0 } {
                set isAllZero 0
            }
        }

        if { $isAllZero } {
            if { [isGUImode] } {
                dialog ok_with_title "ERROR: License Request" \
                                     [strTableGet LICMANUAL_ZERO_ERROR]
                return 0
            } else {
                puts "\n[strTableGet LICMANUAL_ZERO_ERROR]"
                while {[prompt "Press <Enter> to continue."] != "" } {
                }
                pageCreate(licManual)
            }
        }
    }

    dbgputs "feature: $lmVals(lmLicensedProductNames)"
    dbgputs "code: $lmVals(lmLicensedFeatureIds)"
    dbgputs "request: $lmVals(lmFeaturesRequested)"

    if { [isGUImode] } {            
        # re-enable the setup bitmap for next pages
        controlHide wizardDialog.bitmap 0
    }

    # save user's selection
    set valuesReset 0

    return 1
}


#############################################################################
#
# lmValsRequestInit - initialize lmVals value for license request
#
# This procedure initializes the values in the lmVals data structure. 
# The data that is populated are:
#       lmLicensedProductNames
#       lmLicensedFeatureIds
#       lmFeaturesRequested
#
# SYNOPSIS
# .tS
# lmValsRequestInit
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc lmValsRequestInit {} {
    global lmVals setupVals ctrlVals
    global valuesReset env
		
    # If SETUP is NOT running from the CD or with the /L option
    # use licensed products info from setup.log 

	if {[instTypeGet] == "licenseSetup" && $setupVals(runFromCD) == 0} {
		set setupLocal 1
	} else {
		set setupLocal 0
	}

    if {$setupVals(lmError) != "" || $setupLocal == 1} { 

        # get WIND_BASE

        if { [isTornadoProduct] } {
            if { [info exist env(WIND_BASE)] } {
                set setupLog [file join $env(WIND_BASE) setup.log]
            } else {
                messageBox "Error: WIND_BASE variable is not set!"
                return ""
            }
        } else {
            set setupLog [file join [destDirGet] setup.log]
        }

        # try opening setup.log file

        if [catch {open $setupLog r} logfd] {
            messageBox "Error: cannot open file $setupLog!"
            return ""
        } else {
            set text [split [read $logfd] \n]
            set nlines [llength $text]
            close $logfd

            for {set ix 0} {$ix < $nlines} {incr ix} {

                # iterate each line and search for the licensed prod info
                set textLine [split [lindex $text $ix]]

                # search for line that begins with "licensed product:"

                if { [split [lindex $textLine 1]] == "licensed" && 
                     [split [lindex $textLine 2]] == "product:" } {

                    # update license information

                    lappend lmVals(lmLicensedProductNames) \
							[split [lindex $textLine 3]]
                    lappend lmVals(lmLicensedFeatureIds) \
							[split [lindex $textLine 4]]

                    if { $setupVals(lmInstType) == "nodeLocked" } {
                        lappend lmVals(lmFeaturesRequested) 1
                    } else {
                        lappend lmVals(lmFeaturesRequested) 0
                    }
                }
            }
        }
        return
    }

    # get the featureId from the CD, based on what the key unlocks
    # then, use featureId to find all licensed products
    # then, select only licensed products that belong to this host
    # then, add the products to the list to be displayed and
    # configured. This has to be done this way because we have no
    # access to database in the page to retrieve the list of 
    # licensed products that belong to this wind host

    # check wind host type in order to display only native licensed products

    set hostType [windHostTypeGet]

    foreach featureId [cdInfoGet featureIdList] {
        foreach prodIndex [cdInfoGet selectedProdIndexList] {

            # choose only the licensed products

            if { $featureId == [productInfoGet featureId $prodIndex] } {

                # get to desc of the products to check for native products

                set desc [productInfoGet desc $prodIndex] 
                set prodHostType [prodHostTypeGet $desc]

                # if the product belongs to this wind host, 
                # add to the list to be displayed and configured

                if { $hostType == $prodHostType } {

                    #update license information

                    lappend lmVals(lmLicensedProductNames) [productInfoGet name $prodIndex]
                    lappend lmVals(lmLicensedFeatureIds) [productInfoGet featureId $prodIndex]

                    if { $setupVals(lmInstType) == "nodeLocked" } {
                        lappend lmVals(lmFeaturesRequested) 1
                    } else {
                        lappend lmVals(lmFeaturesRequested) 0
                    }
                }
            }
        }
    }
}

#############################################################################
#
# onTableManualEvent - callback for manual floating license table event
#
# This procedure is the callback when a table event occurs.  The current
# values in the table selection are retrieved to update the selected
# product label and the number of requested licenses in the text entry box.  
#
# SYNOPSIS
# .tS
# onTableManualEvent
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#
#

proc onTableManualEvent {} {
    global ctrlVals setupVals

    # if the user is currently updating the entry in the text box
    # or node locked radio choices, simply return so that the 
    # table callback does not update the input controls at the 
    # same time.    

    if {$ctrlVals(inputUpdate) == 1} {
        return
    }

    # only perform an update for a selection change.  

    set event [controlEventGet $ctrlVals(mainWindow).licManualTable]
    if {$event != "selchange"} {
        return
    }
    
    # get the feature values from the table.

    set featureVals [lindex \
					[controlValuesGet $ctrlVals(mainWindow).licManualTable] \
					[controlSelectionGet $ctrlVals(mainWindow).licManualTable]]
    
    set requested [lindex $featureVals 2]
    set prodName [lindex $featureVals 0]

    # set the tableUpdate variable to 1 so that the text entry callback
    # does not update the table at the same time.
    
    set ctrlVals(tableUpdate) 1    

    # update the selected product label and text entry box with the
    # selected table values.  

    controlValuesSet $ctrlVals(mainWindow).selectedProd $prodName

    if {$setupVals(lmInstType) == "floating"} {
        controlValuesSet $ctrlVals(mainWindow).textManualRequested $requested
    } else {        
        # node locked

        if {$requested == "Yes"} {
            controlCheckSet $ctrlVals(mainWindow).yesManualChoice 1
            controlCheckSet $ctrlVals(mainWindow).noManualChoice 0
        } else {
            controlCheckSet $ctrlVals(mainWindow).yesManualChoice 0
            controlCheckSet $ctrlVals(mainWindow).noManualChoice 1
        }

        controlFocusSet $ctrlVals(mainWindow).licManualTable
    }

    set ctrlVals(tableUpdate) 0
}


#############################################################################
#
# checkLMFeaturesRequestedFields
#   For nodelock: checks to see if at least of the fields is checked
#   For updates : checks to see that all fields are entered
#
# SYNOPSIS
# .tS
# checkLMFeaturesRequestedFields
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: 1 if OK to proceed
#          0 if user needs to re-enter
#
# ERRORS: N/A
#
proc checkLMFeaturesRequestedFields {} {
    global lmVals setupVals
    set isOK 0

    if { $setupVals(lmInstType) == "nodeLocked" } {

        # for nodelock, don't need to check with radio controls 

        set isOK 1

    } elseif { $lmVals(reload) == 0 } { # update
        set isOK 1

        # for updates, check to see that a value is entered   

        if { [controlValuesGet wizardDialog.textManualRequested] == "" } {
            set isOK 0
        }
    }
    return $isOK
}

#############################################################################
#
# floatTextManualCB - callback for text entry box
#
# This procedure is the callback for the floating license text entry box.
# A callout is made to update the license request values and update
# the table display.
#
# SYNOPSIS
# .tS
# floatTextManualCB
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#
#

proc floatTextManualCB {} {
    global ctrlVals

    set ix [controlSelectionGet $ctrlVals(mainWindow).licManualTable]

    # if the user is making selections in the table, simply 
    # return so that the text callback does not automatically
    # update the table at the same time.

    if {$ctrlVals(tableUpdate) == 1} {
        return
    }

    # set the inputUpdate variable to 1 so that the table
    # callback does not automatically update the text
    # entry box at the same time.

    set ctrlVals(inputUpdate) 1    

    manualLicRequestedUpdate $ix

    set ctrlVals(inputUpdate) 0
}

proc nodelockChoiceManualCB {} {
    global ctrlVals

    set ix [controlSelectionGet $ctrlVals(mainWindow).licManualTable]

    # if the user is making selections in the table, simply 
    # return so that the text callback does not automatically
    # update the table at the same time.

    if {$ctrlVals(tableUpdate) == 1} {
        return
    }

    # set the inputUpdate variable to 1 so that the table
    # callback does not automatically update the radio
    # choices at the same time.

    set ctrlVals(inputUpdate) 1    

    manualNodelockChoiceCB $ix

    set ctrlVals(inputUpdate) 0
}

#############################################################################
#
# licTableManualUpdate - updates manual floating license table with specified 
#                        values
#
# This procedure updates the floating license table for the specified
# feature and number of licenses requested.  This is called when the
# user updates the number of requsted licenses in the text entry box.
#
# SYNOPSIS
# .tS
# licTableManualUpdate
# .tE
#
# PARAMETERS: 
#     featIx - feature index, corresponding to the selection in the table
#     numRequested - number of requested licenses
#
# RETURNS: N/A
#
# ERRORS: N/A
#
#

proc licTableManualUpdate {featIx numRequested} {
    global lmVals ctrlVals setupVals

    set length [llength $lmVals(lmLicensedProductNames)]
    for {set ix 0} {$ix < $length} {incr ix} {
        # get all the values for the current feature

        set featureVals [lindex [controlValuesGet $ctrlVals(mainWindow).licManualTable] $ix]
   
        if { $ix == $featIx } {
            # then get just the first two values, the third value (requested)
            # will be set here
        
            set featureVals [lrange $featureVals 0 1]

            if {$setupVals(lmInstType) == "floating"} {
                lappend featureVals $numRequested
            } else {
                # node locked

                if {$numRequested == 1} {
                    lappend featureVals "Yes"
                } else {
                    lappend featureVals "No"
                }
            }
        } 

        lappend licTableVals $featureVals         
    } 

    controlFocusSet $ctrlVals(mainWindow).licManualTable  
    controlValuesSet $ctrlVals(mainWindow).licManualTable $licTableVals            
    controlSelectionSet $ctrlVals(mainWindow).licManualTable $featIx
           
    if {$ctrlVals(inputUpdate) == 1} {
        # if the user is updating the text entry box, put focus
        # back on the entry box

        if {$setupVals(lmInstType) == "floating"} {
            controlFocusSet $ctrlVals(mainWindow).textManualRequested
        }
    }            
}

#############################################################################
#
# manualLicRequestedUpdate 
#
# This procedure does the work for the manual license text box callback
# procedures.  It updates the temporary array to be displayed on the 
# Email or Phone/Fax License Request Summary page and controls
# enabling or disabling of the Next button.
#
# SYNOPSIS
# .tS
# manualRequestedUpdate ix
# .tE
#
# PARAMETERS: N/A
# ix - the index or order in which the licensed product is displayed
#
# RETURNS: n/a
#
# ERRORS: N/A
#
proc manualLicRequestedUpdate {ix} {
    global ctrlVals lmVals setupVals

    if { [isGUImode] } {
        if { $setupVals(lmInstType) == "floating" } {
            if {[controlValuesGet wizardDialog.textManualRequested] != ""} {
                set input [controlValuesGet wizardDialog.textManualRequested]
                if {[isNumeric $input "License Count Input Error" wizardDialog.textManualRequested]} {

                    #update licensed product(s) information
                    set lmVals(lmFeaturesRequested) \
                            [lreplace $lmVals(lmFeaturesRequested) $ix $ix $input]
                    licTableManualUpdate $ix $input
                }
            }
        } else {
            if {[controlValuesGet wizardDialog.${ix}Requested] != ""} {
                set input [controlValuesGet wizardDialog.${ix}Requested]
                if {[isNumeric $input "License Count Input Error" wizardDialog.${ix}Requested]} {

                    #update licensed product(s) information
                    set lmVals(lmFeaturesRequested) \
                        [lreplace $lmVals(lmFeaturesRequested) $ix $ix $input]
                }
            } else {
                 set lmVals(lmFeaturesRequested) \
                    [lreplace $lmVals(lmFeaturesRequested) $ix $ix 0]
            }
        }
        

        if { [checkLMFeaturesRequestedFields] } {
            controlEnable wizardDialog.nextButt 1
        } else {
            controlEnable wizardDialog.nextButt 0
        }

    } else { # TEXT mode

        set name [lindex $lmVals(lmLicensedProductNames) $ix]

        puts "Enter the number of licenses to be requested for $name product."

        set ret [prompt]
        switch -regexp -- $ret {
            "^-$" {
                pageCreate(licManual)
            }
            "[ ]+" {
                puts "Error: Invalid input."
                while {[prompt "Press <Enter> to continue."] != "" } {
                }
                pageCreate(licManual)
            }
            "^[0-9]+" { 
                set lmVals(lmFeaturesRequested) \
                        [lreplace $lmVals(lmFeaturesRequested) $ix $ix $ret]
            }
            "[eE][xX][iI][tT]" {  
                return 0  
            }
            default {
                puts "Error: Invalid input."
                while {[prompt "Press <Enter> to continue."] != "" } {
                }
                pageCreate(licManual)
            }
        }
    }
}

#############################################################################
#
# manualNodelockChoiceCB
#
# This procedure does the work for the node locked license check box 
# callback procedures.  It updates the temporary array to be displayed on
# the Email or Phone/Fax License Request Summary page
#
# SYNOPSIS
# .tS
# manualNodelockChoiceCB ix
# .tE
#
# PARAMETERS: N/A
# ix - the index or order in which the licensed product is displayed
#
# RETURNS: n/a
#
# ERRORS: N/A
#
proc manualNodelockChoiceCB {ix} {
    global ctrlVals lmVals setupVals

    if { [isGUImode] } {
        if {[controlChecked wizardDialog.yesManualChoice] == 1} {
            #update licensed product(s) information
            set lmVals(lmFeaturesRequested) \
                    [lreplace $lmVals(lmFeaturesRequested) $ix $ix 1]

        } else {
            set lmVals(lmFeaturesRequested) \
                    [lreplace $lmVals(lmFeaturesRequested) $ix $ix 0]
        }

        licTableManualUpdate $ix [controlChecked wizardDialog.yesManualChoice]

        if { [checkLMFeaturesRequestedFields] } {
            controlEnable wizardDialog.nextButt 1
        } else {
            controlEnable wizardDialog.nextButt 0
        }

    } else { # TEXT mode
        set oldValue [lindex $lmVals(lmFeaturesRequested) $ix]
        
        if { $oldValue == 1 } {
            set lmVals(lmFeaturesRequested) \
                    [lreplace $lmVals(lmFeaturesRequested) $ix $ix 0]
        } else {
            set lmVals(lmFeaturesRequested) \
                    [lreplace $lmVals(lmFeaturesRequested) $ix $ix 1]
        }
    }
}


######################################################################
# Dialog Text Messages
######################################################################

set strTable(LICMANUAL_TITLE_EMAIL) "Email License Configuration"

set strTable(LICMANUAL_TITLE_PHONE) "Phone/Fax License Configuration"

set strTable(LICMANUAL_MSG_COMMON) \
    "Please refer to the Sales Acknowledgement Agreement for \
     the number of licenses available for the installed product(s)."

set strTable(LICMANUAL_UPDATE1) \
	"Please enter the number of licenses to be requested for\
     this host for all the installed product(s) listed below. \
     [strTableGet LICMANUAL_MSG_COMMON]"

set  strTable(LICMANUAL_TEXT) \
    "Enter the item number for the products for which you\
     would like to request a license or press \<Return\> to\
     accept this configuration."

set strTable(LICMANUAL_UPDATE2) \
	"After configuring floating licenses, click <Next> to continue."

set strTable(LICMANUAL_ELM_UPDATE2) \
	"After configuring licenses, click <Next> to continue."

set strTable(LICMANUAL_NODELOCK1) \
	"Please select the node locked licenses desired for this host from\
	the following list of installed product(s):"

set  strTable(LICMANUAL_NODELOCK2) \
	"After configuring node locked licenses, click <Next> to continue."

set strTable(LICMANUAL_ZERO_ERROR) \
    "You must enter a non-zero value for at least one product."

set strTable(LICMANUAL_TABLE_FLOATING) \
        "Select a product in the table above, then enter the number of\
        licenses to be allocated."

set strTable(LICMANUAL_TABLE_NODELOCKED) \
        "Select a product above, then specify whether to\
        request a node locked license."

set strTable(LICMANUAL_COL1) "Licensed Product"

set strTable(LICMANUAL_COL2) "Feature ID"

set strTable(LICMANUAL_COL3) "No. of licenses\nto be allocated"

set strTable(LICMANUAL_NODELOCK) "Request a node\nlocked license"

