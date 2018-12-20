/* fppArchLib.c - PowerPC floating-point unit support library */

/* Copyright 1984-1995 Wind River Systems, Inc. */
#include "copyright_wrs.h"

/*
modification history
--------------------
01k,15aug01,pch  Add minimal PPC440 support
01j,25oct00,s_m  renamed PPC405 cpu types
01i,25oct00,s_m  fixed comment
01h,24oct00,s_m  cleared FP exceptions enable bits
01g,07sep00,sm   modified fppProbe () for PPC405 and PPC405F
01f,18mar99,tam  cleared FP exceptions enable bits (work-arround to SPR 25682).
01e,10feb97,tam  reworked initialisation of the FP_CONTEXT structure.
01d,10nov96,tpr  moved mathHardInit() in math/mathHardLib.c.
01c,23feb96,ms   added fppRegsToCtx and fppCtxToRegs.
01b,28mar95,caf  removed "NULL fp context" debug message.
01a,12jan94,caf  created, based on 68k version.
*/

/*
DESCRIPTION
This library provides a low-level interface to the PowerPC
floating-point unit (FPU).  The routines fppTaskRegsSet() and
fppTaskRegsGet() set and get FPU registers on a per task basis.
The routine fppProbe() checks for the presence of an FPU.
With the exception of fppProbe(), the higher level
facilities in dbgLib and usrLib should be used instead of these
routines.  See fppLib for architecture independent portion.

SEE ALSO: fppALib, PowerPC 601 User's Manual
*/

#include "vxWorks.h"
#include "objLib.h"
#include "taskLib.h"
#include "taskArchLib.h"
#include "memLib.h"
#include "string.h"
#include "regs.h"
#include "fppLib.h"


/* globals */

REG_INDEX fpRegName [] =
    {
    {"fr0",  FPX_OFFSET( 0)},
    {"fr1",  FPX_OFFSET( 1)},
    {"fr2",  FPX_OFFSET( 2)},
    {"fr3",  FPX_OFFSET( 3)},
    {"fr4",  FPX_OFFSET( 4)},
    {"fr5",  FPX_OFFSET( 5)},
    {"fr6",  FPX_OFFSET( 6)},
    {"fr7",  FPX_OFFSET( 7)},
    {"fr8",  FPX_OFFSET( 8)},
    {"fr9",  FPX_OFFSET( 9)},
    {"fr10", FPX_OFFSET(10)},
    {"fr11", FPX_OFFSET(11)},
    {"fr12", FPX_OFFSET(12)},
    {"fr13", FPX_OFFSET(13)},
    {"fr14", FPX_OFFSET(14)},
    {"fr15", FPX_OFFSET(15)},
    {"fr16", FPX_OFFSET(16)},
    {"fr17", FPX_OFFSET(17)},
    {"fr18", FPX_OFFSET(18)},
    {"fr19", FPX_OFFSET(19)},
    {"fr20", FPX_OFFSET(20)},
    {"fr21", FPX_OFFSET(21)},
    {"fr22", FPX_OFFSET(22)},
    {"fr23", FPX_OFFSET(23)},
    {"fr24", FPX_OFFSET(24)},
    {"fr25", FPX_OFFSET(25)},
    {"fr26", FPX_OFFSET(26)},
    {"fr27", FPX_OFFSET(27)},
    {"fr28", FPX_OFFSET(28)},
    {"fr29", FPX_OFFSET(29)},
    {"fr30", FPX_OFFSET(30)},
    {"fr31", FPX_OFFSET(31)},
    {NULL, 0},
    };

REG_INDEX fpCtlRegName [] =
    {
    {"fpcsr", FPCSR_OFFSET},
    {NULL, 0},
    };

/*******************************************************************************
*
* fppArchInit - initialize floating-point unit support
*
* This routine must be called before using the floating-point unit.
* It is typically called from fppInit().
*
* NOMANUAL
*/

void fppArchInit (void)

    {
    fppCreateHookRtn = (FUNCPTR) NULL;
    }

/*******************************************************************************
*
* fppArchTaskCreateInit - initialize floating-point unit support for task
*
* INTERNAL
* Note that the FP_CONTEXT data structure is 260 bytes on the PowerPC.
*
* The floating point context is initialized as follows:
*    - floating point registers are set to NaN.
*    - the floating point status and control register (FPSCR) is initialized
*      to its default value _PPC_FPSCR_INIT (only a few exception enable bits 
*      are set, all the status and summary bits are cleared). Furthermore these
*      exception enable bits are ORed with their current value. In other words,
*      a given task may inherit FPSCR exception enable bits from the task
*      it was spawned from.
*
* NOMANUAL
*/

void fppArchTaskCreateInit
    (
    FP_CONTEXT *pFpContext		/* pointer to FP_CONTEXT */
    )
    {
    /*
     * Initialize the FP_CONTEXT structure for the new task:
     *   - floating point register are set to NaN. 
     *   - ctrl bits of the FPSCR takes their current value or their default
     *     value (FP_EXC_DEFAULT). FPSCR status and summary bits are cleared.
     */

    bfill ((char *) pFpContext, sizeof (FP_CONTEXT), 0xff); /* fills with NaN */

#ifdef	_PPC_MSR_FP
# if	0
    pFpContext->fpcsr = (vxFpscrGet() & _PPC_FPSCR_CTRL_MASK) | _PPC_FPSCR_INIT;
# else /* work-arround to SPR 25682 */
    /* clear all FP exceptions enable bits */

    pFpContext->fpcsr = 0;
# endif
#else
    pFpContext->fpcsr = 0;
#endif	/* _PPC_MSR_FP */
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
* RETURNS: OK, or ERROR if there is no floating-point support.
*
* SEE ALSO: fppTaskRegsSet()
*/

STATUS fppTaskRegsGet
    (
    int task,           	/* task to get info about */
    FPREG_SET *pFpRegSet	/* pointer to floating-point register set */
    )
    {
    int ix;
    FAST FP_CONTEXT *pFpContext;
    FAST WIND_TCB *pTcb = taskTcb (task);

    if (pTcb == NULL)
	return (ERROR);

    pFpContext = pTcb->pFpContext;

    if (pFpContext == (FP_CONTEXT *)NULL)
	return (ERROR);			/* no FPU support */
    else
	{
	for (ix = 0; ix < FP_NUM_DREGS; ix++)
	    pFpRegSet->fpr[ix] = pFpContext->fpr[ix];

	pFpRegSet->fpcsr  = pFpContext->fpcsr;
	}

    return (OK);
    }

/*******************************************************************************
*
* fppTaskRegsSet - set the floating-point registers of a task
*
* This routine loads the specified values into the specified task TCB.
*
* RETURNS: OK, or ERROR if there is no floating-point support.
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
    int ix;

    if (pTcb == NULL)
	return (ERROR);

    pFpContext = pTcb->pFpContext;

    if (pFpContext == (FP_CONTEXT *)NULL)
	return (ERROR);			/* no FPU support, PUT ERRNO */
    else
	{
	for (ix = 0; ix < FP_NUM_DREGS; ix++)
	    pFpContext->fpr[ix]  = pFpRegSet->fpr[ix];

	pFpContext->fpcsr = pFpRegSet->fpcsr;
	}

    return (OK);
    }

/*******************************************************************************
*
* fppProbe - probe for the presence of a floating-point unit
*
* This routine determines whether a PowerPC floating-point unit is present.
*
* RETURNS:
* OK if the floating-point unit is present, otherwise ERROR.
*/

STATUS fppProbe ()
    {
/* XXX - PPC440 should probe for an (optional) FPU, but initially
 * XXX   we only support the 440GP which is known not to have one.
 */
#if	((CPU == PPC403) || (CPU == PPC405) || (CPU == PPC860) || \
	 (CPU == PPC440))
    return (ERROR);
#else	/* ((CPU == PPC4xx) || (CPU == PPC860)) */
    return (OK);
#endif	/* ((CPU == PPC4xx) || (CPU == PPC860)) */
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
    bcopy ((char *) pFpRegSet, (char *)pFpContext,
           sizeof (FP_CONTEXT));    
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
    bcopy ((char *) pFpContext, (char *)pFpRegSet,
           sizeof (FP_CONTEXT));    
    }

