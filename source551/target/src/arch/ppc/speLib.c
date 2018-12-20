/* speLib.c - SPE support library */

/* Copyright 1984-1994 Wind River Systems, Inc. */
#include "copyright_wrs.h"

/*
modification history
--------------------
01b,17oct02,dtr  Change bit masking of SPE bit in msr.
01a,29mar01,pcs  Implement code review suggestions.
*/

/*
DESCRIPTION
This library provides a general interface to the Spe part of the gpr's.
To activate SPE support, speInit() must be called before any
tasks using the SPE are spawned.  This is done automatically by
the root task, usrRoot(), in usrConfig.c when the configuration macro
INCLUDE_SPE is defined.

For information about architecture-dependent SPE routines, see
the manual entry for speArchLib.

The speShow() routine displays spe registers on a per-task basis.
For information on this facility, see the manual entries for speShow and
speShow().

VX_SPE_TASK OPTION
Saving and restoring SPE registers adds to the context switch
time of a task.  Therefore, SPE registers are not saved
and restored for every task.  Only those tasks spawned with the task
option VX_SPE_TASK will have SPE registers saved and restored.

.RS 4 4
\%NOTE:  If a task does any spe operations,
it must be spawned with VX_SPE_TASK.
.RE

INTERRUPT LEVEL
SPE registers are not saved and restored for interrupt
service routines connected with intConnect().  However, if necessary,
an interrupt service routine can save and restore spe registers
by calling routines in speArchLib.

INCLUDE FILES: speLib.h

SEE ALSO: speArchLib, speShow, intConnect(),
.pG "Basic OS"
*/

#include "vxWorks.h"
#include "objLib.h"
#include "private/taskLibP.h"
#include "taskArchLib.h"
#include "taskHookLib.h"
#include "memLib.h"
#include "stdio.h"
#include "iv.h"
#include "speLib.h"
#include "regs.h"
#include "logLib.h"
#include "string.h"

/* globals */
extern WIND_TCB *       pTaskLastSpeTcb;
WIND_TCB *	pSpeTaskIdPrevious;	/* Task ID for deferred exceptions */
FUNCPTR		speCreateHookRtn;	/* arch dependent create hook routine */
FUNCPTR		speDisplayHookRtn;	/* arch dependent display routine */

/* forward declarations */

LOCAL void speCreateHook (WIND_TCB *pTcb);
LOCAL void speSwapHook (WIND_TCB *pOldTcb, WIND_TCB *pNewTcb);

LOCAL SPE_CONTEXT * pSpeDummyContext;


/*******************************************************************************
*
* speInit - initialize spe coprocessor support
*
* This routine initializes spe coprocessor support and must be
* called before using the spe coprocessor.  This is done
* automatically by the root task, usrRoot(), in usrConfig.c when the
* configuration macro INCLUDE_SPE is defined.
* 
* RETURNS: N/A
*/

void speInit (void)

    {
    if ( speProbe() == OK )
       {
       taskCreateHookAdd ((FUNCPTR) speCreateHook);
       taskSwapHookAdd ((FUNCPTR) speSwapHook);

       /* Allocate memory for Dummy spe task context */

       pSpeDummyContext = (SPE_CONTEXT *) memalign (_CACHE_ALIGN_SIZE,sizeof (SPE_CONTEXT));
       if ( pSpeDummyContext != NULL )
       {  
          /* fills with Zero     */
          bfill ((char *) pSpeDummyContext, sizeof (SPE_CONTEXT), 0); 
       }

       speArchInit ();
       }
    }
/*******************************************************************************
*
* speCreateHook - initialize spe coprocessor support for task
*
* Carves an spe context from the end of the stack.
* This routine is called whenever a task is created with the VX_SPE_TASK
* option bit set. This routine has to installed in the Task Create Table via
* the taskCreateHookAdd routine when the spe Library is initialized.
*
* NOMANUAL
*/

LOCAL void speCreateHook
    (
    FAST WIND_TCB *pTcb		/* newly create task tcb */
    )
    {
    unsigned int *pMem;

    /* check for option bit and presence of the spe */

    if (pTcb->options & VX_SPE_TASK)
	{
	/* allocate space for saving context and registers */

        /*  
         * The spe context has to be 16 byte aligned.
         * We have to ask for an extra 8 bytes to allow for the 
	 * rounding up to the 16 byte address in case taskStackAllot()
	 * returns an 8 byte aligned memory address.
         */

        pMem = taskStackAllot ((int) pTcb, sizeof (SPE_CONTEXT) + _CACHE_ALIGN_SIZE);
 
	if ( pMem == NULL )
	   return;

        /*  Align on a 16 byte boundary. */
        pMem = (unsigned int *) ROUND_UP(pMem,_CACHE_ALIGN_SIZE);

        SPE_CONTEXT_SET(pTcb,pMem);

	pTcb->regs.msr |= (_PPC_MSR_SPE);           /* enable SPE */

	taskSwapHookAttach ((FUNCPTR) speSwapHook, (int) pTcb, 
			    TRUE, FALSE);

	taskLock ();
	speArchTaskCreateInit ((SPE_CONTEXT *)pMem);

	taskUnlock ();
        
        /* Call Arch specific routine. */
	if (speCreateHookRtn != NULL)
	    (*speCreateHookRtn) (pTcb);

	}
    else 
        SPE_CONTEXT_SET(pTcb,NULL);
     
    }
/*******************************************************************************
*
* speSwapHook - swap in task spe registers
*
* This routine is the task swap hook that implements the task spe
* registers facility.  It swaps the current and saved values of
* all the task spe registers of the last spe task and the
* in-coming spe task.
* This routine is called whenever a task is Swapped in by the Kernel scheduler
* This routine has to installed in the Task Swap Table via the taskSwapHookAdd 
* routine when the spe Library is initialized.
*/

LOCAL void speSwapHook
    (
    WIND_TCB *pOldTcb,      /* task tcb switching out */
    FAST WIND_TCB *pNewTcb  /* task tcb switching in */
    )
    {

    SPE_CONTEXT * pSpe;

    if (pTaskLastSpeTcb == pNewTcb)
        return;
 
    /* save task spe registers into last spe task */

    if (pTaskLastSpeTcb != NULL)
        {
        pSpeTaskIdPrevious = pTaskLastSpeTcb;
        pSpe = SPE_CONTEXT_GET(pTaskLastSpeTcb);
        speSave (pSpe);
        }
    else
        speSave (pSpeDummyContext);     /* to avoid protocol errors */

    /* restore task spe registers of incoming task */
    
    if (pNewTcb->options & VX_SPE_TASK)
       {
       pSpe = SPE_CONTEXT_GET(pNewTcb);
       speRestore (pSpe);
       }
    pTaskLastSpeTcb = pNewTcb;

    }


