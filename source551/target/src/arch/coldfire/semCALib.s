/* semCALib.s - internal VxWorks counting semaphore assembler library */

/* Copyright 1984-2002 Wind River Systems, Inc. */
	.data
	.globl	_copyright_wind_river
	.long	_copyright_wind_river

/*
modification history
--------------------
01c,07mar02,bwa  Added check for int context in semCTake (SPR 74204).
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

	.globl	_semCGive		/* optimized counting semaphore give */
	.globl	_semCTake		/* optimized counting semaphore take */

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
* semCGive - optimized give of a counting semaphore
*

*STATUS semCGive
*    (
*    SEM_ID semId		/@ semaphore id to give @/
*    )

*/
_semCGive:				/* a0 = semId! d0 = 0! */
	movew	sr,d1			/* old sr into d1 */
	movew	d1,d0
	oril	#0x0700,d0		/* set interrupt mask in SR */
	movew	d0,sr			/* LOCK INTERRUPTS */
	movel	#_semClass,d0
	cmpl	a0@,d0			/* check validity */

#ifdef WV_INSTRUMENTATION
        jeq     objOkCGive

	/* windview - check the validity of instrumented class */
	movel	#_semInstClass,d0		/* check validity */
	cmpl	a0@,d0
#endif

        jne     semIsInvalidUnlock      /* invalid semaphore */

objOkCGive:
	movel	a0@(SEM_Q_HEAD),d0	/* test semaphore queue head */
	jne 	_semQGet		/* if not empty, get from q */
	addql	#1,a0@(SEM_STATE)	/* decrement count */

	movel	a0@(SEM_EVENTS_TASKID),d0
        cmpil   #0,d0			/* does a task want events? */
        bne     semCSendEvents          /* if (taskId != NULL), yes */
 
	movew	d1,sr			/* UNLOCK INTERRUPTS */
	rts				/* d0 is still 0 for OK */

 
        /* we want to call eventSend() */
semCSendEvents:
        movel   #OK,-(a7)               /* retStatus = OK */
        movel   _errno,-(a7)            /* save old errno */
	movel	#TRUE,d0
        movel   d0,_kernelState		/* kernelState = TRUE */
        movew   d1,sr                   /* UNLOCK INTERRUPTS */
        movel   a0,-(a7)                /* save a0 */
        movel   a0@(SEM_EVENTS_REGISTERED),-(a7) /* args on stack */
        movel   a0@(SEM_EVENTS_TASKID),-(a7)
        jsr     _eventRsrcSend          /* call fcn,return value in d0*/
        addal   #8,a7                   /* cleanup eventSend args */
        moveal  (a7)+,a0                /* restore a0 */
        cmpil   #0,d0                   /* eventSend failed ? */
        bne     semCEventSendFailed     /* if so, set errno ? */
        btst    #0,a0@(SEM_EVENTS_OPTIONS) /* if not,send events once?*/
        beq     semCGiveWindExit        /* if not, kernel exit */
semCGiveTaskIdClear:                            /* if so, clear taskId */
        clrl    a0@(SEM_EVENTS_TASKID)  /* semId->events.taskId = NULL*/
semCGiveWindExit:
        jsr     _windExit               /* KERNEL EXIT */
        movel   (a7)+,_errno            /* and wanted value in errno */
        movel   (a7)+,d0                /* put wanted error code in d0*/
        rts                             /* d0 = retStatus */

semCEventSendFailed:
        btst    #4,a0@(SEM_OPTIONS)     /* want to return error ? */
        beq     semCGiveTaskIdClear     /* no, clear taskId */
	movel	#-1,d0
        movel   d0,a7@(4)              /* yes, save ERROR on stack */
        movel   #((134<<16)+0x4),d0    /* and save errno on stack */
	movel	d0, a7@
        bra     semCGiveTaskIdClear     /* then clear taskId */
 
/* end of semCGive() */

/*******************************************************************************
*
* semCTake - optimized take of a counting semaphore
*

*STATUS semCTake
*    (
*    SEM_ID semId		/@ semaphore id to take @/
*    )

*/
semCIntRestrict:
	jmp	_semIntRestrict

_semCTake:				/* a0 = semId! */
	tstl	_intCnt
	jne	semCIntRestrict
	movew	sr,d1			/* old sr into d1 */
	movew	_intLockTaskSR,d0	/* LOCK INTERRUPTS */
	movew	d0,sr
	movel	#_semClass,d0
	cmpl	a0@,d0			/* check validity */

#ifdef WV_INSTRUMENTATION
        jeq     objOkCTake

	/* windview - check the validity of instrumented class */
	movel	#_semInstClass,d0		/* check validity */
	cmpl	a0@,d0
#endif

        jne     semIsInvalidUnlock      /* invalid semaphore */
objOkCTake:

	tstl	a0@(SEM_STATE)		/* test count */
	jeq 	_semQPut		/* if sem is owned we block */
	subql	#1,a0@(SEM_STATE)	/* decrement count */
	movew	d1,sr			/* UNLOCK INTERRUPTS */
	clrl	d0			/* return OK */
	rts

#endif	/* !PORTABLE */
