/* workQALib.s - internal VxWorks kernel work queue assembler library */

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
01w,01aug01,mem  Diab integration
01v,16jul01,ros  add CofE comment
01u,12jun01,mem  Update to new coding standard.
01t,19jun00,dra  work around 5432 branch bug
01s,10sep99,myz  added CW4000_16 support.
01q,19jan99,dra  added CW4000, CW4011, VR4100, VR5000 and VR5400 support.
01p,25feb99,nps  remove obsolete scrPad references.
01o,16apr98,pr   removed WindView 10x support.
01n,15jul96,cah  added R4650 support
01m,23jul96,pr   added windview instrumentation.
01l,22feb96,mem  fixed R4000 support.  Was using sw/lw with FRAMERx().
01j,19oct93,cd   added R4000 support.
01i,29sep93,caf  undid fix of SPR #2359.
01h,07jul93,yao  fixed to preserve parity error bit of status
		 register (SPR #2359).
           +caf  fixed spelling of "workQDoWork", more ansi cleanup,
		 updated copyright notice.
01g,04jul92,jcf  scalable/ANSI/cleanup effort.
01f,05jun92,ajm  5.0.5 merge
01e,26may92,rrr  the tree shuffle
01d,15oct91,ajm   pulled in optimizations
01c,04oct91,rrr   passed through the ansification filter
                   -fixed #else and #endif
                   -changed VOID to void
                   -changed ASMLANGUAGE to _ASMLANGUAGE
                   -changed copyright notice
01b,01aug91,ajm   removed assembler .set noreorder macros. They tend to screw 
		   up assembler.
01a,01may91,ajm   ported to MIPS from 68K version 01g.
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
#include "private/eventP.h"

/* optimized version available for MIPS targets */

#if (defined(PORTABLE))
#define workQALib_PORTABLE
#endif

#ifndef workQALib_PORTABLE

	/* globals */

	.globl	workQAdd0		/* add function to workQ */
	.globl	workQAdd1		/* add function and 1 arg to workQ */
	.globl	workQAdd2		/* add function and 2 args to workQ */
	.globl	workQDoWork		/* do all queued work in a workQ */

	/* externs */

	.extern	workQWriteIx
	.extern	workQReadIx
	.extern	workQIsEmpty
	.extern	errno

	.text
	.set	reorder

/*******************************************************************************
*
* workQOverflow - work queue has overflowed so call workQPanic ()
*
* NOMANUAL
*/  

workQOverflow:					/* leave interrupts locked */
	jal	workQPanic			/* panic and never return */

/*******************************************************************************
*
* workQAdd0 - add a function with no argument to the work queue
*
* NOMANUAL

* void workQAdd0
*     (
*     FUNCPTR func	/@ function to invoke @/
*     )

*/  

	.ent	workQAdd0
workQAdd0:
	HAZARD_VR5400
	mfc0	t0, C0_SR
	li	t1, ~SR_INT_ENABLE
	and	t1, t1, t0
	mtc0	t1, C0_SR			/* LOCK INTERRUPTS */
	HAZARD_INTERRUPT
	lbu	t2, workQWriteIx		/* get write index */
	lbu	t3, workQReadIx			/* get read index */
	addu	t4, t2, 4			/* bump write index */
	andi	t4, 0xff			/* take care of byte overflow */
	beq	t4, t3, workQOverflow		/* panic if Q overflow */
	sb	t4, workQWriteIx		/* update write index */
	HAZARD_VR5400
	mtc0	t0, C0_SR			/* UNLOCK INTS */
	sw	zero, workQIsEmpty		/* we put something in it */
	sll	t2, 2				/* scale index by 4 */
	la	t4, pJobPool			/* get start of job pool */
	addu	t4, t2
	sw	a0, JOB_FUNCPTR(t4)		/* move the function to pool */
	j	ra				/* we're done */
	.end	workQAdd0

/*******************************************************************************
*
* workQAdd1 - add a function with one argument to the work queue
*
* NOMANUAL

* void workQAdd1
*     (
*     FUNCPTR func,	/@ function to invoke 		@/
*     int arg1		/@ parameter one to function	@/
*     )

*/  

	.ent	workQAdd1
workQAdd1:
	HAZARD_VR5400
	mfc0	t0, C0_SR
	li	t1, ~SR_INT_ENABLE
	and	t1, t1, t0
	mtc0	t1, C0_SR			/* LOCK INTERRUPTS */
	HAZARD_INTERRUPT
	lbu	t2, workQWriteIx		/* get write index */
	lbu	t3, workQReadIx			/* get read index */
	addu	t4, t2, 4			/* bump write index */
	andi	t4, 0xff			/* take care of byte overflow */
	beq	t4, t3, workQOverflow		/* panic if Q overflow */
	sb	t4, workQWriteIx		/* update write index */
	HAZARD_VR5400
	mtc0	t0, C0_SR			/* UNLOCK INTS */
	sw	zero, workQIsEmpty		/* we put something in it */
	sll     t2, 2                           /* scale index by 4 */
	la	t4, pJobPool			/* get start of job pool */
	addu	t4, t2
	sw	a0, JOB_FUNCPTR(t4)		/* move the function to pool */
	sw	a1, JOB_ARG1(t4)		/* move arg1 to pool */
	j	ra				/* we're done */
	.end	workQAdd1

/*******************************************************************************
*
* workQAdd2 - add a function with two arguments to the work queue
*
* NOMANUAL

* void workQAdd2
*     (
*     FUNCPTR func,	/@ function to invoke 		@/
*     int arg1,		/@ parameter one to function	@/
*     int arg2		/@ parameter two to function	@/
*     )

*/  

	.ent	workQAdd2
workQAdd2:
	HAZARD_VR5400
	mfc0	t0, C0_SR
	li	t1, ~SR_INT_ENABLE
	and	t1, t1, t0
	mtc0	t1, C0_SR			/* LOCK INTERRUPTS */
	HAZARD_INTERRUPT
	lbu	t2, workQWriteIx		/* get write index */
	lbu	t3, workQReadIx			/* get read index */
	addu	t4, t2, 4			/* bump write index */
	andi	t4, 0xff			/* take care of byte overflow */
	beq	t4, t3, workQOverflow		/* panic if Q overflow */
	sb	t4, workQWriteIx		/* update write index */
	HAZARD_VR5400
	mtc0	t0, C0_SR			/* UNLOCK INTS */
	sw	zero, workQIsEmpty		/* we put something in it */
        sll     t2, 2                           /* scale index by 4 */
	la	t4, pJobPool			/* get start of job pool */
	addu	t4, t2
	sw	a0, JOB_FUNCPTR(t4)		/* move the function to pool */
	sw	a1, JOB_ARG1(t4)		/* move arg1 to pool */
	sw	a2, JOB_ARG2(t4)		/* move arg2 to pool */
	j	ra				/* we're done */
	.end	workQAdd2

/*******************************************************************************
*
* workQDoWork - perform all the work queued in the kernel work queue
*
* This routine empties all the deferred work in the work queue.  The global
* variable errno is saved restored, so the work will not clobber it.
* The work routines may be C code, and thus clobber the temporary registers
*
* NOMANUAL

* void workQDoWork (void)

*/

	.ent	workQDoWork
workQDoWork:
	SETFRAME(workQDoWork,2)
	subu	sp, FRAMESZ(workQDoWork)	/* get some stack */
	SW	ra, FRAMERA(workQDoWork)(sp)	/* save ra */
	SW	s0, FRAMER0(workQDoWork)(sp)	/* save s0 */
	lw	s0, errno			/* save errno */
	lbu	t0, workQReadIx			/* grab read index */
	lbu	t1, workQWriteIx		/* grab write index */
	beq	t0, t1, workQNoMoreWork		/* work to do? */
workQMoreWork:
	addu	t2, t0, 4			/* increment read index */
	sb	t2, workQReadIx			/* put it to memory */
        sll     t0, 2                           /* scale index by 4 */
	la	t3, pJobPool			/* get start of job pool */
	addu	t3, t0
	lw	t4, JOB_FUNCPTR(t3)		/* get work function */
	lw	a0, JOB_ARG1(t3)		/* get work parma 1 */
	lw	a1, JOB_ARG2(t3)		/* get work parma 2 */
	jal	t4				/* call work routine */

	li	t2, 1				/* load boolean */
	sw	t2, workQIsEmpty		/* set boolean before test! */
	lbu	t0, workQReadIx			/* grab read index */
	lbu	t1, workQWriteIx		/* grab write index */
	bne	t0, t1,workQMoreWork		/* more work to be done */
workQNoMoreWork:
	sw	s0, errno			/* restore errno */
	LW	s0, FRAMER0(workQDoWork)(sp)	/* restore s0 */
	LW	ra, FRAMERA(workQDoWork)(sp)	/* restore ra */
	addu	sp, FRAMESZ(workQDoWork)	/* clean up stack */
	j	ra				/* we're done */
	.end	workQDoWork

#endif /* workQALib_PORTABLE */
