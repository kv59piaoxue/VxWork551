/* workQALib.s - internal VxWorks kernel work queue assembler library */

/* Copyright 1995-2000 Wind River Systems, Inc. */

	.data
	.global	_copyright_wind_river
	.long	_copyright_wind_river

/*
modification history
--------------------
01q,07jan01,hk   fix workQDoWork (same as SPR28648).
01p,30aug00,hk   merge intLockIntSR to intLockTaskSR.
		 confirm SR.DSP bit preservation in workQAdd[012].
01o,21aug00,hk   merge SH7729 to SH7700, SH7410 and SH7040 to SH7600. simplify
		 CPU conditionals. deleted FALSE clause in workQOverflow.
01n,28mar00,hk   added .type directive to function names.
01m,17mar00,zl   made use of alignment macro _ALIGN_TEXT
01l,07mar00,zl   deleted WindView section and removed obsolete scrPad.h.
01k,16jul98,st   added SH7750 support.
01k,08may98,jmc  added support for SH-DSP and SH3-DSP.
01j,09jul97,hk   optimized workQDoWork instrumentation code.
01i,08may97,hk   fixed constants alignment for WV_INSTRUMENTATION.
01h,01may97,hk   made windview instrumentation conditionally compiled.
01g,28apr97,hk   changed SH704X to SH7040.
01h,16mar97,hms  changed symbol reference.
01g,06mar97,hms  added WindView support.
01f,03mar97,hk   changed XFFFFFF0F to XFF0F.
01e,04oct96,hk   improved intLock code in workQAdd[012].
01d,26sep96,hk   fixed [SPR: #H1005] bug in inlined intLock() for SH7700.
01c,26jul96,hk   changed intLock sequence for SH7700 bank switching.
01d,09jun95,sa   use optimized for WindView.
01c,05jun95,sa   added PORTABLE for WindView.
01b,22may95,hk   optimized workQOverflow.
01a,12apr95,hk   written based on mc68k-01n.
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

#undef	PORTABLE
#ifndef PORTABLE

	/* globals */

	.global	_workQAdd0		/* add function to workQ */
	.global	_workQAdd1		/* add function and 1 arg to workQ */
	.global	_workQAdd2		/* add function and 2 args to workQ */
	.global	_workQDoWork		/* do all queued work in a workQ */

	.text

/*******************************************************************************
*
* workQOverflow - work queue has overflowed so call workQPanic ()
*
* NOMANUAL
*/
	.align	_ALIGN_TEXT
	.type	workQOverflow,@function

workQOverflow:					/* leave interrupts locked */
	mov.l	WorkQPanic,r0
	jmp	@r0;				/* panic and never return */
	nop

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
	.align	_ALIGN_TEXT
	.type	_workQAdd0,@function

_workQAdd0:
#if (CPU==SH7600 || CPU==SH7000)
	mov.l	IntLockSR,r1;		mov.l	WorkQWriteIx,r2;
	mov.l	@r1,r0;			mov.l	WorkQReadIx, r3;

	stc	sr,r7				/* save old sr */
	ldc	r0,sr				/* LOCK INTERRUPTS */
#else
	mov.l	IntLockMask,r1;		mov.l	WorkQWriteIx,r2;
	mov.l	@r1,r0;			mov.l	WorkQReadIx, r3;
						/* r0: 0x000000m0 */
	mov.w	XFF0F,r1			/* r1: 0xffffff0f */
	stc	sr,r7				/* r7: 0x?___?_?_ */
	and	r7,r1				/* r1: 0x?___?_0_ */
	or	r0,r1				/* r1: 0x?___?_m_ */
	ldc	r1,sr				/* LOCK INTERRUPTS */
#endif
	mov.b	@r2,r0;				/* get write index into r0 */
	mov.b	@r3,r1;				/* get read  index into r1 */
	extu.b	r0,r3				/* r3 indexes job */
	add	#4,r0				/* advance write index */
	mov.b	r0,@r2				/* update  write index */

	cmp/eq	r0,r1				/* overflow?           */
	bt	workQOverflow			/* panic if overflowed */

	ldc	r7,sr				/* UNLOCK INTERRUPTS */

	mov.l	WorkQIsEmpty,r0;
	mov	#0,r1
	mov.l	r1,@r0				/* work queue isn't empty */

	mov.l	PJobPool,r0;			/* get the start of job pool */
	shll2	r3				/* scale r3 by 4 */
	add	r0,r3
	rts;					/* we're done */
	mov.l	r4,@(JOB_FUNCPTR,r3)		/* move the function to pool */

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
	.align	_ALIGN_TEXT
	.type	_workQAdd1,@function

_workQAdd1:
#if (CPU==SH7600 || CPU==SH7000)
	mov.l	IntLockSR,r1;		mov.l	WorkQWriteIx,r2;
	mov.l	@r1,r0;			mov.l	WorkQReadIx, r3;

	stc	sr,r7				/* save old sr */
	ldc	r0,sr				/* LOCK INTERRUPTS */
#else
	mov.l	IntLockMask,r1;		mov.l	WorkQWriteIx,r2;
	mov.l	@r1,r0;			mov.l	WorkQReadIx, r3;
						/* r0: 0x000000m0 */
	mov.w	XFF0F,r1			/* r1: 0xffffff0f */
	stc	sr,r7				/* r7: 0x?___?_?_ */
	and	r7,r1				/* r1: 0x?___?_0_ */
	or	r0,r1				/* r1: 0x?___?_m_ */
	ldc	r1,sr				/* LOCK INTERRUPTS */
#endif
	mov.b	@r2,r0;				/* get write index into r0 */
	mov.b	@r3,r1;				/* get read  index into r1 */
	extu.b	r0,r3				/* r3 indexes job */
	add	#4,r0				/* advance write index */
	mov.b	r0,@r2				/* update  write index */

	cmp/eq	r0,r1				/* overflow?           */
	bt	workQOverflow			/* panic if overflowed */

	ldc	r7,sr				/* UNLOCK INTERRUPTS */

	mov.l	WorkQIsEmpty,r0;
	mov	#0,r1
	mov.l	r1,@r0				/* work queue isn't empty */

	mov.l	PJobPool,r0;			/* get the start of job pool */
	shll2	r3				/* scale r3 by 4 */
	add	r0,r3
	mov.l	r4,@(JOB_FUNCPTR,r3)		/* move the function to pool */
	rts;					/* we're done */
	mov.l	r5,@(JOB_ARG1,   r3)		/* move the argument to pool */

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

* INTERNAL
*	r7:	saved sr
*	r6:	argument2
*	r5:	argument1
*	r4:	function
*	r3:	WorkQReadIx, pJob
*	r2:	WorkQWriteIx
*/
	.align	_ALIGN_TEXT
	.type	_workQAdd2,@function

_workQAdd2:
#if (CPU==SH7600 || CPU==SH7000)
	mov.l	IntLockSR,r1;		mov.l	WorkQWriteIx,r2;
	mov.l	@r1,r0;			mov.l	WorkQReadIx, r3;

	stc	sr,r7				/* save old sr */
	ldc	r0,sr				/* LOCK INTERRUPTS */
#else
	mov.l	IntLockMask,r1;		mov.l	WorkQWriteIx,r2;
	mov.l	@r1,r0;			mov.l	WorkQReadIx, r3;
						/* r0: 0x000000m0 */
	mov.w	XFF0F,r1			/* r1: 0xffffff0f */
	stc	sr,r7				/* r7: 0x?___?_?_ */
	and	r7,r1				/* r1: 0x?___?_0_ */
	or	r0,r1				/* r1: 0x?___?_m_ */
	ldc	r1,sr				/* LOCK INTERRUPTS */
#endif
	mov.b	@r2,r0;				/* get write index into r0 */
	mov.b	@r3,r1;				/* get read  index into r1 */
	extu.b	r0,r3				/* r3 indexes job */
	add	#4,r0				/* advance write index */
	mov.b	r0,@r2				/* update  write index */

	cmp/eq	r0,r1				/* overflow?           */
	bt	workQOverflow			/* panic if overflowed */

	ldc	r7,sr				/* UNLOCK INTERRUPTS */

	mov.l	WorkQIsEmpty,r0;
	mov	#0,r1
	mov.l	r1,@r0				/* work queue isn't empty */

	mov.l	PJobPool,r0;			/* get the start of job pool */
	shll2	r3				/* scale r3 by 4 */
	add	r0,r3
	mov.l	r4,@(JOB_FUNCPTR,r3)		/* move the function to pool */
	mov.l	r5,@(JOB_ARG1,   r3)		/* move the argument to pool */
	rts;					/* we're done */
	mov.l	r6,@(JOB_ARG2,   r3)		/* move the argument to pool */

/*******************************************************************************
*
* workQDoWork - perform all the work queued in the kernel work queue
*
* This routine empties all the deferred work in the work queue.  The global
* variable errno is saved restored, so the work will not clobber it.
* The work routines may be C code, and thus clobber the volatile registers
* r0-r7.  This routine avoids using these registers in workQMoreWork loop.
*
* NOMANUAL

* void workQDoWork ()

* INTERNAL
*	r12:	&_pJobPool
*	r11:	_errno
*	r10:	WorkQIsEmpty
*	r9:	WorkQWriteIx
*	r8:	WorkQReadIx
*	r7:	_workQWriteIx
*	r6:	_workQReadIx
*	r5:	arg2
*	r4:	arg1
*	r3:	pJob
*/
	.align	_ALIGN_TEXT
	.type	_workQDoWork,@function

_workQDoWork:
	mov.l	r8, @-sp;		mov.l	r9, @-sp
	mov.l	WorkQReadIx, r8;	mov.l	WorkQWriteIx,r9;
	mov.b	@r8,r6;			mov.b	@r9,r7;
	cmp/eq	r6,r7
	bt	workQNoMoreWork

	mov.l	r10,@-sp;		mov.l	WorkQIsEmpty,r10;
	mov.l	r11,@-sp;		mov.l	Errno,r0;
	mov.l	r12,@-sp;		mov.l	@r0,r11;
	sts.l	pr, @-sp;		mov.l	PJobPool,r12;

workQMoreWork:
	extu.b	r6,r3			/* mask noise in upper bits */
	shll2	r3			/* scale r3 by 4            */
	add	r12,r3			/* add base of job pool     */

	add	#4,r6
	mov.b	r6,@r8			/* increment readIndex      */

	mov.l	@(JOB_FUNCPTR,r3),r0;	/* load pointer to function */
	mov.l	@(JOB_ARG1,   r3),r4;	/* set arg1                 */
	jsr	@r0;			/* do the work routine      */
	mov.l	@(JOB_ARG2,   r3),r5;	/* set arg2                 */

	/* set boolean before test! */
	mov	#1,r0
	mov.l	r0,@r10

	/* load new index */
	mov.b	@r8,r6;
	mov.b	@r9,r7;
	cmp/eq	r6,r7
	bf	workQMoreWork

	lds.l	@sp+,pr;		mov.l	Errno,r0;
	mov.l	@sp+,r12;		mov.l	r11,@r0
	mov.l	@sp+,r11
	mov.l	@sp+,r10
workQNoMoreWork:			/* return to caller */
	mov.l	@sp+,r9;		rts;
	mov.l	@sp+,r8


			.align	2
WorkQReadIx:		.long	_workQReadIx
WorkQWriteIx:		.long	_workQWriteIx
WorkQPanic:		.long	_workQPanic
WorkQIsEmpty:		.long	_workQIsEmpty
PJobPool:		.long	_pJobPool
Errno:			.long	_errno
#if (CPU==SH7600 || CPU==SH7000)
IntLockSR:		.long	_intLockTaskSR
#else
IntLockMask:		.long	_intLockMask
XFF0F:			.word	0xff0f
#endif

#endif	/* !PORTABLE */
