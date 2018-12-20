/* intALib.s - interrupt library assembly language routines */

/* Copyright 1996-2002 Wind River Systems, Inc. */

/*
modification history
--------------------
01p,16jan02,to   add context switch for _fpStatus
01o,17oct01,t_m  convert to FUNC_LABEL:
01n,11oct01,jb   Enabling removal of pre-pended underscores for new compilers
                 (Diab/Gnu elf)
01n,09nov01,scm  remove IF_bitTest...
01m,23jul01,scm  change XScale name to conform to coding standards...
01l,15feb01,jb   Isolate FUNC(IF_bitTest) to XScale
01k,11dec00,scm  replace references to ARMSA2 with XScale
01j,03oct00,scm  add debug for sa2...
01i,13nov98,cdp  added back intLock(), intLock(); removed armIrqFlagSet();
		 added intIFLock(), intIFUnlock(); tidied; optimise for no
		 instrumentation plus minor other optimisations.
01h,02sep98,cjtc port to windView 2.0
01g,31jul98,pr   temporarily commentig out WindView code
01e,09oct97,cdp  change WindView code in intEnt so it logs nothing but
		 just saves the timestamp; apply WindView fixes from
		 Paola Rossaro (incorrect extern and label); tidy up.
01d,23sep97,cdp  removed kludges for old Thumb tool-chains.
01c,05aug97,cdp  rewritten for new interrupt structure.
		 added WindView support.
01b,26mar97,cdp  added ARM7TDMI_T support.
01a,09may96,cdp  written.
*/

/*
DESCRIPTION
This library supports various functions associated with interrupts from
C routines. Note that VxWorks handles IRQ only: FIQ is left for code
outside VxWorks e.g. DRAM refresh, pseudo-DMA etc.


SEE ALSO: intLib, intArchLib

INTERNAL
The 68K versions of routines in this module "link" and "unlk" the "c"
frame pointer for the benefit of the stacktrace facility to allow it to
properly trace tasks executing within these routines. The ARM versions,
like the i86 versions, do not do the equivalent.
*/

#define _ASMLANGUAGE
#include "vxWorks.h"
#include "private/taskLibP.h"
#include "private/eventP.h"

	.data
	.globl	FUNC(copyright_wind_river)
	.long	FUNC(copyright_wind_river)

	/* globals */

	.globl	FUNC(intLock)
	.globl	FUNC(intUnlock)
	.globl	FUNC(intIFLock)
	.globl	FUNC(intIFUnlock)
	.globl	FUNC(intVBRSet)
	.globl	FUNC(intEnt)		/* interrupt entry routine */
	.globl	FUNC(intExit)	/* interrupt exit routine */

	/* externs */

	.extern	VAR(_fpStatus)
	.extern	FUNC(vxSvcIntStackBase)
	.extern	FUNC(errno)
	.extern	FUNC(intCnt)
	.extern	FUNC(_func_armIrqHandler)
	.extern	FUNC(kernelState)
	.extern	FUNC(taskIdCurrent)
	.extern	FUNC(readyQHead)
	.extern	FUNC(reschedule)
#ifdef WV_INSTRUMENTATION
        .extern	FUNC(evtAction)
        .extern	FUNC(wvEvtClass)
        .extern	FUNC(trgEvtClass)
        .extern	FUNC(_func_evtLogT0)
	.extern FUNC(_func_trgCheck)
	.extern	FUNC(workQIsEmpty)
#endif /* WV_INSTRUMENTATION */

#if	(ARM_THUMB)
	.extern	FUNC(arm_call_via_r12)
#endif	/* ARM_THUMB */

	/* variables */

	.data
	.balign	4

intNestingLevel:
	.long	0
#ifdef	CHECK_NESTING
maxIntNestingLevel:
	.long	0
#endif

	.text
	.balign	4
	.code	32

/* PC-relative-addressable symbols - LDR Rn,=sym is broken */

L$__fpStatus:
	.long	VAR(_fpStatus)

#ifdef	CHECK_NESTING
L$maxIntNestingLevel:
	.long	maxIntNestingLevel
#endif
L$_vxSvcIntStackBase:
	.long	FUNC(vxSvcIntStackBase)

	/*
	 * L$_errno, L$_intCnt, L$intNestingLevel MUST be together for
	 * optimisations to work
	 */

L$_errno:
	.long	FUNC(errno)
L$_intCnt:
	.long	FUNC(intCnt)
L$intNestingLevel:
	.long	intNestingLevel

L$__func_armIrqHandler:
	.long	FUNC(_func_armIrqHandler)

L$_kernelState:
	.long	FUNC(kernelState)
L$_taskIdCurrent:
	.long	FUNC(taskIdCurrent)
L$_readyQHead:
	.long	FUNC(readyQHead)

#ifdef WV_INSTRUMENTATION
L$_evtAction:
	.long	FUNC(evtAction)
L$_wvEvtClass:
	.long	FUNC(wvEvtClass)
L$_trgEvtClass:
	.long	FUNC(trgEvtClass)
L$__func_evtLogT0:
	.long	FUNC(_func_evtLogT0)
L$__func_trgCheck:
	.long   FUNC(_func_trgCheck)
L$_workQIsEmpty:
	.long	FUNC(workQIsEmpty)
#endif /* WV_INSTRUMENTATION */

/*******************************************************************************
*
* intLock - lock out IRQ interrupts
*
* This routine disables IRQ interrupts to the CPU but leaves the mask
* state of FIQ interrupts unchanged.  It returns the state of the CPSR
* I bit as the lock-out key for the interrupt level prior to the call
* and this should be passed back to the routine intUnlock() to restore
* the previous interrupt level.
*
* EXAMPLE
* .CS
*     lockKey = intLock ();
*
*      ...
*
*     intUnlock (lockKey);
* .CE
*
* RETURNS
* The I bit from the CPSR as the lock-out key for the interrupt level
* prior to the call.
*
* SEE ALSO: intUnlock(), taskLock()
*
* int intLock ()
*
*/

_ARM_FUNCTION_CALLED_FROM_C(intLock)
	MRS	r1, cpsr		/* get current status */
	AND	r0, r1, #I_BIT		/* save bit to return in r0 */
	ORR	r1, r1, #I_BIT		/* disable IRQs but leave FIQs */
	MSR	cpsr, r1
#if	(ARM_THUMB)
	BX	lr
#else
	MOV	pc, lr
#endif	/* ARM_THUMB */

/*******************************************************************************
*
* intUnlock - cancel IRQ interrupt locks
*
* This routine restores the enable state of IRQ interrupts that have
* been disabled by a call to the routine intLock().  Use the lock-out key
* obtained from the preceding intLock() call.
*
* RETURNS: N/A
*
* SEE ALSO: intLock()
*
* void intUnlock
*       (
*       int lockKey
*       )
*
*/

_ARM_FUNCTION_CALLED_FROM_C(intUnlock)
	MRS	r1, cpsr		/* get current status */
	BIC	r1, r1, #I_BIT		/* clear I bit */
	AND	r0, r0, #I_BIT		/* clear all bits passed except I bit */
	ORR	r1, r1, r0		/* OR in passed bit */
	MSR	cpsr, r1
#if	(ARM_THUMB)
	BX	lr
#else
	MOV	pc, lr
#endif	/* ARM_THUMB */

/*******************************************************************************
*
* intIFLock - lock out IRQ and FIQ interrupts
*
* This routine disables IRQ and FIQ interrupts to the CPU.  It returns
* the state of the CPSR I and F bits as the lock-out key for the
* interrupt level prior to the call and this should be passed back to the
* routine intIFUnlock() to restore the previous interrupt level.
*
* Note that this routine is not a replacement for intLock(); it should
* be used only by code that needs FIQ disabled as well as IRQ (e.g. FIQ
* handling code).
*
* EXAMPLE
* .CS
*     lockKey = intIFLock ();
*
*      ...
*
*     intIFUnlock (lockKey);
* .CE
*
* RETURNS
* The I and F bits from the CPSR as the lock-out key for the interrupt level
* prior to the call.
*
* SEE ALSO: intIFUnlock(), intLock(), intUnlock(), taskLock()
*
* int intIFLock ()
*
*/

_ARM_FUNCTION_CALLED_FROM_C(intIFLock)
	MRS	r1, cpsr		/* get current status */
	AND	r0, r1, #I_BIT | F_BIT	/* save bits to return in r0 */
	ORR	r1, r1, #I_BIT | F_BIT	/* disable IRQ and FIQ */
	MSR	cpsr, r1
#if	(ARM_THUMB)
	BX	lr
#else
	MOV	pc, lr
#endif	/* ARM_THUMB */

/*******************************************************************************
*
* intIFUnlock - cancel IRQ and FIQ interrupt locks
*
* This routine restores the enable state of IRQ and FIQ interrupts that
* have been disabled by a call to the routine intLock().  Use the
* lock-out key obtained from the preceding intIFLock() call.
*
* Note that this routine is not a replacement for intUnlock(); it
* should be used only by code that needs to change the FIQ state as well
* as IRQ (e.g. FIQ handling code).
*
* RETURNS: N/A
*
* SEE ALSO: intIFLock(), intLock(), intUnlock()
*
* void intIFUnlock
*       (
*       int lockKey
*       )
*
*/

_ARM_FUNCTION_CALLED_FROM_C(intIFUnlock)
	MRS	r1, cpsr		/* get current status */
	BIC	r1, r1, #I_BIT | F_BIT	/* clear IRQ and FIQ bits */
	AND	r0, r0, #I_BIT | F_BIT	/* clear all bits passed except I & F */
	ORR	r1, r1, r0		/* OR in passed bit */
	MSR	cpsr, r1
#if	(ARM_THUMB)
	BX	lr
#else
	MOV	pc, lr
#endif	/* ARM_THUMB */

/*******************************************************************************
*
* intVBRSet - set the vector base register
*
* This routine should only be called in supervisor mode.
* It is not used on the ARM.
*
* NOMANUAL

* void intVBRSet (baseAddr)
*      FUNCPTR *baseAddr;       /@ vector base address @/

*/

#if	(ARM_THUMB)
_THUMB_FUNCTION(intVBRSet)
	BX	lr
#else
_ARM_FUNCTION(intVBRSet)
	MOV	pc, lr
#endif	/* ARM_THUMB */

/*******************************************************************************
*
* intEnt - enter an interrupt service routine
*
* This routine is installed on the IRQ vector and is called at the
* entrance to an interrupt service routine to change to an interrupt
* stack, save critical registers and errno, increment the kernel
* interrupt counter and call routines to handler the interrupt. It is
* installed on the vector by excVecInit.
*
* This routine can NEVER be called from C.
*
* SEE ALSO: excVecInit(2)

* void intEnt ()

* INTERNAL
* It is expected that interrupt service routines will run with
* interrupts reenabled. The IRQ mode of the ARM has its own stack pointer
* but its r14 would be overwritten if the interrupt handler were
* reentered. To get around this problem, this routine switches to SVC
* mode (switching to a separate interrupt stack if necessary) before
* calling any interrupt service code. The IRQ stack pointer points to a
* stack which is used before the switch to SVC mode. It needs to be six
* words for every level of nesting of interrupts (PSR,r0-r3,PC).
*
* NOTE: FIQ is no longer handled by this routine and, consequently, cannot use
* VxWorks facilities.
*
*/

_ARM_FUNCTION(intEnt)

	/*
	 * Entered directly from the hardware vector (via LDR pc, [])
	 * Adjust return address so it points to instruction to resume
	 */

	SUB	lr, lr, #4

	/* save regs on IRQ stack */

	STMFD	sp!, {r0-r3,lr}
	MRS	r0, spsr
	STMFD	sp!, {r0}

	/* save sp in non-banked reg so can access saved regs from SVC mode */

	MOV	r2, sp

	/*
	 * switch to SVC mode with IRQs disabled (they should be already)
	 * Note this can be done without clearing the mode bits before ORRing
	 */

	MRS	r1, cpsr

/*
 *  save off cpsr for inspection/debug
 */
	ORR	r1, r1, #MODE_SVC32 | I_BIT
	MSR	cpsr, r1

	/*
	 * INTERRUPTS DISABLED
	 *
	 * r0 = [scratch]
	 * r1 = [scratch]
	 * r2 = irq_sp
	 * r3 = [scratch]
	 * lr = lr of interrupted svc process
	 * MODE: SVC
	 *
	 * bump our interrupt nesting level counter - we have to use
	 * this rather than the kernel's counter (intCnt) because the
	 * kernel sometimes increments its counter to fake interrupt
	 * context and we need something to tell us when we should
	 * change stacks
	 */

	LDR	r1, L$intNestingLevel
	LDR	r0, [r1]
	ADD	r0, r0, #1
	STR	r0, [r1]

#ifdef	CHECK_NESTING
	LDR	r1, L$maxIntNestingLevel
	LDR	r1, [r1]
	CMPS	r0, r1
	LDRHI	r1, L$maxIntNestingLevel
	STRHI	r0, [r1]
#endif

	/* switch to SVC-mode interrupt stack if not already using it */

	MOV	r1, sp				/* save svc_sp */
	TEQS	r0, #1				/* first level of nesting? */
	LDREQ	sp, L$_vxSvcIntStackBase	/* ...yes, change stack */
	LDREQ	sp, [sp]

	/* get errno */

	ADR	r0, L$_errno
	LDMIA	r0, {r0,r3}	/* get pointers to errno and intCnt */
	LDR	r0, [r0]	/* r0 = errno */

	/*
	 * save errno and registers on stack
	 * r0 = errno
	 * r1 = svc_sp
	 * r2 = irq_sp
	 * r3-> intCnt
	 * lr = lr of interrupted svc process
	 */

	STMFD	sp!, {r0-r2,r12,lr}	/* errno, save svc_sp, irq_sp */
					/* svc_r12, svc_lr */

	/*
	 * IRQ stack contains
	 *    irq_SPSR
	 *    r0-r3
	 *    irq_lr
	 *
	 * SVC interruptStack contains
	 *    errno
	 *    svc_sp
	 *    irq_sp
	 *    svc_r12
	 *    svc_lr when changed from IRQ mode to SVC mode
	 *
	 * Carry on with normal intEnt stuff - IRQs still disabled
	 */

	LDR	lr, [r3]	/* increment kernel interrupt counter */
	ADD	lr, lr, #1
	STR	lr, [r3]

	/*
	 * WV_INSTRUMENTATION
	 * WindView Instrumentation for this architecure is performed
	 * single-step in intArchLib.c. No action is required here
	 */

	/* call interrupt handler, via function pointer */

	LDR	r0, L$__func_armIrqHandler	/* get IRQ handler pointer */
#if	(ARM_THUMB)
	ADR	lr, ARM_intExit			/* set return address */
	LDR	r12, [r0]
	B	FUNC(arm_call_via_r12)
#else
	ADR	lr, FUNC(intExit)			/* set return address */
	LDR	pc, [r0]
#endif	/* ARM_THUMB */

/*******************************************************************************
*
* intExit - exit an interrupt service routine
*
* Check the kernel ready queue to determine if resheduling is necessary.  If
* no higher priority task has been readied, and no kernel work has been queued,
* then we return to the interrupted task.
*
* If rescheduling is necessary, the context of the interrupted task is saved
* in its associated TCB.
*
* This routine must be branched to when exiting an interrupt service routine.
* This normally happens automatically, as the return address for the
* higher-level IRQ handler is set to intExit by intEnt.
*
* This routine can NEVER be called from C.
*
* SEE ALSO: intConnect(2)

* void intExit ()

* INTERNAL
*
* REGISTERS
*    lr trashable because this routine does not return
*    r0-r3 trashable because they're on the stack
*
* IRQ stack contains
*    irq_SPSR
*    r0-r3
*    irq_lr
*
* SVC interruptStack contains
*    errno
*    svc_sp
*    irq_sp
*    svc_r12
*    svc_lr when changed from IRQ mode to SVC mode
*/

_ARM_FUNCTION_CALLED_FROM_C(intExit)
ARM_intExit:

	/* restore errno from stack */

	LDMFD	sp!, {lr}
	LDR	r0, L$_errno
	STR	lr, [r0]

	/* disable IRQs */

	MRS	r1, cpsr
	ORR	r0, r1, #I_BIT
	MSR	cpsr, r0

	/* INTERRUPTS DISABLED */

#ifdef WV_INSTRUMENTATION

        /* windview instrumentation - BEGIN
         * log event if work has been done in the interrupt handler.
         */

	LDR	lr, L$_evtAction	/* is instrumentation on? */
	LDR	lr, [lr]
	TEQS	lr, #0
	BNE	instrumentIntExit	/* branch if so */

	/* instrumentation currently disabled */

resumeIntExit:

	/* windview instrumentation - END */
#endif /* WV_INSTRUMENTATION */


	ADR	r0, L$_intCnt
	LDMIA	r0, {r0, r1}	/* get pointers to intCnt, intNestingLevel */

	/*
	 * r0-> intCnt
	 * r1-> intNestingLevel
	 *
	 * decrement kernel interrupt nesting counter
	 */

	LDR	lr, [r0]
	SUB	lr, lr, #1
	STR	lr, [r0]

	/*
	 * decrement and check our private interrupt nesting counter
	 * if nested, RTI
	 */

	LDR	lr, [r1]
	SUBS	lr, lr, #1
	STR	lr, [r1]
	BNE	intExit_RTI

	/*
	 * interrupts were not nested
	 *
	 * if kernelState, RTI
	 */

	LDR	r0, L$_kernelState	/* if kernelState == TRUE */
	LDR	lr, [r0]
	TEQS	lr, #0
	BNE	intExit_RTI		/* exit */

	/*
	 * not kernelState
	 *
	 * If the interrupt occurred during an interrupt entry sequence, we're
	 * nested so RTI.
	 * Similarly, if the interrupt occurred during an exception entry
	 * sequence, we can't easily save the context for a task switch so RTI.
	 * These cases are handled by simply testing the CPU mode.
	 */

	LDR	lr, [sp, #4*1]		/* get irq_sp */
	LDR	lr, [lr]		/* get irq_SPSR */
	AND	lr, lr, #MASK_SUBMODE	/* check mode bits */
	TEQS	lr, #MODE_SVC32 & MASK_SUBMODE /* SVC mode? */
	BNE	intExit_RTI		/* no, leave interrupt handling */

	/* if (current task == highest ready task), RTI */

	LDR	r0, L$_taskIdCurrent	/* get current task */
	LDR	r0, [r0]
	LDR	lr, L$_readyQHead	/* is it head of readyQ? */
	LDR	lr, [lr]
	TEQS	lr, r0
	BEQ	intExit_RTI		/* branch if yes */

	/*
	 * current task is NOT highest priority ready task
	 * check if allowed to preempt this task
	 * r0 -> TCB
	 * if (current task lock count != 0)
	 *    // task preemption not allowed
	 *    if (current task status == READY)
	 *        RTI
	 */

	LDR	lr, [r0, #WIND_TCB_LOCK_CNT]	/* task preemption allowed? */
	TEQS	lr, #0
	BEQ	saveIntContext			/* branch if yes */

	/* task preemption not allowed - is task ready? */

	LDR	lr, [r0, #WIND_TCB_STATUS]	/* check status */
	TEQS	lr, #WIND_READY
	BNE	saveIntContext			/* branch if not ready */

	/* current task cannot be preempted and is ready to run so resume it */

intExit_RTI:

	/*
	 * IRQs still disabled
	 * restore SVC-mode regs before changing back to IRQ mode
	 */

	LDMFD	sp!, {r1-r2,r12,lr}

	/*
	 * r1  = svc_sp (original)
	 * r2  = irq_sp
	 * r12 = svc_r12 (original)
	 * lr  = svc_lr (original)
	 *
	 * SVC-mode interruptStack now flattened
	 */

	MOV	sp, r1

	/* return to IRQ mode with IRQs disabled */

	MRS	r0, cpsr
	BIC	r0, r0, #MASK_MODE
	ORR	r0, r0, #MODE_IRQ32 | I_BIT
	MSR	cpsr, r0

	/*
	 * now in IRQ mode
	 * restore registers and return from interrupt
	 */

	LDMFD	sp!, {r0}		/* restore SPSR */
	MSR	spsr, r0
	LDMFD	sp!, {r0-r3,pc}^	/* restore regs and return from intr */

	/* NEVER FALL THROUGH */


saveIntContext:

	/*
	 * interrupt occurred during task code and the task is either
	 * blocked or preemption is allowed so we're going to reschedule
	 *
	 * IRQs still disabled
	 * r0 -> TCB
	 *
	 * set kernelState = TRUE
	 */

	MOV	lr, #1
	LDR	r1, L$_kernelState
	STR	lr, [r1]

	/* recover registers from SVC-mode interrupt stack */

	LDMFD	sp!, {r1-r2,r12,lr}

	/*
	 * r0 -> TCB
	 * r1  = svc_sp (original)
	 * r2  = irq_sp
	 * r12 = svc_r12 (original)
	 * lr  = svc_lr (original)
	 *
	 * SVC-mode interruptStack now flattened
	 */

	MOV	sp, r1			/* restore original svc_sp */

	/* store registers in the TCB of the current task */

	ADD	r1, r0, #WIND_TCB_R4	/* r1 -> regs.r[4] */
	STMIA	r1, {r4-r12,sp,lr}	/* store r4-r14 */

	LDMIA	r2, {r4-r9}			/* get task's CPSR,r0-r3,PC */
	STR	r4, [r0, #WIND_TCB_CPSR]	/* put CPSR in TCB */
	STMDB	r1, {r5-r8}			/* put r0-r3 in TCB */
	STR	r9, [r0, #WIND_TCB_PC]		/* put PC in TCB */

	/* save _fpStatus in TCB */

	LDR	lr, L$__fpStatus
	LDR	lr, [lr]
	STR	lr, [r0, #WIND_TCB_FPSTATUS]

	/* save errno in TCB */

	LDR	lr, L$_errno
	LDR	lr, [lr]
	STR	lr, [r0, #WIND_TCB_ERRNO]

	/* change to IRQ mode to flatten its stack */

	MRS	r1, cpsr			/* save mode and intr state */
	BIC	r3, r1, #MASK_MODE
	ORR	r3, r3, #MODE_IRQ32 | I_BIT	/* interrupts still disabled */
	MSR	cpsr, r3
	ADD	sp, sp, #4*6			/* flatten stack */

	/* now back to SVC mode with interrupts enabled */

	BIC	r1, r1, #I_BIT			/* enable interrupts */
	MSR	cpsr, r1

	/*
	 * INTERRUPTS ENABLED
	 *
	 * enter scheduler with r0 -> current task
	 * Note: reschedule runs on stack of interrupted task
	 */

	B	FUNC(reschedule)

/******************************************************************************/

#ifdef WV_INSTRUMENTATION

        /* windview instrumentation - BEGIN
         * log event if work has been done in the interrupt handler.
         */

instrumentIntExit:

	/*
	 * intExit instrumentation - branched to if currently instrumenting
	 *
	 * event type depends on whether there is anything in the work queue
	 */

	LDR	lr, L$_workQIsEmpty
	LDR	lr, [lr]
	TEQS	lr, #0			/* anything in work Q ? */
	MOVNE	r0, #EVENT_INT_EXIT	/* yes */
	MOVEQ	r0, #EVENT_INT_EXIT_K	/* no */

        LDR	lr, L$_wvEvtClass	/* is event logging on? */
	LDR	lr, [lr]
        AND	lr, lr, #WV_CLASS_1_ON
        TEQS	lr, #WV_CLASS_1_ON
	BNE	trgCheckIntExit		/* branch if not */

	/*
	 * write values to buffer
	 * r0 = event type
	 */

	LDR	r12, L$__func_evtLogT0	/* get address of fn pointer */
#if	(ARM_THUMB)
	LDR	r12, [r12]			/* get function address */
	BL	FUNC(arm_call_via_r12)		/* and call it */
#else
	MOV	lr, pc				/* call function */
	LDR	pc, [r12]
#endif	/* ARM_THUMB */

trgCheckIntExit:
        LDR	lr, L$_trgEvtClass		/* is triggering on? */
	LDR	lr, [lr]
        AND	lr, lr, #TRG_CLASS_1_ON
        TEQS	lr, #TRG_CLASS_1_ON
	BNE	resumeIntExit			/* branch if not */

	/* no need to save r0-r3 - comments above say they're trashable */

	/*
	 * There are 8 parameters to the trgCheck function:
	 * r0	 <- eventId
	 * r1 	 <- index = TRG_CLASS1_INDEX
	 * r2 	 <- obj (NULL)
	 * r3 	 <- arg1 (NULL - unused)
	 * stack <- arg2 (NULL - unused)
	 * stack <- arg3 (NULL - unused)
	 * stack <- arg4 (NULL - unused)
	 * stack <- arg5 (NULL - unused)
	 */

	MOV	r3, #0				/* NULL parms for stack */
	MOV	r2, #0
	MOV	r1, #0
	MOV	r0, #0

	STMFD	sp!, {r0-r3}			/* push stack-based parms */

	LDR	r1, L$_workQIsEmpty
	LDR	r1, [r1]
	TEQS	r1, #0				/* anything in work Q ? */
	MOVNE	r0, #EVENT_INT_EXIT		/* yes: r0 <- eventId */
	MOVEQ	r0, #EVENT_INT_EXIT_K		/* no : r0 <- eventId */

	MOV   	r1, #TRG_CLASS1_INDEX		/* r1 <- TRG_CLASS1_INDEX */
						/* r2 <- NULL (from above) */
						/* r3 <- NULL (from above) */

	LDR	r12,L$__func_trgCheck 		/* trigCheck routine */
#if	(ARM_THUMB)
	LDR	r12, [r12]			/* get function address */
	BL	FUNC(arm_call_via_r12)		/* and call it */
#else
	MOV	lr, pc				/* call function */
	LDR	pc, [r12]
#endif	/* ARM_THUMB */

	ADD	sp, sp, #16		/* strip 4 parameters from stack */

	B	resumeIntExit

        /* windview instrumentation - END */
#endif /* WV_INSTRUMENTATION */

