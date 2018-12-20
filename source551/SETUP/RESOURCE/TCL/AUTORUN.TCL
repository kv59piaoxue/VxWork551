# AUTORUN.TCL - AutoRun for the CD-ROM to install products
#
# Copyright 1996-1999, Wind River Systems, Inc.
#
# modification History
# --------------------
# 03b,05mar02,bwd  Modified SETUP to be non-tornado centric
# 03a,12jun01,j_w  Modified for Tornado 2.2
# 02e,02nov00,j_w  name change - Tornado AE
# 02d,09jun00,bwd  Added another host type check for x86-linux2
# 02c,21oct99,bjl  removed parisc-hpux support, added passing of command
#                  line arguments for Windows.
# 02b,23apr99,wmd  make check for SETUP_DEBUG to be > 0.
# 02a,28jan99,bjl  removed preview and slide show code, added headers and
#                  edited for coding conventions.
# 01n,23nov98,tcy+ remove trailing slash for INSTW32.TCL CD root argument.
#             bjl
# 01m,13nov98,bjl  bypass AutoRun and directly run Setup.
# 01l,12nov98,bjl  changed Add Icons to Remote Icons, hide buttons instead
#                  of disabling if .TXT files do not exist.
# 01k,11nov98,bjl  use /bin/more when EDITOR is not set (spr #23166). Removed
#                  -w option from /bin/more for parisc-hpux10.
# 01i,10nov98,bjl  placed buttons closer together to allow for large
#                  font setting in Windows (spr #23004).
# 01h,30oct98,bjl  use 16 color bitmap if color manager is not running.
# 01g,28oct98,bjl  dos2unix .TXT files before opening for Unix, run Setup
#                  automatically if using test answer file.
# 01f,27oct98,bjl  added code for Unix, removed loading of setuptcl.dll.
# 01e,26oct98,bjl  changed button callbacks to run UITclSh instead of
#                  setup.exe, added check for debug console.
# 01d,17sep98,bjl  removed soundPlay and preview button.
# 01c,03aug98,bjl  load UITclControls.dll, added What's New and Add Icons
#                  buttons.
# 01b,23jul98,wmd  modified for T2, added new dialogs
# 01a,-------,pdn
#
# DESCRIPTION
# This module contains the Autorun functions that are executed when the
# product CD-ROM is inserted.  It also contains the initial splash
# screen functionality.
#
# RESOURCE FILES
# RESOURCE/TCL/GLOBAL.TCL
# */

# globals

set setup_lib       ""      ;# The handle to the setupTclDll
set tempDir         ""      ;# The location to which files are unzipped
set autorunBypass   1       ;# Bypass Autorun and directly run Setup.

#############################################################################
#
# tornadoAutoRun@@Init - the Autorun dialog initialization function.
#
# This procedure sets up the controls for the Autorun dialog.
#
# SYNOPSIS:
# tornadoAutoRun@@Init
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc tornadoAutoRun@@Init {} {
    upvar setup_lib setup_lib
    global env

    # choose a 16 color bitmap if no color manager is running,
    # otherwise choose the default 256 color bitmap.

    if {[info exists env(SETUP_NOCOLORMGR)]} {
        if {$env(SETUP_NOCOLORMGR)==1} {
            set torbitmap "TOR16.BMP"
        } else {
            set torbitmap "TOR256.BMP"
        }
    } else {
        set torbitmap "TOR256.BMP"
    }

    # create the bitmap control.

    controlCreate tornadoAutoRun@@ \
        [list bitmap -x 8 -y 8 -name bitmap -hidden \
          -title [CDDriveGet]RESOURCE/BITMAPS/$torbitmap]

    # create the Setup button.

    controlCreate tornadoAutoRun@@ [list \
        button -w 50 -height 16 -hidden -title "&Setup" -name setupButton \
        -callback {
            global env

            # add the "-C" option for UITclSh to bring up the debug
            # console.

            if {[info exists env(SETUP_DEBUG)] && $env(SETUP_DEBUG) > 1} {
                set option "-C"
            } else {
                set option ""
            }

            # run INSTW32.TCL and close the Autorun window.

            if {[isUnix]} {
                if {[catch {exec [tempDirGet]/UITclSh \
                        [CDDriveGet]RESOURCE/TCL/INSTW32.TCL [CDDriveGet] &}\
                        error]} {
                    messageBox $error
                } else {
                    tornadoAutoRun@@windowClose
                }
            } else {
                # remove trailing slash using "string trimright" since
                # an extra slash is added in INSTW32.TCL.  Two slashes
                # does not work under W95 (e.g. c:\\).

                if {[catch {processCreate "[CDDriveGet]X86/WIN32/UITCLSH.EXE \
                            $option [CDDriveGet]RESOURCE/TCL/INSTW32.TCL \
                            [string trimright [CDDriveGet] \\]"} error]} {
                    messageBox $error
                } else {
                    tornadoAutoRun@@windowClose
                }
            }
        }]

    # create the Remote Icons button.

    controlCreate tornadoAutoRun@@ [list \
        button -w 50 -height 16 -hidden -title "Remote &Icons" \
                -name addiconButton \
                -callback {
                    global env

                    # run the Remote Icon installation.

                    if {[info exists env(SETUP_DEBUG)] && \
                        $env(SETUP_DEBUG) > 1} {
                        set option "-C"
                    } else {
                        set option ""
                    }
                    if {[catch {processCreate \
                        "[CDDriveGet]X86/WIN32/UITCLSH.EXE $option \
                         [CDDriveGet]RESOURCE/TCL/INSTW32.TCL [CDDriveGet]\
                          /ICON"} error]} {
                        messageBox $error
                    } else {
                        tornadoAutoRun@@windowClose
                    }
                }]

    # create the Read Me button.

    controlCreate tornadoAutoRun@@ [list \
        button -w 50 -height 16 -hidden -title "&Read Me..." \
        -name readmeButton \
        -callback {
             if {[isUnix]} {
                 global env

                 if [file exist [CDDriveGet]README.TXT] {
                     if { $env(WIND_HOST_TYPE) == "sun4-solaris2" ||
                          $env(WIND_HOST_TYPE) == "x86-linux2" } {

                         # use dos2unix on the text file for Unix,
                         # otherwise ^M's appear in the editor.

                         if {[catch {exec /bin/dos2unix \
                             [CDDriveGet]README.TXT > \
                             [tempDirGet]/README.TXT} error]} {
                             set filename "[CDDriveGet]README.TXT"
                         } else {
                             set filename "[tempDirGet]/README.TXT"
                         }
                     } elseif {$env(WIND_HOST_TYPE)=="parisc-hpux10"} {
                         if {[catch {exec /bin/dos2ux \
                             [CDDriveGet]README.TXT > \
                             [tempDirGet]/README.TXT} error]} {
                             set filename "[CDDriveGet]README.TXT"
                         } else {
                             set filename "[tempDirGet]/README.TXT"
                         }
                     } else {
                         set filename "[CDDriveGet]README.TXT"
                     }
                     catch {[editorCommand $filename]} error
                 } else {
                     messageBox -exclam "No README available at this time."
                 }
             } else {
                 # display README using Notepad on Windows

                 if [file exist [CDDriveGet]README.TXT] {
                     if {[catch [list processCreate \
                        "notepad.exe [CDDriveGet]README.TXT"] error]} {
                        messageBox $error
                     }
                 } else {
                    messageBox -exclam "No README available at this time."
                 }
             }
        }]

    # create What's New button.

    controlCreate tornadoAutoRun@@ [list \
        button -w 50 -height 16 -hidden -title "&What's New..." \
        -name whatsnewButton \
        -callback {
            if {[isUnix]} {
                global env
                
                if [file exist [CDDriveGet]NEW.TXT] {
                    if { $env(WIND_HOST_TYPE) != "x86-win32" ||
                         $env(WIND_HOST_TYPE) == "x86-linux2" } {

                        # use dos2unix on the text file for Unix,
                        # otherwise ^M's appear in the editor.

                        if {[catch {exec /bin/dos2unix \
                            [CDDriveGet]NEW.TXT > [tempDirGet]/NEW.TXT}\
                            error]} {
                            set filename "[CDDriveGet]NEW.TXT"
                        } else {
                            set filename "[tempDirGet]/NEW.TXT"
                        }
                    } elseif {$env(WIND_HOST_TYPE)=="parisc-hpux10"} {
                        if {[catch {exec /bin/dos2ux [CDDriveGet]NEW.TXT \
                            > [tempDirGet]/NEW.TXT} error]} {
                            set filename "[CDDriveGet]NEW.TXT"
                        } else {
                            set filename "[tempDirGet]/NEW.TXT"
                        }
                    } else {
                        set filename "[CDDriveGet]NEW.TXT"
                    }
                    catch {[editorCommand $filename]} error
                } else {
                    messageBox -exclam "WHAT'S NEW not available at this time."
                }
            } else {

                # display file on Windows using Notepad.

                if [file exist [CDDriveGet]NEW.TXT] {
                    if {[catch [list processCreate \
                        "notepad.exe [CDDriveGet]NEW.TXT"] error]} {
                        messageBox $error
                    }
                } else {
                        messageBox -exclam "WHAT'S NEW not available at this\
                                            time."
                }
            }
        }]

    # create Exit button.

    controlCreate tornadoAutoRun@@ [list \
        button -w 50 -height 16 -hidden -title "E&xit" -name exitButton \
        -callback tornadoAutoRun@@windowClose]

    welcomePageLayoutPrepare
}

#############################################################################
#
# welcomePageLayoutPrepare - displays the Autorun dialog.
#
# This procedure sets up the controls and displays the Autorun dialog.
#
# SYNOPSIS:
# welcomePageLayoutPrepare
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc welcomePageLayoutPrepare {} {
    global env
    global autorunBypass
    global argv

    # Retrieve the bitmap's width and height in dialog units.

    set bitmapW [lindex [controlSizeGet tornadoAutoRun@@.bitmap] 0]
    set bitmapH [lindex [controlSizeGet tornadoAutoRun@@.bitmap] 1]

    # Resize the dialog now that we know the bitmap's size in dialog units.

    windowSizeSet tornadoAutoRun@@ \
        [expr 8 + $bitmapW + 8 + 50 + 8] [expr 8 + $bitmapH + 8]

    windowTitleSet tornadoAutoRun@@ "Welcome to [getProdInfo name]"

    controlHide tornadoAutoRun@@.bitmap 0

    # set the button coordinates.

    set buttonxpos [expr 8 + $bitmapW + 8]
    set button1ypos 8
    set button2ypos [expr 8 + 13 + 8]
    set button3ypos [expr 8 + 13 + 8 + 13 + 8]
    set button4ypos [expr 8 + 13 + 8 + 13 + 8 + 13 + 8]

    # Unix does not have a Remote icon button.

    if {[isUnix]} {
        controlPositionSet tornadoAutoRun@@.setupButton $buttonxpos \
                                                        $button1ypos
        controlPositionSet tornadoAutoRun@@.readmeButton $buttonxpos \
                                                         $button2ypos
        controlPositionSet tornadoAutoRun@@.whatsnewButton $buttonxpos \
                                                           $button3ypos
    } else {
        controlPositionSet tornadoAutoRun@@.setupButton $buttonxpos \
                                                        $button1ypos
        controlPositionSet tornadoAutoRun@@.addiconButton $buttonxpos \
                                                          $button2ypos
        controlPositionSet tornadoAutoRun@@.readmeButton $buttonxpos \
                                                         $button3ypos
        controlPositionSet tornadoAutoRun@@.whatsnewButton $buttonxpos \
                                                           $button4ypos
    }

    controlPositionSet tornadoAutoRun@@.exitButton [expr 8 + $bitmapW + 8] \
                                                   [expr 8 + $bitmapH - 16]

    # display the buttons.

    controlHide tornadoAutoRun@@.setupButton 0
    if {![isUnix]} {
        controlHide tornadoAutoRun@@.addiconButton 0
    }
    controlHide tornadoAutoRun@@.exitButton 0
    if [file exist [CDDriveGet]README.TXT] {
        controlHide tornadoAutoRun@@.readmeButton 0
    }
    if [file exist [CDDriveGet]NEW.TXT] {
        controlHide tornadoAutoRun@@.whatsnewButton 0
    }

    # Automatically run INSTW32.TCL if autorunBypass is set or if
    # the automated test answer file is being used.

    if { $autorunBypass || [info exists env(SETUP_ANS_FILE)]} {

        # add the "-C" option for UITclSh for the debug console.
        if {[info exists env(SETUP_DEBUG)] && $env(SETUP_DEBUG) > 1} {
            set option "-C"
        } else {
            set option ""
        }

        # run UITclSh with INSTW32.TCL and close the Autorun window.

        if {[isUnix]} {
            if {[catch {exec [tempDirGet]/UITclSh \
                [CDDriveGet]RESOURCE/TCL/INSTW32.TCL [CDDriveGet] &} error]} {
                messageBox $error
            } else {
                tornadoAutoRun@@windowClose
            }
        } else {
            # remove trailing slash using "string trimright" since an extra
            # slash is added in INSTW32.TCL.  Two slashes does not work under
            # W95 (e.g. c:\\).

            if {[catch {processCreate "[CDDriveGet]X86/WIN32/UITCLSH.EXE \
                $option [CDDriveGet]RESOURCE/TCL/INSTW32.TCL [string \
                trimright [CDDriveGet] \\] [lrange $argv 1 [expr [llength $argv] - 1]]"} error]} {
                messageBox $error
            } else {
                tornadoAutoRun@@windowClose
            }
        }
    }
}

#############################################################################
#
# tornadoAutoRun@@windowClose - closes the Autorun dialog window.
#
# This procedure closes the Autorun dialog window.
#
# SYNOPSIS:
# tornadoAutoRun@@windowClose
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc tornadoAutoRun@@windowClose {} {

    autoTimerCallbackSet tornadoAutoRun@@ 0
    windowClose tornadoAutoRun@@
}

#############################################################################
#
# tornadoAutoRunShow - creates the Autorun dialog.
#
# This procedure creates the Autorun dialog.
#
# SYNOPSIS:
# tornadoAutoRunShow
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc tornadoAutoRunShow {} {
    dialogCreate -name tornadoAutoRun@@ \
        -w 100 -h 100 -init tornadoAutoRun@@Init \
        -nocontexthelp \
        -exit {
            catch {global setup_lib}
            if {$setup_lib != ""} {
                dllUnload $setup_lib
                set setup_lib ""
            }
        } \
        -nocontexthelp
}

#############################################################################
#
# CDDriveGet - returns the root of the Setup tree.
#
# This procedure returns the root of the Setup image tree based on
# the path of UITclSh.
#
# SYNOPSIS:
# tornadoAutoRunShow
#
# PARAMETERS: N/A
#
# RETURNS:
# the root of the Setup tree, terminated with `\` for Windows
# or '/' for Unix.
#
# ERRORS: N/A
#

proc CDDriveGet {} {
    if {[isUnix]} {
        global env

        return "$env(CD_ROOT)/"
    } else {
        set remainder [info nameofexecutable]
        set drive ""

        regsub -all {/} $remainder {\\} remainder

        # Check for UNC

        set index [string first "\\" $remainder]

        if {$index != -1} {
            # Parse out UNC segment with '\\' intact
            set uncSeg $remainder
            set remainder [string range $remainder 2 end]
            set index [string first "\\" $remainder]

            set drive [string range $uncSeg 0 [expr $index + 2]]
            set remainder [string range $remainder [expr $index + 1] end]
        }

        # Set remainder to a list describing the image root

        set remainder [file split $remainder]
        set remainder [lrange $remainder 0 [expr [llength $remainder] - 4]]

        # String remainder back into a '\' separated path, ending in '\'
        foreach elem $remainder {
            set drive "$drive$elem\\"
        }
        return $drive
    }
}

#############################################################################
#
# tempDirGet - returns the temporary directory to which files
#              have been extracted.
#
# This procedure returns the path location for, or to which, files
# have been extracted.  If TMP or TEMP are not found, C:/TMP is
# created.
#
# SYNOPSIS:
# tempDirGet
#
# PARAMETERS: N/A
#
# RETURNS:
# the temporary directory.
#
# ERRORS: N/A
#

proc tempDirGet {} {
    global env
    global tempDir

    if {$tempDir == ""} {
        set envList [array names env]
        foreach var $envList {
            if {![string compare [string tolower $var] tmp]} {
                set tempDir $env($var)
                break
            } elseif {![string compare [string tolower $var] temp]} {
                set tempDir $env($var)
                break
            }
        }

        # If we can't find TMP, then create it
        if {$tempDir == ""} {
            if [file mkdir c:/TMP] {
                set env(TMP) c:/TMP
                set tempDir c:/TMP
            }
        }
    }

    # Must end in '/'

    regsub -all {\\} $tempDir / tempDir
    if {[string index $tempDir [expr [string length $tempDir] - 1]] != "/"} {
        set tempDir "$tempDir/"
    }
    return $tempDir
}

#############################################################################
#
# isUnix - returns whether the host machine is a Unix machine.
#
# This procedure returns whether the host machine is a Unix machine.
# This is determined by either the environment setting for WIND_HOST_TYPE,
# or by the existence of MWHOME if WIND_HOST_TYPE has not been set.
#
# SYNOPSIS:
# isUnix
#
# PARAMETERS: N/A
#
# RETURNS:
# 1 if a Unix host.
# 0 if not a Unix host.
#
# ERRORS: N/A
#

proc isUnix {} {
    global env

    if {[info exists env(WIND_HOST_TYPE)]} {
        if {[string match sun4* $env(WIND_HOST_TYPE)]} {
            return 1;
        } elseif {[string match "x86-linux2" $env(WIND_HOST_TYPE)]} {
            return 1;
        } elseif {[string match parisc* $env(WIND_HOST_TYPE)]} {
            return 1;
        } else {
            return 0;
        }
    } else {
        return [info exists env(MWHOME)]
    }
}

#############################################################################
#
# editorCommand - returns the command to execute an editor on Unix.
#
# This procedure returns the tcl command the execute an editor with
# the specified filename on a Unix host.  The editor used is the value
# set for the environment variable EDITOR.  If the variable is not set,
# or if EDITOR is set to an unsupported editor, an xterm using the
# "more" command is used to display the file.  Supported editors are
# vi, emacs, and xemacs.
#
# SYNOPSIS:
# editorCommand filename
#
# PARAMETERS:
# <filename>
# the file to edit.
#
# RETURNS:
# the tcl command to open the editor with the specified file.
#
# ERRORS: N/A
#

proc editorCommand {filename} {
    global env

    if {[info exists env(EDITOR)]} {
        switch $env(EDITOR) {
            vi { return [exec xterm -title [file tail $filename] -e vi\
                 $filename &] }
            emacs { return [exec emacs $filename &] }
            xemacs { return [exec xemacs $filename &] }
            default {
                if { $env(WIND_HOST_TYPE) == "sun4-solaris2" ||
                     $env(WIND_HOST_TYPE) == "x86-linux2" } {                  
                    return [exec xterm -title [file tail $filename] -e \
                            /bin/more -w $filename &]
                } elseif {$env(WIND_HOST_TYPE) == "parisc-hpux10"} {
                    return [exec xterm -title [file tail $filename] -e \
                            /bin/more $filename &] 
                }               
            }
        }
    } else {
        # EDITOR environment variable not set

        if {$env(WIND_HOST_TYPE) == "sun4-solaris2" ||
            $env(WIND_HOST_TYPE) == "x86-linux2" } {
            return [exec xterm -title [file tail $filename] -e /bin/more \
                    -w $filename &]
        } elseif {$env(WIND_HOST_TYPE) == "parisc-hpux10"} {
            return [exec xterm -title [file tail $filename] -e /bin/more \
                    $filename &] 
        }  
    }
}

#############################################################################
# AUTORUN.TCL - Initialization code
#
# This code is executed when the file is sourced.  It sources GLOBAL.TCL,
# loads UITclControls.dll, and executes the entry routine tornadoAutoRunShow.
#

source [CDDriveGet]/RESOURCE/TCL/GLOBAL.TCL
source [CDDriveGet]/RESOURCE/TCL/INCLUDE.TCL
source [CDDriveGet]/RESOURCE/TCL/CONFIG.TCL

# load the UITclControls dll.

if {[isUnix]} {
    if { $env(WIND_HOST_TYPE) == "sun4-solaris2" ||
         $env(WIND_HOST_TYPE) == "x86-linux2" } {
        dllLoad [tempDirGet]/libuitclcontrols.so _UITclControls_Init
    } elseif {$env(WIND_HOST_TYPE) == "parisc-hpux10"} {
        dllLoad [tempDirGet]/libuitclcontrols.sl _UITclControls_Init
    }

} else {
    dllLoad [CDDriveGet]X86/WIN32/UITCLCONTROLS.DLL _UITclControls_Init
}

catch {tornadoAutoRunShow}
