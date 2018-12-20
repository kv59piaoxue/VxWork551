# LICCFG.TCL - Setup procedures for implementing license configuration page
#
# Copyright 1999-2003 Wind River Systems, Inc
#
# modification history
# --------------------
# 03p,15may03,bjl  changed node locked licensing to use table.
# 03o,29apr03,bjl  changed to table to accomodate more features; grammar fix 
#                  (spr 87804).  
# 03n,20feb03,bjl  do not display floating dialog if ELM for sysadmin;
#                  modified sysadmin license wording; fixed error flow
#                  after dbquery for sysadmin.  
# 03m,14feb03,bjl  fixed error dialog display for nodelock reload, modifed
#                  page sequence for db error for ELM.
# 03l,05feb03,wmd  Change back to using prodVer for the release set.
# 03k,02feb03,wmd  Need to use setupVals(torVer) for correct releaseSetVersion
#                  number.
# 03j,28jan03,wmd  Modify lmValsPopulate proc to use ALI 2.0.
# 03i,18sep02,bjl  select licensed product by default only if seats are
#                  available (spr 80884).  
# 03h,30jul02,wmd  Remvoe the Beta period limit of 10 licenses warning.
# 03g,24apr02,j_w  Added detection for existing NL license (SPR 76046)
# 03f,20mar02,bwd  SPR 72885: add pop-up dialog to warn user to install
#                  correct number of floating licenses, not more
# 03e,11mar02,bwd  For Beta period, limit to 10 licenses per host
# 03d,11mar02,bwd  SPR 73927: modified default number of seats requested to 1
# 03c,08mar02,bwd  Adjusted height for each row of products
# 03b,05mar02,bwd  Modified SETUP to be non-tornado centric
# 03a,12jun01,j_w  Added for Tornado 2.2
# 03a,22nov00,bwd  SPR 35941: added a dialog to prompt user to exit if no more
#                  licenses available for configuration.
# 02z,01nov00,j_w  fixed summary page text display
# 02y,30oct00,j_w  Added proc rmPageList to removed the correct page 
#                  list depends on the value of setupVals(lmInstType) 
#                  if transaction is canceled
# 02x,02oct00,wmd  Update a user message for clarity.
# 02w,19sep00,bwd  SPR 34462: reconstruct hostRec for commit request in proc
#                  licConfigCallback
# 02v,25aug00,bwd  Fixed TCL error - infinite loop when enter invalid input
# 02u,30jul00,wmd  Add warning about consequences of configuring LM.
# 02t,07jul00,j_w  fixed typo
# 02s,28jun00,bwd  Changed host checking to use windHostTypeGet instead of
#                  env(WIND_HOST_TYPE)
# 02r,20jun00,wmd  Remove display of setupicon for linux host.
# 02q,02jun00,bwd  Changed all "dialog ok" to use "dialog ok_with_title"
# 02p,31may00,bwd  SPR 31564: uncheck boxes by default for node locked if
#                  reload
# 02o,19may00,bwd  Small bug fix in TEXT mode - SETUP should not exit when
#                  user cancel the commit request.
# 02n,18may00,bwd  SPR 31030 - modified codes to match new page list when
#                  calling sendToALD
# 02m,27apr00,j_w  Constructed hostRec after lmPort is being set
# 02l,19apr00,bwd  Added a workaround to skip license configuration error
#                  checking for Reload until the database is ready
# 02k,13apr00,bwd  Fixed typo on variable names. Fixed error handling and
#                  page displays when CGI errors arise.
# 02j,13apr00,j_w  Updated parameters for licFileConfig and ackCommit
# 02j,13apr00,bwd  Added a column on License Config page to display the no. of
#                  licenses already allocated for current host.
# 02i,12apr00,bwd  Added codes to check that user cannot enter 0 for all
#                  features if first time configuring on this host
# 02h,27mar00,bwd  Fixed error handling for LM Configuration when requesting
#                  for licenses more than available.
# 02g,24mar00,bwd  Fixed TEXT mode to correctly display License Config Summary
#                  page
# 02f,24mar00,bwd  Removed host name from the column headings on License
#                  Configuration pages. Fixed default value to 0 for reload.
# 02e,23mar00,bwd  Fixed lmValsPopulate to correctly populate lmVals with
#                  the new format of data coming in from CGI. Changed codes 
#                  to manipulate new lmVals structure.
# 02d,02mar00,bwd  Changed the title for the License Config summary page to 
#                  fit the dialog box. Fixed isLMFeaturesRequestedNull to 
#                  correctly handle inputs for both GUI and TEXT mode
# 02c,14feb00,wmd  Change all references to prodCode to featureId.
# 02b,03feb00,j_w  Remove commit in the parameter list of commit request call
# 02a,02feb00,j_w  Add licServPort in lmValsPopulate
# 01z,01feb00,bwd  Added a global variable licServPort to store port number
#                  from the license file
# 01y,31jan00,bwd  Fixed error handling for test automation - suppress exit
#                  confirmation dialog
# 01x,27jan00,bwd  Fixed error handlings for test automation and cleaned up
#                  codes
# 01w,25jan00,j_w  move lmValsPopulate to dbQuery page
# 01v,21jan00,j_w  Set lmVals(lmPort) to default port number. 
# 01v,21jan00,bwd  Added codes to display this page for TEXT MODE (Phase 3)
# 01u,20jan00,bwd  Added codes to display this page for TEXT MODE (Phase 2)
# 01t,19jan00,wmd  Remove any requests to rollback database, no longer
#                  required.
# 01s,18jan00,bwd  Added codes to display this page for TEXT MODE
# 01r,06jan00,bwd  No test automation for command line SETUP
# 01q,17dec99,clc  change  switch statement patterns
# 01p,14dec99,wmd  Add icon to wait banner.
# 01p,02dec99,clc  add text mode
# 01o,23nov99,wmd  Add output to setup.log to log license file that is written
#                  to disk.
# 01n,22nov99,bwd  Skipped license confirm display and more work on automating
#                  Floating License installation
# 01m,22nov99,bwd  Corrected TCL error for auto floating license installation
# 01l,19nov99,bwd  Added sections for automatic LM installation
# 01k,19nov99,wmd  Fix the Exceeds number of license error dialog to display
#                  ammended value.
# 01j,17nov99,wmd  Remove spaces from the commit command.
# 01i,15nov99,wmd  Add more error handling.
# 01h,13nov99,wmd  Add error handling.
# 01g,09nov99,wmd  Need to add logic for the configuration of LM.
# 01f,03nov99,wmd  Add code to send request to the database.
# 01e,02nov99,wmd  Use the real data from the database.
# 01d,01nov99,wmd  Fix the node locked license configuration screen to match
#                  the design docs.
# 01c,31oct99,wmd  Modify wording, and add edit boxes.
# 01b,30oct99,wmd  Add a dlgTitle for nodedLock license Configuration.
# 01a,07Oct99,j_w   written
#

global returnValue
global licServPort

#############################################################################
#
# pageCreate(licConfig) - Configure licenses on current host
#
# This procedure will configure license on current host
#
# SYNOPSIS
# .tS
# pageCreate(licConfig)
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc pageCreate(licConfig) {} {
    global ctrlVals setupVals lmVals lmHostFeaturesNum
    global licConfigReturn
    global returnValue    

    # reset values that control the table or user input 
    # controls

    set ctrlVals(tableUpdate) 0
    set ctrlVals(inputUpdate) 0

    if { $setupVals(lmInstType) == "floating" } {
        set isFloatLic 1
    } else {
        set isFloatLic 0
    }

    if { [isGUImode] } {

        if {$isFloatLic && $setupVals(ELMUser) != 1} {
            # Warn user to configure number of floating licenses correctly 
            # (according to what is purchased) 
            dialog ok_with_title "Licenses Configuration" \
                [strTableGet LICCFG_CONFIGURE_LICENSES_WARN]
        }
               
        # hide the setup bitmap to allow more space on the page
        controlHide $ctrlVals(mainWindow).bitmap 1

        # set up constants to be used for control dimensions and spacing

        # dimensions for license display with table

        set XCOL1 10
        set XCOL2 90
        set XCOL3 135
        set XCOL4 175
        set XCOL5 215
        set XCOL6 260
        set Y     24
        set WIDTH 40
        set FEATWIDTH 60
        set HTHDR 25
        set FEAT_HDR_HT  [expr $Y + $HTHDR + 7]
        set HT    11
        set TXTWIDTH 19
        set INDENT 8
        set TABLEWIDTHS {83 38 40 42 42 36}

        # if reload of current license file, change the labels appropriately

        if {$lmVals(reload)} {
            set reloadY 7
            set reloadH $HT

            set ctrlVals(volatileFrm) [list \
                [list label -name Label_1 \
                        -title [strTableGet LICCFG_RELOAD_1] \
                        -x $XCOL1 -y $reloadY -w 300 -h $reloadH] \
                [list label -name label_3 \
                        -title [strTableGet LICCFG_RELOAD_2] \
                        -x $XCOL1 -y 160 -w 300 -h 15]
            ]
        } elseif {$isFloatLic} {
            set label1Text ""
            set label2Text ""

            if {$setupVals(ELMUser) == 1} {
                set label1Text [strTableGet LICCFG_ELM_1] 
                set label2Text [strTableGet LICCFG_ELM_2] 
            } else {
                set label1Text [strTableGet LICCFG_FLOAT_1] 
                set label2Text [strTableGet LICCFG_FLOAT_2] 
            }

            set ctrlVals(volatileFrm) [list \
                [list label -name Label_1 \
                        -title $label1Text \
                        -x $XCOL1 -y 7 -w 300 -h 17] \
                [list label -name label_3 \
                        -title $label2Text \
                        -x $XCOL1 -y 160 -w 300 -h 17] 
            ]
        } else {
            # node-locked

            set ctrlVals(volatileFrm) [list \
                [list label -name Label_1 \
                        -title [strTableGet LICCFG_NODELOCK_1] \
                        -x $XCOL1 -y 7 -w 300 -h 17] \
                [list label -name label_3 \
                        -title [strTableGet LICCFG_NODELOCK_2]  \
                        -x $XCOL1 -y 160 -w 300 -h 15]
            ]
        }

        # place default values in the edit boxes or check boxes 

        if {$isFloatLic} {
            lappend ctrlVals(volatileFrm) \
                [list label -name col6 \
                        -title [strTableGet LICCFG_COL6] \
                        -x $XCOL6 -y $Y -w $WIDTH -h $HTHDR]
        } else { 
            # node locked
            lappend ctrlVals(volatileFrm) \
                [list label -name col6 \
                        -title [strTableGet LICCFG_NODELOCK_COL6] \
                        -x $XCOL6 -y $Y -w $WIDTH -h $HTHDR]
        }


        # add the common controls 

        lappend ctrlVals(volatileFrm) \
            [list label -name col1 \
                        -title [strTableGet LICCFG_COL1] \
                        -x $XCOL1 -y $Y -w $FEATWIDTH -h $HTHDR] \
            [list label -name col2 \
                        -title [strTableGet LICCFG_COL2] \
                        -x $XCOL2 -y $Y -w $WIDTH -h $HTHDR] \
            [list label -name col3 \
                        -title [strTableGet LICCFG_COL3] \
                        -x $XCOL3 -y $Y -w $WIDTH -h $HTHDR] \
            [list label -name col4 \
                        -title [strTableGet LICCFG_COL4] \
                        -x $XCOL4 -y $Y -w $WIDTH -h $HTHDR] \
            [list label -name col5 \
                        -title [strTableGet LICCFG_COL5] \
                         -x $XCOL5 -y $Y -w $WIDTH -h $HTHDR] 

        # set the values for license seats

        set hostIndex [lsearch $lmVals(lmHosts) $lmVals(lmHostName)]
        if {$hostIndex == -1} {
            set numberOfFeatures 0
        } else {
            set numberOfFeatures [lindex $lmHostFeaturesNum $hostIndex]
        }

        for {set ix 0} {$ix < [llength $lmVals(lmLicensedProductNames)]} {incr ix} {
            set feature [lindex $lmVals(lmLicensedProductNames) $ix]
            set newY [expr $FEAT_HDR_HT + ($ix * $HT)]
            set featureId [lindex $lmVals(lmLicensedFeatureIds) $ix]
            set fHostAllocated 0

            if {$isFloatLic} {
                set fAllocated [lmFeaturesValueGet lmFLFeaturesAllocated $feature]
                set fAvailable [lmFeaturesValueGet lmFLFeaturesAvailable $feature]
                set fTotal [lmFeaturesValueGet lmFLFeaturesTotal $feature]
            } else {
                set fAllocated [lmFeaturesValueGet lmNLFeaturesAllocated $feature]
                set fAvailable [lmFeaturesValueGet lmNLFeaturesAvailable $feature]
                set fTotal [lmFeaturesValueGet lmNLFeaturesTotal $feature]
            }

            for {set ixf 0} {$ixf < $numberOfFeatures} {incr ixf} {

                # only if the feature is previously allocated on this host
                # (name match), retrieve allocated value

                if {$isFloatLic} {
                    set licTypeAllocated "licFLAllocated"
                } else {
                    set licTypeAllocated "licNLAllocated"
                }
                if { $feature == [lmLicProdInfoGet prodName $lmVals(lmHostName) $ixf] } {
                    set fHostAllocated \
                        [lmLicProdInfoGet $licTypeAllocated $lmVals(lmHostName) $ixf]
                }
            }
                    
            # set initial vales to be added to the table

            if {$isFloatLic} {
                set initialVal 0
            } else {
                set initialVal "No"
            }

            set featureVals [list $feature $fTotal $fAllocated $fHostAllocated $fAvailable $initialVal]
            lappend tableVals $featureVals
        }
                
        # add the table

        lappend ctrlVals(volatileFrm) \
            [list table -name licTable \
                -columns 6 -border \
	 	-x 10 -y 50 -width 295 -height 64 \
                -callback onTableEvent \
                -initial $tableVals ]

        if {$isFloatLic} {
            lappend ctrlVals(volatileFrm) \
                [list label -name tableLabel \
                    -title [strTableGet LICCFG_TABLE_FLOATING] \
                    -x 10 -y 120 -w 295 -h $HT]
        } else {
            lappend ctrlVals(volatileFrm) \
                [list label -name tableLabel \
                    -title [strTableGet LICCFG_TABLE_NODELOCK] \
                    -x 10 -y 120 -w 295 -h $HT]
        }

        # add the requested text entry box and labels

        lappend ctrlVals(volatileFrm) \
            [list label -name selectedProdLabel \
                -title "Selected Product:" \
                -x $XCOL1 -y 132 -w 59 -h $HT] \
            [list label -name selectedProd \
                -title "" \
                -x 72 -y 132 -w 233 -h $HT]

	if {$isFloatLic} {
            lappend ctrlVals(volatileFrm) \
                [list label -name allocateLabel \
                    -title "Additional Licenses to Allocate:" \
                    -x $XCOL1 -y 146 -w 104 -h $HT ]

            lappend ctrlVals(volatileFrm) \
                [list text -name textRequested  \
                    -callback "floatTextCB" \
                    -x [expr $XCOL1 + 106] -y 144 -w 30 -h 12]
        } else {
	    lappend ctrlVals(volatileFrm) \
                [list label -name checkLabel \
                    -title "Request a node locked license:" \
                    -x $XCOL1 -y 146 -w 104 -h $HT ]

            lappend ctrlVals(volatileFrm) \
                [list choice -name yesChoice -newgroup -auto \
                    -title "Yes" \
                    -x [expr $XCOL1 + 106] -y 144 -w 30 -h 12 \
                    -callback "nodelockChoiceCB"] \
                [list choice -name noChoice -auto \
                    -title "No" \
                    -x [expr $XCOL1 + 136] -y 144 -w 30 -h 12 \
                    -callback "nodelockChoiceCB"] \
        }

        # Set title for the dialog

        if {$lmVals(reload)} {
            set w [dlgFrmCreate [strTableGet LICCFG_TITLE_RELOAD]]            
        } elseif {$isFloatLic} {
            if {$setupVals(ELMUser) == 1} {
                set w [dlgFrmCreate [strTableGet LICCFG_TITLE_ELM]]
            } else {
                set w [dlgFrmCreate [strTableGet LICCFG_TITLE_FLOATING]]
            }
        } else {
            set w [dlgFrmCreate [strTableGet LICCFG_TITLE_NODELOCKED]]
        }       

        controlEnable $w.backButt 1
        controlEnable $w.nextButt 0

        if {$isFloatLic} {
            # set initial values for requested licenses:
            #     if licenses are available, default to 1
            #     if no license available, gray out the box for that product
            #     if no license available for all products, display message

            set noLicenseAllProd 1
            set length [llength $lmVals(lmLicensedProductNames)]
            for {set ix 0} {$ix < $length} {incr ix} {
                # check if any lmLicProdInfoGetlicenses left
                set prodName [lindex $lmVals(lmLicensedProductNames) $ix]
                set fInput [lmFeaturesValueGet lmFLFeaturesAvailable $prodName]
                
                # get all the values for the current feature

                set featureVals [lindex [controlValuesGet $ctrlVals(mainWindow).licTable] $ix]

                # then get just the first five values, the sixth value (requested)
                # will be set here
        
                set featureVals [lrange $featureVals 0 4]

                if { $fInput <= 0 } {
                    # no license left for this product. Default to 0.
                                       
                    set lmVals(lmFeaturesRequested) \
                       [lreplace $lmVals(lmFeaturesRequested) $ix $ix 0]
                    lappend featureVals 0
                } else {
                    # default to 1, or 0 if reload

                    if {$lmVals(reload)} {
                        # if reload, use existing license info - no new allocation

                        set lmVals(lmFeaturesRequested) \
                           [lreplace $lmVals(lmFeaturesRequested) $ix $ix 0]
                        lappend featureVals 0

                    } else {                   
                        set lmVals(lmFeaturesRequested) \
                           [lreplace $lmVals(lmFeaturesRequested) $ix $ix 1]

                        lappend featureVals 1
                    }                

                    set noLicenseAllProd 0
                }

                lappend licTableVals $featureVals                
            }            
        } else { # node locked
            if {$lmVals(reload) != 1} {
                set noLicenseAllProd 1
            } else {
                set noLicenseAllProd 0
            }
            set length [llength $lmVals(lmLicensedProductNames)]
            for {set ix 0} {$ix < $length} {incr ix} {
                # check if any lmLicProdInfoGetlicenses left
                set prodName [lindex $lmVals(lmLicensedProductNames) $ix]
                set fInput [lmFeaturesValueGet lmNLFeaturesAvailable $prodName]

                # also check to see if the customer has already configured a node-locked
                # license for this product, if so set fInput = 0 to disable the checkbox
        
                if {[lmLicHostIndexGet $lmVals(lmHostName)] > 0} {
                    if {[isNLSeatAllocated  $prodName $lmVals(lmHostName)] == 1} {
                        set fInput 0
                    }
                } else {
                    if {$fInput !=  0} {
                        set fInput 1
                    }
                }

                # get all the values for the current feature

                set featureVals [lindex [controlValuesGet $ctrlVals(mainWindow).licTable] $ix]

                # then get just the first five values, the sixth value (requested)
                # will be set here
        
                set featureVals [lrange $featureVals 0 4]
                set allocated [lindex $featureVals 3]

                if { $fInput <= 0 || $allocated == 1} {
                    # no license left for this product or node locked
                    # license already allocated. Default to "No". 

                    set lmVals(lmFeaturesRequested) \
                       [lreplace $lmVals(lmFeaturesRequested) $ix $ix 0]
                    lappend featureVals "No"

                } else {
                    # default to "Yes"
                    
                    set noLicenseAllProd 0
                    if {$lmVals(reload)} {
                        set lmVals(lmFeaturesRequested) \
                           [lreplace $lmVals(lmFeaturesRequested) $ix $ix 0]

                        lappend featureVals "No"
                    } else {
                        set lmVals(lmFeaturesRequested) \
                           [lreplace $lmVals(lmFeaturesRequested) $ix $ix 1]

                        lappend featureVals "Yes"
                    }
                }

                lappend licTableVals $featureVals                
            }
        }

        controlPropertySet $w.licTable -columnwidths $TABLEWIDTHS 

        # If no more licenses available for all products, prompt user
        if { $noLicenseAllProd == 1 } {
            dialog ok_with_title "No More Licenses" [strTableGet LICCFG_NO_LIC_ERROR]
            controlEnable $w.nextButt 0

            if {$isFloatLic} {
	        controlEnable $w.textRequested 0
	    } else {
                controlEnable $w.yesChoice 0
                controlEnable $w.noChoice 0
            }
        } else {
            # fill in the table values

            controlValuesSet $w.licTable $licTableVals

            # focus on the first selection in the table

            controlSelectionSet $w.licTable 0
            controlFocusSet $w.licTable

            if {[isLMFeaturesRequestedNull]} {
                controlEnable wizardDialog.nextButt 0
            } else {
                controlEnable wizardDialog.nextButt 1
            }
        }        

        if {$lmVals(reload)} {
            if {$isFloatLic} {
                controlEnable $w.textRequested 0
            } else {
                # nodelocked

                controlEnable $w.yesChoice 0
                controlEnable $w.noChoice 0
            }

            controlEnable $w.nextButt 1
        }

        # test automation

        if {$ctrlVals(useInputScript)} {
            autoSetupLog "License Configuration Page: skipped"
            nextCallback
        }

    } else { # text mode
        doTextMode $isFloatLic
    }
}

#############################################################################
#
# onTableEvent - callback for floating license table event
#
# This procedure is the callback when a table event occurs.  The current
# values in the table selection are retrieved to update the selected
# product label and the number of requested licenses in the text entry box.  
#
# SYNOPSIS
# .tS
# onTableEvent
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#
#

proc onTableEvent {} {
    global ctrlVals lmVals setupVals

    # if the user is currently updating the entry in the text box
    # or node locked radio buttons, simply return so that the 
    # table callback does not update the text entry at the same time.    

    if {$ctrlVals(inputUpdate) == 1} {
        return
    }

    # only perform an update for a selection change.  

    set event [controlEventGet $ctrlVals(mainWindow).licTable]
    if {$event != "selchange"} {
        return
    }

    # get the feature values from the table.

    set featureVals [lindex \
			[controlValuesGet $ctrlVals(mainWindow).licTable] \
			[controlSelectionGet $ctrlVals(mainWindow).licTable]]
    
    set requested [lindex $featureVals 5]
    set available [lindex $featureVals 4]
    set allocated [lindex $featureVals 3]
    set prodName [lindex $featureVals 0]
    
    # set the tableUpdate variable to 1 so that the text entry callback
    # does not update the table at the same time.  

    set ctrlVals(tableUpdate) 1

    # update the selected product label and text entry box with the
    # selected table values.  

    controlValuesSet $ctrlVals(mainWindow).selectedProd $prodName
    if {$setupVals(lmInstType) == "floating"} {
        controlValuesSet $ctrlVals(mainWindow).textRequested $requested
    } else {     
        # nodelocked
        if {$requested == "Yes"} {
            controlCheckSet $ctrlVals(mainWindow).yesChoice 1
            controlCheckSet $ctrlVals(mainWindow).noChoice 0
        } else {
            controlCheckSet $ctrlVals(mainWindow).yesChoice 0
            controlCheckSet $ctrlVals(mainWindow).noChoice 1
        }

        controlFocusSet $ctrlVals(mainWindow).licTable
    }

    # disable the text box if no licenses are available or if
    # reloading the license file.

    if {$setupVals(lmInstType) == "floating"} {
        if {$available == 0 || $lmVals(reload) == 1} {
            controlEnable $ctrlVals(mainWindow).textRequested 0
        } else {
            controlEnable $ctrlVals(mainWindow).textRequested 1
        }   
    } else {
        # node-locked

        if {$available == 0 || $lmVals(reload) == 1 || $allocated == 1} {
            controlEnable $ctrlVals(mainWindow).yesChoice 0
            controlEnable $ctrlVals(mainWindow).noChoice 0
        } else {
            controlEnable $ctrlVals(mainWindow).yesChoice 1
            controlEnable $ctrlVals(mainWindow).noChoice 1
        }   
    }

    # table selection update is done.  
    
    set ctrlVals(tableUpdate) 0
}

#############################################################################
#
# licTableUpdate - updates floating license table with specified values
#
# This procedure updates the floating license table for the specified
# feature and number of licenses requested.  This is called when the
# user updates the number of requsted licenses in the text entry box.
#
# SYNOPSIS
# .tS
# licTableUpdate
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


proc licTableUpdate {featIx numRequested} {
    global lmVals ctrlVals setupVals

    set length [llength $lmVals(lmLicensedProductNames)]
    for {set ix 0} {$ix < $length} {incr ix} {             
        # get all the values for the current feature

        set featureVals [lindex [controlValuesGet $ctrlVals(mainWindow).licTable] $ix]
   
        if { $ix == $featIx } {
            # then get just the first five values, the sixth value (requested)
            # will be updated here
        
            set featureVals [lrange $featureVals 0 4]

            if {$setupVals(lmInstType) == "floating"} {
                lappend featureVals $numRequested
            } else {
                # node-locked
                if {$numRequested == 1} {
                    lappend featureVals "Yes"
                } else {
                    lappend featureVals "No"
                }
            }
        } 

        lappend licTableVals $featureVals         
    } 

    controlFocusSet $ctrlVals(mainWindow).licTable  
    controlValuesSet $ctrlVals(mainWindow).licTable $licTableVals            
    controlSelectionSet $ctrlVals(mainWindow).licTable $featIx
           
    if {$ctrlVals(inputUpdate) == 1} {
        # if the user is updating the text entry box, put focus
        # back on the entry box

        if {$setupVals(lmInstType) == "floating"} {
            controlFocusSet $ctrlVals(mainWindow).textRequested
        } 
    }            
}

#############################################################################
#
# doTextMode
#
# This procedure will configure license on current host in text mode
#
# SYNOPSIS
# .tS
# doTextMode isFloatLic
# .tE
#
# PARAMETERS: isFloatLic - parameter indicating if license mode is floating
#
# RETURNS: N/A
#
# ERRORS: N/A
#
#
proc doTextMode {isFloatLic} {

    global ctrlVals setupVals lmVals lmHostFeaturesNum
    global licConfigReturn
    global returnValue


    # find the maximum width of the product names

    set nameWidth 0
    foreach name $lmVals(lmLicensedProductNames) {
        if { [string length $name] > $nameWidth } {
            set nameWidth [string length $name]
        }
    }

    set host $lmVals(lmHostName)

    while (1) {

    # Set title
    if {$lmVals(reload)} {

        printPageTitle [strTableGet LICCFG_TITLE_RELOAD]
        puts "[strTableGet LICCFG_RELOAD_1]\n"

    } elseif {$isFloatLic} {

        # Floating License End User

        printPageTitle [strTableGet LICCFG_TITLE_FLOATING]
        puts "[strTableGet LICCFG_FLOAT_1]\n"

    } else {

        # Nodelocked End User

            printPageTitle [strTableGet LICCFG_TITLE_NODELOCKED]
        puts "[strTableGet LICCFG_NODELOCK_1]\n"
    }

    # print column labels for table of products

    # print column label

    if { $lmVals(reload) || $isFloatLic } {
        set HEADER_L1 "Additional"
        set HEADER_L2 "licenses"
        set HEADER_L3 "to allocate"
    } else {
        set HEADER_L1 "Check to"
        set HEADER_L2 "request a"
        set HEADER_L3 "license"
    }

    puts [format " %-4s  %-*s\t %-13s %-13s  %-11s  %-13s   %-13s" \
          "" $nameWidth "" "Total No." "Total No." \
          "Existing" "Licenses" "$HEADER_L1"]
    puts [format " %-4s  %-*s\t %-13s %-13s  %-11s  %-13s   %-13s" \
          "" $nameWidth "Licensed" "of licenses" "of licenses"\
          "licenses" "available for" "$HEADER_L2"]
    puts [format " %-4s  %-*s\t %-13s %-13s  %-11s  %-13s   %-13s" \
          "item" $nameWidth "Product" "purchased" "allocated"\
          "on host" "allocation" "$HEADER_L3"]
    for { set i 0 } { $i < [expr $nameWidth + 80] } { incr i } {
        puts -nonewline "-"
    }
    puts ""

    # display table contents 

    set hostIndex [lsearch $lmVals(lmHosts) $lmVals(lmHostName)]
    if {$hostIndex == -1} {
        set numberOfFeatures 0
    } else {
        set numberOfFeatures [lindex $lmHostFeaturesNum $hostIndex]
    }

    if {$isFloatLic} {
        for { set ix 0 } { $ix < [llength $lmVals(lmLicensedProductNames)] } { incr ix } {
            set feature [lindex $lmVals(lmLicensedProductNames) $ix]
            set featureId [lindex $lmVals(lmLicensedFeatureIds) $ix]              
            set fHostAllocated 0

            set fAllocated [lmFeaturesValueGet lmFLFeaturesAllocated $feature]
            set fAvailable [lmFeaturesValueGet lmFLFeaturesAvailable $feature]
            set fTotal [lmFeaturesValueGet lmFLFeaturesTotal $feature]

            for {set ixf 0} {$ixf < $numberOfFeatures} {incr ixf} {

                # only if the feature is previously allocated on this host
                # (name match), retrieve allocated value

                if { $feature == [lmLicProdInfoGet prodName $lmVals(lmHostName) $ixf] } {
                      set fHostAllocated \
                        [lmLicProdInfoGet licFLAllocated $lmVals(lmHostName) $ixf]
                }
            }

            if {$lmVals(reload)} {
                set lmVals(lmFeaturesRequested) \
                    [lreplace $lmVals(lmFeaturesRequested) $ix $ix \
                              0 $ix]

                puts [format " %-4s  %-*s\t   %-13s  %-13s  %-11s  %-13s   %-4s" \
                    [expr $ix + 1] \lmLicProdInfoGet
                    $nameWidth $feature $fTotal $fAllocated $fHostAllocated $fAvailable \
                    [lindex $lmVals(lmFeaturesRequested) $ix] ]

            } else {
                puts [format " %-4s  %-*s\t   %-13s  %-13s  %-11s  %-13s   %-4s" \
                    [expr $ix + 1] \
                    $nameWidth $feature $fTotal $fAllocated $fHostAllocated $fAvailable 1 ]
            }
        }
    } else { # Node-locked section
        for { set ix 0 } { $ix < [llength $lmVals(lmLicensedProductNames)] } { incr ix } {
            set feature [lindex $lmVals(lmLicensedProductNames) $ix]
            set featureId [lindex $lmVals(lmLicensedFeatureIds) $ix]              
            set fHostAllocated 0

            set fAllocated [lmFeaturesValueGet lmNLFeaturesAllocated $feature]
            set fAvailable [lmFeaturesValueGet lmNLFeaturesAvailable $feature]
            set fTotal [lmFeaturesValueGet lmNLFeaturesTotal $feature]

            for {set ixf 0} {$ixf < $numberOfFeatures} {incr ixf} {

                # only if the feature is previously allocated on this host
                # (name match), retrieve allocated value

                if { $feature == [lmLicProdInfoGet prodName $lmVals(lmHostName) $ixf] } {
                      set fHostAllocated \
                        [lmLicProdInfoGet licNLAllocated $lmVals(lmHostName) $ixf]
                }
            }

            if {$lmVals(reload)} {
                set lmVals(lmFeaturesRequested) \
                    [lreplace $lmVals(lmFeaturesRequested) $ix $ix \
                              0 $ix]

                puts [format " %-4s  %-*s\t   %-13s  %-13s  %-11s  %-13s   %-4s" \
                    [expr $ix + 1] \lmLicProdInfoGet
                    $nameWidth $feature $fTotal $fAllocated $fHostAllocated $fAvailable \
                    [lindex $lmVals(lmFeaturesRequested) $ix] ]

            } else {
                if { [lindex $lmVals(lmFeaturesRequested) $ix] == 0 } {
                    set request ""
                } else {
                    set request "x"
                }

                puts [format "%4s  %-*s  %-13s  %-13s  %-11s  %-13s   %4s" \
                    [expr $ix + 1] \
                    $nameWidth $feature $fTotal $fAllocated $fHostAllocated $fAvailable \
                    $request ]
            }
        }
    }
        
    # prompt for user input

    if {$lmVals(reload)} {

        # reload current license file

        puts "\n[strTableGet LICCFG_RELOAD_2_TEXT]\n"

        set totalProd [llength $lmVals(lmLicensedProductNames)]
        set ret [prompt]

        switch -regexp -- $ret {
            "^$" {
                set ret [licConfigCallBack]
                if { $ret == 1} {
                    set licConfigReturn 0
                    nextCallback
                    return 0
                } elseif { $ret == -1 } {
                    set licConfigReturn 1
                    nextCallback
                    return 0
                } elseif { $ret == 0 } {
                    return 0
                } else {
                    return [pageCreate(licConfig)]
                }
            }
            "^-$" {
                backCallback
                return 0  
            }
            "^[eE][xX][iI][tT]$" { 
                set returnValue 0
                return 0  
            }
            default {
                puts "Error: Invalid input. You are requesting to\
                      reload the existing license file."
                while {[prompt "Press <Enter> to continue."] != "" } {
                }
            }
        }
    } elseif {$isFloatLic} {

        #floating license configuration

        puts "\n\n[strTableGet LICCFG_FLOAT_2_TEXT]\n"

        set totalProd [llength $lmVals(lmFeaturesAvailable)]
        set ret [prompt]

        switch -regexp -- $ret {
            "^$" {
                if { [isLMFeaturesRequestedNull] } {
                    puts "Warning: Please enter the number of\
                          license\(s\) for all products"
                } else {
                    set ret [licConfigCallBack]
                    if { $ret == 1} {
                        set licConfigReturn 0
                        nextCallback
                        return 0
                    } elseif { $ret == -1 } {
                        set licConfigReturn 1
                        nextCallback
                        return 0
                    } elseif { $ret == 0 } {
                        return 0
                    } else {
                        return [pageCreate(licConfig)]
                    }
                }
            }
            "^-$" {  
                backCallback
                return 0  
            }
            "^[eE][xX][iI][tT]$" {  
                set returnValue 0
                return 0  
            }
            "[ ]+" {
                puts "Error: please enter select only one item"
                while {[prompt "Press <Enter> to continue."] != "" } {
                }
            }
            "([1-9])+" {
                if { $ret > $totalProd } {
                     puts [strTableGet 3145_COMP_SELECT_CHANGE_INVALID]
                    while {[prompt "Press <Enter> to continue."] != "" } {
                    }
                } else {
                    floatingLicRequestedUpdate [expr $ret - 1]
                }
            }
            default {
                puts "Error: Invalid input."
                while {[prompt "Press <Enter> to continue."] != "" } {
                }
            }
        }

    } else {

        # nodelock end user mode

        puts "\n[strTableGet LICCFG_NODELOCK_2_TEXT]"

        set totalProd [llength $lmVals(lmFeaturesAvailable)]
        set ret [prompt]

        switch -regexp -- $ret {
            "^$" {
                if { [isLMFeaturesRequestedNull] } {
                    puts "Error: At least one product must be selected."
                    while {[prompt "Press <Enter> to continue."] != "" } {
                    }
                } else {
                    set ret [licConfigCallBack]
                    if { $ret == 1} {
                        set licConfigReturn 0
                        nextCallback
                        return 0
                    } elseif { $ret == -1 } {
                        set licConfigReturn 1
                        nextCallback
                        return 0
                    } elseif { $ret == 0 } {
                        return 0
                    } else {
                        return [pageCreate(licConfig)]
                    }
                }
            }
            "^-$" {
                backCallback
                return 0
            }
            "[eE][xX][iI][tT]" {
                set returnValue 0
                return 0
            }
            "([1-9])+" {
                set okFlag 1
                foreach index $ret {
                    if { $index > $totalProd } {
                        set okFlag 0
                    }
                }

                if { $okFlag == 0 } {
                    puts [strTableGet 3145_COMP_SELECT_CHANGE_INVALID]
                    while {[prompt "Press <Enter> to continue."] != "" } {
                    }
                } else {
                   foreach index $ret {
                       nodelockLicRequestedUpdate [expr $index - 1]
                   }
                }
            }
            default {
                puts "Warning: The list you have entered is invalid."
                while {[prompt "Press <Enter> to continue."] != "" } {
                }
            }
        }
     }
  }
}

#############################################################################
#
# licConfigDlgCreate() - Create License Configuration dialog
#
# This procedure will create License Configuration dialog
#
# SYNOPSIS
# .tS
# licConfigDlgCreate() 
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc licConfigDlgCreate {} {
    global ctrlVals
    global setupVals
    global env

    if { [windHostTypeGet] == "x86-linux2"} {
        dialogCreate \
            -name licConfigDlg \
            -notitle \
            -parent $ctrlVals(parentDialog) \
            -helpfile $setupVals(setupHelp) \
            -width 250 -height 32 \
            -init {
                controlPropertySet licConfigDlg.message1 -bold 1; \
                windowTimerCallbackSet licConfigDlg \
                            -milliseconds 200 licConfigCallBack
            } \
            -controls [list \
                    [list label -name "message1" -center \
                        -title [strTableGet LICCFG_BANNER] \
                        -x 35 -y 12 -w 200 -h 10 ]
            ]
    } else {
        dialogCreate \
            -name licConfigDlg \
            -notitle \
            -parent $ctrlVals(parentDialog) \
            -helpfile $setupVals(setupHelp) \
            -width 250 -height 32 \
            -init {
                controlPropertySet licConfigDlg.message1 -bold 1; \
                windowTimerCallbackSet licConfigDlg \
                            -milliseconds 200 licConfigCallBack
            } \
            -controls [list \
                    [list bitmap -name bmp -stretch -title \
                        "[cdFileNameGet \
                        [file join RESOURCE BITMAPS SETUPICO.BMP]]" \
                        -x 10 -y 5 -w 20 -h 20] \
                    [list label -name "message1" -center \
                        -title [strTableGet LICCFG_BANNER] \
                        -x 35 -y 12 -w 200 -h 10 ]
            ]
    }
}

#############################################################################
#
# licConfigCallBack() - Callback routine to send the license request
#
# This procedure will send the license request
#
# SYNOPSIS
# .tS
# licConfigCallBack() 
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: 
#
#    GUI MODE:
#     1 - to go onto the next page
#     0 - to redisplay LICCFG page
#     [calcPage lmInstOptions] - to go back to lmInstOptions page
#
#    TEXT MODE:
#     2 - to redisplay LICCFG page
#     1 - to go onto the next page
#     0 - exit SETUP
#    -1 - to go back to lmInstOptions page
#
#
# ERRORS: N/A
#


proc licConfigCallBack {} {
    global setupVals ctrlVals
    global lmVals
    global LicFileConfigRequest CommitRequest
    global env
    global returnValue

        set hostRec {}

    if { ![isGUImode] } {

        # TEXT mode: for update, prompt error if user entered all 0 for requests

        if { !$lmVals(reload) } {

            set isAllZero 1
            for {set ix 0} {$ix < [llength $lmVals(lmFeaturesRequested)]} {incr ix} {
                if { [lindex $lmVals(lmFeaturesRequested) $ix] != 0 } {
                    set isAllZero 0
                }
            }

            if { $isAllZero } {
                puts "[strTableGet LICCFG_ZERO_ERROR]\n\n\Press <Enter> to return\
                      to the License Configuration page and enter license\(s\) for\
                      at least one feature."

                while { [prompt] != "" } {
                }

                return 2
            }
        }
    }

    if { [isGUImode] } {
        windowTimerCallbackSet licConfigDlg 0 ""
    } else {
        puts "[strTableGet LICCFG_BANNER]\n"
    }

    # license calculation and error checking here...
 
    set lmVals(token) 0

    # format the parameters to send to the ALD

    set configList {}
    for {set ix  0} {$ix < [llength $lmVals(lmLicensedProductNames)]} {incr ix} {
        set featureSet ""
        append featureSet "[lindex $lmVals(lmLicensedProductNames) $ix]:"
        append featureSet "[lindex $lmVals(lmLicensedFeatureIds) $ix]:"
        append featureSet "[lindex $lmVals(lmFeaturesRequested) $ix]"
        set featureSet [string trim $featureSet]

        if {$ix != [expr [llength $lmVals(lmLicensedProductNames)]- 1]} {
            append featureSet "|"
        }
        append configList $featureSet
    }


    # check that if port is NULL use 27000

    if {$lmVals(lmPort) == ""} {
        set lmVals(lmPort) $lmVals(defaultServPort)
    }

        set hostRec \
                "$lmVals(lmHostName)|$lmVals(lmHostId)|$lmVals(lmPort)|$configList"

    set params [format "%s|%s|%s|%s" \
                                $setupVals(WRSLicense) $setupVals(prodVer) \
                $setupVals(lmInstType) $hostRec]

    # send to ALD

    set reply 0
    while {$reply == 0} {
        set reply [sendToALD  $LicFileConfigRequest $params]
	 
        if { [isGUImode] } {

            # if an error occurs either retry or go to lm options
            # if error occurs during test automation, exit SETUP
  
            if {[isNumeric $reply]} {
                                
                if {$reply == 1} {

                    if { $ctrlVals(useInputScript) } {
                        autoSetupLog "ERROR in sendToALD: $CommitRequest $params"
                        autoSetupLog "Reply: $reply"
                        autoSetupLog "Application Exit\n"
                        set setupVals(cancel) 1                
                        applicationExit
                        set returnValue 0
                        return $returnValue
                    } else {
                        controlEnable wizardDialog.nextButt 1
                        controlEnable wizardDialog.backButt 1
                                                
                        windowClose licConfigDlg
                        
                        # remove autoInst or nodelock page list 
                        rmPageList

                        if {[instTypeGet] == "license"} {
                            # Return to lmInstOptions page and set to email option

                            set setupVals(lmInstOptions) "onEmail"                                                             
                            set returnValue [calcPage lmInstOptions]
                        } else {
                            # Return to lmAutoManChoice page and set to manual 
                            # option
                            
                            set setupVals(lmAutoManChoice) "onManual"                                  
                            set returnValue [calcPage lmAutoManChoice]
                            controlHide $ctrlVals(mainWindow).bitmap 0
                        }
                        
                        return $returnValue
                    }
                }
            }
        } else { # TEXT MODE

            # if an error occurs go to lm options page
  
            if {[isNumeric $reply]} {
                if {$reply == 1} {
                    return -1
                }
            }
        }
    }

    # No error, the reply is a valid token to be saved for the commit request

    set lmVals(token) [string trim $reply]
    set retVal [licenseConfirm]

    # check to make sure directory paths exists and is writable

    set path [destDirGet]
    set outFileName [file join $path .wind license WRSLicense.lic]
    set path1 [file join $path .wind license]

    while {![file isdirectory $path1]} {
        if {[catch [file mkdir $path1] err]} {

            # invalid path...exit SETUP

            if { [isGUImode] } {

                if { $ctrlVals(useInputScript) } {

                    autoSetupLog "[strTableGet CANNOT_CREATE_PATH_1_TEXT]"
                    autoSetupLog "Application Exit\n"
                    set setupVals(cancel) 1                
                    applicationExit
                    set returnValue 0
                    return $returnValue

                } else {
                    set ans [dialog resume_exit \
                            "License Management Configuration" \
                            [strTableGet CANNOT_CREATE_PATH_1]]

                    dbgputs "Cannot create $path1"

                    if {$ans == "1"} {  applicationExit  }
                }

            } else {
                dbgputs "Cannot create $path1"
                puts [strTableGet CANNOT_CREATE_PATH_1_TEXT]

                set msg "\nPress 1 to retry , 2 to exit SETUP\n"
                while (1) {
                    switch -regexp -- [prompt $msg] {
                        "^1$" { break }
                        "^2$" { return 0 }
                    }
                }
            }
        }
    }
    
    # update the return value to user's input (OK or CANCEL)
    set returnValue $retVal

    if {$retVal} { # OK on Summary page...commit
 
        # send the commit command and save the license file into the 
        # licensefile dir [destDirGet]/.wind/license

        dbgputs "Commit: hostRec"

        set hostRec \
               "$lmVals(lmHostName)|$lmVals(lmHostId)|$lmVals(lmPort)|$configList"

        set params [format "%s|%s|%s|%s|%s|%s|%s|%s|%s" \
                                $setupVals(WRSLicense) $setupVals(prodVer) \
                                $lmVals(token) $setupVals(sysAdminName) \
                                $setupVals(userPhone) $setupVals(userEmail) \
                                "SETUP" $setupVals(lmInstType)  \
                                $hostRec]

        set reply 0
        while {$reply == 0} {
            set reply [sendToALD $CommitRequest $params]
  
            if { [isGUImode] } {

                # if an error occurs either retry or go to lm options
                # if test automation, exit and put error log

                if {[isNumeric $reply]} {

                    if {$reply == 1} {

                        if { $ctrlVals(useInputScript) } {
                            autoSetupLog "ERROR in sendToALD: $CommitRequest $params"
                            autoSetupLog "Reply: $reply"
                            autoSetupLog "Application Exit\n"
                            set setupVals(cancel) 1                
                            applicationExit

                            set returnValue 0
                            return $returnValue

                        } else {
                            controlEnable wizardDialog.nextButt 1
                            controlEnable wizardDialog.backButt 1

                            windowClose licConfigDlg  

                            # remove autoInst or nodeLock page list
                            rmPageList

                            if {[instTypeGet] == "license"} {
                                # Return to lmInstOptions page and set to email option

                                set setupVals(lmInstOptions) "onEmail"                                                             
                                set returnValue [calcPage lmInstOptions]
                            } else {
                                # Return to lmAutoManChoice page and set to manual 
                                # option
                            
                                set setupVals(lmAutoManChoice) "onManual"                                  
                                set returnValue [calcPage lmAutoManChoice]
                                controlHide $ctrlVals(mainWindow).bitmap 0
                            }

                            return $returnValue
                        }
                    }
                }
            } else { # TEXT MODE 

                # if an error occurs, go to lm options

                if {[isNumeric $reply]} {
                    if {$reply == 1} {
                        return -1
                    }
                }
            }
        }

        if { [isGUImode] } {  beginWaitCursor  }

        # opening license file to update

        if {[catch {open $outFileName w} fd]} {

            # If errror, prompt message and exit SETUP

            set msg "Error opening license file output filename: $outFileName"
            uninstLog setup $msg
            dbgputs $msg

            if { $ctrlVals(useInputScript) } {            
                autoSetupLog "$msg"
                autoSetupLog "Application Exit\n"
                set setupVals(cancel) 1                
                applicationExit

                set returnValue 0
                return $returnValue
            }

            if { [isGUImode] } {     
                endWaitCursor

                windowClose licConfigDlg  
                set returnValue 0
                return $returnValue

            } else {
                set msg "Press <Enter> to Continue"
                while { [prompt $msg] != "" } {
                }
                return 0
            }
        } else {
            puts $fd $reply

            # closing license file

            if {[catch {close $fd} err]} {

                set msg "Error closing file $outFileName"
                uninstLog setup $msg
                dbgputs msg

                if { $ctrlVals(useInputScript) } {            
                    autoSetupLog "$msg"
                    autoSetupLog "Application Exit\n"
                    set setupVals(cancel) 1                
                    applicationExit

                    set returnValue 0
                    return $returnValue
                 }
            }
            uninstLog setup "Setup wrote \"$reply\" to $outFileName"

            if { $ctrlVals(useInputScript) } {            
                autoSetupLog "Setup wrote the following information\
                              to $outFileName:\n\"$reply\""
            }
        }

        # success in updating the license file
        # proceed to next page

        if { [isGUImode] } {

            endWaitCursor

            # turn on the setup bitmap for next page
            controlHide $ctrlVals(mainWindow).bitmap 0

            windowClose licConfigDlg
        }
        
    } else { # user click Cancel on Summary page (retVal=0)
       
        # Return to License Configuration page

        if { [isGUImode] } {

            windowClose licConfigDlg  

        } else {
            # return to LICCFG page
            return 2
        }
    }

    return $returnValue
}

#############################################################################
#
# pageProcess(licConfig) - process inputs from the licConfig page
#
# This procedure will process inputs from the licConfig page
#
# SYNOPSIS
# .tS
# pageProcess(licConfig)
# .tE
#
# PARAMETERS: N/A
#
# RETURNS:  1 if successful
#
# ERRORS: N/A
#

proc pageProcess(licConfig) {} {
    global ctrlVals setupVals lmVals
    global returnValue
    global licConfigReturn


    if { [isGUImode] } {
        controlEnable wizardDialog.nextButt 0
        controlEnable wizardDialog.backButt 0

        # test automation...store licenses information
     
        if { $ctrlVals(useInputScript) } {

            for {set ix 0} {$ix < [llength $lmVals(lmLicensedProductNames)]} {incr ix} {
                set featureName [lindex $lmVals(lmLicensedProductNames) $ix]
                set fAvailable [lmFeaturesValueGet lmFeaturesAvailable $featureName]

                if {$lmVals(lmLicMode) == "floating"} {
                    set fAvailable [lmFeaturesValueGet lmFLFeaturesAvailable $featureName]
                    set lmVals(lmFeaturesRequested) \
                        [lreplace $lmVals(lmFeaturesRequested) $ix $ix $fAvailable]
                } else {
                    set fAvailable [lmFeaturesValueGet lmNLFeaturesAvailable $featureName]
                    set lmVals(lmFeaturesRequested) \
                        [lreplace $lmVals(lmFeaturesRequested) $ix $ix 1]
                }
            }
        }

        # GUI mode: for update, prompt error if user entered all 0 for requests

        if { !$lmVals(reload) } {

            set isAllZero 1
            for {set ix 0} {$ix < [llength $lmVals(lmFeaturesRequested)]} {incr ix} {
                if { [lindex $lmVals(lmFeaturesRequested) $ix] != 0 } {
                    set isAllZero 0
                }
            }

            if { $isAllZero } {
                dialog ok_with_title "ERROR: License Request" \
                    [strTableGet LICCFG_ZERO_ERROR]

                controlEnable wizardDialog.nextButt 1
                controlEnable wizardDialog.backButt 1
                return 0
            }
            
            # SPR 76046
            # detect if the host has been configured previously
            if { $setupVals(lmInstType) == "nodeLocked" } {
                if { [hasExistingNL] } { 
                    set ans [dialog yes_no_cancel "NodeLocked license" \
                            [strTableGet LICCFG_TO_RELOAD]]            
                    if { $ans == 0 } { 
                        # yes
                        set lmVals(reload) 1
                        updateToNLRequest
                    } elseif {$ans == 1} {
                        # no
                        set lmVals(reload) 0
                    } else {
                        # cancel
                        controlEnable wizardDialog.nextButt 1
                        controlEnable wizardDialog.backButt 1
                    
                        return 0
                    }
                }
            }

        }

                
        licConfigDlgCreate

        if {[isUnix]} {
            pageRemove lmStartupOptions
        }
        controlEnable wizardDialog.nextButt 1
        controlEnable wizardDialog.backButt 1

    } else { # text mode
        
        # return to lmOptions if an error occurs in licConfigCallBack

        if { $licConfigReturn } {

            # remove autoInst or nodeLock page list
            rmPageList

            # Return to lmInstOptions page and set to email option
            set setupVals(lmInstOptions) "onEmail"                                      

            return [calcPage lmInstOptions]
        }

        if {[isUnix]} {
             pageRemove lmStartupOptions
        }
    }

    return $returnValue
}

#############################################################################
#
# rmPageList() - helper function to remove autoInst or nodeLock page list, 
#                depends on setupVals(lmInstType)
#
# This procedure will remove the autoInst or nodeLocke page list
#
# SYNOPSIS
# .tS
# rmPageList
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#
proc rmPageList {} {
        global setupVals

        if {$setupVals(lmInstType) == "nodeLocked"} {
                pageListRemove dbQuery
                pageListRemove lmOptions
                pageListRemove nodeLock
        } elseif {$setupVals(lmInstType) == "floating"} {
                pageListRemove autoInst
        }

}

#############################################################################
#
# licenseConfirmInit() - Display License Summary information
#
# This procedure will display license summary
#
# SYNOPSIS
# .tS
# licenseConfirmInit(isFloatLic)
# .tE
#
# PARAMETERS: isFloatLic - 1 if floating license, else 0
#
# RETURNS:  1 if ok or 0 if cancel
#
# ERRORS: N/A
#

proc licConfirmDlgInit {} {
    global lmVals ctrlVals lmHostFeaturesNum

    set hostIndex [lsearch $lmVals(lmHosts) $lmVals(lmHostName)]
    if {$hostIndex == -1} {
        set numberOfFeatures 0
    } else {
        set numberOfFeatures [lindex $lmHostFeaturesNum $hostIndex]
    }

    # Fill in the informational text box for the users

    if {$lmVals(lmLicMode) == "floating"} {
        for {set ix 0} {$ix < [llength $lmVals(lmFeaturesTotal)]} {incr ix} {
            set feature [lindex $lmVals(lmFeaturesTotal) $ix]
            set featureName [lindex $feature 0]
            set fHostAllocated 0

            for {set ixf 0} {$ixf < $numberOfFeatures} {incr ixf} {

                # only if the feature is previously allocated on this host
                # (name match), retrieve allocated value

                if { $featureName == [lmLicProdInfoGet prodName $lmVals(lmHostName) $ixf] } {
                    set fHostAllocated \
                        [lmLicProdInfoGet licFLAllocated $lmVals(lmHostName) $ixf]
                }
            }

            set featureName [lindex $lmVals(lmLicensedProductNames) $ix]
            set featureTotal [expr [lindex $lmVals(lmFeaturesRequested) $ix] + $fHostAllocated]
            set featureOutput [list $featureName $featureTotal]
            lappend featureOutputList $featureOutput
        }

        controlPropertySet licConfirmDlg.floatSummaryTable -columnwidths {100 75} 
        controlValuesSet licConfirmDlg.floatSummaryTable $featureOutputList
    } else { # node locked

        # for Reload, display all feature names retrieved from database

        if {$lmVals(reload)} {
            for {set ix 0} {$ix < [llength $lmVals(lmFeaturesTotal)]} {incr ix} {
                set feature [lindex $lmVals(lmFeaturesTotal) $ix]
                set featureName [lindex $feature 0]
                set fHostAllocated 0

                for {set ixf 0} {$ixf < $numberOfFeatures} {incr ixf} {

                    # only if the feature is previously allocated on this host
                    # (name match), display that feature name
 
                    if { $featureName == [lmLicProdInfoGet prodName $lmVals(lmHostName) $ixf] } {
                        set fHostAllocated \
                            [lmLicProdInfoGet licNLAllocated $lmVals(lmHostName) $ixf]
                    }
                }
                if { $fHostAllocated != 0 } {
                    set line [format "%s\r\n" [lindex $lmVals(lmLicensedProductNames) $ix]]
                    append output $line
                }
            }

        } else { # otherwise, display features selected

            for {set ix 0} {$ix < [llength $lmVals(lmLicensedProductNames)]} {incr ix} {
                if {[lindex $lmVals(lmFeaturesRequested) $ix] == 1} {
                    set line [format "%s\r\n" [lindex $lmVals(lmLicensedProductNames) $ix]]
                    append output $line
                }
            }
        }

        controlPropertySet licConfirmDlg.nodelockSummaryTable -columnwidths {180} 
        controlValuesSet licConfirmDlg.nodelockSummaryTable $output
    }
}


#############################################################################
#
# licenseConfirm() - Display License Summary
#
# This procedure will display license summary
#
# SYNOPSIS
# .tS
# licenseConfirm()
# .tE
#
# PARAMETERS: N/A
#
# RETURNS:  1 if ok or 0 if cancel
#
# ERRORS: N/A
#
proc licenseConfirm {} {
    global ctrlVals setupVals lmVals lmHostFeaturesNum

    set ctrlVals(dlgRetVal) 0

    if { $setupVals(lmInstType) == "floating" } {
        set isFloatLic 1
    } else {
        set isFloatLic 0
    }

    set hostIndex [lsearch $lmVals(lmHosts) $lmVals(lmHostName)]

    if { [isGUImode] } {
 
        # Automation: skip display summary and populate autoSetupLog

        if { $ctrlVals(useInputScript) } {
            set ctrlVals(dlgRetVal) 1

            if {$lmVals(reload)} {
                autoSetupLog "Reload Existing License File Summary Page: skipped"
                autoSetupLog "[strTableGet LICCFG_DLGRLD_1]"

            } elseif {$lmVals(lmLicMode) == "floating"} {
                autoSetupLog "Floating License Configuration Summary Page: skipped"
                autoSetupLog "[strTableGet LICCFG_DLGMSG_1]"

            } else {
                autoSetupLog "NodeLocked License Configuration Summary Page: skipped"
                autoSetupLog "[strTableGet LICCFG_NODELOCK_DLGMSG_1]"
            } 

            # display values

            set hostIndex [lsearch $lmVals(lmHosts) $lmVals(lmHostName)]
            if {$hostIndex == -1} {
                set numberOfFeatures 0
            } else {
                set numberOfFeatures [lindex $lmHostFeaturesNum $hostIndex]
            }

            for {set ix 0} {$ix < [llength $lmVals(lmFeaturesTotal)]} {incr ix} {
                set feature [lindex $lmVals(lmFeaturesTotal) $ix]
                set featureName [lindex $feature 0]
                set fHostAllocated 0

                for {set ixf 0} {$ixf < $numberOfFeatures} {incr ixf} {

                    # only if the feature is previously allocated on
                    # this host (name match), retrieve allocated value

                    if { $featureName == [lmLicProdInfoGet prodName $lmVals(lmHostName) $ixf] } {
                        set fHostAllocated \
                            [lmLicProdInfoGet licAllocated $lmVals(lmHostName) $ixf]
                    }
                }


                if {$lmVals(reload)} {
                    autoSetupLog "\t$featureName: $fHostAllocated license(s) \
                                  after this transaction"

                } elseif {$lmVals(lmLicMode) == "floating"} {
                    autoSetupLog "\t$featureName: \
                                  [expr [lindex $lmVals(lmFeaturesRequested) $ix] + \
                                  $fHostAllocated] license(s) after this transaction"

                } else { # Node Locked
                    autoSetupLog "\t$featureName"
                }
            }
        } else { # create Summary page
 
            if {$lmVals(reload)} {
                set dlgTitle "Summary: Reload Existing License File"
                set dlgControls [list \
                        [list label -title [strTableGet LICCFG_DLGRLD_1] \
                                   -x 10 -y 10 -w 200 -h 25]]
            } elseif {$isFloatLic} {      
                set dlgText ""
               
                if {$setupVals(ELMUser) == 1} {
                    set dlgTitle "Summary"
                    set dlgText [strTableGet LICCFG_DLGMSG_ELM_1]
                } else {
                    set dlgTitle "Summary: Floating License"
                    set dlgText [strTableGet LICCFG_DLGMSG_1]
                }
                set dlgControls [list \
                        [list label -title $dlgText \
                                    -x 10 -y 10 -w 200 -h 25]]
            } else {
                set dlgTitle "Summary: Node Locked License"
                set dlgControls [list \
                        [list label -title [strTableGet LICCFG_NODELOCK_DLGMSG_1] \
                                    -x 10 -y 10 -w 200 -h 25]]
            }
    
            if {$isFloatLic} {
                lappend dlgControls \
                        [list button -name okbutt -title "OK" \
                                     -x 50 -y 135 -w 50 -h 15 \
                                     -callback {onLicConfirmDlg 1} ] \
                        [list button -name cancelButt -title "Cancel" \
                                     -x 120 -y 135 -w 50 -h 15 \
                                     -callback {onLicConfirmDlg 0} ] \
                        [list label -name sumCol1 \
                                    -title [strTableGet LICCFG_SUMMSG_1] \
                                    -x 10 -y 40 -w 60 -h 12] \
                        [list label -name sumCol2 \
                                    -title [strTableGet LICCFG_SUMMSG_2] \
                                    -x 100 -y 37 -w 69 -h 23] \
                        [list table -name floatSummaryTable \
					        -columns 2 -border \
					        -x 10 -y 57 -width 190 -height 62]
            } else {
                lappend dlgControls \
                        [list button -name okbutt -title "OK" \
                                                             -x 50 -y 135 -w 50 -h 15 \
                                                 -callback {onLicConfirmDlg 1} ] \
                        [list button -name cancelButt -title "Cancel" \
                                             -x 120 -y 135 -w 50 -h 15 \
                                                 -callback {onLicConfirmDlg 0} ] \
                        [list table -name nodelockSummaryTable \
					        -columns 1 -border \
					        -x 10 -y 38 -width 190 -height 81]

 
             }

             # create the dialog box
             dialogCreate \
                    -name licConfirmDlg \
                    -init licConfirmDlgInit \
                    -parent $ctrlVals(mainWindow) \
                    -title $dlgTitle\
                    -width 220 -height 160 \
                    -controls $dlgControls 

        }

    } else { # text mode

        # find the maximum width of the product names

        set nameWidth [string length "Licensed Product"]
        foreach name $lmVals(lmLicensedProductNames) {
            if { [string length $name] > $nameWidth } {
                set nameWidth [string length $name]
            }
        }

        # print summary page text

        if {$lmVals(reload)} {

            printPageTitle "[strTableGet LICCFG_TITLE_RELOAD]: Summary"
            puts "[strTableGet LICCFG_DLGRLD_1]\n"

            puts [format "%-*s     %s" $nameWidth "Licensed Product" "Total licenses after"]
            puts [format "%-*s     %s\r\n" $nameWidth "" "  this transaction "]

        } elseif {$isFloatLic} {

                printPageTitle "[strTableGet LICCFG_TITLE_FLOATING]: Summary"
            puts "[strTableGet LICCFG_DLGMSG_1]\n\n"

            puts [format "%-*s     %s" $nameWidth "Licensed Product" "Total licenses after"]
            puts [format "%-*s     %s\r\n" $nameWidth "" "  this transaction "]

        } else { # NODELOCK

            printPageTitle "[strTableGet LICCFG_TITLE_NODELOCKED]: Summary"
            puts "[strTableGet LICCFG_NODELOCK_DLGMSG_1]\n" 

        }

        # display values

        set hostIndex [lsearch $lmVals(lmHosts) $lmVals(lmHostName)]
        if {$hostIndex == -1} {
            set numberOfFeatures 0
        } else {
            set numberOfFeatures [lindex $lmHostFeaturesNum $hostIndex]
        }

        for {set ix 0} {$ix < [llength $lmVals(lmFeaturesTotal)]} {incr ix} {
            set feature [lindex $lmVals(lmFeaturesTotal) $ix]
            set featureName [lindex $feature 0]
            set fHostAllocated 0

            for {set ixf 0} {$ixf < $numberOfFeatures} {incr ixf} {

                # only if the feature is previously allocated on this host
                # (name match), retrieve allocated value

                if { $featureName == [lmLicProdInfoGet prodName $lmVals(lmHostName) $ixf] } {
                    set fHostAllocated \
                        [lmLicProdInfoGet licAllocated $lmVals(lmHostName) $ixf]
                }
            }

            if {$lmVals(reload)} {

                puts [format "%-*s             %4s" $nameWidth $featureName $fHostAllocated]

            } elseif {$isFloatLic} {     

                puts [format "%-*s             %4s" $nameWidth $featureName\
                      [expr [lindex $lmVals(lmFeaturesRequested) $ix] + $fHostAllocated]]

            } else { # NODELOCK

                if {[lindex $lmVals(lmFeaturesRequested) $ix] == 1} {
                    puts [format "%s\r\n" $featureName]
                }

            }
        }

        if {$lmVals(reload)} {
            set msg "\nPress <Enter> to continue."
        } else {
            set msg "\nPress <Enter> to continue or type '-' to change the settings."
        }

        set ret [prompt $msg]
        switch -regexp -- $ret {
            "^$"  {  set ctrlVals(dlgRetVal) 1  }
            "^-$" {  set ctrlVals(dlgRetVal) 0  } 
            "[eE][xX][iI][tT]" {
                puts "You must return to the previous page before exiting."
                while {[prompt "Press <Enter> to return to previous page."] != "" } {
                }
            }
            default {
                set ctrlVals(dlgRetVal) -1
            }
        }
    }

    return $ctrlVals(dlgRetVal)
}

#############################################################################
#
# onLicConfirmDlg(val) - process licenseConfirm dialog
#
# This procedure will process licenseConfirm dialog
#
# SYNOPSIS
# .tS
# onLicConfirmDlg(val)
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: n/a
#
# ERRORS: N/A
#
proc onLicConfirmDlg {val} {
    global ctrlVals


    # 1 if ok, 0 if cancel
    set ctrlVals(dlgRetVal) $val
    windowClose licConfirmDlg
    
}

#############################################################################
#
# isLMFeaturesRequestedNull - checks if the no. of licenses requested is null
#
# This procedure determines if all the license requested are null. 
#
# SYNOPSIS
# .tS
# isLMFeaturesRequestedNull
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: n/A
#
# ERRORS: N/A
#
proc isLMFeaturesRequestedNull {} {
    global lmVals setupVals
    set isNull 0
    set input ""

    if { $setupVals(lmInstType) == "floating" } {
        set isFloatLic 1
    } else {
        set isFloatLic 0
    }

    if { [isGUImode] } {

        if { $isFloatLic } {
            for {set ix 0} {$ix < [llength $lmVals(lmLicensedProductNames)]} {incr ix} {
                if { [controlValuesGet wizardDialog.textRequested] == "" } {
                    set isNull 1
                }
            }
        } else {
	    # nodelocked - don't need to determine with radio buttons

	    set isNull 0
        }
    } else { # TEXT MODE

        if { $isFloatLic } {
            for {set ix 0} {$ix < [llength $lmVals(lmFeaturesRequested)]} {incr ix} {
                if { [lindex $lmVals(lmFeaturesRequested) $ix] == "" } {
                    set isNull 1
                }
            }
        } else {
            set isNull 1

            for {set ix 0} {$ix < [llength $lmVals(lmFeaturesRequested)]} {incr ix} {
                if { [lindex $lmVals(lmFeaturesRequested) $ix] != 0 } {
                    set isNull 0
                }
            }
        }
    }

    return $isNull
}

#############################################################################
#
# floatingLicRequestedUpdate 
#
# This procedure does the work for the floating license text box callback
# procedures.  It updates the lmVal(lmFeaturesRequested) array and controls
# enabling or disabling of the Next button.
#
# SYNOPSIS
# .tS
# floatingLicRequestedUpdate index
# .tE
#
# PARAMETERS: N/A
# index - the index or order in which the licensed product is displayed
#
# RETURNS: n/a
#
# ERRORS: N/A
#
proc floatingLicRequestedUpdate {ix} {
    global ctrlVals lmVals setupVals
    global returnValue lmHostFeaturesNum

    if { [isGUImode] } {
        set input [controlValuesGet wizardDialog.textRequested]
        if {[isNumeric $input "License Count Input Error" wizardDialog.textRequested]} {

            # check if value entered exceeds number to allocate

            set featureName [lindex $lmVals(lmLicensedProductNames) $ix]
            set featureAllocated [lmFeaturesValueGet lmFLFeaturesAllocated $featureName]
            set featureTotal [lmFeaturesValueGet lmFLFeaturesTotal $featureName]

            if { $input <= [expr $featureTotal - $featureAllocated] } { 
                set lmVals(lmFeaturesRequested) \
                        [lreplace $lmVals(lmFeaturesRequested) $ix $ix $input]
                if {$input >= 0} {
                    # update the table display for the feature

                    licTableUpdate $ix $input
                }
            } else {

                if { $ctrlVals(useInputScript) } {

                    # if error during automation, exit SETUP

                    autoSetupLog "ERROR: the number of licenses exceeds the\
                                 the number available for this feature."
                    autoSetupLog "Application Exit\n"
                    set setupVals(cancel) 1
                    applicationExit
                    return 0

                } else {

                    dialog ok_with_title "Floating License Configuration Error" \
                                         [strTableGet REQ_INPUT_EXCEEDED]

                    controlValuesSet wizardDialog.textRequested ""
                    return 0
                 }
            }

        }

        if {[isLMFeaturesRequestedNull]} {
            controlEnable wizardDialog.nextButt 0
        } else {
            controlEnable wizardDialog.nextButt 1
        }

    } else { # TEXT MODE

        set name [lindex $lmVals(lmLicensedProductNames) $ix]

        puts "Enter the number of licenses for $name: \n"
        set ret [prompt]
        switch -regexp -- $ret {
            "^-$" {  }
            "^[eE][xX][iI][tT]$" {  }
            "[ ]+" {
                puts "Error: Invalid input."
                while {[prompt "Press <Enter> to continue."] != "" } {
                }
             }
            "^[0-9]+" { 
                set lmVals(lmFeaturesRequested) \
                        [lreplace $lmVals(lmFeaturesRequested) $ix $ix $ret]
            }
            default {
                puts "Error: Invalid input."
                while {[prompt "Press <Enter> to continue."] != "" } {
                }
            }
        }
    }
}

#############################################################################
#
# nodelockLicRequestedUpdate
#
# This procedure does the work for the nodelocked license text box callback
# procedures.  It updates the lmVal(lmFeaturesRequested) array and controls
# enabling or disabling of the Next button.
#
# SYNOPSISlmLicProdInfoGet
# .tS
# nodelockLicRequestedUpdate index
# .tElmLicProdInfoGet
#
# PARAMETERS: 
# index - the index or order in which the licensed product is displayed
#
# RETURNS: n/a
#
# ERRORS: N/A
#
proc nodelockLicRequestedUpdate {ix} {
    global ctrlVals setupVals lmVals

    if { [isGUImode] } {
        if {[controlChecked wizardDialog.yesChoice] == 1} {
            set lmVals(lmFeaturesRequested) \
                [lreplace $lmVals(lmFeaturesRequested) $ix $ix 1]
        } else {
            set lmVals(lmFeaturesRequested) \
                [lreplace $lmVals(lmFeaturesRequested) $ix $ix 0]
        }

        licTableUpdate $ix [controlChecked wizardDialog.yesChoice]

        if {[isLMFeaturesRequestedNull]} {
            controlEnable wizardDialog.nextButt 0
        } else {
            controlEnable wizardDialog.nextButt 1
        }

    } else { # text mode
        set oldValue [lindex $lmVals(lmFeaturesRequested) $ix]
        
        if { $oldValue == 1 } {
            set lmVals(lmFeaturesRequested) \
                    [lreplace $lmVals(lmFeaturesRequested) $ix $ix 0]
        } else {
            set lmVals(lmFeaturesRequested) \lmLicProdInfoGet
                    [lreplace $lmVals(lmFeaturesRequested) $ix $ix 1]
        }

        # check for at least one license is done in pageCreate
    }

}


#############################################################################
#
# lmValsPopulate - fill the remaining values for lmVals for this host
#
# This procedure fills the values pertaining for the current host in the
# lmVals data structure. The data that is populated are:
#       lmLicensedProductNames
#       lmLicensedFeatureIds
#       lmFeaturesAllocated
#       lmPort
#
# SYNOPSIS
# .tS
# lmValsPopulate currHost
# .tE
#
# PARAMETERS: 
# currHost - the current host or host passed
#
# RETURNS: n/a
#
# ERRORS: N/A
#

proc lmValsPopulate {lmHost} {
    global setupVals lmVals lmHostRecs lmHostRecsLen 
    global lmHostFeaturesNum licServPort

    set lmVals(lmLicMode) $setupVals(lmInstType)
    set index [lsearch $lmVals(lmHosts) $lmHost]
    set lmVals(lmPort) [lindex $lmVals(lmHostPorts) $index]
    set numFeatures [lindex $lmHostFeaturesNum $index]
    set maxAvail 0

    # licServPort will be use in licServerPort page

    set licServPort $lmVals(lmPort)

    # fill in info for all features: num available, allocated, requested (potentially)

    for {set ix 0} {$ix < [llength $lmVals(lmFeaturesTotal)]} {incr ix} {
        set numAllocated 0
        set numFLAllocated 0
        set numNLAllocated 0
        set featureName [lindex [lindex $lmVals(lmFeaturesTotal) $ix] 0]

        lappend lmVals(lmLicensedProductNames) $featureName
        lappend lmVals(lmLicensedFeatureIds) [lmTotalInfoGet featureId $ix]

        # for each hosts that has been configured previously

        for {set ixh 0} {$ixh < [llength $lmVals(lmHosts)]} {incr ixh} {

            # get the host name
            set hName [lmLicHostInfoGet hostName $ixh]
            
            # Go through ALL the hosts and sum up the total number
            # of features allocated for EACH feature

            set numberOfFeatures [lindex $lmHostFeaturesNum $ixh]

            for {set ixf 0} {$ixf < $numberOfFeatures} {incr ixf} {
                if {$featureName == [lmLicProdInfoGet prodName $hName $ixf]} {
                    set numFLAllocated \
                        [expr $numFLAllocated + \
                        [lmLicProdInfoGet licFLAllocated $hName $ixf]]
                    set numNLAllocated \
                        [expr $numNLAllocated + \
                        [lmLicProdInfoGet licNLAllocated $hName $ixf]]
                    set numAllocated \
                        [expr $numAllocated + \
                        [lmLicProdInfoGet licAllocated $hName $ixf]]
                }
            }
        }

        lappend lmVals(lmFeaturesAllocated) [list $featureName $numAllocated]
        lappend lmVals(lmFLFeaturesAllocated) [list $featureName $numFLAllocated]
        lappend lmVals(lmNLFeaturesAllocated) [list $featureName $numNLAllocated]

        # Calculate features available
        set featureTotal [lmFeaturesValueGet lmFeaturesTotal $featureName]
        set maxAvail [expr $featureTotal - $numAllocated]
        lappend lmVals(lmFeaturesAvailable) [list $featureName $maxAvail]
        
        set FLFeatureTotal [lmFeaturesValueGet lmFLFeaturesTotal $featureName]
        set FLMaxAvail [expr $FLFeatureTotal - $numFLAllocated]
        lappend lmVals(lmFLFeaturesAvailable) [list $featureName $FLMaxAvail]

        set NLFeatureTotal [lmFeaturesValueGet lmNLFeaturesTotal $featureName]
        set NLMaxAvail [expr $NLFeatureTotal - $numNLAllocated]
        lappend lmVals(lmNLFeaturesAvailable) [list $featureName $NLMaxAvail]

        # set default number of licenses to request

        if { $setupVals(lmInstType) == "floating" } {

            # initialize lmFeaturesRequested to max no. of licenses available
            lappend lmVals(lmFeaturesRequested) $maxAvail
            lappend lmVals(lmFLFeaturesRequested) $FLMaxAvail
        } else { # NODELOCK
            if {$maxAvail > 0} {
                lappend lmVals(lmFeaturesRequested) 1
            } else {
                lappend lmVals(lmFeaturesRequested) 0
            }

            if {$NLMaxAvail > 0} {
                lappend lmVals(lmNLFeaturesRequested) 1
            } else {
                lappend lmVals(lmNLFeaturesRequested) 0
            }
       }
    }

    dbgputs "lmFeaturesTotal: $lmVals(lmFeaturesTotal)"
    dbgputs "lmFeaturesAllocated: $lmVals(lmFeaturesAllocated)"
    dbgputs "lmFLFeaturesAllocated: $lmVals(lmFLFeaturesAllocated)"
    dbgputs "lmNLFeaturesAllocated: $lmVals(lmNLFeaturesAllocated)"
    dbgputs "lmFeaturesAvailable: $lmVals(lmFeaturesAvailable)"
    dbgputs "lmFLFeaturesAvailable: $lmVals(lmFLFeaturesAvailable)"
    dbgputs "lmNLFeaturesAvailable: $lmVals(lmNLFeaturesAvailable)"
    dbgputs "lmFeaturesRequested: $lmVals(lmFeaturesRequested)\n\n"
    dbgputs "lmFLFeaturesRequested: $lmVals(lmFLFeaturesRequested)\n\n"
    dbgputs "lmNLFeaturesRequested: $lmVals(lmNLFeaturesRequested)\n\n"
}

######################################################################
# Callback Routines for Additional Licenses to Allocate
#
# All the following callbacks take no parameters, and return nothing
# The values typed into the text controls are stored by these
# routines.
#
######################################################################

proc floatTextCB {} {
    global ctrlVals

    set ix [controlSelectionGet $ctrlVals(mainWindow).licTable]

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
 
    floatingLicRequestedUpdate $ix

    set ctrlVals(inputUpdate) 0
}

proc nodelockChoiceCB {} {
    global ctrlVals
    set ix [controlSelectionGet $ctrlVals(mainWindow).licTable]

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
 
    nodelockLicRequestedUpdate $ix

    set ctrlVals(inputUpdate) 0
}


# check if the current host has been configured with a NL license before
proc hasExistingNL {} {
    global lmVals setupVals 
    
    #dbgputs "lmVals(lmHostName): $lmVals(lmHostName)"
    #dbgputs "lmVals(lmHosts): $lmVals(lmHosts)" 
    
    set warning 0
    
    if {$setupVals(lmInstType) != "nodeLocked"} {
        return 0
    }
    
    set hostIndex [lsearch $lmVals(lmHosts) $lmVals(lmHostName)]
    dbgputs "hostIndex: $hostIndex"
    
    if {$hostIndex == -1} {
        # host does not exists in the db
        return 0
    }
    
    for {set ix 0} {$ix < [llength $lmVals(lmLicensedProductNames)]} {incr ix} {
        set feature [lindex $lmVals(lmLicensedProductNames) $ix]
        
        controlSelectionSet wizardDialog.licTable $ix
        if {[controlChecked wizardDialog.yesChoice]} {
            set featureVals [lindex [controlValuesGet wizardDialog.licTable] $ix]

            # get the third value which is the host allocation
        
            set num [lindex $featureVals 3]

            if {$num > 0} {
                set warning 1
            }
        }
    }
    
    return $warning
}


proc updateToNLRequest {} {
    global lmVals
            
    for {set ix 0} {$ix < [llength $lmVals(lmLicensedProductNames)]} {incr ix} {
        controlSelectionSet wizardDialog.licTable $ix        

        # uncheck the check box and gray it out
        controlCheckSet wizardDialog.noChoice 1 
        
        # set the no. of request to 0
        set lmVals(lmFeaturesRequested) \
                [lreplace $lmVals(lmFeaturesRequested) $ix $ix 0] 
                 
    }
    controlEnable wizardDialog.yesChoice 0
    controlEnable wizardDialog.noChoice 0
}
######################################################################
# Dialog Text Messages
######################################################################

set strTable(LICCFG_TITLE_FLOATING) "Floating License Configuration"

set strTable(LICCFG_TITLE_ELM) "License Configuration"

set strTable(LICCFG_TITLE_NODELOCKED) "Node Locked License Configuration"

set strTable(LICCFG_TITLE_RELOAD) "Reload Existing License File"

set strTable(LICCFG_FLOAT_1) \
        "Please enter the number of floating licenses for this host from\
        the following list of installed product(s):"

set strTable(LICCFG_ELM_1) \
        "Please enter the number of licenses for this host from\
        the following list of installed product(s):"

set strTable(LICCFG_RELOAD_1) \
        "The following chart describes the license allocation that currently\
        exists on this host."

set strTable(LICCFG_COL1) \
        "\n\Licensed\nProduct"

set strTable(LICCFG_COL2) \
        "Total No.\nof licenses\npurchased"

set strTable(LICCFG_COL3) \
        "Total No.\nof licenses\nallocated"

set strTable(LICCFG_COL4) \
        "Existing\nlicenses\non host"

set strTable(LICCFG_COL5) \
        "Licenses\navailable for\nallocation"

set strTable(LICCFG_COL6) \
        "Additional\nlicenses\nto allocate"

set strTable(LICCFG_NODELOCK_COL6) \
        "Request a\nnode locked\nlicense"

set strTable(LICCFG_FLOAT_2) \
        "After configuring floating licenses, click <Next> to continue.\
        NOTE: available licenses once allocated cannot be reconfigured\
        on-line except through WRS license administrators."

set strTable(LICCFG_TABLE_FLOATING) \
        "Select a product above, then enter the number of\
        additional licenses to allocate."

set strTable(LICCFG_TABLE_NODELOCK) \
        "Select a product above, then specify whether to\
        request a node locked license."


set strTable(LICCFG_ELM_2) \
        "After configuring, click <Next> to continue.\
        NOTE: available licenses once allocated cannot be reconfigured\
        on-line except through WRS license administrators."

set strTable(LICCFG_FLOAT_2_TEXT) \
        "Enter the item number for the product for which you would like\
        to request a license or press \<Return\> to accept this\
        configuration."

set strTable(LICCFG_DLGRLD_1) \
        "A license file with the following product(s) will be downloaded\
        to your host.  It will overwrite and replace the existing one."

set strTable(LICCFG_DLGMSG_1) \
                "Additional floating license(s) will be added for the following\
                product(s) served by this host."

set strTable(LICCFG_DLGMSG_ELM_1) \
                "Additional license(s) will be added for the following\
                product(s) served by this host."

set strTable(LICCFG_NODELOCK_DLGMSG_1) \
        "Licenses will be allocated to this host for the following product(s):"

set strTable(LICCFG_NODELOCK_1) \
        "Please select the node locked licenses desired for this host from\
        the following list of installed product(s):"

set strTable(LICCFG_NODELOCK_2) \
        "After configuring node locked licenses, click <Next> to continue."

set  strTable(LICCFG_NODELOCK_2_TEXT) \
        "Enter a list of index numbers separated by spaces for the products\
     for which you would to request a license. Press <Enter> to accept\
     the current settings."

set strTable(LICCFG_RELOAD_2) \
    "After reviewing the configuration chart, please click <Next> to\
     reload the current license file."

set strTable(LICCFG_RELOAD_2_TEXT) \
        "After reviewing the configuration chart, press <Enter> to\
        reload the current license file."

set strTable(LICCFG_SUMMSG_1) \
        "Licensed Product"

set strTable(LICCFG_SUMMSG_2) \
        "Total licenses after\n  this transaction"

set strTable(REQ_INPUT_EXCEEDED) \
        "The value you have entered exceeds the number of license seats\
        that you have available for this feature.  Please re-enter a\
        valid value, or if there are no licenses available please click\
        cancel to exit.  Contact Wind River Sales to purchase additional\
        seats."

set strTable(CANNOT_CREATE_PATH_1) \
        "Setup License Management cannot create the path [destDirGet]/\
        .wind/license.  Please check the permissions on the directory\
        [destDirGet] and then click on the \"Resume\" button to continue.\
          Click on the \"Exit\" button to exit and try again later."

set strTable(CANNOT_CREATE_PATH_1_TEXT) \
        "Setup License Management cannot create the path [destDirGet]/\
        .wind/license.  Please check the permissions on the directory\
        [destDirGet]."

set strTable(LICCFG_BANNER) \
        "Updating license configuration, please wait..."

set strTable(LICCFG_ZERO_ERROR) \
    "ERROR: you must allocate license\(s\) for at least one feature."

set strTable(LICCFG_NO_LIC_ERROR) \
    "SETUP detected that you have either already exhausted all licenses available \
     or you have already configured licensing for all your purchased \
     products. Please go back and check the recapture button to download your previous \
     license file or press Cancel to exit License Management Installation."

set strTable(LICCFG_BETA_MAX_LICENSES) \
    "For Beta testing period, at most 10 license seats per host are allowed.\
     Configuration for more than 10 license seats per host is not allowed."

set strTable(LICCFG_CONFIGURE_LICENSES_WARN) \
    "Warning!  The number of floating seats you install at this time needs to\
     be equal to or less than the number of floating seats on your purchase\
     order.\n\nIf your purchase order has a mixture of node-locked seats and\
     floating seats and you inadvertently install more floating seats than you\
     purchased, Wind River will contact you to reconcile the difference in\
     license type allocation.\n\nPlease review your purchase order before\
     proceeding with this installation to ensure the number of floating seats\
     you are about to install equals or is less than the number of floating\
     seats on your purchase order."
     
set strTable(LICCFG_TO_RELOAD) \
    "One or more of the products for which you have requested a license\
    has already been allocated a license for this host.\n\n\If those\
    previous licenses were node-locked then this request will fail\
    as you cannot have more than one node-locked license for any given\
    product on the same host. In this case, you should instead use the\
    recapture option to recover your previous license file.\n\n\Would\
    you like to recapture your previous license file?\n  - Yes will send\
    a request to recapture your license\n  - No will continue your\
    request for additional licenses\n  - Cancel will back to the\
    license configuration page"
