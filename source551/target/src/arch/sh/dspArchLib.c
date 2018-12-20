/* dspArchLib.c - Hitachi SH dsp coprocessor support library */

/* Copyright 1998-2000 Wind River Systems, Inc. */
#include "copyright_wrs.h"

/*
modification history
--------------------
01c,09sep00,hk   changed dspArchInit() to preserve SR.DSP bit for SH7729.
		 added BOOL dspEnabled for dspArchInit()/dspProbe().
		 suppressed compilation warning on dspArchTaskCreateInit().
01b,01sep98,kab  Added MOD reg.
01a,22jul98,mem  written.
*/

/*
DESCRIPTION
This library provides a low-level interface to Hitachi SH-DSP
support.

Routines dspTaskRegsSet, and dspTaskRegsGet allow inspection and setting of
dsp registers on a per task basis.  DspProbe checks the presence
of the dsp support on chip.  Excepting dspProbe, users should not
normally use these routines but use the higher level facilities in dbgLib and
usrLib.  See dspLib for architecture independent portion.
*/

#include "vxWorks.h"
#include "private/taskLibP.h"
#include "memLib.h"
#include "dspLib.h"
#include <string.h>		/* memcpy() */
#if (CPU==SH7700)
#include "intLib.h"		/* intGlobalSRSet() */
#endif /* CPU==SH7700 */


/* globals */

REG_INDEX dspRegName[] = 
    {
    {"a0",	DSPREG_SET_A0},
    {"a0g",	DSPREG_SET_A0G},
    {"a1",	DSPREG_SET_A1},
    {"a1g",	DSPREG_SET_A1G},
    {"m0",	DSPREG_SET_M0},
    {"m1",	DSPREG_SET_M1},
    {"x0",	DSPREG_SET_X0},
    {"x1",	DSPREG_SET_X1},
    {"y0",	DSPREG_SET_Y0},
    {"y1",	DSPREG_SET_Y1},
    {NULL, 0},
    };

REG_INDEX dspCtlRegName[] = 
    {
    {"rs",	DSPREG_SET_RS},
    {"re",	DSPREG_SET_RE},
    {"dsr",	DSPREG_SET_DSR},
    {"mod",	DSPREG_SET_MOD},
    {NULL, 0},
    };

ULONG initialTaskDSR = DSR_CARRY_MODE;


/* locals */

LOCAL BOOL dspEnabled = FALSE;


/******************************************************************************
*
* dspArchInit - initialize dsp support
*
* This routine must be called before using the dsp.
*
* NOMANUAL
*/

void dspArchInit (void)
    {
#if (CPU==SH7700)

    /* Enable the SR.DSP bit. (XXX - Here we assume that the total number of
     * already spawned tasks prior to this intGlobalSRSet() call is under 64)
     */

    if (intGlobalSRSet (0x00001000, 0xffffefff, 64) == OK)
	dspEnabled = TRUE;
#else

    dspEnabled = TRUE;

#endif
    }

/******************************************************************************
*
* dspArchTaskCreateInit - initialize dsp support for task
*
* NOMANUAL
*/

void dspArchTaskCreateInit
    (
    DSP_CONTEXT * pDspContext		/* pointer to DSP_CONTEXT */
    )
    {
    bzero ((char *)pDspContext, sizeof (DSP_CONTEXT));
    pDspContext->dsr = initialTaskDSR;
    }

/******************************************************************************
*
* dspTaskRegsGet - get a task's dsp registers from TCB
*
* This routine returns, in the location whose pointer is
* passed as a parameter, the task's dsp registers as
* an array containing the registers.
*
* NOTE
* This routine only works well if the specified task is not that
* of the calling task.  If a task tries to discover its own registers,
* the values will be stale, i.e. leftover from the last task switch.
*
* RETURNS: OK, or ERROR if there is no dsp support.
*
* SEE ALSO: dspTaskRegsSet()
*/

STATUS dspTaskRegsGet
    (
    int			task,	       	/* task to get info about */
    DSPREG_SET *	pDspRegSet	/* pointer to dsp register set */
    )
    {
    DSP_CONTEXT *pDspContext;
    WIND_TCB *pTcb = taskTcb (task);

    if (pTcb == NULL)
	return (ERROR);

    pDspContext = pTcb->pDspContext;
    if (pDspContext == (DSP_CONTEXT *)NULL)
	return (ERROR);			/* no coprocessor support */

    memcpy (pDspRegSet, pDspContext, sizeof (DSP_CONTEXT));
    return (OK);
    }

/******************************************************************************
*
* dspTaskRegsSet - set the dsp registers of a task
*
* This routine loads the specified values into the specified task TCB.
*
* RETURNS: OK, or ERROR if there is no dsp support.
*
* SEE ALSO: dspTaskRegsGet()
*/

STATUS dspTaskRegsSet
    (
    int		  task,		/* task whose registers are to be set */
    DSPREG_SET *  pDspRegSet 	/* pointer to dsp register set */
    )
    {
    DSP_CONTEXT *pDspContext;
    WIND_TCB *pTcb = taskTcb (task);

    if (pTcb == NULL)
	return (ERROR);

    pDspContext = pTcb->pDspContext;
    if (pDspContext == (DSP_CONTEXT *)NULL)
	return (ERROR);			/* no coprocessor support */

    memcpy (pDspContext, pDspRegSet, sizeof (DSPREG_SET));
    return (OK);
    }

/******************************************************************************
*
* dspProbe - probe for the presence of a dsp
*
* This routine determines whether this processor supports dsp ops.
*
* IMPLEMENTATION
* The SH7729 does not understand DSP instructions until setting the SR.DSP bit
* to 1.  Also it is NOT advised by Hitachi to set the SH.DSP bit to 1 on other
* SH7700 CPUs.  So we assume that DSP is available if dspEnabled is set TRUE
* by dspArchInit().
*
* RETURNS:
* OK if on-chip dsp support is present, otherwise ERROR.
*/

STATUS dspProbe (void)
    {
    return (dspEnabled ? OK : ERROR);
    }
