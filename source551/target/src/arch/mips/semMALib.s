/* semMALib.s - internal VxWorks kernel semaphore assembler library */

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
01r,01oct01,pcm  added VxWorks semaphore events
01q,01aug01,mem  Diab integration
01p,16jul01,ros  add CofE comment
01o,12jun01,mem  Update for new coding standard.
01n,19jun00,dra  work around 5432 branch bug
01m,10sep99,myz  reworked last mod.
01l,07sep99,myz  added mips16 support.
01k,19jan99,dra  added CW4000, CW4011, VR4100, VR5000 and VR5400 support.
01j,15apr99,kk   fixed bug in semMGive (SPR# 26766 & 26698)
01i,15jul96,cah  added R4650 support
01h,22feb96,mem  fixed R4000 support.  Was using sw/lw with FRAMERx().
01g,18oct93,cd   added R4000 support and enabled for all MIPS targets.
01f,29sep93,caf  undid fix of SPR #2359.
01e,07jul93,yao  fixed to preserve parity error bit of status 
		 register (SPR #2359).  changed copyright notice.
01d,04aug92,ajm  fixed for signal restart
01c,28jul92,rrr  removed semMTakeKern, however restart does not work
01b,10jul92,ajm  added semMTakeKern for signals
01a,06jun92,ajm  extracted from semALib.s v1n.
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
#include "private/workQLibP.h"
#include "private/semLibP.h"

/* optimized version available for MIPS targets */


#if (defined(PORTABLE))
#define semMALib_PORTABLE
#endif

#ifndef semMALib_PORTABLE

	/* globals */

	.globl	semMGive		/* optimized mutex semaphore give */
	.globl	semMTake		/* optimized mutex semaphore take */

	/* externals */

	.extern	kernelState			/* in kernel ? */
	.extern	taskIdCurrent			/* running task */
	.extern	intCnt				/* interrupt nest counter */
	.extern	semMGiveKernWork		/* what does kern have ? */
	.extern	_func_sigTimeoutRecalc		/* timeout recalculation */

	.text
	.set	reorder

/*******************************************************************************
*
* semMGive - optimized give of a counting semaphore
*

*STATUS semMGive (semId)
*    SEM_ID semId;		/* semaphore id to give *

*/

semMIntRestrict:
	j	semIntRestrict			/* let C do the work */

semMRecurse:
	lhu	t3, SEM_RECURSE(a0)		/* else {read recurse count */
	subu	t3, 1				/* decrement recurse count */
	sh	t3, SEM_RECURSE(a0)		/* store recurse count} */
	move 	v0, zero			/* make sure return is 0 */
	HAZARD_VR5400
        mtc0    t0, C0_SR			/* UNLOCK INTS */
	j	ra				/* and return */

	.ent	semMGive
semMGive:					/* a0 = semId! d0 = 0! */
	lw	v1, taskIdCurrent		/* taskIdCurrent into v1 */
	lw	t2, intCnt			/* read intCnt */
	bne	zero, t2, semMIntRestrict	/* intCnt > 0, no isr use */
	la	t3, semClass			/* get class address */

	HAZARD_VR5400
	mfc0	t0, C0_SR
	li	t1, ~SR_INT_ENABLE
	and	t1, t1, t0
	mtc0	t1, C0_SR			/* LOCK INTERRUPTS */
	HAZARD_INTERRUPT

	lw	t2, 0(a0)			/* read semClass */
	bne	t2, t3, semIsInvalidUnlock	/* check validity */
	lw	t3, SEM_STATE(a0)		/* taskIdCurrent is owner ? */
	bne	v1, t3, semIsInvalidUnlock	/* SEM_INVALID_OPERATION */
	lhu	t2, SEM_RECURSE(a0)		/* is recurse count > 0 ? */
	bne	zero, t2, semMRecurse		/* handle recursion */
semMInvCheck:
	lbu	t2, SEM_OPTIONS(a0)		/* read sem options */
	andi	t2, 8				/* sem inversion safe? */
	beq	zero, t2, semMQLock		/* if not, test semQ */
	lw	t3, WIND_TCB_MUTEX_CNT(v1)	/* else {read mutex count */
	subu	t3, 1				/* decrement mutex count */
	sw	t3, WIND_TCB_MUTEX_CNT(v1)	/* store mutex count} */
	bne	zero, t3, semMQLock		/* if t3 != 0, test semQ */

	lw	v0, WIND_TCB_PRIORITY(v1)	/* put priority in v0 */
	lw	t2, WIND_TCB_PRI_NORMAL(v1)	/* put normal prio in t2 */
	subu	v0, v0, t2			/* subtract normal priority */
	beq	zero, v0, semMStateSet		/* if same test semQ */
	li	v0, 4				/* or in PRIORITY_RESORT */
	j	semMStateSet			/* now test mutex sem Q */
semMQLock:
	move	v0, zero		/* make sure v0 is 0 for semMStateSet */
semMStateSet:
	lw	t3, SEM_Q_HEAD(a0)		/* read head */
	sw	t3, SEM_STATE(a0)		/* update semaphore state */
	beq	zero, t3, semMEventRsrcSend	/* anyone need to be got? */
	ori	v0, 1				/* set SEM_Q_GET */
	j	semMDelSafe

semMEventRsrcSend:
	lw	t4, SEM_EVENTS_TASKID (a0)
	beq	zero, t4, semMDelSafe
	ori	v0, SEM_M_SEND_EVENTS

semMDelSafe:
	lbu	t2, SEM_OPTIONS(a0)		/* read sem options */
	andi	t2, 4				/* sem delete safe? */
	beq	zero, t2, semMShortCut		/* check for short cut */
	lw	t3, WIND_TCB_SAFE_CNT(v1)	/* else {read safety count */
	subu	t3, 1				/* decrement safety count */
	sw	t3, WIND_TCB_SAFE_CNT(v1)	/* store safety count} */
	bne	zero, t3, semMShortCut		/* check for short cut */
	lw	t4, WIND_TCB_SAFETY_Q_HEAD(v1)	/* check for pended deleters */
	beq	zero, t4, semMShortCut		/* check for short cut */
	ori	v0, 2				/* set SAFETY_Q_FLUSH */
semMShortCut:
	bne	zero, v0, semMKernWork	/* any work for kernel level? */
	HAZARD_VR5400
	mtc0	t0, C0_SR		/* UNLOCK INTS */
	j	ra			/* v0 still 0 for OK */
semMKernWork:
	li	t2, 1			/* load immidiate value */
	sw	t2, kernelState		/* KERNEL ENTER */
	sw	v0, semMGiveKernWork	/* setup work for semMGiveKern */
	HAZARD_VR5400
	mtc0	t0, C0_SR		/* UNLOCK INTS */
	j	semMGiveKern		/* finish semMGive in C */
	.end	semMGive

/*******************************************************************************
*
* semMTake - optimized take of a mutex semaphore
*

*STATUS semMTake (semId)
*    SEM_ID semId;		/* semaphore id to give *

*/

	.ent	semMTake
semMTake:					/* a0 = semId! */
	lw	v1, taskIdCurrent		/* taskIdCurrent into v1 */
	HAZARD_VR5400
	mfc0	t0, C0_SR
	li	t1, ~SR_INT_ENABLE
	and	t1, t1, t0
	mtc0	t1, C0_SR			/* LOCK INTERRUPTS */
	HAZARD_INTERRUPT
	la	t2, semClass			/* read semClass address */
	lw	t3, 0(a0)			/* read class address */
	bne	t2, t3, semIsInvalidUnlock	/* invalid semaphore? */
	lw	v0, SEM_STATE(a0)		/* test for owner */
	bne	zero, v0, semMEmpty		/* sem is owned, is it ours? */
	sw	v1, SEM_STATE(a0)		/* we now own semaphore */
	lbu	t2, SEM_OPTIONS(a0)		/* read sem options */
	andi	t2, 4				/* sem delete safe? */
	beq	zero, t2, semMPriCheck		/* if no, then semMPriCheck */
	lw	t3, WIND_TCB_SAFE_CNT(v1)	/* else {read safety count */
	addiu	t3, 1				/* increment safety count */
	sw	t3, WIND_TCB_SAFE_CNT(v1)	/* store safety count} */
semMPriCheck:
	lbu	t2, SEM_OPTIONS(a0)		/* read sem options */
	andi	t2, 8				/* sem inversion safe? */
	beq	zero, t2, semMDone		/* if no, then semMDone */
	lw	t3, WIND_TCB_MUTEX_CNT(v1)	/* else {read mutex count */
	addiu	t3, 1				/* increment mutex count */
	sw	t3, WIND_TCB_MUTEX_CNT(v1)	/* store mutex count} */

semMDone:
	HAZARD_VR5400
	mtc0	t0, C0_SR			/* UNLOCK INTS */
	j	ra				/* return, v0 still zero */
semMEmpty:
	bne	v1, v0, semMQUnlockPut	/* if not recursive take, then block */
	lhu	t3, SEM_RECURSE(a0)	/* else {read sem recurse */
	addiu	t3, 1			/* increment sem recurse */
	sh	t3, SEM_RECURSE(a0)	/* store sem recurse} */
	move	v0, zero		/* return value = OK */
	HAZARD_VR5400
	mtc0	t0, C0_SR		/* UNLOCK INTS */
	j	ra			/* return */
semMQUnlockPut:
	SETFRAME(semMQUnlockPut,2)
	subu	sp, FRAMESZ(semMQUnlockPut) /* create some stack space */
	SW	ra, FRAMERA(semMQUnlockPut)(sp)	/* save return address */
	SW	a0, FRAMER0(semMQUnlockPut)(sp)	/* save semId */
	SW	a1, FRAMER1(semMQUnlockPut)(sp)	/* save timeout */
	li	t2, 1			/* load immediate value */
	sw	t2, kernelState		/* KERNEL ENTER */
	HAZARD_VR5400
	mtc0	t0, C0_SR		/* UNLOCK INTS */
	jal	semMPendQPut		/* do as much in C as possible */
        bne     zero, v0, semMFail      /* if !OK, exit kernel, ERROR */

semMQPendQOk:
        jal     windExit                /* KERNEL EXIT */
	li      t1, 1                   /* load RESTART */
	beq	v0, t1, semMRestart	/* is it a RESTART? */
	LW	ra, FRAMERA(semMQUnlockPut)(sp)	/* restore return address */
	addiu	sp, FRAMESZ(semMQUnlockPut) /* restore stack pointer */
        j	ra                      /* finished OK or TIMEOUT */

semMRestart:
	LW	a0, FRAMER1(semMQUnlockPut)(sp) /* pass timeout */
        lw	t0, _func_sigTimeoutRecalc/* address of recalc routine */
        jal     t0                      /* recalc the timeout */
	LW	a0, FRAMER0(semMQUnlockPut)(sp)	/* restore semId */
	move	a1, v0			/* restore timeout */
	LW	ra, FRAMERA(semMQUnlockPut)(sp)	/* restore return address */
	addiu	sp, FRAMESZ(semMQUnlockPut) /* restore stack pointer */
        j	semTake			/* start the whole thing over */
semMFail:
        jal	windExit		/* KERNEL EXIT */
        li	v0, -1			/* return ERROR */
	LW	ra, FRAMERA(semMQUnlockPut)(sp)	/* restore return address */
	addiu	sp, FRAMESZ(semMQUnlockPut) /* restore stack */
        j	ra                      /* failed */
	.end	semMTake

/********************************************************************************
* semIsInvalid - unlock interupts and call semInvalid ().
*/

semIsInvalidUnlock:
	HAZARD_VR5400
        mtc0    t0, C0_SR               /* UNLOCK INTS */
semIsInvalid:
        j       semInvalid              /* let C rtn do work and rts */

#endif /* semMALib_PORTABLE */
