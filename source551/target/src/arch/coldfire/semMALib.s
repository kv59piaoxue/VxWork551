/* semMALib.s - internal VxWorks mutex semaphore assembler library */

/* Copyright 1984-2002 Wind River Systems, Inc. */
	.data
	.globl	_copyright_wind_river
	.long	_copyright_wind_river

/*
modification history
--------------------
01d,15may02,dee  lock interrupts earlier for semMGive() (SPR 77206).
01c,07mar02,bwa  Added check for int context in semMTake (SPR 74204).
01b,22jan02,bwa  Implemented VxWorks events support.
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
#include "private/taskLibP.h"
#include "private/semLibP.h"

#ifndef PORTABLE

	/* globals */

	.globl	_semMGive		/* optimized mutex semaphore give */
	.globl	_semMTake		/* optimized mutex semaphore take */

	.text
	.even

/*******************************************************************************
*
* semIsInvalid - unlock interupts and call semInvalid ().
*/

semIsInvalidUnlock:
	movew	d1,sr			/* UNLOCK INTERRUPTS */
semIsInvalid:
	jmp	_semInvalid		/* let C rtn do work and rts */

/*******************************************************************************
*
* semMGive - optimized give of a mutex semaphore
*

*STATUS semMGive
*    (
*    SEM_ID semId		/@ semaphore id to give @/
*    )

*/

semMIntRestrict:
	jmp	_semIntRestrict			/* let C do the work */

semMRecurse:
	movew	a0@(SEM_RECURSE),a1		/* auto sign extend */
	subql	#1,a1				/* decrement recurse count */
	movew	a1,a0@(SEM_RECURSE)
	movew   d1,sr				/* UNLOCK INTERRUPTS */
	clrl	d0				/* good return */
	rts

_semMGive:					/* a0 = semId! d0 = 0! */
	movel	_taskIdCurrent,a1		/* taskIdCurrent into a1 */
	tstl	_intCnt				/* restrict isr use */
	jne 	semMIntRestrict			/* intCnt > 0 */
	movew	sr,d1				/* old sr into d1 */
	movew	_intLockTaskSR,d0		/* LOCK INTERRUPTS */
	movew	d0,sr
	movel	#_semClass, d0
	cmpl	a0@,d0				/* check validity */

#ifdef WV_INSTRUMENTATION

        jeq     objOkMGive

	/* windview - check the validity of instrumented class */
	movel	#_semInstClass,d0		/* check validity */
	cmpl	a0@,d0
#endif

	jne 	semIsInvalidUnlock		/* semaphore id error */

objOkMGive:
	cmpl	a0@(SEM_STATE),a1		/* taskIdCurrent is owner? */
	jne 	semIsInvalidUnlock		/* SEM_INVALID_OPERATION */
	tstw	a0@(SEM_RECURSE)		/* if recurse count > 0 */
	jne 	semMRecurse			/* handle recursion */
semMInvCheck:
	moveq	#0,d0				/* clear before proceeding */
	btst	#3,a0@(SEM_OPTIONS)		/* SEM_INVERSION_SAFE? */
	jeq 	semMStateSet			/* if not, test semQ */
	subql	#1,a1@(WIND_TCB_MUTEX_CNT)	/* decrement mutex count */
	jne 	semMStateSet			/* if nonzero, test semQ */
	movel	a1@(WIND_TCB_PRIORITY),d0	/* put priority in d0 */
	subl	a1@(WIND_TCB_PRI_NORMAL),d0	/* subtract normal priority */
	jeq 	semMStateSet			/* if same, test semQ */
	moveq	#4,d0				/* or in PRIORITY_RESORT */
semMStateSet:
	movel	a0@(SEM_Q_HEAD),a0@(SEM_STATE)	/* update semaphore state */
        beq     semMVerifyTaskId                /* no task pending,test taskId*/
	addql	#1,d0				/* set SEM_Q_GET */
semMDelSafe:
	btst	#2,a0@(SEM_OPTIONS)		/* SEM_DELETE_SAFE? */
	jeq 	semMShortCut			/* check for short cut */
	subql	#1,a1@(WIND_TCB_SAFE_CNT)	/* decrement safety count */
	jne 	semMShortCut			/* check for short cut */
	tstl	a1@(WIND_TCB_SAFETY_Q_HEAD)	/* check for pended deleters */
	jeq 	semMShortCut			/* check for short cut */
	addql	#2,d0				/* set SAFETY_Q_FLUSH */
semMShortCut:
	tstl	d0				/* any work for kernel level? */
	jne 	semMKernWork			/* enter kernel if any work */
	movew	d1,sr				/* UNLOCK INTERRUPTS */
	rts					/* d0 is still 0 for OK */
semMKernWork:
	movel	#0x1,a0				/* KERNEL ENTER */
	movel	a0,_kernelState
	movew	d1,sr				/* UNLOCK INTERRUPTS */
	movel	d0,_semMGiveKernWork		/* setup work for semMGiveKern*/
	jmp	_semMGiveKern			/* finish semMGive in C */

semMVerifyTaskId:
	movel	d2,-(a7)
	movel	a0@(SEM_EVENTS_TASKID),d2
        cmpil   #0,d2				/* task waiting for events ? */
        beq     semMPopD2                       /* no, finish semMGive work */
        addql   #0x8,d0                         /* yes, set SEM_M_SEND_EVENTS */
semMPopD2:
	movel	(a7)+,d2
	bra	semMDelSafe
 
/*******************************************************************************
*
* semMTake - optimized take of a mutex semaphore
*

*STATUS semMTake
*    (
*    SEM_ID semId		/@ semaphore id to give @/
*    )

*/

_semMTake:					/* a0 = semId! */
	movel	_taskIdCurrent,a1		/* taskIdCurrent into a1 */
	tstl	_intCnt
	jne	semMIntRestrict
	movew	sr,d1				/* old sr into d1 */
	movew	_intLockTaskSR,d0		/* LOCK INTERRUPTS */
	movew	d0,sr
	movel	#_semClass,d0
	cmpl	a0@,d0				/* check validity */

#ifdef WV_INSTRUMENTATION
        jeq     objOkMTake

	/* windview - check the validity of instrumented class */
	movel	#_semInstClass,d0		/* check validity */
	cmpl	a0@,d0
#endif

        jne     semIsInvalidUnlock      	/* invalid semaphore */

objOkMTake:
	movel	a0@(SEM_STATE),d0		/* test for owner */
	jne 	semMEmpty			/* sem is owned, is it ours? */
	movel	a1,a0@(SEM_STATE)		/* we now own semaphore */
	btst	#2,a0@(SEM_OPTIONS)		/* SEM_DELETE_SAFE? */
	jeq 	semMPriCheck			/* semMPriCheck */
	addql	#1,a1@(WIND_TCB_SAFE_CNT)	/* bump safety count */
semMPriCheck:
	btst	#3,a0@(SEM_OPTIONS)		/* SEM_INVERSION_SAFE? */
	jeq 	semMDone			/* if not, skip increment */
	addql	#1,a1@(WIND_TCB_MUTEX_CNT)	/* bump priority mutex count */
semMDone:
	movew	d1,sr				/* UNLOCK INTERRUPTS */
	rts					/* d0 is still 0 for OK */

semMEmpty:
	cmpl	a1,d0				/* recursive take */
	jne 	semMQUnlockPut			/* if not, block */
	movew	a0@(SEM_RECURSE),a1		/* auto sign extend */
	addql	#1,a1
	movew	a1,a0@(SEM_RECURSE)		/* increment recurse count */
	movew	d1,sr				/* UNLOCK INTERRUPTS */
	clrl	d0				/* return OK */
	rts

semMQUnlockPut:
	movel	#0x1,d0				/* KERNEL ENTER */
	movel	d0,_kernelState
	movew	d1,sr				/* UNLOCK INTERRUPTS */
	movel	a7@(0x8),a7@-			/* push the timeout */
	movel	a0,a7@-				/* push the semId */
        jsr	_semMPendQPut			/* do as much in C as possible*/
        addql	#0x8,a7				/* cleanup */
	tstl	d0				/* test return */
	jne 	semMFail			/* if !OK, exit kernel, ERROR */

semMQPendQOk:
        jsr	_windExit			/* KERNEL EXIT */
	tstl	d0				/* test the return value */
	jgt 	semMRestart			/* is it a RESTART? */
        rts					/* finished OK or TIMEOUT */

semMRestart:
	movel   a7@(0x8),a7@-			/* push the timeout */
        movel   __func_sigTimeoutRecalc,a0	/* address of recalc routine */
        jsr     a0@				/* recalc the timeout */
        addql	#0x4,a7				/* clean up */
        movel   d0,a7@(0x8)			/* and restore timeout */
        jmp     _semTake			/* start the whole thing over */

semMFail:
        jsr	_windExit			/* KERNEL EXIT */
        moveq	#-1,d0				/* return ERROR */
	rts					/* failed */

#endif	/* !PORTABLE */
