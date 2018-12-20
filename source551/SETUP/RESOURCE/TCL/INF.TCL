# inf.tcl - Setup routines to process inf files.
#
# Copyright 1998 Wind River Systems, Inc
#
# Modification history
# --------------------
# 03b,13jul02,wmd  Change setup log message for failure to start service to
#                  say "Unable to confirm..."
# 03a,12jun01,j_w  Modified for Tornado 2.2
# 02a,21jun00,bjl  Added int option to addRegistryLine.
# 01z,31may00,j_w  Enabled the Tornado Registry Service to be re-started right
#                  after removal (SPR 31316)
# 01y,16mar00,bwd  Changed patch checking to support only Solaris 2.7
# 01x,21oct99,bjl  removed parisc-hpux support.
# 01w,13oct99,bjl  process TORNADO.INF for tornado-* products in
#                  searchAndProcessSection.
# 01v,22mar99,bjl  do not write to uninstall log for first reg subkey.
# 01u,19mar99,wmd  Debug message writes to a file instead.
# 01t,08mar98,wmd  added work-around to get setup running on HPUX, don't
#                  redirect output to a file using exec.
# 01s,03mar99,wmd  Place catches around exec calls.
# 01r,24feb99,bjl  fixed default registry values to be empty when no values
#                  are specified.
# 01q,21feb99,bjl  fixed creation of first subkey directly below root key
#                  in the windows registry.
# 01p,01feb99,bjl  replaced ampersandReplace with subspecSpecialCharReplace.
# 01o,08jan99,bjl  replace ampersands in regsub subspecs (fixes spr 24217).
# 01n,09dec98,bjl  enhanced HPUX patch checking to check for list of
#                  patch numbers or use patch description.
# 01m,04dec98,bjl  limit Solaris 2.6 patch checking to 2.6 instead of 2.6.x.
# 01l,11nov98,bjl  added processing of ALLPRODUCTS.INF to
#                  selectedProductsProcessInfFile.
# 01k,27oct98,bjl  added patch checking for HPUX 10, added required
#                  and recommended criteria to patch checking.
# 01j,25sep98,bjl  added required patch checking for Solaris.
# 01i,15sep98,bjl  swapped args and dir position for addIconLine.
# 01h,09sep98,bjl  added os version to filesCopy, account for unix paths.
# 01g,03sep98,bjl  changed inf filenames to uppercase.
# 01f,13aug98,bjl  added infputs wrapper and changed all puts to infputs.
# 01e,13aug98,tcy  added extra argument "args" for linkCreateLog
# 01d,12aug98,tcy  changed function calls in accordance with new OLE-based SETUP
# 01c,11aug98,tcy  unixified
# 01b,04aug98,bjl  added WarningsFile and InstallLast sections, tab cleanup.
# 01a,26jul98,bjl  written.
#

#############################################################################
#
# extractSectionName - extract the section name between the brackets
#
# This procedure will extract the section name between the brackets.
#
# SYNOPSIS
# extractSectionName <bracketedName>
#
# PARAMETERS:
#   bracketedName : a section name in between brackets
#
# RETURNS: the section name without brackets
#
# ERRORS: N/A
#

proc extractSectionName {bracketedName} {
    regexp {[^[]+} $bracketedName extractedName
    regexp {[^]]+} $extractedName extractedName
    return $extractedName
}


#############################################################################
#
# readLine - read the next line with data.
#
# This procedure will read and return the next line from the inf file
# containing valid data.  Blank lines are skipped.
#
# SYNOPSIS
# readLine
#
# PARAMETERS: N/A
#
# RETURNS: sucessfully read line from inf file.
#
# ERRORS: N/A
#

proc readLine {} {
    global infFileId

    set lineRead 0

    # skip over blank lines
    while {$lineRead == 0} {
        set lineRead [gets $infFileId line]
    }

    return $line
}

#############################################################################
#
# openFile - open the inf file for processing.
#
# Opens the inf file specified by <fileName> and sets the global
# inf file id.
#
# SYNOPSIS
# openFile <fileName>
#
# PARAMETERS:
#   fileName : name of the inf file to open.
#
# RETURNS:
#   0 if <fileName> cannot be opened.
#   1 if successful.
#
# ERRORS: N/A
#

proc openFile {fileName} {
    global infFileId

    if [catch {open $fileName r} infFileId] {
        infputs "INF processing: Cannot open INF file $fileName"
        return 0
    }
    return 1
}

#############################################################################
#
# closeFile - closes the inf file being processed
#
# Closes the current inf file being processed, which is specified
# by the global variable infFileId.
#
# SYNOPSIS
# closeFile
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc closeFile {} {
    global infFileId

    close $infFileId
}

#############################################################################
#
# getLineType - returns the line type of the specified line.
#
# Returns whether the line contains a comment, section name, or data.
#
# SYNOPSIS
# getLineType <line>
#
# PARAMETERS:
#   line : a line read from the inf file.
#
# RETURNS:
#   "comment" if the line is a comment (begins with ";")
#   "section_name" if the line contains a section name (begins with "[")
#   "data" for all other cases
#   "end_of_file" if the end of the file has been reached
#
# ERRORS: N/A
#

proc getLineType {line} {
    # end of file does not register as a blank line for readLine
    if {[endOfFile]} {
        return end_of_file
    }

    # get the first character that is not a space or tab
    regexp {[^ \t]} $line firstCharacter

    switch -exact -- $firstCharacter {
        ;       { return comment }
        [       { return section_name }
        default { return data }
    }
}

#############################################################################
#
# endOfFile - returns whether the end of the inf file has been reached.
#
# Returns whether the end-of-file has been reached for the current inf file
# begin processed.
#
# SYNOPSIS
# endOfFile
#
# PARAMETERS: N/A
#
# RETURNS:
#   0 if eof has not been reached
#   1 if eof has been reached
#
# ERRORS: N/A
#

proc endOfFile {} {
    global infFileId

    return [eof $infFileId]
}


#############################################################################
#
# subspecSpecialCharReplace - replace all special characeters within a
#                             string to be used as a regsub subspec.
#
# For a given string that is to be used as a subspec for the regsub
# command, this procedure replaces all special characters within
# the string so that they retain their literal value.
#
# All occurences of slashes are first replaced with four slashes.  Oddly
# for the latest Tcl (8.0), this ensures that a literal slash is preserved
# through the regsub, rather than becoming part of a character
# interpretation.
#
# All occurrences of & are replaced with \&.  A plain & in a subspec is
# replaced with the string that matched the pattern.
#
# SYNOPSIS
# subspecSpecialCharReplace <value>
#
# PARAMETERS:
#   value : a string with possible special characters to be replaced.
#
# RETURNS:
#   A new value in which special characters have been replaced so they
#   retain their literal values during a regsub, if the value is used as a
#   replacement pattern (subspec).
#
# ERRORS: N/A
#

proc subspecSpecialCharReplace {value} {

    regsub -all {\\} $value {\\\\} value
    regsub -all & $value \\\\& value
    return $value
}

#############################################################################
#
# percentEvaluate - evaluates substring values between percent signs.
#
# For a given string, this procedure evaluates and replaces all substrings
# between percent signs.  A new string containing the replaced substrings is
# returned.
#
# The order of evaluation for each substring is as follows:
#   1. the substring is replaced with the value specified in the Strings
#      section of the inf file.
#   2. if the substring is a procedure name, it is replaced with its return
#      value.
#   3. if the substring is a global variable, it is replaced with its value.
#
# SYNOPSIS
# percentEvaluate <value>
#
# PARAMETERS:
#   value : a string with possible substrings between % signs
#
# RETURNS:
#   A new string with substrings between % signs replaced with their
#   evaluated strings.  If a substring between % signs cannot be replaced,
#   the original string is returned.
#
#
# ERRORS: N/A
#

proc percentEvaluate {value} {
    global infString

    while {[regexp {%[^%]+%} $value evaluation_subspec] != 0} {
        regexp {[^%]+} $evaluation_subspec valueToEvaluate

        # check if infString, procedure, or variable exists
        set infStringExists [info exists infString($valueToEvaluate)]
        set functionExists [info procs $valueToEvaluate]

        # allow checking of arrays - check for array variable format
        if {[regexp {[^()]+\([^(]+\)} $valueToEvaluate != 0]} {
            regexp {[^\(]+} $valueToEvaluate arrayName
            global $arrayName
        } else {
            global $valueToEvaluate
        }
        set variableExists [info exists $valueToEvaluate]

        # do the evaluation
        if {$infStringExists == 1} {
            regsub {%[^%]+%} $value [subspecSpecialCharReplace $infString($valueToEvaluate)] value
        } elseif {[string length $functionExists] > 0} {
            regsub {%[^%]+%} $value [subspecSpecialCharReplace [$valueToEvaluate]] value
        } elseif {$variableExists == 1} {
            regsub {%[^%]+%} $value [subspecSpecialCharReplace [set $valueToEvaluate]] value
        } else {
            infputs "INF processing: %$valueToEvaluate% is not specified"
            infputs "in the Strings section, is not a procedure, and is not a"
            infputs "global variable."
            return $value
        }
    }
    return $value
}

#############################################################################
#
# nthValueFromCommaDelimitedLine - returns the nth value of a comma delimited
#                                  list
#
# For a list of values separated by commas, returns the nth value in the
# list.  Whitespace preceding each value is accounted for.  Substrings
# for each value in between % signs are replaced by calling the
# procedure percentEvaluate.
#
#
# SYNOPSIS
# nthValueFromCommaDelimitedLine <line> <index>
#
# PARAMETERS:
#   line : a string of comma delimited values
#   index : specifies the nth value to be returned.  The index starts with
#           1 (the first value in the list).
#
# RETURNS:
#   The nth value specified by <index>.
#   "no_value" if the value specified by index does not exist.
#
# ERRORS: N/A
#

proc nth {line index} {
    return [nthValueFromCommaDelimitedLine $line $index]
}

proc nthValueFromCommaDelimitedLine {line index} {

    # count the number of commas.  If the number is less than
    # the index-1, the index value does not exist.
    set numcommas [regsub -all , $line {} ignore]
    if {$numcommas < [expr $index - 1]} {
        return no_value
    }

    set value [lindex [split $line ,] [expr $index - 1]]

    # remove prefixing spaces or tabs
    regexp "\[^ \t\]+.*" $value value

    if {[string length $value] == 0 } {
        return no_value
    }

    # make sure value does not consist of just spaces or tabs
    if {[regexp "\[^ \t\]+" $value]==0} {
        return no_value
    }

    # evaluate all strings between percent signs
    set value [percentEvaluate $value]

    return $value
}

#############################################################################
#
# checkPossibleRegRootNames - checks that the Registry root name is valid.
#
# Checks that <reg_root_string> is a valid value for the Windows registry.
# If a valid abbreviation, returns the full registry root name.  The
# special case HKEY_LOCAL_MACHINE_CURRENT_USER, used only by the inf routines,
# is allowed.
#
# SYNOPSIS
# checkPossibleRegRootNames <reg_root_string>
#
# PARAMETERS:
#   reg_root_string : a registry root name or abbreviation.
#
# RETURNS:
#   If a valid abbreviation, the full registry root name.
#   <reg_root_string> if valid.
#   "invalid" if reg_root_string is an invalid registry root name.
#
# ERRORS: N/A
#

proc checkPossibleRegRootNames {reg_root_string} {
    switch -exact -- $reg_root_string {
        HKCR {
                return HKEY_CLASSES_ROOT
        }
        HKCU {
                return HKEY_CURRENT_USER
        }
        HKLM {
                return HKEY_LOCAL_MACHINE
        }
        HKU {
                return HKEY_USERS
        }
        HKLMCU {
                return HKEY_LOCAL_MACHINE_CURRENT_USER
        }

        # these values do not have to be changed
        HKEY_CLASSES_ROOT {
                return $reg_root_string
        }
        HKEY_CURRENT_USER {
                return $reg_root_string
        }
        HKEY_LOCAL_MACHINE {
                return $reg_root_string
        }
        HKEY_USERS {
                return $reg_root_string
        }
        HKEY_LOCAL_MACHINE_CURRENT_USER {
                return $reg_root_string
        }

        # invalid registry root names
        no_value {
                infputs "INF processing: no value given for reg-root-string"
                return invalid
        }
        default {
                infputs "INF processing: invalid reg-root-string: $reg_root_string"
                return invalid
        }
    }
}

#############################################################################
#
# addSubKeyToRegistry - adds a subkey to the Window registry
#
# Adds the specified subkey "path" to the Windows registry.  For each subkey
# in the path, the subkey is automatially added to the registry if it does
# not already exist.  Thus full subkey path values can be specified
# for <subkey>, instead of having the user add one subkey value at a time.
#
# For the special case where <reg_root_string> is specified as
# HKEY_LOCAL_MACHINE_CURRENT_USER, if the user is installing under NT and
# has administrator privileges, the subkey will be added to both
# HKEY_LOCAL_MACHINE and HKEY_CURRENT_USER.
#
# SYNOPSIS
# addSubKeyToRegisty <reg_root_string> <subkey> <logValue>
#
# PARAMETERS:
#   reg_root_string : a registry root name or abbreviation.
#   subkey : the subkey "path" to be added to the registry.
#   logValue : specifies whether to write to the log file.
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc addSubkeyToRegistry {reg_root_string subkey logValue} {
    global ctrlVals

    set subkeyList [split $subkey \\]
    set partialKey [lindex $subkeyList 0]

    # save the original value of subkeyList and partialKey
    set original_subkeyList $subkeyList
    set original_partialKey $partialKey


    if {[string compare $reg_root_string HKEY_LOCAL_MACHINE_CURRENT_USER] == 0} {
        if {$ctrlVals(NT) && $ctrlVals(admin)} {
            set reg_root_string_list {HKEY_LOCAL_MACHINE HKEY_CURRENT_USER}
        } else {
            set reg_root_string_list HKEY_CURRENT_USER
        }
    } else {
        set reg_root_string_list $reg_root_string
    }


    foreach reg_root_string $reg_root_string_list {
        # first create the first subkey below reg_root-string
        regKeyCreateLog $reg_root_string "" $partialKey noLog

        # if there is only one subkey, it has just been written.
        if {[llength $subkeyList]==1} {
            return
        }

        # remove the first subkey from the list
        set subkeyList [lrange $subkeyList 1 [expr [llength $subkeyList]-1]]

        # add the remaining subkeys
        foreach key $subkeyList {
            regKeyCreateLog $reg_root_string $partialKey $key $logValue
            append partialKey "\\$key"
        }

        # restore the subkeyList and partialKey for the next iteration
        set subkeyList $original_subkeyList
        set partialKey $original_partialKey
    }
}

#############################################################################
#
# addRegistryLine - adds values extracted from an inf file line to the
#                   registry
#
# Adds the specified value to the Windows Registry.  The subkey is also
# added to the Registry if it does not yet exist.  The format of the
# line read from the inf file is as follows (optional parameters in brackets):
#
#   reg_root_string, subkey, value_name, value, [logValue], [control var]
#
#   reg_root_string : a valid registry root name or abbreviation
#   subkey : the subkey under which the value is to be added.  May be
#            a "path".
#   value_name : name of the value to be added.
#   value : value to be added.
#   [logValue] : specifies whether to write to the setup log file.  "true" by
#                default.  Any other value disables writing to the log.
#   [control var] : conditional control variable allowing value to be written
#                   to the registry.  infVals(control var) must exist and be
#                   set to any value other than 0.
#
# If [control var] is specified, the global variable infVars(control var)
# must exist and be set to a value other than 0.  Otherwise the value will not
# be added to the registry.  This allows for conditional control of adding to
# the registry.
#
# For the special case where <reg_root_string> is specified as
# HKEY_LOCAL_MACHINE_CURRENT_USER, if the user is installing under NT and
# has administrator privileges, the subkey and value will be added to both
# HKEY_LOCAL_MACHINE and HKEY_CURRENT_USER.
#
# SYNOPSIS
# addRegistryLine <line>
#
# PARAMETERS:
#   line : a comma delimited line containing values to be added to the
#          Windows Registry.
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc addRegistryLine {line} {
    global ctrlVals
    global infVals

    set reg_root_string [nthValueFromCommaDelimitedLine $line 1]
    set reg_root_string [checkPossibleRegRootNames $reg_root_string]
    if {[string compare $reg_root_string invalid] == 0} {
        infputs "INF Processing: cannot add values to registry: invalid reg-root-string: $line"
        return
    }
    if {[string compare $reg_root_string no_value] == 0} {
        infputs "INF Processing: no reg_root_string given: $line"
        return
    }

    set subkey [nthValueFromCommaDelimitedLine $line 2]
    set value_name [nthValueFromCommaDelimitedLine $line 3]
    set value [nthValueFromCommaDelimitedLine $line 4]    
    set logValue [nthValueFromCommaDelimitedLine $line 5]
    set controlvar [nthValueFromCommaDelimitedLine $line 6]

    # set default variables
    if {[string compare $logValue no_value]==0} {
        set logValue "true"
    }
    if {[string compare $value_name no_value]==0} {
        set value_name ""
    }
    if {[string compare $value no_value]==0} {
        set value ""
    }

    # check the control variable
    set addregistry 1
    if {[string compare $controlvar no_value] != 0} {
        if {![info exists infVals($controlvar)]} {
            # control variable is specified but does not exist
            set addregistry 0
            infputs "INF Processing: will not add to registry: $line"
            infputs "$controlvar specified but infVals($controlvar) not set"
        } elseif {$infVals($controlvar)==0} {
            # control variable is set to 0
            set addregistry 0
            infputs "INF Processing: will not add to registry: $line"
            infputs "$controlvar specified but infVals($controlvar) = 0"
        }
    }

    # changes for T2.2             
    if {$addregistry != 0} {
        infputs "INF Processing: adding to Registry:"
        infputs "$reg_root_string $subkey $value_name $value"
        addSubkeyToRegistry $reg_root_string $subkey $logValue
        if {[string compare $reg_root_string HKEY_LOCAL_MACHINE_CURRENT_USER] == 0} {
            if {$ctrlVals(NT) && $ctrlVals(admin)} {
                regValueWriteLog HKEY_LOCAL_MACHINE $subkey $value_name $value $logValue              
            }
            regValueWriteLog HKEY_CURRENT_USER $subkey $value_name $value $logValue  
        } else {
            regValueWriteLog $reg_root_string $subkey $value_name $value $logValue  
        }
    }
    
}

#############################################################################
#
# addIconLine - adds icon to a program group from the values read from
#               an inf file line
#
# Adds icon to the specified program group.  The program group is also
# created if it does not yet exist.  The format of the line to be read from
# the inf file is as follows (optional parameters in brackets):
#
#   group, item, exe, args, dir, fmin, iconIndex, iconPath, [logValue], [OS version], [control var]
#
#   group : the program group to add the icon
#   item : the icon name to be added to the program group
#   exe : the executable or file to be linked with the icon
#   args : the arguments for the executable
#   dir : the directory location of the executable or file.
#   fmin :
#   iconIndex :
#   iconPath: the path to the location of the file to be used as the icon bitmap
#   [logValue] : specifies whether to write to the setup log.  "true" by
#                default.  Any other value disables writing to the log.
#   [OS version] : NT3x, NT4x, or WIN95.  Specifies to add the icon only if the
#                  current OS being used for installation is that which is specified.
#                  If no value is specified the icon will be added for any OS.
#   [control var] : conditional control variable allowing icon to be added.
#                   infVals(control var) must exist and be set to any value other
#                   than 0.
#
# If [control var] is specified, the global variable infVars(control var)
# must exist and be set to a value other than 0.  Otherwise the icon will not
# be added.  This allows for conditional control of adding the icon to the
# program group.
#
# If the icon is to be added to the program group specified by the
# user <group> should be specified to be %defGroupGet% in the inf file.
#
# The icon executable directory and iconPath are written in relation to
# the destination directory specified by the user, i.e. the destination
# directory is prepended to the specified directory and iconPath.  The
# setup program itself queries the user for the destination directory.
#
# SYNOPSIS
# addIconLine <line>
#
# PARAMETERS:
#   line : a comma delimited line containing values in which to add an icon
#          to a program group.
#
# RETURNS: N/A
#
# ERRORS: N/A
#


proc addIconLine {line} {
    global ctrlVals
    global infVals

    set group [nthValueFromCommaDelimitedLine $line 1]
    set item [nthValueFromCommaDelimitedLine $line 2]
    set exe [nthValueFromCommaDelimitedLine $line 3]
    set args [nthValueFromCommaDelimitedLine $line 4]
    set dir [nthValueFromCommaDelimitedLine $line 5]
    set fmin [nthValueFromCommaDelimitedLine $line 6]
    set iconIndex [nthValueFromCommaDelimitedLine $line 7]
    set iconPath [nthValueFromCommaDelimitedLine $line 8]
    set logValue [nthValueFromCommaDelimitedLine $line 9]
    set osversion [nthValueFromCommaDelimitedLine $line 10]
    set controlvar [nthValueFromCommaDelimitedLine $line 11]


    set destinationDir [destDirGet]

    # add trailing slash to destinationDir if it does not exist
    set lastCharacter [string index $destinationDir [expr [string length $destinationDir]-1]]
    if {[string compare $lastCharacter \\] != 0} {
        append destinationDir \\
    }

    # set default values
    if {[string compare $fmin no_value]==0} {
        set fmin 0
    }
    if {[string compare $iconIndex no_value]==0} {
        set iconIndex 0
    }
    if {[string compare $logValue no_value]==0} {
        set logValue "true"
    }
    if {[string compare $args no_value]==0} {
        set args ""
    }

    set addicon 0

    # check the os version
    switch -exact -- $osversion {
        no_value { set addicon 1 }
        default {
           if {[string compare $osversion $ctrlVals(version)]==0} {
           set addicon 1
           } else {
               set addicon 0
               infputs "INF Processing: will not add icon $item: osversion does not match OS: $osversion"
           }
        }
    }

    # check the control variable
    if {$addicon == 1} {
        if {[string compare $controlvar no_value] != 0} {
            if {![info exists infVals($controlvar)]} {
                # control variable is specified but does not exist
                set addicon 0
                infputs [array get infVals]
                infputs "INF Processing: will not add icon $item: $controlvar specified but infVals($controlvar) not set"
            } elseif {$infVals($controlvar)==0} {
                # control variable is set to 0
                set addicon 0
                infputs "INF Processing: will not add icon $item: $controlvar specified but infVals($controlvar) = 0"
            }
        }
    }

    if {$addicon == 1} {
        set completeDirName [completeDestinationDirName $dir]

        # create the group
        folderCreateLog $group $ctrlVals(admin) $logValue

        # add the icon
        if {[string compare $iconPath no_value]==0} {
            # iconPath not specified, use default executable for icon
            infputs "INF Processing: \
                  adding Icon: $group $item $exe $args $completeDirName"
            linkCreateLog $group $item "$destinationDir$exe" $args \
                          $completeDirName $ctrlVals(admin) $fmin $iconIndex
        } else {
            infputs "INF Processing: \
                  adding Icon: $group $item $exe $args $completeDirName \
                               $destinationDir$iconPath"
            linkCreateLog $group $item "$destinationDir$exe" $args \
                          $completeDirName $ctrlVals(admin) $fmin \
                          $iconIndex "$destinationDir$iconPath"
        }
    }
}

#############################################################################
#
# completeDestinationDirName - returns a directory path based on
#                              the user selected destination directory
#
# Prepends the destination directory specified by [destDirGet] to
# the directory value.  Slashes are correctly handled.
#
# SYNOPSIS
# completeDestinationDirName <dir>
#
# PARAMETERS:
#   dir : directory path to prepend the destination directory path
#
# RETURNS:
#   directory path with destination directory prepended
#
# ERRORS: N/A
#


proc completeDestinationDirName {dir} {
    set destinationDir [destDirGet]

    # add trailing slash to destinationDir if it does not exist
    set lastCharacter [string index $destinationDir [expr [string length $destinationDir]-1]]
    if {[string compare $lastCharacter \\] != 0} {
        append destinationDir \\
    }

    # remove beginning slash from dir if it exists
    set firstCharacter [string index $dir 0]
    if {[string compare $firstCharacter \\] == 0} {
        set dir [string range $dir 1 [expr [string length $dir]-1]]
    }

    # dir might be equal to no_value.  Set it to an empty string if this is the case.
    if {[string compare $dir no_value]==0} {
        set dir ""
    }

    return "$destinationDir$dir"
}

#############################################################################
#
# fullPathName - returns a full path to the specified executable.
#
# Returns a complete pathname given, including the destination directory
# prepended to the path, given an executable or file and the path to the executable.
#
# SYNOPSIS
# fullPathName <path> <exe>
#
# PARAMETERS:
#   path : directory path to the executable
#   exe : executable or file
#
# RETURNS:
#   complete directory path to the executable, including the destination
#   directory prepended to the path.
#
# ERRORS: N/A
#

proc fullPathName {path exe} {
    set completeDirName [completeDestinationDirName $path]

    set endStringIndex [expr [string length $completeDirName]-1]
    set lastCharacter [string index $completeDirName $endStringIndex]

    # add the trailing slash to completeDirName if it does not exist
    if {[string compare $lastCharacter \\] != 0} {
        append completeDirName \\
    }

    # append the executable name to completeDirName
    append completeDirName $exe
    return $completeDirName
}

#############################################################################
#
# addServiceLine - adds a service to Windows NT from the values read from
#                  a line from an inf file
#
# Adds and starts the specified service if the OS is Windows NT.  If the OS
# is not Windows NT the procedure simply returns.  The format of the line read
# from the inf file is as follows (optional parameters in brackets):
#
#   service name, executable, path, [dependency], [control var]
#
#   service name : name of the service to be added to Windows NT
#   executable : filename of the service executable
#   path : directory path to the executable
#   dependency : any dependencies that must be started before this service
#   [control var] : conditional control variable allowing service to be added.
#                   infVals(control var) must exist and be set to any value other
#                   than 0.
#
# If [control var] is specified, the global variable infVars(control var)
# must exist and be set to a value other than 0.  Otherwise the service will not
# be added.  This allows for conditional control of adding the service.
#
# SYNOPSIS
# addServiceLine <line>
#
# PARAMETERS:
#   line : a comma delimited line containing values to be added as a service to
#          Windows NT.
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc addServiceLine {line} {
    global ctrlVals
    global infVals

    if {$ctrlVals(NT) != 1} {
        infputs "INF Processing: will not add service: OS is not NT"
        return
    }

    set serviceName [nthValueFromCommaDelimitedLine $line 1]
    set serviceExe  [nthValueFromCommaDelimitedLine $line 2]
    set servicePath [nthValueFromCommaDelimitedLine $line 3]
    set dependency  [nthValueFromCommaDelimitedLine $line 4]
    set controlvar  [nthValueFromCommaDelimitedLine $line 5]



    if {[string compare $dependency no_value]==0} {
        set dependency ""
    }
    if {[string compare $servicePath no_value]==0} {
        set servicePath ""
    }

    # check the control variable
    set addservice 1
    if {[string compare $controlvar no_value] != 0} {
        if {![info exists infVals($controlvar)]} {
            # control variable is specified but does not exist
            set addservice 0
            infputs "INF Processing: will not add service $serviceName: $controlvar specified but infVals($controlvar) not set"
        } elseif {$infVals($controlvar)==0} {
            # control variable is set to 0
            set addservice 0
            infputs "INF Processing: will not add service $serviceName: $controlvar specified but infVals($controlvar) = 0"
        }
    }

        if {$addservice != 0} {
        infputs "INF processing: adding service: $serviceName $servicePath $serviceExe $dependency"

        if {![catch {setupServiceInstall $serviceName \
                                [fullPathName $servicePath $serviceExe] $dependency} error]} {
            uninstLog resource "service\t$serviceName"
                        dbgputs "service installed: $serviceName"

        } else {
            # NT service registry data
            set rootKey  HKEY_LOCAL_MACHINE
            set key "SYSTEM\\CurrentControlSet\\Services\\$serviceName"
            set valueName ImagePath
            set value [fullPathName $servicePath $serviceExe] 

            # check if "Tornado Registry" exists in the service registry
            # if exists, that means the service has already been installed
            # and we only have to overwrite the wtxregds.exe path and restart
            # the service

            if {[regValueExists $rootKey $key $valueName]} {
                if {![catch {sysRegistryValueWrite \
                        $rootKey $key $valueName $value} error2]} {
                    dbgputs "New registry value written. Service Installed."
                    uninstLog resource "service\t$serviceName"
                 } else {
                    infputs "Unable to install service $serviceName: $error2"
                    uninstLog setuplog \
                        "\tFailed to install service $serviceName: $error2"
                    dbgputs "Failed to install $serviceName: $error2"
                 }
             } else {
                 infputs "Unable to install service $serviceName: $error"
                 uninstLog setuplog \
                    "\tUnable to install service $serviceName: $error"
                 dbgputs "Unable to install $serviceName: $error"
             }
        }

        if {[catch {setupServiceStart $serviceName} error]} {
            dbgputs "Unable to confirm that $serviceName was started."
            uninstLog setupLog \
                "\tUnable to confirm that $serviceName was started."
        } else {
            dbgputs "service started: $serviceName"
        }
    }
}

#############################################################################
#
# checkSolarisPatch - checks to make sure the specified patch is installed
#                     for a Solaris machine.
#
# This is the actual routine for Solaris that checks whether the required 
# patch specified by <line> is installed on the user's machine.  Information
# about the user's machine is first gathered, then the list of conditions
# is iterated through to determine whether to actually check for the installed
# patch.  
#
# The list of conditions is a tcl style list.  If no conditions are specified,
# the patch will automatically be checked to determine if it has been installed.
# If any of the conditions specified do not match the information gathered about
# the user's machine, installation of the patch is NOT checked.  
# The following conditions are supported:
#
# 5.6 | 2.6: operating system is Solaris 2.6
# 5.5 | 2.5: operating system is Solaris 2.5 
# ultra:     user's machine model is an Ultra
# pci:       user's machine uses a PCI bus 
#
# An example condition list: 2.6 ultra pci  
# specifies to check for the patch only if the user's machine is an Ultra with a
# PCI bus running Solaris 2.6.
#
# Any patches that are not found to be installed are appended 
# to the global string setupVals(uninstalledPatches_required) or
# setupVals(uninstalledPatches_recommended).  This string is used
# in INSTW32.TCL to display to the user a messageBox detailing the required 
# patches.  
#
#
# SYNOPSIS
# checkSolarisPatch <line>
#
# PARAMETERS: 
#   line : a comma delimited line containing required patches to be checked. 
#
# RETURNS: N/A
#   
# ERRORS: N/A
#

proc checkSolarisPatch {line} {
    global setupVals

    set patchnumber [nthValueFromCommaDelimitedLine $line 1]
    set description [nthValueFromCommaDelimitedLine $line 2]
    set os          [nthValueFromCommaDelimitedLine $line 3]    
    set conditions  [nthValueFromCommaDelimitedLine $line 4]
    set requirements [nthValueFromCommaDelimitedLine $line 5]

    if {$requirements == "no_value" || $requirements != "required"} {
        set requirements "recommended"
    }

    # os version
    set user_osversion [catch {exec /bin/uname -r}]
    infputs "INF Processing: CheckPatch: osversion = $user_osversion"

    # For Solaris 2.6, specifically check for "5.6".  This means that 
    # only version 2.6 of the OS is checked for, not 2.6.x.  If in 
    # the future we need to check for 2.6.x, do a regsub check as 
    # with the 5.5 check done below.  The reason this has been done is
    # for the required XServer patch for Solaris 2.6(.0) machines that
    # will crash without the required patch, for which 2.6.1 most likely
    # will fix.  
    if {$user_osversion == "5.6"} {
        set solaris26 1
    } else {
        set solaris26 0
    }
    
    if {[regsub 5\.5 $user_osversion {} ignore]} {
        set solaris25 1
    } else {
        set solaris25 0
    }

    # model (e.g. Ultra)
    set user_machinemodel [catch {exec /bin/uname -i}] 
    if {[regsub -nocase Ultra $user_machinemodel {} ignore]} {
        set user_machinemodel ultra
    } else {
        set user_machinemodel sparcstation
    }            
            
    infputs "INF Processing: CheckPatch: model = $user_machinemodel"
            
    # check for pci
    catch { exec /bin/ls /devices | /bin/grep -i pci } pci_check
    if {[regsub -nocase pci $pci_check {} ignore]} {
        set user_pci 1
        infputs "INF Processing: CheckPatch: pci present"
    } else {
        set user_pci 0
        infputs "INF Processing: CheckPatch: pci not present"
    }  

    
    # check for patch conditions
    set check_for_patch 1
    if {$conditions == "no_value"} {
        set conditions ""
    }
    foreach condition $conditions {
        switch -- $condition {
            5.6 -
            2.6 {
                if {$solaris26 == 0} {
                    set check_for_patch 0
                    infputs "INF Processing: CheckPatch: will not check for patch $patchnumber:"
                    infputs "INF Processing: CheckPatch: condition user machine not Solaris 2.6"
                }
            } 
            5.5 -
            2.5 {
                if {$solaris25 == 0} {
                    set check_for_patch 0
                    infputs "INF Processing: CheckPatch: will not check for patch $patchnumber:"
                    infputs "INF Processing: CheckPatch: condition user machine not Solaris 2.5"
                }
            } 
            Ultra -
            ultra {
                if {$user_machinemodel != "ultra"} {
                    set check_for_patch 0
                    infputs "INF Processing: CheckPatch: will not check for patch $patchnumber:"
                    infputs "INF Processing: CheckPatch: condition user machine not Ultra"
                }
            }
            pci -
            PCI {
                if {$user_pci != 1} {
                    set check_for_patch 0
                    infputs "INF Processing: CheckPatch: will not check for patch $patchnumber:"
                    infputs "INF Processing: CheckPatch: condition user machine not pci"
                }
            }
            default {
                infputs "INF Processing: CheckPatch: condition $condition not supported"
            }
        }
    }

    if {$check_for_patch == 1} {
        infputs "INF Processing: CheckPatch: checking for patch $patchnumber"
        regexp {[0-9]+} $patchnumber patchid
        regexp {\-[0-9]+} $patchnumber patchversion
        regexp {[0-9]+} $patchversion patchversion
        infputs "INF Processing: CheckPatch: required patch level: $patchversion"
        catch { exec /bin/showrev -p | /bin/grep $patchid } showrev
        # count the number of patch versions installed
        set num_patches_installed [regsub -all "$patchid-\[0-9\]+" $showrev {} ignore]

        # check the patches are equivalent or higher version
        set patch_installed 0

        for {set i $num_patches_installed} {$i > 0 && $patch_installed == 0} {incr i -1} {
            regexp "$patchid-\[0-9\]+" $showrev patch_compare
            regexp {\-[0-9]+} $patch_compare installed_patch_version
            regexp {[0-9]+} $installed_patch_version installed_patch_version
            if {$installed_patch_version >= $patchversion} {
                set patch_installed 1
                infputs "INF Processing: CheckPatch: $patch_compare installed for $patchnumber requirement"
            }
            regsub "$patchid-\[0-9\]+" $showrev {} showrev
        }
       
        # if patch is not installed, append patch number and description
        # to global string uninstalledPatches, which will be displayed
        # later 
        if {$patch_installed == 0} {
            infputs "INF Processing: CheckPatch: $requirements patch $patchnumber not installed"
            if {$requirements == "required"} {
                append setupVals(uninstalledPatches_required) "$patchnumber\t$description\n"     
            } else {
                append setupVals(uninstalledPatches_recommended) "$patchnumber\t$description\n"     
            }
        }
    }
}

#############################################################################
#
# checkSolarisPatch_for_t3 - checks to make sure the specified patch is 
#                            installed for a Solaris machine.
#
# This procedure is used in T3 only
#
# This is the actual routine for Solaris that checks whether the required
# patch specified by <line> is installed on the user's machine.  Information
# about the user's machine is first gathered, then the list of conditions
# is iterated through to determine whether to actually check for the installed
# patch.
#
# The list of conditions is a tcl style list.  If no conditions are specified,
# the patch will automatically be checked to determine if it has been installed.
# If any of the conditions specified do not match the information gathered about
# the user's machine, installation of the patch is NOT checked.
# The following conditions are supported:
#
# 5.7 | 2.7: operating system is Solaris 2.7
# configuration-specific:
# PGX (M64 Graphics card): for patch 106146-06
# Creator/Creator3D graphics card: for patch 106145-04
# Elite3D graphics card: for patch 106144-06
#
# An example condition list: 2.7 m640
# specifies to check for the patch only if the user's machine has 
# m640 graphics card and is running on Solaris 2.7
#
# Any patches that are not found to be installed are appended
# to the global string setupVals(uninstalledPatches_required) or
# setupVals(uninstalledPatches_recommended).  This string is used
# in INSTW32.TCL to display to the user a messageBox detailing the required
# patches.
#
#
# SYNOPSIS
# checkSolarisPatch <line>
#
# PARAMETERS:
#   line : a comma delimited line containing required patches to be checked.
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc checkSolarisPatch_for_T3 {line} {
    global setupVals

    set patchnumber [nthValueFromCommaDelimitedLine $line 1]
    set description [nthValueFromCommaDelimitedLine $line 2]
    set os          [nthValueFromCommaDelimitedLine $line 3]
    set conditions  [nthValueFromCommaDelimitedLine $line 4]
    set requirements [nthValueFromCommaDelimitedLine $line 5]

    if {$requirements == "no_value" || $requirements != "required"} {
        set requirements "recommended"
    }

    # os version
    catch {exec /bin/uname -r} user_osversion
    infputs "INF Processing: CheckPatch: osversion = $user_osversion"

    # graphics cards
    catch {exec /bin/ls /dev/fbs} user_graphicsCard

    # For Solaris 2.7, specifically check for "5.7".  This means that
    # only version 2.7 of the OS is checked for, not 2.7.x.

    if {$user_osversion == "5.7"} {
        set solaris27 1
    } else {
        set solaris27 0
    }

    # check for patch conditions
    set check_for_patch 1
    if {$conditions == "no_value"} {
        set conditions ""
    }
    foreach condition $conditions {
        switch -- $condition {
            5.7 -
                2.7 {
                if {$solaris27 == 0} {
                    set check_for_patch 0
                    infputs "INF Processing: CheckPatch:\
                             will not check for patch $patchnumber:"
                    infputs "INF Processing: CheckPatch:\
                             condition user machine not Solaris 2.7"
                }
            }
            m640 -
                M640 {
                if {$user_graphicsCard != "m640"} {
                    set check_for_patch 0
                    infputs "INF Processing: CheckPatch:\
                             will not check for patch $patchnumber:"
                    infputs "INF Processing: CheckPatch:\
                                     condition user machine not M640 graphics card"
                }
            }
            ffb -
                FFB {
                if {$user_graphicsCard != "ffb"} {
                    set check_for_patch 0
                    infputs "INF Processing: CheckPatch:\
                             will not check for patch $patchnumber:"
                    infputs "INF Processing: CheckPatch:\
                             condition user machine not FFB graphics card"
                }
            }
            afb -
                AFB {
                if {$user_graphicsCard != "afb"} {
                    set check_for_patch 0
                    infputs "INF Processing: CheckPatch:\
                             will not check for patch $patchnumber:"
                    infputs "INF Processing: CheckPatch:\
                             condition user machine AFB graphics card"
                }
            }
            default {
                infputs "INF Processing: CheckPatch:\
                         condition $condition not supported"
            }
        }
    }

    if {$check_for_patch == 1} {
        infputs "INF Processing: CheckPatch: checking for patch $patchnumber"
            regexp {[0-9]+} $patchnumber patchid
        regexp {\-[0-9]+} $patchnumber patchversion
        regexp {[0-9]+} $patchversion patchversion
        infputs "INF Processing: CheckPatch: required patch level: $patchversion"
        catch { exec /bin/showrev -p | /bin/grep $patchid } showrev        

        # count the number of patch versions installed
            set num_patches_installed [regsub -all "$patchid-\[0-9\]+" $showrev {} ignore]

        # check the patches are equivalent or higher version
        set patch_installed 0

        for {set i $num_patches_installed} {$i > 0 && $patch_installed == 0} {incr i -1} {
            regexp "$patchid-\[0-9\]+" $showrev patch_compare
            regexp {\-[0-9]+} $patch_compare installed_patch_version
            regexp {[0-9]+} $installed_patch_version installed_patch_version
            if {$installed_patch_version >= $patchversion} {
                set patch_installed 1
                infputs "INF Processing: CheckPatch: $patch_compare installed for $patchnumber requirement"
            }
            regsub "$patchid-\[0-9\]+" $showrev {} showrev
        }

        # if patch is not installed, append patch number and description
        # to global string uninstalledPatches, which will be displayed
        # later
        if {$patch_installed == 0} {
            infputs "INF Processing: CheckPatch:\
                     $requirements patch $patchnumber not installed"
                if {$requirements == "required"} {
                append setupVals(uninstalledPatches_required)\
                           "$patchnumber\t$description\n"
                } else {
                append setupVals(uninstalledPatches_recommended)\
                           "$patchnumber\t$description\n"
            }
        }
    }
}


#############################################################################
#
# checkHPUXPatch - checks to make sure the specified patch is installed
#                     for an HPUX machine.
#
# This is the actual routine for HPUX that checks whether the required
# patch specified by <line> is installed on the user's machine.
#
# Currently there are no special conditions to check for HPUX.
# The condition list is ignored.
#
# Any patches that are not found to be installed are appended
# to the global string uninstalledPatches.  This string is used
# in INSTW32.TCL to display to the user a messageBox detailing the required
# patches.
#
# SYNOPSIS
# checkHPUXPatch <line>
#
# PARAMETERS:
#   line : a comma delimited line containing required patches to be checked.
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc checkHPUXPatch {line} {
    global setupVals
    global ctrlVals
    global env

    set patchlist    [nthValueFromCommaDelimitedLine $line 1]
    set description  [nthValueFromCommaDelimitedLine $line 2]
    set os           [nthValueFromCommaDelimitedLine $line 3]
    set conditions   [nthValueFromCommaDelimitedLine $line 4]
    set requirements [nthValueFromCommaDelimitedLine $line 5]

    if {$requirements == "no_value" || $requirements != "required"} {
        set requirements "recommended"
    }

    set check_for_patch 1

    #
    # check for any necessary conditions here.
    #

    if {$check_for_patch == 1} {
        infputs "INF Processing: CheckPatch: checking for patch $patchlist"

        # run swlist once to save time.
        if {![info exists ctrlVals(swlist)]} {
            catch { exec /usr/sbin/swlist -l product | /bin/grep PH } ctrlVals(swlist)
            if {[catch {open $env(TMP)/swlist w} swlist_fileid]} {
                # Cannot open the file
                puts "Cannot open $env(TMP)/swlist"
            } else {
                puts $swlist_fileid $ctrlVals(swlist)
                close $swlist_fileid
            }
        }
        # this should be the minimum patch version required to be installed.
        set minimum_patch_version [lindex $patchlist end]

        # this should be the latest patch version we know of and will
        # be used in the message displayed to the user.
        set patchnumber [lindex $patchlist 0]

        # check if the patch is installed.
        set patch_installed 0

        # first use the patch list directly to check for the patch.
        foreach patch $patchlist {
            if {[regsub -all $patch $ctrlVals(swlist) {} ignore]} {
                set patch_installed 1
            }
        }

        # if using the patch list is unsucessful, use the description
        # to check for the patch.  The last value in $patchlist is the
        # minimum patch version to check for as well.

        if { $patch_installed == 0 } {
            # if a version of the patch is installed, the following command
            # should return the patch version and the description of the
            # patch.
            catch { exec /bin/fgrep -i "$description" $env(TMP)/swlist } grep_result

            # now check to see if $description is part of $grep_result.
            # If it is, check to make sure the version installed is the
            # minimum required.  If both criterias are true, a valid
            # version of the patch has been installed.
            if {[string last [string toupper $description] [string toupper $grep_result]] > -1} {
                set user_patch_version [lindex $grep_result 0]

                # extract the prefix portion of the patch version
                # e.g. extract PHSS_ from PHSS_15043
                regexp {[^0-9]+} $user_patch_version user_patch_version_prefix

                # extract the prefix portion of the minimum patch version
                regexp {[^0-9]+} $minimum_patch_version minimum_patch_version_prefix

                # make sure the prefixes match
                if {$user_patch_version_prefix == $minimum_patch_version_prefix} {
                    # extract the number portion of the patch version
                    # e.g. extract 15043 from PHSS_15043
                    regexp {[0-9]+} $user_patch_version user_patch_version_number

                    # extract the number portion of the minimum patch version
                    regexp {[0-9]+} $minimum_patch_version minimum_patch_version_number
                    if { $user_patch_version_number >= $minimum_patch_version_number } {
                        set patch_installed 1
                    }
                }
            }
        }

        # if patch is not installed, append patch number and description
        # to global string uninstalledPatches, which will be displayed
        # later
        if {$patch_installed == 0} {
            infputs "INF Processing: CheckPatch: $requirements patch $patchnumber not installed"
            if {$requirements == "required"} {
                append setupVals(uninstalledPatches_required) "$patchnumber\t$description\n"
            } else {
                append setupVals(uninstalledPatches_recommended) "$patchnumber\t$description\n"
            }
        }
    }
}

#############################################################################
#
# checkPatchLine - checks to make sure the specified patch is installed.
#
# Checks that the required patch specified is installed on the user's
# machine.  Any required patches that are not found to be installed are
# appended to the global string uninstalledPatches.  This string is used
# in INSTW32.TCL to display to the user a messageBox detailing the required
# patches.  Currently Solaris and HPUX10 is supported.
#
# The format of the line read from the inf file is as follows (optional
# parameters in brackets):
#
#   patch number, patch description, os version (wind host type), conditions, [requirements]
#
#   patch number : number and version of patch to be checked
#   patch description : string description of required patch
#   os version/wind host type: sun4-solaris2 | parisc-hpux10
#   conditions : a list of required conditions that specify whether to check
#                if the patch is installed.  See checkSolarisPatch and
#                and checkHPUXPatch for more details.
#   requirements: required | recommended
#             if the patch is required to be installed, Setup will inform
#             the user and not allow installation to continue.  Default
#             is recommended, in which case Setup will inform the user that
#             it is recommended to install the patch, but will allow
#             installation to continue.
#
# SYNOPSIS
# checkPatchLine <line>
#
# PARAMETERS:
#   line : a comma delimited line containing required patches to be checked.
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc checkPatchLine {line} {
    global env
    global infVals
    global setupVals

    set os [nthValueFromCommaDelimitedLine $line 3]

    if {![info exists setupVals(uninstalledPatches_required)]} {
        set setupVals(uninstalledPatches_required) ""
    }

    if {![info exists setupVals(uninstalledPatches_recommended)]} {
        set setupVals(uninstalledPatches_recommended) ""
    }

    if {[isUnix]} {
        if {$os == $env(WIND_HOST_TYPE)} {
            switch $os {
                sun4-solaris2 {
                    checkSolarisPatch $line
                }
                parisc-hpux10 {
                    checkHPUXPatch $line
                }
            }        
        }
    }
}

#############################################################################
#
# checkStringsLineFormat - checks whether a Strings line from the inf file
#                          is in the correct format.
#
# Checks to make sure whether the given line is in the correct format
# for the Strings section.  The format is string_variable=string_value.
#
# SYNOPSIS
# checkStringsLineFormat <line>
#
# PARAMETERS:
#   line : a line containing Strings section data.
#
# RETURNS:
#   0 if the line is not in the correct format.
#   1 if the line has the correct format.
#
# ERRORS: N/A
#

proc checkStringsLineFormat {line} {
    return [regexp {[^=]+=.+} $line]
}

#############################################################################
#
# addStringName - adds string variable and replacement value to the global
#                 space
#
# Adds the string variable and replacement value to the global array
# infString.  This global array is used to determine whether a variable
# from the Strings section exists and contains its replacement value.
# $infString(string variable name) contains the string replacement
# value.
#
# SYNOPSIS
# addStringName <line>
#
# PARAMETERS:
#   line : a line containing Strings section data.
#
# RETURNS: N/A
#
# ERRORS: N/A
#


proc addStringName {line} {
   global infString

   set string_name [lindex [split $line =] 0]
   set string_replacement [lindex [split $line =] 1]
   set infString($string_name) $string_replacement
}

#############################################################################
#
# addStringsLine - adds a string variable and replacement value to the global
#                  space from values read from an inf line.
#
# Given a line from the Strings section in the inf file, adds a string
# variable and its replacement value to the global space.  This is used
# for substitution of substrings in the inf file between % signs.  If a
# line contains an invalid format the procedure simly returns.
#
# A Strings section line is of this format:
#   string_name=string_value
#
# SYNOPSIS
# addStringLine <line>
#
# PARAMETERS:
#   line : a line containing Strings section data.
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc addStringsLine {line} {
    if {[checkStringsLineFormat $line] == 0} {
        infputs "INF Processing: the Strings section contains an invalid line: $line"
        return
    }
    addStringName $line
}

#############################################################################
#
# arFlagsLine - sets the arFlags for a specified product index
#
# Sets the arFlag for the specified product index by modifying the
# global array variable arFlags.  A - is prepended to the
# specified arflags if it does not already exist.
#
# The format of the line read from the inf file is as follows:
#   -arflags
#
# SYNOPSIS
# arFlagsLine <line> <prodIndex>
#
# PARAMETERS:
#   line : a line containing the arflags to set.
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc arFlagsLine {line prodIndex} {
    global arFlags

    set arflags [nthValueFromCommaDelimitedLine $line 1]

    # prepend a - to the arflags if it does not exist
    set firstCharacter [string index $arflags 0]

    if {[string compare $firstCharacter \-] != 0} {
        set completeArFlags "\-"
        append completeArFlags $arflags
    } else {
        set completeArFlags $arflags
    }

    infputs "INF Processing: setting arFlags for [productInfoGet name $prodIndex] to $completeArFlags"

    set arFlags($prodIndex) $completeArFlags
}

#############################################################################
#
# warningsFileLine - reads and displays the warning file for the product
#
# Reads the specified warnings file for the product and displays
# a warning message box with the contents of the file.  The warnings file must
# be ascii text and located in RESOURCE/TCL/INF.  This procedure is called last
# for the compSelect page in INSTW32.TCL.
#
# The format of the line read from the inf file is as follows:
#   name_of_warnings_file.txt, [control var]
#
# SYNOPSIS
# warningsFileLine <line> [control var]
#
# PARAMETERS:
#   line : a line containing the warnings file with the contents to display.
#   [control var] : conditional control variable allowing warning message to be
#                   displayed. infVals(control var) must exist and be set to any
#                   value other than 0.
#
# If [control var] is specified, the global variable infVars(control var)
# must exist and be set to a value other than 0.  Otherwise the warning message
# will not be displayed.  This allows for conditional control of displaying the
# warning message.
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc warningsFileLine {line} {
    global infVals

    set warningsFile [nthValueFromCommaDelimitedLine $line 1]
    set controlvar   [nthValueFromCommaDelimitedLine $line 2]

    # check the control variable
    set displayWarning 1
    if {[string compare $controlvar no_value] != 0} {
        if {![info exists infVals($controlvar)]} {
            # control variable is specified but does not exist
            set displayWarning 0
            infputs "INF Processing: will not add display warnings file $warningsFile: $controlvar specified but infVals($controlvar) not set"
        } elseif {$infVals($controlvar)==0} {
            # control variable is set to 0
            set displayWarning 0
            infputs "INF Processing: will not add display warnings file $warningsFile: $controlvar specified but infVals($controlvar) = 0"
        }
    }

    if {$displayWarning != 0} {
        if [catch {open [cdromRootDirGet]\\RESOURCE\\INF\\$warningsFile r} warningsFileId] {
            infputs "INF processing: Cannot open warnings file $warningsFile"
            return
        }

        set warningMessage [read $warningsFileId]
        messageBox $warningMessage
    }
}

#############################################################################
#
# filesCopyLine- copies a file from the values specified from an inf file line
#
# Copies a source file to a destination file.  The format of the line read
# from the inf file is as follows (optional parameters in brackets):
#
#   source path, destination path, [option], [OS version], [control var]
#
#   source path : path of the source file to be copied
#   destination path : path of the destination file
#   [option] : none | update | overwrite.  Set to none by default.
#   [OS version] : NT3x, NT4x, or WIN95.  Specifies to copy the file only if the
#                  current OS being used for installation is that which is
#                  specified.
#                  If no value is specified the icon will be added for any OS.
#   [control var] : conditional control variable allowing file to be copied.
#                   infVals(control var) must exist and be set to any value other
#                   than 0.
#
# If [control var] is specified, the global variable infVars(control var)
# must exist and be set to a value other than 0.  Otherwise the source file
# will not be copied.  This allows for conditional control of copying the source
# file.
#
# SYNOPSIS
# filesCopyLine <line>
#
# PARAMETERS:
#   line : a comma delimited line containing the path and values of the file to
#          be copied.
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc filesCopyLine {line} {
    global ctrlVals
    global infVals

    set sourcePath          [nthValueFromCommaDelimitedLine $line 1]
    set destinationPath     [nthValueFromCommaDelimitedLine $line 2]
    set option              [nthValueFromCommaDelimitedLine $line 3]
    set osversion           [nthValueFromCommaDelimitedLine $line 4]
    set controlvar          [nthValueFromCommaDelimitedLine $line 5]

    if {[string compare $option no_value]==0} {
        set option none
    }

    if {[isUnix]} {
        set sourcePath [dosToUnix $sourcePath]
        set destinationPath [dosToUnix $destinationPath]
    }

    set docopy 1

    # check the os version
    switch -exact -- $osversion {
        no_value { set docopy 1 }
        default {
           if {[string compare $osversion $ctrlVals(version)]==0} {
           set docopy 1
           } else {
               set docopy 0
               infputs "INF Processing: will not copy file $sourcePath: osversion does not match OS: $osversion"
           }
        }
    }

    # check the control variable
    if {$docopy == 1} {
        if {[string compare $controlvar no_value] != 0} {
            if {![info exists infVals($controlvar)]} {
                # control variable is specified but does not exist
                set docopy 0
                infputs "INF processing: will not copy $sourcePath: $controlvar specified but infVals($controlvar) not set"
            } elseif {$infVals($controlvar)==0} {
                # control variable is set to 0
                set docopy 0
                infputs "INF processing: will not copy $sourcePath: specified but infVals($controlvar) = 0"
            }
        }
    }

    if {$docopy != 0} {
        infputs "INF processing: copying file: $sourcePath to $destinationPath"
        if {[fileDup $sourcePath $destinationPath $option] == 0} {
            infputs "INF processing: could not copy $sourcePath"
        }
    }

}

#############################################################################
#
# processInfSection - reads and processes an inf file section.
#
# Processes an inf section until the next section or end of file is
# reached.  The function to process each data line must be specified.
#
# SYNOPSIS
# processInfSection <addFunction> [prodIndex]
#
# PARAMETERS:
#   addFunction : the function that processes each individual line.
#   prodIndex : optional product Index.  Necessary for the ArFlags section.
#
# RETURNS: N/A
#
# ERRORS: N/A
#


proc processInfSection {addFunction {prodIndex 0}} {
    set sectionOver 0
    while {$sectionOver == 0} {
        set line [readLine]
        set lineType [getLineType $line]

        if {[string compare $lineType section_name] == 0} {
            set sectionOver 1
        } elseif {[string compare $lineType comment] == 0} {
            # comment, do nothing
        } elseif {[string compare $lineType end_of_file] == 0} {
            return
        } else {
            if {[string compare $addFunction arFlagsLine] == 0} {
                # ArFlags is the only function that requires prodIndex
                $addFunction $line $prodIndex
            } else {
                $addFunction $line
            }

            # check for end of file
            if {[endOfFile]} {
                return
            }
        }
    }
}

#############################################################################
#
# searchAndProcessSection - searches for and processes an inf file section.
#
# Searches for and processes the specified section of the inf file.  The
# procedure first processes the Strings section of the inf file if it has
# not been done already.
#
# SYNOPSIS
# searchAndProcessSection <section> <fileName> [prodIndex]
#
# PARAMETERS:
#   section : the name of the INF section to be processed.
#   fileName : the name of the INF file.
#   prodIndex : optional product Index.  Necessary for the ArFlags section.
#
# RETURNS:
#   0 if processing the section was unsuccessful.
#   1 if successful.
#
# ERRORS: N/A
#


proc searchAndProcessSection {section fileName {prodIndex 0}} {
    global searchedForStringsSection

    if {![info exists searchedForStringsSection($fileName)]} {
        set searchedForStringsSection($fileName) 1
        searchAndProcessSection Strings $fileName
    }

    if {![openFile $fileName]} {
        infputs "INF processing: cannot open $fileName"
        return 0
    }

    while {[endOfFile] == 0} {
        set line [readLine]
        set lineType [getLineType $line]

        switch -exact -- $lineType {
            comment {
                # do nothing
            }
            section_name {
                set sectionName [extractSectionName $line]
                if {[string compare $sectionName $section] == 0} {
                   switch -exact -- $sectionName {
                        AddRegistry {
                            processInfSection addRegistryLine
                        }
                        AddIcon {
                            processInfSection addIconLine
                        }
                        AddService {
                            processInfSection addServiceLine
                        }
                        Strings {
                            processInfSection addStringsLine
                        }
                        FilesCopy {
                            processInfSection filesCopyLine
                        }
                        ArFlags {
                            processInfSection arFlagsLine $prodIndex
                        }
                        CheckPatch {
                            processInfSection checkPatchLine
                        }
                        WarningsFile {
                            processInfSection warningsFileLine
                        }
                        InstallLast {
                            # no lines necessary to process.  Simply return
                            # 1 since this section name is found.
                        }
                        default {
                            infputs "INF processing: invalid sectionName specified: $sectionName"
                            closeFile
                            return 0
                        }
                    }
                    closeFile
                    return 1
                }
            }
            default {
                # data, skip over
            }
        }
    }
    closeFile
    return 0
}


#############################################################################
#
# chooseInfFile - returns a path to an inf filename.
#
# Given the product index, returns the path to the inf file for the product.
# The inf file resides in RESOURCE\INF and its filename must be
# [PRODUCT NAME].INF (all uppercase).
#
# SYNOPSIS
# chooseInfFile <prodIndex>
#
# PARAMETERS:
#   prodIndex : the product index.
#
# RETURNS:
#   The path to to the product's inf file.
#
# ERRORS: N/A
#

proc chooseInfFile {prodIndex} {
    return [cdFileNameGet [file join RESOURCE INF \
                                [string toupper [productInfoGet name $prodIndex].INF]\
                          ]]
}

#############################################################################
#
# selectedProductsProcessInfFile - processes the specified INF section for
#                                  all selected products.
#
# This procedure processes the specified INF section for all the products
# the user has selected to install.  The special generic file
# ALLPRODUCTS.INF is processed first to carry out actions that should be
# done for any product.
#
# If the product name starts with "tornado", TORNADO.INF is processed
# firest.  This is to account for product names such as tornado-vxsim.
#
# SYNOPSIS
# selectedProductsProcessInfFile <section>
#
# PARAMETERS:
#   section : name of the INF section to process.
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc selectedProductsProcessInfFile {section} {
    searchAndProcessSection $section [cdFileNameGet [file join RESOURCE \
                                         INF ALLPRODUCTS.INF]]
    foreach prodIndex [cdInfoGet selectedProdIndexList] {
        # check if this product is a tornado object.  If so, process TORNADO.INF.
        # This accounts for products whose names start with "tornado", such
        # as "tornado-vxsim".

        set productName [productInfoGet name $prodIndex]
        set productDesc [productInfoGet name $prodIndex]
        if {[tornadoProductCheck $productName $productDesc]} {
            searchAndProcessSection $section [cdFileNameGet [file join RESOURCE \
                                             INF TORNADO.INF]] $prodIndex
        }

        # don't do this again if the product name is exactly tornado, since
        # TORNADO.INF was just processed above.

        if {$productName != "tornado"} {
            searchAndProcessSection $section [chooseInfFile $prodIndex] $prodIndex
        }
    }
}

#############################################################################
#
# extractInfFile - extracts the inf file from WIND.000.
#
# Extracts the specified inf file from WIND.000 and places it in the
# temporary directory.
#
# SYNOPSIS
# extractInfFile <infFile>
#
# PARAMETERS:
#   infFile : name of the INF file to extract.
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc extractInfFile {infFile} {
    set zipFile [cdromZipDirGet]/WIND.000

    if {[file exists $zipFile]} {
       if ![catch {setupUnzip -o -qq -d [tempDirGet] $zipFile $infFile} retVal] {
       } else {
            infputs "INF processing: cannot extract $infFile: reason: $retVal"
       }
    }
}



#############################################################################
#
# infputs - wrapper for puts function.
#
# Wrapper for the puts function.  Only prints out the specified string
# if the environment variable INF_DEBUG exists and is set to a nonzero value.
#
# SYNOPSIS
# infputs <line>
#
# PARAMETERS:
#   line : string to output.
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc infputs {line} {
    global env
    global setupVals

    if {[info exists env(INF_DEBUG)] && $env(INF_DEBUG) != 0} {
        if {[info exists setupVals(DBGLOG_FD)]} {
            puts $setupVals(DBGLOG_FD) $line
        } else {
            puts $line
        }
    }
}
