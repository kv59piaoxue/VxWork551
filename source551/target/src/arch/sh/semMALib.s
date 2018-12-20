/* semMALib.s - internal VxWorks mutex semaphore assembler library */

/* Copyright 1995-2001 Wind River Systems, Inc. */

	.data
	.global	_copyright_wind_river
	.long	_copyright_wind_river

/*
modification history
--------------------
01s,18dec01,hk   made semMTake jump to semIntRestrict if intCnt > 0 (SPR#72119).
01r,24oct01,aeg  added VxWorks events support; moved intLock() earlier in 
		 semMGive() to protect semId accesses.
01q,30aug00,hk   rename IntLockTaskSR to IntLockSR. add .align to semMGive.
		 minor pipeline optimization in inlined intLock().
01p,21aug00,hk   merge SH7729 to SH7700. merge SH7410 and SH7040 to SH7600.
01o,28mar00,hk   added .type directive to function names.
01n,17mar00,zl   made use of alignment macro _ALIGN_TEXT
01m,14sep98,hk   simplified CPU conditionals in _semMGive.
01l,16jul98,st   added SH7750 support.
01l,08may98,jmc  added support for SH-DSP and SH3-DSP.
01k,09jul97,hk   deleted SemInstClass_0, use SemInstClass.
01j,01may97,hk   made windview instrumentation conditionally compiled.
01i,28apr97,hk   changed SH704X to SH7040.
01j,16mar97,hms  changed symbol reference.
01i,05mar97,hms  added WindView support.
01h,03mar97,hk   changed XFFFFFF0F to XFF0F.
01g,26sep96,hk   fixed [SPR: #H1005] bug in inlined intLock() for SH7700.
01f,27jul96,hk   added bank register support for SH7700 by inlining intLock()
		 to _semMGive/_semMTake. merged "stc sr,r7" for non-SH7700
		 chips in semMInvCheck. reviewed #if/#elif/#endif readability.
01e,10jul96,ja	 added support for SH7700.
01d,18dec95,hk   added support for SH704X.
01g,09aug95,sa   made SH to use the optimized version for instrumented kernel.
01e,01aug95,sa   optimized for WindView.
01c,22may95,hk   reworked on pipeline filling, dt chance, int restriction.
01b,21apr95,hk   mostly optimized.
01a,19apr95,hk   written based on mc68k-01e.
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

#ifndef PORTABLE

	/* globals */

	.global	_semMGive		/* optimized mutex semaphore give */
	.global	_semMTake		/* optimized mutex semaphore take */

	.text

/*******************************************************************************
*
* semMGive - optimized give of a counting semaphore
*

*STATUS semMGive
*    (
*    SEM_ID semId		/@ semaphore id to give @/
*    )

* INTERNAL:
*	r7:	old sr
*	r6:	_taskIdCurrent
*	r5:	_kernWork
*	r4:	_semId
*	r3:	_intLockSR
*/
	.align	_ALIGN_TEXT

semMRecurse:
	add	#-1,r0
	mov.w	r0,@(SEM_RECURSE,r4)		/* decrement recurse count */
	ldc	r7,sr				/* UNLOCK INTERRUPTS */
	rts;
	mov	#0,r0

	.align	_ALIGN_TEXT
	.type	_semMGive,@function

_semMGive:					/* r4: semId */
	mov.l	IntCnt,r0;
	mov.l	@r0,r1;
	cmp/pl  r1				/* restrict isr use */
	bt	semMIntRestrict			/* intCnt > 0 */

#if (CPU==SH7600 || CPU==SH7000)
	mov.l	IntLockSR,r0;
	stc	sr,r7				/* old sr into r7 */
	mov.l	@r0,r3;				/* r3: _intLockTaskSR */
#else
	mov.l	IntLockMask,r1;
	mov.w	XFF0F,r3;			/* r3: 0xffffff0f */
	mov.l	@r1,r0;				/* r0: 0x000000m0 */
	stc	sr,r7				/* r7: 0x?___?_?_ */
	and	r7,r3				/* r3: 0x?___?_0_ */
	or	r0,r3				/* r3: 0x?___?_m_ */
#endif /* (CPU==SH7600 || CPU==SH7000) */
	ldc	r3,sr				/* LOCK INTERRUPTS */

	mov.l	@r4,r0;
	mov.l	SemClass,r1;			/* r1: &_semClass */
	cmp/eq  r0,r1				/* check validity */

#ifdef	WV_INSTRUMENTATION
 
	bt	objOkMGive
 
	/* windview - check the validity of instrumented class */

	mov.l	SemInstClass,r1;		/* r0: &_semInstClass */
	cmp/eq	r0,r1				/* check validity */
	bf	semIsInvalidUnlock		/* semaphore id error */
objOkMGive:

#else
	bf	semIsInvalidUnlock		/* semaphore id error */
#endif

	mov.l	TaskIdCurrent,r1;
	mov.l	@(SEM_STATE,r4),r0;
	mov.l	@r1,r6;				/* taskIdCurrent into r6 */
	cmp/eq  r0,r6				/* taskIdCurrent is owner? */
	bf	semOpInvalid			/* SEM_INVALID_OPERATION */

	mov.w	@(SEM_RECURSE,r4),r0;
	tst	r0,r0				/* if recurse count > 0 */
	bf	semMRecurse			/* handle recursion */

semMInvCheck:
	mov	#0,r5				/* r5: _kernWork */

	mov.b	@(SEM_OPTIONS,r4),r0;
	tst	#0x8,r0				/* SEM_INVERSION_SAFE? */
	bt	semMStateSet			/* if not, test semQ */

	mov	#WIND_TCB_MUTEX_CNT,r0
	mov.l	@(r0,r6),r1;
#if (CPU==SH7000)
	add	#-1,r1
	tst	r1,r1
#else
	dt	r1
#endif
	mov.l	r1,@(r0,r6)			/* decrement mutex count */
	bf	semMStateSet			/* if nonzero, test semQ */

	mov	#WIND_TCB_PRIORITY,r0
	mov.l	@(r0,r6),r1;			/* put priority in r1 */
	mov	#WIND_TCB_PRI_NORMAL,r0
	mov.l	@(r0,r6),r2;			/* put normal priority in r2 */
	cmp/eq  r1,r2
	bt	semMStateSet			/* if same, test semQ */
	mov	#4,r5				/* or in SEM_M_PRI_RESORT */

semMStateSet:
	mov.l	@(SEM_Q_HEAD,r4),r1;
	mov	#SEM_M_Q_GET,r0			/* r0: SEM_M_Q_GET */
	tst	r1,r1				/* anyone need to be got */
#if (CPU==SH7000)
	mov.l	r1,@(SEM_STATE,r4)		/* update semaphore state */
	bf	semMDelSafe
#else
	bf.s	semMDelSafe
	mov.l	r1,@(SEM_STATE,r4)		/* update semaphore state */
#endif /* CPU==SH7000 */
	mov.l	@(SEM_EVENTS_TASKID,r4),r1;
	mov	#SEM_M_SEND_EVENTS,r0		/* r0: SEM_M_SEND_EVENTS */
	tst	r1,r1				/* semId->events.taskId = 0? */
	bf	semMDelSafe

	mov	#0,r0				/* kernWork = 0 */
semMDelSafe:
	or      r0,r5				/* update kernWork */
	mov.b	@(SEM_OPTIONS,r4),r0;
	tst	#0x4,r0				/* SEM_DELETE_SAFE? */
	bt	semMShortCut			/* check for short cut */

	mov	#WIND_TCB_SAFE_CNT,r0
	mov.l	@(r0,r6),r1;
#if (CPU==SH7000)
	add	#-1,r1
	tst	r1,r1
#else
	dt	r1
#endif
	mov.l	r1,@(r0,r6)			/* decrement safety count */
	bf	semMShortCut			/* check for short cut */

	mov	#WIND_TCB_SAFETY_Q_HEAD,r0
	mov.l	@(r0,r6),r1;
	tst	r1,r1				/* check for pended deleters */
	bt	semMShortCut			/* check for short cut */

	mov	#2,r0
	or      r0,r5				/* set SAFETY_Q_FLUSH */
semMShortCut:
	tst	r5,r5				/* any work for kernel level? */
	bf	semMKernWork			/* enter kernel if any work */

	ldc	r7,sr				/* UNLOCK INTERRUPTS */
	rts;
	mov	#0,r0				/* return OK */

semMKernWork:					/* r4: semId */
	mov.l	KernelState,r1;
	mov	#1,r0
	mov.l	r0,@r1				/* KERNEL ENTER */
	ldc	r7,sr				/* UNLOCK INTERRUPTS */
	mov.l	SemMGiveKern,r0;
	mov.l	SemMGiveKernWork,r1;
	jmp	@r0;				/* finish semMGive in C */
	mov.l	r5,@r1				/* setup work for semMGiveKern*/

			.align	2
SemMGiveKern:		.long	_semMGiveKern
SemMGiveKernWork:	.long	_semMGiveKernWork

/*******************************************************************************
*
* semIsInvalid - unlock interupts and call semInvalid ().
*/
	.align	_ALIGN_TEXT
	.type	semIsInvalid,@function

semIsInvalidUnlock:
	ldc	r7,sr				/* UNLOCK INTERRUPTS */
semIsInvalid:
	mov.l	SemInvalid,r0;
	jmp	@r0				/* let C rtn do work and rts */
	nop

semOpInvalid:
	ldc	r7,sr				/* UNLOCK INTERRUPTS */
	mov.l	Errno,r0;
	mov.l	X160068,r1;
	mov.l	r1,@r0
	rts;
	mov	#-1,r0

semMIntRestrict:
	mov.l	SemIntRestrict,r0;
	jmp	@r0;				/* let C do the work */
	nop

			.align	2
SemInvalid:		.long	_semInvalid
Errno:			.long	_errno
X160068:		.long	0x00160068
SemIntRestrict:		.long	_semIntRestrict

/*******************************************************************************
*
* semMTake - optimized take of a mutex semaphore
*

*STATUS semMTake
*    (
*    SEM_ID semId,		/@ semaphore id to give @/
*    int timeout		/@ timeout in ticks @/
*    )

* INTERNAL:
*	r7:	old sr
*	r6:	_taskIdCurrent
*	r5:	_timeout
*	r4:	_semId
*	r3:	WindExit
*/
	.align	_ALIGN_TEXT
	.type	_semMTake,@function

_semMTake:					/* r4: semId,  r5: timeout */
	mov.l	IntCnt,r3;
#if (CPU==SH7600 || CPU==SH7000)
	mov.l	IntLockSR,r1;
	mov.l	@r3,r3;
	mov.l	@r1,r0;
	cmp/pl  r3
	bt	semMIntRestrict
	stc	sr,r7				/* old sr into r7 */
	ldc	r0,sr				/* LOCK INTERRUPTS */
#else
	mov.l	IntLockMask,r2;
	mov.l	@r3,r3;
	mov.w	XFF0F,r1;			/* r1: 0xffffff0f */
	cmp/pl  r3
	mov.l	@r2,r0;				/* r0: 0x000000m0 */
	bt	semMIntRestrict
	stc	sr,r7				/* r7: 0x?___?_?_ */
	and	r7,r1				/* r1: 0x?___?_0_ */
	or	r0,r1				/* r1: 0x?___?_m_ */
	ldc	r1,sr				/* LOCK INTERRUPTS */
#endif
	mov.l	@r4,r0;
	mov.l	SemClass,r1;			/* r1: &_semClass */
	cmp/eq  r0,r1				/* check validity */

#ifdef	WV_INSTRUMENTATION
 
	bt	objOkMTake
 
	/* windview - check the validity of instrumented class */
 
	mov.l	SemInstClass,r1;		/* r0: &_semInstClass */
	cmp/eq	r0,r1				/* check validity */
	bf	semIsInvalidUnlock		/* invalid semaphore */
objOkMTake:

#else
	bf	semIsInvalidUnlock		/* invalid semaphore */
#endif

	mov.l	TaskIdCurrent,r1;
	mov.l	@(SEM_STATE,r4),r0;
	mov.l	@r1,r6				/* taskIdCurrent into r6 */
	tst	r0,r0				/* test for owner */
	bf	semMEmpty			/* sem is owned, is it ours? */

	mov.l	r6,@(SEM_STATE,r4)		/* we now own semaphore */

	mov.b	@(SEM_OPTIONS,r4),r0;
	tst	#0x8,r0				/* SEM_INVERSION_SAFE? */
	bt	semMPriCheck			/* if not, skip increment */

	mov	#WIND_TCB_MUTEX_CNT,r0
	mov.l	@(r0,r6),r1;
	add	#1,r1
	mov.l	r1,@(r0,r6)			/* update inherit count */

semMPriCheck:
	mov.b	@(SEM_OPTIONS,r4),r0;
	tst	#0x4,r0				/* SEM_DELETE_SAFE? */
	bt	semMDone			/* if not, skip increment */

	mov	#WIND_TCB_SAFE_CNT,r0
	mov.l	@(r0,r6),r1;
	add	#1,r1
	mov.l	r1,@(r0,r6)			/* update safety count */
semMDone:
	ldc	r7,sr				/* UNLOCK INTERRUPTS */
	rts;
	mov	#0,r0				/* return OK */

semMEmpty:
	cmp/eq  r0,r6				/* recursive take */
	bf	semMQUnlockPut			/* if not, block */

	mov.w	@(SEM_RECURSE,r4),r0;
	add	#1,r0
	mov.w	r0,@(SEM_RECURSE,r4)		/* increment recurse count */

	ldc	r7,sr				/* UNLOCK INTERRUPTS */
	rts;
	mov	#0,r0				/* return OK */

semMQUnlockPut:
	mov.l	KernelState,r1;
	mov	#1,r0
	mov.l	r0,@r1				/* KERNEL ENTER */

	ldc	r7,sr				/* UNLOCK INTERRUPTS */

	sts.l	pr,@-sp				/* save return address */
	mov.l	r4,@-sp				/* save _semId */
	mov.l	r5,@-sp				/* save _timeout */

	mov.l	SemMPendQPut,r0;		/* do as much in C as possible*/
	jsr	@r0;				/* semMPendQPut(semId,timeout)*/
	nop					/*	r4: semId, r5: timeout*/
	mov.l	WindExit,r3;
	tst	r0,r0				/* test return */
	bf	semMFail			/* if !OK, exit kernel, ERROR */

semMQPendQOk:
	jsr	@r3;				/* KERNEL EXIT */
	nop
	cmp/eq  #0x1,r0				/* test the return value */
	bt	semMRestart			/* is it a RESTART? */

	add	#8,sp				/* cleanup */
	lds.l	@sp+,pr				/* and restore return address */
	rts;					/* finished OK or TIMEOUT */
	nop

semMRestart:
	mov.l	Func_sigTimeoutRecalc,r1;
	mov.l	@r1,r0;				/* address of recalc routine */
	jsr	@r0;				/* recalc the timeout */
	mov.l	@sp+,r4				/*     r4: timeout    */

	mov.l	@sp+,r4				/* restore semId */
	mov.l	SemTake,r1;
	lds.l	@sp+,pr				/* restore return address */
	jmp	@r1;				/* start the whole thing over */
	mov	r0,r5				/* update timeout */

semMFail:
	jsr	@r3;				/* KERNEL EXIT */
	add	#8,sp				/* clean up */
	lds.l	@sp+,pr				/* and restore return address */
	rts;					/* failed */
	mov	#-1,r0				/* return ERROR */

			.align	2
Func_sigTimeoutRecalc:	.long	__func_sigTimeoutRecalc
IntCnt:			.long	_intCnt
KernelState:		.long	_kernelState
SemClass:		.long	_semClass
SemMPendQPut:		.long	_semMPendQPut
TaskIdCurrent:		.long	_taskIdCurrent
WindExit:		.long	_windExit
SemTake:		.long	_semTake
#ifdef	WV_INSTRUMENTATION
SemInstClass:		.long	_semInstClass
#endif
#if (CPU==SH7600 || CPU==SH7000)
IntLockSR:		.long	_intLockTaskSR
#else
IntLockMask:		.long	_intLockMask
XFF0F:			.word	0xff0f
#endif

#endif	/* !PORTABLE */
