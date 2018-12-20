/* excArchLib.c - ColdFire exception handling facilities */

/* Copyright 1984-2000 Wind River Systems, Inc. */
#include "copyright_wrs.h"

/*
modification history
--------------------
01d,30nov00,dh  Temporary fix in excTasRetry (MCF5400).
01c,26sep00,dh   MCF5200/5400 differences. Still needs work.
01b,19jun00,ur   Removed all non-Coldfire stuff.
01a,17mar00,dra  Created from T1.0.1 ColdFire and T2 m68k ports.
*/

/*
This module contains Coldfire architecture dependent portions of the
exception handling facilities.  See excLib for the portions that are
architecture independent.

SEE ALSO: dbgLib, sigLib, intLib, "Debugging"
*/

#include "vxWorks.h"
#include "esf.h"
#include "iv.h"
#include "sysLib.h"
#include "intLib.h"
#include "taskLib.h"
#include "qLib.h"
#include "errno.h"
#include "string.h"
#include "fppLib.h"
#include "vxLib.h"
#include "logLib.h"
#include "rebootLib.h"
#include "private/funcBindP.h"
#include "private/kernelLibP.h"
#include "private/taskLibP.h"
#include "private/sigLibP.h"
#include "private/eventP.h"

/* local variables */

#if (CPU == MCF5400)
LOCAL int excTasErrors;		/* count of TAS bus errors - just curiosity */
#endif /* (CPU == MCF5400) */

/* forward functions */

IMPORT	void	intEntTrap ();

/* forward static functions */

LOCAL void	excGetInfoFromESF (int vecNum, void *pEsf, REG_SET *pRegs,
				   EXC_INFO *pExcInfo);
#if (CPU == MCF5400)
LOCAL BOOL	excTasRetry (int vecNum, ESFCOLD *pEsf, REG_SET *pRegs);
#endif /* (CPU == MCF5400) */


/*******************************************************************************
*
* excVecInit - initialize the exception/interrupt vectors
*
* This routine sets all exception vectors to point to the appropriate
* default exception handlers.  These handlers will safely trap and report
* exceptions caused by program errors or unexpected hardware interrupts.
* All vectors from vector 2 (address 0x0008) to 255 (address 0x03fc) are
* initialized.  Vectors 0 and 1 contain the reset stack pointer and program
* counter.
*
* WHEN TO CALL
* This routine is usually called from the system start-up routine
* usrInit() in usrConfig, before interrupts are enabled.
*
* RETURNS: OK (always).
*/

STATUS excVecInit (void)
    {
    FAST int vecNum;

    /* make exception vectors point to proper place in bsr table */

    for (vecNum = LOW_VEC; vecNum <= HIGH_VEC; ++vecNum)
	{
	if (((BUS_ERROR_VEC <= vecNum) && (vecNum <= FORMAT_ERROR)) ||
	    ((TRAP_0_VEC <= vecNum ) && (vecNum < USER_VEC_START)))
	    {
	    intVecSet ((FUNCPTR *)INUM_TO_IVEC (vecNum), (FUNCPTR)excStub);
	    }
	else
	    {
	    intVecSet ((FUNCPTR *)INUM_TO_IVEC (vecNum), (FUNCPTR)excIntStub);
	    }
	}

    /* Install trap handler for interrupt entry. This handler will
     * switch on to the interrupt stack.
     */

    intVecSet ((FUNCPTR *) IV_TRAP_1, (FUNCPTR)intEntTrap);

    return (OK);
    }
/*******************************************************************************
*
* excExcHandle - interrupt level handling of exceptions
*
* This routine handles exception traps.  It is never to be called except
* from the special assembly language interrupt stub routine.
*
* It prints out a bunch of pertinent information about the trap that
* occurred via excTask.
*
* Note that this routine runs in the context of the task that got the exception.
*
* NOMANUAL
*/

void excExcHandle
    (
    int		vecNum,	/* exception vector number */
    void *	pEsf,	/* pointer to exception stack frame */
    REG_SET *	pRegs	/* pointer to register info on stack */
    )
    {
    EXC_INFO excInfo;

#if (CPU == MCF5200)
    /*
     * ColdFire CPU's before MCF5400 don't have a divide instruction,
     * so __divsi3 executes a "trap #0" when divide by zero is detected.
     * Re-map the exception here.
     */
    if (vecNum == IVEC_TO_INUM(IV_TRAP_0))
	vecNum = IVEC_TO_INUM(IV_ZERO_DIVIDE);
#endif /* (CPU == MCF5200) */

    excGetInfoFromESF (vecNum, pEsf, pRegs, &excInfo);	/* fill excInfo/pRegs */

    if ((_func_excBaseHook != NULL) && 			/* user hook around? */
	((* _func_excBaseHook) (vecNum, pEsf, pRegs, &excInfo)))
	return;						/* user hook fixed it */

#if (CPU == MCF5400)
    if (excTasRetry (vecNum, pEsf, pRegs))
	return;						/* retry the TAS */
#endif /* (CPU == MCF5400) */

#ifdef WV_INSTRUMENTATION

    /* windview - level 3 event logging */
    EVT_CTX_1(EVENT_EXCEPTION, vecNum);

#endif

    /* if exception occured in an isr or before multi tasking then reboot */

    if ((INT_CONTEXT ()) || (Q_FIRST (&activeQHead) == NULL))
	{
	if (_func_excPanicHook != NULL)			/* panic hook? */
	    (*_func_excPanicHook) (vecNum, pEsf, pRegs, &excInfo);

	reboot (BOOT_WARM_AUTOBOOT);
	return;						/* reboot returns?! */
	}

    /* task caused exception */

    taskIdCurrent->pExcRegSet = pRegs;			/* for taskRegs[GS]et */

    taskIdDefault ((int)taskIdCurrent);			/* update default tid */

    bcopy ((char *) &excInfo, (char *) &(taskIdCurrent->excInfo),
	   sizeof (EXC_INFO));				/* copy in exc info */

    if (_func_sigExcKill != NULL)			/* signals installed? */
	(*_func_sigExcKill) (vecNum, INUM_TO_IVEC(vecNum), pRegs);

    if (_func_excInfoShow != NULL)			/* default show rtn? */
	(*_func_excInfoShow) (&excInfo, TRUE);

    if (excExcepHook != NULL)				/* 5.0.2 hook? */
        (* excExcepHook) (taskIdCurrent, vecNum, pEsf);

    taskSuspend (0);					/* whoa partner... */

    taskIdCurrent->pExcRegSet = (REG_SET *) NULL;	/* invalid after rts */
    }
/*******************************************************************************
*
* excIntHandle - interrupt level handling of interrupts
*
* This routine handles interrupts.  It is never to be called except
* from the special assembly language interrupt stub routine.
*
* It prints out a bunch of pertinent information about the trap that
* occurred via excTask().
*
* NOMANUAL
*/

void excIntHandle
    (
    int		vecNum,	/* exception vector number */
    void *	pEsf,	/* pointer to exception stack frame */
    REG_SET *	pRegs	/* pointer to register info on stack */
    )
    {
    EXC_INFO excInfo;

    excGetInfoFromESF (vecNum, pEsf, pRegs, &excInfo);	/* fill excInfo/pRegs */
   
#ifdef WV_INSTRUMENTATION

    /* windview - level 3 event logging */
	EVT_CTX_1(EVENT_EXCEPTION, vecNum);

#endif

    if (_func_excIntHook != NULL)
	(*_func_excIntHook) (vecNum, pEsf, pRegs, &excInfo);

    if (Q_FIRST (&activeQHead) == NULL)			/* pre kernel */
	reboot (BOOT_WARM_AUTOBOOT);			/* better reboot */
    }
/*****************************************************************************
*
* excGetInfoFromESF - get relevent info from exception stack frame
*
*/

LOCAL void excGetInfoFromESF
    (
    FAST int 	vecNum,		/* vector number */
    FAST void *	pEsf,		/* pointer to exception stack frame */
    REG_SET *	pRegs,		/* pointer to register info on stack */
    EXC_INFO *	pExcInfo	/* where to fill in exception info */
    )
    {
    int size;

    pExcInfo->vecNum  = vecNum;
    pExcInfo->valid   = EXC_VEC_NUM;

    pExcInfo->valid    |= EXC_PC | EXC_STATUS_REG | EXC_FUNC_CODE;
    pExcInfo->pc        = ((ESFCOLD *) pEsf)->pc;
    pExcInfo->statusReg = ((ESFCOLD *) pEsf)->sr;
    pExcInfo->funcCode  = *((USHORT *) pEsf);

    size = sizeof (ESFCOLD);

    pRegs->spReg = (ULONG)((char *) pEsf + size);	/* bump up stack ptr */
    }

#if (CPU == MCF5400)
/*******************************************************************************
*
* excTasRetry - retry a TAS instruction
*
* If this was a bus error involving a RMW cycle (TAS instruction) we
* return to the handler to retry it.  Such is the case in a vme
* bus deadlock cycle, where the local CPU initiates a TAS instuction
* (or RMW cycle) at the same time it's dual port arbiter grants the local bus
* to an external access.  The cpu backs off by signaling a bus error and
* setting the RM bit in the special status word of the bus error exception
* frame.  The solution is simply to retry the instruction hoping that the
* external access has been resolved.  Even if a card such as a disk controller
* has grabed the bus for DMA accesses for a long time, the worst that will
* happen is we'll end up back here again, and we can keep trying until we get
* through.
*
* RETURNS: TRUE if retry desired, FALSE if not TAS cycle.
* NOMANUAL
*/

LOCAL BOOL excTasRetry
    (
    int		vecNum,		/* exception vector number */
    ESFCOLD *	pEsf,		/* pointer to exception stack frame */
    REG_SET *	pRegs		/* pointer to register info on stack */
    )
    {

    if (FALSE)	/* MCF5400 has no TAS retry exceptions ??? */
	{
	++excTasErrors;				/* keep count of TAS errors */
	pRegs->dataReg[0] = -1;			/* and place a -1 in "d0" */
	return (TRUE);				/* retry the instruction */
	}
    
    return (FALSE);
    }
#endif /* (CPU == MCF5400) */
