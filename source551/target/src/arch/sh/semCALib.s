/* semCALib.s - internal VxWorks counting semaphore assembler library */

/* Copyright 1995-2001 Wind River Systems, Inc. */

	.data
	.global	_copyright_wind_river
	.long	_copyright_wind_river

/*
modification history
--------------------
01q,18dec01,hk   made semCTake jump to semIntRestrict if intCnt > 0 (SPR#72119).
01p,24oct01,aeg  added VxWorks events support.
01o,30aug00,hk   change intLockTaskSR to intLockSR.
		 minor pipeline optimization in inlined intLock().
		 delete #if FALSE clause in semCTake.
01n,21aug00,hk   merge SH7729 to SH7700. merge SH7410 and SH7040 to SH7600.
01m,28mar00,hk   added .type directive to function names.
01l,17mar00,zl   made use of alignment macro _ALIGN_TEXT
01k,16jul98,st   added SH7750 support.
01k,12may98,jmc  added support for SH-DSP and SH3-DSP.
01j,09jul97,hk   deleted SemInstClass_0, use SemInstClass.
01i,01may97,hk   made windview instrumentation conditionally compiled.
01h,28apr97,hk   changed SH704X to SH7040.
01i,16mar97,hms  changed symbol reference.
01h,05mar97,hms  added WindView support.
01g,03mar97,hk   changed XFFFFFF0F to XFF0F.
01f,26sep96,hk   fixed [SPR: #H1005] bug in inlined intLock() for SH7700.
01e,24jul96,hk   added bank register support for SH7700 by inlining intLock()
		 to _semCGive/_semCTake. reviewed #if/#elif/#endif readability.
01d,07jun96,hk   added support for SH7700.
01g,09aug95,sa   made SH to use the optimized version for instrumented kernel.
01e,01aug95,sa   optimized for WindView.
01c,22may95,hk   reworked on _semCGive, semIsInvalidUnlock, _semCTake.
01b,19apr95,hk   mostly optimized.
01a,18apr95,hk   written based on mc68k-01b.
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
#include "private/taskLibP.h"
#include "private/semLibP.h"
#include "eventLib.h"			/* EVENTS_SEND_ONCE */
#include "semLib.h"			/* SEM_EVENTSEND_ERR_NOTIFY */

#ifndef PORTABLE

	/* globals */

	.global	_semCGive		/* optimized counting semaphore give */
	.global	_semCTake		/* optimized counting semaphore take */

	.text

/*******************************************************************************
*
* semCGive - optimized give of a counting semaphore
*

* STATUS semCGive
*     (
*     SEM_ID semId		/@ semaphore id to give @/
*     )

*/
	.align	_ALIGN_TEXT
	.type	_semCGive,@function

_semCGive:				/* r4: semId */
#if (CPU==SH7600 || CPU==SH7000)
	mov.l	IntLockSR,r1;
	mov.l	@r1,r0;
	stc	sr,r7			/* r7: old sr */
	ldc	r0,sr			/* LOCK INTERRUPTS */
#else
	mov.l	IntLockMask,r2;
	mov.w	XFF0F,r1;		/* r1: 0xffffff0f */
	mov.l	@r2,r0;			/* r0: 0x000000m0 */
	stc	sr,r7			/* r7: 0x?___?_?_ */
	and	r7,r1			/* r1: 0x?___?_0_ */
	or	r0,r1			/* r1: 0x?___?_m_ */
	ldc	r1,sr			/* LOCK INTERRUPTS */
#endif
	mov.l	@r4,r1;
	mov.l	SemClass,r0;		/* r0: &_semClass */
	cmp/eq  r0,r1			/* check validity */

#ifdef	WV_INSTRUMENTATION
 
	bt	objOkCGive
 
	/* windview - check the validity of instrumented class */
 
	mov.l	SemInstClass,r0;	/* r0: &_semInstClass */
	cmp/eq	r0,r1			/* check validity */
	bf	semIsInvalidUnlock	/* invalid semaphore */
objOkCGive:

#else
	bf	semIsInvalidUnlock	/* invalid semaphore */
#endif

	mov.l	@(SEM_Q_HEAD,r4),r0;
	tst	r0,r0			/* test semaphore queue head */
	bf	semQGet			/* if not empty, get from q */

	mov.l	@(SEM_STATE,r4),r1;
	add	#1,r1
	mov.l	r1,@(SEM_STATE,r4)	/* increment count */

	/* determine if VxWorks events need to be sent */

	mov.l	@(SEM_EVENTS_TASKID,r4),r6;
	tst	r6,r6			/* semId->events.taskId = 0? */
	bt	semCGiveReturnOK

	/* Events need to be sent; set kernelState */

	mov.l	KernelState,r1;
	mov	#1,r0;
	mov.l	r0,@r1;			/* KERNEL ENTER */

	ldc	r7,sr			/* UNLOCK INTERRUPTS */

	mov.l	r8,@-sp			/* push r8 (non-volatile) */
	mov.l	r9,@-sp			/* push r9 (non-volatile) */
	sts.l	pr,@-sp			/* push return address */

	mov.l	Errno,r1;
	mov.l	EventRsrcSend,r0;
	mov	r4,r8			/* r8: semId */
	mov.l	@r1,r9;			/* r9: errno before eventRsrcSend() */

	/* eventRsrcSend (semId->events.taskId, semId->events.registered) */

	mov.l	@(SEM_EVENTS_REGISTERED,r8),r5;
	jsr	@r0
	mov	r6,r4;			/* transfer taskId parm */

	mov	#0,r6;			/* r6 = retStatus = OK */
	cmp/eq	#0,r0			/* eventRsrcSend() status = OK? */
	bt	semCGiveCheckSendOnce   /* yes -> check EVENTS_SEND_ONCE */

	/* NULL out the semId->events.taskId field if eventRsrcSend() failed */

	mov.l	r6,@(SEM_EVENTS_TASKID,r8);

	/* return ERROR only if SEM_EVENTSEND_ERR_NOTIFY option set */

	mov.b   @(SEM_OPTIONS,r8),r0;
	tst	#SEM_EVENTSEND_ERR_NOTIFY,r0;	/* option bit set? */
	bt	semCGiveWindExit		/* no -> windExit() */

	/* load S_eventLib_EVENTSEND_FAILED errno into oldErrno register */

	mov.l   X860004,r9;
	bra	semCGiveWindExit;
	mov	#-1,r6			/* remember to return ERROR */


semCGiveCheckSendOnce:

        /*
	 * NULL out the semId->events.taskId field if the EVENTS_SEND_ONCE
	 * events option is set.
	 */

	mov	#SEM_EVENTS_OPTIONS,r0;
	mov.b	@(r0,r8),r0;
	tst	#EVENTS_SEND_ONCE,r0	/* option bit set? */
	bt	semCGiveWindExit
	mov.l   r6,@(SEM_EVENTS_TASKID,r8);

	/* fall through to semCGiveWindExit */

semCGiveWindExit:

	mov.l	WindExit,r3
	jsr	@r3			/* call windExit() */
	mov	r6,r8			/* r8: retStatus */

        /* restore errno and return STATUS (in r0) */

	mov.l	Errno,r3;
	mov     r8,r0 			/* restore retStatus */
	mov.l	r9,@r3;			/* old errno -> _errno */

	lds.l	@sp+,pr			/* pop return address */
	mov.l	@sp+,r9			/* pop r9 */
	rts;
	mov.l	@sp+,r8			/* pop r8 */


	/* unlock interrupts and return STATUS of OK */

semCGiveReturnOK:
	ldc	r7,sr			/* UNLOCK INTERRUPTS */
	rts;
	mov	#0,r0;			/* return (OK) */

semQGet:
	mov.l	SemQGet,r0;
	jmp	@r0;			/* r4: semId */
	nop				/* r7: old sr */

			.align	2
SemQGet:		.long	_semQGet
KernelState:		.long	_kernelState
Errno:			.long	_errno
EventRsrcSend:		.long	_eventRsrcSend
WindExit:		.long	_windExit
X860004:		.long	0x860004    /* S_eventLib_EVENTSEND_FAILED */

/*******************************************************************************
*
* semIsInvalidUnlock - unlock interupts and call semInvalid ().
*/
	.align	_ALIGN_TEXT
	.type	semIsInvalidUnlock,@function

					/* r7: old sr */
semIsInvalidUnlock:			/* r4: semId */
	mov.l	SemInvalid,r0;
#if (CPU==SH7600 || CPU==SH7000)
	jmp	@r0;
	ldc	r7,sr
#else
	ldc	r7,sr			/* UNLOCK INTERRUPTS */
	jmp	@r0;			/* let C rtn do work and rts */
	nop
#endif

semCIntRestrict:
	mov.l	SemIntRestrict,r0;
	jmp	@r0;			/* let C do the work */
	nop
			.align	2
SemInvalid:		.long	_semInvalid
SemIntRestrict:		.long	_semIntRestrict

/*******************************************************************************
*
* semCTake - optimized take of a counting semaphore
*

* STATUS semCTake
*     (
*     SEM_ID semId,		/@ semaphore id to take @/
*     int timeout		/@ timeout in ticks @/
*     )

*/
	.align	_ALIGN_TEXT
	.type	_semCTake,@function

_semCTake:				/* r4: semId, r5: timeout */
	mov.l	IntCnt,r3;
#if (CPU==SH7600 || CPU==SH7000)
	mov.l	IntLockSR,r1;
	mov.l	@r3,r3;
	mov.l	@r1,r0;
	cmp/pl	r3
	bt	semCIntRestrict
	stc	sr,r7			/* r7: old sr */
	ldc	r0,sr			/* LOCK INTERRUPTS */
#else
	mov.l	IntLockMask,r2;
	mov.l	@r3,r3;
	mov.w	XFF0F,r1;		/* r1: 0xffffff0f */
	cmp/pl	r3
	mov.l	@r2,r0;			/* r0: 0x000000m0 */
	bt	semCIntRestrict
	stc	sr,r7			/* r7: 0x?___?_?_ */
	and	r7,r1			/* r1: 0x?___?_0_ */
	or	r0,r1			/* r1: 0x?___?_m_ */
	ldc	r1,sr			/* LOCK INTERRUPTS */
#endif
	mov.l	@r4,r1;
	mov.l	SemClass,r0;		/* r0: &_semClass */
	cmp/eq  r0,r1			/* check validity */

#ifdef	WV_INSTRUMENTATION
 
	bt	objOkCTake
 
	/* windview - check the validity of instrumented class */
 
	mov.l	SemInstClass,r0;	/* r0: &_semInstClass */
	cmp/eq	r0,r1			/* check validity */
	bf	semIsInvalidUnlock	/* invalid semaphore */
objOkCTake:

#else
	bf	semIsInvalidUnlock	/* invalid semaphore */
#endif

	mov.l	@(SEM_STATE,r4),r1;
	tst	r1,r1			/* test count */
	bt	semQPut			/* if sem is owned we block */

	add	#-1,r1
	mov.l	r1,@(SEM_STATE,r4)	/* decrement count */
	ldc	r7,sr			/* UNLOCK INTERRUPTS */
	rts;
	mov	#0,r0			/* return OK */

semQPut:
	mov.l	SemQPut,r0;
	jmp	@r0;			/* r4: semId, r5: timeout */
	nop				/* r7: old sr */

			.align	2
IntCnt:			.long	_intCnt
SemClass:		.long	_semClass
#ifdef	WV_INSTRUMENTATION
SemInstClass:		.long	_semInstClass
#endif
SemQPut:		.long	_semQPut
#if (CPU==SH7600 || CPU==SH7000)
IntLockSR:		.long	_intLockTaskSR		/* intArchLib */
#else
IntLockMask:		.long	_intLockMask		/* intArchLib */
XFF0F:			.word	0xff0f
#endif

#endif	/* !PORTABLE */
