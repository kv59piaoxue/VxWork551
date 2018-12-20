/* semCALib.s - internal VxWorks kernel semaphore assembler library */

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
01m,30oct01,pcm  added VxWorks semaphore events
01l,02aug01,mem  Diab integration
01k,16jul01,ros  add CofE comment
01j,12jun01,mem  Update for new coding standard.
01i,19jun00,dra  work around 5432 branch bug
01h,10sep99,myz  reworked last mod.
01g,07sep99,myz  added mips16 support.
01f,19jan99,dra  added CW4000, CW4011, VR4100, VR5000 and VR5400 support.
01e,15jul96,cah  added R4650 support
01d,19oct93,cd   added R4000 support and enable for all MIPS targets
01c,29sep93,caf  undid fix of SPR #2359.
01b,07jul93,yao  fixed to preserve parity error bit of status 
		 register (SPR #2359).  changed copyright notice.
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

/* optimized version available for MIPS architecture */


#if (defined(PORTABLE))
#define semCALib_PORTABLE
#endif

#ifndef semCALib_PORTABLE

	/* globals */

	.globl	semCGive		/* optimized counting semaphore give */
	.globl	semCTake		/* optimized counting semaphore take */

	/* externals */

        .globl	semQGet			/* semaphore queue get routine */
        .globl	semQPut			/* semaphore queue put routine */
	.globl	semEvRsrcSend		/* semaphore event resource send */

	.text
	.set	reorder

/*******************************************************************************
*
* semCGive - optimized give of a counting semaphore
*

*STATUS semCGive (semId)
*    SEM_ID semId;		/* semaphore id to give *

*/
	.ent	semCGive
semCGive:					/* a0 = semId! d0 = 0! */
	HAZARD_VR5400
	mfc0	t0, C0_SR
	li	t1, ~SR_INT_ENABLE
	and	t1, t1, t0
	mtc0	t1, C0_SR			/* LOCK INTERRUPTS */
	HAZARD_INTERRUPT
	la	t3, semClass			/* get class address */
	lw	t2, 0(a0)			/* read semClass */
	bne	t2, t3, semIsInvalidUnlock	/* check validity */
	lw	v0, SEM_Q_HEAD(a0)		/* test sem Q head */
	bne	zero, v0, semCQGet		/* if not empty, get from Q */
	lw	t4, SEM_STATE(a0)		/* else {read sem state */
	addiu	t4, 1				/* increment sem state */
	lw	t3, SEM_EVENTS_TASKID (a0)	/* t4: events.taskId */
	sw	t4, SEM_STATE(a0)		/* store sem state} */
	bne	zero, t3, semCEvRsrcSend
	HAZARD_VR5400
	mtc0	t0, C0_SR			/* UNLOCK INTS */
	j	ra				/* v0 still 0 for OK */
	.end	semCGive

/*******************************************************************************
*
* semCTake - optimized take of a counting semaphore
*

*STATUS semCTake (semId)
*    SEM_ID semId;		/* semaphore id to give *

*/
	.ent	semCTake
semCTake:				/* a0 = semId! */
	HAZARD_VR5400
	mfc0	t0, C0_SR
	li	t1, ~SR_INT_ENABLE
	and	t1, t1, t0
	mtc0	t1, C0_SR			/* LOCK INTERRUPTS */
	HAZARD_INTERRUPT
	la	t3, semClass			/* get class address */
	lw	t2, 0(a0)			/* read semClass */
	bne	t2, t3, semIsInvalidUnlock	/* check validity */
	lw	t4, SEM_STATE(a0)		/* test count */
	beq	zero, t4, semCQPut		/* if sem owned, we block */
	lw	t3, SEM_STATE(a0)		/* else {read count */
	subu	t3, 1				/* decrement count */
	sw	t3, SEM_STATE(a0)		/* store count} */
	move	v0, zero			/* return OK */
	HAZARD_VR5400
	mtc0	t0, C0_SR			/* UNLOCK INTS */
	j	ra				/* and done */
	.end	semCTake

/********************************************************************************
* semIsInvalid - unlock interupts and call semInvalid ().
*/

semIsInvalidUnlock:
	HAZARD_VR5400
        mtc0    t0, C0_SR               /* UNLOCK INTS */
semIsInvalid:
        j       semInvalid              /* let C rtn do work and rts */

/*******************************************************************************
*
* semCQGet - stub so assembler/linker can deal with out of file branch
*
*/

semCQGet:			/* t0 must contain status reg. before intLock */
	j	semQGet		/* let outside rtn do the work and rts */

/*******************************************************************************
*
* semCQPut - stub so assembler/linker can deal with out of file branch
*
*/

semCQPut:			/* t0 must contain status reg. before intLock */
	j	semQPut		/* let outside rtn do the work and rts */

/*******************************************************************************
*
* semCEvRsrcSend - stub so assembler/linker can deal with out of file branch
*
*/
semCEvRsrcSend:
	j	semEvRsrcSend

#endif /* semCALib_PORTABLE */
