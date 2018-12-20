/* semALib.s - internal VxWorks kernel semaphore assembler library */

/* Copyright 1984-2001 Wind River Systems, Inc. */
	.data
	.globl	copyright_wind_river

/*
 * This file has been developed or significantly modified by the
 * MIPS Center of Excellence Dedicated Engineering Staff.
 * This notice is as per the MIPS Center of Excellence Master Partner
 * Agreement, do not remove this notice without checking first with
 * WR/Platforms MIPS Center of Excellence engineering management.
 */

/*
modification history
--------------------
02q,16oct02,agf  check for semID being NULL (spr 68917)
                 modify errno handling of semTake from ISR (spr 73802)
02p,12nov01,pcm  closed open-ended comment inside semEvRsrcSend ()
02o,30oct01,pcm  added VxWorks semaphore events
02n,01aug01,mem  Diab integration.
02m,16jul01,ros  add CofE comment
02l,12jun01,mem  Update for new coding standard.
02k,19jun00,dra  work around 5432 branch bug
02j,10sep99,myz  reworked last mod.
02i,07sep99,myz  added mips16 support.
02h,19jan99,dra	 added CW4000, CW4011, V4100, VR5000 and VR5400 support.
02g,16apr99,pr   saved volatile regs in WindView code (SPR #26766 & 26698)
02f,19aug98,pr   fixed bug for EVENT_SEMTAKE/SEMGIVE (SPR #22183)
02e,16may98,pr   temporarily excluded EVENT_SEMTAKE/SEMGIVE evtlogging
02d,21apr98,pr   fixed problems in EVENT_SEMTAKE/SEMGIVE
02c,16apr98,pr   added WindView 2.0 support
02b,13mar97,kkk  moved .set noreorder line in semQPut(), deleted extra
		 .set noreorder line in semQGet().
02a,14oct96,kkk  added R4650 support.
01z,15sep96,kkk  merge in change from ease. (fixed spr# 7154.)
01y,22feb96,mem  fixed R4000 support.  Was using SW/LW with FRAMEAx() and
		 sw/lw with FRAMERx().
01x,16may95,cd	 rewrote semQPut without noreorder section
		 the noreorder section prevented the kernel from
		 being built -G0 and a missing end of comment
		 led to accusations of bugs in the MIPS assembler
01w,23jul96,pr   added windview instrumentation.
01v,19oct93,cd   added R4000 support and enabled for all MIPS targets.
01u,05nov93,yao  added shared memory support.
01t,29sep93,caf  undid fix of SPR #2359.
01s,07jul93,yao  fixed to preserve parity error bit of status 
		 register (SPR #2359).  changed copyright notice.
01r,08aug92,ajm  corrected stack parameters
01q,30jul92,rrr  changed _sig_timeout_recalc to _func_sigTimeoutRecalc
01p,10jul92,ajm  changed semBTake jump to semTake jump
01o,09jul92,ajm  changed semQPut for new signals
01n,06jul92,ajm  split into sem[CM]ALib.s to increase modularity.
01n,04jul92,jcf  scalable/ANSI/cleanup effort.
01m,26may92,rrr  the tree shuffle
01l,15oct91,ajm   pulled in optimizations
01k,04oct91,rrr   passed through the ansification filter
                   -fixed #else and #endif
                   -changed ASMLANGUAGE to _ASMLANGUAGE
                   -changed copyright notice
01j,01aug91,ajm   removed assembler .set noreorder macros. They tend to screw
		   up assembler
01i,14may91,ajm   ported to MIPS
01h,16oct90,jcf   fixed race of priority inversion in semMGive.
01g,01oct90,dab   changed conditional compilation identifier from
		    HOST_SUN to AS_WORKS_WELL.
01f,12sep90,dab   changed complex addressing mode instructions to .word's
           +lpf     to make non-SUN hosts happy.
01e,27jun90,jcf   optimized version once again.
01d,26jun90,jcf   made PORTABLE for the nonce.
01c,10may90,jcf   added semClear optimization.
01b,23apr90,jcf   changed name and moved to src/68k.
01a,02jan90,jcf   written.
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
#include "eventLib.h"
#include "objLib.h"
#include "semLib.h"
#include "vwModNum.h"
#include "private/taskLibP.h"
#include "private/semLibP.h"
#include "private/eventP.h"
#include "private/workQLibP.h"
#include "private/eventLibP.h"

/* abstracted from private/semLibP.h (where they should be globally defined) */

#define SEM_CLASS		0x00	/* offset into SEMAPHORE */
#define SEM_SM_TYPE		0x04
		
/* optimized version available for MIPS architecture */

#if (defined(PORTABLE))
#define semALib_PORTABLE
#endif

#ifndef semALib_PORTABLE

	/* globals */

	.globl	semGive			/* optimized semGive demultiplexer */
	.globl	semTake			/* optimized semTake demultiplexer */
	.globl	semBGive		/* optimized binary semaphore give */
	.globl	semBTake		/* optimized binary semaphore take */
        .globl  semQGet			/* semaphore queue get routine */
        .globl  semQPut			/* semaphore queue put routine */
	.globl	semOTake		/* optimized old semaphore take */
	.globl	semClear		/* optimized old semaphore semClear */
	.globl	semEvRsrcSend		/* semaphore event resource send */

	/* externals */

	.extern	kernelState		/* in kernel ? */
	.extern	taskIdCurrent		/* running task */
	.extern	intCnt			/* interrupt nest counter */
	.extern	semMGiveKernWork	/* what does kern have ? */
	.extern	_func_sigTimeoutRecalc	/* signal timeout routine */
	.extern smObjPoolMinusOne	/* smObj pool local address */
	.extern	errno			/* errno */
	.extern semGiveTbl		/* semaphhore function table */
	.extern semTakeTbl		/* semahphore function table */

	.text
	.set	reorder

#ifdef WV_INSTRUMENTATION

	.extern _func_evtLogTSched	/* timestamp function pointer */
	.extern _func_trgCheck		/* timestamp function pointer */
	.extern _func_evtLogT0		/* timestamp function pointer */
	.extern evtAction	    
	.extern wvEvtClass	    
	.extern trgEvtClass	    

/* 
 * The stack carving macros for WV is redefined here , because we 
 * need to ensure 32 bit register usages, as the kernel is built 
 * with -gp32 (or use 32 bit registers), will make use of "lw"
 * instead of "ld" for R4000.
 *
 * Note that the stack is aligned at 8-byte boundary, per the ABI.
 * And, we must always carve 20 bytes for a0-a4 and ra, regardless whether
 * the callee requires a parameter or not.
 */
#define WV_FRAMESZ(routine)        _##routine##Fsize

#define WV_SETFRAME(routine,nregs) \
        WV_FRAMESZ(routine) = ((((4*4)+4*(1+(nregs))) + 7) & ~7)

/* The location at which to store the return address */

#define WV_FRAMERA(routine) \
        (WV_FRAMESZ(routine)-4)

/* 
 * Locations at which to store arguments passed on stack or
 * locally used registers 
 */

#define WV_FRAMER(routine,regn) \
        ((4*4)+(4*(regn)))
#define WV_FRAMER0(routine) WV_FRAMER(routine,0)
#define WV_FRAMER1(routine) WV_FRAMER(routine,1)
#define WV_FRAMER2(routine) WV_FRAMER(routine,2)
#define WV_FRAMER3(routine) WV_FRAMER(routine,3)
#define WV_FRAMER4(routine) WV_FRAMER(routine,4)
#define WV_FRAMER5(routine) WV_FRAMER(routine,5)
#define WV_FRAMER6(routine) WV_FRAMER(routine,6)
#define WV_FRAMER7(routine) WV_FRAMER(routine,7)
#define WV_FRAMER8(routine) WV_FRAMER(routine,8)
#define WV_FRAMER9(routine) WV_FRAMER(routine,9)
#define WV_FRAMER10(routine) WV_FRAMER(routine,10)
#define WV_FRAMER11(routine) WV_FRAMER(routine,11)
#define WV_FRAMER12(routine) WV_FRAMER(routine,12)
#define WV_FRAMER13(routine) WV_FRAMER(routine,13)

/* Locations at which to store 32bit argument registers */

#define WV_FRAMEA(routine, regn) \
          (WV_FRAMESZ(routine) + 4*(regn))
#define WV_FRAMEA0(routine) WV_FRAMEA(routine,0)
#define WV_FRAMEA1(routine) WV_FRAMEA(routine,1)
#define WV_FRAMEA2(routine) WV_FRAMEA(routine,2)
#define WV_FRAMEA3(routine) WV_FRAMEA(routine,3)

#endif /* WV_INSTRUMENTATION */

/*******************************************************************************
*
* semGiveKern - add give routine to work queue
*
*/

semGiveKern:
	j	semGiveDefer		/* let C rtn defer work and rts */

/*******************************************************************************
*
* semGive - give a semaphore
*
*
*STATUS semGive (semId)
*    SEM_ID semId;		* semaphore id to give 
* 
*/

	.ent	semGive
semGive:
        beq     a0, zero, semNULLRestrict	/* dont allow NULL ref */
	lw	v0, kernelState			/* are we in kernel state? */
	bne	zero, v0, semGiveKern		/* v0 != 0 if we are not */
	andi	t0, a0, 1			/* check if smObj id */
	beq	t0, zero, 1f			/* t0==zero, local semaphore */
	lw	t1, smObjPoolMinusOne		/* load local pool address  */	
	SETFRAME(semGive,0)
	subu	sp, FRAMESZ(semGive)		/* carve stack space */
	addu	a0, a0, t1			/* convert id to local addr */
	SW	ra, FRAMERA(semGive)(sp)	/* save return address */
	
	/* shared semaphore types are stored in network order
	 * we are only interested in the bottom byte so the
	 * following works in both bigendian and littleendian configurations
	 */
	lbu	t2, SEM_SM_TYPE+3(a0)		/* get semaphore type in t2 */
	andi	t2, 0x7				/* mask t2 */
	la	t3, semGiveTbl			/* load semaphore give table */
	sll	t2, 2				/* scale by size of (FUNCPTR) */
	addu	t3, t2, t3			/* appropriate give table */
	lw	t4, (t3)			/* get function address */
	jal	t4				/* call give func */
	LW	ra, FRAMERA(semGive)(sp)	/* get return address */
	addu 	sp, FRAMESZ(semGive)		/* pop up stack */
	j	ra
1:
#ifdef WV_INSTRUMENTATION
	/* windview instrumentation - BEGIN
	 * semGive level 1 (object status event )
	 */
	lw	t0, evtAction		/* is WV and-or triggering on? */
	beqz	t0, noSemGiveEvt

	lw	t3, SEM_CLASS(a0)
	la	t0, semClass			/* check validity */
	beq	t3, t0, objOkGive
	la	t0, semInstClass		/* check validity */
	bne	t3, t0, noSemGiveEvt    	/* invalid semaphore */
objOkGive:

        /* we are checking
         * if ((wvEvtClass&(WV_CLASS_3_ON)) != (WV_CLASS_3_ON))
         * leave WV instrumentation and check triggering
         */

        lw      t0, wvEvtClass
        li      t4, WV_CLASS_3_ON
        and     t0, t0, t4
        bne     t4, t0, trgCheckSemGive

	/* is this semaphore object instrumented? */
	lw	t0, SEM_INST_RTN(t3)		/* event routine attached? */
	beqz	t0, trgCheckSemGive

	lhu	t2, SEM_RECURSE(a0)

	/* log event for this object */

	/* 
	 * NOTE: If the following called function changes the number of
	 * parameters passed, then we need to change how we pass arguments
	 * to the function. The following assumes the called function
	 * takes 7 parameters, last two are 0.
	 */

	WV_SETFRAME(semGiveInst,11)
	subu	sp, WV_FRAMESZ(semGiveInst) /* create stack frame */
	sw	ra, WV_FRAMERA(semGiveInst)(sp)	/* save ra */
	sw	a0, WV_FRAMEA0(semGiveInst)(sp)	/* and a0 */
	sw	t2, WV_FRAMER0(semGiveInst)(sp)	/* pass t2 to 5th arg of func */
	sw	zero, WV_FRAMER1(semGiveInst)(sp) /* pass 0 to 6th arg */
	sw	zero, WV_FRAMER2(semGiveInst)(sp) /* pass 0 to 7th arg */

	/* now save the rest of the volatile register set. 
         * This is to ensure that when we come back from the C
 	 * function callout, all the register are as they were
	 * before the call since we don't know what registers
	 * the C functions have trashed that the assembly files
	 * might rely on.
	 */

	/* 
         * no need to save t0 & t4, gets trashed right after the
  	 * function call anyways. No need for v1 either.
	 */

	sw	v0, WV_FRAMER3(semGiveInst)(sp) 	/* save v0 */
	sw	t1, WV_FRAMER4(semGiveInst)(sp) 	/* save t1 */
	sw	t3, WV_FRAMER5(semGiveInst)(sp) 	/* save t3 */
	sw	t5, WV_FRAMER6(semGiveInst)(sp) 	/* save t5 */
	sw	t6, WV_FRAMER7(semGiveInst)(sp) 	/* save t6 */
	sw	t7, WV_FRAMER8(semGiveInst)(sp) 	/* save t7 */
	sw	t8, WV_FRAMER9(semGiveInst)(sp) 	/* save t8 */
	sw	t9, WV_FRAMER10(semGiveInst)(sp) 	/* save t9 */
	
	lw	a3, SEM_STATE(a0)		/* put sem state in 3rd arg */
	move	a2, a0				/* a2 = semID, 2nd arg */
	li	a1, 3				/* # of args passed to func */
	li	a0, EVENT_SEMGIVE		/* event ID, in arg0 */
	jal	t0				/* call routine */

	/* now restore all the stuff we have saved */

	lw	t9, WV_FRAMER10(semGiveInst)(sp)
	lw	t8, WV_FRAMER9(semGiveInst)(sp)
	lw	t7, WV_FRAMER8(semGiveInst)(sp)
	lw	t6, WV_FRAMER7(semGiveInst)(sp)
	lw	t5, WV_FRAMER6(semGiveInst)(sp)
	lw	t3, WV_FRAMER5(semGiveInst)(sp)
	lw	t1, WV_FRAMER4(semGiveInst)(sp)
	lw	v0, WV_FRAMER3(semGiveInst)(sp)

	lw	t2, WV_FRAMER0(semGiveInst)(sp)
	lw	a0, WV_FRAMEA0(semGiveInst)(sp)
	lw	ra, WV_FRAMERA(semGiveInst)(sp)
	addu    sp, WV_FRAMESZ(semGiveInst)

trgCheckSemGive:

        lw      t0, trgEvtClass
        li      t4, TRG_CLASS_3_ON
        and     t0, t0, t4
        bne     t4, t0, noSemGiveEvt

	lhu	t2, SEM_RECURSE(a0)
	lw	t1, SEM_STATE(a0)

	WV_SETFRAME(semGiveTrg,11)
	subu	sp, WV_FRAMESZ(semGiveTrg) /* create stack frame */
	sw	ra, WV_FRAMERA(semGiveTrg)(sp)	/* save ra */
	sw	a0, WV_FRAMEA0(semGiveTrg)(sp)	/* and a0 */
	sw	t1, WV_FRAMER0(semGiveTrg)(sp)	/* save t1, 5th arg to func */
	sw	t2, WV_FRAMER1(semGiveTrg)(sp)	/* save t2, 6th arg to func */

	/* No need to save t0 t4, since they are trashed above. 
	   Non need to save v1 either (trashed below).
	 */

	sw	zero, WV_FRAMER2(semGiveTrg)(sp)	/* 7th arg to func */
	sw	zero, WV_FRAMER3(semGiveTrg)(sp)	/* 8th arg to func */

	sw	v0, WV_FRAMER4(semGiveTrg)(sp) 	/* save v0 */
	sw	t3, WV_FRAMER5(semGiveTrg)(sp) 	/* save t3 */
	sw	t5, WV_FRAMER6(semGiveTrg)(sp) 	/* save t5 */
	sw	t6, WV_FRAMER7(semGiveTrg)(sp) 	/* save t6 */
	sw	t7, WV_FRAMER8(semGiveTrg)(sp) 	/* save t7 */
	sw	t8, WV_FRAMER9(semGiveTrg)(sp) 	/* save t8 */
	sw	t9, WV_FRAMER10(semGiveTrg)(sp) 	/* save t9 */

        move    a3, a0  		
	move	a2, a0

	li	a0, EVENT_SEMGIVE
        li      a1, TRG_CLASS3_INDEX
        lw      t1, _func_trgCheck
        jal     t1                              /* call trgCheck routine */

	/* now restore  */

	lw	t9, WV_FRAMER10(semGiveTrg)(sp)
	lw	t8, WV_FRAMER9(semGiveTrg)(sp)
	lw	t7, WV_FRAMER8(semGiveTrg)(sp)
	lw	t6, WV_FRAMER7(semGiveTrg)(sp)
	lw	t5, WV_FRAMER6(semGiveTrg)(sp)
	lw	t3, WV_FRAMER5(semGiveTrg)(sp)
	lw	v0, WV_FRAMER4(semGiveTrg)(sp)

	lw	t2, WV_FRAMER1(semGiveTrg)(sp)
	lw	t1, WV_FRAMER0(semGiveTrg)(sp)
	lw	a0, WV_FRAMEA0(semGiveTrg)(sp)
	lw	ra, WV_FRAMERA(semGiveTrg)(sp)
	addu    sp, WV_FRAMESZ(semGiveTrg)

noSemGiveEvt:
	/* windview instrumentation - END */
#endif /* WV_INSTRUMENTATION */

	lbu	v1, SEM_TYPE(a0)		/* put the sem class into v1 */
	bne	zero, v1, semGiveNotBinary	/* opt for BINARY if v1==0 */

		/* BINARY SEMAPHORE OPTIMIZATION */

semBGive:					/* a0 = semId! */
	HAZARD_VR5400
	mfc0	t0, C0_SR
	li	t1, ~SR_INT_ENABLE
	and	t1, t1, t0
	mtc0	t1, C0_SR			/* LOCK INTERRUPTS */
	HAZARD_INTERRUPT
	la	t3, semClass			/* get semClass address */
	lw	t2, SEM_CLASS(a0)		/* read semIdClass */
	bne	t2, t3, semIsInvalidUnlock	/* valid semaphore? */
1:	lw	v0, SEM_Q_HEAD(a0)		/* */
	lw	t2, SEM_STATE (a0)		/* pOwner */
	sw	v0, SEM_STATE(a0)		/* */
	bne	zero, v0, semQGet		/* if not empty get from Q */
 
	lw	t3, SEM_EVENTS_TASKID (a0)	/* Branch if either previous */
	beq	zero, t2, semGiveReturn		/* semOwner or taskId are */
	beq	zero, t3, semGiveReturn		/* NULL. */

/*
 * a0 - semId
 * t0 - was used with interrupts
 * t1 - was used with interrupts
 * t3 - semId->events.taskId
 * v0 - NULL
 * v1 - NULL
 */
semEvRsrcSend:
	li      t4, 1
	sw      t4, kernelState                 /* KERNEL ENTER */

	HAZARD_VR5400
	mtc0  t0, C0_SR                         /* UNLOCK INTERRUPTS */
	HAZARD_INTERRUPT

	lw      t4, errno
	SETFRAME(semBGive,3)                    /* Create stack frame      */
	subu    sp, FRAMESZ(semBGive)           /* Create some stack space */
	SW      ra, FRAMERA(semBGive)(sp)       /* Save return address     */
	SW      t4, FRAMER1(semBGive)(sp)       /* Save errno              */
	SW      a0, FRAMER0(semBGive)(sp)       /* Save semId              */

	lw      a1, SEM_EVENTS_REGISTERED (a0)  /* semId->events.registered */
	move    a0, t3                          /* semId->events.taskId     */
	jal     eventRsrcSend                   /* eventRsrcSend (a0, a1)   */
 
	LW      a0, FRAMER0(semBGive)(sp)       /* Restore semId  */
	LW      t4, FRAMER1(semBGive)(sp)       /* Restore errno  */
 
	/*
	 * Recall that for boolean expressions, 0 & x = 0, and 1 & x = x.  The
	 * return value of eventRsrcSend () is either OK, or ERROR (0, -1).
	 * If evSendStatus is the return value ...
	 *              evSendStatus & x = {0, evSendStatus}.
	 * Thus after AND-ing, a single test can be performed.
	 *
	 * Also recall for the boolean expressions 0 | x = x, and 1 | x = 1.
	 *              evSendStatus | x = {x, 1}
	 */
 
	move    t3, zero                        /* Default return OK */
 
	lb      t5, SEM_OPTIONS (a0)            /* Combine two tests into */
	and     t5, t5, v0                      /* one.  Refer to previous */
	andi    t5, SEM_EVENTSEND_ERR_NOTIFY    /* comments above. */
	beq     t5, zero, semBGiveEvtOptions
 
	li	t4, S_eventLib_EVENTSEND_FAILED       /* Set new errno */
 
	sub     t3, zero, 1                     /* New return value */
	sw      zero, SEM_EVENTS_TASKID (a0)    /* Clear taskId */
	j       semBGiveEvtOptionsDone
 
semBGiveEvtOptions:
	lb      t5, SEM_EVENTS_OPTIONS (a0)     /* Combine two tests into */
	or      t5, t5, v0                      /* one.  Refer to previous */
	andi    t5, t5, EVENTS_SEND_ONCE        /* comments above. */
	beq     t5, zero, semBGiveEvtOptionsDone
	sw      zero, SEM_EVENTS_TASKID (a0)    /* Clear taskId */
 
semBGiveEvtOptionsDone:
	SW      t3, FRAMER2(semBGive)(sp)       /* Save retVal to stack */
	SW      t4, FRAMER1(semBGive)(sp)       /* Save errno to stack */
 
	jal     windExit                        /* KERNEL EXIT */
 
	LW      ra, FRAMERA(semBGive)(sp)       /* Restore return address */
	LW      a0, FRAMER0(semBGive)(sp)       /* Restore semId */
	LW      t4, FRAMER1(semBGive)(sp)       /* Restore errno */
	LW      v0, FRAMER2(semBGive)(sp)       /* Restore return value */
	addu    sp, FRAMESZ(semBGive)           /* Remove stack frame */
	sw      t4, errno                       /* Update errno */
 
	j       ra                              /* Return */

	/* NEVER FALL THROUGH */

semGiveReturn:
        HAZARD_VR5400
        mtc0    t0, C0_SR               /* UNLOCK INTS */
        j       ra                      /* return, v0 still 0 for OK */

	/* NEVER FALL THROUGH */

semGiveNotBinary:

        /* call semGive indirectly via semGiveTbl.  Note that the index could
	 * equal zero after it is masked.  semBGive is the zeroeth element
	 * of the table, but for it to function correctly in the optimized
	 * version above, we must be certain not to clobber a0.  Note, also
	 * that old semaphores will also call semBGive above.
	 */

	andi	v1, 0x7			/* mask v1 */
	la	t1, semGiveTbl		/* get table address into t1 */
	sll	v1, 2			/* make word indexed */
	addu	t1, v1			/* point to give rtn */
	lw	t2, 0(t1)		/* get right give rtn for this class */
	j	t2			/* invoke give rtn, it will do rts */
	.end	semGive

/*******************************************************************************
*
* semIsInvalid - unlock interupts and call semInvalid ().
*/

semIsInvalidUnlock:
	HAZARD_VR5400
	mtc0	t0, C0_SR		/* UNLOCK INTS */
semIsInvalid:
	j	semInvalid		/* let C rtn do work and rts */

/*******************************************************************************
*
* semNULLRestrict - set errno and return ERROR
*
* The C routine for semInvalid does not work in the case where a semID is
* NULL. It will attempt to ref the NULL semID. Instead, set errno manually & 
* return
*/
semNULLRestrict:
	li	t0, S_objLib_OBJ_ID_ERROR	/* load error ID */
	sw	t0, errno			/* set errno */
	li	v0, ERROR			/* return ERROR */
	j	ra

/*******************************************************************************
*
* semTakeIntRestrict - call semIntRestrict ().
*/
semTakeIntRestrict:
	j	semIntRestrict		/* let C rtn do work and rts */


/*******************************************************************************
*
* semTake - take a semaphore
*

*STATUS semTake (semId, timeout)
*    SEM_ID semId;		/* semaphore id to give *
*    ULONG  timeout;		/* timeout in ticks *

*/

	.ent	semTake
semTake:
	beq	a0, zero, semNULLRestrict	/* dont allow NULL ref */
	lw	t0, intCnt			/* read intCnt */
	bne	zero, t0, semTakeIntRestrict	/* intCnt > 0, no isr use */
	andi	t0, a0, 1			/* check if smObj id */
	beq	t0, zero, 2f			/* t0==zero, local semaphore */
	lw	t1, smObjPoolMinusOne		/* load local pool address */
	SETFRAME(semTake,0)
	subu	sp, FRAMESZ(semTake)		/* carve stack space */
	addu	a0, a0, t1			/* convert id to local addr */
	SW	ra, FRAMERA(semTake)(sp)	/* save return address */
	/* shared semaphore types are stored in network order
	 * we are only interested in the bottom byte so the
	 * following works in both bigendian and littleendian configurations
	 */
	lbu	t2, SEM_SM_TYPE+3(a0)		/* get semaphore type in t2 */
	andi	t2, 0x7				/* mask t2 */
	la	t3, semTakeTbl			/* load semaphore give table */
	sll	t2, 2				/* scale by size of (FUNCPTR) */
	addu	t3, t2, t3			/* appropriate give table */
	lw	t4, (t3)			/* get appropriate take table */
	jal	t4				/* call take func */
	LW	ra, FRAMERA(semTake)(sp)	/* get return address */
	addu 	sp, FRAMESZ(semTake)		/* pop up stack */
	j	ra
2:
#ifdef WV_INSTRUMENTATION

	/* windview instrumentation - BEGIN
	 * semTake level 1 (object status event )
	 */
	lw	t0, evtAction		    /* is level 1 event collection on? */
	beqz	t0, noSemTakeEvt

        lw      t3, SEM_CLASS(a0)
        la      t0, semClass                    /* check validity */
        beq     t3, t0, objOkTake
        la      t0, semInstClass                /* check validity */
        bne     t3, t0, noSemTakeEvt            /* invalid semaphore */
objOkTake:

        /* we are checking
         * if ((wvEvtClass&(WV_CLASS_3_ON)) != (WV_CLASS_3_ON))
         * leave WV instrumentation and check triggering
         */
        lw      t0, wvEvtClass
        li      t4, WV_CLASS_3_ON
        and     t0, t0, t4
        bne     t4, t0, trgCheckSemTake

	/* is this semaphore object instrumented? */
        lw      t0, SEM_INST_RTN(t3)            /* event routine attached? */
	beqz	t0, noSemTakeEvt


	/* log event for this object */

        lhu     t2, SEM_RECURSE(a0)

        WV_SETFRAME(semTakeInst,11)
        subu    sp, WV_FRAMESZ(semTakeInst) /* create stack frame */
        sw      ra, WV_FRAMERA(semTakeInst)(sp) /* save ra */
        sw      a0, WV_FRAMEA0(semTakeInst)(sp)    /* and a0 */
        sw      a1, WV_FRAMEA1(semTakeInst)(sp)    /* and a0 */
        sw      t2, WV_FRAMER0(semTakeInst)(sp) /* pass t2, 5th arg to func */
        sw      zero, WV_FRAMER1(semTakeInst)(sp) /* pass 0 to 6th arg */
        sw      zero, WV_FRAMER2(semTakeInst)(sp) /* pass 0 to 7th arg */


        /* now save the rest of the volatile register set.
         * This is to ensure that when we come back from the C
         * function callout, all the register are as they were
         * before the call since we don't know what registers
         * the C functions have trashed that the assembly files
         * might rely on.
         */

        /*
         * no need to save t0 & t4, gets trashed right after the
         * function call anyways.
         */

        sw      v0, WV_FRAMER3(semTakeInst)(sp)         /* save v0 */
        sw      t1, WV_FRAMER4(semTakeInst)(sp)         /* save t1 */
        sw      t3, WV_FRAMER5(semTakeInst)(sp)         /* save t3 */
        sw      t5, WV_FRAMER6(semTakeInst)(sp)         /* save t5 */
        sw      t6, WV_FRAMER7(semTakeInst)(sp)         /* save t6 */
        sw      t7, WV_FRAMER8(semTakeInst)(sp)         /* save t7 */
        sw      t8, WV_FRAMER9(semTakeInst)(sp)        /* save t8 */
        sw      t9, WV_FRAMER10(semTakeInst)(sp)        /* save t9 */

        lw      a3, SEM_STATE(a0)
        move    a2, a0                          /* a2 = semID */
        li      a1, 3                           /* # of args passed to func */
        li      a0, EVENT_SEMTAKE               /* event ID */

        jal     t0                              /* call routine */

        /* now restore all the stuff we have saved */

        lw      t9, WV_FRAMER10(semTakeInst)(sp)
        lw      t8, WV_FRAMER9(semTakeInst)(sp)
        lw      t7, WV_FRAMER8(semTakeInst)(sp)
        lw      t6, WV_FRAMER7(semTakeInst)(sp)
        lw      t5, WV_FRAMER6(semTakeInst)(sp)
        lw      t3, WV_FRAMER5(semTakeInst)(sp)
        lw      t1, WV_FRAMER4(semTakeInst)(sp)
        lw      v0, WV_FRAMER3(semTakeInst)(sp)

        lw      t2, WV_FRAMER0(semTakeInst)(sp)
        lw      a0, WV_FRAMEA0(semTakeInst)(sp)
        lw      a1, WV_FRAMEA1(semTakeInst)(sp)
        lw      ra, WV_FRAMERA(semTakeInst)(sp)
        addu    sp, WV_FRAMESZ(semTakeInst)

trgCheckSemTake:

        lw      t0, trgEvtClass
        li      t4, TRG_CLASS_3_ON
        and     t0, t0, t4
        bne     t4, t0, noSemTakeEvt

        lhu     t2, SEM_RECURSE(a0)
        lw      t1, SEM_STATE(a0)

        WV_SETFRAME(semTakeTrg,11)
        subu    sp, WV_FRAMESZ(semTakeTrg) /* create stack frame */
        sw      ra, WV_FRAMERA(semTakeTrg)(sp) /* save ra */
        sw      a0, WV_FRAMEA0(semTakeTrg)(sp)    /* and a0 */
        sw      a1, WV_FRAMEA1(semTakeTrg)(sp)    /* and a0 */
        sw      t1, WV_FRAMER0(semTakeTrg)(sp) /* save t1, 5th arg to func */
        sw      t2, WV_FRAMER1(semTakeTrg)(sp) /* save t2, 6th arg to func */

        /* now save the rest of the volatile register set.
         * This is to ensure that when we come back from the C
         * function callout, all the register are as they were
         * before the call since we don't know what registers
         * the C functions have trashed that the assembly files
         * might rely on.
         */

        /* No need to save t0 & t4, since they are trashed above */

        sw      zero, WV_FRAMER2(semTakeTrg)(sp)        /* 7th arg to func */
        sw      zero, WV_FRAMER3(semTakeTrg)(sp)        /* 8th arg to func */

        sw      v0, WV_FRAMER4(semTakeTrg)(sp)         /* save v0 */
        sw      t3, WV_FRAMER5(semTakeTrg)(sp)         /* save t3 */
        sw      t5, WV_FRAMER6(semTakeTrg)(sp)         /* save t5 */
        sw      t6, WV_FRAMER7(semTakeTrg)(sp)         /* save t6 */
        sw      t7, WV_FRAMER8(semTakeTrg)(sp)        /* save t7 */
        sw      t8, WV_FRAMER9(semTakeTrg)(sp)        /* save t8 */
        sw      t9, WV_FRAMER10(semTakeTrg)(sp)        /* save t9 */

        lw      a3, SEM_STATE(a0)
        move    a3, a0
        move    a2, a0

        li      a0, EVENT_SEMTAKE
	li      a1, TRG_CLASS3_INDEX

        lw      t1, _func_trgCheck
        jal     t1                              /* call trgCheck routine */

        /* Now restore */

        lw      t9, WV_FRAMER10(semTakeTrg)(sp)
        lw      t8, WV_FRAMER9(semTakeTrg)(sp)
        lw      t7, WV_FRAMER8(semTakeTrg)(sp)
        lw      t6, WV_FRAMER7(semTakeTrg)(sp)
        lw      t5, WV_FRAMER6(semTakeTrg)(sp)
        lw      t3, WV_FRAMER5(semTakeTrg)(sp)
        lw      v0, WV_FRAMER4(semTakeTrg)(sp)

        lw      t2, WV_FRAMER1(semTakeTrg)(sp)
        lw      t1, WV_FRAMER0(semTakeTrg)(sp)
        lw      a0, WV_FRAMEA0(semTakeTrg)(sp)
        lw      a1, WV_FRAMEA1(semTakeTrg)(sp)
        lw      ra, WV_FRAMERA(semTakeTrg)(sp)
        addu    sp, WV_FRAMESZ(semTakeTrg)

noSemTakeEvt:
	/* windview instrumentation - END */

#endif /* WV_INSTRUMENTATION */
	lbu	v1, SEM_TYPE(a0)		/* get semaphore class
						   into v1 */
	bne	zero, v1, semTakeNotBinary	/* optimize binary
						   semaphore v1 == 0 */
		/* BINARY SEMAPHORE OPTIMIZATION */
semBTake:					/* a0 = semId! */
	.set	noreorder
	HAZARD_VR5400
	mfc0	t0, C0_SR
	HAZARD_CP_READ
	li	t1, ~SR_INT_ENABLE
	and	t1, t1, t0
	mtc0	t1, C0_SR			/* LOCK INTERRUPTS */
	HAZARD_INTERRUPT
	la	t3, semClass			/* get semClass address */
	.set	reorder
	lw	t2, SEM_CLASS(a0)		/* read semIdClass */
	bne	t2, t3, semIsInvalidUnlock	/* valid semaphore? */
1:	lw	v0, SEM_STATE(a0)		/* test for owner */
	bne	zero, v0, semQPut		/* if sem is owned we block */
	lw	t3, taskIdCurrent		/* get tidc */
	sw	t3, SEM_STATE(a0)		/* now we own it */
	HAZARD_VR5400
	mtc0	t0, C0_SR			/* UNLOCK INTS */
	HAZARD_INTERRUPT
	j	ra				/* return, v0 still zero */
semTakeNotBinary:
	andi	v1, 0x7			/* mask v1 to sane value */
	la	t1, semTakeTbl		/* get table address into t1 */
	sll	v1, 2			/* make word indexed */
	addu	t1, v1			/* point to give rtn */
	lw	t2, 0(t1)		/* get right give rtn for this class */
	j	t2			/* invoke give rtn, it will do rts */
	.end	semTake

/*******************************************************************************
*
* semQGet - unblock a task from the semaphore queue head
*/

	.ent	semQGet
semQGet:
	SETFRAME(semQGet,1)		/* create stack frame */
	subu	sp, FRAMESZ(semQGet)	/* create stack frame */
	SW	ra, FRAMERA(semQGet)(sp) /* save ra */
	li	t1, 1			/* load TRUE */
	sw	t1, kernelState		/* KERNEL ENTER */
#ifdef WV_INSTRUMENTATION

	/* windview instrumentation - BEGIN
	 * semGive level 2 (task transition state event )
	 */
        lw      t1, evtAction           /* is WV and-or triggering on? */
        beqz    t1, noSemQGetEvt

	sw	t0, FRAMER0(semQGet)(sp) /* save old sr value */
	SW	a0, FRAMEA0(semQGet)(sp)

        /* we are checking
         * if ((wvEvtClass&(WV_CLASS_2_ON)) != (WV_CLASS_2_ON))
         * leave WV instrumentation and check triggering
         */

        lw      t0, wvEvtClass
        li      t1, WV_CLASS_2_ON
        and     t0, t0, t1
        bne     t1, t0, trgCheckSemQGet

        WV_SETFRAME(semQGetInst,10)
        subu    sp, WV_FRAMESZ(semQGetInst) /* create stack frame */
        sw      ra, WV_FRAMERA(semQGetInst)(sp) /* save ra */

        /* now save the rest of the volatile register set. 
         * This is to ensure that when we come back from the C
         * function callout, all the register are as they were
         * before the call since we don't know what registers
         * the C functions have trashed that the assembly files
         * might rely on.
         */

	/* 
         * no need to save t0 (is saved above) & t1 (gets trashed anyways).
         */

        sw      v0, WV_FRAMER0(semQGetInst)(sp)         /* save v0 */
        sw      v1, WV_FRAMER1(semQGetInst)(sp)         /* save v1 */
        sw      t2, WV_FRAMER2(semQGetInst)(sp) 	/* save t2 */
        sw      t3, WV_FRAMER3(semQGetInst)(sp)         /* save t3 */
        sw      t4, WV_FRAMER4(semQGetInst)(sp)         /* save t4 */
        sw      t5, WV_FRAMER5(semQGetInst)(sp)         /* save t5 */
        sw      t6, WV_FRAMER6(semQGetInst)(sp)         /* save t6 */
        sw      t7, WV_FRAMER7(semQGetInst)(sp)         /* save t7 */
        sw      t8, WV_FRAMER8(semQGetInst)(sp)         /* save t8 */
        sw      t9, WV_FRAMER9(semQGetInst)(sp)         /* save t9 */
        
	lw	t1, _func_evtLogM1      /* call event log routine */
	beqz	t1, trgCheckSemQGet

	move	a1, a0
	li	a0, EVENT_OBJ_SEMGIVE
	jal	t1			 /* call event log routine */

        /* now restore all the stuff we have saved */

        lw      t9, WV_FRAMER9(semQGetInst)(sp)
        lw      t8, WV_FRAMER8(semQGetInst)(sp)
        lw      t7, WV_FRAMER7(semQGetInst)(sp)
        lw      t6, WV_FRAMER6(semQGetInst)(sp)
        lw      t5, WV_FRAMER5(semQGetInst)(sp)
        lw      t4, WV_FRAMER4(semQGetInst)(sp)
        lw      t3, WV_FRAMER3(semQGetInst)(sp)
        lw      t2, WV_FRAMER2(semQGetInst)(sp)
        lw      v1, WV_FRAMER1(semQGetInst)(sp)
        lw      v0, WV_FRAMER0(semQGetInst)(sp)

	lw	ra, WV_FRAMERA(semQGetInst)(sp)
	addu    sp, WV_FRAMESZ(semQGetInst)

trgCheckSemQGet:

        lw      t0, trgEvtClass
        li      t1, TRG_CLASS_2_ON
        and     t0, t0, t1
        bne     t1, t0, restoreSemQGetEvt

	li	a0, EVENT_OBJ_SEMGIVE
	li      a1, TRG_CLASS2_INDEX
	li      a2, 0x0
	LW      a3, FRAMEA0(semQGet)(sp)

        WV_SETFRAME(semQGetTrg,14)
        subu    sp, WV_FRAMESZ(semQGetTrg) /* create stack frame */
        sw      ra, WV_FRAMERA(semQGetTrg)(sp) /* save ra */

        sw      zero, WV_FRAMER0(semQGetTrg)(sp)         /* save v0 */
        sw      zero, WV_FRAMER1(semQGetTrg)(sp)         /* save v0 */
        sw      zero, WV_FRAMER2(semQGetTrg)(sp)         /* save v0 */
        sw      zero, WV_FRAMER3(semQGetTrg)(sp)         /* save v0 */

        /* now save the rest of the volatile register set. 
         * This is to ensure that when we come back from the C
         * function callout, all the register are as they were
         * before the call since we don't know what registers
         * the C functions have trashed that the assembly files
         * might rely on.
         */

       /* 
         * no need to save t0 (is saved above) & t1 (gets trashed anyway).
        */

        sw      v0, WV_FRAMER4(semQGetTrg)(sp)         /* save v0 */
        sw      v1, WV_FRAMER5(semQGetTrg)(sp)         /* save v1 */
        sw      t2, WV_FRAMER6(semQGetTrg)(sp) 	/* save t2 */
        sw      t3, WV_FRAMER7(semQGetTrg)(sp)         /* save t3 */
        sw      t4, WV_FRAMER8(semQGetTrg)(sp)         /* save t4 */
        sw      t5, WV_FRAMER9(semQGetTrg)(sp)         /* save t5 */
        sw      t6, WV_FRAMER10(semQGetTrg)(sp)         /* save t6 */
        sw      t7, WV_FRAMER11(semQGetTrg)(sp)         /* save t7 */
        sw      t8, WV_FRAMER12(semQGetTrg)(sp)         /* save t8 */
        sw      t9, WV_FRAMER13(semQGetTrg)(sp)         /* save t9 */

        lw      t1, _func_trgCheck
        jal     t1                              /* call trgCheck routine */

        /* now restore all the stuff we have saved */

        lw      t9, WV_FRAMER13(semQGetTrg)(sp)
        lw      t8, WV_FRAMER12(semQGetTrg)(sp)
        lw      t7, WV_FRAMER11(semQGetTrg)(sp)
        lw      t6, WV_FRAMER10(semQGetTrg)(sp)
        lw      t5, WV_FRAMER9(semQGetTrg)(sp)
        lw      t4, WV_FRAMER8(semQGetTrg)(sp)
        lw      t3, WV_FRAMER7(semQGetTrg)(sp)
        lw      t2, WV_FRAMER6(semQGetTrg)(sp)
        lw      v1, WV_FRAMER5(semQGetTrg)(sp)
        lw      v0, WV_FRAMER4(semQGetTrg)(sp)

	lw	ra, WV_FRAMERA(semQGetTrg)(sp)
	addu    sp, WV_FRAMESZ(semQGetTrg)
restoreSemQGetEvt:

	lw	t0, FRAMER0(semQGet)(sp)
	LW	a0, FRAMEA0(semQGet)(sp)
noSemQGetEvt:
	/* windview instrumentation - END */

#endif /* WV_INSTRUMENTATION */
	HAZARD_VR5400
	mtc0	t0, C0_SR		/* UNLOCK INTS */
	la	a0, SEM_Q_HEAD(a0)	/* pass pointer to qHead */
	jal	windPendQGet		/* unblock someone */
	jal	windExit		/* KERNEL EXIT */
	LW	ra, FRAMERA(semQGet)(sp) /* restore ra */
	addu	sp, FRAMESZ(semQGet)	/* clean up stack */
	j	ra			/* windExit sets v0 */
	.end	semQGet

/*******************************************************************************
*
* semQPut - block current task on the semaphore queue head
*/

	.ent	semQPut
semQPut:
	SETFRAME(semQPut,1)
	subu	sp, FRAMESZ(semQPut)	/* create stack frame */
	sw	a1, FRAMEA1(semQPut)(sp) /* save timeout */
	sw	a0, FRAMEA0(semQPut)(sp) /* save semId */
	SW	ra, FRAMERA(semQPut)(sp) /* save ra */
	li	t1, 1			/* load TRUE */
	sw	t1, kernelState		/* KERNEL ENTER */
#ifdef WV_INSTRUMENTATION
	/* windview instrumentation - BEGIN
	 * semTake level 2 (task transition state event )
	 */
        lw      t1, evtAction           /* is WV and-or triggering on? */
        beqz    t1, noSemQPutEvt

	sw	t0, FRAMER0(semQPut)(sp) /* save old sr value */

        /* we are checking
         * if ((wvEvtClass&(WV_CLASS_2_ON)) != (WV_CLASS_2_ON))
         * leave WV instrumentation and check triggering
         */

        lw      t0, wvEvtClass
        li      t1, WV_CLASS_2_ON
        and     t0, t0, t1
        bne     t1, t0, trgCheckSemQPut

        WV_SETFRAME(semQPutInst,10)
        subu    sp, WV_FRAMESZ(semQPutInst) /* create stack frame */
        sw      ra, WV_FRAMERA(semQPutInst)(sp) /* save ra */

        /* now save the rest of the volatile register set. 
         * This is to ensure that when we come back from the C
         * function callout, all the register are as they were
         * before the call since we don't know what registers
         * the C functions have trashed that the assembly files
         * might rely on.
         */

       /* 
         * no need to save t0 (is saved above) & t1 (gets trashed anyways).
         */

        sw      v0, WV_FRAMER0(semQPutInst)(sp)         /* save v0 */
        sw      v1, WV_FRAMER1(semQPutInst)(sp)         /* save v1 */
        sw      t2, WV_FRAMER2(semQPutInst)(sp)         /* save t2 */
        sw      t3, WV_FRAMER3(semQPutInst)(sp)         /* save t3 */
        sw      t4, WV_FRAMER4(semQPutInst)(sp)         /* save t4 */
        sw      t5, WV_FRAMER5(semQPutInst)(sp)         /* save t5 */
        sw      t6, WV_FRAMER6(semQPutInst)(sp)         /* save t6 */
        sw      t7, WV_FRAMER7(semQPutInst)(sp)         /* save t7 */
        sw      t8, WV_FRAMER8(semQPutInst)(sp)         /* save t8 */
        sw      t9, WV_FRAMER9(semQPutInst)(sp)         /* save t9 */
        
	lw	t1, _func_evtLogM1      /* call event log routine */
	beqz	t1, trgCheckSemQPut

	move	a1, a0
	li	a0, EVENT_OBJ_SEMTAKE
	jal	t1			/* call event log routine */

        /* now restore all the stuff we have saved */

        lw      t9, WV_FRAMER9(semQPutInst)(sp)
        lw      t8, WV_FRAMER8(semQPutInst)(sp)
        lw      t7, WV_FRAMER7(semQPutInst)(sp)
        lw      t6, WV_FRAMER6(semQPutInst)(sp)
        lw      t5, WV_FRAMER5(semQPutInst)(sp)
        lw      t4, WV_FRAMER4(semQPutInst)(sp)
        lw      t3, WV_FRAMER3(semQPutInst)(sp)
        lw      t2, WV_FRAMER2(semQPutInst)(sp)
        lw      v1, WV_FRAMER1(semQPutInst)(sp)
        lw      v0, WV_FRAMER0(semQPutInst)(sp)

	lw	ra, WV_FRAMERA(semQPutInst)(sp)
	addu    sp, WV_FRAMESZ(semQPutInst)

trgCheckSemQPut:

        lw      t0, trgEvtClass
        li      t1, TRG_CLASS_2_ON
        and     t0, t0, t1
        bne     t1, t0, restoreSemQPutEvt

        li      a0, EVENT_OBJ_SEMTAKE
	li      a1, TRG_CLASS2_INDEX
	li      a2, 0x0
	LW      a3, FRAMEA0(semQPut)(sp)

        WV_SETFRAME(semQPutTrg,10)
        subu    sp, WV_FRAMESZ(semQPutTrg) /* create stack frame */
        sw      ra, WV_FRAMERA(semQPutTrg)(sp) /* save ra */

        /* now save the rest of the volatile register set. 
         * This is to ensure that when we come back from the C
         * function callout, all the register are as they were
         * before the call since we don't know what registers
         * the C functions have trashed that the assembly files
         * might rely on.
         */

       /* 
         * no need to save t0 (is saved above) & t1 (gets trashed anyways).
         */

        sw      v0, WV_FRAMER0(semQPutTrg)(sp)         /* save v0 */
        sw      v1, WV_FRAMER1(semQPutTrg)(sp)         /* save v1 */
        sw      t2, WV_FRAMER2(semQPutTrg)(sp)         /* save t2 */
        sw      t3, WV_FRAMER3(semQPutTrg)(sp)         /* save t3 */
        sw      t4, WV_FRAMER4(semQPutTrg)(sp)         /* save t4 */
        sw      t5, WV_FRAMER5(semQPutTrg)(sp)         /* save t5 */
        sw      t6, WV_FRAMER6(semQPutTrg)(sp)         /* save t6 */
        sw      t7, WV_FRAMER7(semQPutTrg)(sp)         /* save t7 */
        sw      t8, WV_FRAMER8(semQPutTrg)(sp)         /* save t8 */
        sw      t9, WV_FRAMER9(semQPutTrg)(sp)         /* save t9 */

        lw      t1, _func_trgCheck
        jal     t1                              /* call trgCheck routine */

        /* now restore all the stuff we have saved */

        lw      t9, WV_FRAMER9(semQPutTrg)(sp)
        lw      t8, WV_FRAMER8(semQPutTrg)(sp)
        lw      t7, WV_FRAMER7(semQPutTrg)(sp)
        lw      t6, WV_FRAMER6(semQPutTrg)(sp)
        lw      t5, WV_FRAMER5(semQPutTrg)(sp)
        lw      t4, WV_FRAMER4(semQPutTrg)(sp)
        lw      t3, WV_FRAMER3(semQPutTrg)(sp)
        lw      t2, WV_FRAMER2(semQPutTrg)(sp)
        lw      v1, WV_FRAMER1(semQPutTrg)(sp)
        lw      v0, WV_FRAMER0(semQPutTrg)(sp)

	lw	ra, WV_FRAMERA(semQPutTrg)(sp)
	addu    sp, WV_FRAMESZ(semQPutTrg)

restoreSemQPutEvt:
	lw	t0, FRAMER0(semQPut)(sp)
	lw	a0, FRAMEA0(semQPut)(sp)
	lw	a1, FRAMEA1(semQPut)(sp)

noSemQPutEvt:
	/* windview instrumentation - END */

#endif /* WV_INSTRUMENTATION */
	.set	noreorder
	HAZARD_VR5400
	mtc0	t0, C0_SR		/* UNLOCK INTS */
	.set	reorder
	addiu	a0, SEM_Q_HEAD		/* pass pointer to qHead */
	jal	windPendQPut		/* block on semaphore */
	bne	zero, v0, semQPutFail	/* if (return != OK) */
	jal	windExit		/* else KERNEL EXIT */
	li	t1, 1			/* load RESTART */
        lw	t0, _func_sigTimeoutRecalc /* load sig timeout rtn */
	beq	v0, t1, semRestart	/* again if windExit == RESTART */
	LW	ra, FRAMERA(semQPut)(sp) /* restore ra */
	addu	sp, FRAMESZ(semQPut)	/* clean up stack */
	j	ra			/* windExit sets v0 */
semQPutFail:
	jal	windExit		/* KERNEL EXIT */
	LW	ra, FRAMERA(semQPut)(sp) /* restore ra */
	li	v0, -1			/* return ERROR */
	addu	sp, FRAMESZ(semQPut)	/* clean up stack */
	j	ra			/* return to sender */
semRestart:
        lw	a0, FRAMEA1(semQPut)(sp) /* semRestart needs timeout param */
        jal	t0			/* recalc the timeout */
        move	a1, v0			/* and store it */
	lw	a0, FRAMEA0(semQPut)(sp) /* restore semId */
	LW	ra, FRAMERA(semQPut)(sp)/* restore ra */
	addu	sp, FRAMESZ(semQPut)	/* clean up stack */
        j	semTake                 /* start the whole thing over */
	.end	semQPut

/*******************************************************************************
*
* semOTake - VxWorks 4.x semTake
*
* Optimized version of semOTake.  This inserts the necessary argument of
* WAIT_FOREVER for semBTake.
*/

	.ent	semOTake
semOTake:
	SETFRAME(semOTake,0)
	subu	sp, FRAMESZ(semOTake) /* create stack frame */
	SW	ra, FRAMERA(semOTake)(sp) /* save ra */
	li	a1, -1		/* pass WAIT_FOREVER */
	jal	semBTake	/* call semTake */
	LW	ra, FRAMERA(semOTake)(sp) /* restore ra */
	addu	sp, FRAMESZ(semOTake) /* clean up stack frame */
	j	ra		/* and return */
	.end	semOTake

/*******************************************************************************
*
* semClear - VxWorks 4.x semClear
*
* Optimized version of semClear.  This inserts the necessary argument of
* NO_WAIT for semBTake.
*/

	.ent	semClear
semClear:
	SETFRAME(semClear,0)
	subu	sp, FRAMESZ(semClear) /* create stack frame */
	SW	ra, FRAMERA(semClear)(sp) /* save ra */
	move	a1, zero	/* pass NO_WAIT */
	jal	semBTake	/* do semBTake */
	LW	ra, FRAMERA(semClear)(sp) /* restore ra */
	addu	sp, FRAMESZ(semClear) /* clean stack frame */
	j	ra		/* cleanup */
	.end	semClear

#endif /* semALib_PORTABLE */
