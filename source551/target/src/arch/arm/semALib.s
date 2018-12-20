/* semALib.s - VxWorks binary semaphore assembler library */

/* Copyright 1996-2001 Wind River Systems, Inc. */
			
/*
modification history
--------------------
01p,30may02,m_h  semBGive unintended effects of MSREQ (78125)
01o,12mar02,m_h  semTake must return error if called from ISR (74202)
01n,15jan02,m_h  smObjPoolMinusOne typo in .extern
01m,30oct01,pcm  added VxWorks semaphore events
01l,17oct01,t_m  convert to FUNC_LABEL:
01k,11oct01,jb  Enabling removal of pre-pended underscores for new compilers
                 (Diab/Gnu elf)
01j,23nov98,cdp  added big-endian support; fix Thumb instrumentation (not
		 currently used); make Thumb support dependent on ARM_THUMB;
		 optimise for no instrumentation.
01i,09sep98,cjtc completing port for WV20
01h,02sep98,cjtc port to windView 2.0
01g,31jul98,pr   temporarily commentig out WindView code
01f,10feb98,cdp  updated for coding standards.
01e,27oct97,kkk  took out "***EOF***" line from end of file.
01d,15oct97,tam  made semBTake return OK on success.
01c,05sep97,cdp  complete rewrite to facilitate instrumentation.
01b,27may97,jpd  Amalgamated into VxWorks.
01a,05jul96,ams  Written.
*/

/*
DESCRIPTION
This module contains internals to the VxWorks kernel.
These routines have been coded in assembler because they are optimized for
performance.
*/

#define _ASMLANGUAGE
#include "vxWorks.h"
#include "vwModNum.h"
#include "asm.h"
#include "eventLib.h"
#include "semLib.h"
#include "private/semLibP.h"
#include "private/classLibP.h"
#include "private/sigLibP.h"
#include "private/eventP.h"

	.data
	.globl	FUNC(copyright_wind_river)
	.long	FUNC(copyright_wind_river)

#if (defined(PORTABLE))
#define semALib_PORTABLE
#endif

#ifndef semALib_PORTABLE

/* globals */

	.globl	FUNC(semGive)		/* optimized semGive demultiplexer */
	.globl	FUNC(semTake)		/* optimized semTake demultiplexer */
	.globl	FUNC(semBGive)		/* optimized binary semaphore give */
	.globl	FUNC(semBTake)		/* optimized binary semaphore take */
	.globl	FUNC(semQGet)		/* semaphore queue get routine */
	.globl	FUNC(semQPut)		/* semaphore queue put routine */
	.globl	FUNC(semOTake)		/* optimized old semaphore take */
	.globl	FUNC(semClear)		/* optimized old semaphore semClear */
	.globl	FUNC(semEvRsrcSend)	/* semaphore event rsrc send routine */

/* externals */

	.extern	FUNC(_func_sigTimeoutRecalc)
	.extern	FUNC(intCnt)
	.extern	FUNC(kernelState)
	.extern	FUNC(semClass)
	.extern	FUNC(semGiveDefer)
	.extern	FUNC(semGiveTbl)
	.extern	FUNC(semInvalid)
	.extern	FUNC(semTakeTbl)
	.extern	FUNC(smObjPoolMinusOne)
	.extern	FUNC(taskIdCurrent)
	.extern	FUNC(windExit)
	.extern	FUNC(windPendQGet)
	.extern	FUNC(windPendQPut)
#ifdef WV_INSTRUMENTATION
        .extern	FUNC(evtAction)
        .extern	FUNC(wvEvtClass)
        .extern	FUNC(trgEvtClass) 
        .extern	FUNC(_func_evtLogM1)
        .extern	FUNC(_func_trgCheck)
        .extern	FUNC(semInstClass)
#endif /* WV_INSTRUMENTATION */

#if	(ARM_THUMB)
	.extern	FUNC(arm_call_via_r2)
	.extern	FUNC(arm_call_via_r12)
	.extern	FUNC(windPendQGet)
#endif	/* ARM_THUMB */

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
L$_semGiveTbl:
	.long	FUNC(semGiveTbl)
L$_semTakeTbl:
	.long	FUNC(semTakeTbl)
L$_smObjPoolMinusOne:
	.long	FUNC(smObjPoolMinusOne)
L$_taskIdCurrent:
	.long	FUNC(taskIdCurrent)
L$_errno:
	.long	FUNC(errno)

#if	(ARM_THUMB)
L$_windPendQGet:
	.long	FUNC(windPendQGet)
#endif	/* ARM_THUMB */

#ifdef WV_INSTRUMENTATION
L$_evtAction:
	.long	FUNC(evtAction)
L$_wvEvtClass:
	.long	FUNC(wvEvtClass) 
L$_trgEvtClass:
	.long	FUNC(trgEvtClass) 
L$_semInstClass:
	.long	FUNC(semInstClass)
L$__func_evtLogM1:
	.long	FUNC(_func_evtLogM1)
L$__func_trgCheck:
	.long	FUNC(_func_trgCheck)
L$_EVENT_SEMGIVE:
	.long	EVENT_SEMGIVE
L$_EVENT_SEMTAKE:
	.long	EVENT_SEMTAKE
L$_EVENT_OBJ_SEMTAKE:
	.long	EVENT_OBJ_SEMTAKE
L$_TRG_CLASS_2_ON:
	.long	TRG_CLASS_2_ON
L$_TRG_CLASS_3_ON:
	.long	TRG_CLASS_3_ON
#endif /* WV_INSTRUMENTATION */

/*******************************************************************************
*
* semGive - give a semaphore
*
* This routine performs the give operation on a specified semaphore.
* Depending on the type of semaphore, the state of the semaphore and of the
* pending tasks may be affected.  The behavior of semGive() is discussed
* fully in the library description of the specific semaphore type being used.
*
* RETURNS: OK, or ERROR if the semaphore ID is invalid.

* STATUS semGive
*	(
*	SEM_ID semId	/@ semaphore ID to give @/
*	)

*/

FUNC_LABEL(semGive)

	TSTS	r0, #1			/* shared ? */
	BNE	semGiveGlobal		/* branch if shared */

	/* Semaphore is local */

#ifdef WV_INSTRUMENTATION

	/* windview instrumentation - BEGIN
	 * semGive level 1 (object status event)
	 */

	LDR	r2, L$_evtAction	/* event logging or triggering on? */
	LDR	r2, [r2]
	TEQS	r2, #0
	BNE	instrumentSemGive	/* branch if so */

	/* instrumentation currently disabled */

resumeSemGive:

	/* windview instrumentation - END */
#endif	/* WV_INSTRUMENTATION */


	/* if in kernelState, defer */

	LDR	r1, L$_kernelState	/* get addr of kernelState */
	LDR	r1, [r1]		/* load value of kernelState */
	TEQS	r1, #0			/* in kernel state? */
	BNE	FUNC(semGiveDefer)		/* branch if so (r0 = semId) */
	
	/* Give the semaphore now, with fast route for binary semaphores */

	LDRB	r1, [r0, #SEM_TYPE]	/* get semType */
	ANDS	r1, r1, #SEM_TYPE_MASK
	BNE	semGiveCallViaTable	/* branch if not binary */

	/*
	 * BINARY SEMAPHORE OPTIMISATION
	 * FALL THROUGH	to semBGive
	 */

/*******************************************************************************
*
* semBGive - give a binary semaphore
*
* Gives the semaphore.  If a higher priority task has already taken
* the semaphore (so that it is now pended waiting for it), that task
* will now become ready to run, and preempt the task that does the semGive().
* If the semaphore is already full (it has been given but not taken) this
* call is essentially a no-op.
*
* RETURNS: OK, or ERROR if the semaphore ID is invalid.

* STATUS semBGive
*	(
*	SEM_ID semId	/@ semaphore ID to give @/
*	)

*/

FUNC_LABEL(semBGive)
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
#endif /* WV_INSTRUMENTATION */
	BNE	semIsInvalidUnlock	/* branch if invalid */

	/* semaphore is valid */

	LDR	r1, [r0, #SEM_Q_HEAD]	/* update semaphore */
	LDR	r2, [r0, #SEM_STATE]	/* old semOwner */
	STR	r1, [r0, #SEM_STATE]	/* new semOwner */
	TEQS	r1, #0			/* empty? */
	BNE	FUNC(semQGet)		/* if not, get from queue */

	LDR	r12, [r0, #SEM_EVENTS_TASKID]
	TEQS	r12, #0			/* Test the semId->events.taskId and */
	TEQNE	r2, #0			/* previous semOwner against NULL. */
	
	BNE     FUNC(semEvRsrcSend)

	MSR	cpsr, r3		/* Return immediately if either one */
	MOV	r0, #OK			/* was NULL (no state change). */ 
	MOV	pc, lr			/* Otherwise fall through to */
					/* FUNC_LABEL(semEvRsrcSend) to send */
					/* semaphore event. */

/******************************************************************************
*
* semEvRsrcSend - send semaphore event to a task
*
* This sub-routine makes a call to eventRsrcSend() if there has been a state
* change on the semaphore, and semId->events.taskId is not NULL.  The tests for
* determining whether to a state change has occurred are done before this 
* sub-routine is executed.  Note the current register usage.
*
* r0:	semId
* r1:	Can Change
* r2:	Can Change
* r3:	previous cpsr
* r12:	semId->events.taskId
*/
FUNC_LABEL(semEvRsrcSend)
	LDR	r1, L$_kernelState
	MOV	r2, #1			/* ENTER KERNEL */
	STR	r2, [r1]
	MSR	cpsr, r3		/* UNLOCK INTERRUPTS */

	STMFD	sp!, {r4-r6, lr}	/* Save r4-r6, and link register */
	MOV	r4, r0			/* r4: semId */
	LDR	r6, L$_errno		/* r6: &errno */
	LDR	r5, [r6]		/* r5: errno */

	LDR	r1, [r0, #SEM_EVENTS_REGISTERED] /* semId->events.registered */
	MOV	r0, r12			/* semId->events.taskId */

	BL	FUNC(eventRsrcSend)	/* eventSend (r0, r1) */

	/*
	 * "if (evSendStatus && !(semOptions & EVENT_SEND_ERROR_NOTIFY))"
	 * can be condensed to one test condition.  This is because
	 * evSendStatus is either OK (0), or ERROR (-1).  AND'ing evSendStatus
	 * with semOptions will either clear the EVENT_SEND_ERROR_NOTIFY bit
	 * if evSendStatus was OK, or leave the bit unchanged if evSendStatus
	 * was ERROR.
	 */

	LDRB	r2, [r4, #SEM_OPTIONS]
	AND	r1, r0, r2
	TST	r1, #SEM_EVENTSEND_ERR_NOTIFY

	MOVNE	r3, #ERROR			/* covers <retStatus> */
	MOVEQ	r3, #OK

	/* Load S_eventLib_EVENTSEND_FAILED into r5 if <retStatus> == ERROR */

	MOV	r2, #(S_eventLib_EVENTSEND_FAILED >> 16)
	MOVNE	r5, #(S_eventLib_EVENTSEND_FAILED & 65535)
	ORRNE	r5, r5, r2, LSL #16		/* covers <errno> */
	
	/*
	 * "if (evSendStatus || !(evtOptions & EVENTS_SEND_ONCE))"
	 * can be condensed to one test condition.  This is because
	 * evSendStatus is either OK (0), or ERROR (-1).  OR'ing evSendStatus
	 * with evtOptions will either set the EVENTS_SEND_ONCE bit if
	 * evSendStatus was ERROR, or leave the bit unchanged if evSendStatus
	 * was OK.
	 */

	LDRB	r2, [r4, #SEM_EVENTS_OPTIONS]
	ORR	r1, r0, r2
	TST	r1, #EVENTS_SEND_ONCE

	MOV	r0, #0				/* Clear semId->events.taskId */
	STRNE	r0, [r4, #SEM_EVENTS_TASKID]	/* if above test evaluated to */
						/* TRUE. */

	MOV	r4, r3				/* Save <retStatus> */
	BL	FUNC(windExit)			/* KERNEL EXIT */

	MOV	r0, r4				/* return <retStatus> */
	STR	r5, [r6]			/* Update errno */
	LDMFD	sp!, {r4-r6, pc}		/* Restore r4-r6, and return */
	
	/* NEVER FALL THROUGH */

/******************************************************************************/

semGiveGlobal:
	/*
	 * semaphore is shared
	 * r0-> semaphore
	 */

	LDR	r2, L$_smObjPoolMinusOne /* get address of smObjPoolMinusOne */
	LDR	r2, [r2]
	ADD	r0, r0, r2		/* convert id to local address */

	/*
	 * get semaphore type from SM_SEM_ID (struct sm_semaphore): this
	 * is a 32-bit word in network byte order (unlike in SEMAPHORE where
	 * it's a single byte)
	 */

#if (_BYTE_ORDER == _BIG_ENDIAN)
	LDR 	r1, [r0, #SEM_TYPE]	/* get sem type in network byte order */
#else
	LDRB	r1, [r0, #SEM_TYPE+3]	/* get sem type in network byte order */
#endif
	AND	r1, r1, #SEM_TYPE_MASK	/* index into table */

semGiveCallViaTable:
	/*
	 * r0-> semaphore (parameter for semaphore function)
	 * r1 = index into semGiveTbl
	 * lr = return address
	 */

	LDR	r2, L$_semGiveTbl	/* get address of jump table */
	LDR	pc, [r2, r1, LSL #2]	/* jump to fn (semId in r0) */

/******************************************************************************/

#ifdef WV_INSTRUMENTATION

	/* windview instrumentation - BEGIN
	 * semGive level 1 (object status event)
	 */

instrumentSemGive:

	/* is this a valid semaphore? */

	LDR	r2, [r0]		/* get class of semaphore */
	LDR	r3, L$_semClass		/* get address of semClass */
	TEQS	r3, r2			/* if not, semClass.. */
	LDRNE	r3, L$_semInstClass	/* ..get address of semInstClass */
	TEQNES	r3, r2
	BNE	resumeSemGive		/* branch if invalid */

	/* This is a valid semaphore and some sort of instrumentation is on */
	
	STMFD	sp!, {r0,lr}		/* save semId and link */

        /* Check if we are at a high enough logging level */

        LDR	lr, L$_wvEvtClass	/* is instrumentation on? */
	LDR	lr, [lr]
        AND	lr, lr, #WV_CLASS_3_ON	
        TEQS	lr, #WV_CLASS_3_ON	
	BNE	trgSemGiveEvt		/* branch if not */

	/* is this semaphore object instrumented? */

	LDR	r12, [r2, #SEM_INST_RTN] /* event routine attached? */
	TEQS	r12, #0
	BEQ	trgSemGiveEvt		/* branch if no event routine */

	/* 
	 * log event for this object
	 * There are 7 arguments to this function
	 * 4 are passed in registers r0 to r3
	 * 3 are passed on the stack
	 */

	STMFD	sp!, {r0}		/* save semId to stack */

	MOV	r3, #0			/* push 2 dummy args */
	MOV	r2, #0

#if ARM_HAS_HALFWORD_INSTRUCTIONS
	LDRH	r1, [r0, #SEM_RECURSE]	/* r1 = recursion count */
#else
	LDR	r1, [r0, #(SEM_RECURSE & ~3)] /* word-aligned load */
#if (_BYTE_ORDER == _BIG_ENDIAN)
#if ((SEM_RECURSE & 2) != 0)
	MOV	r1, r1, LSL #16		/* so next instr will clear b31..b16 */
#endif
	MOV	r1, r1, LSR #16		/* r1[15..0] = recursion count */
#else	/* _BYTE_ORDER */
#if ((SEM_RECURSE & 2) == 0)
	MOV	r1, r1, LSL #16		/* so next instr will clear b31..b16 */
#endif
	MOV	r1, r1, LSR #16		/* r1[15..0] = recursion count */
#endif	/* _BYTE_ORDER */
#endif	/* ARM_HAS_HALFWORD_INSTRUCTIONS */

	/*
	 * Push the 3 stack-based parameters in r1-r3
	 * They are pushed in order r3, r2, r1
	 */

	STMFD	sp!, {r1-r3}

	LDR	r3, [r0, #SEM_STATE]	/* r3 = semaphore state */
	MOV	r2, r0			/* r2 = semId */
	MOV	r1, #3			/* nParam */
	LDR	r0, L$_EVENT_SEMGIVE	/* r0 = eventId */

#if	(ARM_THUMB)
	BL	FUNC(arm_call_via_r12)	/* call logging routine */
#else
	MOV	lr, pc			
	MOV	pc, r12			/* call logging routine */
#endif	/* ARM_THUMB */

	ADD	sp, sp, #12		/* strip 3 parameters from stack */
	LDMFD	sp!, {r0}		/* restore semId from stack*/

trgSemGiveEvt:
        LDR	r2, L$_trgEvtClass	/* is triggering on? */
	LDR	r2, [r2]
	LDR	r3, L$_TRG_CLASS_3_ON
        AND	r2, r2, r3	
        TEQS	r2, r3
	BNE	semGiveTidy		/* branch if not */

	/*
	 * There are 8 parameters to the trgCheck function:
	 * r0	 <- eventId
	 * r1 	 <- index = TRG_CLASS3_INDEX
	 * r2 	 <- obj = semId
	 * r3 	 <- arg1 (NULL - unused)
	 * stack <- arg2 (NULL - unused)
	 * stack <- arg3 (NULL - unused)
	 * stack <- arg4 (NULL - unused)
	 * stack <- arg5 (NULL - unused)
	 */

	MOV	r2, #0
	MOV	r3, #0
	STMFD	sp!, {r2,r3}		/* push 2 dummy args */
	STMFD	sp!, {r2,r3}		/* push 2 dummy args .. again */
					/* r3 = NULL from above */
	MOV	r2, r0			/* r2 = semId */
	MOV	r1, #TRG_CLASS3_INDEX	/* r1 = Class */
	LDR	r0, L$_EVENT_SEMGIVE	/* r0 = event type */

	LDR	r12,L$__func_trgCheck 		/* trigCheck routine */

#if	(ARM_THUMB)
	LDR	r12, [r12]			/* get function address */
	BL	FUNC(arm_call_via_r12)		/* and call it */
#else
	MOV	lr, pc				/* call function */
	LDR	pc, [r12]
#endif	/* ARM_THUMB */

	ADD	sp, sp, #16		/* strip parameters from stack */
semGiveTidy:
	LDMFD	sp!, {r0,lr}		/* restore semId and link */

	B	resumeSemGive

	/* windview instrumentation - END */
#endif	/* WV_INSTRUMENTATION */

/*******************************************************************************
*
* semTake - take a semaphore
*
* This routine performs the take operation on a specified semaphore.
* Depending on the type of semaphore, the state of the semaphore and
* the calling task may be affected.  The behavior of semTake() is
* discussed fully in the library description of the specific semaphore
* type being used.
*
* A timeout in ticks may be specified.  If a task times out, semTake() will
* return ERROR.  Timeouts of WAIT_FOREVER (-1) and NO_WAIT (0) indicate to wait
* indefinitely or not to wait at all.
*
* When semTake() returns due to timeout, it sets the errno to
* S_objLib_OBJ_TIMEOUT (defined in objLib.h).
*
* The semTake() routine is not callable from interrupt service routines.
* In this case it sets errno to S_intLib_NOT_ISR_CALLABLE and returns ERROR
*
* RETURNS: OK, or ERROR if the semaphore ID is invalid or the task timed out.

* STATUS semTake
*	(
*	SEM_ID	semId,		/@ semaphore ID to take @/
*	ULONG	timeout		/@ timeout in ticks @/
*	)

*/

FUNC_LABEL(semTake)

	TSTS	r0, #1			/* shared semaphore? */
	BNE	semTakeGlobal		/* branch if shared */

	/* Semaphore is local */

#ifdef WV_INSTRUMENTATION

	/* windview instrumentation - BEGIN
	 * semTake level 1 (object status event)
	 */

	LDR	r2, L$_evtAction	/* is event logging or triggering? */
	LDR	r2, [r2]
	TEQS	r2, #0
	BNE	instrumentSemTake	/* branch if so */

resumeSemTake:

	/* windview instrumentation - END */
#endif	/* WV_INSTRUMENTATION */


	LDRB	r12, [r0, #SEM_TYPE]	/* get semType */
	ANDS	r12, r12, #SEM_TYPE_MASK
	BNE	semTakeNotBinary	/* branch if not binary */

	/*
	 * BINARY SEMAPHORE OPTIMISATION
	 * FALL THROUGH	to semBTake
	 */

/*******************************************************************************
*
* semBTake - take a binary semaphore
*
* Takes the semaphore.  If the semaphore is empty, i.e., it has not been given
* since the last semTake() or semInit(), this task will become pended until
* the semaphore becomes available by some other task doing a semGive()
* of it.  If the semaphore is already available, this call will empty
* the semaphore, so that no other task can take it until this task gives
* it back, and this task will continue running.
*
* WARNING
* This routine may not be used from interrupt level.
*
* RETURNS: OK, or ERROR if the semaphore ID is invalid.

* STATUS semBTake
*	(
*	SEM_ID	semId,		/@ semaphore ID to give @/
*	int	timeout		/@ timeout in ticks @/
*	)

*/

FUNC_LABEL(semBTake)

	/* check if called from ISR */

	LDR	r2, L$_intCnt		/* restrict ISR use */
	LDR	r2, [r2]
	TEQS	r2, #0
	BNE	FUNC(semIntRestrict)	/* if ISR, let C function do the work */

	/* LOCK INTERRUPTS */

	MRS	r3, cpsr
	ORR	r12, r3, #I_BIT
	MSR	cpsr, r12

	LDR	r2, [r0]		/* get class of semaphore */
	LDR	r12, L$_semClass	/* get address of semClass */
	TEQS	r12, r2
#ifdef WV_INSTRUMENTATION
	LDRNE	r12, L$_semInstClass	/* if not semClass, check if.. */
	TEQNES	r12, r2			/* ..semInstClass */
#endif	/* WV_INSTRUMENTATION */
	BNE	semIsInvalidUnlock	/* branch if invalid */

	/* semaphore is valid */

	LDR	r12, [r0, #SEM_STATE]	/* test for owner */
	TEQS	r12, #0
	BNE	FUNC(semQPut)		/* if sem is owned, we block */

	LDR	r12, L$_taskIdCurrent	/* make this task the owner */
	LDR	r12, [r12]
	STR	r12, [r0, #SEM_STATE]	

	MSR	cpsr, r3		/* UNLOCK INTERRUPTS */
	MOV	r0, #OK			/* return OK */
	MOV	pc, lr

/******************************************************************************/

semTakeGlobal:
	/*
	 * semaphore is shared
	 * r0-> semaphore
	 * r1 = timeout
	 */

	LDR	r2, L$_smObjPoolMinusOne /* get address of smObjPoolMinusOne */
	LDR	r2, [r2]
	ADD	r0, r0, r2		/* convert id to local address */

	/*
	 * get semaphore type from SM_SEM_ID (struct sm_semaphore): this
	 * is a 32-bit word in network byte order (unlike in SEMAPHORE where
	 * it's a single byte)
	 */
#if (_BYTE_ORDER == _BIG_ENDIAN)
	LDR 	r12, [r0, #SEM_TYPE]	/* get sem type in network byte order */
#else
	LDRB	r12, [r0, #SEM_TYPE+3]	/* get sem type in network byte order */
#endif	/* _BYTE_ORDER */
	AND	r12, r12, #SEM_TYPE_MASK /* index into table */


semTakeNotBinary:
	/*
	 * r0-> semaphore (parameter for semaphore function)
	 * r1 = timeout
	 * r12 = index into semTakeTbl
	 * lr = return address
	 */

	LDR	r2, L$_semTakeTbl	/* get address of jump table */
	LDR	pc, [r2, r12, LSL #2]	/* jump to fn (semId in r0) */

/******************************************************************************/

#ifdef WV_INSTRUMENTATION

	/* windview instrumentation - BEGIN
	 * semTake level 1 (object status event)
	 */

instrumentSemTake:

	/* is this a valid semaphore? */

	LDR	r2, [r0]		/* get class of semaphore */
	LDR	r3, L$_semClass		/* get address of semClass */
	TEQS	r3, r2			/* if not, semClass.. */
	LDRNE	r3, L$_semInstClass	/* ..get address of semInstClass */
	TEQNES	r3, r2
	BNE	resumeSemTake		/* branch if invalid */

	/* This is a valid samaphore and some sort of instrumentation is on */

        /* Check if we are at a high enough logging level */

	LDR	r3, L$_wvEvtClass	/* is instrumentation on? */
	LDR	r3, [r3]
	AND	r3, r3, #WV_CLASS_3_ON	
	TEQS	r3, #WV_CLASS_3_ON	
	BNE	trgSemTakeEvt		/* branch if not */

	/* is this semaphore object instrumented? */

	LDR	r12, [r2, #SEM_INST_RTN] /* event routine attached? */
	TEQS	r12, #0
	BEQ	trgSemTakeEvt		/* branch if no event routine */

	/* 
	 * log event for this object
	 * There are 7 arguments to this function
	 * 4 are passed in registers r0 to r3
	 * 3 are passed on the stack
	 */

	STMFD	sp!, {r0,r1,lr}		/* save semId, timeout, link */

	MOV	r3, #0			/* push two dummy args */
	MOV	r2, #0			/* param 4, param5 */

#if ARM_HAS_HALFWORD_INSTRUCTIONS
	LDRH	r1, [r0, #SEM_RECURSE]	/* r1 = recursion count */
#else
	LDR	r1, [r0, #(SEM_RECURSE & ~3)] /* word-aligned load */
#if (_BYTE_ORDER == _BIG_ENDIAN)
#if ((SEM_RECURSE & 2) != 0)
	MOV	r1, r1, LSL #16		/* so next instr will clear b31..b16 */
#endif
	MOV	r1, r1, LSR #16		/* r1[15..0] = recursion count */
#else	/* _BYTE_ORDER */
#if ((SEM_RECURSE & 2) == 0)
	MOV	r1, r1, LSL #16		/* so next instr will clear b31..b16 */
#endif
	MOV	r1, r1, LSR #16		/* r1[15..0] = recursion count */
#endif	/* _BYTE_ORDER */
#endif	/* ARM_HAS_HALFWORD_INSTRUCTIONS */

	/*
	 * Push the 3 stack-based parameters in r1-r3.
	 * They are pushed in order r3, r2, r1
	 */

	STMFD	sp!, {r1-r3}

	LDR	r3, [r0, #SEM_STATE]	/* param2 (r3) = semaphore state */
	MOV	r2, r0			/* param1 (r2) = semId */
	MOV	r1, #3			/* nParam */
	LDR	r0, L$_EVENT_SEMTAKE	/* action = eventId */

#if	(ARM_THUMB)
	BL	FUNC(arm_call_via_r12)	/* call logging routine */
#else
	MOV	lr, pc			
	MOV	pc, r12			/* call logging routine */
#endif	/* ARM_THUMB */

	ADD	sp, sp, #12		/* strip 3 parameters from stack */

	LDMFD	sp!, {r0,r1,lr}		/* restore semId, timeout and link */

trgSemTakeEvt:
        LDR	r2, L$_trgEvtClass	/* is triggering on? */
	LDR	r2, [r2]
	LDR	r3, L$_TRG_CLASS_3_ON
        AND	r2, r2, r3	
        TEQS	r2, r3
	BNE	resumeSemTake		/* branch if not */

	STMFD	sp!, {r0,r1,lr}		/* save semId, timeout, link */

	/*
	 * There are 8 parameters to the trgCheck function:
	 * r0	 <- eventId
	 * r1 	 <- index = TRG_CLASS3_INDEX
	 * r2 	 <- obj = semId
	 * r3 	 <- arg1 (NULL - unused)
	 * stack <- arg2 (NULL - unused)
	 * stack <- arg3 (NULL - unused)
	 * stack <- arg4 (NULL - unused)
	 * stack <- arg5 (NULL - unused)
	 */

	MOV	r2, #0
	MOV	r3, #0
	STMFD	sp!, {r2,r3}		/* push 2 dummy args */
	STMFD	sp!, {r2,r3}		/* push 2 dummy args .. again */
					/* r3 = NULL from above */
	MOV	r2, r0			/* r2 = semId */
	MOV	r1, #TRG_CLASS3_INDEX	/* r1 = Class */
	LDR	r0, L$_EVENT_SEMTAKE	/* r0 = event type */

	LDR	r12,L$__func_trgCheck 		/* trigCheck routine */

#if	(ARM_THUMB)
	LDR	r12, [r12]			/* get function address */
	BL	FUNC(arm_call_via_r12)		/* and call it */
#else
	MOV	lr, pc				/* call function */
	LDR	pc, [r12]
#endif	/* ARM_THUMB */

	ADD	sp, sp, #16		/* strip parameters from stack */
	LDMFD	sp!, {r0,r1,lr}		/* restore semId, timeout and link */

	B	resumeSemTake

	/* windview instrumentation - END */
#endif	/* WV_INSTRUMENTATION */

/*******************************************************************************
*
* semQGet - unblock a task from the semaphore queue head
*/

FUNC_LABEL(semQGet)
	/*
	 * r0-> semaphore
	 * r3 = previous cpsr
	 * lr = return address
	 * interrupts are locked
	 */

	MOV	r2, #1			/* KERNEL ENTER */
	LDR	r12, L$_kernelState
	STR	r2, [r12]

#ifdef WV_INSTRUMENTATION

        /* windview instrumentation - BEGIN
         * semGive level 2 (task transition state event)
         */

	LDR	r2, L$_evtAction	/* is event logging and or triggering?*/
	LDR	r2, [r2]
	TEQS	r2, #0
	BNE	instrumentSemQGet	/* branch if so */

	/* instrumentation currently disabled */

resumeSemQGet:

        /* windview instrumentation - END */
#endif	/* WV_INSTRUMENTATION */


	MSR	cpsr, r3		/* UNLOCK INTERRUPTS */
	STMFD	sp!, {lr}		/* save link */
	ADD	r0, r0, #SEM_Q_HEAD	/* r0-> qHead */
#if	(ARM_THUMB)
	LDR	r12, L$_windPendQGet	/* unblock someone */
	BL	FUNC(arm_call_via_r12)	/* returns in ARM state */
#else
	BL	FUNC(windPendQGet)		/* unblock someone */
#endif	/* ARM_THUMB */

	LDMFD	sp!, {lr}		/* restore link */
	B	FUNC(windExit)		/* KERNEL EXIT */

/******************************************************************************/

#ifdef WV_INSTRUMENTATION

        /* windview instrumentation - BEGIN
         * semGive level 2 (task transition state event)
         */

instrumentSemQGet:

        LDR	r2, L$_wvEvtClass	/* is instrumentation on? */
	LDR	r2, [r2]
        AND	r2, r2, #WV_CLASS_2_ON	
        TEQS	r2, #WV_CLASS_2_ON	
	BNE	trgSemQGetEvt		/* branch if not */

	LDR	r12, L$__func_evtLogM1	/* event log routine exists ? */
	LDR	r12, [r12]
	TEQS	r12, #0
	BEQ	trgSemQGetEvt		/* branch if nothing to call */

	STMFD	sp!, {r0,r3,lr}		/* save regs */
	MOV	r1, r0			/* r1 = semId */
	MOV	r0, #EVENT_OBJ_SEMGIVE	/* r0 = event id */

#if	(ARM_THUMB)
	BL	FUNC(arm_call_via_r12)	/* call function */
#else
	MOV	lr, pc			/* call function */
	MOV	pc, r12
#endif	/* ARM_THUMB */

	LDMFD	sp!, {r0,r3,lr}		/* restore regs */

trgSemQGetEvt: 
        LDR	r2, L$_trgEvtClass	/* is triggering on? */
	LDR	r2, [r2]
	LDR	r1, L$_TRG_CLASS_2_ON
        AND	r2, r2, r1
        TEQS	r2, r1
	BNE	resumeSemQGet		/* branch if not */

	STMFD	sp!, {r0,r3,lr}		/* save regs */

	/*
	 * There are 8 parameters to the trgCheck function:
	 * r0	 <- eventId
	 * r1 	 <- index = TRG_CLASS2_INDEX
	 * r2 	 <- obj = semId
	 * r3 	 <- arg1 (NULL - unused)
	 * stack <- arg2 (NULL - unused)
	 * stack <- arg3 (NULL - unused)
	 * stack <- arg4 (NULL - unused)
	 * stack <- arg5 (NULL - unused)
	 */

	MOV	r2, #0
	MOV	r3, #0
	STMFD	sp!, {r2,r3}		/* push 2 dummy args */
	STMFD	sp!, {r2,r3}		/* push 2 dummy args .. again */
						/* r3 = NULL from above */
	MOV	r2, r0				/* r2 = semId */
	MOV	r1, #TRG_CLASS2_INDEX		/* r1 = Class */
	MOV	r0, #EVENT_OBJ_SEMGIVE		/* r0 = event type */

	LDR	r12, L$__func_trgCheck 		/* trigCheck routine */

#if	(ARM_THUMB)
	LDR	r12, [r12]			/* get function address */
	BL	FUNC(arm_call_via_r12)		/* and call it */
#else
	MOV	lr, pc				/* call function */
	LDR	pc, [r12]
#endif	/* ARM_THUMB */

	ADD	sp, sp, #16		/* strip parameters from stack */
	LDMFD	sp!, {r0,r3,lr}		/* restore regs */
	B	resumeSemQGet

        /* windview instrumentation - END */
#endif	/* WV_INSTRUMENTATION */

/*******************************************************************************
*
* semQPut - block current task on the semaphore queue head
*/

FUNC_LABEL(semQPut)
	/*
	 * r0-> semaphore
	 * r1 = timeout
	 * r3 = previous cpsr
	 * interrupts are locked
	 */

	MOV	r2, #1			/* KERNEL ENTER */
	LDR	r12, L$_kernelState
	STR	r2, [r12]

#ifdef WV_INSTRUMENTATION

        /* windview instrumentation - BEGIN
         * semTake level 2 (task transition state event)
         */
	
	LDR	r2, L$_evtAction	/* is event logging and or triggering?*/
	LDR	r2, [r2]
	TEQS	r2, #0
	BNE	instrumentSemQPut	/* branch if so */

	/* instrumentation currently disabled */

resumeSemQPut:

        /* windview instrumentation - END */
#endif	/* WV_INSTRUMENTATION */


	MSR	cpsr, r3		/* UNLOCK INTERRUPTS */
	STMFD	sp!, {r0,r1,lr}
	ADD	r0, r0, #SEM_Q_HEAD	/* r0-> qHead */
#if	(ARM_THUMB)
	LDR	r12, L$_windPendQGet	/* unblock someone */
	BL	FUNC(arm_call_via_r12)	/* returns in ARM state */
#else
	BL	FUNC(windPendQPut)		/* block on the semaphore */
#endif	/* ARM_THUMB */

	TEQS	r0, #0			/* succeeded? */
	BNE	semQPutFail		/* branch if failed */

	/* succeeded */

	BL	FUNC(windExit)		/* KERNEL EXIT */
	TEQS	r0, #RESTART		/* if not RESTART.. */
	ADDNE	sp, sp, #8		/* ..strip stack.. */
	LDMNEFD	sp!, {pc}		/* ..and return */

	/* restart: recalculate the timeout and try again */

	LDR	r0, [sp, #4]		/* get timeout from stack */
	LDR	r1, L$__func_sigTimeoutRecalc

#if	(ARM_THUMB)
	LDR	r12, [r1]		/* get function address */
	BL	FUNC(arm_call_via_r12)	/* and call it */
#else
	MOV	lr, pc			/* recalculate the timeout */
	LDR	pc, [r1]
#endif	/* ARM_THUMB */

	MOV	r1, r0			/* r1 = timeout */
	LDMFD	sp!, {r0,r2,lr}		/* restore r0,lr/flatten stack */
	B	FUNC(semTake)		/* go again */

	/* NEVER FALL THROUGH */

semQPutFail:
	BL	FUNC(windExit)		/* KERNEL EXIT */
	MOV	r0, #ERROR		/* return ERROR */
	ADD	sp, sp, #8		/* strip stack */
	LDMFD	sp!, {pc}		/* return */

/******************************************************************************/

#ifdef WV_INSTRUMENTATION

        /* windview instrumentation - BEGIN
         * semTake level 2 (task transition state event)
         */

instrumentSemQPut:

        LDR	r2, L$_wvEvtClass	/* is instrumentation on? */
	LDR	r2, [r2]
        AND	r2, r2, #WV_CLASS_2_ON	
        TEQS	r2, #WV_CLASS_2_ON	
	BNE	trgSemQPutEvt		/* branch if not */

        LDR	r12, L$__func_evtLogM1	/* call event log routine */
	LDR	r12, [r12]
	TEQS	r12, #0
	BEQ	trgSemQPutEvt		/* branch if nothing to call */

	STMFD	sp!, {r0,r1,r3,lr}	/* save regs */
	MOV	r1, r0			/* r1 = semId */
	LDR	r0, L$_EVENT_OBJ_SEMTAKE /* r0 = event id */

#if	(ARM_THUMB)
	BL	FUNC(arm_call_via_r12)	/* call function */
#else
	MOV	lr, pc			/* call function */
	MOV	pc, r12
#endif	/* ARM_THUMB */

	LDMFD	sp!, {r0,r1,r3,lr}	/* restore regs */

trgSemQPutEvt: 
        LDR	r2, L$_trgEvtClass	/* is triggering on? */
	LDR	r2, [r2]
	LDR	r12, L$_TRG_CLASS_2_ON
        AND	r2, r2, r12
        TEQS	r2, r12
	BNE	resumeSemQPut		/* branch if not */

	STMFD	sp!, {r0,r1,r3,lr}	/* save regs */

	/*
	 * There are 8 parameters to the trgCheck function:
	 * r0	 <- eventId
	 * r1 	 <- index = TRG_CLASS2_INDEX
	 * r2 	 <- obj = semId
	 * r3 	 <- arg1 (NULL - unused)
	 * stack <- arg2 (NULL - unused)
	 * stack <- arg3 (NULL - unused)
	 * stack <- arg4 (NULL - unused)
	 * stack <- arg5 (NULL - unused)
	 */

	MOV	r2, #0
	MOV	r3, #0
	STMFD	sp!, {r2,r3}		/* push 2 dummy args */
	STMFD	sp!, {r2,r3}		/* push 2 dummy args .. again */
						/* r3 = NULL from above */
	MOV	r2, r0				/* r2 = semId */
	MOV	r1, #TRG_CLASS2_INDEX		/* r1 = Class */
	LDR	r0, L$_EVENT_OBJ_SEMTAKE 	/* r0 = event type */

	LDR	r12,L$__func_trgCheck 		/* trigCheck routine */

#if	(ARM_THUMB)
	LDR	r12, [r12]			/* get function address */
	BL	FUNC(arm_call_via_r12)		/* and call it */
#else
	MOV	lr, pc				/* call function */
	LDR	pc, [r12]
#endif	/* ARM_THUMB */

	ADD	sp, sp, #16		/* strip parameters from stack */
	LDMFD	sp!, {r0,r1,r3,lr}	/* restore regs */

	B	resumeSemQPut

        /* windview instrumentation - END */
#endif	/* WV_INSTRUMENTATION */

/******************************************************************************/

semIsInvalidUnlock:
	/*
	 * r0-> semaphore
	 * r3 = previous cpsr
	 * lr = return address
	 * interrupts are locked
	 */

	MSR	cpsr, r3		/* UNLOCK INTERRUPTS */
	B	FUNC(semInvalid)		/* let C function do work */

/*******************************************************************************
*
* semOTake - VxWorks 4.x semTake
*
* Optimized version of semOTake.  This inserts the necessary argument of
* WAIT_FOREVER for semBTake.

* STATUS semOTake
*	(
*	SEM_ID semId
*	)

*/

FUNC_LABEL(semOTake)
	MOV	r1, #WAIT_FOREVER
	B	FUNC(semBTake)

/*******************************************************************************
*
* semClear - VxWorks 4.x semClear
*
* Optimized version of semClear.  This inserts the necessary argument of
* NO_WAIT for semBTake.

* STATUS semClear
*	(
*	SEM_ID semId
*	)

*/

FUNC_LABEL(semClear)
	MOV	r1, #NO_WAIT
	B	FUNC(semBTake)

#endif /* ! semALib_PORTABLE */
