/* altivecLib.c - ALTIVEC coprocessor support library */

/* Copyright 1984-1994 Wind River Systems, Inc. */
#include "copyright_wrs.h"

/*
modification history
--------------------
01e,08may02,dtr  Zeroing the altivec TCB pointer. SPR 75407
01d,07mar02,pcs  AltivecDummyContext needs to be 16 byte aligned. 
                 Malloc this during the init and align it to 16 bytes.
01c,13nov01,kab  Added manifest const for _PPC_MSR_VEC
01b,24may01,kab  Moved enabling ALTIVEC bit in MSR to altivec-specific task
                 create
01a,29mar01,pcs  Implement code review suggestions.
*/

/*
DESCRIPTION
This library provides a general interface to the Altivec coprocessor.
To activate ALTIVEC support, altivecInit() must be called before any
tasks using the coprocessor are spawned.  This is done automatically by
the root task, usrRoot(), in usrConfig.c when the configuration macro
INCLUDE_ALTIVEC is defined.

For information about architecture-dependent ALTIVEC routines, see
the manual entry for altivecArchLib.

The altivecShow() routine displays altivec registers on a per-task basis.
For information on this facility, see the manual entries for altivecShow and
altivecShow().

VX_ALTIVEC_TASK OPTION
Saving and restoring ALTIVEC registers adds to the context switch
time of a task.  Therefore, ALTIVEC registers are not saved
and restored for every task.  Only those tasks spawned with the task
option VX_ALTIVEC_TASK will have ALTIVEC registers saved and restored.

.RS 4 4
\%NOTE:  If a task does any altivec operations,
it must be spawned with VX_ALTIVEC_TASK.
.RE

INTERRUPT LEVEL
ALTIVEC registers are not saved and restored for interrupt
service routines connected with intConnect().  However, if necessary,
an interrupt service routine can save and restore altivec registers
by calling routines in altivecArchLib.

INCLUDE FILES: altivecLib.h

SEE ALSO: altivecArchLib, altivecShow, intConnect(),
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
#include "altivecLib.h"
#include "regs.h"
#include "logLib.h"
#include "string.h"

/* globals */
extern WIND_TCB *       pTaskLastAltivecTcb;
WIND_TCB *	pAltivecTaskIdPrevious;	/* Task ID for deferred exceptions */
FUNCPTR		altivecCreateHookRtn;	/* arch dependent create hook routine */
FUNCPTR		altivecDisplayHookRtn;	/* arch dependent display routine */

/* forward declarations */

LOCAL void altivecCreateHook (WIND_TCB *pTcb);
LOCAL void altivecSwapHook (WIND_TCB *pOldTcb, WIND_TCB *pNewTcb);

LOCAL ALTIVEC_CONTEXT * pAltivecDummyContext;


/*******************************************************************************
*
* altivecInit - initialize altivec coprocessor support
*
* This routine initializes altivec coprocessor support and must be
* called before using the altivec coprocessor.  This is done
* automatically by the root task, usrRoot(), in usrConfig.c when the
* configuration macro INCLUDE_ALTIVEC is defined.
* 
* RETURNS: N/A
*/

void altivecInit (void)

    {
    if ( altivecProbe() == OK )
       {
       taskCreateHookAdd ((FUNCPTR) altivecCreateHook);
       taskSwapHookAdd ((FUNCPTR) altivecSwapHook);

       /* Allocate memory for Dummy altivec task context */

       pAltivecDummyContext = (ALTIVEC_CONTEXT *) memalign (16, sizeof (ALTIVEC_CONTEXT));
       if ( pAltivecDummyContext != NULL )
       {  
          /* fills with Zero     */
          bfill ((char *) pAltivecDummyContext, sizeof (ALTIVEC_CONTEXT), 0); 
       }

       altivecArchInit ();
       }
    }
/*******************************************************************************
*
* altivecCreateHook - initialize altivec coprocessor support for task
*
* Carves an altivec coprocessor context from the end of the stack.
* This routine is called whenever a task is created with the VX_ALTIVEC_TASK
* option bit set. This routine has to installed in the Task Create Table via
* the taskCreateHookAdd routine when the altivec Library is initialized.
*
* NOMANUAL
*/

LOCAL void altivecCreateHook
    (
    FAST WIND_TCB *pTcb		/* newly create task tcb */
    )
    {
    unsigned int *pMem;

    /* check for option bit and presence of altivec coprocessor */

    if (pTcb->options & VX_ALTIVEC_TASK)
	{
	/* allocate space for saving context and registers */

        /*  
         * The altivec context has to be 16 byte aligned.
         * We have to ask for an extra 8 bytes to allow for the 
	 * rounding up to the 16 byte address in case taskStackAllot()
	 * returns an 8 byte aligned memory address.
         */

        pMem = taskStackAllot ((int) pTcb, sizeof (ALTIVEC_CONTEXT)+8);
 
	if ( pMem == NULL )
	   return;

        /*  Align on a 16 byte boundary. */
        pMem = (unsigned int *) ROUND_UP(pMem,16);

        ALTIVEC_CONTEXT_SET(pTcb,pMem);

	pTcb->regs.msr |= (_PPC_MSR_VEC << 16);           /* enable ALTIVEC */

	taskSwapHookAttach ((FUNCPTR) altivecSwapHook, (int) pTcb, 
			    TRUE, FALSE);

	taskLock ();
	altivecArchTaskCreateInit ((ALTIVEC_CONTEXT *)pMem);

	taskUnlock ();
        
        /* Call Arch specific routine. */
	if (altivecCreateHookRtn != NULL)
	    (*altivecCreateHookRtn) (pTcb);

	}
    else 
        ALTIVEC_CONTEXT_SET(pTcb,NULL);
     
    }
/*******************************************************************************
*
* altivecSwapHook - swap in task altivec coprocessor registers
*
* This routine is the task swap hook that implements the task altivec
* coprocessor registers facility.  It swaps the current and saved values of
* all the task coprocessor registers of the last altivec task and the
* in-coming altivec task.
* This routine is called whenever a task is Swapped in by the Kernel scheduler
* This routine has to installed in the Task Swap Table via the taskSwapHookAdd 
* routine when the altivec Library is initialized.
*/

LOCAL void altivecSwapHook
    (
    WIND_TCB *pOldTcb,      /* task tcb switching out */
    FAST WIND_TCB *pNewTcb  /* task tcb switching in */
    )
    {

    ALTIVEC_CONTEXT * pAlti;

    if (pTaskLastAltivecTcb == pNewTcb)
        return;
 
    /* save task coprocessor registers into last altivec task */

    if (pTaskLastAltivecTcb != NULL)
        {
        pAltivecTaskIdPrevious = pTaskLastAltivecTcb;
        pAlti = ALTIVEC_CONTEXT_GET(pTaskLastAltivecTcb);
        altivecSave (pAlti);
        }
    else
        altivecSave (pAltivecDummyContext);     /* to avoid protocol errors */

    /* restore task coprocessor registers of incoming task */
    
    if (pNewTcb->options & VX_ALTIVEC_TASK)
       {
       pAlti = ALTIVEC_CONTEXT_GET(pNewTcb);
       altivecRestore (pAlti);
       }
    pTaskLastAltivecTcb = pNewTcb;

    }


