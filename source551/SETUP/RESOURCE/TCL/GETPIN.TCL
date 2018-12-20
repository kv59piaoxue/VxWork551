# GETPIN.TCL - Setup procedures for implementing user authorization 
#              wizard page
#
# Copyright 1999 Wind River Systems, Inc
#
# modification history
# --------------------
# 03d,22may02,bwd  SPR 77766: use setupVals(WRS) variable for company name
# 03c,03apr02,wmd  Fix SPR #75050, no need to call Authorize Pin request if
#                  PIN = 0, and add new Flexlm key words to validate license
#                  file.
# 03b,05mar02,bwd  Modified SETUP to be non-tornado centric
# 03a,12jun01,j_w  Added for Tornado 2.2
# 02g,19dec00,wmd  Change wording for authorization error message.
# 02f,15dec00,wmd  Fix PIN -> Authorization Code for Text mode.
# 02e,15dec00,wmd  Modify comments for where authorization code is printed.
# 02d,23may00,bwd  Modified codes to allow email address beginning with
#                  numbers
# 02c,18may00,bwd  SPR 31003 - set a variable to return to DBQUERY page if
#                  user click cancel while retrieving data from database
# 02b,07feb00,bwd  Added codes for test automation to retrieve values from
#                  input script file
# 02a,04feb00,bwd  TEXT MODE: Fixed the loop to skip prompting for pin if pin
#                  is not required
# 01z,04feb00,wmd  Fix spelling.
# 01y,04feb00,j_w  Initialized lmSavePin to 0
# 01x,04feb00,j_w  Rename page title to Contact Information if no PIN required
# 01w,03feb00,bwd  Added coded to check email address format for GUI mode
# 01v,02feb00,bwd  Removed debug messages
# 01u,02feb00,bwd  Fixed writing of the registry values - use queueExecute to
#                  save all the reg values
# 01t,01feb00,bwd  Added codes for TEXT MODE for new user information
# 01s,31jan00,j_w  Added user's info and fix duplicate code
# 01r,25jan00,j_w  Fixed spacing
# 01r,25jan00,bwd  Fixed the codes to correctly accept input when prompting to
#                  save pin number
# 01q,10jan00,bwd  Deleted the register authCode if the authorization pin
#                  doesnot need to be saved
# 01p,07jan00,bwd  Fixed codes to use saved pin number when press <Enter> on
#                  prompt
# 01o,07jan00,bwd  No Test automation for command line SETUP
# 01n,17dec99,clc  change  switch statement patterns
# 01m,17dec99,clc  change  switch patterns
# 01l,09dec99,clc  Fix error in printing of banner.
# 01k,07dec99,j_w  Add more space for checkbox descriptions
# 01k,02dec99,clc  add text mode
# 01j,30nov99,wmd  Testing..
# 01i,23nov99,wmd  Add wait cursor.
# 01h,17nov99,wmd  Put the nextCallback inside the automation braces.
# 01g,17nov99,bwd  Added sections for automatic LM installation
# 01f,15nov99,wmd  Remove debugging messages.
# 01e,11nov99,wmd  Testing...
# 01d,08nov99,wmd  Further development.
# 01c,03nov99,wmd  Fix to not disable the Back button.
# 01b,02nov99,wmd  Need to enable the next button due to downstream disabling.
# 01a,05Oct99,j_w  written
#

global lmSavePin
set lmSavePin 0

#############################################################################
#
# pageCreate(userAuthorization) - prompts user for authorization code 
#                                 abd sends to
# database application with an authorizePin request.
#
# The page will not advance to the next page unless the PIN number is 
# validated by the database application.
#
# SYNOPSIS
# .tS
# pageCreate(userAuthorization)
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc pageCreate(userAuthorization) {} {
    global ctrlVals setupVals lmVals 
    global AuthorizePinRequest lmSavePin 
    global cancelDBQUERY

    # if user clicks Cancel while retrieving data from
    # Wind River database, return to DBQUERY page
    if { $cancelDBQUERY } {
        set cancelDBQUERY 0
        backCallback
        return 1
    }

    # get user name, phone, email and pin store them in the reg array
    # if test automation, retrieve values from input script
    # otherwise, get values from registry

    foreach key {sysAdminName userPhone userEmail pin} {

        if { ![isStandAlone] } {
            if { $ctrlVals(useInputScript) } {
                set reg($key) $setupVals($key)
            } else {
                if { ![catch {sysRegistryValueRead HKEY_CURRENT_USER \
                                  "Software\\$setupVals(WRS)" "$key"} value] } {
                    set reg($key) $value
                    dbgputs "$key: $reg($key)"
                } else {
                    set reg($key) ""
                }
            }
        } else {
            set reg($key) $setupVals($key)
        }
    }

    # populate sysAdmin from userName
    if {"$reg(sysAdminName)" == ""} {
        set reg(sysAdminName) [userNameGet]
    }
        
    # reset pinNum if pin is not required
    if {!$lmVals(lmPinRequired)} {
        set lmVals(pinNum) 0
    }

    if { $lmVals(lmPinRequired) } {
        set pinMsg [strTableGet USERAUTH_USEPIN_MSG]
        set title [strTableGet USERAUTH_TITLE]
    } else {
        set pinMsg [strTableGet USERAUTH_NOPIN_MSG]
        set title [strTableGet USERAUTH_TITLE_NOPIN]
    }
                
    if { [isGUImode] } {
        # enable bitmap display
        controlHide $ctrlVals(mainWindow).bitmap 0
                
        set ctrlVals(volatileFrm) [list \
                [list label -name label1 \
                            -title $pinMsg \
                            -x 100 -y 10 -w 190 -h 40] \
                [list label -name label1 -title "User/Sys Admin" \
                            -x 100 -y 57 -w 35 -h 15] \
                                [list text -name sysAdminName -border \
                                           -callback {onTextChange sysAdminName sysAdminName} \
                                           -x 140 -y 60 -w 120 -h 12] \
                                [list label -name label2 -title "Phone" \
                                            -x 100 -y 80 -w 35 -h 12] \
                                [list text -name userPhone -border \
                                            -callback {onTextChange userPhone userPhone} \
                                            -x 140 -y 80 -w 120 -h 12] \
                                [list label -name label3 -title "Email" \
                                            -x 100 -y 100 -w 35 -h 12] \
                                [list text -name userEmail -border \
                                           -callback {onTextChange userEmail userEmail} \
                                           -x 140 -y 100 -w 120 -h 12] ]

                if { $lmVals(lmPinRequired) } {
                        lappend ctrlVals(volatileFrm) \
                                        [list label -name label4 -title "Authorization Code"\
                                                    -x 100 -y 120 -w 80 -h 12] \
                                        [list text -name pin -border -callback onPin \
                                                           -x 140 -y 120 -w 60 -h 12] \
                                        [list boolean -name savePin -auto \
                                                      -title [strTableGet SAVE_AUTHCODE] \
                                                                  -callback onSavePin \
                                                                  -x 100 -y 140 -w 180 -h 12] 
        }

        set w [dlgFrmCreate $title]

        controlEnable $w.backButt 1
        controlEnable $w.cancelButt 1
        controlEnable $w.nextButt 1
                
                # get pin from registry 
                if { $lmVals(lmPinRequired) } {
                        controlCheckSet $w.savePin 1
                        controlEnable $w.nextButt 0
                        controlValuesSet $w.pin $reg(pin)
                }

                # get values from registry
                foreach key {sysAdminName userPhone userEmail} {
                        controlValuesSet $w.$key $reg($key)
                }
                
                if { "$reg(sysAdminName)" == "" } {
                        controlFocusSet $w.sysAdminName
                } elseif { "$reg(userPhone)" == "" } {
                        controlFocusSet $w.userPhone
                } elseif { "$reg(userEmail)" == "" } {
                        controlFocusSet $w.userEmail 
                } else {
                        if { $lmVals(lmPinRequired) } {
                                controlFocusSet $w.pin
                        }
                }
                
                
        # automatic LM installation

        if { $ctrlVals(useInputScript) } {
            set lmVals(pinNum) $setupVals(pin)
            autoSetupLog "User Authorization Page: skipped"
                        autoSetupLog "\tUser/Sys Admin: $setupVals(sysAdminName)"
                        autoSetupLog "\tPhone: $setupVals(userPhone)"
                        autoSetupLog "\tEmail: $setupVals(userEmail)"

            if { $lmVals(lmPinRequired) } {
                autoSetupLog "\tPIN: $setupVals(pin)"
            }

            nextCallback
        }

    } else { # text mode

        printPageTitle [strTableGet USERAUTH_TITLE]

        # display message
        puts "$pinMsg\n\n"

        set question "name"
        while {[string compare $question "done"] != 0} {
            switch -exact $question {
                "name"  {                
                    if {"$reg(sysAdminName)" == ""} {
                        set ret [prompt "User/Sys Admin name: "]
                    } else {
                        set ret [prompt "User/Sys Admin name: \
                                 \[$reg(sysAdminName)\]"]
                    }
 
                    switch -regexp -- $ret {
                        "^[eE][xX][iI][tT]$" {  return 0  }
                        "^-$"  { backCallback ; return 0  }
                        "^$" {
                            if { $reg(sysAdminName) != "" } {
                                set setupVals(sysAdminName) $reg(sysAdminName)
                                set question "phone"
                            }
                        }
                        default {
                            set setupVals(sysAdminName) $ret
                            set question "phone"
                        }
                    }
                }
                "phone" {
                    if {"$reg(userPhone)" == ""} {
                        set ret [prompt "Phone: "]
                    } else {
                        set ret [prompt "Phone: \[$reg(userPhone)\]"]
                    }

                    switch -regexp -- $ret {
                        "^[eE][xX][iI][tT]$" {  return 0  }
                        "^-$" { 
                            set question "name"      
                        }
                        "^$" {
                            if { $reg(userPhone) != "" } {
                                set setupVals(userPhone) $reg(userPhone)
                                set question "email"
                            }
                        }
                        default {
                            set setupVals(userPhone) $ret
                            set question "email"
                        }
                    }
                }
                "email" {
                    if {"$reg(userEmail)" == ""} {
                        set ret [prompt "Email: "]
                    } else {
                        set ret [prompt "Email: \[$reg(userEmail)\]"]
                    }

                    switch -regexp -- $ret {
                        "^[eE][xX][iI][tT]$" {  return 0  }
                        "^-$" { 
                            set question "phone"      
                        }
                        "^$" {
                            if { $reg(userEmail) != "" } {
                                set setupVals(userEmail) $reg(userEmail)

                                # if pin not required, proceed to next page

                                if { !$lmVals(lmPinRequired) } {
                                    set question "done"
                                } else {
                                    set question "pin"
                                }
                            }
                        }
                        "^[a-zA-Z].*@.*" {
                            set setupVals(userEmail) $ret

                            # if pin not required, proceed to next page

                            if { !$lmVals(lmPinRequired) } {
                                set question "done"
                            } else {
                                set question "pin"
                            }
                        }
                        default {
                            puts "Error: Invalid email address format.\n"
                            set question "email"
                        }
                    }
                }
                "pin" {
                    if { $lmVals(lmPinRequired) } {
                    
                        # if a pin number has been saved in the registry, use it

                        if { "$reg(pin)" == "" } {
                            set ret [prompt "PIN: "]
                        } else {
                            set ret [prompt "PIN: \[$reg(pin)\]"]
                        }

                        switch -regexp -- $ret {
                            "^[eE][xX][iI][tT]$" {  return 0  }
                            "^-$" { 
                                set question "email"
                            }
                            "^$" {
                                if { $reg(pin) != "" } {
                                    set lmVals(pinNum) $reg(pin)

                                    # send the PIN to the database app. 
                                    # send the AuthorizePinRequest = 4 request

                                    set params "$setupVals(WRSLicense)|$lmVals(pinNum)|$lmVals(token)"
                                    set reply [sendToALD  $AuthorizePinRequest $params]
                                    set reply [string trim $reply]
                    
                                    if {[string compare "OK" $reply] == 0} {
                                        set question "savePin"
                                    } else {
                                        puts [strTableGet USERAUTH_FAILED]
                                        set question "pin"
                                    }
                                } else {
                                    puts "Error: you must enter an Authorization Code.\n"
                                    set question "pin"
                                }
                            }
                            "^[0-9]+" {

                                set lmVals(pinNum) $ret

                                # send the PIN to the database app. 
                                # send the AuthorizePinRequest = 4 request

                                set params \
                                    "$setupVals(WRSLicense)|$lmVals(pinNum)|$lmVals(token)"
                                set reply [sendToALD  $AuthorizePinRequest $params]
                                set reply [string trim $reply]
                    
                                if {[string compare "OK" $reply] == 0} {
                                    set question "savePin"
                                } else {
                                        puts [strTableGet USERAUTH_FAILED]
                                    set question "pin"
                                }
                            }
                            default {
                                puts "Error: Invalid PIN.\n"
                                set question "pin"
                            }
                        }
                    }
                }
                "savePin" {
                    set msg "Would you like save the Authorization Code\
                             for automatic retrieval? \[Y\]"
                    set ret [prompt $msg]
                    switch -regexp -- $ret {
                        "^[eE][xX][iI][tT]$" {  return 0  }
                        "^-$" { 
                            set question "pin"      
                        }
                        "^$" -
                        "^[Yy](es)?" {
                            set lmSavePin 1
                            set question "done"
                        }
                        "^[Nn](o)?" {
                            set lmSavePin 0
                            set question "done"
                        }
                        default {
                            puts "Error: Invalid input.\n"
                            set question "savePin"
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
# onSavePin - callback for savePin boolean
#
# This procedure sets a value to indicate that the user wants to save the
# authorization code in the registry.
#
# SYNOPSIS
# .tS
# onSavePin()
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc onSavePin {} {
    global lmSavePin

    if {[controlChecked wizardDialog.savePin] == 1} {
        set lmSavePin 1
    } else {
        set lmSavePin 0
    }
}

#############################################################################
#
# onPin - callback for pinNum text box
#
# This procedure validates that the entry is all numeric and stores the
# value in lmVals(lmPinNum)
#
# SYNOPSIS
# .tS
# onPin()
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc onPin {} {
    global lmVals 

    isNumeric [controlValuesGet wizardDialog.pin] \
              "User Authorization" wizardDialog.pin

    set lmVals(pinNum) [controlValuesGet wizardDialog.pin]

    if {$lmVals(pinNum) != ""} {
        controlEnable wizardDialog.nextButt 1
    } else {
        controlEnable wizardDialog.nextButt 0
    }
}


#############################################################################
#
# pageProcess(userAuthorization) - process inputs from userAuthorization page
#
# This procedure will process inputs from the userAuthorization page
#
# SYNOPSIS
# .tS
# pageProcess(userAuthorization)
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: 1 when successful, else 0
#
# ERRORS: N/A
#

proc pageProcess(userAuthorization) {} {
    global setupVals ctrlVals lmVals
    global AuthorizePinRequest lmSavePin 

    if { [isGUImode] } {

                # error checking
                foreach var {sysAdminName userPhone userEmail} {
                        if { "$setupVals($var)" == "" } {
                                messageBox [strTableGet USERAUTH_DLG_ERR1]
                                return 0
                        }
                }

        if { ![regexp {^[a-zA-Z0-9].*@.*} $setupVals(userEmail)] } {
            messageBox "Invalid email address format: $setupVals(userEmail)"
            return 0
        }
            if {$lmVals(pinNum) != 0} {
                beginWaitCursor

                # send the PIN to the database app. 
                # send the AuthorizePinRequest = 4 request
                set params "$setupVals(WRSLicense)|$lmVals(pinNum)|$lmVals(token)"
                set reply [sendToALD  $AuthorizePinRequest $params]
                set reply [string trim $reply]

                endWaitCursor

                if {[string compare "OK" $reply] != 0} {
                        pinAuthorizationFailedDlg
                        return 0
                }
            } 
        } 

        if { ![isStandAlone] } {
            # write the pin into registry
            if { $lmSavePin } {

                regValueWriteLog HKEY_CURRENT_USER \
                                "Software\\$setupVals(WRS)" "pin" $lmVals(pinNum)

            } else {

                if {[regValueExists HKEY_CURRENT_USER \
                                "Software\\$setupVals(WRS)" "pin"]} {
                    if {[catch {sysRegistryValueDelete HKEY_CURRENT_USER \
                                "Software\\$setupVals(WRS)" "pin"} err]} {
                        puts "cannot delete registry key, \"pin\": $err"
                    }
                }
            }
        
            # write other user values into registry
            foreach var {sysAdminName userPhone userEmail} {
                    regValueWriteLog HKEY_CURRENT_USER \
                                "Software\\$setupVals(WRS)" "$var" $setupVals($var)
            }
        }

        queueExecute
        
        return 1
}


#############################################################################
#
# pinAuthorizationFailedDlg - displays pin authorization failure
#
# This procedure will display the PIN number authorization failed dialog
#
# SYNOPSIS
# .tS
# pageProcess(userAuthorization)
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: 1 when successful, else 0
#
# ERRORS: N/A
#
proc pinAuthorizationFailedDlg {} {
    set result [dialog resume_exit "User Authorization Failed" \
                        [strTableGet USERAUTH_FAILED]]
    if {$result == 1} {
        quitCallback
    }
}


######################################################################
# Dialog Text Messages
######################################################################

set strTable(USERAUTH_TITLE) "User Authorization"

set strTable(USERAUTH_TITLE_NOPIN) "Contact Information"

set strTable(USERAUTH_NOPIN_MSG) \
        "Please enter your name, phone number and email."

set strTable(USERAUTH_USEPIN_MSG) \
        "Please enter your name, phone number, email and your\
         Authorizaion Code. Your Autorization Code is printed on the\
         Installation Keys form in your [cdromDescGet] shipment."

set strTable(USERAUTH_FAILED) \
        "The Authorization Code you have entered is NOT valid. Please\
        check the Authorization Code on your Installation Keys form and\
        re-enter it. The Installation Key form is shipped with your\
        [cdromDescGet] shipment."

set strTable(SAVE_AUTHCODE) \
        "Save the Authorization Code for automatic retrieval."

set strTable(USERAUTH_DLG_ERR1) \
        "Please enter the requested information."
