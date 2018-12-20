/* altivecArchLib.c - PowerPC altivec unit support library */

/* Copyright 2001-2002 Wind River Systems, Inc. */
#include "copyright_wrs.h"

/*
modification history
--------------------
01d,21nov02,pch  SPR 84107: initialize _func_altivecTaskRegsShow and
		 _func_altivecProbe
01c,15jun01,pch  fix redefinition of `_func_altivecProbeRtn',
                 and finish removal of altiVecExcHandle()
01b,14jun01,kab  Fixed Altivec Unavailable exchandler, SPR 68206
01a,21mar01,pcs  Enable AltivecProbe
*/

/*
DESCRIPTION
This library provides a low-level interface to the PowerPC
ALTIVEC unit (ALTIVEC).  The routines altivecTaskRegsSet() and
altivecTaskRegsGet() set and get ALTIVEC registers on a per task basis.
The routine altivecProbe() checks for the presence of an ALTIVEC.
With the exception of altivecProbe(), the higher level
facilities in dbgLib and usrLib should be used instead of these
routines.  See altivecLib for architecture independent portion.

SEE ALSO: altivecLib
*/

#include "vxWorks.h"
#include "objLib.h"
#include "taskLib.h"
#include "taskArchLib.h"
#include "memLib.h"
#include "string.h"
#include "regs.h"
#include "altivecLib.h"
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
   returns TRUE if the CPU supports ALTIVEC UNIT. It has to be initialized
   before calling altivecInit.
 */ 
int       (* _func_altivecProbeRtn) () = NULL;

/*******************************************************************************
*
* altivecArchInit - initialize altivec unit support
*
* This routine must be called before using the altivec unit.
* It is typically called from altivecInit().
*
* NOMANUAL
*/

void altivecArchInit (void)
    {
    altivecCreateHookRtn = (FUNCPTR) NULL;
    _func_altivecProbe = (FUNCPTR) altivecProbe;
    _func_altivecTaskRegsShow = (FUNCPTR) altivecTaskRegsShow;
    }

/*******************************************************************************
*
* altivecArchTaskCreateInit - initialize altivec unit support for task
*
* NOMANUAL
*/

void altivecArchTaskCreateInit
    (
    ALTIVEC_CONTEXT *pAltivecContext		/* pointer to ALTIVEC_CONTEXT */
    )
    {
    /*
     * Initialize the ALTIVEC_CONTEXT structure for the new task:
     */

    bfill ((char *) pAltivecContext, sizeof (ALTIVEC_CONTEXT), 0x00); 

    }

/*******************************************************************************
*
* altivecTaskRegsGet - get the altivec registers from a task TCB
*
* This routine copies the altivec registers of a task to the locations whose 
* pointers are passed as parameters.  
*
* NOTE
* This routine only works well if <task> is not the calling task.
* If a task tries to discover its own registers, the values will be stale
* (i.e., leftover from the last task switch).
*
* RETURNS: OK, or ERROR if there is no altivec support.
*
* SEE ALSO: altivecTaskRegsSet()
*/

STATUS altivecTaskRegsGet
    (
    int task,           	/* task to get info about */
    ALTIVECREG_SET *pAltivecRegSet	/* pointer to altivec register set */
    )
    {
    int ix;
    ALTIVECREG_SET *pAltivecContext;
    WIND_TCB *pTcb = taskTcb (task);
    int			reg;

    if (pTcb == NULL)
	return (ERROR);

    pAltivecContext = ALTIVEC_CONTEXT_GET(pTcb);

    if (pAltivecContext == (ALTIVEC_CONTEXT *)NULL)
	return (ERROR);			/* no ALTIVEC support */
    else
	{
        for (reg=0; reg<ALTIVEC_NUM_REGS; reg++)
        {
     	  for (ix = 0; ix < 4; ix++)
          {
            pAltivecRegSet->vrfile[reg][ix] = pAltivecContext->vrfile[reg][ix];
          }

        }
        for (ix = 0; ix < 4; ix++)
        {
          pAltivecRegSet->vscr[ix] = pAltivecContext->vscr[ix];
        }
        pAltivecRegSet->vrsave  = pAltivecContext->vrsave;
	}

    return (OK);
    }

/*******************************************************************************
*
* altivecTaskRegsSet - set the altivec registers of a task
*
* This routine loads the specified values into the specified task TCB.
*
* RETURNS: OK, or ERROR if there is no altivec support.
*
* SEE ALSO: altivecTaskRegsGet()
*/

STATUS altivecTaskRegsSet
    (
    int task,           	    /* task whose registers are to be set */
    ALTIVECREG_SET *pAltivecRegSet  /* pointer to altivec register set */
    )
    {

    FAST WIND_TCB *pTcb = taskTcb (task);
    FAST ALTIVEC_CONTEXT *pAltivecContext;
    int reg,ix;

    if (pTcb == NULL)
	return (ERROR);

    pAltivecContext = ALTIVEC_CONTEXT_GET(pTcb);

    if (pAltivecContext == (ALTIVEC_CONTEXT *)NULL)
	return (ERROR);			/* no ALTIVECU support, PUT ERRNO */
    else
	{
        for (reg=0; reg<ALTIVEC_NUM_REGS; reg++)
        {
     	  for (ix = 0; ix < 4; ix++)
          {
            pAltivecContext->vrfile[reg][ix] = pAltivecRegSet->vrfile[reg][ix];
          }

        }
        for (ix = 0; ix < 4; ix++)
        {
          pAltivecContext->vscr[ix] = pAltivecRegSet->vscr[ix];
        }
        pAltivecContext->vrsave = pAltivecRegSet->vrsave;
	}

    return (OK);
    }

/*******************************************************************************
*
* altivecProbe - probe for the presence of a altivec unit
*
* This routine determines whether a PowerPC altivec unit is present.
* NOTE:  The BSP has to provide with a routine which returns TRUE if
         the CPU has a ALTIVEC UNIT.
* RETURNS:
* OK if the altivec unit is present, otherwise ERROR.
*/

STATUS altivecProbe ()
    {

    if (_func_altivecProbeRtn == NULL)
        return (ERROR);

    return (_func_altivecProbeRtn ());

    }

/******************************************************************************
*
* altivecRegsToCtx - convert ALTIVECREG_SET to ALTIVEC_CONTEXT.
*/

void altivecRegsToCtx
    (
    ALTIVECREG_SET *  pAltivecRegSet,             /* input -  altivec reg set */
    ALTIVEC_CONTEXT * pAltivecContext             /* output - altivec context */
    )
    {

    bcopy ((char *) pAltivecRegSet, (char *)pAltivecContext,
           sizeof (ALTIVEC_CONTEXT));    
    }

/******************************************************************************
*
* altivecCtxToRegs - convert ALTIVEC_CONTEXT to ALTIVECREG_SET.
*/

void altivecCtxToRegs
    (
    ALTIVEC_CONTEXT * pAltivecContext,            /* input -  altivec context */
    ALTIVECREG_SET *  pAltivecRegSet              /* output - altivec register set */
    )
    {
    bcopy ((char *) pAltivecContext, (char *)pAltivecRegSet,
           sizeof (ALTIVEC_CONTEXT));    
    }

