# PERMISSN.TCL  - Setup procedures for implementing permission wizard page
#
# Copyright 1999-2003 Wind River Systems, Inc
#
# modification history
# --------------------
# 03c,29apr03,bjl  text rewording.
# 03b,23aug02,bjl  catch permission change error (spr 81083).
# 03a,12jun01,j_w  Modified for Tornado 2.2
# 02h,21sep00,j_w  made the $WIND_BASE/.wind permission based on the
#                  permission set by the user
# 02g,31jan00,bwd  Deleted redundant codes and replaced setupVals(cmdMode)
#                  with isGUImode
# 02f,17dec99,clc  change  switch statement patterns
# 02e,23nov99,clc  add text mode executable permissions
# 02d,09nov99,clc  add text mode
# 02c,27oct99,bjl  set permissions for the WIND_BASE directory.  
# 02b,05oct99,j_w  Fixed Title
# 02a,30Sep99,j_w  Modified for T3
# 01d,23jul99,j_w  added text messages
# 01c,01feb99,tcy  moved procs from INSTALL.TCL.
# 01b,30jan99,bjl  added execute permissions (spr 23883, 24552).
# 01a,26jan99,tcy  extracted from INSTW32.TCL.
#

#############################################################################
#
# pageCreate(permission) - display permissions of files after installation
#
# This procedure will display permissions of files after installation
#
# SYNOPSIS
# .tS
# pageCreate(permission)
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc pageCreate(permission) {} {
    global ctrlVals
    global setupVals
    global perVals 

    if {[catch {setupId effective group} gprName]} {
        set gprName "group"
    }

    if {[catch {setupId effective user} usrName]} {
        set usrName "user"
    }

    if ![info exists setupVals(umask)] { umaskGet }


    if { [isGUImode] } {
        set msg0 [strTableGet PERMISSION_MSG_1]
        
        set ctrlVals(ur) "$usrName read"
        set ctrlVals(gr) "$gprName read"
        set ctrlVals(or) "other read"
        set ctrlVals(uw) "$usrName write"
        set ctrlVals(gw) "$gprName write"
        set ctrlVals(ow) "other write"
        set ctrlVals(ux) "$usrName execute"
        set ctrlVals(gx) "$gprName execute"
        set ctrlVals(ox) "other execute"

        set msg0Ctrl [list label -name msg0 -title $msg0 \
                                 -x 100 -y 10 -w 205 -h 64]

        set urCtrl [list boolean -name ur \
                                 -title $ctrlVals(ur) \
                                 -newgroup -auto \
                                 -x 100 -y 80 -w 70 -h 10]

        set grCtrl [list boolean -name gr \
                                 -title $ctrlVals(gr) \
                                 -auto \
                                 -x 100 -y 93 -w 70 -h 10]

        set orCtrl [list boolean -name or \
                                 -title $ctrlVals(or) \
                                 -auto \
                                 -x 100 -y 106 -w 70 -h 10]

        set uwCtrl [list boolean -name uw \
                                 -title $ctrlVals(uw) \
                                 -auto \
                                -x 170 -y 80 -w 70 -h 10]

        set gwCtrl [list boolean -name gw \
                                 -title $ctrlVals(gw) \
                                 -auto \
                                 -x 170 -y 93 -w 70 -h 10]

        set owCtrl [list boolean -name ow \
                                 -title $ctrlVals(ow) \
                                 -auto \
                                 -x 170 -y 106 -w 70 -h 10]

        set uxCtrl [list boolean -name ux \
                                 -title $ctrlVals(ux) \
                                 -newgroup -auto \
                                 -x 240 -y 80 -w 70 -h 10]

        set gxCtrl [list boolean -name gx \
                                 -title $ctrlVals(gx) \
                                 -auto \
                                 -x 240 -y 93 -w 70 -h 10]

        set oxCtrl [list boolean -name ox \
                                 -title $ctrlVals(ox) \
                                 -auto \
                                 -x 240 -y 106 -w 70 -h 10]

        set ctrlVals(volatileFrm) [list $msg0Ctrl $urCtrl \
                                        $grCtrl $orCtrl \
                                        $uwCtrl $gwCtrl $owCtrl \
                                        $uxCtrl $gxCtrl $oxCtrl ]

        set ctrlVals(permissionsw) [dlgFrmCreate [strTableGet PERMISSION_TITLE]]

        controlCheckSet $ctrlVals(permissionsw).ur 1
        controlCheckSet $ctrlVals(permissionsw).uw 1
        controlCheckSet $ctrlVals(permissionsw).ux 1
        controlCheckSet $ctrlVals(permissionsw).gr 1
        controlCheckSet $ctrlVals(permissionsw).gx 1
        controlCheckSet $ctrlVals(permissionsw).or 1
        controlCheckSet $ctrlVals(permissionsw).ox 1
        controlEnable $ctrlVals(permissionsw).ur 0
        controlEnable $ctrlVals(permissionsw).uw 0
        controlEnable $ctrlVals(permissionsw).ux 0

        # test automation

        if { $ctrlVals(useInputScript) } {
            autoSetupLog "Permissions page:"
            autoSetupLog "\tUsing default settings:"
            autoSetupLog "\tuser read: \
                          [controlChecked $ctrlVals(permissionsw).ur]"
            autoSetupLog "\tuser write: \
                          [controlChecked $ctrlVals(permissionsw).uw]"
            autoSetupLog "\tuser execute: \
                          [controlChecked $ctrlVals(permissionsw).ux]"
            autoSetupLog "\tgroup read: \
                          [controlChecked $ctrlVals(permissionsw).gr]"
            autoSetupLog "\tgroup write: \
                          [controlChecked $ctrlVals(permissionsw).gw]"
            autoSetupLog "\tgroup execute: \
                          [controlChecked $ctrlVals(permissionsw).gx]"
            autoSetupLog "\tother read: \
                          [controlChecked $ctrlVals(permissionsw).or]"
            autoSetupLog "\tother write: \
                          [controlChecked $ctrlVals(permissionsw).ow]"
            autoSetupLog "\tother execute: \
                          [controlChecked $ctrlVals(permissionsw).ox]"

            nextCallback

        } else {
            controlFocusSet $ctrlVals(permissionsw).gr
           controlEnable $ctrlVals(permissionsw).backButt 1
        }
    } else { # TEXT mode

        # find the maximum string length among other, usrName and gprName
        if { [string length "other"] > [string length $gprName] && \
            [string length "other"] > [string length $usrName] } {
            set perVals(colWidth) [string length "other"]    
        } elseif {
            [string length $usrName] > \
            [string length $gprName] } {
            set perVals(colWidth) [string length $usrName]
        } else {
            set perVals(colWidth) [string length $gprName]
        }

        # initialize the permission array     
        set perVals(infoList) "ur uw gr gw or ow"
        foreach item $perVals(infoList)  {
            if { $setupVals($item) == 1 } {
                set perVals($item) "x" 
            } else {
                set perVals($item) ""
            }
        }
        set width [expr $perVals(colWidth)] 
        set str [createString - $width]

        while (1) {

            printPageTitle [strTableGet 1460_TITLE_PERMISSION]
            puts "[strTableGet 3160_PERMISSION]\n"
            puts "[strTableGet 3162_PERMISSION]\n"

            puts [format "%4s %10s %-*s %-13s" "item" "    on    " $width \
                       user "   permission" ]
            puts [format "%4s %10s %-*s %-13s" "----" "   ----   " $width \
                       $str "   ----------" ]
            puts [format "%4s %10s %-*s %-13s"     "" "     $perVals(ur)    " \
                       $width $usrName "   read" ]
            puts [format "%4s %10s %-*s %-13s"     "" "     $perVals(uw)    " \
                       $width $usrName "   write" ]
            puts [format "%4s %10s %-*s %-13s"      1 "     $perVals(gr)    " \
                       $width $gprName "   read" ]
            puts [format "%4s %10s %-*s %-13s"      2 "     $perVals(gw)    " \
                       $width $gprName "   write" ]
            puts [format "%4s %10s %-*s %-13s"      3 "     $perVals(or)    " \
                       $width other "   read" ]
            puts [format "%4s %10s %-*s %-13s"      4 "     $perVals(ow)    " \
                       $width other "   write" ]
            puts ""

            set ret [prompt [strTableGet 3165_PERMISSION_QUESTION]]
            switch -regexp -- $ret {
                "^-$"       { backCallback; return 0 }
                "^[0-9]+([ ][0-9]+)*$" { changePermission $ret }
                "^$"        { nextCallback; return 0 }
                "[eE][xX][iI][tT]"      { return 0 }
                default     { }
            }
        }
        nextCallback
        return 0
    }
}

#############################################################################
#
# pageProcess(permission) - process inputs from permission page
#
# This procedure will process permission set by users from the permission page
#
# SYNOPSIS
# .tS
# pageProcess(permission)
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: 1 when successful
#
# ERRORS: N/A
#

proc pageProcess(permission) {} {
    global ctrlVals
    global setupVals
    global infVals

    if { [isGUImode] } {
        beginWaitCursor
        set setupVals(ur) [controlChecked $ctrlVals(permissionsw).ur]
        set setupVals(gr) [controlChecked $ctrlVals(permissionsw).gr]
        set setupVals(or) [controlChecked $ctrlVals(permissionsw).or]
        set setupVals(uw) [controlChecked $ctrlVals(permissionsw).uw]
        set setupVals(gw) [controlChecked $ctrlVals(permissionsw).gw]
        set setupVals(ow) [controlChecked $ctrlVals(permissionsw).ow]
        set setupVals(ux) [controlChecked $ctrlVals(permissionsw).ux]
        set setupVals(gx) [controlChecked $ctrlVals(permissionsw).gx]
        set setupVals(ox) [controlChecked $ctrlVals(permissionsw).ox]

    } else { # TEXT MODE

        # set permissions for the WIND_BASE (destDir) directory.
        
        set setupVals(ux) 1
        set setupVals(gx) 1
        set setupVals(ox) 1
    }

    umaskSet

    # set permissions for the WIND_BASE (destDir) directory.
 
        set windBase [destDirGet]

    if {$setupVals(gr)} {
        catch {exec /bin/chmod g+r $windBase}
                catch {exec /bin/chmod g+r $windBase/.wind}
    } else {
        catch {exec /bin/chmod g-r $windBase}
                catch {exec /bin/chmod g-r $windBase/.wind}
    }
    if {$setupVals(gw)} {
        catch {exec /bin/chmod g+w $windBase}
                catch {exec /bin/chmod g+w $windBase/.wind}
    } else {
        catch {exec /bin/chmod g-w $windBase}
                catch {exec /bin/chmod g-w $windBase/.wind}
    }
    if {$setupVals(or)} {
        catch {exec /bin/chmod o+r $windBase}
                catch {exec /bin/chmod o+r $windBase/.wind}
    } else {
        catch {exec /bin/chmod o-r $windBase}
                catch {exec /bin/chmod o-r $windBase/.wind}
    }
    if {$setupVals(ow)} {
        catch {exec /bin/chmod o+w $windBase}
                catch {exec /bin/chmod o+w $windBase/.wind}
    } else {
        catch {exec /bin/chmod o-w $windBase}
                catch {exec /bin/chmod o-w $windBase/.wind}
    }

    if { [isGUImode] } {
        endWaitCursor
    }

    return 1
}


##############################################################################
#
# umaskGet - getting the user umask value
#
# This routine gets the current umask setting, converts it to file permision
# format.
#
# SYNOPSIS
# umaskGet
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc umaskGet {} {
    global setupVals

    set setupVals(umask) [split [setupUmaskSet [format "%d" 022]] ""]
    setupUmaskSet $setupVals(umask)

    #initialize all to 0
    set setupVals(ur) 0
    set setupVals(uw) 0
    set setupVals(gr) 0
    set setupVals(gw) 0
    set setupVals(or) 0
    set setupVals(ow) 0

    set noRead {7 6 5 4}
    set noWrite {7 6 3 2}

    set user [lindex $setupVals(umask) 1]
    if {[lsearch $noRead $user] == "-1"}  { set setupVals(ur) 1 }
    if {[lsearch $noWrite $user] == "-1"} { set setupVals(uw) 1 }

    set group [lindex $setupVals(umask) 2]
    if {[lsearch $noRead $group] == "-1"}  { set setupVals(gr) 1 }
    if {[lsearch $noWrite $group] == "-1"} { set setupVals(gw) 1 }

    set other [lindex $setupVals(umask) 3]
    if {[lsearch $noRead $other] == "-1"}  { set setupVals(or) 1 }
    if {[lsearch $noWrite $other] == "-1"} { set setupVals(ow) 1 }
}

##############################################################################
#
# umaskSet - sets new umask value
#
# This routine gets the user file permision request, converts it to a umask
# value then set it for the current process.  A global variable fileMode is
# also created in 'chmod' flag syntax for later use.
#
# SYNOPSIS
# umaskSet
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc umaskSet {} {
    global setupVals

    set user  [expr 6 - ( $setupVals(ur)*4 + $setupVals(uw)*2 )]
    set group [expr 6 - ( $setupVals(gr)*4 + $setupVals(gw)*2 )]
    set other [expr 6 - ( $setupVals(or)*4 + $setupVals(ow)*2 )]
    setupUmaskSet [format "%d" 0$user$group$other]

    set plus "+"
    set minus "-"
    set setupVals(fileMode) [format "u%sr,u%sw,g%sr,g%sw,o%sr,o%sw" \
                            [expr $setupVals(ur) == 1 ? \$plus:\$minus] \
                            [expr $setupVals(uw) == 1 ? \$plus:\$minus] \
                            [expr $setupVals(gr) == 1 ? \$plus:\$minus] \
                            [expr $setupVals(gw) == 1 ? \$plus:\$minus] \
                            [expr $setupVals(or) == 1 ? \$plus:\$minus] \
                            [expr $setupVals(ow) == 1 ? \$plus:\$minus]]

}


##############################################################################
#
# setExecutePermissions - sets the execute permissions of a file.
#
# This routine sets the "group" and "other" execute permissions of a file,
# based on the "execute" checkbox settings the user has selected on the
# File Permissions page for Unix.  Execute permissions are only changed if
# the file originally has been set for "user" execute.
#
# SYNOPSIS:
# setExecutePermissions <filename>
#
# PARAMETERS:
# <filename>
# The file whose execute permissions are to be changed.
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc setExecutePermissions {filename} {
    global setupVals

    # first make sure the filename exists and it is actually a file.

    if { [file exists $filename] && [file isfile $filename] } {
        set permissions [file attributes $filename -permissions]
        set userPerm [string index $permissions 2]
        set groupPerm [string index $permissions 3]
        set otherPerm [string index $permissions 4]

        # change execute permissions if the file is actually
        # an executable file, i.e. user executable permissions
        # have originally been set.

        if {[expr $userPerm % 2] != 0} {
            # change group permissions to executable, if the "group
            # executable" checkbox was checked in the Permissions
            # page, and if the file was not already set to be group
            # executable.

            if {$setupVals(gx) == 1 && [expr $groupPerm % 2] == 0} {
                set groupPerm [incr groupPerm]
            } elseif {$setupVals(gx) == 0 && \
                      [expr $groupPerm % 2] != 0} {

                # change group permissions to be NOT executable, if the
                # group executable checkbox was NOT checked, but the file
                # was already set to be group executable.

                set groupPerm [expr $groupPerm - 1]
            }

            # change other permissions to executable, if the "other
            # executable" checkbox was checked in the Permissions page,
            # and if the file was not already set to be other executable.

            if {$setupVals(ox) == 1 && [expr $otherPerm % 2] == 0} {
                set otherPerm [incr otherPerm]
            } elseif {$setupVals(ox) == 0 && \
                      [expr $otherPerm % 2] != 0} {

                # change other permissions to be NOT executable, if the
                # other executable checkbox was NOT checked, but the file
                # was already set to be other executable.

                set otherPerm [expr $otherPerm - 1]
            }

            # finally change permissions on the file.

            set newpermissions "00$userPerm$groupPerm$otherPerm"
            catch {file attributes $filename -permissions $newpermissions}
        }
    }
}


##############################################################################
#
# changePermission - this procedure toggles permissions
#
# This procedure toggles permissions
#
# SYNOPSIS:
# .tS
# changePermission
# .tE
#
# PARAMETERS:
# idList - list of permission id's which need to be switch
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc changePermission {idList} {

    global setupVals
    global perVals 

    set count 1
    foreach per "gr gw or ow"  {
        set perList($count) $per
        incr count
    } 

    foreach id $idList {
        if {[array size perList] < $id || $id == 0} {
            puts "Error: [strTableGet 3145_COMP_SELECT_CHANGE_INVALID]"
            while { [prompt "Press <Return> to continue."] != "" } {
            }
            return 0
        } 
    }

    foreach id $idList {
        flipPermission $perList($id) 
    }

    return 1
}
##############################################################################
#
# createString - creates a string of repeated characters
#
# This procedure creates a string of repeated characters.
#
# SYNOPSIS:
# .tS
# createString
# .tE
#
# PARAMETERS:
# char - character to be repeated in the string
# length - length of resulting string
#
# RETURNS:
# str - string of repeated characters
#
# ERRORS: N/A
#

proc createString {char length} {

    set i 0
    set str ""
    while {$i < $length} {
        append str $char
        incr i
    }
    return $str
}

##############################################################################
#
# flipPermission - toggles permission values
#
# This procedure toggles permission values in setupVals and changes the output 
# to be displayed in perVals.
#
# SYNOPSIS:
# .tS
# flipPermission
# .tE
#
# PARAMETERS:
# bit - permission which should be changed (ie: gr, gw, or, ow)
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc flipPermission {bit} {

    global setupVals 
    global perVals 

    if { $setupVals($bit) == "0" } {
        set setupVals($bit) 1
        set perVals($bit) "x"
    } {
        set setupVals($bit) 0
        set perVals($bit) ""
    }
}

######################################################################
# Dialog Text Messages
######################################################################

set strTable(PERMISSION_TITLE) "File Permission Settings"

set strTable(PERMISSION_MSG_1) \
    "Select the file permissions that SETUP should use for the files\
     it installs.\n\nNOTE: These permissions will not apply to the files\
     and directories the user will create when running Tornado. The\
     umask of the user running Tornado will determine the permissions\
     assigned to them."

