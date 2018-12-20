/* semALib.s - internal VxWorks binary semaphore assembler library */

/* Copyright 1995-2001 Wind River Systems, Inc. */

	.data
	.global	_copyright_wind_river
	.long	_copyright_wind_river

/*
modification history
--------------------
01w,18dec01,hk   made semBTake jump to semIntRestrict if intCnt > 0 (SPR#72119).
01v,06nov01,aeg  removed redundant call to semQGet() in semBGive().
01u,15oct01,aeg  added VxWorks events support; rearranged code layout so
		 that short branches can be used.
01t,20mar01,hk   fix semGive/semTake recurse/state display on WindView.
01s,30aug00,hk   rearrange semGive code layout to use short branch in semBGive.
		 change intLockTaskSR to intLockSR.  simplify semGiveGlobal/
		 semTakeGlobal.  delete #if FALSE clause in semBTake.
		 minor pipeline optimization in inlined intLock().
01r,21aug00,hk   merge SH7729 to SH7700, merge SH7410 and SH7040 to SH7600.
01q,22may00,hk   reviewed WindView instrumentation code for T2/SH4.
01p,09may00,frf  Update SH support for WindView:semGive/Take,semQGet/Put
01o,28mar00,hk   added .type directive to function names.
01n,17mar00,zl   made use of alignment macro _ALIGN_TEXT. reordered for pcrel
01m,26may99,jmb  Fix access of recurse field (Windview instrumentation).
01l,16jul98,st   added SH7750 support.
01k,08may98,jmc  added support for SH-DSP and SH3-DSP.
01j,09jul97,hk   reviewed windview instrumentation code.
01i,01may97,hk   made windview instrumentation conditionally compiled.
01h,28apr97,hk   changed SH704X to SH7040.
01i,16mar97,hms  changed symbol reference.
01h,05mar97,hms  added WindView support.
01g,03mar97,hk   changed XFFFFFF0F to XFF0F.
01f,26sep96,hk   fixed [SPR: #H1005] bug in inlined intLock() for SH7700.
01e,24jul96,hk   added bank register support for SH7700 by inlining intLock()
		 to _semBGive/_semBTake. reviewed #if/#elif/#endif readability.
01d,07jun96,hk   added support for SH7700.
01i,22aug95,sa   fixed semTake.
01h,09aug95,sa   fixed semTake.
01g,08aug95,sa   made SH to use the optimized version for instrumented kernel.
01e,01aug95,sa   optimized for WindView.
01c,22may95,hk   reworked on register usage, added old sem stuff.
01b,18apr95,hk   mostly optimized. check XXX later. old sem stuff not coded.
01a,13apr95,hk   written based on mc68k-01q.
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
#include "private/eventP.h"
#include "private/evtLogLibP.h"
#include "eventLib.h"			/* EVENTS_SEND_ONCE */
#include "semLib.h"			/* SEM_EVENTSEND_ERR_NOTIFY */

#ifndef PORTABLE

#if	(TRG_CLASS2_INDEX > 0x7f)
#error	TRG_CLASS2_INDEX > 0x7f, check eventP.h
#endif
#if	(TRG_CLASS3_INDEX > 0x7f)
#error	TRG_CLASS3_INDEX > 0x7f, check eventP.h
#endif
#if	(SEM_TYPE > 15)
#error	SEM_TYPE > 15, check semLibP.h
#endif
#if	(SEM_RECURSE > 30)
#error	SEM_RECURSE > 30, check semLibP.h
#endif
#if	(SEM_Q_HEAD > 60)
#error	SEM_Q_HEAD > 60, check semLibP.h
#endif
#if	(SEM_STATE > 60)
#error	SEM_STATE > 60, check semLibP.h
#endif
#if	(SEM_INST_RTN > 60)
#error	SEM_INST_RTN > 60, check semLibP.h
#endif

	/* globals */

	.global	_semGive		/* optimized semGive demultiplexer */
	.global	_semTake		/* optimized semTake demultiplexer */
	.global	_semBGive		/* optimized binary semaphore give */
	.global	_semBTake		/* optimized binary semaphore take */
	.global	_semQGet		/* semaphore queue get routine */
	.global	_semQPut		/* semaphore queue put routine */
	.global	_semOTake		/* optimized old semaphore take */
	.global	_semClear		/* optimized old semaphore semClear */
#undef	DEBUG
#ifdef	DEBUG
	.global	semGiveKern
	.global	semGiveGlobal
	.global	semGiveNotBinary
	.global	semTakeNotBinary
	.global	semTakeGlobal
#endif	/*DEBUG*/

	.text

/******************************************************************************
*
* semGiveKern - add give routine to work queue
*
*/
	.align	_ALIGN_TEXT
	.type	semGiveKern,@function

semGiveKern:
	mov.l	SemGiveDefer,r0;
	jmp	@r0;			/* let C rtn defer work and rts */
	nop				/* r4: semId */

		.align	2
SemGiveDefer:	.long	_semGiveDefer

/******************************************************************************
*
* semGiveGlobal
*
*/
	.align	_ALIGN_TEXT
	.type	semGiveGlobal,@function

semGiveGlobal:				/* r4: semId */
	mov.l	SmObjPoolMinusOne,r1;
	mov.l	@r1,r0;
	add	r0,r4			/* convert id to local address    */
	mov.l	@(4,r4),r0;		/* get semaphore type in r0       */
	mov.l	SemGiveTbl,r1;		/* r1 = semaphore give table      */
	and	#0x7,r0			/* mask r0 to MAX_SEM_TYPE value  */
	shll2	r0			/* scale r0 by sizeof (FUNCPTR)   */
	mov.l	@(r0,r1),r2;		/* r2 = appropriate give function */
	jmp	@r2;			/* invoke give rtn, it will do rts */
	nop				/* r4: smObjSemId */

/******************************************************************************
*
* semGiveNotBinary - call semGive indirectly via semGiveTbl
*
*/
	.align	_ALIGN_TEXT
	.type	semGiveNotBinary,@function

semGiveNotBinary:			/* r4: semId */

        /* call semGive indirectly via semGiveTbl.  Note that the index could
	 * equal zero after it is masked.  semBGive is the zeroeth element
	 * of the table, but for it to function correctly in the optimized
	 * version above, we must be certain not to clobber r4.  Note, also
	 * that old semaphores will also call semBGive above.
	 */

	mov.l	SemGiveTbl,r1;		/* get table address into r1         */
	and	#0x7,r0			/* mask r0 to MAX_SEM_TYPE value     */
	shll2	r0			/* scale r0 by sizeof (FUNCPTR)      */
	mov.l	@(r0,r1),r2;		/* get right give rtn for this class */
	jmp	@r2;			/* invoke give rtn, it will do rts   */
	nop				/* r4: semId */

		.align	2
SemGiveTbl:	.long	_semGiveTbl

/******************************************************************************
*
* semGive - give a semaphore
*

* STATUS semGive
*     (
*     SEM_ID semId		/@ semaphore id to give @/
*     )

*/
	.align	_ALIGN_TEXT
	.type	_semGive,@function

_semGive:				/* r4: semId */
	mov	r4,r0
	tst	#0x1,r0
	bf	semGiveGlobal		/* if semId lsb = 1 its a global sem */

#ifdef	WV_INSTRUMENTATION
	/* windview instrumentation - BEGIN
	 * semGive level 1 (object status event )
	 */
	mov.l	EvtAction,r1;		/* is level 1 event collection on? */
	mov.l	@r1,r0;
	tst	r0,r0
	bt	noSemGiveEvt
 
	mov.l	SG_SemClass,r1;
	mov.l	@r4,r3;			/* r3: semId->objCore */
	cmp/eq	r1,r3			/* check validity */
	bt	objOkGive		/* valid semaphore */
	mov.l	SemInstClass,r1;
	cmp/eq	r1,r3			/* check validity */
	bf	noSemGiveEvt		/* invalid semaphore */
objOkGive:
				/* is this semaphore object instrumented? */
	sts.l	pr,@-sp;		mov.l	@(SEM_INST_RTN,r3),r2;
	mov.l	r4,@-sp;		tst	r2,r2
					bt	semGiveCheckTrg

	/* Check if we need to log this event */
	mov.l	SG_WvEvtClass,r1;
	mov.l	SG_WV_CLASS_3_ON,r5;
	mov.l	@r1,r0;			mov	#0,r1;	/* r1: NULL */
	and	r5,r0
	cmp/eq	r5,r0
	bf	semGiveCheckTrg

	/* log event for this object (EVT_OBJ_3, see eventP.h) */

	/* __evtRtn__ (evtId,nParam,semId,state,recur,0, 0) */
	/* __evtRtn__ ( r4     r5    r6    r7    +0  +4 +8) */

					mov.l	r1,@-sp
					mov.l	r1,@-sp
					mov.w	@(SEM_RECURSE,r4),r0;
	mov.l	@(SEM_STATE,r4),r7;	mov.l	r0,@-sp
					mov	r4,r6
					mov.l	Event_SemGive,r4;
	jsr	@r2;			mov	#3,r5
					add	#12,sp	/* pop params */
semGiveCheckTrg:
	/* check if we need to evaluate trigger for this event */
	mov.l	SG_TrgEvtClass,r1;
	mov.l	SG_TRG_CLASS_3_ON,r2;
	mov.l	@r1,r0;			mov	#0,r1;	/* r1: NULL */
	and	r2,r0
	cmp/eq	r2,r0
	bf	semGiveInstDone

	/* trgCheck (event,index,semID,semID,state,recur, 0,    0) */
	/* trgCheck ( r4    r5    r6    r7    +0    +4   +8   +12) */

					mov.l	@sp,r6;	/* r6: semId */
	mov.l	r1,@-sp;		mov.w	@(SEM_RECURSE,r6),r0;
	mov.l	r1,@-sp;		mov.l	@(SEM_STATE,r6),r1;
	mov.l	r0,@-sp
	mov.l	r1,@-sp
	mov.l	SG_TrgCheck,r1;		mov	r6,r7
	mov.l	@r1,r0;			mov.l	Event_SemGive,r4
	jsr	@r0;			mov	#TRG_CLASS3_INDEX,r5
	add	#16,sp	/* pop params */
semGiveInstDone:
	mov.l	@sp+,r4
	lds.l	@sp+,pr	
noSemGiveEvt:
	/* windview instrumentation - END */
#endif 
	mov.l	KernelState,r1;
	mov.l	@r1,r0;
	tst	r0,r0
	bf	semGiveKern		/* if we are in kernel, defer work */

	mov.b	@(SEM_TYPE,r4),r0;	/* put the sem class into r0 */
	tst	r0,r0
	bf	semGiveNotBinary	/* optimization for BINARY if r0 == 0 */

	/* BINARY SEMAPHORE OPTIMIZATION */

	.type	_semBGive,@function
_semBGive:					/* r4: semId */
#if		(CPU==SH7600 || CPU==SH7000)
	mov.l	IntLockSR,r1;
	mov.l	@r1,r0;
	stc	sr,r7			/* r7: old sr */
	ldc	r0,sr			/* LOCK INTERRUPTS */
#else
	mov.l	IntLockMask,r2;
	mov.w	SG_XFF0F,r1;		/* r1: 0xffffff0f */
	mov.l	@r2,r0;			/* r0: 0x000000m0 */
	stc	sr,r7			/* r7: 0x?___?_?_ */
	and	r7,r1			/* r1: 0x?___?_0_ */
	or	r0,r1			/* r1: 0x?___?_m_ */
	ldc	r1,sr			/* LOCK INTERRUPTS */
#endif
	mov.l	@r4,r1;
	mov.l	SG_SemClass,r0;		/* r0: &_semClass */
	cmp/eq	r0,r1			/* check validity */

#ifdef	WV_INSTRUMENTATION

	bt	objOkBGive
 
	/* windview - check the validity of instrumented class */
	mov.l	SemInstClass,r0;
	cmp/eq	r0,r1
	bf	semBGiveInvalidUnlock	/* invalid semaphore */
objOkBGive:
#else
	bf	semBGiveInvalidUnlock	/* invalid semaphore */
#endif

	mov.l	@(SEM_Q_HEAD,r4),r0;
	mov.l   @(SEM_STATE,r4),r1;	/* cache semId->semOwner */
	tst	r0,r0
#if (CPU==SH7000)
	mov.l	r0,@(SEM_STATE,r4);
	bf	_semQGet		/* if not empty, get from q */
#else
	bf.s	_semQGet		/* if not empty, get from q */
	mov.l	r0,@(SEM_STATE,r4);
#endif /* CPU==SH7000 */

	/* determine if VxWorks events need to be sent */

	mov.l   @(SEM_EVENTS_TASKID,r4),r6;
	tst	r6,r6			/* semId->events.taskId = 0? */
	bt	semBGiveReturnOK	/* yes -> return (OK) */
	tst	r1,r1			/* semId->semOwner = NULL? */
	bt	semBGiveReturnOK	/* yes -> return (OK) */

	/* Events need to be sent; set kernelState */

	mov.l	KernelState,r1;
	mov	#1,r0;
	mov.l	r0,@r1;			/* KERNEL ENTER */

	ldc	r7,sr			/* UNLOCK INTERRUPTS */

	mov.l	r8,@-sp			/* push r8 (non-volatile) */
	mov.l	r9,@-sp			/* push r9 (non-volatile) */
	sts.l   pr,@-sp			/* push return address */

	mov.l   Errno,r1;
	mov.l	EventRsrcSend,r0;
	mov	r4,r8			/* r8: semId */
	mov.l   @r1,r9;			/* r9: errno before eventRsrcSend() */

	/* eventRsrcSend (semId->events.taskId, semId->events.registered) */

	mov.l   @(SEM_EVENTS_REGISTERED,r8),r5;
	jsr	@r0	
	mov	r6,r4;			/* transfer taskId parm */

	mov	#0,r6;			/* r6 = retStatus = OK */
	cmp/eq	#0,r0			/* eventRsrcSend() status = OK? */
	bt	semBGiveCheckSendOnce   /* yes -> check EVENTS_SEND_ONCE */

	/* NULL out the semId->events.taskId field if eventRsrcSend() failed */

	mov.l   r6,@(SEM_EVENTS_TASKID,r8);

	/* return ERROR only if SEM_EVENTSEND_ERR_NOTIFY option set */

	mov.b   @(SEM_OPTIONS,r8),r0;
	tst	#SEM_EVENTSEND_ERR_NOTIFY,r0;	/* option bit set? */
	bt	semBGiveWindExit		/* no -> windExit() */

	/* load S_eventLib_EVENTSEND_FAILED errno into oldErrno register */

	mov.l   X860004,r9;
	bra	semBGiveWindExit;
	mov	#-1,r6 			/* remember to return ERROR */


semBGiveCheckSendOnce:

        /*
	 * NULL out the semId->events.taskId field if the EVENTS_SEND_ONCE 
	 * events option is set.
	 */

	mov	#SEM_EVENTS_OPTIONS,r0;
	mov.b	@(r0,r8),r0;
	tst	#EVENTS_SEND_ONCE,r0	/* option bit set? */
	bt	semBGiveWindExit
	mov.l   r6,@(SEM_EVENTS_TASKID,r8);

	/* fall through to semBGiveWindExit */

semBGiveWindExit:

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

semBGiveReturnOK:
	ldc	r7,sr			/* UNLOCK INTERRUPTS */
	rts;
	mov	#0,r0; 			/* return (OK) */


semBGiveInvalidUnlock:			/* r4: semId */
	mov.l	SG_SemInvalid,r0;
#if (CPU==SH7600 || CPU==SH7000)
	jmp	@r0;
	ldc	r7,sr
#else
	ldc	r7,sr			/* UNLOCK INTERRUPTS */
	jmp	@r0;			/* let C rtn do work and rts */
	nop
#endif /* (CPU==SH7600 || CPU==SH7000) */


			.align	2
SG_SemClass:		.long	_semClass
EventRsrcSend:		.long	_eventRsrcSend
Errno:			.long   _errno
X860004:		.long	0x860004     /* S_eventLib_EVENTSEND_FAILED */
#ifdef WV_INSTRUMENTATION
Event_SemGive:		.long	EVENT_SEMGIVE
SG_WvEvtClass:		.long	_wvEvtClass
SG_WV_CLASS_3_ON:	.long   WV_CLASS_3_ON
SG_TrgCheck:		.long	__func_trgCheck
SG_TrgEvtClass:		.long	_trgEvtClass
SG_TRG_CLASS_3_ON:	.long	TRG_CLASS_3_ON	
#endif
SG_SemInvalid:		.long	_semInvalid
SG_XFF0F:		.word	0xff0f

/******************************************************************************
*
* semQGet - unblock a task from the semaphore queue head
*
* INTERNAL:	This routine is called from '_semBGive' and '_semCGive'.
*/
	.align	_ALIGN_TEXT
	.type	_semQGet,@function
					/* r7: old sr */
_semQGet:				/* r4: semId */
	mov.l	KernelState,r1;
	mov	#1,r0
	mov.l	r0,@r1			/* KERNEL ENTER */

#ifdef	WV_INSTRUMENTATION
	/* windview instrumentation - BEGIN
	 * semGive level 2 (task transition state event, EVT_TASK_1 )
	 */
	mov.l	EvtAction,r1;		/* is level 1 event collection on? */
	mov.l	@r1,r0;
	tst	r0,r0
	bt	noSemQGetEvt	
					/* Check if we need to log this event */
	sts.l	pr,@-sp;		mov.l	QG_WvEvtClass,r1;
	mov.l	r7,@-sp;		mov.l	@r1,r0;
					mov.l	QG_WV_CLASS_2_ON,r1;
	mov.l	r4,@-sp;		and	r1,r0
					cmp/eq	r1,r0
					bf	semQGetCheckTrg
	
	mov.l	Func_EvtLogM1,r1;	mov	r4,r5;
	mov.l	@r1,r0;			mov.l	Event_Obj_SemGive,r4;
	tst	r0,r0
	bt	semQGetCheckTrg
	jsr	@r0;			/* _evtLogM1 (evtId, semId) */
	nop

semQGetCheckTrg:
	/* check if we need to evaluate trigger for this event */
	mov.l	QG_TrgEvtClass,r1;
	mov.l	QG_TRG_CLASS_2_ON,r2;
	mov.l	@r1,r0;			mov	#0,r7;	/* r7: NULL */
	and	r2,r0
	cmp/eq	r2,r0
	bf	semQGetInstDone

	/*            r4    r5    r6   r7 +0 +4 +8 +12 */
	/* trgCheck (evtID,index,semID, 0, 0, 0, 0, 0) */

					mov.l	@sp,r6	/* r6: semId */
					mov.l	r7,@-sp
					mov.l	r7,@-sp
					mov.l	r7,@-sp
	mov.l	QG_TrgCheck,r1;		mov.l	r7,@-sp
	mov.l	@r1,r0;			mov.l	Event_Obj_SemGive,r4
	jsr	@r0;			mov	#TRG_CLASS2_INDEX,r5
					add	#16,sp	/* pop params */
semQGetInstDone:
	mov.l	@sp+,r4
	mov.l	@sp+,r7
	lds.l	@sp+,pr
noSemQGetEvt:
	/* windview instrumentation - END */
#endif

	ldc	r7,sr			/* UNLOCK INTERRUPTS */

	mov.l	WindPendQGet,r1;
	sts.l	pr,@-sp
	jsr	@r1;			/* unblock someone */
	add	#SEM_Q_HEAD,r4		/*     r4: pointer to qHead */

	mov.l	WindExit,r0;
	jsr	@r0;			/* KERNEL EXIT */
	nop
	lds.l	@sp+,pr
	rts;
	mov	#0,r0			/* XXX: windExit sets d0, so this could
					 *      be nop. see 68k code. */

			.align	2
WindPendQGet:		.long	_windPendQGet
#ifdef	WV_INSTRUMENTATION
Event_Obj_SemGive:	.long	EVENT_OBJ_SEMGIVE	/* eventP.h */
				/* CLASS2_EVENT(20) = (MIN_CLASS2_ID + 20) */
				/*                  = (600 + 20)	*/
				/*		    = 620 = 0x26c	*/
QG_WvEvtClass:		.long	_wvEvtClass
QG_WV_CLASS_2_ON:	.long   WV_CLASS_2_ON
QG_TrgCheck:		.long	__func_trgCheck
QG_TrgEvtClass:		.long	_trgEvtClass
QG_TRG_CLASS_2_ON:	.long	TRG_CLASS_2_ON	
#endif


/******************************************************************************
*
* semTakeGlobal
*
*/
	.align	_ALIGN_TEXT
	.type	semTakeGlobal,@function

semTakeGlobal:				/* r4: semId, r5: timeout         */
	mov.l	SmObjPoolMinusOne,r1;
	mov.l	@r1,r0;
	add	r0,r4			/* convert id to local adress     */
	mov.l	@(4,r4),r0;		/* get semaphore type in r0       */
	mov.l	SemTakeTbl,r1;		/* r1 = semaphore take table      */
	and	#0x7,r0			/* mask r0 to MAX_SEM_TYPE value  */
	shll2	r0			/* scale r0 by sizeof (FUNCPTR)   */
	mov.l	@(r0,r1),r2;		/* r2 = appropriate take function */
	jmp	@r2;			/* invoke take rtn, it will do rts */
	nop				/* r4: smObjSemId, r5: timeout     */

/******************************************************************************
*
* semTakeNotBinary
*
*/
	.align	_ALIGN_TEXT
	.type	semTakeNotBinary,@function

semTakeNotBinary:
	mov.l	SemTakeTbl,r1;		/* get address of take routine table */
	and	#0x7,r0			/* mask r0 to sane value             */
	shll2	r0			/* scale r0 by sizeof (FUNCPTR)      */
	mov.l	@(r0,r1),r2;		/* get right take rtn for this class */
	jmp	@r2;			/* invoke take rtn, it will do rts   */
	nop				/* r4: semId, r5: timeout            */

			.align	2
SmObjPoolMinusOne:	.long	_smObjPoolMinusOne
SemTakeTbl:		.long	_semTakeTbl

/******************************************************************************
*
* semTake - take a semaphore
*

* STATUS semTake
*     (
*     SEM_ID semId,		/@ semaphore id to take @/
*     ULONG  timeout		/@ timeout in ticks @/
*     )

*/
	.align	_ALIGN_TEXT
	.type	_semTake,@function
					/* r4: semId */
_semTake:				/* r5: timeout */
	mov	r4,r0
	tst	#0x1,r0
	bf	semTakeGlobal		/* if semId lsb = 1 its a global sem */

#ifdef	WV_INSTRUMENTATION
	/* windview instrumentation - BEGIN
	 * semTake level 1 (object status event )
	 */	
	mov.l	EvtAction,r1;		/* is level 1 event collection on? */
	mov.l	@r1,r0;
	tst	r0,r0
	bt	noSemTakeEvt
 
	mov.l	SemClass,r1;
	mov.l	@r4,r3;			/* r3: semId->objCore */
	cmp/eq	r1,r3			/* check validity */
	bt	objOkTake		/* valid semaphore */
	mov.l	SemInstClass,r1;
	cmp/eq	r1,r3			/* check validity */
	bf	noSemTakeEvt		/* invalid semaphore */
objOkTake:
				/* is this semaphore object instrumented? */
	sts.l	pr,@-sp;		mov.l	@(SEM_INST_RTN,r3),r2;
	mov.l	r5,@-sp;		tst	r2,r2
	mov.l	r4,@-sp;		bt	semTakeCheckTrg

	/* Check if we need to log this event */
	mov.l	ST_WvEvtClass,r1;
	mov.l	ST_WV_CLASS_3_ON,r5;
	mov.l	@r1,r0;			mov	#0,r1	/* r1: NULL */
	and	r5,r0
	cmp/eq	r5,r0
	bf	semTakeCheckTrg

	/* log event for this object (EVT_OBJ_3, see eventP.h) */

	/* __evtRtn__ (evtId,nParam,semId,state,recur, 0, 0) */
	/* __evtRtn__ ( r4     r5    r6    r7    +0   +4 +8) */

					mov.l	r1,@-sp
					mov.l	r1,@-sp
					mov.w	@(SEM_RECURSE,r4),r0;
	mov.l	@(SEM_STATE,r4),r7;	mov.l	r0,@-sp
					mov	r4,r6
					mov.l	Event_SemTake,r4;
	jsr	@r2;			mov	#3,r5
					add	#12,sp	/* pop params */
semTakeCheckTrg:
	/* check if we need to evaluate trigger for this event */
	mov.l	ST_TrgEvtClass,r1;
	mov.l	ST_TRG_CLASS_3_ON,r2;
	mov.l	@r1,r0;			mov	#0,r1;	/* r1: NULL */
	and	r2,r0
	cmp/eq	r2,r0
	bf	semTakeInstDone

	/* trgCheck (event,index,semID,semID,state,recur, 0,   0) */
	/* trgCheck ( r4    r5    r6    r7    +0    +4   +8  +12) */

					mov.l	@sp,r6;	/* r6: semId */
	mov.l	r1,@-sp;		mov.w	@(SEM_RECURSE,r6),r0;
	mov.l	r1,@-sp;		mov.l	@(SEM_STATE,r6),r1;
	mov.l	r0,@-sp
	mov.l	r1,@-sp
	mov.l	ST_TrgCheck,r1;		mov	r6,r7
	mov.l	@r1,r0;			mov.l	Event_SemTake,r4
	jsr	@r0;			mov	#TRG_CLASS3_INDEX,r5
	add	#16,sp	/* pop params */
semTakeInstDone:
	mov.l	@sp+,r4
	mov.l	@sp+,r5
	lds.l	@sp+,pr	
noSemTakeEvt:
	/* windview instrumentation - END */
#endif 	
 
	mov.b	@(SEM_TYPE,r4),r0;	/* get semaphore class into r0 */
	tst	r0,r0
	bf	semTakeNotBinary	/* optimize binary semaphore r0 == 0 */

		/* BINARY SEMAPHORE OPTIMIZATION */

		.type	_semBTake,@function
_semBTake:					/* r4: semId */
		mov.l	ST_IntCnt,r3;
#if		(CPU==SH7600 || CPU==SH7000)
		mov.l	IntLockSR,r1;
		mov.l	@r3,r3;
		mov.l	@r1,r0;
		cmp/pl	r3
		bt	semBTakeIntRestrict
		stc	sr,r7			/* r7: old sr */
		ldc	r0,sr			/* LOCK INTERRUPTS */
#else
		mov.l	IntLockMask,r2;
		mov.l	@r3,r3;
		mov.w	XFF0F,r1;		/* r1: 0xffffff0f */
		cmp/pl	r3
		mov.l	@r2,r0;			/* r0: 0x000000m0 */
		bt	semBTakeIntRestrict
		stc	sr,r7			/* r7: 0x?___?_?_ */
		and	r7,r1			/* r1: 0x?___?_0_ */
		or	r0,r1			/* r1: 0x?___?_m_ */
		ldc	r1,sr			/* LOCK INTERRUPTS */
#endif
		mov.l	@r4,r1;
		mov.l	SemClass,r0		/* r0: &_semClass(=semClassId)*/
		cmp/eq	r0,r1			/* check validity */

#ifdef		WV_INSTRUMENTATION

		bt	objOkBTake
 
		/* windview - check the validity of instrumented class */
		mov.l	SemInstClass,r0;
		cmp/eq	r0,r1
		bf	semBTakeInvalidUnlock	/* invalid semaphore */
objOkBTake:
#else
		bf	semBTakeInvalidUnlock	/* invalid semaphore */
#endif
		mov.l	@(SEM_STATE,r4),r0;
		tst	r0,r0			/* test for owner */
		bf	_semQPut		/* if sem is owned we block */

		mov.l	TaskIdCurrent,r2;
		mov.l	@r2,r1;
		mov.l	r1,@(SEM_STATE,r4)
#if		(CPU==SH7600 || CPU==SH7000)
		rts;
		ldc	r7,sr
#else
		ldc	r7,sr			/* UNLOCK INTERRUPTS */
		rts;				/* r0 is 0 for return(OK) */
		nop
#endif

semBTakeIntRestrict:
	mov.l	ST_SemIntRestrict,r0;
	jmp	@r0;			/* let C do the work */
	nop

semBTakeInvalidUnlock:			/* r4: semId */
	mov.l	ST_SemInvalid,r0;
#if (CPU==SH7600 || CPU==SH7000)
	jmp	@r0;
	ldc	r7,sr
#else
	ldc	r7,sr			/* UNLOCK INTERRUPTS */
	jmp	@r0;			/* let C rtn do work and rts */
	nop
#endif /* (CPU==SH7600 || CPU==SH7000) */

			.align	2
ST_IntCnt:		.long	_intCnt
TaskIdCurrent:		.long	_taskIdCurrent
ST_SemIntRestrict:	.long	_semIntRestrict
ST_SemInvalid:		.long	_semInvalid
#ifdef	WV_INSTRUMENTATION
EvtAction:		.long	_evtAction
SemInstClass:		.long	_semInstClass
Event_SemTake:		.long	EVENT_SEMTAKE	/* CLASS3_EVENT(15) (eventP.h)*/
ST_WvEvtClass:		.long	_wvEvtClass
ST_WV_CLASS_3_ON:	.long   WV_CLASS_3_ON	/* 0x10000007 (eventP.h) */
ST_TrgCheck:		.long	__func_trgCheck
ST_TrgEvtClass:		.long	_trgEvtClass
ST_TRG_CLASS_3_ON:	.long	TRG_CLASS_3_ON	/* 0x10000100 (eventP.h) */
#endif
XFF0F:			.word	0xff0f


/******************************************************************************
*
* semQPut - block current task on the semaphore queue head
*
* INTERNAL:	This routine is called from '_semBTake' and '_semCTake'.
*/
	.align	_ALIGN_TEXT
	.type	_semQPut,@function
					/* r7: old sr  */
					/* r5: timeout */
_semQPut:				/* r4: semId   */
	mov.l	KernelState,r1;
	mov	#1,r0
	mov.l	r0,@r1			/* KERNEL ENTER */

#ifdef  WV_INSTRUMENTATION
	/* windview instrumentation - BEGIN
	 * semQPut level 2 (task transition state event, EVT_TASK_1 )
	 */
	mov.l	QP_EvtAction,r1;	/* is level 1 event collection on? */
	mov.l	@r1,r0;
	tst	r0,r0
	bt	noSemQPutEvt	
					/* Check if we need to log this event */
	sts.l	pr,@-sp;		mov.l	QP_WvEvtClass,r1;
	mov.l	r7,@-sp;		mov.l	@r1,r0;
	mov.l	r5,@-sp;		mov.l	QP_WV_CLASS_2_ON,r1;
	mov.l	r4,@-sp;		and	r1,r0
					cmp/eq	r1,r0
					bf	semQPutCheckTrg

	mov.l	Func_EvtLogM1,r1;	mov	r4,r5
	mov.l	@r1,r0;			mov.l	Event_Obj_SemTake,r4;
	tst	r0,r0
	bt	semQPutCheckTrg
	jsr	@r0;			/* evtLogM1 (evtID,semId) */
	nop

semQPutCheckTrg:	
	/* check if we need to evaluate trigger for this event */
	mov.l  QP_TrgEvtClass,r1;
	mov.l  QP_TRG_CLASS_2_ON,r2;
	mov.l  @r1,r0;			mov	#0,r7	/* r7: NULL */
	and    r2,r0
	cmp/eq r2,r0
	bf     semQPInstDone

	/*            r4    r5    r6   r7 +0 +4 +8 +12 */
	/* trgCheck (evtID,index,semID, 0, 0, 0, 0, 0) */

					mov.l	@sp,r6;	/* r6: semId */
					mov.l	r7,@-sp
					mov.l	r7,@-sp
					mov.l	r7,@-sp
	mov.l	QP_TrgCheck,r1;		mov.l	r7,@-sp
	mov.l	@r1,r0;			mov.l	Event_Obj_SemTake,r4
	jsr	@r0;			mov	#TRG_CLASS2_INDEX,r5
					add	#16,sp	/* pop params */
semQPInstDone:
	mov.l	@sp+,r4
	mov.l	@sp+,r5
	mov.l	@sp+,r7
	lds.l	@sp+,pr	
noSemQPutEvt:
	/* windview instrumentation - END */
#endif

	ldc	r7,sr			/* UNLOCK INTERRUPTS */

	sts.l	pr,@-sp			/* save return address */
	mov.l	r4,@-sp			/* save semId   */
	mov.l	r5,@-sp			/* save timeout */

	mov.l	WindPendQPut,r0;
	jsr	@r0;			/* block on the semaphore  */
	add	#SEM_Q_HEAD,r4		/*	r4: &semId->qHead  */
					/*	r5: timeout        */
	mov.l	WindExit,r6;
	tst	r0,r0			/* if (windPendQPut != OK) */
	bf	semQPutFail		/*      put failed         */

	jsr	@r6;			/* else KERNEL EXIT        */
	nop
	cmp/eq	#0x1,r0			/* test windExit */
	bt	semRestart		/* RESTART */

	add	#8,sp			/* tidy up */
	lds.l	@sp+,pr			/* and restore return address */
	rts;				/* done, return exit status in r0 */
	nop

semQPutFail:
	jsr	@r6;			/* KERNEL EXIT */
	add	#8,sp			/* tidy up */
	lds.l	@sp+,pr			/* and restore return address */
	rts;				/* return to sender */
	mov	#-1,r0			/* return ERROR */

semRestart:
	mov.l	Func_sigTimeoutRecalc,r1;
	mov.l	@r1,r0;
	jsr	@r0;			/* recalc the timeout */
	mov.l	@sp+,r4			/*      r4: timeout   */

	mov.l	@sp+,r4			/* restore semId */
	lds.l	@sp+,pr			/* restore return address */
	bra	_semTake;		/* start the whole thing over */
	mov	r0,r5			/* update timeout */

			.align	2
WindPendQPut:		.long	_windPendQPut
Func_sigTimeoutRecalc:	.long	__func_sigTimeoutRecalc

#ifdef WV_INSTRUMENTATION
QP_EvtAction:		.long	_evtAction
Func_EvtLogM1:		.long	__func_evtLogM1
Event_Obj_SemTake:	.long	EVENT_OBJ_SEMTAKE
QP_WvEvtClass:		.long	_wvEvtClass
QP_WV_CLASS_2_ON:	.long   WV_CLASS_2_ON
QP_TrgCheck:		.long	__func_trgCheck
QP_TrgEvtClass:		.long	_trgEvtClass
QP_TRG_CLASS_2_ON:	.long	TRG_CLASS_2_ON	
#endif /*WV_INSTRUMENTATION*/

SemClass:		.long	_semClass
KernelState:		.long	_kernelState
WindExit:		.long	_windExit
#if (CPU==SH7600 || CPU==SH7000)
IntLockSR:		.long	_intLockTaskSR
#else
IntLockMask:		.long	_intLockMask
#endif

/******************************************************************************
*
* semOTake - VxWorks 4.x semTake
*
* Optimized version of semOTake.  This inserts the necessary argument of
* WAIT_FOREVER for semBTake.

* STATUS semOTake
*     (
*     SEM_ID semId	/@ semaphore ID to take @/
*     )
*     {
*     return (semBTake (semId, WAIT_FOREVER));
*     }

*/
	.align	2
	.type	_semOTake,@function

_semOTake:				/* r4: semId        */
	bra	_semBTake;		/*     do semBTake  */
	mov	#-1,r5			/* r5: WAIT_FOREVER */

/******************************************************************************
*
* semClear - VxWorks 4.x semClear
*
* Optimized version of semClear.  This inserts the necessary argument of
* NO_WAIT for semBTake.

* STATUS semClear
*     (
*     SEM_ID semId	/@ semaphore ID to empty @/
*     )
*     {
*     return (semBTake (semId, NO_WAIT));
*     }

*/
	.align	2
	.type	_semClear,@function

_semClear:				/* r4: semId       */
	bra	_semBTake;		/*     do semBTake */
	mov	#0,r5			/* r5: NO_WAIT     */

#endif	/* !PORTABLE */
