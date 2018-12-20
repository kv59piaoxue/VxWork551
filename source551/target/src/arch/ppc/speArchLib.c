/* speArchLib.c - PowerPC spe unit support library */

/* Copyright 1984-1995 Wind River Systems, Inc. */
#include "copyright_wrs.h"

/*
modification history
--------------------
01a,03sep02,dtr  Created from altivecArchLib.c
*/

/*
DESCRIPTION
This library provides a low-level interface to the PowerPC
SPE unit (SPE).  The routines speTaskRegsSet() and
speTaskRegsGet() set and get SPE registers on a per task basis.
The routine speProbe() checks for the presence of an SPE.
With the exception of speProbe(), the higher level
facilities in dbgLib and usrLib should be used instead of these
routines.  See speLib for architecture independent portion.

SEE ALSO: speLib
*/

#include "vxWorks.h"
#include "objLib.h"
#include "taskLib.h"
#include "taskArchLib.h"
#include "memLib.h"
#include "string.h"
#include "regs.h"
#include "speLib.h"
#include "arch/ppc/esfPpc.h"
#include "excLib.h"
#include "intLib.h"
#include "esf.h"
#include "sysLib.h"
#include "rebootLib.h"
#include "fioLib.h"

extern STATUS          excConnect (VOIDFUNCPTR *, VOIDFUNCPTR);

/* globals */

/* This variable has to be initialized by the BSP to a routine which
   returns TRUE if the CPU supports SPE UNIT. It has to be initialized
   before calling speInit.
 */ 
int       (* _func_speProbeRtn) () = NULL;

/*******************************************************************************
*
* speArchInit - initialize spe unit support
*
* This routine must be called before using the spe unit.
* It is typically called from speInit().
*
* NOMANUAL
*/

void speArchInit (void)
    {
    speCreateHookRtn = (FUNCPTR) NULL;
    }

/*******************************************************************************
*
* speArchTaskCreateInit - initialize spe unit support for task
*
* NOMANUAL
*/

void speArchTaskCreateInit
    (
    SPE_CONTEXT *pSpeContext		/* pointer to SPE_CONTEXT */
    )
    {
    /*
     * Initialize the SPE_CONTEXT structure for the new task:
     */

    bfill ((char *) pSpeContext, sizeof (SPE_CONTEXT), 0x00); 

    }

/*******************************************************************************
*
* speTaskRegsGet - get the spe registers from a task TCB
*
* This routine copies the spe registers of a task to the locations whose 
* pointers are passed as parameters.  
*
* NOTE
* This routine only works well if <task> is not the calling task.
* If a task tries to discover its own registers, the values will be stale
* (i.e., leftover from the last task switch).
*
* RETURNS: OK, or ERROR if there is no spe support.
*
* SEE ALSO: speTaskRegsSet()
*/

STATUS speTaskRegsGet
    (
    int task,           	/* task to get info about */
    SPEREG_SET *pSpeRegSet	/* pointer to spe register set */
    )
    {
    int ix;
    SPEREG_SET *pSpeContext;
    WIND_TCB *pTcb = taskTcb (task);
    int			reg;

    if (pTcb == NULL)
	return (ERROR);

    pSpeContext = SPE_CONTEXT_GET(pTcb);

    if (pSpeContext == (SPE_CONTEXT *)NULL)
	return (ERROR);			/* no SPE support */
    else
	{
        for (reg=0; reg<SPE_NUM_REGS; reg++)
            {
            pSpeRegSet->gpr[reg] = pSpeContext->gpr[reg];
            }
        
	pSpeRegSet->acc[0] = pSpeContext->acc[0];
	pSpeRegSet->acc[1] = pSpeContext->acc[1];
	}

    return (OK);
    }

/*******************************************************************************
*
* speTaskRegsSet - set the spe registers of a task
*
* This routine loads the specified values into the specified task TCB.
*
* RETURNS: OK, or ERROR if there is no spe support.
*
* SEE ALSO: speTaskRegsGet()
*/

STATUS speTaskRegsSet
    (
    int task,           	    /* task whose registers are to be set */
    SPEREG_SET *pSpeRegSet  /* pointer to spe register set */
    )
    {

    FAST WIND_TCB *pTcb = taskTcb (task);
    FAST SPE_CONTEXT *pSpeContext;
    int reg,ix;

    if (pTcb == NULL)
	return (ERROR);

    pSpeContext = SPE_CONTEXT_GET(pTcb);

    if (pSpeContext == (SPE_CONTEXT *)NULL)
	return (ERROR);			/* no SPEU support, PUT ERRNO */
    else
	{

        for (reg=0; reg<SPE_NUM_REGS; reg++)
            {
            pSpeContext->gpr[reg] = pSpeRegSet->gpr[reg];
            }

            pSpeContext->acc[0] = pSpeRegSet->acc[0];
            pSpeContext->acc[1] = pSpeRegSet->acc[1];

	}

    return (OK);
    }

/*******************************************************************************
*
* speProbe - probe for the presence of a spe unit
*
* This routine determines whether a PowerPC spe unit is present.
* NOTE:  The BSP has to provide with a routine which returns TRUE if
         the CPU has a SPE UNIT.
* RETURNS:
* OK if the spe unit is present, otherwise ERROR.
*/

STATUS speProbe ()
    {

    if (_func_speProbeRtn == NULL)
        return (ERROR);

    return (_func_speProbeRtn ());

    }

/******************************************************************************
*
* speRegsToCtx - convert SPEREG_SET to SPE_CONTEXT.
*/

void speRegsToCtx
    (
    SPEREG_SET *  pSpeRegSet,             /* input -  spe reg set */
    SPE_CONTEXT * pSpeContext             /* output - spe context */
    )
    {

    bcopy ((char *) pSpeRegSet, (char *)pSpeContext,
           sizeof (SPE_CONTEXT));    
    }

/******************************************************************************
*
* speCtxToRegs - convert SPE_CONTEXT to SPEREG_SET.
*/

void speCtxToRegs
    (
    SPE_CONTEXT * pSpeContext,            /* input -  spe context */
    SPEREG_SET *  pSpeRegSet              /* output - spe register set */
    )
    {
    bcopy ((char *) pSpeContext, (char *)pSpeRegSet,
           sizeof (SPE_CONTEXT));    
    }

