/* semCALib.s - VxWorks counting semaphore assembler library */

/* Copyright 1996-2001 Wind River Systems, Inc. */

/*
modification history
--------------------
01h,12mar02,m_h  semTake must return error if called from ISR (74202)
01g,30oct01,pcm  added VxWorks semaphore events
01f,17oct01,t_m  convert to FUNC_LABEL:
01e,11oct01,jb  Enabling removal of pre-pended underscores for new compilers
                 (Diab/Gnu elf)
01d,12feb98,cdp  rewritten with instrumentation work.
01c,27oct97,kkk  took out "***EOF***" line from end of file.
01b,27may97,jpd  Amalgamated into VxWorks.
01a,09jul96,ams  Written.
*/

/*
DESCRIPTION
This library provides the interface to VxWorks counting
semaphores.  Counting semaphores are useful for guarding multiple
instances of a resource.
*/

#define _ASMLANGUAGE
#include "vxWorks.h"
#include "arch/arm/arm.h"
#include "private/semLibP.h"

	.data
	.globl	FUNC(copyright_wind_river)
	.long	FUNC(copyright_wind_river)

#if (defined(PORTABLE))
#define semCALib_PORTABLE
#endif

#ifndef semCALib_PORTABLE

/* globals */

	.global	FUNC(semCGive)	/* give a counting semaphore */
	.global	FUNC(semCTake)	/* take a counting semaphore */

/* externals */

	.extern	FUNC(intCnt)
	.extern	FUNC(semClass)
	.extern	FUNC(semInvalid)
	.extern	FUNC(semQGet)
	.extern	FUNC(semQPut)
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

L$_intCnt:
	.long	FUNC(intCnt)
L$_semClass:
	.long	FUNC(semClass)
L$_errno:
	.long	FUNC(errno)

#ifdef WV_INSTRUMENTATION
L$_semInstClass:
	.long	FUNC(semInstClass)
#endif

/*******************************************************************************
*
* semCGive - give a counting semaphore
*
* Gives the semaphore.  If a higher priority task has already taken
* the semaphore (so that it is now pended waiting for it), that task
* will now become ready to run, and preempt the task that does the semGive().
* If the semaphore is already full (it has been given but not taken) this
* call is essentially a no-op.
*
* RETURNS: OK, or ERROR if the semaphore ID is invalid.

* STATUS semCGive
*	(
*	SEM_ID semId	/@ semaphore ID to give @/
*	)

*/

FUNC_LABEL(semCGive)

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
	BNE	semIsInvalidUnlock	/* branch if invalid */

	/* semaphore is valid */

	LDR	r1, [r0, #SEM_Q_HEAD]	/* test semaphore queue head */
	TEQS	r1, #0
	BNE	FUNC(semQGet)		/* if not empty, get from Q */

	LDR	r1, [r0, #SEM_STATE]	/* increment count */
	ADD	r1, r1, #1		/* A state change has occurred */
	STR	r1, [r0, #SEM_STATE]

	LDR	r12, [r0, #SEM_EVENTS_TASKID]
	TEQS	r12, #0			/* Is semId->events.taskId NULL ? */

	BNE	FUNC(semEvRsrcSend)	/* Branch if not NULL */

	MSR	cpsr, r3		/* UNLOCK INTERRUPTS */
	MOV	r0, #OK			/* Return OK */
	MOV	pc, lr

	/* NEVER FALL THROUGH */

/*******************************************************************************
*
* semCTake - take a counting semaphore
*
* Takes the semaphore.  If the semaphore is empty, i.e., it has not been given
* since the last semTake() or semInit(), this task will become pended until
* the semaphore becomes available by some other task doing a semGive()
* of it.  If the semaphore is already available, this call will empty
* the semaphore, so that no other task can take it until this task gives
* it back, and this task will continue running.
*
* This routine may not be used from interrupt level.
* In this case it sets errno to S_intLib_NOT_ISR_CALLABLE and returns ERROR
*
* RETURNS: OK, or ERROR if the semaphore ID is invalid.

* STATUS semCTake
*	(
*	SEM_ID	semId,		/@ semaphore id to take @/
*	int	timeout		/@ timeout in ticks @/
*	)

*/

FUNC_LABEL(semCTake)

	/* check if called from ISR */

	LDR	r2, L$_intCnt		/* restrict ISR use */
	LDR	r2, [r2]
	TEQS	r2, #0
	BNE	FUNC(semIntRestrict)	/* if ISR, let C function do the work */

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
	BNE	semIsInvalidUnlock	/* branch if invalid */

	/* semaphore is valid */

	LDR	r12, [r0, #SEM_STATE]	/* test count */
	TEQS	r12, #0
	BEQ	FUNC(semQPut)		/* if sem is owned, block */

	SUB	r12, r12, #1		/* decrement count */
	STR	r12, [r0, #SEM_STATE]

	MSR	cpsr, r3		/* UNLOCK INTERRUPTS */
	MOV	r0, #OK			/* return OK */
	MOV	pc, lr

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

#endif /* ! semCALib_PORTABLE */
