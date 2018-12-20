/* workQALib.s - internal VxWorks kernel work queue assembler library */

/* Copyright 1996-1998 Wind River Systems, Inc. */

/*
modification history
--------------------
01h,17oct01,t_m  convert to FUNC_LABEL:
01g,11oct01,jb  Enabling removal of pre-pended underscores for new compilers
                 (Diab/Gnu elf)
01f,25feb99,nps  remove obsolete scrPad references.
01e,10aug98,pr   commenting out WV code. To be removed after porting WV20 
01d,27feb98,cdp  rewritten and instrumented.
01c,27oct97,kkk  took out "***EOF***" line from end of file.
01b,19may97,jpd  Amalgamated into VxWorks.
01a,08jul96,apl  Written.
*/

/*
DESCRIPTION
This module contains internals to the VxWorks kernel.
These routines have been coded in assembler because they are optimized for
performance.

The work queue is single reader, multiple writer, so interrupts must be
locked when writing into the ring but, because the reader can never
interrupt the writer, interrupts need only be locked while actually
advancing the write queue index.

Note that workQAdd0/1/2 all bump workQWriteIx even if the workQ is
overflowing.  This differs from what the 68K code does but is the
same as the portable code.
*/

#define _ASMLANGUAGE
#include "vxWorks.h"
#include "asm.h"
#include "private/workQLibP.h"
#include "arch/arm/arm.h"

	.data
	.globl	FUNC(copyright_wind_river)
	.long	FUNC(copyright_wind_river)

#if (defined(PORTABLE))
#define workQALib_PORTABLE
#endif

#ifndef PORTABLE

/* globals */

	.globl	FUNC(workQAdd0)	/* Add function to workQ */
	.globl	FUNC(workQAdd1)	/* Add function and 1 arg to workQ */
	.globl	FUNC(workQAdd2)	/* Add function and 2 args to workQ */
	.globl	FUNC(workQDoWork)	/* Do all queued work in a workQ */


/* externals */

	.extern	FUNC(workQPanic)
	.extern	FUNC(errno)
	.extern	FUNC(pJobPool)
	.extern	FUNC(workQReadIx)
	.extern	FUNC(workQWriteIx)
	.extern	FUNC(workQIsEmpty)

	.text
	.balign	4

/******************************************************************************/

/*
 * PC-relative-addressable pointers - LDR Rn,=sym was (is?) broken
 * note "_" after "$" to stop preprocessor performing substitution
 */

L$_errno:
	.long	FUNC(errno)
L$_pJobPool:
	.long	FUNC(pJobPool)
L$_workQReadIx:
	.long	FUNC(workQReadIx)
L$_workQWriteIx:
	.long	FUNC(workQWriteIx)
L$_workQIsEmpty:
	.long	FUNC(workQIsEmpty)

/*******************************************************************************
*
* workQAdd0 - Add a function with no arguments to the work queue.
*
* RETURNS: N/A
*
* NOMANUAL

* void workQAdd0
*	(
*	FUNCPTR	func	/@ function to invoke @/
*	)

*/

FUNC_LABEL(workQAdd0)

	LDR	r12, L$_workQWriteIx	/* r12-> workQWriteIx */

	MRS	r3, cpsr		/* LOCK INTERRUPTS */
	ORR	r2, r3, #I_BIT
	MSR	cpsr, r2

	/* get write index and advance it (4 words per entry) */

	LDRB	r1, [r12]		/* r1 = write index */
	ADD	r2, r1, #4		/* r2 = advanced write index */
	STRB	r2, [r12]		/* update write index */

	/* check for overflow */

	AND	r2, r2, #0xFF		/* mask to byte for comparison */
	LDR	r12, L$_workQReadIx	/* r12-> workQReadIx */
	LDRB	r12, [r12]		/* r12 = read index */
	TEQS	r12, r2
	BLEQ	FUNC(workQPanic)		/* overwrites LR but doesn't return */

	/* no overflow - put job in pool */

	MSR	cpsr, r3		/* UNLOCK INTERRUPTS */
	LDR	r12, L$_workQIsEmpty	/* r12-> workQIsEmpty */
	MOV	r3, #FALSE		/* workQIsEmpty := FALSE */
	STR	r3, [r12]

	LDR	r12, L$_pJobPool	/* r12-> pJobPool */
	STR	r0, [r12, r1, LSL #2]	/* put fnptr in pool */

	MOV	pc, lr

/*******************************************************************************
*
* workQAdd1 - Add a function with one argument to the work queue.
*
* RETURNS: N/A
*
* NOMANUAL

* void workQAdd1
*	(
*	FUNCPTR	func,	/@ function to invoke @/
*	int	arg1	/@ parameter one to function @/
*	)

*/

FUNC_LABEL(workQAdd1)

	LDR	r12, L$_workQWriteIx	/* r12-> workQWriteIx */

	MRS	r3, cpsr		/* LOCK INTERRUPTS */
	ORR	r2, r3, #I_BIT
	MSR	cpsr, r2

	/* get write index and advance it (4 words per entry) */

	LDRB	r2, [r12]		/* r2 = write index */
	ADD	r2, r2, #4		/* r2 = advanced write index */
	STRB	r2, [r12]		/* update write index */

	/* check for overflow */

	AND	r2, r2, #0xFF		/* mask to byte for comparison */
	LDR	r12, L$_workQReadIx	/* r12-> workQReadIx */
	LDRB	r12, [r12]		/* r12 = read index */
	TEQS	r12, r2
	BLEQ	FUNC(workQPanic)		/* overwrites LR but doesn't return */

	/* no overflow - put job in pool */

	MSR	cpsr, r3		/* UNLOCK INTERRUPTS */
	LDR	r12, L$_workQIsEmpty	/* r12-> workQIsEmpty */
	MOV	r3, #FALSE		/* workQIsEmpty := FALSE */
	STR	r3, [r12]

	LDR	r12, L$_pJobPool	/* r12-> pJobPool */
	SUB	r2, r2, #4		/* step back index */
	AND	r2, r2, #0xFF		/* mask to byte */
	ADD	r12, r12, r2, LSL #2
	STMIA	r12, {r0,r1}		/* put fnptr/arg in pool */

	MOV	pc, lr

/*******************************************************************************
*
* workQAdd2 - Add a function with two arguments to the work queue.
*
* RETURNS: N/A
*
* NOMANUAL

* void workQAdd2
*	(
*	FUNCPTR	func,	/@ function to invoke @/
*	int	arg1,	/@ parameter one to function @/
*	int	arg2	/@ parameter two to function @/
*	)

*/

FUNC_LABEL(workQAdd2)

	STMFD	sp!, {lr}		/* save link */

	LDR	r12, L$_workQWriteIx	/* r12-> workQWriteIx */

	MRS	r3, cpsr		/* LOCK INTERRUPTS */
	ORR	lr, r3, #I_BIT
	MSR	cpsr, lr

	/* get write index and advance it (4 words per entry) */

	LDRB	lr, [r12]		/* lr = write index */
	ADD	lr, lr, #4		/* lr = advanced write index */
	STRB	lr, [r12]		/* update write index */

	/* check for overflow */

	AND	lr, lr, #0xFF		/* mask to byte for comparison */
	LDR	r12, L$_workQReadIx	/* r12-> workQReadIx */
	LDRB	r12, [r12]		/* r12 = read index */
	TEQS	r12, lr
	BLEQ	FUNC(workQPanic)		/* overwrites LR but doesn't return */

	/* no overflow - put job in pool */

	MSR	cpsr, r3		/* UNLOCK INTERRUPTS */
	LDR	r12, L$_workQIsEmpty	/* r12-> workQIsEmpty */
	MOV	r3, #FALSE		/* workQIsEmpty := FALSE */
	STR	r3, [r12]

	LDR	r12, L$_pJobPool	/* r12-> pJobPool */
	SUB	lr, lr, #4		/* step back index */
	AND	lr, lr, #0xFF		/* mask to byte */
	ADD	r12, r12, lr, LSL #2
	STMIA	r12, {r0-r2}		/* put fnptr/args in pool */

	LDMFD	sp!, {pc}

/*******************************************************************************
*
* workQDoWork - perform all the work queued in the kernel work queue
*
* This routine empties all the deferred work in the work queue.  The global
* variable errno is saved restored, so the work will not clobber it.
*
* RETURNS: N/A
*
* NOMANUAL

* void workQDoWork ()

*/

FUNC_LABEL(workQDoWork)

	/* check if work to do */

	LDR	r2, L$_workQReadIx	/* r2-> workQReadIx */
	LDR	r3, L$_workQWriteIx	/* r3-> workQWriteIx */
	LDRB	r0, [r2]		/* r0 = workQReadIx */
	LDRB	r1, [r3]		/* r1 = workQWriteIx */
	TEQS	r0, r1			/* read index == write index? */
	MOVEQ	pc, lr			/* quick return if no work */

	/* work to do - save regs and set up "static" values */

	STMFD	sp!, {r4-r8,lr}

	MOV	r4, r2			/* r4-> workQReadIx */
	MOV	r5, r3			/* r5-> workQWriteIx */

	LDR	r12, L$_errno		/* save errno */
	LDR	r6, [r12]		/* r6 = errno */

	LDR	r7, L$_pJobPool		/* r7-> pJobPool */
	LDR	r8, L$_workQIsEmpty	/* r8-> workQIsEmpty */

L0_workQDoWork:
	/*
	 * r0 = workQReadIx
	 * r1 = workQWriteIx
	 * r4-> workQReadIx
	 * r5-> workQWriteIx
	 * r6 = errno
	 * r7-> pJobPool
	 * r8-> workQIsEmpty
	 */

	ADD	r12, r0, #4		/* bump read index - entry is 4 words */
	STRB	r12, [r4]		/* update read index before calling fn*/

	ADD	r12, r7, r0, LSL #2	/* r12-> job */
	LDMIB	r12, {r0,r1}		/* get args */
	MOV	lr, pc			/* set link */
	LDR	pc, [r12]		/* call function */

	/* set workQIsEmpty := TRUE before checking indices */

	MOV	r0, #TRUE
	STR	r0, [r8]

	/* check if more to do */

	LDRB	r0, [r4]		/* r0 = workQReadIx */
	LDRB	r1, [r5]		/* r1 = workQWriteIx */
	TEQS	r0, r1			/* read index == write index? */
	BNE	L0_workQDoWork

	/* restore errno */

	LDR	r12, L$_errno
	STR	r6, [r12]
	LDMFD	sp!, {r4-r8, pc}

#endif /* ! workQALib_PORTABLE */
