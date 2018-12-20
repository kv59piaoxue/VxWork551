/* workQALib.s - internal VxWorks kernel work queue assembler library */

/* Copyright 1984-2000 Wind River Systems, Inc. */
	.data
	.globl	_copyright_wind_river
	.long	_copyright_wind_river

/*
modification history
--------------------
01c,15jun00,dh   T2/Coldfire merge.
01a,17mar00,dra  Created from T1.0.1 ColdFire and T2 m68k ports.
*/

/*
DESCRIPTION
This module contains internals to the VxWorks kernel.
These routines have been coded in assembler because they are optimized for
performance.
*/

#define _ASMLANGUAGE
#include "vxWorks.h"
#include "asm.h"
#include "private/workQLibP.h"
#include "private/eventP.h"

#ifndef PORTABLE

	/* globals */

	.globl	_workQAdd0		/* add function to workQ */
	.globl	_workQAdd1		/* add function and 1 arg to workQ */
	.globl	_workQAdd2		/* add function and 2 args to workQ */
	.globl	_workQDoWork		/* do all queued work in a workQ */

	.text
	.even

/*******************************************************************************
*
* workQOverflow - work queue has overflowed so call workQPanic ()
*
* NOMANUAL
*/

workQOverflow:					/* leave interrupts locked */
	jsr	_workQPanic			/* panic and never return */

/*******************************************************************************
*
* workQAdd0 - add a function with no argument to the work queue
*
* NOMANUAL

* void workQAdd0
*     (
*     FUNCPTR func,	/@ function to invoke @/
*     )

*/

_workQAdd0:
	movel	d2,a7@-
	clrl	d0
	movew	sr,d1				/* save old sr */
	movew	_intLockIntSR,d2		/* LOCK INTERRUPTS */
	movew	d2,sr
	moveb	_workQWriteIx,d0		/* get write index into d0 */
	addql	#4,d0				/* advance write index */
	clrl	d2
	moveb	_workQReadIx,d2			/* get read index */
	cmpl	d2,d0				/* overflow */
	jeq 	workQOverflow			/* panic if overflowed */
	moveb	d0,_workQWriteIx		/* update write index */
	subql	#4,d0				/* d0 indexes job */
	movew	d1,sr				/* UNLOCK INTERRUPTS */
	clrl	_workQIsEmpty			/* work queue isn't empty */
	lea	_pJobPool,a0			/* get the start of job pool */
	lsll	#2,d0				/* scale d0 by 4 */
	movel	a7@+,d2
	movel	a7@(0x4),d1			/* move the function to pool */
	movel	d1,a0@(JOB_FUNCPTR,d0:l)

	rts					/* we're done */

/*******************************************************************************
*
* workQAdd1 - add a function with one argument to the work queue
*
* NOMANUAL

* void workQAdd1
*     (
*     FUNCPTR func,	/@ function to invoke @/
*     int arg1		/@ parameter one to function @/
*     )

*/

_workQAdd1:
	movel	d2,a7@-
	clrl	d0				/* clear d0 */
	movew	sr,d1				/* save old sr */
	movew	_intLockIntSR,d2		/* LOCK INTERRUPTS */
	movew	d2,sr
	moveb	_workQWriteIx,d0		/* get write index into d0 */
	addql	#4,d0				/* advance write index */
	clrl	d2
	moveb	_workQReadIx,d2			/* get read index */
	cmpl	d2,d0				/* overflow */
	jeq 	workQOverflow			/* panic if overflowed */
	moveb	d0,_workQWriteIx		/* update write index */
	subql	#4,d0				/* d0 indexes job */
	movew	d1,sr				/* UNLOCK INTERRUPTS */
	clrl	_workQIsEmpty			/* work queue isn't empty */
	lea	_pJobPool,a0			/* get the start of job pool */
	lsll	#2,d0				/* scale d0 by 4 */
	movel	a7@+,d2
	movel	a7@(0x4),d1			/* move the function to pool */
	movel	d1,a0@(JOB_FUNCPTR,d0:l)
	movel	a7@(0x8),d1			/* move the argument to pool */
	movel	d1,a0@(JOB_ARG1,d0:l)
	rts					/* we're done */

/*******************************************************************************
*
* workQAdd2 - add a function with two arguments to the work queue
*
* NOMANUAL

* void workQAdd2
*     (
*     FUNCPTR func,	/@ function to invoke @/
*     int arg1,		/@ parameter one to function @/
*     int arg2		/@ parameter two to function @/
*     )

*/

_workQAdd2:
	movel	d2,a7@-
	clrl	d0				/* clear d0 */
	movew	sr,d1				/* save old sr */
	movew	_intLockIntSR,d2		/* LOCK INTERRUPTS */
	movew	d2,sr
	moveb	_workQWriteIx,d0		/* get write index into d0 */
	addql	#4,d0				/* advance write index */
	clrl	d2
	moveb	_workQReadIx,d2			/* get read index */
	cmpl	d2,d0				/* overflow */
	movew   sr,d1                           /* save old sr */
	jeq	workQOverflow			/* panic if overflowed */
	moveb	d0,_workQWriteIx		/* update write index */
	subql	#4,d0				/* d0 indexes job */
	movew	d1,sr				/* UNLOCK INTERRUPTS */
	clrl	_workQIsEmpty			/* work queue isn't empty */
	lea	_pJobPool,a0			/* get the start of job pool */
	lsll	#2,d0				/* scale d0 by 4 */
	movel	a7@+,d2
	movel	a7@(0x4),d1			/* move the function to pool */
	movel	d1,a0@(JOB_FUNCPTR,d0:l)
	movel	a7@(0x8),d1			/* move the argument to pool */
	movel	d1,a0@(JOB_ARG1,d0:l)
	movel	a7@(0xc),d1			/* move the argument to pool */
	movel	d1,a0@(JOB_ARG2,d0:l)
	rts					/* we're done */

/*******************************************************************************
*
* workQDoWork - perform all the work queued in the kernel work queue
*
* This routine empties all the deferred work in the work queue.  The global
* variable errno is saved restored, so the work will not clobber it.
* The work routines may be C code, and thus clobber the volatile registers
* d0,d1,a0, or a1.  This routine avoids using these registers.
*
* NOMANUAL

* void workQDoWork ()

*/

_workQDoWork:
	movel	_errno,a7@-			/* push _errno */

	clrl	d0
	moveb	_workQReadIx,d0			/* load read index */
	clrl	d1
	moveb	_workQWriteIx,d1
	cmpl	d1,d0				/* if readIndex != writeIndex */
	jeq 	workQNoMoreWork			/* more work to be done */

workQMoreWork:
	clrl	d1
	moveb	_workQReadIx,d1
	addql	#4,d1
	moveb	d1,_workQReadIx			/* increment readIndex */
	lea	_pJobPool,a0		 	/* base of job pool into a0 */
	andl	#0xff,d0			/* mask noise in upper bits */
	lsll	#2,d0				/* scale d0 by 4 */
	movel	a0@(JOB_ARG2,d0:l),a7@-		/* push arg2 */
	movel	a0@(JOB_ARG1,d0:l),a7@-		/* push arg1 */
	movel	a0@(JOB_FUNCPTR,d0:l),a1	/* load pointer to function */
	jsr	a1@				/* do the work routine */
	addql	#0x8,a7				/* clean up stack */

	movew   sr,d1
	movew   d1,a7@-                 	/* save old sr */
	andl	#0xf8ff,d1
	movew	_intLockMask,d0
	orl	d0,d1
        movew	a7@+,d1
        movew	d1,sr				/* UNLOCK INTERRUPTS */
	movel	#1,d0				/* set boolean before test! */
	movel	d0,_workQIsEmpty		/* set boolean before test! */
	clrl	d0
	moveb	_workQReadIx,d0			/* load the new read index */
	clrl	d1
	moveb	_workQWriteIx,d1		/* load the write index */
	cmpl	d1,d0				/* if readIndex !=writeIndex */
	jne 	workQMoreWork			/* more work to be done */

workQNoMoreWork:
	movel	a7@+,_errno			/* pop _errno */
	rts					/* return to caller */

#endif	/* !PORTABLE */
