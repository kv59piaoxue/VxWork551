# FILECOPY.TCL  - Setup procedures for implementing file-copying wizard page
#
# Copyright 1999-2003 Wind River Systems, Inc
#
# modification history
# --------------------
# 03i,29apr03,bjl  use default toolset (spr 87803), text rewording.
# 03h,27feb03,bjl  changed toolset to be extracted dynamically rather than
#                  using a hardcoded list.  
# 03g,03oct02,bjl  fixed skipping of slideshow bitmap (spr 82816).
# 03f,31may02,wmd  Remove the fadebmp option from the slideshow, Spr #78088.
# 03e,23may02,bjl  fixed postInstall to be executed per product rather than
#                  for all parts (spr 77976).  
# 03d,19nov01,bwd  Added checks to store a list of new archives
# 03c,30oct01,bwd  SPR 70033: added option "DO NOT OVERWRITE ANY NEWER FILES"
# 03b,17sep01,bwd  Fixed SPR 69435 and 69982
# 03a,12jun01,j_w  Modified for Tornado 2.2
# 02y,07nov00,wmd  Fix SPR # 35911, the retry command to remove a file doesn't
#                  work.
# 02x,25oct00,bwd  Initialize setupFiles variable. Do not skip installing
#                  mainwin-related files if no mw source. Fixed setupFiles
#                  selection process.
# 02w,16oct00,bwd  SPR 35262: fixed mw linking to first check if files exist
# 02v,25sep00,bwd  Skip linking mainwin-related files if running SETUP on
#                  Windows
# 02u,19sep00,bwd  Changed /usr/bin to /bin
# 02t,18sep00,j_w  Added libUpdate back for FCS. Added product index back in
#                  archListPut{}
# 02s,18sep00,bwd  LINUX: skip coping mainwin-related files under SETUP
#                  directory and creat links instead
# 02r,05sep00,bwd  Skip coping mainwin-related files under SETUP directory 
#                  and creat links instead
# 02q,26jun00,bwd  Added cases to skip copying non-native-host files under
#                  SETUP directory
# 02p,26jun00,bwd  Added CD description in setup.log
# 02o,22jun00,bwd  SPR 31613: write to setup.log the list of licensed products
#                  on this page to avoid any duplicate logging
# 02n,22jun00,bwd  SPR 32060: hide HELP button for this page
# 02m,09jun00,bwd  Added another host type check for x86-linux2
# 02l,09may00,bwd  Catch error when closing a file in procedure execute
# 02k,03feb00,bjl  always pageRemove libExtract for EAR-2.
# 02j,01feb00,bwd  Fixed error handling for test automation
# 02i,11jan00,bwd  Removed test automations from command line SETUP
# 02h,23nov99,clc  add text mode
# 02g,12nov99,bwd  Corrected typo
# 02f,25oct99,bjl  removed product index from object list so that related
#                  optional comp. objects are stored in one array.
# 02e,21oct99,bjl  removed parisc-hpux support.
# 02d,18oct99,bjl  added handling of library archives.
# 02c,18oct99,j_w  removed debug message
# 02b,14oct99,bjl  remove readonly attribute during setupCopy,
#                  set default bitmap for Unix if no billboard list.
# 02a,30Sep99,j_w  Modified for T3
# 01n,11aug99,j_w  Added messages
# 01m,26apr99,bjl  do not resize or reposition window for KDE.
# 01l,23apr99,bjl  check for KDE and FVWM.
# 01k,22apr99,wmd  Added fix for window resizing problem.
# 01j,22mar99,bjl  do not move window during resizing.
# 01i,19mar99,wmd  Output to a file any debug messages.
# 01h,15mar99,wmd  Need to make array multipleVersion global, spr #25678..
# 01g,15mar99,tcy  use setupWinVerGetEx() to obtain os version info
# 01f,12mar99,wmd  Add line indicating host os type to setup.log.
# 01e,04mar99,tcy  fixed problem with last checkin
# 01d,03mar99,tcy  save CD number in installCDnumber file for About-Box usage
# 01c,01feb99,tcy  invoke setExecutePermissions in filesCopy()
# 01b,28jan99,tcy  moved procs here from INSTALL.TCL
# 01a,26jan99,tcy  extracted from INSTW32.TCL.
#

#############################################################################
#
# pageCreate(filesCopy) - display file installation progress with meter and
#                         install files onto user's destination directory and
#                         back up files if necessary
#
# This procedure will display file installation progress with meter, install
# files onto user's destination directory and back up files if necessary
#
# SYNOPSIS
# .tS
# pageCreate(filesCopy)
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc pageCreate(filesCopy) {} {
    global ctrlVals
    global setupVals
    global tornadoInstalled

    if { [isGUImode] } {
        if {[limitColors]} {

            # create the meter here, so it can be displayed in the
            # dialog window.  Do not display the billboard.
 
            set ctrlVals(numBbrd) 0
            meterCreate [strTableGet FILESCOPY_LABEL]

        } elseif {[removeBackground]} {
            resizeBbrdDialog
        }

        set w [dlgFrmCreate [strTableGet FILESCOPY_TITLE]]

        controlEnable $w.backButt 0
        controlEnable $w.nextButt 0
        set setupVals(cancel) 0

        if {![removeBackground]} {

            # create the billboards and meter to be placed in the background.

            set ctrlVals(bbrdList) [bbrdListGet .BMP]

            if {"$ctrlVals(bbrdList)" == ""} {
                set ctrlVals(bbrdList) \
                    [dosToUnix [cdFileNameGet \
                               [file join RESOURCE BITMAPS SETUP.BMP]]]
            }

            set ctrlVals(numBbrd) [llength $ctrlVals(bbrdList)]
            set ctrlVals(displayInt) [expr 100 / $ctrlVals(numBbrd)]
            set ctrlVals(bbrdElapse) $ctrlVals(displayInt)

            meterCreate [strTableGet FILESCOPY_LABEL]
        } 

        controlPropertySet $ctrlVals(meterWindow).$ctrlVals(meterWg) \
                            -background Blue -foreground Black

    } else { # TEXT MODE
        
        printPageTitle [strTableGet FILESCOPY_TITLE]
        puts [strTableGet FILESCOPY_LABEL]
        
        set setupVals(cancel) 0
    }

    setupCopy

    if {!$setupVals(cancel)} {

        # call filesCopy
        # for TEXT mode, if return value = 0, exit SETUP

        if { [filesCopy] == 0 } {
            if { ![isGUImode] } { return 0 }
        }

        backupFileQueueFlush
        lappend setupVals(commandQueue) [list backupFileQueueFlush]
    }
    
    if { [isGUImode] } {

        controlEnable $w.backButt 1
        controlEnable $w.nextButt 1

        # test automation

        if { $ctrlVals(useInputScript) } {
            autoSetupLog "Files copy page:"
            autoSetupLog "\tFiles copied onto $setupVals(destDir)"
        }

        nextCallback

    } else { # TEXT mode
        nextCallback
        return 0
    }
}

#############################################################################
#
# pageProcess(filesCopy) - process inputs from filesCopy page
#
# This procedure will process inputs from filesCopy page
#
# SYNOPSIS
# .tS
# pageProcess(filesCopy)
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: 0 if successful
#          1 if cancel button is pushed
#
# ERRORS: N/A
#

proc pageProcess(filesCopy) {} {
    global setup_objects
    global ctrlVals
    global setupVals

    # This global variable is set in the tornado/postInstall.tcl

    global tornadoInstalled

    set retVal 0

    if {"$setupVals(cancel)" != "1"} {

        if {[array names setup_objects] == ""} {
            dbgputs "Remove libUpdate"
            pageRemove "libUpdate"
        }

        if { [isGUImode] } {
            meterDestroy $ctrlVals(meterWindow)
        }
        set retVal 1

    } else {
        if { [isGUImode] } {
            applicationExit
        }
    }

    return $retVal
}

#############################################################################
#
# resizeBbrdDialog - resize the billboard dialog box
#
# This procedure will resize the billboard dialog box according to window size
#
# SYNOPSIS
# resizeBbrdDialog
#
# .tE
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc resizeBbrdDialog {} {
    global ctrlVals
    global env

    set ctrlVals(restoredDialog) 0

    # calculate the billboard dimensions.

    set bbrdW $ctrlVals(bbrdW)
    set bbrdH $ctrlVals(bbrdH)

    set dimension [pixelsToDialogUnits $ctrlVals(mainWindow) \
                    [list $bbrdW $bbrdH]]
    set bbrdW [lindex $dimension 0]
    set bbrdH [lindex $dimension 1]

    # move and resize the dialog window so the billboards can fit.
    # save the original values of the dialog window first.

    set ctrlVals(dlg_orig_xpos) [lindex [windowPositionGet \
                                             $ctrlVals(mainWindow)] 0]
    set ctrlVals(dlg_orig_ypos) [lindex [windowPositionGet \
                                         $ctrlVals(mainWindow)] 1]
    set ctrlVals(dlg_orig_size) [windowSizeGet $ctrlVals(mainWindow)]
    set ctrlVals(dlg_orig_frm2_size) [controlSizeGet \
                                         $ctrlVals(mainWindow).frm2]
    set ctrlVals(dlg_orig_frm2_pos) [controlPositionGet \
                                         $ctrlVals(mainWindow).frm2]
    set ctrlVals(dlg_orig_back_pos) [controlPositionGet \
                                         $ctrlVals(mainWindow).backButt]
    set ctrlVals(dlg_orig_next_pos) [controlPositionGet \
                                         $ctrlVals(mainWindow).nextButt]
    set ctrlVals(dlg_orig_next_size) [controlSizeGet \
                                         $ctrlVals(mainWindow).nextButt]
    set ctrlVals(dlg_orig_cancel_pos) [controlPositionGet \
                                         $ctrlVals(mainWindow).cancelButt]

    set dlg_orig_w [lindex $ctrlVals(dlg_orig_size) 0]
    set right_border [expr $dlg_orig_w - 10]
    set dlg_orig_h [lindex $ctrlVals(dlg_orig_size) 1]
    set dlg_orig_cancel_w \
        [lindex [controlSizeGet $ctrlVals(mainWindow).cancelButt] 0]
    set dlg_orig_next_w \
        [lindex [controlSizeGet $ctrlVals(mainWindow).nextButt] 0]
    set dlg_orig_back_w \
        [lindex [controlSizeGet $ctrlVals(mainWindow).backButt] 0]

    # The dialog window will be reduced in width to just fit the billboard
    # width, and increased in height to account for the billboard.

    # subtract billboard width but add 20 for the edges

    set width_reduction [expr $dlg_orig_w - $bbrdW + 20]

    # now calculate the height increase
    # based on the the billboard ypos

    if {[info exists env(SETUP_USEKDE)]} {
        set billboard_ypos 10
    } else {
        set billboard_ypos 40
    }

    set billboard_bottom [expr $billboard_ypos + $bbrdH]
    set meterlabel_ypos [expr $billboard_bottom + 10]
    set meter_ypos [expr $meterlabel_ypos + 12]
    set frm2_ypos [expr $meter_ypos + 15]
    set button_ypos [expr $frm2_ypos + 7]

    # bottomedge is also the new dialog window height

    set bottomedge [expr $button_ypos + 19]

    set height_increase [expr $bottomedge - $dlg_orig_h]

    # do not reposition the window for KDE to avoid window manager
    # crash.

    if {![info exists env(SETUP_USEKDE)]} {
        windowPositionSet $ctrlVals(mainWindow) \
                          $ctrlVals(dlg_orig_xpos) \
                          $ctrlVals(dlg_orig_ypos)
    }
    
    # Hide the help button - no use during copying
    controlHide $ctrlVals(mainWindow).helpButt 1

    # Hide the Next button and substitute it with a "phony" button.
    # The Next button is set to be the default button, which causes
    # UITclSh to think that its size is larger due to the border.
    # This causes problems with the button appearance when moving the
    # button around and when restoring the original dialog window.
    # Restore the Next button in the "restoreOriginalDialog" procedure.

    controlHide $ctrlVals(mainWindow).nextButt 1
    controlCreate $ctrlVals(mainWindow) \
                [list button -name phonynextButt -title "&Next >" \
                             -callback nextCallback \
                              -x 197 -y 185 -w 50 -h 14]
    controlEnable $ctrlVals(mainWindow).phonynextButt 0

    controlFocusSet $ctrlVals(mainWindow).cancelButt
    controlHide $ctrlVals(mainWindow).bitmap 1

    # controls are specially set for KDE because we do not shrink
    # the window.

    if {[info exists env(SETUP_USEKDE)]} {
        controlSizeSet $ctrlVals(mainWindow).frm2 [expr $right_border - 10] 2
    } else {
        controlSizeSet $ctrlVals(mainWindow).frm2 $bbrdW 2
    }
    controlPositionSet $ctrlVals(mainWindow).frm2 10 $frm2_ypos

    if {[info exists env(SETUP_USEKDE)]} {
        set cancel_xpos [expr $right_border - $dlg_orig_cancel_w]
    } else {
        set cancel_xpos [expr 10 + $bbrdW - $dlg_orig_cancel_w]
    }
    set next_xpos [expr $cancel_xpos - 8 - $dlg_orig_next_w ]
    set back_xpos [expr $next_xpos - $dlg_orig_back_w]
    controlPositionSet $ctrlVals(mainWindow).backButt $back_xpos \
                                                      $button_ypos
    controlPositionSet $ctrlVals(mainWindow).phonynextButt $next_xpos \
                                                      $button_ypos
    controlPositionSet $ctrlVals(mainWindow).cancelButt $cancel_xpos \
                                                        $button_ypos

    # do not resize the window for KDE to avoid a window manager crash.

    if {![info exists env(SETUP_USEKDE)]} {
        set ctrlVals(mainWindowSize) [list [expr $bbrdW + 20] $bottomedge]
        windowSizeSet $ctrlVals(mainWindow) \
            [expr $bbrdW + 20] $bottomedge
    }


    set ctrlVals(bbrdList) [bbrdListGet .BMP]
    if {"$ctrlVals(bbrdList)" == ""} {
        set ctrlVals(bbrdList) \
            [dosToUnix [cdFileNameGet \
                       [file join RESOURCE BITMAPS SETUP.BMP]]]
    }
    set ctrlVals(numBbrd) [llength $ctrlVals(bbrdList)]
    set ctrlVals(displayInt) [expr 100 / $ctrlVals(numBbrd)]
    set ctrlVals(bbrdElapse) $ctrlVals(displayInt)

    # create the meter here, so it can be displayed in the
    # dialog window.

    meterCreate [strTableGet FILESCOPY_LABEL]
}

#############################################################################
#
# toolsetExtract - extracts the toolset list from the installed makefiles
#
# This procedure will extract the toolset list by searching for
# "TOOL = <tool>" lines in the make.*<tool>* files in target/h/tool/<tool>
# or target/h/make.  The string returned is the list of tools found
# separated by |, for example "sfgnule|sfgnu|gnu|diab".  Substrings must
# come later in the list, for example "gnu" must come after "sfgnule|sfgnu".  
# This list is used as a pattern matcher during file copying and archiving.
#
# SYNOPSIS
# .tS
# toolSetExtract
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: the toolset list, each tool separated by | and sorted so that
#          substrings come last
#          defaultSet if the makefile directories do not exist or no
#          TOOL=<tool> lines are found.  
#
# ERRORS: N/A
#

proc toolsetExtract {} {
    global setupVals

    set toolPattern "TOOL\[ \t\]*=\[ \t\]*"
    set toolFamilyList {gnu diab}
    set toolset ""

    set defaultSet $setupVals(toolSet)

    # save the current directory
    set curDir [pwd]

    set toolDir [file join [destDirGet] target h tool]
    set toolDirExists 0

    if {[file exists $toolDir]} {
        set makefileDir $toolDir

        # get the tool families, which are the directories
        # under target\h\tool except "common"

        if {[catch {
            # catch file operation errors just in case

            cd $toolDir   
            set toolFamilyDirs [glob -nocomplain *]

            } error]} {
            dbgputs "toolsetExtract error: $error"
            uninstLog setupLog "archive error: $error"
            cd $curDir
            return $defaultSet            
        }

        if {$toolFamilyDirs != ""} {
            set toolFamilyList ""
            foreach toolFamily $toolFamilyDirs {
                if {$toolFamily != "common"} {
                    lappend toolFamilyList $toolFamily
                }
            }
        }        
        cd $curDir

        set toolDirExists 1
    } else {
        set makefileDir [file join [destDirGet] target h make]
        if {![file exists $makefileDir]} {
            set errorString "target makefile directories do not exist"
            dbgputs "toolsetExtract error: $errorString"
            uninstLog setupLog  "archive error: $errorString"

            # if makefile directories do not exist, return a default toolset
            # so that Setup can continue

            return $defaultSet
        }    
    }

    if {[catch {   
        # catch file operation errors just in case

        foreach toolFamily $toolFamilyList {
            cd $makefileDir

            if {$toolDirExists == 1} {
                if {[file exists $toolFamily] && 
                    [file isdirectory $toolFamily]} {
                cd $toolFamily
                } else {
                    continue
                }
            }

            foreach f [glob -nocomplain "make.*$toolFamily*"] {
                set fd [open $f r]
                foreach line [split [read $fd] \n] {
                    # skip comments

                    if {[string first \# [string trimleft $line]] == 0} {
                        continue
                    }

                    if {[regexp "($toolPattern)(.*)" $line match toolstring tool]} {
                        # the lsubstringAppend procedure is used to add the
                        # tool string to the toolset list, to ensure that 
                        # substrings of any string in the list are added after
                        # those strings. This is because the toolset is used
                        # as a pattern matcher during archiving to strip out
                        # any existing cpu variant from the "tool" string.
                        # Regexp will match the first string found, so we 
                        # don't want only "sfgnu" extracted out of 
                        # "sfgnule_vr54xx" for example (refer to 
                        # newLibUpdateHelper in LIBUPDTE.TCL).

                        set toolset [lsubstringAppend $toolset $tool]

                        # make sure each tool in the set is unique
                        set toolset [lunique $toolset]
                    }
                }
                close $fd
            }
        }

        # end of catch

        } error]} {
        dbgputs "toolsetExtract error: $error"
        uninstLog setupLog "archive error: $error"
        cd $curDir
        return $defaultSet
    } 
    

    # go back to the current directory
    cd $curDir

    regsub -all " " $toolset "|" toolset

    if {$toolset == ""} {
        set errorString "TOOL settings not found or target makefiles do not exist"
        dbgputs "toolsetExtract error: $errorString"
        uninstLog setupLog "archive error: $errorString"
        return $defaultSet
    }

    return $toolset
}


##############################################################################
#
# archListPut - save the object filename
#
# This procedure checks the provided filename for a special pattent.  If
# matches, the filename will be saved in a global array for later archiving
# step.  The keys of this associated array are the object location, and product
# index.
#
# SYNOPSIS
# archListPut <fileName> <index>
#
# PARAMETERS:
#    fileName : a path filename
#    index : an index to a current product
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc archListPut {fileName index} {
    global setup_objects
    global setup_libraries
    global newArchive
    global setupVals

    # toolset and typeset can be a set of strings "|" together
    # "sfgnule|gnu..."

    set toolset $setupVals(toolset)
    set typeset "vx"

    if {[regexp "^.*/lib/obj(.*)($toolset)($typeset)(.*)/(.*$)" $fileName \
         junk cpu tool type typex tailFileName] == "1"} {

        set objDir "$index,obj,$cpu,$tool,$type,$typex"

        if [info exists setup_objects($objDir)] {
            if {[lsearch $setup_objects($objDir) $tailFileName] == "-1"} {
                lappend setup_objects($objDir) $tailFileName
            }
        } else {
            set setup_objects($objDir) [list $tailFileName]
        }
    }

    if {[regexp "^.*/lib/lib(.*)($toolset)($typeset)(.*).a" $fileName \
         junk cpu tool type typex] == "1"} {

        set objLib "$index,obj,$cpu,$tool,$type,$typex"
        set setup_libraries($objLib) lib$cpu$tool$type$typex.a
    }


    # For archiving format target/lib/PPC/ppc604/gnu/objcplus/foo.o

    if {[regexp "^.*/lib/(.*)/(.*)/(.*)/obj(.*)/(.*$)" $fileName \
         junk family cpu tool type tailFileName] == "1"} {
 
        set newArchive 1
        set objDir "$index,obj,$family,$cpu,$tool,$type"

        if [info exists setup_objects($objDir)] {
            if {[lsearch $setup_objects($objDir) $tailFileName] == "-1"} {
                lappend setup_objects($objDir) $tailFileName
            }
        } else {
            set setup_objects($objDir) [list $tailFileName]
        }
    }

    if {[regexp "^.*/lib/(.*)/(.*)/(.*)/lib(.*).a" $fileName \
         junk family cpu tool type] == "1"} {

        set objLib "$index,obj,$family,$cpu,$tool,$type"
        set setup_libraries($objLib) lib$type.a
    }
}

##############################################################################
#
# processInstall - process the return value from filesCopy routine
#
# SYNOPSIS
# processInstall <retVal>
#
# PARAMETERS: The return value from call to setupFileExtract in filesCopy
#
# RETURNS: string "break" if EOF encountered, else "NULL".
#
# ERRORS: N/A
#

proc processInstall {retVal fileName prodIndex} {
    global ctrlVals setupVals
    global current_file multipleVersion
    global overwritePolicy donotOverwrite

    set f [destDirGet]/$fileName

    switch $retVal {
        OK {
            uninstLog file "wind_base\t$fileName"

            # Build archList for later updating the archirve.

            archListPut $fileName $prodIndex
            setupFileNext
        }

        EXIST_AND_SAME {
            # Workaround the problem that the base product is
            # reinstalled, and messup the libraries.
            archListPut $fileName $prodIndex

            setupFileNext
        }

        EXIST_AND_NEWER {

            if { [isGUImode] } {
                # do not overwrite if auto install
                if { $ctrlVals(useInputScript) } {
                    archListPut $fileName $prodIndex; \
                    setupFileNext
                    return NULL
                }
            }

            if { [info exists overwritePolicy(ALL)] && $overwritePolicy(ALL) } {
                backup $fileName; \
                set newerFileArray($fileName) ""; \

                set fileRm [fileRemove $f]
                if { $fileRm == "IGNORE"} {
                    setupFileNext
                } elseif { $fileRm == 0 } { 
                    # for TEXT mode, if return value = 0, exit SETUP
                    if { ![isGUImode] } { return 0 }
                }
            } elseif { [info exists donotOverwrite(ALL)] && $donotOverwrite(ALL) } {
                archListPut $fileName $prodIndex; \
                setupFileNext

            } else {

                if { [isGUImode] } {
                    messageBeep -exclamation
                    set ret [dialog file_exists_newer_warn "Setup" \
                                [strTableGet FILESCOPY_FILE_EXISTS_NEWER_WARN] \
                                question 0]
                } else {
                    puts "\n\n[strTableGet FILESCOPY_FILE_EXISTS_NEWER_WARN]\n\n\
                          Choose 0: overwrite the existing file.\n\
                          Choose 1: do not overwrite the existing file.\n\
                          Choose 2: overwrite ALL files, do not prompt about\
                                    this again.
                          Choose 3: do not overwrite ANY newer files, do not\
                                    prompt about this again."
                    set ret [prompt]
                }

                switch -regexp -- $ret {
                    0  {backup $fileName; \
                        set newerFileArray($fileName) ""; \

                        set fileRm [fileRemove $f]

                        while { $fileRm == "RETRY" } {
                            set fileRm [fileRemove $f]
                        }

                        if { $fileRm == "IGNORE" } {
                            setupFileNext
                        } elseif { $fileRm == 0 } { 
                            # for TEXT mode, if return value = 0, exit SETUP
                            if { ![isGUImode] } { return 0 }
                        }
                    } 
                    1  {archListPut $fileName $prodIndex; \
                        setupFileNext
                    }
                    2  {set overwritePolicy(ALL) 1; \
                        backup $fileName; \
                        set newerFileArray($fileName) ""; \

                        set fileRm [fileRemove $f]
                        if { $fileRm == "IGNORE"} {
                            setupFileNext
                        } elseif { $fileRm == 0 } { 
                            # for TEXT mode, if return value = 0, exit SETUP
                            if { ![isGUImode] } { return 0 }
                        }
                    }
                    3  {set donotOverwrite(ALL) 1; \
                        archListPut $fileName $prodIndex; \
                        setupFileNext
                    }
                    "[eE][xX][iI][tT]"  { return 0 } # TEXTmode exit
                }
            }
        }

        EXIST_AND_OLDER {
           backup $fileName; \

           set fileRm [fileRemove $f]
           if { $fileRm == "IGNORE"} {
               setupFileNext
           } elseif { $fileRm == 0 } { 
               # for TEXT mode, if return value = 0, exit SETUP
               if { ![isGUImode] } { return 0 }
           }
        }

        MULTIPLE_VERSION {
            # Setup detected that the file being install has more
            # than one versions on the CD-ROM.

            if ![file exists $f._${prodIndex}_] {
                uninstLog setup "\t$f._${prodIndex}_: does not exist"
                setupFileNext
                return NULL
            }

            if {![info exists multipleVersion($fileName)]} {
                set multipleVersion($fileName) $prodIndex
            } else {
                # Check to see if there is a duplicate prodIndex
                set indexLocate [lsearch -exact \
                    $multipleVersion($fileName) $prodIndex]

                if {$indexLocate == -1} {
                    lappend multipleVersion($fileName) $prodIndex
                }
            }

            setupFileNext
        }

        NOT_FOUND {
            set msg [strTableGet FILESCOPY_DEFLATE_ERROR]
            set logMsg "\terror: cannot copy $fileName: not found"

            if { [isGUImode] } {
                if { $ctrlVals(useInputScript) } {
                    autoSetupLog "$logMsg"
                    autoSetupLog "Application Exit\n"
                    set setupVals(cancel) 1                
                    applicationExit
                    return 0
                }
            }

            if { [isGUImode] } {
                set ret [dialog re_ig_cancel "Setup" $msg question 0]
            } else {
                puts "\n\n$msg\n\nChoose 0: Retry\nChoose 1: Ignore\nChoose 2: Abort\n"
                set ret [prompt]
            }
            switch -- $ret {
                0 { return NULL }
                1 {
                    lastErrorSet $logMsg
                    uninstLog setup $logMsg
                    setupFileNext
                }
                2 {
                    # if TEXT mode, exit
                    if { ![isGUImode] } { return 0 }

                    quitCallback
                }
            }
        }

        ZIP_ERROR {
            set logMsg "\terror: can not copy $fileName: zip error"
            lastErrorSet $logMsg
            uninstLog setup $logMsg
            setupFileNext
        }

        MEMORY_LOW {
            set msg [strTableGet FILESCOPY_MEMORY_LOW_WARN]

            if { [isGUImode] } {
                if { $ctrlVals(useInputScript) } {
                    autoSetupLog "$msg"
                    autoSetupLog "Application Exit\n"
                    set setupVals(cancel) 1                
                    applicationExit
                    return 0
                }
            }

            if { [isGUImode] } {
                set ret [dialog ok_cancel "Setup" $msg question 0]
            } else {
                puts "\n\n$msg\n\nChoose 0: Continue\nChoose 1: Exit SETUP\n"
                set ret [prompt]
            }
            switch -- $ret {
                0 { return NULL }
                1 { 
                    # if TEXT mode, exit
                    if { ![isGUImode] } { return 0 }

                    quitCallback
                }
            }
        }

        NO_ZIP_FILE {
            set msg [strTableGet FILESCOPY_CDROM_READ_ERROR]
            set logMsg "\terror: cannot copy $fileName : no zip file"

            if { [isGUImode] } {
                if { $ctrlVals(useInputScript) } {
                    autoSetupLog "$logMsg"
                    autoSetupLog "Application Exit\n"
                    set setupVals(cancel) 1                
                    applicationExit
                    return 0
                }
            }
 
            if { [isGUImode] } {
                set ret [dialog re_ig_cancel "Setup" $msg question 0]
            } else {
                puts "\n\n$msg\n\nChoose 0: Retry\nChoose 1: Ignore\nChoose 2: Abort\n"
                set ret [prompt]
            }

            switch -- $ret {
                0 { return NULL }
                1 {
                    lastErrorSet $logMsg
                    uninstLog setup $logMsg
                    setupFileNext
                }
                2 { 
                    # if TEXT mode, exit
                    if { ![isGUImode] } { return 0 }

                    quitCallback
                }
            }
        }

        BAD_PARAM {
            set logMsg "\terror: cannot copy $fileName: bad param"
            lastErrorSet $logMsg
            uninstLog setup $logMsg
            setupFileNext
        }

        DISK_FULL {
            set msg [strTableGet FILESCOPY_DISK_FULL_WARN]

            if { [isGUImode] } {
                if { $ctrlVals(useInputScript) } {
                    autoSetupLog "$msg"
                    autoSetupLog "Application Exit\n"
                    set setupVals(cancel) 1                
                    applicationExit
                    return 0
                }
            }

            if { [isGUImode] } {
                set ret [dialog ok_cancel "Setup" $msg question 0]
            } else {
                puts "\n\n$msg\n\nChoose 0: Continue\nChoose 1: Exit SETUP\n"
                set ret [prompt]
            }
            switch -- $ret {
                0 {return NULL}
                1 {
                    set setupVals(diskfull) 1
                                    
                    # if TEXT mode, exit
                    if { ![isGUImode] } { return 0 }
    
                    quitCallback
                }
            }
        }

        UNEXPECT_EOF {
            set logMsg "\terror: can not copy $fileName: zip corrupt"
            lastErrorSet $logMsg
            uninstLog setup $logMsg
            setupFileNext
        }

        END_OF_LIST { return break }

        default {
            set msg "Setup was unable to copy $fileName from \
                    the CDROM due to $retVal.\n\n"

            if { [isGUImode] } {
                if { $ctrlVals(useInputScript) } {
                    autoSetupLog "$msg"
                    autoSetupLog "Application Exit\n"
                    set setupVals(cancel) 1                
                    applicationExit
                    return 0
                }
            } 
            if { [isGUImode] } {
                set ret [dialog re_ig_cancel "Setup" $msg question 0]
            } else {
                puts "\n\n$msg\nChoose 0: Retry\nChoose 1: Ignore\nChoose 2: Abort\n"
                set ret [prompt]
            }

            switch -- $ret {    
                0 { return NULL }
                1 {
                    set logMsg "\terror: cannot copy $fileName : $retVal"
                    lastErrorSet $logMsg
                    uninstLog setup $logMsg
                    setupFileNext
                }
                2 { 
                    # if TEXT mode, exit
                    if { ![isGUImode] } { return 0 }

                    quitCallback
                }
            }
        }
    }
    return NULL
}

##############################################################################
#
# fileRemove - remove the specified file
#
# This procedure removes the specified file, and if fails to do so, it's then
# popping up a dialog to query for the next action.
#
# SYNOPSIS
# fileRemove <fileName>
#
# PARAMETERS:
#    fileName : a path filename
#
# RETURNS:
#    OK     : successful removing <filename>
#    RETRY  : failed to remove the file, and user wants to retry.
#    IGNORE : failed to remove the file, and user wants to ignore it.
#
# ERRORS: N/A
#

proc fileRemove {fileName} {

    if [catch {file delete $fileName} error] {
        set msg [strTableGet FILESCOPY_FILE_ACCESS_ERROR $fileName $error]

        if { [isGUImode] } {
            set ret [dialog re_ig_cancel "Setup" $msg question 0]
        } else {
            puts "\n$msg\n\nChoose 0: Retry\nChoose 1: Ignore\nChoose 2: Cancel\n"
            set ret [prompt]
        }

        switch -- $ret {
            0 { return "RETRY" }
            1 {
                set logMsg "\terror: $fileName: $error"
                lastErrorSet $logMsg
                uninstLog setup $logMsg
                return "IGNORE"
            }
            2 { # cancel
                # if TEXT mode, exit
                if { ![isGUImode] } { return 0 }

                quitCallback
            }
        }
    }
    return "OK"
}

##############################################################################
#
# filesCopy - copies all the selected product files into the user destination
#             directory.
#
# This routine walks thru each selected product, and do the following actions:
#
#   - runs the preInstall.tcl if any
#   - creates a record to the setup.log
#   - obtains a list of sub-products, and do the following actions:
#
#      + calls setupFileSetMake to build the sub-product filelist
#      + calls setupFileExtract to extract each file from the filelist.
#        An internal pointer is advanced until it hits the end of the list.
#        The setupFileExtract function returns one of the following messages:
#
#        Message           Next actions
#        -------           ------------
#        OK                - creates uninstall record,  advances file pointer.
#        EXIST_AND_SAME    - skips this file
#        EXIST_AND_NEWER   - backup the original file, and extracts this file
#                            again
#        EXIST_AND_OLDER   - same as above
#        MULTIPLE_VERSION  - keeps the newer version of the file, backup the
#                            original if it's older.
#        NOT_FOUND         - queries for retry until user gives up.
#        ZIP_ERROR         - logs the error message into the setup.log
#        MEMORY_LOW        - queries user for continue or not.
#        NO_ZIP_FILE       - queries for retry until user gives up.
#        BAD_PARAM         - logs the error message into the setup.log
#        DISK_FULL         - queries user for continue or not.
#        UNEXPECT_EOF      - logs the error message into the setup.log
#        END_OF_LIST       - continues w/ the next sub-product.
#
#   - runs the postInstall.tcl if any
#
#
# SYNOPSIS
# filesCopy
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc filesCopy {} {
    global setupVals
    global ctrlVals
    global current_file
    global multipleVersion

    cd [destDirGet]

    set setupVals(cancel) 0
    set totalFiles [cdInfoGet totalFile]
    set desc "Unknown component"
    set i 0

    uninstLog setup "CD manufacturing time: [cdNameGet time]"
    uninstLog setup "[cdInfoGet number]\t$setupVals(version)\t[destDirGet]"
    uninstLog setup [cdNameGet description]

    # Append CD Info to the uninstall record

    uninstLog cdNumber "$setupVals(CDnumber)"

    # Add host OS to setup log

    if {[isUnix]} {
        catch {exec uname -a} hostOS
    } else {
        if [catch {setupWinVerGetEx} hostOS] {
            puts "error: $hostOS"
        }
    }
    uninstLog setup "$hostOS"

    # find products that specify to be installed last

    set firstList ""
    set lastList ""
    foreach prodIndex [cdInfoGet selectedProdIndexList] {
        if {[searchAndProcessSection InstallLast \
            [chooseInfFile $prodIndex]]==1} {
            puts "INF Processing: installing \
                  [productInfoGet name $prodIndex] last"
            set lastList [linsert $lastList end $prodIndex]
        } else {
            set firstList [linsert $firstList end $prodIndex]
        }
    }

    set sortedSelectedProdIndexList [concat $firstList $lastList]
    set licensedProds ""

    foreach prodIndex $sortedSelectedProdIndexList {

        currentIndexSet $prodIndex

        # Do preinstall if any
        execute [productInfoGet name $prodIndex]/preInstall.tcl

        # Append install info to the setup.log

        set featureID [productInfoGet featureId $prodIndex]
        set productName [productInfoGet name $prodIndex]
        set prodNum [productInfoGet number $prodIndex]
        set desc [productInfoGet desc $prodIndex]
        set current_product $desc

        # compile the list of licensed products

        if {[licensedProductCheck $featureID]} {
            lappend licensedProds "licensed product: $productName $featureID"
        }

        uninstLog setup "$prodNum\t$desc"
        if ![info exists setupVals(confirmation)] {
            set setupVals(confirmation) ""
        }

        lappend setupVals(confirmation) "$desc"

        # Append info to the uninstall record

        uninstLog info "$desc"

        # Begin the copy loop

        set prevFileName ""

        foreach partIndex [productInfoGet selectedPartIndexList $prodIndex] {

            set partDesc [partInfoGet desc $partIndex]

            if [catch {setupFileSetMake $partIndex} error] {
                uninstLog setup "\tskip installing $partDesc: $error"
                dbgputs "unable to install $partDesc: $error"
                lastErrorSet "$error"
                continue
            } else {
                dbgputs "Installing [productInfoGet desc $prodIndex] -> $partDesc"
            }

            while { 1 } {
                if {$setupVals(cancel) == 1} {return}

                set fileName [setupFileNameGet 0]
                set current_file [checkPathLen $fileName]

                # update meter

                set percent [expr $i * 100 / $totalFiles]
                meterUpdate $percent $fileName

                # GUI mode only
                if { [isGUImode] } {
                    if {![limitColors]} { bbrdUpdate $percent }
                }

                set f [destDirGet]/$fileName

                catch {setupFileExtract} retVal

                # change "group" and "other" execute permissions for Unix files.

                if {[isUnix]} { setExecutePermissions $f }

                dbgputs [format "%20s\t%s" $retVal $fileName]

                set instRet [processInstall $retVal $fileName $prodIndex]

                if { $instRet == "break" } {
                    break
                } elseif { $instRet == 0 } {
                    # for TEXT mode, return value = 0, exit SETUP
                    if { ![isGUImode] } { return 0 }
                }

                if {"$prevFileName" != "$fileName"} {
                    incr i
                    set prevFileName $fileName
                }
            }

        }
        execute [productInfoGet name $prodIndex]/postInstall.tcl
    }

    #
    # fix up multiple versions of file
    #
    set count 0
    set totalFiles [llength [array names multipleVersion]]

    foreach fileName [array names multipleVersion] {
        set percent [expr $count * 100 / $totalFiles]
        meterUpdate $percent "Resolving version conflicts..."
        incr count

        set f [destDirGet]/$fileName
        set numProdIndex [llength $multipleVersion($fileName)]
        set pIndx [lindex $multipleVersion($fileName) 0]

        #
        # Finds the latest version and keeps it.  Removes the older versions.
        # After this step, the pIndx variable will end up holding the latest
        # version.
        #
        if {$numProdIndex > 1} {
            for {set i 1} {$i < $numProdIndex} {incr i} {
                set pIndx1 [lindex $multipleVersion($fileName) $i]

                if {[file mtime $f._${pIndx}_] < [file mtime $f._${pIndx1}_]} {
                    catch {file delete $f._${pIndx}_}
                    set pIndx $pIndx1
                } else {
                    catch {file delete $f._${pIndx1}_}
                }
            }
        }

        #
        # Take the appropriate steps to save and log the file before removing
        # it (if exists), since we always want the newest version among those
        # just installed regardless of the relative timestamp of the existing
        # one and the new one.
        #
        if {[file exists $f]} {
            if {[file mtime $f] > [file mtime $f._${pIndx}_]} {
                set newerFileArray($fileName) ""
            }

            if {[file mtime $f] != [file mtime $f._${pIndx}_]} {
                backup $fileName
            }

            while {1} {
                set retVal [fileRemove $f]
                if {($retVal == "OK") || ($retVal == "IGNORE")} {
                    break
                } elseif { $retVal == 0 } {
                    # for TEXT mode, if return value = 0, exit SETUP
                    if { ![isGUImode] } { return 0 }
                }
            }
        }

        #
        # Finally, make the newest version among those installed from this
        # session be the official one for use.
        #
        if ![catch {file rename $f._${pIndx}_ $f}] {
            uninstLog file "wind_base\t$fileName"
            archListPut $fileName $pIndx
        }
    }

    # write to the log file the list of overwritten files.

    if {[llength [array names newerFileArray]] > 0} {
        uninstLog setup ""
        uninstLog setup "SETUP has overwritten the following files which"
        uninstLog setup "are newer than those on the CDROM.  Original files"
        uninstLog setup "are zipped into $setupVals(uninstFile)."
        uninstLog setup "Use any unzip utility in case you need to get back"
        uninstLog setup "original version of the files."
        uninstLog setup ""

        foreach file [lsort [array names newerFileArray]] {
            uninstLog setup "\t$file"
        }
    }

    # write list of licensed products (if any) to setup.log

    if { [info exists licensedProds] && $licensedProds != "" } {
        uninstLog setup ""
        foreach prod $licensedProds {
            uninstLog setup $prod
        }
        uninstLog setup ""
    }
}

##############################################################################
#
# listDir - lists recursively Setup files/folders in a directory
#
# This procedure lists recursively the directories and files that reside in
# the Setup path passed as input.  The results are kept in a global array
# setupVals(setupFiles).
#
# SYNOPSIS
# listDir <dir>
#
# PARAMETERS: <dir> is the path to the Setup files on the CD ROM
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc listDir {dir} {

    global setupVals

    set setupFilesList [glob -nocomplain [file join $dir *]]

    foreach file $setupFilesList {
        set newDir [file join $dir $file]
        if ![file isdirectory $newDir] {
            lappend setupVals(setupFiles) $newDir
        } else {
            listDir $newDir
        }
    }
}

##############################################################################
#
# setupCopy - copies the Setup files from the CD ROM to the user's disk
#
# This procedure copies the Setup file from the CD ROM to the user's
# destination directory under $WIND_BASE.
#
# SYNOPSIS
# setupCopy
#
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#
proc setupCopy {} {
    global setupVals
    global tornadoInstalled

    set windDir [file join [destDirGet] SETUP WIND]
    catch {file mkdir $windDir}

    listDir "[cdromRootDirGet]/"

    if ![info exists setupVals(setupFiles)] {
        uninstLog setup "setupCopy: cannot obtain list of setup files"
        return
    }

    # skip copying non-native-host files under SETUP directory

    set setupFiles ""
    foreach file $setupVals(setupFiles) {
        if { [windHostTypeGet] == "sun4-solaris2" ||
             [windHostTypeGet] == "parisc-hpux10"    } {
            switch -regexp $file {
                DISK_ID|disk_id {}
                /WIND/|/wind/ {}
                /X86/|/x86/ {}
                default { lappend setupFiles $file }
            }
        } elseif { [windHostTypeGet] == "x86-win32" ||
                   [windHostTypeGet] == "x86-linux2" } {
            switch -regexp $file {
                DISK_ID|disk_id {}
                /WIND/|/wind/ {}
                /SUN4/|/sun4/ {}
                /X86/|/x86/ {
                    # for X86, separate Windows and Linux

                    if { [windHostTypeGet] == "x86-win32" } {
                        switch -regexp $file {
                            X86/LINUX2/|x86/linux2/ {}
                            default { lappend setupFiles $file }
                        }
                    } else { # linux
                        switch -regexp $file {
                            X86/WIN32/|x86/win32/ -
                            X86/WINNT/|x86/winnt/ {}
                            default { lappend setupFiles $file }
                        }
                    }
                }
                default { lappend setupFiles $file }
            }
        }
    }

    set count 0
    set totalFiles [llength $setupFiles]

    foreach file $setupFiles {
        if {$setupVals(cancel) == 1} {return}

        set percent [expr $count * 100 / $totalFiles]
        meterUpdate $percent "Preparing to copy files ..."
        incr count

        # remove "[cdromRootDirGet]" from file name
        regsub [dosToUnix [cdromRootDirGet]] [dosToUnix $file] {} rawFile

        # remove forward slash from rawFile so "file join" could work
        regsub "\/" $rawFile {} rawFile

        set destFile "[file join [dosToUnix [destDirGet]] SETUP $rawFile]"

        dbgputs [format "%20s\t%s" SETUP_COPY $destFile]
        fileDup $file $destFile update
 
    }
}

##############################################################################
#
# bbrdListGet - obtains a list of bitmaps
#
# This routine walks thru all selected products, and extracts the available
# bitmaps.
#
# SYNOPSIS
# bbrdListGet <extension>
#
# PARAMETERS:
#    <extension> : bitmap file extension, supported extension are .BMP and .PPM
#
# RETURNS: a list of bitmap filename.
#
# ERRORS: N/A
#

proc bbrdListGet {extension} {
    global ctrlVals

    set retVal ""
    set newList ""

    if {[windHostTypeGet] == "x86-win32"} {
        set zipFile [cdromZipDirGet]\\WIND.000
    } else {
        set zipFile [cdromZipDirGet]/WIND.000
    }

    set prodNameList "prologue"
    lappend prodNameList [cdInfoGet selectedProdNameList]
    lappend prodNameList "epilogue"
    set prodNameList [join $prodNameList]

    foreach prodName $prodNameList {
        if ![catch {setupUnzip -o -qq -d [tempDirGet] $zipFile \
                    "$prodName/*$extension"} error] {

            set saveDir [pwd]
            cd [tempDirGet]/$prodName

            set bbrdList [glob -nocomplain "*$extension"]

            foreach bbrdFile $bbrdList {
                if {[windHostTypeGet] == "x86-win32"} {
                    lappend newList "[tempDirGet]\\$prodName\\$bbrdFile"
                } else {
                    lappend newList "[tempDirGet]/$prodName/$bbrdFile"
                }
            }
            cd $saveDir
        }
    }
    return $newList
}

##############################################################################
#
# execute - executes product pre/postInstall tcl script
#
# This procedure extracts the provided tclFile, if exists, then evaluates it.
#
# SYNOPSIS
# execute <tclFile>
#
# PARAMETERS:
#    <tclFile> : product preInstall.tcl or postInstall.tcl
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc execute {tclFile} {

    set zipFile [cdromZipDirGet]/WIND.000

    if {[file exists $zipFile]} {
        if ![catch {setupUnzip -o -qq -d [tempDirGet] \
                    $zipFile $tclFile} retVal] {
            if ![catch {open [tempDirGet]/$tclFile "r"} fp] {
                set retVal [read $fp]
                catch { close $fp } err

                dbgputs "Evaluating $tclFile"
                dbgputs "$retVal"

                if [catch {eval $retVal} error] {
                    puts "$error"
                }
            }
        }
    }
}

#############################################################################
#
# limitColors - determine whether environment variable SETUP_LIMITCOLORS is set
#
# This procedure will determine whether environment variable
# SETUP_LIMITCOLORS is set
#
# SYNOPSIS
# .tS
# limitColors
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: 0 if enviroment variable SETUP_LIMITCOLORS is not set
#          1 if enviroment variable SETUP_LIMITCOLORS is set
#
# ERRORS: N/A
#

proc limitColors {} {
    global env

    if {[info exists env(SETUP_LIMITCOLORS)]} {
        if {$env(SETUP_LIMITCOLORS)==1} {
            return 1
                }
    }

    return 0
}

#############################################################################
#
# bbrdUpdate - update the billboard
#
# This procedure will update the billboard
#
# SYNOPSIS
# .tS
# bbrdUpdate <percent>
# .tE
#
# PARAMETERS:
# .IP percent
# percentage of billboards that have been shown
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc bbrdUpdate {percent} {
    global ctrlVals

    if { $percent > $ctrlVals(bbrdElapse) } {

        incr ctrlVals(bbrdElapse) $ctrlVals(displayInt)

        set prevBbrdIndex $ctrlVals(nextBbrd)
        incr ctrlVals(nextBbrd)

        if { [lindex $ctrlVals(bbrdList) $ctrlVals(nextBbrd)] != "" } {
            controlValuesSet $ctrlVals(bbrdWindow).bbrd \
                    [lindex $ctrlVals(bbrdList) $ctrlVals(nextBbrd)]
        }
    }
}




######################################################################
# Dialog Text Messages
######################################################################

set strTable(FILESCOPY_TITLE) "Installation in Progress"

set strTable(FILESCOPY_LABEL) \
    "format %s \"SETUP is installing the product(s) you selected in\
                \[destDirGet\].\""


set strTable(FILESCOPY_FILE_EXISTS_NEWER_WARN) \
     "format %s \"The file \'\$current_file\' exists in your destination\
                directory path \'\[destDirGet\]\' and is newer.  You can\
                set the policy for handling duplicate files by\
                selecting one of the following options.  All files to be\
                overwritten will be backed up.\""

set strTable(FILESCOPY_DEFLATE_ERROR) \
    "format %s \"SETUP isn\'t able to deflate \[setupFileNameGet 0\]\
                 \n\nPlease select one of the following options\
                 to continue with the SETUP process.\""

set strTable(FILESCOPY_MEMORY_LOW_WARN) \
    "The system is running out of memory.  To continue, close applications\
     or increase the system swap space."

set strTable(FILESCOPY_DISK_FULL_WARN) \
    "No disk space left.  To continue, free up some disk space."

set strTable(FILESCOPY_CDROM_READ_ERROR) \
    "format %s \"SETUP cannot read \[setupFileNameGet 0\] from the CD-ROM.\
    Please ensure that the CD-ROM is properly mounted.\""

set strTable(FILESCOPY_FILE_ACCESS_ERROR) \
    "format %s \"SETUP cannot create/update file \[lindex \$args 0\]:\
    \[lindex \$args 1\]\""

