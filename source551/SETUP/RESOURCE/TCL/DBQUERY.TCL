# DBQUERY.TCL - Setup procedures for implementing Database Query Permission 
#              wizard page
#
# Copyright 1999-2003 Wind River Systems, Inc
#
# modification history
# --------------------
# 03i,29apr03,bjl  keep track of successful db query (spr 88068).
# 03h,20feb03,bjl  changed licinfo dialogs to wizard page flow; remove 
#                  puf licinfo page if no license servers.
# 03j,14feb03,bjl  modified for ELM page sequences. 
# 03i,05feb03,wmd  Change back to using prodVer for the release set.
# 03h,02feb03,wmd  Need to use setupVals(torVer) for correct releaseSetVersion
#                  number.
# 03g,27jan03,wmd  Modify to use licInfoGetAll2 for ALI.
# 03f,22may02,bwd  SPR 77766: increased the width for more text to be
#                  displayed
# 03e,13may02,wmd  Fix SPR 77291,  fix detail button to mention use with a
#                  docking station.
# 03d,24apr02,j_w  Fixed SPR 76126: able to specify DISK_SERIAL as host id
# 03c,05mar02,bwd  Modified SETUP to be non-tornado centric
# 03b,07may01,j_w  Update text messages
# 03a,02may01,j_w  Display the correct hostId
# 02z,12mar01,wmd  Fix spr 63962, add NIC hostId info for Windows hosts.
# 02y,06nov00,bwd  Remove resetting lmVals(reload) variable because of change
#                  in page flow
# 02x,04nov00,wmd  Fix typos in text explanations.
# 02w,18oct00,j_w  remove tellMeMore button refrence (spr 35340)
# 02v,03oct00,bwd  SPR 31034: removed "Tell Me More" dialog since setup online
#                  help is in place
# 02u,12sep00,bwd  SPR 34383: added a dialog box to display instruction for
#                  End User when encountering DB errors. Change -helpfile to
#                  -nocontexthelp
# 02t,28jun00,bwd  Changed host checking to use windHostTypeGet instead of
#                  env(WIND_HOST_TYPE)
# 02s,31may00,bwd  SPR 31388: removed text DBQUERY_MSG_3 and modified message
#                  display for TEXT mode
# 02r,30may00,bwd  Enable back for reload in TEXT mode
# 02q,26may00,bwd  Enable Back button for reload
# 02p,23may00,bwd  Fixed message
# 02o,22may00,bwd  fixed typo - calPage. Fixed page order when DB errors
#                  occur.
# 02n,22may00,bwd  SPR 31003 - modified to add cancel button to banner 
#                  indicating database transaction.
# 02m,17may00,bwd  SPR 31030 - design change for nodelock to be like floating
#                  license: added lmInstOptions before DBQUERY page and when 
#                  onDenied, go back to lmInstOptions.
# 02l,15may00,bwd  SPR 31030 - added lmInstOptions page list when user selects
#                  "no access to Wind River web site"
# 02k,12may00,wmd  Modify the "Tell Me More" text string for clarity.
# 02j,12may00,wmd  Fix spr # 31201, warn users that internet access is
#                  required.
# 02i,23mar00,bwd  Fixed licInfoGetAllCallBack to match with the new format of
#                  data coming in from CGI. Removed licInfoGetAllText and moved
#                  all TEXT mode codes to licInfoGetAllCallBack. Removed
#                  lmTotalInfoGetByCode. Created new format for lmVals
# 02h,17mar00,j_w  Rewording radiobutton messages
# 02g,14feb00,wmd  Change all references to prodCode to featureId.
# 02f,09feb00,wmd  Fix text mode as well for "Tell Me More".
# 02e,09feb00,wmd  Provide a "Tell Me More" text specifically for end-user
#                  mode.
# 02d,04feb00,wmd  Add text mode error handling.
# 02c,03feb00,j_w  Fix lmExit page problem
# 02b,03feb00,j_w  Initialize lmHostFeaturesNum to zero in licInfoGetAllText
# 02a,03feb00,wmd  Need to initialize lmHostFeaturesNum to zero.
# 01z,31jan00,j_w  Renamed lmVals(PinRequired) to lmVals(lmPinRequired)
# 01y,25jan00,j_w  Populate lmVals at the end of licInfoGetAllCallBack
# 01x,21jan00,j_w  Updated parameter list for sendToALD call
# 01w,06jan00,bwd  No test automation for command line SETUP
# 01v,06jan00,j_w  Fixed DBQUERY_STATEMENT message layout size
# 01u,17dec99,clc  change  switch patterns
# 01t,17dec99,clc  fix missing-close brace
# 01s,14dec99,wmd  Add icon to wait banner.
# 01r,10dec99,j_w  Remove autoInst pageList if licInfoRetVal is 1
# 01q,06dec99,wmd  Fix the error handling to work correctly.
# 01p,03dec99,wmd  Add statement saying that we will not upload any user data.
# 01o,23nov99,wmd  Fix wait cursor.
# 01o,23nov99,clc  add text mode
# 01n,22nov99,wmd  Add lmLicHostIndexGet proc.
# 01m,17nov99,j_w  Disable the back button if reload option is selected in the
#                  current license info page. Reset lmVals(reload) to 0 in
#                  the onDenied option
# 01l,16nov99,wmd  Add record call totalRecs to hold totals.
# 01k,15nov99,j_w  set onGrant to be the default option
# 01j,15nov99,j_w  Removed desired pagelist if onDenied option is selected
# 01i,15nov99,wmd  Add a lmValsInit proc.
# 01h,15nov99,bwd  Added sections for automatic setup installation
# 01g,11nov99,wmd  Add code to parse the licInfoGetAll request reply.
# 01f,05nov99,wmd  Add code to make sure next button is enabled.
# 01e,05nov99,j_w  Fixed Next button
# 01d,03nov99,j_w  Renamed licInfoGetAll to licInfGetAllCallBack 
# 01c,01nov99,j_w  Implemented details of licInfoGetAll
# 01b,30oct99,wmd  Change how it invokes the lmExit page.
# 01a,04Oct99,j_w  written
#

global licInfoRetVal
global cancelDBQUERY

#############################################################################
#
# pageCreate(dbQuery) - Database Query Permission page
#
# SYNOPSIS
# .tS
# pageCreate(dbQuery)
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#


proc pageCreate(dbQuery) {} {
    global ctrlVals env setupVals lmVals
    
    set setupVals(WRSLicense) [setupLicenseNumGet]
    set idType "(MAC)"
   
    set licInfo    "WRS License: $setupVals(WRSLicense)"
    set hostInfo   "Host Name: $setupVals(hostName)"
    set idInfo     "Host ID $idType: $setupVals(hostId)"
    
    if { [isGUImode] } {

        set ctrlVals(volatileFrm) [list \
                    [list label -name message1 \
                                -title [strTableGet DBQUERY_MSG_1] \
                                -x 99 -y 10 -w 197 -h 20] \
                    [list label -name licInfo \
                                -title $licInfo \
                                -x 99 -y 30 -w 190 -h 10] \
                    [list label -name hostInfo \
                                -title $hostInfo \
                                -x 99 -y 40 -w 190 -h 10] \
                    [list label -name idInfo \
                                -title $idInfo \
                                -x 99 -y 50 -w 190 -h 10] \
                    [list label -name message3 \
                                -title [strTableGet DBQUERY_MSG_2] \
                                -x 99 -y 80 -w 195 -h 35] \
                    [list choice -name grant -auto \
                                 -title [strTableGet DBQUERY_GRANT] \
                                 -x 99 -y 120 -w 190 -h 10 \
                                 -callback onGrant] \
                    [list choice -name denied -auto \
                                -title [strTableGet DBQUERY_DENIED] \
                                -x 99 -y 130 -w 190 -h 10 \
                                -callback onDenied] \
                    [list label -name message4 \
                                -title [strTableGet DBQUERY_STATEMENT] \
                                -x 99 -y 145 -w 195 -h 20] ]

        if {![isUnix]} {
            lappend ctrlVals(volatileFrm) \
                [list boolean -name vsnChkBox \
                        -auto \
                        -title "Use Disk Serial Number for host ID" \
                        -x 110 -y 62 -w 130 -h 10 \
                        -callback onSerial]
                        
            lappend ctrlVals(volatileFrm) \
                [list button -name "vsn_details" \
                        -title "Details..." \
                        -x 250 -y 60 -w 40 -h 12 \
                        -callback onVsnDetails]
        }
        
        set w [dlgFrmCreate [strTableGet DBQUERY_TITLE]]

        controlValuesSet $w.nextButt "&Next >"
        controlEnable $w.backButt 1
        controlEnable $w.nextButt 1
        controlEnable $w.cancelButt 1
        controlEnable $w.helpButt 1

        if { [isTornadoProduct] } {
            controlEnable $w.helpButt 1
        } else {
            controlEnable $w.helpButt 0
        }

        controlCheckSet $w.grant 1
	if {![isUnix]} {
            controlCheckSet $w.vsnChkBox 0
	}
        
        # test automation
 
        if { $ctrlVals(useInputScript) } {
            autoSetupLog "Database Query Permission Page: skipped"
            autoSetupLog "\tDB Permission: $setupVals(dbQueryOptions)" 
            nextCallback
        }

    } else { # TEXT mode

        printPageTitle [strTableGet DBQUERY_TITLE]
        puts [strTableGet DBQUERY_MSG_1]
        puts "\n$licInfo\n"
        puts "[strTableGet DBQUERY_MSG_2]\n"
        puts "[strTableGet DBQUERY_STATEMENT]\n"
        puts "Choose 1 - [strTableGet DBQUERY_GRANT]\n"
        puts "       2 - [strTableGet DBQUERY_DENIED]\n"

        set loop 1

        while  { $loop == 1} {
            set ret [prompt "Please enter the number of your selection. \[1\]"]
            switch -regexp -- $ret {
                "1" { 
                    onGrant
                    nextCallback
                    return 0
                }
                "2" { 
                    onDenied 
                    nextCallback
                    return 0
                }
                "^-$" {
                    backCallback
                    return 0
                }
                "[eE][xX][iI][tT]" {
                    return 0
                }
                "^$" { 
                    onGrant
                    nextCallback
                    return 0
                }
                default {
                }
            }
        }           
    } 
}

#############################################################################
#
# pageProcess(dbQuery) - process inputs from dbQuery page 
#
# This procedure will process inputs from dbQueru page
#
# SYNOPSIS
# .tS
# pageProcess(dbQuery)
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: 1 when successful
#
# ERRORS: N/A
#

proc pageProcess(dbQuery) {} {
    global setupVals lmVals ctrlVals
    global licInfoRetVal setupPageList
    global lmHostRecsLen

    # zero out values that are volatile

    lmValsInit

    switch $setupVals(dbQueryOptions) {
        onGrant {

            if { [isGUImode] } {

                # get license information
                set licInfoRetVal 0
                while { $licInfoRetVal == 0 } {
                    # Error occur and retry
                    licInfoGetAllDlgCreate
                }

                # Error occur but don't retry
                # XXXX Need more work here... XXX

                if {$licInfoRetVal == 1} {
                        set outFile ""
                        if { [isUnix] } {
                            set outFile "[destDirGet]/endUserInfo.txt"
                        } else {
                            set outFile "[destDirGet]\\endUserInfo.txt"
                        }

                        messageBox "[strTableGet DBQUERY_ERROR]\n\
                                    \nThe information will be written to\
                                    $outFile for your convenience.\n"

                        if { ![catch {open $outFile "w"} outFile] } {
                            puts $outFile [strTableGet DBQUERY_ERROR]
                        } else {
                            puts "ERROR writing to file: $outFile"
                        }

                        close $outFile
                        set setupVals(cancel) 1                
                        applicationExit
                }

            } else { # TEXT MODE
                # get license information
                set licInfoRetVal 0
                while { $licInfoRetVal == 0 } {
                    # An error occurred, and retry by user
                    licInfoGetAllCallBack
                }

                if { $licInfoRetVal == 1 } {
                    backCallback
                }
            }
              
            if { $licInfoRetVal != 1 } {
                if { [instTypeGet] != "license" } {
                    if {$setupVals(ELMUser) == 1} {
                        set setupVals(lmInstType) "endUser"

                        if {$lmHostRecsLen == 0} {
                            # if no servers, remove the next information    
                            # screen

                            pageRemove lmInfo
                            pageListAdd ELM                            
                        }
                    } else {
                        set setupVals(lmInstType) ""     
                    }
                }
            }
        }
        onDenied {
             if {[instTypeGet] == "license"} {
                 pageListRemove "autoInst"

                 # Return to lmInstOptions page and set to email option
                 set setupVals(lmInstOptions) "onEmail"                                  

                 # return to the lmInstOptions page                
                 return [calcPage lmInstOptions]
             } else {
                 pageListRemove "dbQuery"   
                 
                 # Return to lmAutoManChoice page and set to manual option                
            
                 set setupVals(lmAutoManChoice) "onManual"                                               
                 return [calcPage lmAutoManChoice]
             }
        }
    }

    dbgputs "dbQuery: $ctrlVals(pageList)"
    dbgputs "dbQuery choice: $setupVals(dbQueryOptions)"

    return 1
}

#############################################################################
#
# licInfoGetAllDlgCreate - create dialog box for retrieving customer 
#                          data from WRS website
#
# SYNOPSIS
# .tS
# licInfoGetAllDlgCreate
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc licInfoGetAllDlgCreate {} {
    global ctrlVals
    global setupVals
    global env

    if { [windHostTypeGet] == "x86-linux2" } {
        dialogCreate \
            -name licInfoGetAllDlg \
            -notitle \
            -parent $ctrlVals(parentDialog) \
            -nocontexthelp \
            -width 250 -height 42 \
            -init {
                controlPropertySet licInfoGetAllDlg.message1 -bold 1; \
                windowTimerCallbackSet licInfoGetAllDlg \
                            -milliseconds 200 licInfoGetAllCallBack
            } \
            -controls [list \
                [list label -name "message1" -center \
                            -title [strTableGet DBQUERY_LICINFO_BANNER] \
                            -x 35 -y 10 -w 200 -h 10 ] \
                [list button -name cancel -title "&Cancel" \
                             -callback onCancel \
                             -x 100 -y 23 -w 50 -h 15] ]

    } else {
        dialogCreate \
            -name licInfoGetAllDlg \
            -notitle \
            -parent $ctrlVals(parentDialog) \
            -nocontexthelp \
            -width 250 -height 42 \
            -init {
                controlPropertySet licInfoGetAllDlg.message1 -bold 1; \
                windowTimerCallbackSet licInfoGetAllDlg \
                            -milliseconds 200 licInfoGetAllCallBack
            } \
            -controls [list \
                [list bitmap -name bmp -stretch \
                             -title [cdFileNameGet [file join RESOURCE \
                                BITMAPS SETUPICO.BMP]] \
                             -x 10 -y 5 -w 20 -h 20] \
                [list label -name "message1" -center \
                            -title [strTableGet DBQUERY_LICINFO_BANNER] \
                            -x 35 -y 10 -w 200 -h 10 ] \
                [list button -name cancel -title "&Cancel" \
                             -callback onCancel \
                             -x 100 -y 23 -w 50 -h 15] ]
    }
}

#############################################################################
#
# licInfoGetAllCallBack
#     GUI mode : a call back function for licInfoGetAllDlg
#     TEXT mode: retrieves license information from WRS database
#
# This function retrieves customer license information from WRS database. It 
# parses the license file, populates some lmVals values and calls 
# lmValsPopulate to fill the rest of lmVals values
#
# SYNOPSIS
# .tS
# licInfoGetAllCallBack
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#
proc licInfoGetAllCallBack {} {
    global setupVals lmVals lmTotalRecs 
    global lmHostRecsLen lmHostRecs lmHostFeaturesNum
    global licInfoRetVal lmPurchasedProds lmPackages

    set licInfo ""
    set lmPackages {}

    if { [isGUImode] } {
        windowTimerCallbackSet licInfoGetAllDlg 0 ""
    } else {
        puts "\n[strTableGet DBQUERY_LICINFO_BANNER]"
    }

    set lmVals(successfulDbQuery) 0

    # get license information here
        # send the licInfoGetAllRequest = 5 (ALI2.0)
        # send WRSLicense and Tornado version
        #
        set licInfoGetAllRequest 5
        set parms "$setupVals(WRSLicense)|$setupVals(prodVer)"

    set licInfo [sendToALD $licInfoGetAllRequest $parms]

    if {[isNumeric $licInfo]} {
        # error handling code here ...

        if {$licInfo == 0 || $licInfo == 1} {
            set licInfoRetVal $licInfo
           
            if { [isGUImode] } { windowClose licInfoGetAllDlg }

            return
        }
    }

    set lmVals(successfulDbQuery) 1

    # parse the input into lmVals

    set licInfo [split $licInfo '\n']
    set listLen [llength $licInfo]
    if {[lindex $licInfo [expr $listLen - 1]] == ""} {
        set licInfo [lreplace $licInfo [expr $listLen - 1] [expr $listLen - 1]]
        set listLen [expr $listLen - 1]
    }

    # get the token
    set lmVals(token) [lindex $licInfo 0]

    # get the WRSLicense/projectName field
    set custLicProjName [split [lindex $licInfo 1] "|"]
    set lmVals(WRSLicense) [lindex $custLicProjName 0]
    set lmVals(projName) [lindex $custLicProjName 1]

    # get lmFeaturesTotal info (3rd line)
    set lmTotalRecs [split [lindex $licInfo 2] "|"]
    set lmVals(lmFeaturesTotal) ""

    # populate lmVals(lmFeaturesTotal)
    foreach feature $lmTotalRecs {
        set prod [split $feature ":"]
        set fName [lindex $prod 0]
        set fID [lindex $prod 1]

        # if any feature id is negative then this is an ELM user.

        if {$fID < 0} {
            dbgputs "dbQuery: ELM feature id found: $fID"
            set setupVals(ELMUser) 1
        } 	    		
	
        set fFLTotal [FLSeatsGet $feature]
        set fNLTotal [NLSeatsGet $feature]
        set fTotal [expr $fFLTotal + $fNLTotal]

        set lmVals(lmFeaturesTotal) \
            [lappend lmVals(lmFeaturesTotal) [list $fName $fTotal]]
        set lmVals(lmFLFeaturesTotal) \
            [lappend lmVals(lmFLFeaturesTotal) [list $fName $fFLTotal]]
        set lmVals(lmNLFeaturesTotal) \
            [lappend lmVals(lmNLFeaturesTotal) [list $fName $fNLTotal]]
    }

    # parse the hostRecords, they are of the form:
    # host|hostID|port|feature:featureId:FL-nn:NL-mm|...
    # Stop when we reach a line starting with %, then get the packages
    # and the purchased product records if any

    set packagesIndex [lsearch $licInfo "% Packages"]
    if {$packagesIndex != -1} {
        set lmHostRecs [lrange $licInfo 3 [expr $packagesIndex - 1]]
        set purchasedProdIndex [lsearch $licInfo "% PurchasedProducts"]
        set lmPackages [lrange $licInfo [expr $packagesIndex + 1] \
	   [expr $purchasedProdIndex -1]]
    } else {
        set purchasedProdIndex [lsearch $licInfo "% PurchasedProducts"]
        set lmHostRecs [lrange $licInfo 3 [expr $purchasedProdIndex - 1]]
    }
    set lmPurchasedProds [lrange $licInfo [expr $purchasedProdIndex + 1] $listLen]
    set lmHostRecsLen [llength $lmHostRecs]
    
    set lmHostFeaturesNum {}
    set nextRecIndex 0

    for {set ix 0} {$ix < $lmHostRecsLen} {incr ix} {
        set hostRec [split [lindex $lmHostRecs $ix] "|"]

        # get host information

        lappend lmVals(lmHosts) [lindex $hostRec 0]
        lappend lmVals(lmHostIds) [lindex $hostRec 1]
        lappend lmVals(lmHostPorts) [lindex $hostRec 2]  

        # get the number of features configured for that host

        set hostRecLen [llength $hostRec]
        lappend lmHostFeaturesNum [expr $hostRecLen - 3]
    }

    # Populate lmVals from the return record

    lmValsPopulate $lmVals(lmHostName)
    dbgputs "lmPurchasedProds: $lmPurchasedProds\n\n"
    dbgputs "lmPackages: $lmPackages\n\n"

    set licInfoRetVal ""

    if { [isGUImode] } { 
        windowClose licInfoGetAllDlg 
    } else {
        return 0
    }
}

#############################################################################
#
# onGrant - callback function when the grant option is selected
#
# This procedure is a callback which sets up wizard pages when the grant 
# option is selected
#
# SYNOPSIS
# .tS
# onGrant
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc onGrant {} {
    global setupVals 

    set setupVals(dbQueryOptions) "onGrant"
    
}

#############################################################################
#
# onDenied - callback function when the denied option is selected
#
# This procedure is a callback which sets up wizard pages when the denied 
# option is selected
#
# SYNOPSIS
# .tS
# onDenied
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#  
# ERRORS: N/A
#

proc onDenied {} {
    global setupVals 

    set setupVals(dbQueryOptions) "onDenied"
    
}


proc onSerial {} {
    global ctrlVals setupVals lmVals
    
    set w $ctrlVals(mainWindow) 
    
    
    if {[controlChecked $w.vsnChkBox]} {                                                 
        set id [hostIdGen vsn]
        set idType "(Disk Serial)"
    } else {
        set id [hostIdGen]
        set idType "(MAC)"
    }
    
    set setupVals(hostId) $id
    set lmVals(lmHostId) $id 
    
    set msg "Host ID $idType: $setupVals(hostId)"
       
    controlValuesSet $w.idInfo $msg
}

proc onVsnDetails {} {
    dialog ok_with_title \
        "Disk Serial Information" \
        [strTableGet DBQUERY_VSN_DETAILS]
}


#############################################################################
#
# onCancel - callback function when user clicks cancel while retrieving information
#
# This procedure is a callback when user clicks cancel button while retrieving
# license information from the database
#
# SYNOPSIS
# .tS
# onGrant
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc onCancel {} {
    global cancelDBQUERY
    global lmVals

    if {$lmVals(httpToken) != ""} {
        http_reset $lmVals(httpToken)
        set lmVals(httpToken) ""
    }
    controlEnable wizardDialog.backButt 0
    controlEnable wizardDialog.nextButt 0
    controlEnable wizardDialog.cancelButt 0
    controlEnable wizardDialog.helpButt 0
    windowClose licInfoGetAllDlg
    set cancelDBQUERY 1
}


#############################################################################
#
# lmValsInit - routine to clean out values that are volatile
#
# SYNOPSIS
# .tS
# lmValsInit
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#
proc lmValsInit {} {
    global lmVals

    # clean out values that lmValsPopulate will add 
    
    set lmVals(lmHostIds) {}
    set lmVals(lmHostPorts) {}
    set lmVals(lmLicensedProductNames) {}
    set lmVals(lmLicensedFeatureIds) {}
    set lmVals(lmFeaturesAllocated) {}
    set lmVals(lmFeaturesAvailable) {}
    set lmVals(lmFeaturesRequested) {}

    # new lmVals for ALI 2.0
    set lmVals(lmFLFeaturesAllocated) {}
    set lmVals(lmNLFeaturesAllocated) {}
    set lmVals(lmFLFeaturesAvailable) {}
    set lmVals(lmNLFeaturesAvailable) {}
    set lmVals(lmFLFeaturesRequested) {}
    set lmVals(lmNLFeaturesRequested) {}

}


#############################################################################
#
# lmLicHostIndexGet - gets index to lmHostRecs for hostName
#
# This procedure gets the index in lmHostRecs list for the hostName parameter
#
# SYNOPSIS
# .tS
# lmLicHostInfoGet <attribute> index
#              
# .tE
#
# PARAMETERS: hostName
#
# RETURNS: index
#
# ERRORS: N/A
#

proc lmLicHostIndexGet {hostName} {
    global lmVals       

    set retVal -1
    for {set ix 0} {$ix < [llength $lmVals(lmHosts)]} {incr ix} {
        if {$hostName == [lindex $lmVals(lmHosts) $ix]} {
            set retVal $ix
            break
        }
    }
    return $retVal
}

#############################################################################
#
# lmLicHostInfoGet - gets attributes from lmHostRecs for host related items
#
# This procedure gets attributes from lmHostRecs list for licensed host items
# based on the index value parameter
#
# SYNOPSIS
# .tS
# lmLicHostInfoGet <attribute> index
#              
# .tE
#
# PARAMETERS: attribute index
# where attribute can be one of:
#       hostName        returns the host name corresponding to index
#       hostId          returns the host Id corresponding to index
#       hostPort        returns the host port corresponding to index
# and index is the index into the list
#
# RETURNS: see above
#
# ERRORS: N/A
#

proc lmLicHostInfoGet {attrib index} {
    global lmVals lmHostRecs lmHostRecsLen

    if {$index < 0} {
        puts "Error: index $index invalid"
        return ""
    }

    switch -exact $attrib {
        hostName {
            set rec [lindex $lmHostRecs $index]
            return [parseBarIndex $rec 0]
        }

        hostId {
            set rec [lindex $lmHostRecs $index]
            return [parseBarIndex $rec 1]
        }

        hostPort {
            set rec [lindex $lmHostRecs $index]
            return [parseBarIndex $rec 2]
        }
        
        default {
            puts "Error: no such attribute $attrib in lmHostRecs"
            return ""
        }
    }
}

#############################################################################
#
# isNLSeatAllocated -
#
# This procedure returns if the product passed is licensed as node-locked on
# the host passed
#
# SYNOPSIS
# .tS
# isNLSeatAllocated prodName hostName
# .tE
#
# PARAMETERS: prodName hostName
#
# RETURNS: 1 if node-locked license exists, else 0
#
# ERRORS: N/A
#

proc isNLSeatAllocated {prodName hostName} {
    global lmVals lmHostRecs lmHostRecsLen lmHostFeaturesNum

    # get the record for the correct host
    
    set recIndex [lsearch -exact $lmVals(lmHosts) $hostName]
    if {$recIndex == -1} {
        return "Error: no such $hostName in lmHostRecs"
    }

    set rec [lindex $lmHostRecs $recIndex]
    set rec [split $rec |]
    set featureRecs [lrange $rec 3 [expr 3 + [lindex $lmHostFeaturesNum $recIndex]]]
    set recLen [llength $featureRecs]

    for {set ix 0} {$ix < $recLen} {incr ix} {
        if {$prodName == [lmLicProdInfoGet prodName $hostName $ix]} {
            return [lmLicProdInfoGet licAllocated $hostName $ix]
        }
    }
    return 0
}

#############################################################################
#
# lmLicProdInfoGet
#
# This procedure returns licensed product info corresponding to the host
# and the index into the list of licensed products for that host.
#
# SYNOPSIS
# .tS
# lmLicProdInfoGet <attribute> hostName index
# .tE
#
# PARAMETERS: attribute hostName index
# where attribute can be one of:
#       prodName        returns the product name or feature name
#       featureId        returns the featureId for the product
#       licAllocated    returns the number of license already allocated
#                         for this product on host hostName
#       licFLAllocated  returns the number of floating licenses already
#                         allocated for this product on host hostName
#       licNLAllocated  returns the number of node-lockedlicenses already
#                         allocated for this product on host hostName
#   hostName is the host in question
#   index is the index of the product in featureRecs
# RETURNS: see above
#
# ERRORS: N/A
#

proc lmLicProdInfoGet {attrib hostName index} {
    global lmVals lmHostRecs lmHostRecsLen lmHostFeaturesNum

    # get the record for the correct host
    
    set recIndex [lsearch -exact $lmVals(lmHosts) $hostName]
    if {$recIndex == -1} {
        return "Error: no such $hostName in lmHostRecs"
    }

    set rec [lindex $lmHostRecs $recIndex]
    set rec [split $rec |]
    set featureRecs [lrange $rec 3 [expr 3 + [lindex $lmHostFeaturesNum $recIndex]]]

    switch -exact $attrib {
         prodName {
            set featureRec [lindex $featureRecs $index]
            return  [parseColonIndex $featureRec 0]   
        }

        featureId {
            set featureRec [lindex $featureRecs $index]
            return  [parseColonIndex $featureRec 1]   
        }

        licAllocated {
            set featureRec [lindex $featureRecs $index]
            return [expr [FLSeatsGet $featureRec] + [NLSeatsGet $featureRec]]
        } 

        licFLAllocated {
            set featureRec [lindex $featureRecs $index]
            return [FLSeatsGet $featureRec]
        }

        licNLAllocated {
            set featureRec [lindex $featureRecs $index]
            return [NLSeatsGet $featureRec]
        }

        default {
            puts "Error: no such attribute $attrib in lmHostRecs"
            return ""
        }
    }
}

#############################################################################
#
# FLSeatsGet
#
# This procedure returns the number of floating seats on the host 
#       in the featureRec passed
#
# SYNOPSIS
# .tS
# FLSeatsGet featureRec
# .tE
#
# PARAMETERS: featureRec - the feature record for the host selected
#      featureRec looks like this: feature:featID:FL-##:NL-##
#
# RETURNS: the number of floating seats
#
# ERROR

proc FLSeatsGet {featureRec} {

    set float [parseColonIndex $featureRec 2]
    if {$float == ""} {return 0}
    set float [string range $float 3 end]

    return $float
}

#############################################################################
#
# NLSeatsGet
#
# This procedure returns the number of nodelocked seats on the host in the
#       featureRec passed
#       featureRec looks like this: feature:featID:FL-##:NL-##
#
# SYNOPSIS
# .tS
# NLSeatsGet featureRec
# .tE
#
# PARAMETERS: featureRec - the feature Record for the host selected
#                         
#
# RETURNS: the number of nodelocked seats
#
# ERROR

proc NLSeatsGet {featureRec} {

    set nodeLocked [parseColonIndex $featureRec 3]
    if {$nodeLocked == ""} {return 0}
    set nodeLocked [string range $nodeLocked 3 end]

    return $nodeLocked
}

#############################################################################
#
# lmTotalInfoGet
#
# This procedure returns licensed product info (based on a given index),
# corresponding to the totals that are returned by the database
#
# SYNOPSIS
# .tS
# lmTotalInfoGet <attribute>  index
# .tE
#
# PARAMETERS: attribute hostName index
# where attribute can be one of:
#       prodName        returns the product name or feature name
#       featureId       returns the featureId for the product
#       totAllocated    returns the number of licenses allocated
#                         for this product (NL+FL)
#       totFLAllocated  returns the number of floating licenses
#                         allocated for this product
#       totNLAllocated  returns the number of node-locked licenses
#                         allocated for this product
#
# RETURNS: see above
#
# ERRORS: N/A
#

proc lmTotalInfoGet {attrib index} {
    global lmVals lmTotalRecs

    switch -exact $attrib {
        prodName {
            set totalRec [lindex $lmTotalRecs $index]
            return [parseColonIndex $totalRec 0]
        }

        featureId {
            set totalRec [lindex $lmTotalRecs $index]
            return [parseColonIndex $totalRec 1]   
        }

        totAllocated {
            set totalRec [lindex $lmTotalRecs $index]
            set allocated [expr [FLSeatsGet $totalRec] + [NLSeatsGet $totalRec]]
            return $allocated
        }

        totFLAllocated {
            set totalRec [lindex $lmTotalRecs $index]
            return [FLSeatsGet $totalRec]
        }

        totNLAllocated {
            set totalRec [lindex $lmTotalRecs $index]
            return [NLSeatsGet $totalRec]
        }

        default {
            puts "Error: no such attribute $attrib in lmHostRecs"
            return ""
        }
    }
}

#############################################################################
#
# lmFeaturesValueGet
#
#
# Given feature's name, this procedure retrieves its corresponding value 
# from one of the specified lmVals: 
#   lmFeaturesTotal
#   lmFeaturesAllocated
#   lmFeaturesAvailable
#   lmFLFeaturesTotal
#   lmNLFeaturesTotal
#   lmFLFeaturesAllocated
#   lmNLFeaturesAllocated
#   lmFLFeaturesAvailable
#   lmNLFeaturesAvailable
#
# SYNOPSIS
# .tS
# lmFeaturesValueGet <attribute> prodName
# .tE
#
# PARAMETERS: attribute prodName
# where attribute can be one of:
#   lmFeaturesTotal       returns the total number of licenses for that 
#                         product for all hosts
#   lmFeaturesAllocated   returns the total number of licenses allocated 
#                         for that product for all hosts
#   lmFeaturesAvailable   returns the total number of licenses available
#                         for that product for all hosts
#   lmFLFeaturesTotal     returns total number of floating licenses for all hosts
#   lmNLFeaturesTotal     returns total number of NL licenses for all hosts
#   lmFLFeaturesAllocated returns total # of FL licenses allocated for the product
#   lmNLFeaturesAllocated returns total # of FN licenses allocated for the product
#   lmFLFeaturesAvailable returns total # of FL licenses available for the product
#   lmNLFeaturesAvailable returns total # of NL licenses available for the product
#
#
# RETURNS: see above
#
# ERRORS: N/A
#

proc lmFeaturesValueGet {attrib prodName} {
    global lmVals
    
    set lmList [list lmFeaturesTotal lmFeaturesAllocated \
                     lmFeaturesAvailable lmFLFeaturesTotal lmNLFeaturesTotal \
                     lmFLFeaturesAllocated lmNLFeaturesAllocated \
                     lmFLFeaturesAvailable lmNLFeaturesAvailable]

    if { [lsearch -exact $lmList $attrib] == -1 } {
            puts "Error: no such attribute $attrib in lmVals!"
            return ""
    }

    foreach lm $lmVals($attrib) {
        if { [string match $prodName [lindex $lm 0]] } {
            return [lindex $lm 1]
        }
    }
}

#####################################################################
#
# parseColonIndex - routine which returns the value in colon
#            separated string.
#
# SYNOPSIS
# parseColonIndex string index
#
# PARAMETERS:
#    string - string with colon separated values
#    index  - index to use to fetch value, starting with 0
#
# RETURNS: the value at index, or NULL string
#
# ERRORS: N/A
#

proc parseColonIndex {string index} {

    set retVal ""
    set buf [split $string :]
    set retVal [lindex $buf $index]

    return $retVal
}

#####################################################################
#
# parseBarIndex - routine which returns the value in vertical bar
#            separated string.
#
# SYNOPSIS
# parseBarIndex string index
#
# PARAMETERS:
#    string - string with bar separated values
#    index  - index to use to fetch value, starting with 0
#
# RETURNS: the value at index, or NULL string
#
# ERRORS: N/A
#

proc parseBarIndex {string index} {

    set retVal ""
    set buf [split $string |]
    set retVal [lindex $buf $index]

    return $retVal
}

######################################################################
# Dialog Text Messages
######################################################################
global setupVals

set strTable(DBQUERY_TITLE) "Database Query Permission"

set strTable(DBQUERY_MSG_1) \
        "In order to automate this installation, SETUP will now query\
        Wind River with the following information:"

set strTable(DBQUERY_MSG_2) \
        "Access to the World Wide Web is required to contact the Wind\
        River license database. If you have a restrictive firewall or a\
        proxy server, Automated License Installation is not possible,\
        therefore select \"No.\""

set strTable(DBQUERY_GRANT) \
        "Yes, contact the Wind River web site."

set strTable(DBQUERY_DENIED) \
        "No, do not contact the Wind River web site."

set strTable(DBQUERY_LICINFO_BANNER) \
        "Retrieving license information, please wait..."

set strTable(DBQUERY_ERROR) \
    "License management configuration as an end-user is not complete!\
     \n\nDue to network connection problems or errors received from the\
     license database at Wind River you have chosen to discontinue license\
     management setup.\n\nIf you desire to configure license management\
     manually, an environment variable LM_LICENSE_FILE needs to be set to the\
     name of the license server host. Please ask your system administrator\
     for the server name and set the environment variable to it. The\
     format of LM_LICENSE_FILE value is:\n\nport@server\n\nwhere:\n\"port\"\
     is the port which is set by your system administrator. Port number\
     can be left blank if using the default port (which is 27000).\
     \n\"server\" is the name of the license server host.\n\nIf you do not\
     configure license management manually, then upon invocation of any\
     licensed application, you will be presented with end-user license\
     management screens again."

set strTable(DBQUERY_STATEMENT) \
    "Note: This program will not upload any unauthorized information from\
     your machine."
     
set strTable(DBQUERY_VSN_DETAILS) \
    "This option uses your disk serial number as your host\
     ID instead of your MAC address.\n\nIf you have a laptop\
     with a docking station, and you switch between\
     them, this option is recommended.\n\nFor more information, please\
     see our web site at\
     http://www.windriver.com/corporate/support/license.html"


