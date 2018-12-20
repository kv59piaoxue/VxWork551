/* semMALib.s - VxWorks mutual-exclusion semaphore assembler library */

/* Copyright 1996-2001 Wind River Systems, Inc. */


/*
modification history
--------------------
01k,29may02,m_h  recurse problems from MSRNE (78125)
01j,20may02,m_h  reenable interrupts on error and recurse (77430)
01i,12mar02,m_h  semTake must return error if called from ISR (74202)
01h,30oct01,pcm  added VxWorks semaphore events
01g,17oct01,t_m  convert to FUNC_LABEL:
01f,11oct01,jb  Enabling removal of pre-pended underscores for new compilers
                 (Diab/Gnu elf)
01e,22jun98,cdp  added big-endian support.
01d,17feb98,cdp  rewritten with intrumentation work.
01c,27oct97,kkk  took out "***EOF***" line from end of file.
01b,27may97,jpd  Amalgamated into VxWorks.
01a,15jul96,ams  Written.
*/

/*
DESCRIPTION
This library provides the interface to VxWorks mutual-exclusion
semaphores.  Mutual-exclusion semaphores offer convenient options
suited for situations requiring mutually exclusive access to resources.
Typical applications include sharing devices and protecting data
structures.  Mutual-exclusion semaphores are used by many higher-level
VxWorks facilities.

The mutual-exclusion semaphore is a specialized version of the binary
semaphore, designed to address issues inherent in mutual exclusion, such
as recursive access to resources, priority inversion, and deletion safety.
The fundamental behavior of the mutual-exclusion semaphore is identical
to the binary semaphore (see the manual entry for semBLib), except for
the following restrictions:

    - It can only be used for mutual exclusion.
    - It can only be given by the task that took it.
    - It may not be taken or given from interrupt level.
    - The semFlush() operation is illegal.

These last two operations have no meaning in mutual-exclusion situations.
*/

#define _ASMLANGUAGE
#include "vxWorks.h"
#include "semLib.h"
#include "private/semLibP.h"
#include "private/sigLibP.h"
#include "private/taskLibP.h"

	.data
	.globl	FUNC(copyright_wind_river)
	.long	FUNC(copyright_wind_river)

#if (defined(PORTABLE))
#define semMALib_PORTABLE
#endif

#ifndef semMALib_PORTABLE


/* globals */

	.global	FUNC(semMGive)		/* give a mutual exclusion semaphore */
	.global	FUNC(semMTake)		/* take a mutual exclusion semaphore */

/* externals */

	.extern	FUNC(_func_sigTimeoutRecalc)
	.extern	FUNC(intCnt)
	.extern	FUNC(kernelState)
	.extern FUNC(semClass)
	.extern	FUNC(semIntRestrict)
	.extern	FUNC(semInvalid)
	.extern	FUNC(semMGiveKern)
	.extern	FUNC(semMGiveKernWork)
	.extern	FUNC(semMPendQPut)
	.extern	FUNC(semTake)
	.extern	FUNC(taskIdCurrent)
	.extern	FUNC(windExit)
#ifdef WV_INSTRUMENTATION
	.extern	FUNC(semInstClass)
#endif

	.text
	.balign	4

/******************************************************************************/
/*
 * PC-relative-addressable pointers - LDR Rn,=sym was (is?) broken
 * note "_" after "$" to stop preprocessor performing substitution
 */

L$__func_sigTimeoutRecalc:
	.long	FUNC(_func_sigTimeoutRecalc)
L$_intCnt:
	.long	FUNC(intCnt)
L$_kernelState:
	.long	FUNC(kernelState)
L$_semClass:
	.long	FUNC(semClass)
L$_semMGiveKernWork:
	.long	FUNC(semMGiveKernWork)
L$_taskIdCurrent:
	.long	FUNC(taskIdCurrent)

#ifdef WV_INSTRUMENTATION
L$_semInstClass:
	.long	FUNC(semInstClass)
#endif

/*******************************************************************************
*
* semMGive - give a semaphore
*
* Gives the semaphore.  If a higher priority task has already taken
* the semaphore (so that it is now pended waiting for it), that task
* will now become ready to run, and preempt the task that does the semGive().
* If the semaphore is already full (it has been given but not taken) this
* call is essentially a no-op.
*
* If deletion safe option is enabled, an implicit taskUnsafe() operation will
* occur.
*
* If priority inversion safe option is enabled, and this is the last priority
* inversion safe semaphore to be released, the calling task will revert to
* its normal priority.
*
* This routine may not be used from interrupt level.
* In this case it sets errno to S_intLib_NOT_ISR_CALLABLE and returns ERROR
*
* RETURNS: OK, or ERROR if the semaphore ID is invalid.

* STATUS semMGive
*	(
*	SEM_ID semId	/@ semaphore ID to give @/
*	)

*/

FUNC_LABEL(semMGive)

	/* check if called from ISR */

	LDR	r2, L$_intCnt		/* restrict ISR use */
	LDR	r2, [r2]
	TEQS	r2, #0
	BNE	FUNC(semIntRestrict)		/* if ISR, let C function do the work */

	/* LOCK INTERRUPTS */

	MRS	r3, cpsr
	ORR	r12, r3, #I_BIT
	MSR	cpsr, r12

	/* check validity of semaphore */

	LDR	r2, [r0]		/* get class of semaphore */
	LDR	r12, L$_semClass	/* get address of semClass */
	TEQS	r12, r2
#ifdef WV_INSTRUMENTATION
	LDRNE	r12, L$_semInstClass	/* if not semClass, semInstClass? */
	TEQNES	r12, r2
#endif
	BNE	L3_semMGiveInvalid	/* return error if invalid */

	/* semaphore is valid - check if current task is owner */

	LDR	r1, L$_taskIdCurrent
	LDR	r1, [r1]
	LDR	r12, [r0, #SEM_STATE]	/* r12 = owner */
	TEQS	r12, r1
	BNE	L3_semMGiveInvalid	/* return error if invalid */

	/* check recursion count */

#if ARM_HAS_HALFWORD_INSTRUCTIONS
	LDRH	r12, [r0, #SEM_RECURSE]	/* r12 = recursion count */
	TEQS	r12, #0
	BEQ	L3_semMGive

	SUB	r12, r12, #1		/* decrement count if != 0 */
	STRH	r12, [r0, #SEM_RECURSE]
#else /* ARM_HAS_HALFWORD_INSTRUCTIONS */
	LDR	r12, [r0, #(SEM_RECURSE & ~3)] /* word-aligned load */
#if (_BYTE_ORDER == _BIG_ENDIAN)
#if (SEM_RECURSE & 2)
	MOVS	r2, r12, LSL #16	/* set flags */
#else
	MOVS	r12, r12, LSR #16	/* move count to b15..b0, set flags */
#endif
	BEQ	L3_semMGive

	SUB	r12, r12, #1		/* decrement count if != 0 */
	STRB	r12, [r0, #SEM_RECURSE+1]
	MOV	r12, r12, LSR #8
	STRB	r12, [r0, #SEM_RECURSE+0]
#else  	/* _BYTE_ORDER == _BIG_ENDIAN */
#if (SEM_RECURSE & 2)
	MOVS	r12, r12, LSR #16	/* move count to b15..b0, set flags */
#else
	MOVS	r2, r12, LSL #16	/* set flags */
#endif
	BEQ	L3_semMGive

	SUB	r12, r12, #1		/* decrement count if != 0 */
	STRB	r12, [r0, #SEM_RECURSE+0]
	MOV	r12, r12, LSR #8
	STRB	r12, [r0, #SEM_RECURSE+1]
#endif 	/* _BYTE_ORDER == _BIG_ENDIAN */
#endif	/* ARM_HAS_HALFWORD_INSTRUCTIONS */

	MSR	cpsr, r3		/* UNLOCK INTERRUPTS */
	MOV	r0, #OK			/* ..and return OK */
	MOV	pc, lr

L3_semMGive:

/*
 * this semaphore is not recursive
 *
 * r0: semId
 * r1: taskIdCurrent
 * r2: Available
 * r3: previous cpsr
 * r12: Available
 */

	/* recursion count was zero - check if inversion safe */

	LDRB	r12, [r0, #SEM_OPTIONS]
	TSTS	r12, #SEM_INVERSION_SAFE
	MOVEQ	r12, #0			/* zero flags */
	BEQ	L0_semMGive		/* if not, test semQ */

	/*
	 * it is inversion safe - decrement and check mutex count
	 * r1 = taskIdCurrent
	 */

	LDR	r12, [r1, #WIND_TCB_MUTEX_CNT]
	SUBS	r12, r12, #1
	STR	r12, [r1, #WIND_TCB_MUTEX_CNT]
	MOVNE	r12, #0			/* zero flag */
	BNE	L0_semMGive		/* if non-zero, test semQ */

	/* check priority */

	LDR	r2, [r1, #WIND_TCB_PRIORITY] 	/* r2 = current priority */
	LDR	r12, [r1, #WIND_TCB_PRI_NORMAL]	/* r12 = normal priority */
	TEQS	r2, r12			/* are they the same? */
	MOVNE	r12, #SEM_M_PRI_RESORT	/* if not, OR in RESORT flag */
	MOVEQ	r12, #0

L0_semMGive:
	/* set owner to head of queue and check if queue was empty */

	LDR	r2, [r0, #SEM_Q_HEAD]	/* set owner = head of queue */
	STR	r2, [r0, #SEM_STATE]
	TEQS	r2, #0			/* queue empty? */
	ORRNE	r12, r12, #SEM_M_Q_GET	/* if not, OR in Q_GET flag */
	BNE	semMDeleteSafe

	/*
	 * The queue is empty.  If semId->events.taskId is not NULL, then
	 * set the SEM_M_SEND_EVENTS bit in the <kernWork> variable.  Although
	 * inserting an alogithm similar to semEvRsrcSend in semALib.s could
	 * be used here, it is more convenient to simply set the bit, and let
	 * the work be done in the C function semMGiveKern (semId).
	 */

	LDR	r2, [r0, #SEM_EVENTS_TASKID]
	TEQ	r2, #0
	ORRNE	r12, r12, #SEM_M_SEND_EVENTS

	/* check if delete safe */
semMDeleteSafe:
	LDRB	r2, [r0, #SEM_OPTIONS]
	TSTS	r2, #SEM_DELETE_SAFE
	BEQ	L1_semMGive		/* branch if not delete safe */

	LDR	r2, [r1, #WIND_TCB_SAFE_CNT] /* decrement safety count */
	SUBS	r2, r2, #1
	STR	r2, [r1, #WIND_TCB_SAFE_CNT]
	BNE	L1_semMGive		/* branch if count not zero */

	LDR	r2, [r1, #WIND_TCB_SAFETY_Q_HEAD] /* check for pended deleters*/
	TEQS	r2, #0
	ORRNE	r12, r12, #SEM_M_SAFE_Q_FLUSH /* OR in if Q not empty */

L1_semMGive:
	/*
	 * have we accumulated any work to do
	 * r0-> semaphore
	 * r1 = taskIdCurrent
	 * r3 = previous cpsr
	 * r12 = flags indicating work to do
	 */

	TEQS	r12, #0			/* anything to do? */
	BNE	L2_semMGive		/* branch if yes */

	/* all done */

	MSR	cpsr, r3		/* UNLOCK INTERRUPTS */
	MOV	r0, #OK			/* return OK */
	MOV	pc, lr

	/* NEVER FALL THROUGH */

L2_semMGive:
	/*
	 * we have got some work to do
	 * r0-> semaphore
	 * r1 = taskIdCurrent
	 * r3 = previous cpsr
	 * r12 = flags indicating work to do
	 */

	LDR	r2, L$_kernelState	/* KERNEL ENTER */
	MOV	r1, #1
	STR	r1, [r2]
	MSR	cpsr, r3		/* UNLOCK INTERRUPTS */
	LDR	r2, L$_semMGiveKernWork	/* setup work for semMGiveKern */
	STR	r12, [r2]
	B	FUNC(semMGiveKern)

	/* NEVER FALL THROUGH */

L3_semMGiveInvalid:
	/*
	 * semaphore is invalid
	 * r3 = previous cpsr
	 * interrupts are locked
	 */

	MSR	cpsr, r3		/* UNLOCK INTERRUPTS */
	B	FUNC(semInvalid)

/*******************************************************************************
*
* semMTake - take a semaphore
*
* Takes the semaphore.  If the semaphore is empty, i.e., it has not been given
* since the last semTake() or semInit(), this task will become pended until
* the semaphore becomes available by some other task doing a semGive()
* of it.  If the semaphore is already available, this call will empty
* the semaphore, so that no other task can take it until this task gives
* it back, and this task will continue running.
*
* If deletion safe option is enabled, an implicit taskSafe() operation will
* occur.
*
* If priority inversion safe option is enabled, and the calling task blocks,
* and the priority of the calling task is greater than the semaphore owner,
* the owner will inherit the caller's priority.
*
* WARNING
* This routine may not be used from interrupt level.

* STATUS semMTake
*	(
*	SEM_ID	semId,		/@ semaphore ID to take @/
*	int	timeout		/@ timeout in ticks @/
*	)
*/

FUNC_LABEL(semMTake)

	/* check if called from ISR */

	LDR	r2, L$_intCnt		/* restrict ISR use */
	LDR	r2, [r2]
	TEQS	r2, #0
	BNE	FUNC(semIntRestrict)	/* if ISR, let C function do the work */

	STMFD	sp!, {r0, r1, lr}	/* save args and link */
	LDR	r1, L$_taskIdCurrent
	LDR	r1, [r1]		/* r1 = taskIdCurrent */

	/* LOCK INTERRUPTS */

	MRS	r3, cpsr
	ORR	r12, r3, #I_BIT
	MSR	cpsr, r12

	/* check validity of semaphore */

	LDR	r2, [r0]		/* get class of semaphore */
	LDR	r12, L$_semClass	/* get address of semClass */
	TEQS	r12, r2
#ifdef WV_INSTRUMENTATION
	LDRNE	r12, L$_semInstClass	/* if not semClass, semInstClass? */
	TEQNES	r12, r2
#endif
	BNE	L3_semMTakeInvalid	/* return error if invalid */

	/* semaphore is valid - check if owned */

	LDR	r12, [r0, #SEM_STATE]	/* r12 = owner */
	TEQS	r12, #0			/* is it owned? */
	BNE	L0_semMTake		/* branch if it is owned */

	/* semaphore is not owned - set owner to current task (r1) */

	STR	r1, [r0, #SEM_STATE]	/* we now own semaphore */

	/* check if delete safe */

	LDRB	r2, [r0, #SEM_OPTIONS]
	TSTS	r2, #SEM_DELETE_SAFE
	LDRNE	r12, [r1, #WIND_TCB_SAFE_CNT] /* if del safe, inc safety cnt */
	ADDNE	r12, r12, #1
	STRNE	r12, [r1, #WIND_TCB_SAFE_CNT]

	/* check if inversion safe */

	TSTS	r2, #SEM_INVERSION_SAFE
	LDRNE	r12, [r1, #WIND_TCB_MUTEX_CNT] /* if inv safe, inc mutex cnt */
	ADDNE	r12, r12, #1
	STRNE	r12, [r1, #WIND_TCB_MUTEX_CNT]

	MSR	cpsr, r3		/* UNLOCK INTERRUPTS */
	ADD	sp, sp, #12		/* flatten stack */
	MOV	r0, #OK			/* return OK */
	MOV	pc, lr

	/* NEVER FALL THROUGH */

L0_semMTake:
	/*
	 * semaphore is owned
	 * r0-> semaphore
	 * r1 = taskIdCurrent
	 * r3 = previous cpsr
	 * r12 = owner of semaphore
	 */

	TEQS	r1, r12			/* does this task own semaphore? */
	BNE	L1_semMTake		/* branch if not (block) */

	/* recursive take - increment count */

#if ARM_HAS_HALFWORD_INSTRUCTIONS
	LDRH	r2, [r0, #SEM_RECURSE]	/* r2 = recursion count */
	ADD	r2, r2, #1		/* bump count */
	STRH	r2, [r0, #SEM_RECURSE]
#else
	LDR	r2, [r0, #(SEM_RECURSE & ~3)] /* word-aligned load */
#if (_BYTE_ORDER == _BIG_ENDIAN)
#if ((SEM_RECURSE & 2) == 0)
	MOV	r2, r2, LSR #16		/* move count to b15..b0 */
#endif
	ADD	r2, r2, #1		/* bump count */
	STRB	r2, [r0, #SEM_RECURSE+1]
	MOV	r2, r2, LSR #8
	STRB	r2, [r0, #SEM_RECURSE+0]
#else
#if (SEM_RECURSE & 2)
	MOV	r2, r2, LSR #16		/* move count to b15..b0 */
#endif
	ADD	r2, r2, #1		/* bump count */
	STRB	r2, [r0, #SEM_RECURSE+0]
	MOV	r2, r2, LSR #8
	STRB	r2, [r0, #SEM_RECURSE+1]
#endif	/* _BYTE_ORDER == _BIG_ENDIAN */
#endif	/* ARM_HAS_HALFWORD_INSTRUCTIONS */

	MSR	cpsr, r3		/* UNLOCK INTERRUPTS */
	ADD	sp, sp, #12		/* flatten stack */
	MOV	r0, #OK			/* return OK */
	MOV	pc, lr

	/* NEVER FALL THROUGH */

L1_semMTake:
	/*
	 * this task does not own the semaphore - block
	 * r0-> semaphore
	 * r3 = previous cpsr
	 */

	LDR	r2, L$_kernelState	/* KERNEL ENTER */
	MOV	r1, #1
	STR	r1, [r2]
	MSR	cpsr, r3		/* UNLOCK INTERRUPTS */

	LDR	r1, [sp, #4]		/* reload timeout */
	BL	FUNC(semMPendQPut)		/* let C function do the work */
	TEQS	r0, #OK			/* check result */
	BNE	L2_semMTake		/* branch if not OK */

	/* succeeded */

	BL	FUNC(windExit)		/* KERNEL EXIT */
	TEQS	r0, #RESTART		/* if not RESTART.. */
	ADDNE	sp, sp, #8		/* ..flatten stack */
	LDMNEFD	sp!, {pc}		/* ..and return */

	/* restart: recalculate the timeout and try again */

	LDR	r0, [sp, #4]		/* get timeout from stack */
	LDR	r1, L$__func_sigTimeoutRecalc
	MOV	lr, pc			/* recalculate the timeout */
	LDR	pc, [r1]
	MOV	r1, r0			/* r1 = timeout */
	LDMFD	sp!, {r0,r2,lr}		/* restore r0,lr/flatten stack */
	B	FUNC(semTake)		/* go again */

	/* NEVER FALL THROUGH */

L2_semMTake:
	/* could not block (semMPendQPut failed) - return ERROR */

	BL	FUNC(windExit)		/* KERNEL EXIT */
	MOV	r0, #ERROR		/* return ERROR */
	ADD	sp, sp, #8		/* flatten stack */
	LDMFD	sp!, {pc}

	/* NEVER FALL THROUGH */

L3_semMTakeInvalid:
	/*
	 * semaphore is invalid
	 * r3 = previous cpsr
	 * interrupts are locked
	 * sp-> {original r0,r1,lr}
	 */

	MSR	cpsr, r3		/* UNLOCK INTERRUPTS */
	LDMFD	sp!, {r0,r1,lr}		/* restore regs/flatten stack */
	B	FUNC(semInvalid)

#endif /* ! semMALib_PORTABLE */
