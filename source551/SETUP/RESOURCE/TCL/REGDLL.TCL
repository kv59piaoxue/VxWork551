# REGDLL.TCL - Setup procedures for implementing dll-registration wizard page
#
# Copyright 1999 Wind River Systems, Inc
#
# modification history
# --------------------
# 02a,12jun01,j_w  Modified for Tornado 2.2
# 01e,13apr99,wmd  Add some time delay between registration of each program to
#                  ensure that registration completes before starting another.
# 01d,19mar99,wmd  Output to a file any debug messages.
# 01c,22feb99,tcy  fixed logic to print debug messages
# 01b,17feb99,tcy  modified debug messages when registering for dlls of remote
#                  servers
# 01a,26jan99,tcy  extracted from INSTW32.TCL.
#

#############################################################################
#
# pageCreate(regTornado) - call regTornado to register Tornado DLLs for DCOM use
#
# This procedure will call procedure regTornado to register Tornado DLLs for
# DCOM use and also display progress with a meter
#
# SYNOPSIS
# .tS
# pageCreate(regTornado)
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc pageCreate(regTornado) {} {
    global ctrlVals

    set ctrlVals(numBbrd) 0

    meterCreate [strTableGet REGTOR_MSG1]

    set w [dlgFrmCreate [strTableGet REGTOR_TITLE]]

    controlPropertySet $ctrlVals(meterWindow).$ctrlVals(meterWg) \
                        -background Blue -foreground Black

    controlEnable $w.helpButt 0
    controlEnable $w.backButt 0
    controlEnable $w.nextButt 0

    # process INF files --
    # this compares the versions of the DLLs on the system and on the CD
    # and uses the latest version

    searchAndProcessSection FilesCopy \
        [cdFileNameGet [file join RESOURCE INF TORNADO.INF]]

    regTornado

    meterDestroy $ctrlVals(meterWindow)

    nextCallback
}

#############################################################################
#
# pageProcess(regTornado) - process inputs from regTornado page if any
#
# This procedure will process inputs from regTornado page if any
#
# SYNOPSIS
# .tS
# pageProcess(regTornado)
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: 1 when successful
#
# ERRORS: N/A
#

proc pageProcess(regTornado) {} {
    return 1
}

#############################################################################
#
# addSlash - add extra slashes for eval use later
#
# This procedure will add extra slashes for eval user later
#
# SYNOPSIS
# .tS
# addSlash <path>
# .tE
#
# PARAMETERS:
# .IP path
# path with slashes
#
# RETURNS: new path with extra slashes
#
# ERRORS: N/A
#

proc addSlash {path} {
    regsub -all {\\} $path {\\\\} newpath
    return $newpath
}

#############################################################################
#
# regTornado - register all tornado dlls and executables
#
# This procedure will register all tornado dlls and executables
#
# SYNOPSIS
# .tS
# regTornado
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc regTornado {} {
    global ctrlVals
    global setupVals

    set regsvr32               "[sysDirGet]\\Regsvr32.exe"
    set binFile(ComTcl.dll)    "[destDirGet]\\host\\x86-win32\\bin\\ComTcl.dll"
    set binFile(WrsDebugger.dll) \
                          "[destDirGet]\\host\\x86-win32\\bin\\WrsDebugger.dll"
    set binFile(Tornado.exe)   "[destDirGet]\\host\\x86-win32\\bin\\Tornado.exe"
    set regCommand(ComTcl.dll) "$regsvr32 /s /c $binFile(ComTcl.dll)"
    set regCommand(WrsDebugger.dll) "$regsvr32 /s /c $binFile(WrsDebugger.dll)"
    set regCommand(Tornado.exe) "$binFile(Tornado.exe) /RegServer"

    set gdbFiles [glob -nocomplain [file join [destDirGet] \
                 host x86-win32 bin Cgdb*exe]]

    foreach absFile $gdbFiles {
        set f [file tail $absFile]
        set binFile($f) [unixToDos $absFile]
        set regCommand($f) "$binFile($f) /RegServer"
    }

    # check for file existence
    foreach f [array names binFile] {
        if ![file exists $binFile($f)] {
            if {[debug] || ![info exists setupVals(iconInstallation)]} {
                dbgputs "Error: $binFile($f) not found"
            }
        }
    }

    if ![file exists $regsvr32] {
        if {[debug] || ![info exists setupVals(iconInstallation)]} {
            dbgputs "Error: $regsvr32 not found"
        }
    }

    # set up the meter
    set count 0
    set totalCmds [llength [array names binFile]]

    foreach b [array names binFile] {
        set percent [expr $count * 100 / $totalCmds]
        meterUpdate $percent "Registering $b ..."
        incr count

        if {![catch {eval exec [addSlash $regCommand($b)]} result]} {
            if {[debug] || ![info exists setupVals(iconInstallation)]} {
                dbgputs "$b registration successful!"
            }
        } else {
            if {[debug] || ![info exists setupVals(iconInstallation)]} {
                dbgputs "$b registration failed: $result"
                uninstLog setupLog "$b registration failed: $result"
            }
        }
        after 2000
    }
    meterUpdate 100 ""
}

######################################################################
# Dialog Text Messages
######################################################################
    
set strTable(REGTOR_TITLE) "Software Registration"

set strTable(REGTOR_MSG1) \
    "SETUP is registering software on your machine. This will take a few\
    minutes."

