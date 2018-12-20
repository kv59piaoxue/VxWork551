# LIBUPDATE.TCL  - Setup procedures for updating vxWorks libraries 
#                  wizard page
#
# Copyright 1999-2003 Wind River Systems, Inc
#
# modification history
# --------------------
# 02g,25feb03,bjl  strip cpu variant before calling make (spr 86344).
# 02f,23may02,bjl  fixed archiving for objects into a T2.0.x tree (spr 76643)
# 02e,05feb02,bwd  Do not use gnu as a default tool for coldfire
# 02d,18jan02,bwd  Modified path to makefiles for archiving
# 02c,03dec01,bwd  Moved dbgputs for newArchive variable
# 02b,19nov01,bwd  Modified for new format of archives
# 02a,12jun01,j_w  Modified for Tornado 2.2
# 01h,12mar01,j_w  Prevent the archiving of non-native simulator libraries --
#                  including SIMLINUX
# 01g,10Jan01,j_w  Avoid adding duplicate objects onto the objs(arPassId) list
# 01f,19dec00,wmd  Prevent archiving of libs that don't have a make.<CPU>gnu
#                  file in the ../target/h/make directory.
# 01e,21nov00,wmd  Prevent the archiving of non-native simulator libraries.
# 01d,10nov00,j_w  backup the library only if it exists
# 01c,08nov00,j_w  Archive the objects into the library if obj<cpu>gnuvx
#                  directory exists. Updated arFlag to use -crus
# 01b,31oct00,bwd  SPR 35597: Remove HELP button
# 01a,18sep00,j_w  modified from LIBEXTRACT.TCL. (from version tor3_x/8).
#                  Updated makefileCreate{} to include TGT_DIR
#


#############################################################################
#
# pageCreate(libUpdate) - Update the library archive objects and displays
#                         progess in updating libraries
#
# This procedure will update the library archive objects and displays progess
# in updating libraries
#
# SYNOPSIS
# .tS
# pageCreate(libUpdate)
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc pageCreate(libUpdate) {} {
    global ctrlVals
    global setupVals
    global newArchive
    
    if { [isGUImode] } {
        set ctrlVals(numBbrd) 0
        meterCreate [strTableGet LIBUPDATE_LABEL]
        set w [dlgFrmCreate [strTableGet LIBUPDATE_TITLE]]

        controlPropertySet $ctrlVals(meterWindow).$ctrlVals(meterWg) \
                                -background Blue -foreground Black

        controlEnable $w.backButt 0
        controlEnable $w.nextButt 0
        controlHide $w.helpButt 1

    } else {   
        printPageTitle [strTableGet LIBUPDATE_TITLE] 
        puts [strTableGet LIBUPDATE_LABEL_TEXT]
    }

    # Handle 2 different formats of archive
    # Variable is set in FILECOPY once found out the archive format
    if { [info exist newArchive] == 1 && $newArchive == 1 } {
        set newArchive 0
        newLibrariesUpdate
    } else {
        librariesUpdate
    }

    if { [isGUImode] } {
        meterDestroy $ctrlVals(meterWindow)

        controlEnable $w.backButt 1
        controlEnable $w.nextButt 1

        # test automation

        if { $ctrlVals(useInputScript) } {
            autoSetupLog "Library Update page:"
            autoSetupLog "\tUpdated library objects"
        }
        nextCallback

    } else {
        nextCallback        
        return 0
    }
}


#############################################################################
#
# pageProcess(libUpdate) - process inputs from libUpdate page if necessary
#
# This procedure will process inputs from libUpdate page if necessary
#
# SYNOPSIS
# .tS
# pageProcess(libUpdate)
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: 1 when successful
#
# ERRORS: N/A
#

proc pageProcess(libUpdate) {} {
    return 1
}


##############################################################################
#
# librariesUpdate - updating the vxWorks libraries.
#
# This routine walks thru each product, updates the vxWorks libraries w/ the
# object list which was obtained and saved by the archListPut() function.  The
# default updating flag is -crus.  A particular product can override this
# default setting by provide a postInstall.tcl file that contains a call to
# the arFlagsSet() function.  To speed up the archiving process, a minimum
# amount of AR invocations is made. This is achieved by grouping the object
# list into smaller lists of distinct flags and libraries, then archiving
# each list of objects via an AR invocation.
#
#
# SYNOPSIS
# librariesUpdate
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#


proc librariesUpdate {} {
    global setupVals
    global setup_objects 

    dbgputs "\nlibrariesUpdate...\n"
    set setupVals(cancel) 0

    # Determine the total number of new object files for GUI updating purpose.

    set totalObjFile 0

    foreach objDir [array names setup_objects] {
        incr totalObjFile [llength $setup_objects($objDir)]
    }

    set percent 0

    # Updating the libraries.

    if {$totalObjFile != "0"} {
        meterUpdate $percent ""
        foreach prodIndex [cdInfoGet selectedProdIndexList] {

            searchAndProcessSection ArFlags [chooseInfFile $prodIndex] \
               $prodIndex
            set prodARFlag [arFlagsGet $prodIndex]

            foreach archKey [array names setup_objects] {

                # typex is useful when updating special component.
                # ex: windview,...

                if {[regexp {^(.*),(.*),(.*),(.*),(.*),(.*)$} $archKey \
                    junk index obj cpu tool type typex] && \
                    "$prodIndex" == "$index"} {

                    # An arPassId is characterized by the following variables:
                    # "$prodARFlag,$cpu,$tool,$type,$typex,". It corresponds
                    # to one AR call. For example,
                    # prodARFlag,   cpu, tool, type, typex,
                    #       -cru, R4650,  gnu,   vx,    wv,

                    set arPassId $prodARFlag,$cpu,$tool,$type,$typex,

                    # Any objects that have these properties are "AR"ed
                    # together. typex is optional.

                    #initialize objs and objsArchived if necessary
                    if ![info exists objs($arPassId)] {
                        set objs($arPassId) ""
                    }

                    if ![info exists objsArchived($arPassId) ] {
                        set objsArchived($arPassId) 0
                    }

                    # now group objects by arPassId and update the
                    # number of objects archived for each arPassId
                                        
                    foreach objFile $setup_objects($archKey) {

                        # avoid duplicate objects being added onto the 
                        # object list
                        
                        if {[lsearch $objs($arPassId) $objFile] == "-1"} {
                            set objs($arPassId) "$objFile $objs($arPassId)"
                            incr objsArchived($arPassId)
                        } else {
                            #dbgputs "duplicate objects($cpu): $objFile"
                            incr objsArchived($arPassId)
                        }
                    }
                }
            }

                        
        }

        set numArchivedSoFar 0
        foreach arPassId [array name objsArchived] {

            if {"$setupVals(cancel)" == "1"} { return }

            # extract elements from arPassId
            if {[regexp {^(.*),(.*),(.*),(.*),(.*),(.*)$} $arPassId \
                                        junk prodARFlag cpu tool type typex] } {

                set archiveFile [file join [destDirGet] target lib \
                        lib$cpu$tool$type.a]

                meterUpdate $percent "Updating lib$cpu$tool${type}.a"

                switch -exact $cpu {
                    SIMNT {
                        #puts "cpu = $cpu"
                        #puts "hosttype = [windHostTypeGet]"
                        if {[windHostTypeGet] == "sun4-solaris2"} {
                            continue
                        }
                        if {[windHostTypeGet] == "x86-linux2"} {
                            continue
                        }
                     }
                
                    SIMSPARCSOLARIS {
                        #puts "cpu = $cpu"
                        #puts "hosttype = [windHostTypeGet]"
                        if {[windHostTypeGet] == "x86-win32"} {
                            continue
                        }
                        if {[windHostTypeGet] == "x86-linux2"} {
                            continue
                        }
                    }

                    SIMLINUX {
                        if {[windHostTypeGet] == "x86-win32"} {
                            continue
                        }
                        if {[windHostTypeGet] == "sun4-solaris2"} {
                            continue
                        }
                    }
                                        
                }

                # skip library update if the make.<cpu><tool> file is not present
                # to prevent SETUP from shipping archives of uninstalled arch

                set dirTool ""
                if { [regexp {.*(gnu).*} $tool] } {
                    set dirTool "gnu"
                } elseif { [regexp {.*(diab).*} $tool] } {
                    set dirTool "diab"
                }
                set mFile [file join \
                            [destDirGet] target h tool $dirTool make.$cpu$tool]

                if {[file exists $mFile] == 0} {
                    # Check if makefile exists in target/h/make.  
                    # This is for the case of installing an optional product
                    # into a Tornado 2.0.x tree.   
                 
                    set mFile [file join \
                                [destDirGet] target h make make.$cpu$tool]                    
                }

                if {[file exists $mFile] == 0} {
                    continue
                }

                # don't backup library if this is the first installation
                # Backup only if the .a exists
                if {[file extension $setupVals(uninstFile)] != ".001"} {
                    set aFile [file join [destDirGet] target lib \
                                lib$cpu$tool$type.a] 
                    if {[file exists $aFile]} {
                        backup target/lib/lib$cpu$tool$type.a
                        # immediately flush the queue; otherwise we may not
                        # be backing up the old archive
                        backupFileQueueFlush
                    }
                }
                                
                cd [file join [destDirGet] target lib \
                    obj$cpu$tool$type$typex]
                                
                set numArchivedSoFar \
                    [expr $numArchivedSoFar + $objsArchived($arPassId)]
                                
                set percent [expr $numArchivedSoFar * 100 / $totalObjFile]
                                
                libUpdateHelper $cpu $tool $type ar \
                                $prodARFlag $objs($arPassId)
                                
                # Ranlib to update the lib table of content.
                libUpdateHelper $cpu $tool $type ranlib
                                
                meterUpdate $percent "Updating lib$cpu$tool${type}.a"
                                
                dbgputs "                       AR pass Id: $arPassId"
                dbgputs "                          Library: \
                                                lib$cpu$tool$type.a"
                dbgputs "                       Object directory: [pwd]"
                dbgputs "                          ARFLAGS: $prodARFlag"
                dbgputs "Number of objects in this AR pass: \
                                                $objsArchived($arPassId)"
                dbgputs "Number of objects archived so far: \
                                                $numArchivedSoFar"
                dbgputs "          Percent archived so far: \
                                          $percent% of $totalObjFile objects" 
                dbgputs "------------------------------------------------"
                                
                # log it for uninstall
                set f [file join target lib lib$cpu$tool${type}.a]
                uninstLog file "wind_base\t$f"
                dbgputs "uninstLog file $f"
                                
            } else {
                puts "librariesUpdate: cannot get arPassId"
            }
        }
        meterUpdate 100 ""
    }
}

##############################################################################
#
# libUpdateHelper - invokes make to carry out the requested action.
#
# a -n option is used to obtain a list of commands that 'make' supposes to
# carry out.  Each command is then evaluated separately.  Asking make to carry
# out the real action will cause many console windows to pop up.
#
#
# SYNOPSIS
# libUpdateHelper <cpu> <tool> <type> <action> [arFlags] [objs]
#
# PARAMETERS:
#    <cpu> : CPU family, i.e. MC68000
#    <tool>: compiler family, i.e 'gnu' or 'sfgnule'
#    <type>: library type, i.e. 'vx'
#    <action>: build target, i.e. 'ar' or 'ranlib'
#    <DIR_TOOL>: name of tool directory, i.e. 'gnu' or 'diab'
#    [arFlags] : the default value is -crus
#    [objs] : object file list separated by space, needed when <action> is ar
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc libUpdateHelper {cpu tool type action {arFlags "-crus"} {objs ""}} {

    set binDir [file join [destDirGet] host [windHostTypeGet] bin]
    regsub -all {\\} $binDir {/} binDir

    set dirTool ""
    if { [regexp {.*(gnu).*} $tool] } {
        set dirTool "gnu"
    } elseif { [regexp {.*(diab).*} $tool] } {
        set dirTool "diab"
    }

    if {![catch {exec $binDir/make -n -f [makefileCreate] CPU=$cpu \
                              TOOL=$tool TYPE=$type \
                              OBJS=$objs DIR_TOOL=$dirTool \
                              ARFLAGS=$arFlags $action} retVal]} {

        regsub -all {\\} $retVal {/} retVal

        # location of diab archiver (but not for ranlib)
        if { $action != "ranlib" } {
            if { [string match $dirTool "diab"] } {
                set binDir ""

                if { [isUnix] } {
                    set binDir [file join [destDirGet] host diab SUNS bin]
                } else {
                    set binDir [file join [destDirGet] host diab WIN32 bin]
                }
            }
            regsub -all {\\} $binDir {/} binDir
        }

        if {[catch {eval "exec $binDir/$retVal"} error1]} {
            if {[catch {eval "exec $retVal"} error2]} {
                puts "$error1\n$error2"
                uninstLog setup "\t$error1"
                uninstLog setup "\t$error2"
            } else {
                dbgputs "\n$retVal"
            }
        } else {
            dbgputs "\n$binDir/$retVal"
        }
    } else {
        puts "libUpdate: $retVal"
        uninstLog setup "\t$retVal"
    }
}

##############################################################################
#
# makefileCreate - create a makefile for use with the archiver and
#                  vxWorks libraries.
#
# SYNOPSIS
# makefileCreate
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc makefileCreate {} {

    if {[windHostTypeGet] == "x86-win32"} {
        set Makefile "[tempDirGet]\\Makefile"
    } else {
        set Makefile "[tempDirGet]/Makefile"
    }

    set windowsIncludeLine "include [destDirGet]\\target\\h\\tool\\$(DIR_TOOL)\\make.$(CPU)$(TOOL)"
    set unixIncludeLine "include [destDirGet]/target/h/tool/$(DIR_TOOL)/make.$(CPU)$(TOOL)"

    # Check to see if target/h/tool exists, thus signifying a Tornado 2.2 tree.  
    # For installation of an optional product into a Tornado 2.0.x tree,
    # make.$cpu$tool exists in target/h/make, and the above include lines must
    # change accordingly.    

    set mFile [file join \
                  [destDirGet] target h tool]

    if {[file exists $mFile] == 0} {
        set windowsIncludeLine "include [destDirGet]\\target\\h\\make\\make.$(CPU)$(TOOL)"
        set unixIncludeLine "include [destDirGet]/target/h/make/make.$(CPU)$(TOOL)"
    }

    if ![file exists $Makefile] {
        set f [open $Makefile "w"]

        if {"[windHostTypeGet]" == "x86-win32"} {
            puts $f "TGT_DIR = [destDirGet]\\target"
            puts $f $windowsIncludeLine
            puts $f "ARFLAGS = -crus"
            puts $f "ar:"
            puts $f "\t- $(AR) $(ARFLAGS) ..\\lib$(CPU)$(TOOL)$(TYPE).a $(OBJS)"
            puts $f "ranlib:"
            puts $f "\t- $(RANLIB) ..\\lib$(CPU)$(TOOL)$(TYPE).a"
        } else {
            puts $f "TGT_DIR = [destDirGet]/target"
            puts $f $unixIncludeLine
            puts $f "ARFLAGS = -crus"
            puts $f "ar:"
            puts $f "\t- $(AR) $(ARFLAGS) ../lib$(CPU)$(TOOL)$(TYPE).a $(OBJS)"
            puts $f "ranlib:"
            puts $f "\t- $(RANLIB) ../lib$(CPU)$(TOOL)$(TYPE).a"
        }
        close $f
    }

    return $Makefile
}


##############################################################################
#
# newLibrariesUpdate - update the vxWorks libraries for new format of archives
#
# Format: target/lib/<FAMILY>/<CPU>/<TOOL>/obj<type>/*.o
#         (ex: target/lib/mips/MIPS32/sfcommonle/objarch/foo.o)
#         (ex: target/lib/mips/MIPS32/sfgnule/objcplus/foo2.o)
#
# This routine walks thru each product, updates the vxWorks libraries w/ the
# object list which was obtained and saved by the archListPut() function.  The
# default updating flag is -crus. A particular product can override this
# default setting by provide a postInstall.tcl file that contains a call to
# the arFlagsSet() function. To speed up the archiving process, a minimum
# amount of AR invocations is made. This is achieved by grouping the object
# list into smaller lists of distinct flags and libraries, then archiving
# each list of objects via an AR invocation.
#
# SYNOPSIS
# newLibrariesUpdate
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc newLibrariesUpdate {} {
    global setupVals
    global setup_objects

    dbgputs "\nnewLibrariesUpdate...\n"
    set setupVals(cancel) 0

    # Determine the total number of new object files for GUI updating purpose.

    set totalObjFile 0

    foreach objDir [array names setup_objects] {
        incr totalObjFile [llength $setup_objects($objDir)]
    }

    set percent 0

    # Updating the libraries.

    if {$totalObjFile != "0"} {
        meterUpdate $percent ""
        foreach prodIndex [cdInfoGet selectedProdIndexList] {

            searchAndProcessSection ArFlags [chooseInfFile $prodIndex] \
               $prodIndex
            set prodARFlag [arFlagsGet $prodIndex]

            foreach archKey [array names setup_objects] {

                if {[regexp {^(.*),(.*),(.*),(.*),(.*),(.*)$} $archKey \
                    junk index obj family cpu tool type] && \
                    "$prodIndex" == "$index"} {

                    # An arPassId is characterized by the following variables:
                    # "$prodARFlag,$family,$cpu,$tool,$type,". It corresponds
                    # to one AR call. For example,
                    # prodARFlag, family, cpu, tool, type,
                    #       -cru, mips, MIPS32, sfgnule, cplus,

                    set arPassId $prodARFlag,$family,$cpu,$tool,$type,

                    #initialize objs and objsArchived if necessary
                    if ![info exists objs($arPassId)] {
                        set objs($arPassId) ""
                    }

                    if ![info exists objsArchived($arPassId) ] {
                        set objsArchived($arPassId) 0
                    }

                    # now group objects by arPassId and update the
                    # number of objects archived for each arPassId
                                        
                    foreach objFile $setup_objects($archKey) {
                        # avoid duplicate objects being added onto the 
                        # object list
                        
                        if {[lsearch $objs($arPassId) $objFile] == "-1"} {
                            set objs($arPassId) "$objFile $objs($arPassId)"
                            incr objsArchived($arPassId)
                        } else {
                            #dbgputs "duplicate objects($cpu): $objFile"
                            incr objsArchived($arPassId)
                        }
                    }
                }
            }                        
        }

        set numArchivedSoFar 0
        foreach arPassId [array name objsArchived] {

            if {"$setupVals(cancel)" == "1"} { return }

            # extract elements from arPassId
            if { [regexp {^(.*),(.*),(.*),(.*),(.*),(.*)$} $arPassId \
                      junk prodARFlag family cpu tool type] } {

                set archiveFile [file join [destDirGet] target lib \
                                        $family $cpu $tool lib$type.a]

                meterUpdate $percent "Updating $archiveFile"

                switch -exact $cpu {
                    SIMNT {
                        #puts "cpu = $cpu"
                        #puts "hosttype = [windHostTypeGet]"
                        if {[windHostTypeGet] == "sun4-solaris2"} {
                            continue
                        }
                        if {[windHostTypeGet] == "x86-linux2"} {
                            continue
                        }
                     }
                
                    SIMSPARCSOLARIS {
                        #puts "cpu = $cpu"
                        #puts "hosttype = [windHostTypeGet]"
                        if {[windHostTypeGet] == "x86-win32"} {
                            continue
                        }
                        if {[windHostTypeGet] == "x86-linux2"} {
                            continue
                        }
                    }

                    SIMLINUX {
                        if {[windHostTypeGet] == "x86-win32"} {
                            continue
                        }
                        if {[windHostTypeGet] == "sun4-solaris2"} {
                            continue
                        }
                    }
                }

                # skip library update if the make.<cpu><tool> file is not present
                # to prevent SETUP from shipping archives of uninstalled arch
                # And skip this checking if tool (the directory name) is "common"

                if { ![regexp {.*common.*} $tool] } {
                    set dirTool ""
                    if { [regexp {.*(gnu).*} $tool] } {
                        set dirTool "gnu"
                    } elseif { [regexp {.*(diab).*} $tool] } {
                        set dirTool "diab"
                    }
                    set mFile [file join \
                            [destDirGet] target h tool $dirTool make.$cpu$tool]

                    if {[file exists $mFile] == 0} {
                        continue
                    }
                }

                # don't backup library if this is the first installation
                # Backup only if the .a exists
                if {[file extension $setupVals(uninstFile)] != ".001"} {
                    set aFile [file join [destDirGet] target lib \
                                        $family $cpu $tool lib$type.a]
                    if {[file exists $aFile]} {
                        backup target/lib/$family/$cpu/$tool/lib$type.a
                        # immediately flush the queue; otherwise we may not
                        # be backing up the old archive
                        backupFileQueueFlush
                    }
                }
                                
                cd [file join [destDirGet] target lib $family \
                                           $cpu $tool obj$type]
                                
                set numArchivedSoFar \
                    [expr $numArchivedSoFar + $objsArchived($arPassId)]
               
                set percent [expr $numArchivedSoFar * 100 / $totalObjFile]
                                
                # call to create makefile and archive
                newLibUpdateHelper $family $cpu $tool $type ar \
                                   $prodARFlag $objs($arPassId)
                               
                # Ranlib to update the lib table of content.
                newLibUpdateHelper $family $cpu $tool $type ranlib
                                
                meterUpdate $percent "Updating ../target/lib/$family/$cpu/$tool/lib$type.a"
                                
                dbgputs "                       AR pass Id: $arPassId"
                dbgputs "                          Library: \
                                                target/lib/$family/$cpu/$tool/lib$type.a"
                dbgputs "                       Object directory: [pwd]"
                dbgputs "                          ARFLAGS: $prodARFlag"
                dbgputs "Number of objects in this AR pass: \
                                                $objsArchived($arPassId)"
                dbgputs "Number of objects archived so far: \
                                                $numArchivedSoFar"
                dbgputs "          Percent archived so far: \
                                          $percent% of $totalObjFile objects" 
                dbgputs "------------------------------------------------"
                                
                # log it for uninstall
                set f [file join target lib $family $cpu $tool lib$type.a]
                uninstLog file "wind_base\t$f"
                dbgputs "uninstLog file $f"
                                
            } else {
                puts "newLibrariesUpdate: cannot get arPassId"
            }
        }
        meterUpdate 100 ""
    }
}

##############################################################################
#
# newLibUpdateHelper - invokes make to carry out the requested action.
#
# a -n option is used to obtain a list of commands that 'make' supposes to
# carry out.  Each command is then evaluated separately.  Asking make to carry
# out the real action will cause many console windows to pop up.
#
# SYNOPSIS
# newLibUpdateHelper <family> <cpu> <tool> <type> <action> [arFlags] [objs]
#
# PARAMETERS:
#    <family>: Architecture, i.e. ppc, mips
#    <cpu> : CPU family, i.e. ppc604, MIPS32
#    <tool>: compiler family, i.e 'gnu', 'sfgnule'
#    <type>: library type, ex: type is 'cplus' for the "objcplus" directory
#    <action>: build target, i.e. 'ar' or 'ranlib'
#    <DIR_TOOL>: name of tool directory, i.e. 'gnu' or 'diab'
#    [arFlags] : the default value is -crus
#    [objs] : object file list separated by space, needed when <action> is ar
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc newLibUpdateHelper {family cpu tool type action {arFlags "-crus"} {objs ""}} {
    global setupVals

    set binDir [file join [destDirGet] host [windHostTypeGet] bin]
    regsub -all {\\} $binDir {/} binDir

    # for *common* directory, use gnu tool for archiving (except for coldfire)
    # for coldfire, use "diab" as a default tool
    # for others (ex: gnu, diab, gnule..), use that tool
    if { [string match $family "cf"] } {
        regsub {(.*)common(.*)} $tool {\1diab\2} tool
    } else {
        regsub {(.*)common(.*)} $tool {\1gnu\2} tool
    }

    set dirTool ""
    if { [regexp {.*(gnu).*} $tool] } {
        set dirTool "gnu"
    } elseif { [regexp {.*(diab).*} $tool] } {
        set dirTool "diab"
    }

    # If a cpu variant is part of the "tool" string, strip 
    # it out before doing the make so that the proper makefile
    # is used.  For example, "_vr54xx" is stripped from 
    # "sfgnule_vr54xx".  

    if { [regexp $setupVals(toolset) $tool basetool] } {
        set tool $basetool
    }

    if {![catch {exec $binDir/make -n -f [newMakefileCreate] CPU=$cpu \
                              TOOL=$tool TYPE=$type \
                              OBJS=$objs DIR_TOOL=$dirTool \
                              ARFLAGS=$arFlags $action} retVal]} {

        regsub -all {\\} $retVal {/} retVal

        # location of diab archiver (but not for ranlib)
        if { $action != "ranlib" } {
            if { [string match $dirTool "diab"] } {
                set binDir ""
                if { [isUnix] } {
                    set binDir [file join [destDirGet] host diab SUNS bin]
                } else {
                    set binDir [file join [destDirGet] host diab WIN32 bin]
                }
                regsub -all {\\} $binDir {/} binDir
            }
        }

        if {[catch {eval "exec $binDir/$retVal"} error1]} {
            if {[catch {eval "exec $retVal"} error2]} {
                puts "$error1\n$error2"
                uninstLog setup "\t$error1"
                uninstLog setup "\t$error2"
            } else {
                dbgputs "\n$retVal"
            }
        } else {
            dbgputs "\n$binDir/$retVal"
        }
    } else {
        puts "new_libUpdate: $retVal"
        uninstLog setup "\t$retVal"
    }
}


##############################################################################
#
# newMakefileCreate - create a makefile for use with the archiver and
#                     vxWorks libraries.
#
# SYNOPSIS
# newMakefileCreate
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc newMakefileCreate {} {

    if {[windHostTypeGet] == "x86-win32"} {
        set mFile "[tempDirGet]\\Makefile"
    } else {
        set mFile "[tempDirGet]/Makefile"
    }

    if ![file exists $mFile] {
        set f [open $mFile "w"]

        if {"[windHostTypeGet]" == "x86-win32"} {
            puts $f "TGT_DIR = [destDirGet]\\target"
            puts $f "include [destDirGet]\\target\\h\\tool\\$(DIR_TOOL)\\make.$(CPU)$(TOOL)"
            puts $f "ARFLAGS = -crus"
            puts $f "ar:"
            puts $f "\t- $(AR) $(ARFLAGS) ..\\lib$(TYPE).a $(OBJS)"
            puts $f "ranlib:"
            puts $f "\t- $(RANLIB) ..\\lib$(TYPE).a"
        } else {
            puts $f "TGT_DIR = [destDirGet]/target"
            puts $f "include [destDirGet]/target/h/tool/$(DIR_TOOL)/make.$(CPU)$(TOOL)"
            puts $f "ARFLAGS = -crus"
            puts $f "ar:"
            puts $f "\t- $(AR) $(ARFLAGS) ../lib$(TYPE).a $(OBJS)"
            puts $f "ranlib:"
            puts $f "\t- $(RANLIB) ../lib$(TYPE).a"
        }
        close $f
    }
    return $mFile
}

######################################################################
# Dialog Text Messages
######################################################################

set strTable(LIBUPDATE_TITLE) "Libraries Update"

set strTable(LIBUPDATE_LABEL) \
    "SETUP is updating the VxWorks libraries.  We recommend that you let\
     SETUP finish this step, or the libraries will be in an inconsistent\
     state.  Please be patient as the process may take several minutes. \
     If you want to quit the SETUP program, click <Cancel> and run\
     the SETUP program again at a later time."

set strTable(LIBUPDATE_LABEL_TEXT) \
    "SETUP is updating the VxWorks libraries.  We recommend that you let\
     SETUP finish this step, or the libraries will be in an inconsistent\
     state.  Please be patient as the process may take several minutes."

