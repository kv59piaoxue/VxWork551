# SYSCONFG.TCL  - Setup procedures for implementing system-configuration
#                 wizard page
#
# Copyright 1999 Wind River Systems, Inc
#
# modification history
# --------------------
# 03m,08oct03,s_l  Fix torVars.sh for DIAB_HOST_TYPE
# 03l,23sep03,s_l  Fix and error while seting the env DIAB_HOST_TYPE.
# 03k,26aug03,s_l  Changed set to setenv from the csh file.
# 03k,26aug03,s_l  Added variable DIAB_HOST_TYPE to torVars.bat section.
# 03j,14jan03,wmd  Fix SPR #85387 - do not reset WIND_BASE if it already
#                  exists.
# 03i,17may02,j_w  Fixed error in torRegNTServ
# 03h,13may02,j_w  SPR 74991 - Replaced the Tornado Registry service only if
#                  the user selects the NT service option
# 03h,09may02,bwd  SPR 76374: fixed to use tcl command to search for files
# 03g,11apr02,bwd  SPR 75292: backed out the change done for spr 72382 to fix
#                  multiple windows flashing
# 03f,02apr02,bwd  SPR 72382: more fixes to generate toolchain info file
# 03e,01apr02,bwd  SPR 72910: backward compatibility for T2.0.x archiving
#                  SPR 72382: Added codes to regenerate toolchain info files
# 03d,05mar02,bwd  Modified SETUP to be non-tornado centric
# 03c,07dec01,j_w  Added procedure torVarsCreateDiab
# 03b,20sep01,bwd  SPR 70287: invoke windxRegen.tcl to rebuild windex 
#                  database.
# 03a,12jun01,j_w  Modified for Tornado 2.2
# 01v,01nov00,bwd  SPR 35597: Remove HELP button
# 01u,18oct00,j_w  Do not update html help viewer if it is win2000 and the
#                  user has not admin privilege
# 01t,17oct00,j_w  Update hh.exe on user's winnt directory for windows
#                  installation (to version 1.32)
# 01s,28jun00,wmd  Fix spr # 32228, torVars fixes.
# 01r,16jun00,wmd  Modify so that htmlBook.tcl doesn't run for Windows.
# 01q,12jun00,wmd  Add SETUP/X86/WIN32 to the PATH env. var. for ZIP/UNZIP
# 01p,09jun00,bwd  Added another host type check for x86-linux2
# 01o,31may00,j_w  Stopped any running Tornado Registry Service before
#                  installing a new one (SPR 31616)
# 01n,19apr00,bwd  Comment out codes that update hh. SETUP now uses HTML pages
#                  for HELP
# 01m,02feb00,bwd  Changed setupVals(cmdMode) to use isGUImode
# 01l,06jan00,bwd  No test automation for command line SETUP
# 01k,06dec99,j_w  Update hh.exe on user's winnt directory for windows
#                  installation
# 01k,23nov99,clc  add text mode
# 01j,21oct99,bjl  removed parisc-hpux support.
# 01i,20apr99,wmd  Modify to add $WIND_BASE/host/$WIND_HOST_TYPE/lib/to
#                  LD_LIBRARY_PATH, etc.
# 01h,24mar99,tcy  moved code for opening program folder to FINISH page
# 01g,19mar99,wmd  Output to a file any debug messages.
# 01f,10feb99,bjl  added LD_LIBRARY_PATH for solaris hosts.
# 01e,10feb99,tcy  fixed USER condition
# 01d,02feb99,tcy  added USER line torVars.csh/sh (fix for SPR 24724)
# 01c,01feb99,tcy  moved torVarsCreate() from INSTALL.TCL;
#                  redo messages
# 01b,28jan99,tcy  made the meter blue.
# 01a,26jan99,tcy  extracted from FINISH.TCL.
#

#############################################################################
#
# pageCreate(systemConfig) - configure user system for Tornado
#
# This procedure will display a wizard page showing what Setup is doing
# to configure the system:
# - Updating the Windows registry for Tornado (Windows only)
# - Installing Tornado program group icons (Windows only)
# - Creating torVars.bat/csh
# - Configuring on-line HTML help
# - rebuild windex database (invoke tcl script)
# - Create make files under target/h/make for backward compatibility
# - Re-generate toolchain info files for Project Facility
#
# SYNOPSIS
# .tS
# pageCreate(systemConfig)
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc pageCreate(systemConfig) {} {
    global ctrlVals
    global tornadoInstalled
    global env
    global setupVals

    set msg "SETUP is performing final steps to finish installation."

    if { [isTornadoProduct] } {
        if {[isUnix]} {
            set torVarsFiles "torVars.csh and torVars.sh"
        } else {
            set torVarsFiles torVars.bat
        }
    }

    if { [isGUImode] } {
    
        set ctrlVals(numBbrd) 0

        meterCreate $msg

        set w [dlgFrmCreate "System configuration"]
 
        controlPropertySet $ctrlVals(meterWindow).$ctrlVals(meterWg) \
                                -background Blue -foreground Black

        controlHide $w.helpButt 1
        controlEnable $w.backButt 0
        controlEnable $w.nextButt 0
        controlEnable $w.cancelButt 1
        controlFocusSet $w.cancelButt

    } else { # TEXT
       printPageTitle "System configuration"
    }
            
    if { ![isUnix] && [isTornadoProduct] } {
        meterUpdate 0 "Updating the Windows registry for Tornado"
    } else {
        meterUpdate 0 ""
    }

    # write Registry values from <$productName>.INF.  This is required to update
    # the user name, company, keydata, folder, etc. each time the user runs
    # the setup program.

    set prod [string toupper [getProdInfo name]]
    searchAndProcessSection AddRegistry [cdFileNameGet [file join RESOURCE \
                                                                  INF $prod.INF]]


    # process INF files for all selected products
    selectedProductsProcessInfFile FilesCopy
     
    if { [isTornadoProduct] && 
         [info exists setupVals(torRegOption)] &&
         $setupVals(torRegOption) == "torRegNTServ"} {
        if {![isUnix]} {
            # stop any Tornado Registry running service if tornado object
            # is selected for installation and only if the user has selected
            # the NT service option
            if { [info exists tornadoInstalled] && $tornadoInstalled } {
                if {![catch {setupServiceStop $setupVals(torRegServName)} err]} {
                    if {[isGUImode]} {                    
                        messageBox -ok -information [strTableGet TOR_REG_WARN]
                    } else {
                        puts "Tornado Registry Service:" 
                        puts "[strTableGet TOR_REG_WARN]"
                    }
                }
            }
        }
    }
    # Add service
    if {![isUnix]} {
        selectedProductsProcessInfFile AddService
    }

    selectedProductsProcessInfFile AddRegistry

    if { [isTornadoProduct] } {  set infVals(torRegNTServ) 0  }

    if {![isUnix]} {
        # make sure we have a folder if tornado is not installed
        # before we add icons 
        if { [isTornadoProduct] } {
            if { ![info exists tornadoInstalled] || !$tornadoInstalled } {
                folderCreateLog [defGroupGet] $ctrlVals(admin)
            }
        } else {
            folderCreateLog [defGroupGet] $ctrlVals(admin)
            set prod [getProdInfo name]
            searchAndProcessSection AddIcon [cdFileNameGet [file join \
                                                     RESOURCE INF $prod.INF]]
        }
        selectedProductsProcessInfFile AddIcon
    }
        
    queueExecute

    if { [isTornadoProduct] } {

        meterUpdate 22 "Creating make fragments for backward compatibility"

        set oldMakeDir [file join [destDirGet] target h make]
        set srcDir [file join [destDirGet] target h tool]

        foreach tool {gnu diab} {
            set toolDir [file join $srcDir $tool]

            set isSuccess 0
            set fileList ""
            if [isUnix] {
                if { ![catch { exec ls $toolDir } fileList] } {
                    set isSuccess 1
                }
            } else {
                regsub -all {/} $toolDir {\\} toolDir
                if { ![catch { exec cmd /c dir /w $toolDir } fileList] } {
                    set isSuccess 1
                }
            }

            if { $isSuccess == 1 } {
                foreach mFile $fileList {
                    if { [regexp {^make\.*} $mFile] } {
                        set Makefile [file join $oldMakeDir $mFile]
                        if { [file exists $Makefile] } {
                            file delete -force $Makefile
                        }
                        oldMakefileCreate $Makefile
                    }
                }
            }
        }

        meterUpdate 44 "Creating $torVarsFiles"

        if { [info exists tornadoInstalled] && $tornadoInstalled } {
            torVarsCreate
        }

        meterUpdate 66 "Configuring on-line HTML help. Please wait..."

        set htmlBookPath \
            [file join [destDirGet] host resource doctools htmlBook.tcl]
        
        if [isUnix] {
            set wtxtcl [file join [destDirGet] host [windHostTypeGet] bin wtxtcl.ex]
        } else {
            set wtxtcl [file join [destDirGet] host [windHostTypeGet] bin wtxtcl.exe]
        
            # turn off use of htmlBook for Windows, set wtx to nonexistent file
            #    set wtxtcl xyxfoobar
        }

        if {[isGUImode]} { 
            # use wait cursor here to let users know this step may step a while ...
            beginWaitCursor
        }

        # sets WIND_BASE so the spawned shell can pick up the env. variable
        set env(WIND_BASE) [destDirGet]
        if {[file exists $htmlBookPath] && [file exists $wtxtcl]} {
            if [catch {exec $wtxtcl $htmlBookPath \
                   [file join [destDirGet] docs]} error] {
                dbgputs "Cannot run html tool: $error"
            } else {
                dbgputs "Html tool runs successfully"
            } 
        }

        if {[isGUImode]} {  endWaitCursor  }
    
        if {[isUnix]} {

            set windexFile [file join [destDirGet] host resource \
                                  doctools windexRegen.tcl]
            if { [file exist $windexFile] } {

                # Source windexRegen.tcl to rebuild windex database
                meterUpdate 77 "Rebuild windex database"

                if { [catch {source $windexFile} err] } {
                    if { [isGUImode] } {
                        messageBox "Error: $err\
                                    SETUP cannot rebuild windex database"
                    } else {
                        puts "Error: $err\nSETUP cannot rebuild windex database\n"
                        while { [prompt "Press <Enter> to continue."] != "" } {
                        }
                    }
                }
            }
        }

        # comment out these lines to fix multiple windows flashing (spr 75292)
        #meterUpdate 88 "Re-generating toolchain info files. Please wait..."
        #generateToolchain

        meterUpdate 100 ""

    } else {
        # non-tornado product
        meterUpdate 100 ""
    }    

    if { [isGUImode] } {
        meterDestroy $ctrlVals(meterWindow)

        # test automation
        if { $ctrlVals(useInputScript) } {
            autoSetupLog "System configuration page"
        }
        nextCallback
    } else {
        nextCallback
        return 0
    }
}

#############################################################################
#
# pageProcess(systemConfig) - process inputs from system configuration
#                             page if any
#
# This procedure will process inputs from system configuration page if any
#
# SYNOPSIS
# .tS
# pageProcess(systemConfig)
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: 1 when successful
#
# ERRORS: N/A
#

proc pageProcess(systemConfig) {} {
    return 1
}

##############################################################################
#
# generateToolchain - regenerates toolchain info files for Project Facility.
#
# This procedure regenerates toolchain info files for Project Facility.
# This is done in SETUP to avoid this task being performed when launching
# Tornado for the first time, as this process takes a very long time.
#
# SYNOPSIS
# generateToolchain
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc generateToolchain {} {
    global env

    # set environment variables

    set env(WIND_BASE) [destDirGet]
    set env(WIND_HOST_TYPE) [windHostTypeGet]
    dbgputs "$env(WIND_BASE)\n$env(WIND_HOST_TYPE)\n"

    foreach envVar {PATH LD_LIBRARY_PATH TCL_LIBRARY} {
        switch $envVar {
            PATH {
                set pathToAdd [file join [destDirGet] host [windHostTypeGet] bin]
            }
            LD_LIBRARY_PATH {
                if { [isUnix] } {
                    set pathToAdd [list [file join [destDirGet] host [windHostTypeGet] lib] \
                                    [file join usr dt lib] [file join usr openwin lib] ]
                } else {
                    set pathToAdd [list [file join [destDirGet] host [windHostTypeGet] lib]]
                }
            }
            TCL_LIBRARY {
                set pathToAdd [file join [destDirGet] host [windHostTypeGet] lib]
            }
        }

        if { [info exists env($envVar)] } {
            if { [isUnix] } {
                set libSeparator ":"
            } else {
                set libSeparator ";"
            }

            # check if we need to add new paths to the existing environment

            foreach newPath $pathToAdd {
                if {[string first $newPath $env($envVar)] == -1} {

                    # if path does not seem to appear in the already
                    # existing environment path, add it

                    set env($envVar) [format "%s%s%s" $newPath $libSeparator \
                                                          $env($envVar)]
                }
            }
        } else {
            # set the TCL_LIBRARY to be able to retrieve packages
            set env($envVar) $pathToAdd
        }
        dbgputs "$env($envVar)\n"
    }

    # re-generate toolchain info file...

    set oldMakeDir [file join [destDirGet] target h make]
    set srcDir [file join [destDirGet] target h tool]
    set infoGenFile [file join [destDirGet] host resource tcl app-config Project gnuInfoGen.tcl]

    if [isUnix] {
        set wtxtclFile [file join [destDirGet] host [windHostTypeGet] bin wtxtcl.ex]
    } else {
        set wtxtclFile [file join [destDirGet] host [windHostTypeGet] bin wtxtcl.exe]
    }

    set isSuccess 0
    set fileList ""
    if [isUnix] {
        if { ![catch { exec ls $toolDir } fileList] } {
            set isSuccess 1
        }
    } else {
        regsub -all {\\} $toolDir {/} toolDir
        if { ![catch { exec cmd /c dir /w $toolDir } fileList] } {
            set isSuccess 1
        }
    }

    if { $isSuccess == 1 } {

        # check target/h/tool/$tool directory
        foreach tool {gnu diab} {
            if { $fileList != "" } {
                catch {exec $wtxtclFile $infoGenFile $tool} err
                dbgputs "Exec from target/h/tool/$tool:\n$err"
            }
        }

        # check target/h/make directory
        if { $fileList != "" } {
            catch {exec $wtxtclFile $infoGenFile gnu} err
            dbgputs "Exec from target/h/make:\n$err"
        }
    }
}

##############################################################################
#
# oldMakefileCreate - creates make files in target/h/make directory
#
# This procedure creates make files in target/h/make directory to provide
# backward compatibility when user installs T2.0.x 3rd party products
# such as Codetest (or installing any product with SETUP old-format
# library archiving.
#
# This procedure creates make files under target/h/make with the same names
# as makefiles in target/h/tool/(TOOL)/make.* where (TOOL) is gnu or diab.
# This "intermediate" makefiles created here simply points SETUP to the
# location of the actual makefiles under target/h/tool/(TOOL)
#
# SYNOPSIS
# oldMakefileCreate
#
# PARAMETERS: fName - name of make file to be created
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc oldMakefileCreate {fName} {

    if { ![catch {open $fName "w"} f] } {
        puts $f "#"
        puts $f "# This make fragments is used by SETUP to ensure backward compatibility for our"
        puts $f "# pre-veloce partner products. This file MUST NOT be used for anything else."
        puts $f "#\n"
        puts $f "# SETUP install directory"
        puts $f "SETUP_INSTALL_DIR = [destDirGet]\n"
        puts $f "# if WIND_BASE not set, set it"
        puts $f "# if WIND_BASE is set but wrong one, reset it"
        puts $f "ifeq ($(WIND_BASE),)"
        puts $f "WIND_BASE = $(SETUP_INSTALL_DIR)"
        puts $f "endif\n"
        puts $f "ifeq ($(TOOL_FAMILY),)"
        puts $f "ifeq ($(findstring gnu,$(TOOL)),gnu)"
        puts $f "TOOL_FAMILY = gnu"
        puts $f "else"
        puts $f "ifeq ($(findstring diab,$(TOOL)),diab)"
        puts $f "TOOL_FAMILY = diab"
        puts $f "endif"
        puts $f "endif"
        puts $f "endif\n"
        puts $f "ifeq ($(TGT_DIR),)"
        puts $f "TGT_DIR = $(WIND_BASE)/target"
        puts $f "endif\n"
        puts $f "include $(TGT_DIR)/h/tool/$(TOOL_FAMILY)/make.$(CPU)$(TOOL)"
        close $f
    } else {
        puts "ERROR in creating old makefile: $f"
    }
}

##############################################################################
#
# torVarsCreate - creates a Tornado environment variables startup file.
#
# SYNOPSIS
# torVarsCreate
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc torVarsCreate {} {
    global setupVals
    
    set binDir [destDirGet]/host/[windHostTypeGet]/bin

    if {"[windHostTypeGet]" == "x86-win32" && [file isdirectory $binDir]} {

        if {![file exists $binDir/torVars.bat]} {
            uninstLog file "wind_base\thost/[windHostTypeGet]/bin/torVars.bat"
        }

        if {![catch {open $binDir/torVars.bat "w"} f]} {
            puts $f "rem Command line build environments"
            puts $f "set WIND_HOST_TYPE=[windHostTypeGet]"
            puts $f "set WIND_BASE=[destDirGet]"

            if [info exists setupVals(regHost)] {
                puts $f "set WIND_REGISTRY=$setupVals(regHost)"
            }
            puts $f "set PATH=%WIND_BASE%\\host\\%WIND_HOST_TYPE%\\bin;%PATH%"
            
            close $f
        }

    } elseif {[file isdirectory $binDir]} {

        if {![file exists $binDir/torVars.csh]} {
            uninstLog file "wind_base\thost/[windHostTypeGet]/bin/torVars.csh"
        }

        if {![catch {open $binDir/torVars.csh "w"} f]} {

            puts $f "# Command line build environments"
            puts $f "setenv WIND_HOST_TYPE [windHostTypeGet]"
            puts $f "setenv WIND_BASE [destDirGet]"

            if {[info exists setupVals(registry)]} {
                puts $f "setenv WIND_REGISTRY $setupVals(registry)"
            }

            puts $f {setenv PATH $WIND_BASE/host/$WIND_HOST_TYPE/bin:$PATH}
            #if {"[windHostTypeGet]" == "sun4-solaris2"} {
            #    puts $f {setenv PATH $WIND_BASE/SETUP/SUN4/SOLARIS2:$PATH} } else {
            #    puts $f {setenv PATH $WIND_BASE/SETUP/X86/LINUX2:$PATH}
            #}
            puts $f "if \(! \$\?USER) then"
            puts $f "    setenv USER \$LOGNAME"
            puts $f "endif"

            if { [windHostTypeGet] == "sun4-solaris2" ||
                 [windHostTypeGet] == "x86-linux2" } {
                puts $f "if \(\$\?LD_LIBRARY_PATH) then"
                puts $f "    setenv LD_LIBRARY_PATH \${LD_LIBRARY_PATH}:\$WIND_BASE/host/\$WIND_HOST_TYPE/lib:/usr/dt/lib:/usr/openwin/lib"
                puts $f "else"
                puts $f "    setenv LD_LIBRARY_PATH \$WIND_BASE/host/\$WIND_HOST_TYPE/lib:/usr/dt/lib:/usr/openwin/lib"
                puts $f "endif"
            } elseif {[windHostTypeGet]=="parisc-hpux10"} {
                puts $f "if \(\$\?SHLIB_PATH) then"
                puts $f "    setenv SHLIB_PATH \${SHLIB_PATH}:\$WIND_BASE/host/\$WIND_HOST_TYPE/lib"
                puts $f "else"
                puts $f "    setenv SHLIB_PATH \$WIND_BASE/host/\$WIND_HOST_TYPE/lib"
                puts $f "endif"
            }
            
            close $f
        }

        if {![file exists $binDir/torVars.sh]} {
            uninstLog file "wind_base\thost/[windHostTypeGet]/bin/torVars.sh"
        }

        if {![catch {open $binDir/torVars.sh "w"} f]} {

            puts $f "# Command line build environments"
            puts $f "WIND_HOST_TYPE=[windHostTypeGet]"
            puts $f "export WIND_HOST_TYPE"
            puts $f "WIND_BASE=[destDirGet]"
            puts $f "export WIND_BASE"

            if {[info exists setupVals(registry)]} {
                puts $f "WIND_REGISTRY=$setupVals(registry)"
                puts $f "export WIND_REGISTRY"
            }

            puts $f {PATH=$WIND_BASE/host/$WIND_HOST_TYPE/bin:$PATH}
            #if {"[windHostTypeGet]" == "sun4-solaris2"} {
            #    puts $f {PATH=$WIND_BASE/SETUP/SUN4/SOLARIS2:$PATH}
            #} else {
            #    puts $f {PATH=$WIND_BASE/SETUP/X86/LINUX2:$PATH}
            #}
            puts $f "export PATH"
            puts $f "if \[ \"\$USER\" = \"\" \] ; then"
            puts $f "    USER=\$LOGNAME"
            puts $f "fi"
            puts $f "export USER"

            if { [windHostTypeGet] == "sun4-solaris2" ||
                 [windHostTypeGet] == "x86-linux2" } {
                puts $f "if \[ \"\$LD_LIBRARY_PATH\" = \"\" \] ; then"
                puts $f "    LD_LIBRARY_PATH=\$WIND_BASE/host/\$WIND_HOST_TYPE/lib:/usr/dt/lib:/usr/openwin/lib"
                puts $f "else"
                puts $f "    LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:\$WIND_BASE/host/\$WIND_HOST_TYPE/lib:/usr/dt/lib:/usr/openwin/lib"
                puts $f "fi"
                puts $f "export LD_LIBRARY_PATH"
            } elseif {[windHostTypeGet]=="parisc-hpux10"} {
                puts $f "if \[ \"\$SHLIB_PATH\" = \"\" \] ; then"
                puts $f "    SHLIB_PATH=\$WIND_BASE/host/\$WIND_HOST_TYPE/lib"
                puts $f "else"
                puts $f "    SHLIB_PATH=\$SHLIB_PATH:\$WIND_BASE/host/\$WIND_HOST_TYPE/lib"
                puts $f "fi"
                puts $f "export SHLIB_PATH"
            }
            
            close $f
        }
    }
    
    # append diab environment
    if {[file exists [destDirGet]/host/diab]} {
        torVarsCreateDiab
    }
}

proc torVarsCreateDiab {} {
    
    ################################
    # Lines to add to torVars.sh
    ################################
    set shLines {
# Diab Toolchain additions
case $WIND_HOST_TYPE in
sun4-solaris2)
    export DIAB_HOST_TYPE="SUNS" ;;
parisc-hpux10)
    export DIAB_HOST_TYPE="HPUX" ;;
*)
    export DIAB_HOST_TYPE="NONE" ;;
esac
if [ "$DIAB_HOST_TYPE" != "NONE" ] ; then
    DIABLIB=$WIND_BASE/host/diab
    export DIABLIB
    PATH=$DIABLIB/$DIAB_HOST_TYPE/bin:$PATH
    export PATH
else
    echo "Unknown WIND_HOST_TYPE. Diab Toolchain is not in PATH."
fi
    }
    
    ################################
    # Lines to add to torVars.csh
    ################################
    set cshLines {
# Diab Toolchain additions
switch ($WIND_HOST_TYPE)
    case sun4-solaris2:
        setenv DIAB_HOST_TYPE SUNS
        breaksw
    case parisc-hpux10:
        setenv DIAB_HOST_TYPE HPUX
        breaksw
    default:
        setenv DIAB_HOST_TYPE NONE
        breaksw
endsw
if ($DIAB_HOST_TYPE != "NONE") then
    setenv DIABLIB  $WIND_BASE/host/diab
    setenv PATH     $DIABLIB/$DIAB_HOST_TYPE/bin:$PATH
else
    echo "Unknown WIND_HOST_TYPE. Diab Toolchain is not in PATH."
endif
    }

    ################################
    # Lines to add to torVars.bat
    ################################
    set batLines {
rem Diab Toolchain additions
set DIABLIB=%WIND_BASE%\host\diab
set DIAB_HOST_TYPE=WIN32
set PATH=%DIABLIB%\WIN32\bin;%PATH%
    }

    # Update any torVars scripts found
    set bin [destDirGet]/host/[windHostTypeGet]/bin
    foreach script {torVars.sh torVars.csh torVars.bat} {
        if { [file exists $bin/$script] && [file writable $bin/$script] } {
            switch $script {
                torVars.sh  { set lines $shLines }
                torVars.csh { set lines $cshLines }
                torVars.bat { set lines $batLines }
                default     { error "bad script name" }
            }        

            set out [open $bin/$script a]
            puts -nonewline $out $lines
            close $out
        }
    }

}
######################################################################
# Dialog Text Messages
######################################################################

set strTable(TOR_REG_WARN) \
                "Setup has detected a previously installed Tornado Registry Service. \
                Setup will now remove it and install a newer version of the \
                Tornado Registry."
