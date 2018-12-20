/* fppArchLib.c - Coldfire floating-point coprocessor support library */

/* Copyright 1984-2000 Wind River Systems, Inc. */
#include "copyright_wrs.h"

/*
modification history
--------------------
01a,27jun00,dh   stolen from 68k
*/

/*
DESCRIPTION
This library provides a low-level interface to the MC68881/MC68882
coprocessor.  The routines fppTaskRegsSet() and fppTaskRegsGet()
inspect and set coprocessor registers on a per task basis.  The
routine fppProbe() checks for the presence of the MC68881/MC68882
coprocessor.  With the exception of fppProbe(), the higher level
facilities in dbgLib and usrLib should be used instead of these
routines.  See fppLib for architecture independent portion.

SEE ALSO: fppALib, intConnect(), MC68881/MC68882 User's Manual
*/

#include "vxWorks.h"
#include "objLib.h"
#include "taskLib.h"
#include "taskArchLib.h"
#include "memLib.h"
#include "string.h"
#include "iv.h"
#include "intLib.h"
#include "regs.h"
#include "fppLib.h"


/* globals */

REG_INDEX fpRegName [] =
    {
    {"f0", FPX_OFFSET(0)},
    {"f1", FPX_OFFSET(1)},
    {"f2", FPX_OFFSET(2)},
    {"f3", FPX_OFFSET(3)},
    {"f4", FPX_OFFSET(4)},
    {"f5", FPX_OFFSET(5)},
    {"f6", FPX_OFFSET(6)},
    {"f7", FPX_OFFSET(7)},
    {NULL, 0},
    };

REG_INDEX fpCtlRegName [] =
    {
    {"fpcr",   FPCR},
    {"fpsr",   FPSR},
    {"fpiar",  FPIAR},
    {NULL, 0},
    };

/* locals */

LOCAL FP_CONTEXT fppInitContext;	/* initialized to initial fp context */


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
    fppCreateHookRtn = (FUNCPTR) NULL;
    fppSave (&fppInitContext);		/* fppProbe() was called in fppInit() */
    }
/*******************************************************************************
*
* fppArchTaskCreateInit - initialize floating-point coprocessor support for task
*
* INTERNAL
* We utilize a NULL frame (not possible for the 040) to optimize the
* context switch time until an actual floating point instruction is
* executed.
*
* On the 040:
* It might seem odd that we use a bcopy() to initialize the floating point
* context when a fppSave() of an idle frame would accomplish the same thing
* without the cost of a 324 byte data structure.  The problem is that we
* are not guaranteed to have an idle frame.  Consider the following scenario:
* a floating point task is midway through a floating point instruction when
* it is preempted by a *non-floting point* task.  In this case the swap-in
* hook does not save the coprocessor state as an optimization.  Now if we
* create a floating point task the initial coprocessor frame would not be
* idle but rather mid-instruction.  To make matters worse when get around
* to saving the original fp task's floating point context frame, it would be
* incorrectly saved as idle!  One solution would be to fppSave() once to
* the original fp task's context, then fppSave() an idle frame to the new task,
* and finally restore the old fp task's context (in case we return to it
* before another fp task).  The problem with this approach is that it is
* *slow* and considering the fact that preemption is locked, the 324 bytes
* don't look so bad anymore.  Indeed, when this approach is adopted by all
* architectures we will not need to lock out preemption anymore.
*
* NOMANUAL
*/

void fppArchTaskCreateInit
    (
    FP_CONTEXT *pFpContext		/* pointer to FP_CONTEXT */
    )
    {
    /* create NULL frame as initial frame */

    bzero ((char *)pFpContext, sizeof (FP_CONTEXT));
    }

/******************************************************************************
*
* fppRegsToCtx - convert FPREG_SET to FP_CONTEXT.
*/ 

void fppRegsToCtx
    (
    FPREG_SET *  pFpRegSet,		/* input -  fpp reg set */
    FP_CONTEXT * pFpContext		/* output - fpp context */
    )
    {
    int ix;

    if (pFpContext->stateFrame [NULLFRAME - STATEFRAME] == 0)
        bcopy ((const char *) &fppInitContext, (char *)pFpContext,
               sizeof (FP_CONTEXT));    /* must have init context to change */


    /* normal/idle state */

    for (ix = 0; ix < FP_NUM_DREGS; ix++)
        fppDtoDx ((DOUBLEX *) &pFpContext->fpRegSet.fpx[ix],
                  (double *) &pFpRegSet->fpx [ix]);

    pFpContext->fpRegSet.fpcr  = pFpRegSet->fpcr;
    pFpContext->fpRegSet.fpsr  = pFpRegSet->fpsr;
    pFpContext->fpRegSet.fpiar = pFpRegSet->fpiar;
    }

/******************************************************************************
*
* fppCtxToRegs - convert FP_CONTEXT to FPREG_SET.
*/ 

void fppCtxToRegs
    (
    FP_CONTEXT * pFpContext,		/* input -  fpp context */
    FPREG_SET *  pFpRegSet		/* output - fpp register set */
    )
    {
    int ix;

    if (pFpContext->stateFrame [NULLFRAME - STATEFRAME] == 0)
        pFpContext = &fppInitContext;   /* return results of idle frame */

    /* normal/idle state */

    for (ix = 0; ix < FP_NUM_DREGS; ix++)
        fppDxtoD ((double *) &pFpRegSet->fpx[ix],
                  (DOUBLEX *) &pFpContext->fpRegSet.fpx[ix]);

    pFpRegSet->fpcr  = pFpContext->fpRegSet.fpcr;
    pFpRegSet->fpsr  = pFpContext->fpRegSet.fpsr;
    pFpRegSet->fpiar = pFpContext->fpRegSet.fpiar;
    }

/*******************************************************************************
*
* fppTaskRegsGet - get the floating-point registers from a task TCB
*
* This routine copies the floating-point registers of a task
* (PCR, PSR, and PIAR) to the locations whose pointers are passed as
* parameters.  The floating-point registers are copied in
* an array containing the 8 registers.
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
    FAST FP_CONTEXT *pFpContext;
    FAST WIND_TCB *pTcb = taskTcb (task);

    if (pTcb == NULL)
	return (ERROR);

    pFpContext = pTcb->pFpContext;

    if (pFpContext == (FP_CONTEXT *)NULL)
	return (ERROR);			/* no coprocessor support */

    fppCtxToRegs (pFpContext, pFpRegSet);

    return (OK);
    }
/*******************************************************************************
*
* fppTaskRegsSet - set the floating-point registers of a task
*
* This routine loads the specified values into the specified task TCB.
* The 8 registers f0-f7 are copied to the array <fpregs>.
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
    FAST WIND_TCB *pTcb = taskTcb (task);
    FAST FP_CONTEXT *pFpContext;

    if (pTcb == NULL)
	return (ERROR);

    pFpContext = pTcb->pFpContext;

    if (pFpContext == (FP_CONTEXT *)NULL)
	return (ERROR);			/* no coprocessor support, PUT ERRNO */

    fppRegsToCtx (pFpRegSet, pFpContext);

    return (OK);
    }
/*******************************************************************************
*
* fppReset - reset the floating point coprocessor
*
* This routine will reset the floating point coprocessor by issuing a
* fppRestore() of a NULL frame.  The contents of the floating point registers
* will be reset, as well as all other floating point state information.
*
* Use of this routine will improve context switch time between floating point
* tasks if it is issued at points when a consistent floating point context 
* is no longer required.
*
* CAVEATS
* Not all versions of the MC68040 correctly support NULL frames, so the use
* of this routine on this processor is not advised.
*
* RETURNS: N/A
*
* SEE ALSO: fppALib, MC68881/MC68882 User's Manual
*
* NOMANUAL
*/

void fppReset (void)
    {
    FP_CONTEXT nullContext;

    bzero ((char *)&nullContext, sizeof (FP_CONTEXT));
    fppRestore (&nullContext);
    }
/*******************************************************************************
*
* fppProbe - probe for the presence of a floating-point coprocessor
*
* This routine determines whether there is an MC68881/MC68882
* floating-point coprocessor in the system.
*
* IMPLEMENTATION
* This routine sets the illegal coprocessor opcode trap vector and executes
* a coprocessor instruction.  If the instruction causes an exception,
* fppProbe() will return ERROR.  Note that this routine saves and restores
* the illegal coprocessor opcode trap vector that was there prior to this
* call.
*
* The probe is only performed the first time this routine is called.
* The result is stored in a static and returned on subsequent
* calls without actually probing.
*
* RETURNS:
* OK if the floating-point coprocessor is present, otherwise ERROR.
*/

STATUS fppProbe (void)
    {
    static int fppProbed = -2;		/* -2 = not done, -1 = ERROR, 0 = OK */
    FUNCPTR oldVec;

    if (fppProbed == -2)
	{
	/* save error vector */
	oldVec = intVecGet ((FUNCPTR *) IV_LINE_1111_EMULATOR);

	/* replace error vec */
	intVecSet ((FUNCPTR *) IV_LINE_1111_EMULATOR, (FUNCPTR) fppProbeTrap);

	fppProbed = fppProbeSup ();	/* execute coprocessor instruction */

	/* replace old err vec*/
	intVecSet ((FUNCPTR *) IV_LINE_1111_EMULATOR, (FUNCPTR) oldVec);
	}

    return (fppProbed);
    }
