/* fppArchLib.c - ARM floating-point coprocessor support library */

/* Copyright 1996-1997 Wind River Systems, Inc. */
#include "copyright_wrs.h"

/*
modification history
--------------------
01c,27oct97,kkk  took out "***EOF***" line from end of file.
01b,03mar97,jpd  Tidied comments/documentation.
01a,18jul96,cdp  created, based on 68k version.
*/

/*
DESCRIPTION
This library provides a low-level interface to the ARM floating-point
unit (FPU).  The routines fppTaskRegsSet() and fppTaskRegsGet()
inspect and set coprocessor registers on a per task basis.  The
routine fppProbe() checks for the presence of the FPU.
With the exception of fppProbe(), the higher level
facilities in dbgLib and usrLib should be used instead of these
routines.  See fppLib for architecture independent portion.

SEE ALSO: fppALib
*/

#include "vxWorks.h"
#include "regs.h"
#include "fppLib.h"


/* globals */

REG_INDEX fpRegName [] =
    {
    {NULL, 0},
    };

REG_INDEX fpCtlRegName [] =
    {
    {NULL, 0},
    };

/*******************************************************************************
*
* fppArchInit - initialize floating-point coprocessor support
*
* This routine must be called before using the floating-point coprocessor.
* It is typically called from fppInit().
*
* NOMANUAL
*/

void fppArchInit (void)
    {
    }

/*******************************************************************************
*
* fppArchTaskCreateInit - initialize floating-point unit support for task
*
* NOMANUAL
*/

void fppArchTaskCreateInit
    (
    FP_CONTEXT *pFpContext		/* pointer to FP_CONTEXT */
    )
    {
    }

/*******************************************************************************
*
* fppTaskRegsGet - get the floating-point registers from a task TCB
*
* This routine copies the floating-point registers of a task
* to the locations whose pointers are passed as parameters.
* The floating-point registers are copied to an array containing
* the registers.
*
* NOTE
* This routine only works well if <task> is not the calling task.
* If a task tries to discover its own registers, the values will be stale
* (i.e., leftover from the last task switch).
*
* RETURNS: OK, or ERROR if there is no floating-point
* support or there is an invalid state.
*
* SEE ALSO: fppTaskRegsSet()
*/

STATUS fppTaskRegsGet
    (
    int task,           	/* task to get info about */
    FPREG_SET *pFpRegSet	/* pointer to floating-point register set */
    )
    {
    return ERROR;		/* no FPU */
    }

/*******************************************************************************
*
* fppTaskRegsSet - set the floating-point registers of a task
*
* This routine loads the specified values into the specified task TCB.
* The registers are copied into the array <fpregs>.
*
* RETURNS: OK, or ERROR if there is no floating-point
* support or there is an invalid state.
*
* SEE ALSO: fppTaskRegsGet()
*/

STATUS fppTaskRegsSet
    (
    int task,           	/* task whose registers are to be set */
    FPREG_SET *pFpRegSet	/* pointer to floating-point register set */
    )
    {
    return ERROR;		/* no FPU */
    }

/*******************************************************************************
*
* fppProbe - probe for the presence of a floating-point coprocessor
*
* This routine determines whether there is an FPU in the system.
*
* RETURNS: ERROR (no FPU).
*/

STATUS fppProbe (void)
    {
    return ERROR;		/* no FPU */
    }

/*******************************************************************************
*
* fppSave - save fp registers.
*
* This routine saves the floating-point coprocessor context.
* Currently, this routine does nothing.
*
* RETURNS: N/A
*
* SEE ALSO: fppRestore()
*/

void fppSave (FP_CONTEXT *pFpContext)
    {
    }

/*******************************************************************************
*
* fppRestore - restore fp registers.
*
* RETURNS: N/A
*/

void fppRestore (FP_CONTEXT *pFpContext)
    {
    }
