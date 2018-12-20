/* windALib.s - internal VxWorks kernel assembly library */

/* Copyright 1996-2002 Wind River Systems, Inc. */
/*
modification history
--------------------
01m,16jan02,to   add context switch for _fpStatus
01l,17oct01,t_m  convert to FUNC_LABEL:
01k,11oct01,jb   Enabling removal of pre-pended underscores for new compilers
                 (Diab/Gnu elf)
01j,13nov98,cdp  add big-endian support; make Thumb support dependent on
		 ARM_THUMB; optimise for no instrumentation.
01i,02sep98,cjtc port to windView 2.0
01h,31jul98,pr   temporarily commentig out WindView code
01g,24nov97,cdp  fix ARM7TDMI_T call to workQAdd1 (WindView instrumentation).
01f,28oct97,cdp  correct WindView instrumentation code, remove "EOF", tidy.
01e,09oct97,cdp  WindView fixes from Paola Rossaro (incorrect extern); tidy up.
01d,23sep97,cdp  removed kludges for old Thumb tool-chains.
01c,16apr97,cdp  added (Thumb) ARM7TDMI_T support;
		 added WindView support.
01b,05feb97,cdp  Fix return from windExit().
01a,09may96,cdp  written, based (loosely) on 68K version
*/

/*
DESCRIPTION
This module contains internals to the VxWorks kernel.
These routines have been coded in assembler because they are either
specific to this processor, or they have been optimized for performance.
*/

#define _ASMLANGUAGE
#include "vxWorks.h"
#include "private/taskLibP.h"
#include "private/workQLibP.h"
#include "private/eventP.h"

        .data
        .globl	FUNC(copyright_wind_river)
        .long	FUNC(copyright_wind_river)

	/* globals */

	.globl	VAR(_fpStatus)
	.globl	FUNC(windExit)		/* routine to exit mutual exclusion */
	.globl	FUNC(windIntStackSet)	/* interrupt stack set routine */

#ifdef	PORTABLE
	.globl	FUNC(windLoadContext)	/* needed by portable reschedule () */
#else
	.globl	FUNC(reschedule)		/* optimized reschedule () routine */
#endif	/* PORTABLE */


	/* externs */

	.extern	FUNC(workQIsEmpty)
	.extern	FUNC(workQDoWork)
	.extern	FUNC(kernelState)
	.extern	FUNC(intCnt)
	.extern	FUNC(taskIdCurrent)
	.extern	FUNC(readyQHead)
	.extern	FUNC(errno)

#ifdef	PORTABLE
	.extern	FUNC(reschedule)
#else
	.extern FUNC(kernelIsIdle)
	.extern	FUNC(taskSwapTable)
	.extern	FUNC(taskSwitchTable)
#endif	/* PORTABLE */

	.extern	FUNC(exit)

#ifdef	WV_INSTRUMENTATION
        .extern	FUNC(evtAction)
        .extern	FUNC(wvEvtClass)
        .extern	FUNC(trgEvtClass) 
        .extern	FUNC(_func_evtLogT0)
        .extern	FUNC(_func_evtLogTSched)
        .extern	FUNC(_func_trgCheck)
#endif	/* WV_INSTRUMENTATION */

#if	(ARM_THUMB)
	.extern	FUNC(arm_call_via_r2)
	.extern	FUNC(arm_call_via_r12)
#endif	/* (ARM_THUMB) */

	/* variables */

	.data
	.balign	4
VAR_LABEL(_fpStatus)
	.long	0

	.text
	.balign	4
	.code	32

/* PC-relative-addressable pointers - LDR Rn,=sym is broken */

L$__fpStatus:
	.long	VAR(_fpStatus)
L$_workQIsEmpty:
	.long	FUNC(workQIsEmpty)
L$_kernelState:
	.long	FUNC(kernelState)	
L$_intCnt:
	.long	FUNC(intCnt)
L$_taskIdCurrent:
	.long	FUNC(taskIdCurrent)
L$_readyQHead:
	.long	FUNC(readyQHead)
L$_errno:
	.long	FUNC(errno)

#if	(ARM_THUMB)
L$_workQDoWork:
	.long	FUNC(workQDoWork)
#endif	/* (ARM_THUMB) */

#ifdef	WV_INSTRUMENTATION 
L$_evtAction:
	.long	FUNC(evtAction)
L$_wvEvtClass:
	.long	FUNC(wvEvtClass) 
L$_trgEvtClass:
	.long	FUNC(trgEvtClass) 
L$__func_evtLogT0:
	.long	FUNC(_func_evtLogT0) 
L$__func_evtLogTSched:
	.long	FUNC(_func_evtLogTSched)
L$__func_trgCheck:
	.long	FUNC(_func_trgCheck)
#endif	/* WV_INSTRUMENTATION */

#ifndef	PORTABLE
L$_kernelIsIdle:
	.long	FUNC(kernelIsIdle)
L$_taskSwapTable:
	.long	FUNC(taskSwapTable)
L$_taskSwitchTable:
	.long	FUNC(taskSwitchTable)
#endif	/* !PORTABLE */

/*******************************************************************************
*
* windExitInt - exit kernel routine from interrupt level
*
* windExit branches here if exiting kernel routine from int level
* No rescheduling is necessary because the ISR will exit via intExit, and
* intExit does the necessary rescheduling.  Before leaving kernel state
* the work queue is emptied.
*
* REGISTERS
*    Exit: r0 = 0
*/

windExitInt:

	/* save interrupt state and link */

	STMFD	sp!, {r4,lr}		/* save v1 and link */
	MRS	r4, cpsr

windExitIntLoop:

	/*
	 * disable interrupts
	 * r4 = CPSR
	 */

	ORR	r0, r4, #I_BIT
	MSR	cpsr, r0

	/*
	 * INTERRUPTS DISABLED
	 *
	 * see if workQ is empty
	 */

	LDR	r0, L$_workQIsEmpty
	LDR	r0, [r0]
	TEQS	r0, #0
	BNE	windExitIntNoWork	/* branch if empty */

	/*
	 * work to do
	 * restore interrupt state
	 * r4 = previous CPSR
	 */

	MSR	cpsr, r4

	/*
	 * INTERRUPTS ENABLED
	 *
	 * call a C routine to empty the workQ
	 */

#if	(ARM_THUMB)
	LDR	r12, L$_workQDoWork	/* empty workQ (r4 preserved) */
	BL	FUNC(arm_call_via_r12)	/* returns in ARM state */
#else
	BL	FUNC(workQDoWork)		/* empty workQ (r4 preserved) */
#endif	/* (ARM_THUMB) */

	B	windExitIntLoop

	/* NEVER FALL THROUGH */


windExitIntNoWork:

	/* workQ is empty */

#ifdef	WV_INSTRUMENTATION

	/* windview instrumentation - BEGIN
	 * exit windExit with no dispatch; point 1 in the windExit diagram.
	 */

	LDR	lr, L$_evtAction	/* is event logging or triggering? */
	LDR	lr, [lr]
	TEQS	lr, #0
	BNE	instrumentDispatch1	/* branch if so */

	/* instrumentation currently disabled */

resumeDispatch1:

	/* windview instrumentation - END */
#endif	/* WV_INSTRUMENTATION */


	/* exit kernelState */

	LDR	lr, L$_kernelState
	MOV	r0, #0
	STR	r0, [lr]

	/*
	 * restore interrupt state and return OK
	 * r0 = 0
	 */

	MSR	cpsr, r4

	/* INTERRUPTS ENABLED */

#if	(ARM_THUMB)
	LDMFD	sp!, {r4,lr}
	BX	lr
#else
	LDMFD	sp!, {r4,pc}
#endif	/* (ARM_THUMB) */

/******************************************************************************/

#ifdef	WV_INSTRUMENTATION

	/* windview instrumentation - BEGIN
	 * exit windExit with no dispatch; point 1 in the windExit diagram.
	 */

instrumentDispatch1:

        LDR	lr, L$_wvEvtClass		/* is instrumentation on? */
	LDR	lr, [lr]
        AND	lr, lr, #WV_CLASS_1_ON	
        TEQS	lr, #WV_CLASS_1_ON	
	BNE	trgInst1			/* branch if not */

	/* 
	 * try to determine if the task is running at an inherited priority
	 * and log a different event if so
	 */

	LDR	r12, L$_taskIdCurrent
	LDR	r12, [r12]			/* r12 -> TCB */
	LDR	r1, [r12, #WIND_TCB_PRIORITY]
	LDR	r2, [r12, #WIND_TCB_PRI_NORMAL]
	CMPS	r2, r1
	MOVHI	r0, #EVENT_WIND_EXIT_NODISPATCH_PI
	MOVLS	r0, #EVENT_WIND_EXIT_NODISPATCH

	LDR	r12, L$__func_evtLogTSched	/* get address of fn pointer */

#if	(ARM_THUMB)
	LDR	r12, [r12]			/* get function address */
	BL	FUNC(arm_call_via_r12)		/* and call it */
#else
	MOV	lr, pc				/* call function */
	LDR	pc, [r12]
#endif	/* (ARM_THUMB) */

trgInst1: 
        LDR	lr, L$_trgEvtClass		/* is triggering on? */
	LDR	lr, [lr]
        AND	lr, lr,#TRG_CLASS_1_ON	
        TEQS	lr, #TRG_CLASS_1_ON	
	BNE	resumeDispatch1			/* branch if not */

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

	/* 
	 * try to determine if the task is running at an inherited priority
	 * and log a different event if so
	 */

	LDR	r12, L$_taskIdCurrent
	LDR	r12, [r12]			/* r12 -> TCB */
	LDR	r0, [r12, #WIND_TCB_PRIORITY]
	LDR	r1, [r12, #WIND_TCB_PRI_NORMAL]
	CMPS	r1, r0
	MOVHI	r0, #EVENT_WIND_EXIT_NODISPATCH_PI 
	MOVLS	r0, #EVENT_WIND_EXIT_NODISPATCH	/* r0 <- eventId */

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
#endif	/* (ARM_THUMB) */

	ADD	sp, sp, #16		/* strip 4 parameters from stack */

	B	resumeDispatch1

	/* windview instrumentation - END */
#endif	/* WV_INSTRUMENTATION */

/*******************************************************************************
*
* checkTaskReady - check that taskIdCurrent is ready to run
*
* This code branched to by windExit when it finds preemption is disabled.
* It is possible that even though preemption is disabled, a context switch
* must occur.  This situation arises when a task blocks during a preemption
* lock.  So this routine checks if taskIdCurrent is ready to run, if not it
* branches to save the context of taskIdCurrent, otherwise it falls thru to
* check the work queue for any pending work.
*
* REGISTERS
*    r0 -> TCB
*/

checkTaskReady:
	LDR	r1, [r0, #WIND_TCB_STATUS]	/* is task ready to run? */
	TEQS	r1, #WIND_READY
	BNE	saveTaskContext			/* if no, go and reschedule */

	/*
	 * task is ready to run
	 *
	 * FALL THROUGH TO checkWorkQ
	 */

/*******************************************************************************
*
* checkWorkQ -  check the work queue for any work to do
*
* This code is branched to by windExit.  Currently taskIdCurrent is highest
* priority ready task, but before we can return to it we must check the work
* queue.  If there is work we empty it via doWorkPreSave, otherwise we unlock
* interrupts, clear r0, and return to taskIdCurrent.
*
* REGISTERS
*    r0 scratch
*    lr = link
*/

checkWorkQ:

	/* disable interrupts */

	MRS	r0, cpsr
	ORR	r0, r0, #I_BIT
	MSR	cpsr, r0

	/* INTERRUPTS DISABLED */

	LDR	r0, L$_workQIsEmpty
	LDR	r0, [r0]
	TEQS	r0, #0			/* empty? */
	BEQ	doWorkPreSave		/* branch if not */

	/* workQ is empty */

#ifdef	WV_INSTRUMENTATION

	/* windview instrumentation - BEGIN
	 * exit windExit with no dispatch; point 4 in the windExit diagram.
	 */

	LDR	r0, L$_evtAction	/* is event logging or triggering? */
	LDR	r0, [r0]
	TEQS	r0, #0
	BNE	instrumentDispatch4	/* branch if so */

	/* instrumentation currently disabled */

resumeDispatch4:

	/* windview instrumentation - END */
#endif	/* WV_INSTRUMENTATION */


	/* release exclusion */

	STMFD	sp!, {lr}
	LDR	lr, L$_kernelState
	MOV	r0, #0
	STR	r0, [lr]

	/* enable interrupts */

	MRS	r0, cpsr
	BIC	r0, r0, #I_BIT
	MSR	cpsr, r0

	/*
	 * INTERRUPTS ENABLED
	 *
	 * return OK
	 */
	
	MOV	r0, #0
#if	(ARM_THUMB)
	LDMFD	sp!, {lr}
	BX	lr
#else
	LDMFD	sp!, {pc}
#endif	/* (ARM_THUMB) */

/******************************************************************************/

#ifdef	WV_INSTRUMENTATION

	/* windview instrumentation - BEGIN
	 * exit windExit with no dispatch; point 4 in the windExit diagram.
	 */

instrumentDispatch4:

	STMFD	sp!, {lr}		/* save link */

        LDR	lr, L$_wvEvtClass		/* is instrumentation on? */
	LDR	lr, [lr]
        AND	lr, lr, #WV_CLASS_1_ON	
        TEQS	lr, #WV_CLASS_1_ON	
	BNE	trgInst4			/* branch if not */

	/* 
	 * try to determine if the task is running at an inherited priority
	 * and log a different event if so
	 */

	LDR	r12, L$_taskIdCurrent
	LDR	r12, [r12]			/* r12 -> TCB */
	LDR	r1, [r12, #WIND_TCB_PRIORITY]
	LDR	r2, [r12, #WIND_TCB_PRI_NORMAL]
	CMPS	r2, r1
	MOVHI	r0, #EVENT_WIND_EXIT_NODISPATCH_PI
	MOVLS	r0, #EVENT_WIND_EXIT_NODISPATCH

	LDR	r12, L$__func_evtLogTSched	/* get address of fn pointer */

#if	(ARM_THUMB)
	LDR	r12, [r12]			/* get function address */
	BL	FUNC(arm_call_via_r12)		/* and call it */
#else
	MOV	lr, pc				/* call function */
	LDR	pc, [r12]
#endif	/* (ARM_THUMB) */

trgInst4: 
        LDR	lr, L$_trgEvtClass	/* is instrumentation on? */
	LDR	lr, [lr]
        AND	lr, lr, #TRG_CLASS_1_ON	
        TEQS	lr, #TRG_CLASS_1_ON	
	BNE	instTidy4		/* branch if not */

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

	/* 
	 * try to determine if the task is running at an inherited priority
	 * and log a different event if so
	 */

	LDR	r12, L$_taskIdCurrent
	LDR	r12, [r12]			/* r12 -> TCB */
	LDR	r0, [r12, #WIND_TCB_PRIORITY]
	LDR	r1, [r12, #WIND_TCB_PRI_NORMAL]
	CMPS	r1, r0
	MOVHI	r0, #EVENT_WIND_EXIT_NODISPATCH_PI 
	MOVLS	r0, #EVENT_WIND_EXIT_NODISPATCH	/* r0 <- eventId */
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
#endif	/* (ARM_THUMB) */

	ADD	sp, sp, #16		/* strip 4 parameters from stack */

instTidy4:
	LDMFD	sp!, {lr}		/* restore link */

	B	resumeDispatch4

	/* windview instrumentation - END */
#endif	/* WV_INSTRUMENTATION */

/*******************************************************************************
*
* doWorkPreSave - empty the work queue with current context not saved
*
* We try to empty the work queue here, rather than let reschedule
* perform the work because there is a strong chance that the
* work we do will not preempt the calling task.  If this is the case, then
* saving the entire context just to restore it in reschedule is a waste of
* time.  Once the work has been emptied, the ready queue must be checked to
* see if reschedule must be called; the check of the ready queue is done by
* branching to checkTaskSwitch.
*/

doWorkPreSave:

	/* enable interrupts */

	MRS	r0, cpsr
	BIC	r0, r0, #I_BIT
	MSR	cpsr, r0

	/* INTERRUPTS ENABLED */

	STMFD	sp!, {lr}

#if	(ARM_THUMB)
	LDR	r12, L$_workQDoWork	/* empty the work queue */
	BL	FUNC(arm_call_via_r12)	/* returns in ARM state */
#else
	BL	FUNC(workQDoWork)		/* empty the work queue */
#endif	/* (ARM_THUMB) */

	LDMFD	sp!, {lr}
	B	checkTaskSwitch		/* go and test if tasks switched */

/******************************************************************************
*
* windExit - task level exit from kernel
*
* Release kernel mutual exclusion (kernelState) and dispatch any new task if
* necessary.  If a higher priority task than the current task has been made
* ready, then we invoke the rescheduler.  Before releasing mutual exclusion,
* the work queue is checked and emptied if necessary.
*
* If rescheduling is necessary, the context of the calling task is saved in its
* associated TCB with the PC pointing at the next instruction after the BL to
* this routine. Thus the context saved is as if this routine was never called.
*
* Only the volatile registers r0-r3 are safe to use until the context
* is saved in saveTaskContext.
*
* At the call to reschedule the value of taskIdCurrent must be in r0.
*
* RETURNS: OK or
*          ERROR if semaphore timeout occurs.
*
* NOMANUAL

* STATUS windExit ()

*/

_ARM_FUNCTION_CALLED_FROM_C(windExit)

	/* if (intCnt != 0), exiting interrupt code */

	LDR	r0, L$_intCnt
	LDR	r0, [r0]
	TEQS	r0, #0
	BNE	windExitInt

	/*
	 * exiting task level code
	 *
	 * FALL THROUGH TO checkTaskSwitch
	 */

/*******************************************************************************
*
* checkTaskSwitch - check to see if taskIdCurrent is still highest task
*
* We arrive at this code either as the result of falling thru from
* windExit, or if we have finished emptying the work queue. We compare
* taskIdCurrent with the highest ready task on the ready queue. If they
* are same we go to a routine to check the work queue. If they are
* different and preemption is NOT [original comment incorrect] allowed
* we branch to a routine to make sure that taskIdCurrent is really ready
* (it may have blocked with preemption disabled). Otherwise we save the
* context of taskIdCurrent and fall thru to reschedule.
*
* REGISTERS
*   Entry: lr = task link
*   Uses r0, r1
*/

checkTaskSwitch:

	/* check if current task is highest ready task */

	LDR	r0, L$_taskIdCurrent
	LDR	r0, [r0]
	LDR	r1, L$_readyQHead
	LDR	r1, [r1]
	TEQS	r0, r1
	BEQ	checkWorkQ		/* branch if it is */

	/*
	 * current task is NOT highest ready task
	 * check if we can preempt it
	 * r0 -> TCB
	 */

	LDR	r1, [r0, #WIND_TCB_LOCK_CNT]
	TEQS	r1, #0			/* can preempt? */
	BNE	checkTaskReady		/* branch if not */

	/* we CAN preempt this task */

saveTaskContext:

	/*
	 * Save return address as PC so that when this task is resumed,
	 * it resumes at the exit from its windExit() call.
	 * NOTE: unlike on 68K and i86, no adjustment of task SP is necessary
	 */

	STR	lr, [r0, #WIND_TCB_PC]

	/* store a brand new PSR */

#if	(ARM_THUMB)
	MOV	r1, #MODE_SVC32 | T_BIT		/* interrupts enabled, Thumb */
#else
	MOV	r1, #MODE_SVC32			/* interrupts enabled */
#endif	/* (ARM_THUMB) */

	STR	r1, [r0, #WIND_TCB_CPSR]

	/* set r0 in TCB to return OK */

	MOV	r1, #0
	STR	r1, [r0, #WIND_TCB_R0]

	/*
	 * save registers: no need to save r0-r3 as they are volatile
	 * i.e. caller of windExit() does not expect them to be
	 * preserved (APCS)
	 */

	ADD	r1, r0, #WIND_TCB_R4
	STMIA	r1, {r4-r12,sp}

	/* save _fpStatus in TCB */

	LDR	r1, L$__fpStatus
	LDR	r1, [r1]
	STR	r1, [r0, #WIND_TCB_FPSTATUS]

	/* save errno in TCB */

	LDR	r1, L$_errno
	LDR	r1, [r1]
	STR	r1, [r0, #WIND_TCB_ERRNO]

#ifndef	PORTABLE

	/* FALL THROUGH to reschedule */

/*******************************************************************************
*
* reschedule - fast rescheduler for VxWorks kernel
*
* This routine is called when either intExit, or windExit, thinks the
* context might change.  All of the contexts of all of the tasks have been
* accurately stored in the task control blocks when entering this function.
* The status register is set to SVC32 mode with interrupts enabled.
*
* The register r0 must contain the value of FUNC(taskIdCurrent) at the entrance to
* this routine.
*
* At the conclusion of this routine, taskIdCurrent will equal the highest
* priority task eligible to run, and the kernel work queue will be empty.
* If a context switch to a different task is to occur, then the installed
* switch hooks are called.
*
* NOMANUAL

* void reschedule ()

* INTERNAL
* This routine can use whatever registers it likes since it does not
* return to its caller but enters a new task, loading all its registers
* to do so.
*
* The following non-volatile registers are used:
*    r4 -> TCB of current task
*    r5 -> TCB of task at top of readyQ ('highest task')
*    r6 = swap mask
*    r8 -> taskIdCurrent i.e. the pointer to the TCB pointer
*/

_ARM_FUNCTION(reschedule)

	MOV	r4, r0				/* r4 -> current task */
	LDR	r8, L$_taskIdCurrent		/* keep r8 -> taskIdCurrent */
	LDR	r5, L$_readyQHead
	LDR	r5, [r5]			/* r5 -> highest task */
	TEQS	r5, #0				/* readyQ empty? */
	BEQ	idle				/* branch if so */

switchTasks:

	/*
	 * r4 -> current task
	 * r5 -> highest task
	 * update taskIdCurrent so that it points to the highest task
	 */

	STR	r5, [r8]			/* taskIdCurrent -> highest */

	/* swap current/highest pointers */

	MOV	r2, r5				/* r2 -> highest task */
	MOV	r5, r4				/* r5 -> previous task */
	MOV	r4, r2				/* r4 -> highest task */

	/*
	 * check the swap masks (16 bit fields)
	 * r4 -> highest task
	 * r5 -> previous task
	 */

#if	((WIND_TCB_SWAP_IN & 3) == 0) && ((WIND_TCB_SWAP_OUT & 3) == 2)
	LDR	r3, [r4, #WIND_TCB_SWAP_IN]	/* get swap masks */
	LDR	r2, [r5, #WIND_TCB_SWAP_OUT & ~3]
#if (_BYTE_ORDER == _BIG_ENDIAN)
	ORR	r3, r2, r3, LSR #16		/* b0..15 = OR of masks */
#else
	ORR	r3, r3, r2, LSR #16		/* b0..15 = OR of masks */
#endif /* (_BYTE_ORDER == _BIG_ENDIAN) */
	MOVS	r6, r3, LSL #16			/* r6[31..16] = OR of masks */
	BNE	doSwapHooks			/* branch if swap hooks to do */
#else
#	error	WIND_TCB_SWAP_IN/OUT alignment incorrect for code
#endif	/* WIND_TCB_SWAP_IN */

	/* check for global hooks */

	LDR	r7, L$_taskSwitchTable		/* any global hooks? */
	LDR	r2, [r7], #4
	TEQS	r2, #0
	BNE	doSwitchHooks			/* branch if so */

dispatch:

	/*
	 * despatch the new task
	 * r4 -> TCB
	 * NOTE: MIPS code reloads from taskIdCurrent here but MC68K does
	 * not - it should not be necessary
	 *
	 * first restore _fpStatus from TCB
	 */

	LDR	r1, [r4, #WIND_TCB_FPSTATUS]
	LDR	r2, L$__fpStatus
	STR	r1, [r2]

	/* restore errno from TCB */

	LDR	r1, [r4, #WIND_TCB_ERRNO]
	LDR	r2, L$_errno
	STR	r1, [r2]

	/* lock interrupts */

	MRS	r0, cpsr
	ORR	r0, r0, #I_BIT
	MSR	cpsr, r0

	/*
	 * INTERRUPTS DISABLED
	 *
	 * see if workQ is empty
	 */

	LDR	r2, L$_workQIsEmpty
	LDR	r2, [r2]
	TEQS	r2, #0			/* queue empty? */
	BEQ	doWorkUnlock		/* branch if not */

	/* nothing in workQ so continue despatch */

#ifdef	WV_INSTRUMENTATION
 
	/* windview instrumentation - BEGIN
	 * exit windExit with dispatch
	 */

	LDR	lr, L$_evtAction	/* is instrumentation on? */
	LDR	lr, [lr]
	TEQS	lr, #0
	BNE	instrumentDispatch3	/* branch if so */

	/* instrumentation currently disabled */

resumeDispatch3:

	/* windview instrumentation - END */
#endif	/* WV_INSTRUMENTATION */

	LDR	r2, L$_kernelState		/* exit kernel state */
	MOV	r0, #0
	STR	r0, [r2]

	/* get task's saved status and put it in svc_spsr */

	LDR	r1, [r4, #WIND_TCB_CPSR]	/* get status */
	MSR	spsr, r1			/* and put it in place */

	/* load all regs and reenter task */

	ADD	r4, r4, #WIND_TCB_REGS		/* r4 -> task regs */
	LDMIA	r4, {r0-r12,sp,lr,pc}^

/******************************************************************************/

#ifdef	WV_INSTRUMENTATION

	/* windview instrumentation - BEGIN
	 * exit windExit with dispatch
	 */

instrumentDispatch3:

        LDR	lr, L$_wvEvtClass		/* is instrumentation on? */
	LDR	lr, [lr]
        AND	lr, lr, #WV_CLASS_1_ON	
        TEQS	lr, #WV_CLASS_1_ON	
	BNE	trgInst3			/* branch if not */

	/* 
	 * try to determine if the task is running at an inherited priority
	 * and log a different event if so
	*
 	 * register usage :
	 *	r0 : eventId
	 *	r1 : taskId
	 *	r2 : task priority
	 *	r3 : scratch (for task priority normal)
	 *
	 * These have been used to be in the right place for the call to the
	 * logging routine
	 */

	LDR	r1, L$_taskIdCurrent
	LDR	r1, [r1]			/* r1 = taskId */
	LDR	r2, [r1, #WIND_TCB_PRIORITY]	/* r2 = task priority */
	LDR	r3, [r1, #WIND_TCB_PRI_NORMAL]
	CMPS	r3, r2
	MOVHI	r0, #EVENT_WIND_EXIT_DISPATCH_PI /* r0 = eventId */
	MOVLS	r0, #EVENT_WIND_EXIT_DISPATCH

	LDR	r12, L$__func_evtLogTSched	/* get address of fn pointer */

#if	(ARM_THUMB)
	LDR	r12, [r12]			/* get function address */
	BL	FUNC(arm_call_via_r12)		/* and call it */
#else
	MOV	lr, pc				/* call function */
	LDR	pc, [r12]
#endif	/* (ARM_THUMB) */

trgInst3: 

        LDR	lr, L$_trgEvtClass	/* is instrumentation on? */
	LDR	lr, [lr]
        AND	lr, lr, #TRG_CLASS_1_ON	
        TEQS	lr, #TRG_CLASS_1_ON	
	BNE	resumeDispatch3		/* branch if not */

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

	/* 
	 * try to determine if the task is running at an inherited priority
	 * and log a different event if so
	 */

	LDR	r12, L$_taskIdCurrent
	LDR	r12, [r12]			/* r12 -> TCB */
	LDR	r0, [r12, #WIND_TCB_PRIORITY]
	LDR	r1, [r12, #WIND_TCB_PRI_NORMAL]
	CMPS	r1, r0
	MOVHI	r0, #EVENT_WIND_EXIT_DISPATCH_PI 
	MOVLS	r0, #EVENT_WIND_EXIT_DISPATCH	/* r0 <- eventId */
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
#endif	/* (ARM_THUMB) */

	ADD	sp, sp, #16		/* strip 4 parameters from stack */

	B	resumeDispatch3

	/* windview instrumentation - END */
#endif	/* WV_INSTRUMENTATION */

/*******************************************************************************
*
* idle - spin here until there is more work to do
*
* When the kernel is idle, we spin here continually checking for work to do.
*/

idle:

#ifdef	WV_INSTRUMENTATION
 
	/* windview instrumentation - BEGIN
	 * enter idle state
	 */

	LDR	lr, L$_evtAction	/* is instrumentation on? */
	LDR	lr, [lr]
	TEQS	lr, #0
	BNE	instrumentIdle		/* branch if so */

	/* instrumentation currently disabled */

resumeIdle:

	/* windview instrumentation - END */
#endif	/* WV_INSTRUMENTATION */


	/* unlock interrupts */

	MRS	r0, cpsr
	BIC	r0, r0, #I_BIT
	MSR	cpsr, r0

	/* set idle flag for spyLib */

	LDR	r1, L$_kernelIsIdle
	MOV	r0, #1
	STR	r0, [r1]

	/* now idle until there's something in the work queue */

	LDR	r2, L$_workQIsEmpty

idleLoop:
	/*
	 * r1 -> kernelIsIdle
	 * r2 -> workQIsEmpty
	 */

	LDR	r0, [r2]
	TEQS	r0, #0			/* work queue still empty? */
	BNE	idleLoop		/* loop if so */

	/*
	 * there is now something in the work queue
	 * unset the idle flag and go do the work
	 */

	MOV	r0, #0
	STR	r0, [r1]
	B	doWork

/******************************************************************************/

#ifdef	WV_INSTRUMENTATION

	/* windview instrumentation - BEGIN
	 * enter idle state
	 */

instrumentIdle:

	/* lock interrupts */

	MRS	r0, cpsr
	ORR	r0, r0, #I_BIT
	MSR	cpsr, r0

	/*
	 * INTERRUPTS DISABLED
	 */

	/* Check if we need to log this event */

	LDR	lr, L$_wvEvtClass		/* load event class */
	LDR	lr, [lr]
	AND	lr, lr, #WV_CLASS_1_ON  	/* examine to see if action */
	TEQS	lr, #WV_CLASS_1_ON
	BNE	idleCheckTrg			/* jump if no action */

	MOV	r0, #EVENT_WIND_EXIT_IDLE	/* param to log function */
	LDR	r12, L$__func_evtLogT0		/* get address of fn pointer */

#if	(ARM_THUMB)
	LDR	r12, [r12]			/* get function address */
	BL	FUNC(arm_call_via_r12)		/* and call it */
#else
	MOV	lr, pc				/* call function */
	LDR	pc, [r12]
#endif	/* (ARM_THUMB) */

idleCheckTrg:

        LDR	lr, L$_trgEvtClass	/* is instrumentation on? */
	LDR	lr, [lr]
        AND	lr, lr, #TRG_CLASS_1_ON	
        TEQS	lr, #TRG_CLASS_1_ON	
	BNE	resumeIdle		/* branch if not */

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

	MOV	r0, #EVENT_WIND_EXIT_IDLE	/* r0 <- eventId */
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
#endif	/* (ARM_THUMB) */

	ADD	sp, sp, #16		/* strip 4 parameters from stack */

	B	resumeIdle

	/* windview instrumentation - END */
#endif	/* WV_INSTRUMENTATION */

/*******************************************************************************
*
* doSwapHooks - execute the tasks' swap hooks
*/

doSwapHooks:

	/*
	 * r4 -> new TCB
	 * r5 -> old TCB
	 * r6[31..16] = OR of swap-in and swap-out masks
	 *
	 * before entering loop, make sure that all values we care about
	 * have been moved out of r0-r3 as the called routine is at liberty
	 * to corrupt these
	 */

	LDR	r7, L$_taskSwapTable	/* get adrs of task switch rtn list */

doSwapHooksLoop:
	MOVS	r6, r6, LSL #1		/* check MS bit */
	MOVCS	r0, r5			/* if set, set args to old, new */
	MOVCS	r1, r4

#if	(ARM_THUMB)
	LDRCS	r2, [r7]
	BLCS	FUNC(arm_call_via_r2)	/* returns in ARM state */
#else
	MOVCS	lr, pc			/* ..and call routine */
	LDRCS	pc, [r7]
#endif	/* (ARM_THUMB) */

	TEQS	r6, #0			/* all done? */
	ADDNE	r7, r7, #4		/* if not, bump routine pointer */
	BNE	doSwapHooksLoop		/* ..and go again */

	/*
	 * have now processed all bits set in the swap mask
	 * NOTE: MC68K code reloads from taskIdCurrent here but MIPS code does
	 * not - it should not be necessary
	 */

	LDR	r7, L$_taskSwitchTable	/* any global switch hooks? */
	LDR	r2, [r7], #4		/* get task switch routine */
	TEQS	r2, #0			/* present? */
	BEQ	dispatch		/* branch if not */

	/* FALL THROUGH to doSwitchHooks */

/*******************************************************************************
*
* doSwitchHooks - execute the global switch hooks
*
* r2 -> first routine in taskSwitchTable (!= 0)
* r4 -> new current task
* r5 -> previous task
* r7 -> taskSwitchTable+4
*/


doSwitchHooks:
	MOV	r0, r5			/* set args to old, new */
	MOV	r1, r4

#if	(ARM_THUMB)
	BL	FUNC(arm_call_via_r2)	/* returns in ARM state */
#else
	MOV	lr, pc			/* ..and call routine */
	MOV	pc, r2
#endif	/* (ARM_THUMB) */

	LDR	r2, [r7], #4		/* get next routine */
	TEQS	r2, #0			/* end of table? */
	BNE	doSwitchHooks		/* branch if not */

	/*
	 * NOTE: MC68K code reloads from taskIdCurrent here but MIPS code does
	 * not - it should not be necessary
	 */

	B	dispatch

/*******************************************************************************
*
* doWork - empty the work queue
* doWorkUnlock - unlock interrupts and empty the work queue
*/

doWorkUnlock:

	/* unlock interrupts */

	MRS	r0, cpsr
	BIC	r0, r0, #I_BIT
	MSR	cpsr, r0
doWork:

#if	(ARM_THUMB)
	LDR	r12, L$_workQDoWork	/* empty the work queue */
	BL	FUNC(arm_call_via_r12)	/* returns in ARM state */
#else
	BL	FUNC(workQDoWork)		/* empty the work queue */
#endif	/* (ARM_THUMB) */

	LDR	r4, [r8]		/* r4 -> TCB of new current task */
	LDR	r5, L$_readyQHead
	LDR	r5, [r5]		/* r5 -> TCB highest task */
	TEQS	r5, #0			/* anyone ready? */
	BEQ	idle			/* branch if not */

	TEQS	r4, r5			/* current == highest? */
	BEQ	dispatch		/* if so, despatch */
	B	switchTasks		/* if not, do switch */

#else	/* PORTABLE */

	/*
	 * PORTABLE code - branch to portable reschedule
	 * 68k and i86 architectures have a BL to reschedule here rather
	 * than a branch - this makes no sense since reschedule does not
	 * return (it calls windLoadContext).
	 */

	B	FUNC(reschedule)

/*******************************************************************************
*
* windLoadContext - load the register context from the control block
*
* The errno and PSR of the task to be entered, (the one reschedule chose),
* are loaded from its control block. Its registers are then reloaded and
* it is entered using a LDM instruction.
*
* NOMANUAL

* void windLoadContext ()

*/

_ARM_FUNCTION_CALLED_FROM_C(windLoadContext)

	LDR	r0, L$_taskIdCurrent
	LDR	r0, [r0]			/* r0 -> TCB */

	/* restore _fpStatus from TCB */

	LDR	r1, [r0, #WIND_TCB_FPSTATUS]
	LDR	r2, L$__fpStatus
	STR	r1, [r2]

	/* restore errno from TCB */

	LDR	r1, [r0, #WIND_TCB_ERRNO]
	LDR	r2, L$_errno
	STR	r1, [r2]

	/* get task's saved status and put it in svc_spsr */

	LDR	r1, [r0, #WIND_TCB_CPSR]	/* get status */
	MSR	spsr, r1			/* and put it in place */

	/* load all regs and reenter task */

	ADD	r0, r0, #WIND_TCB_REGS		/* r0 -> task regs */
	LDMIA	r0, {r0-r12,sp,lr,pc}^

#endif	/* !PORTABLE */

/*******************************************************************************
*
* windIntStackSet - set the interrupt stack pointer
*
* This routine sets the interrupt stack pointer to the specified address.
* On the ARM, this is a null routine because the real work is done
* by sysIntStackSplit in the BSP.
*
* NOMANUAL

* void windIntStackSet
*     (
*     char *pBotStack   /@ pointer to bottom of interrupt stack @/
*     )

*/

#if	(ARM_THUMB)

_THUMB_FUNCTION(windIntStackSet)
	BX	lr

#else

_ARM_FUNCTION(windIntStackSet)
	MOV	pc, lr

#endif	/* (ARM_THUMB) */
