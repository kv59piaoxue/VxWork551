/* fppArchLib.c - MIPS R-Series floating-point coprocessor support library */

/* Copyright 1984-2001 Wind River Systems, Inc. */
#include "copyright_wrs.h"

/*
 * This file has been developed or significantly modified by the
 * MIPS Center of Excellence Dedicated Engineering Staff.
 * This notice is as per the MIPS Center of Excellence Master Partner
 * Agreement, do not remove this notice without checking first with
 * WR/Platforms MIPS Center of Excellence engineering management.
 */

/*
modification history
--------------------
01x,16jul01,ros  add CofE comment
01w,05jun01,mem  Added hooks for extended save/restore.
01v,18jan01,pes  Cleanup handling of 32/64-bit fpp init/save/restore.
01u,02jan01,pes  Correct floating point register list.
01t,21dec00,pes  Adapt to MIPS32/MIPS64 CPU architectures
01s,01dec96,tam  Added specific definition of fpRegName[] for R4650.
01r,12feb96,mem  Added Tornado support.
01q,26sep95,cd	 removed previous change
01p,16jun94,yao  changed to initialize fppDisplayHookRtn to fppSwapRegs
                 routine if compiled little endian, and NULL otherwise.
01o,04feb94,cd   Added register width information.
01n,01apr93,caf  removed parameter from fppArchInit().
01o,03mar94,yao  changed to initialize fppDisplayHookRtn to fppSwapRegs 
		 routine for MIPSEL, and NULL otherwise.
01n,01apr93,caf  removed parameter from fppArchInit().
01m,14sep92,yao  made fppArchInit(), fppArchTaskCreateInit() NOMANUAL.
01l,23aug92,jcf  made filename consistant.
01k,08aug92,ajm  ansified
01j,04jul92,jcf  scalable/ANSI/cleanup effort.
01i,05jun92,ajm  5.0.5 merge, notice mod history changes
01h,26may92,rrr  the tree shuffle
01g,22feb92,yao  removed fppInit(), fppCreateHook(), fppSwapHook(),
                 fppTaskRegsShow().  added fpRegIndex[], fpCtlRegIndex[].
                 changed to pass pointer to task id and fp register set
                 to fppTaskRegs{S,G}et.  added fppArchInit(), fppArchTaskInit().
                 included intLib.h.  changed copyright notice.  documentation.
01f,16jan92,ajm  fixed display of floats
01e,15jan92,jdi  doc tweak.
01d,14jan92,jdi  documentation cleanup.
01c,04oct91,rrr  passed through the ansification filter
                  -changed VOID to void
                  -changed copyright notice
01b,01aug91,ajm  moved probe and int handlers to assembler (fppALib.s)
01a,24oct90,ajm  split fppLib.c.
*/

/*
DESCRIPTION
This library provides a low-level interface to the MIPS R3010/4010 coprocessor.
Routines fppTaskRegsShow(), fppTaskRegsSet(), and fppTaskRegsGet() inspect
and set coprocessor registers on a per task basis.  The higher level facilities
in dbgLib and usrLib should be used instead of these routines.

INITIALIZATION
To activate floating-point support, fppInit() must be called before any
tasks using the coprocessor are spawned.  This is done by the root task,
usrRoot(), in usrConfig.c.  See fppLib.

SEE ALSO: fppALib, fppLib, intConnect(),
.I "MIPS R3000 RISC Architecture"
.I "MIPS R-Series Architecture"

*/

#include "vxWorks.h"
#include "objLib.h"
#include "private/windLibP.h"
#include "private/kernelLibP.h"
#include "private/taskLibP.h"
#include "taskArchLib.h"
#include "memLib.h"
#include "iv.h"
#include "esf.h"
#include "fppLib.h"

/* imports */

IMPORT void intVecSet(FUNCPTR * vector, FUNCPTR function);
IMPORT FUNCPTR fpIntr(void);

/* globals */

REG_INDEX fpRegName [] = 
    {
#if	(_WRS_FP_REGISTER_SIZE == 4)
    /* Even register only, but can do 64bit math */
    {"fp0",  FP0, sizeof(double)},
    {"fp2",  FP2, sizeof(double)},
    {"fp4",  FP4, sizeof(double)},
    {"fp6",  FP6, sizeof(double)},
    {"fp8",  FP8, sizeof(double)},
    {"fp10", FP10, sizeof(double)},
    {"fp12", FP12, sizeof(double)},
    {"fp14", FP14, sizeof(double)},
    {"fp16", FP16, sizeof(double)},
    {"fp18", FP18, sizeof(double)},
    {"fp20", FP20, sizeof(double)},
    {"fp22", FP22, sizeof(double)},
    {"fp24", FP24, sizeof(double)},
    {"fp26", FP26, sizeof(double)},
    {"fp28", FP28, sizeof(double)},
    {"fp30", FP30, sizeof(double)},
#elif	(_WRS_FP_REGISTER_SIZE == 8)
    /* 32 64bit regs */
    {"fp0",  FP0, sizeof(double)},
    {"fp1",  FP1, sizeof(double)},
    {"fp2",  FP2, sizeof(double)},
    {"fp3",  FP3, sizeof(double)},
    {"fp4",  FP4, sizeof(double)},
    {"fp5",  FP5, sizeof(double)},
    {"fp6",  FP6, sizeof(double)},
    {"fp7",  FP7, sizeof(double)},
    {"fp8",  FP8, sizeof(double)},
    {"fp9",  FP9, sizeof(double)},
    {"fp10", FP10, sizeof(double)},
    {"fp11", FP11, sizeof(double)},
    {"fp12", FP12, sizeof(double)},
    {"fp13", FP13, sizeof(double)},
    {"fp14", FP14, sizeof(double)},
    {"fp15", FP15, sizeof(double)},
    {"fp16", FP16, sizeof(double)},
    {"fp17", FP17, sizeof(double)},
    {"fp18", FP18, sizeof(double)},
    {"fp19", FP19, sizeof(double)},
    {"fp20", FP20, sizeof(double)},
    {"fp21", FP21, sizeof(double)},
    {"fp22", FP22, sizeof(double)},
    {"fp23", FP23, sizeof(double)},
    {"fp24", FP24, sizeof(double)},
    {"fp25", FP25, sizeof(double)},
    {"fp26", FP26, sizeof(double)},
    {"fp27", FP27, sizeof(double)},
    {"fp28", FP28, sizeof(double)},
    {"fp29", FP29, sizeof(double)},
    {"fp30", FP30, sizeof(double)},
    {"fp31", FP31, sizeof(double)},
#else 	/* (_WRS_FP_REGISTER_SIZE */
#error "invalid (_WRS_FP_REGISTER_SIZE value"
#endif	/* _WRS_FP_REGISTER_SIZE == 4) */
    {NULL, 0},
    };

REG_INDEX fpCtlRegName []  = 
    {
    {"fpcsr", FPCSR, sizeof(ULONG)},
    {NULL, 0},
    };

FUNCPTR _func_fppSaveHook = NULL;
FUNCPTR _func_fppRestoreHook = NULL;
FUNCPTR _func_fppInitializeHook = NULL;

/* forward declarations */

/*******************************************************************************
*
* fppArchInit - initialize floating-point coprocessor support
*
* This routine must be called before using the floating-point coprocessor.
*
* NOMANUAL
*/

void fppArchInit (void)
    {
    fppCreateHookRtn = (FUNCPTR) NULL;
    fppDisplayHookRtn = (FUNCPTR) NULL;
    }

/*******************************************************************************
*
* fppArchTaskCreateInit - initialize floating-point coprocessor support for task
*
* NOMANUAL
*/

void fppArchTaskCreateInit
    (
    FP_CONTEXT *pFpContext              /* pointer to FP_CONTEXT */
    )
    {
    int ix;
    
    /* Get fpcsr */
    fppSave (pFpContext);

    /* Now zero the rest */
    for (ix = 0; ix < FP_NUM_DREGS; ix++)
	pFpContext->fpx[ix] = 0;
#if (_WRS_FP_REGISTER_SIZE == 8)
    for (ix = 0; ix < FP_EXTRA; ix++)
	pFpContext->fpxtra[ix] = 0;
#endif	/* _WRS_FP_REGISTER_SIZE */
    }

/*******************************************************************************
*
* fppTaskRegsGet - get the floating-point registers from a task's TCB
*
* This routine copies a task's floating-point registers -- fpcsr and fp0 - fp31
* -- to the locations whose pointers are passed as parameters.  The
* floating-point registers are copied into an array containing the 16/32
* double-precision registers (depending on 32 or 64bit FP support).
*
* NOTE
* This routine only works well if <task> is not 
* the calling task.  If a task tries to discover its own registers,
* the values will be stale (i.e., left over from the last task switch).
*
* RETURNS: OK, or ERROR if there is no floating-point 
* support or if there is an invalid state.
*
* SEE ALSO: fppTaskRegsSet()
*/

STATUS fppTaskRegsGet
    (
    int task,                   /* task to get info about */
    FPREG_SET *pFpRegSet        /* pointer to fp register set */
    )
    {
    int ix;
    FP_CONTEXT *pFpContext;
    WIND_TCB *pTcb = taskTcb (task);

    if (pTcb == NULL)
        return (ERROR);

    pFpContext = pTcb->pFpContext;
    if (pFpContext == (FP_CONTEXT *)NULL)
        return (ERROR);                 /* no coprocessor support */

    /* normal/idle state */

    pFpRegSet->fpcsr = pFpContext->fpcsr;
    for (ix = 0; ix < FP_NUM_DREGS; ix++)
	pFpRegSet->fpx[ix] = pFpContext->fpx[ix];
#if (_WRS_FP_REGISTER_SIZE == 8)
    for (ix = 0; ix < FP_EXTRA; ix++)
	pFpRegSet->fpxtra[ix] = pFpContext->fpxtra[ix];
#endif	/* _WRS_FP_REGISTER_SIZE */

    return (OK);
    }

/*******************************************************************************
*
* fppTaskRegsSet - set a task's floating-point registers 
*
* This routine loads the specified values into the TCB for a specified task.
* The registers are in an array containing fp0 - fp31.
*
* RETURNS: OK, or ERROR if there is no floating-point support.
*
* SEE ALSO: fppTaskRegsGet()
*/

STATUS fppTaskRegsSet
    (
    int task,                   /* task whose registers are to be set */
    FPREG_SET *pFpRegSet        /* point to floating-point register set */
    )
    {
    int ix;
    WIND_TCB *pTcb = taskTcb (task);
    FP_CONTEXT *pFpContext;

    if (pTcb == NULL)
        return (ERROR);

    pFpContext = pTcb->pFpContext;
    if (pFpContext == (FP_CONTEXT *)NULL)
        return (ERROR);                 /* no coprocessor support */

    /* normal/idle state */

    pFpContext->fpcsr = pFpRegSet->fpcsr;
    for (ix = 0; ix < FP_NUM_DREGS; ix++)
	pFpContext->fpx[ix] = pFpRegSet->fpx[ix];
#if (_WRS_FP_REGISTER_SIZE == 8)
    for (ix = 0; ix < FP_EXTRA; ix++)
	pFpContext->fpxtra[ix] = pFpRegSet->fpxtra[ix];
#endif	/* _WRS_FP_REGISTER_SIZE */

    return (OK);
    }

/******************************************************************************
*
* fppRegsToCtx - convert FPREG_SET to FP_CONTEXT.
*/

void fppRegsToCtx
    (
    FPREG_SET *  pFpRegSet,             /* input -  fpp reg set */
    FP_CONTEXT * pFpContext             /* output - fpp context */
    )
    {
    *pFpContext = *(FP_CONTEXT *)pFpRegSet;
    }

/******************************************************************************
*
* fppCtxToRegs - convert FP_CONTEXT to FPREG_SET.
*/

void fppCtxToRegs
    (
    FP_CONTEXT * pFpContext,            /* input -  fpp context */
    FPREG_SET *  pFpRegSet              /* output - fpp register set */
    )
    {
    *pFpRegSet = *(FPREG_SET *)pFpContext;
    }

/******************************************************************************
*
* fppArchUnitInit - intialize a MIPS floating point unit and set the floating
*                   point interrupt vector routine.
*/

void fppArchUnitInit
    (
    )
    {
    /* check that there is a floating point unit */
    if (fppProbe () == OK)
	{
	fppInitialize ();

	/* Call the initialize hook if installed */
	if (_func_fppInitializeHook)
	    (*_func_fppInitializeHook)();

	intVecSet ((FUNCPTR *) INUM_TO_IVEC (IV_FPE_VEC), (FUNCPTR)fpIntr);
	}
    }
