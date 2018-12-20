/* intALib.s - interrupt library assembly language routines */

/* Copyright 1984-2000 Wind River Systems, Inc. */
	.data
	.globl	_copyright_wind_river
	.long	_copyright_wind_river

/*
modification history
--------------------
01a,17mar00,dra  Created from T1.0.1 ColdFire and T2 m68k ports.
*/

/*
DESCRIPTION
This library supports various functions associated with interrupts from C
routines.  The routine intLevelSet() changes the current interrupt level
of the processor.

SEE ALSO: intLib, intArchLib

INTERNAL
Some routines in this module "link" and "unlk" the "c" frame pointer
(a6) although they don't use it in any way!  This is only for the benefit of
the stacktrace facility to allow it to properly trace tasks executing within
these routines.
*/

#define _ASMLANGUAGE
#include "vxWorks.h"
#include "asm.h"

	.text
	.even

	/* globals */

	.globl	_intLevelSet
	.globl	_intLock
	.globl	_intUnlock
	.globl	_intVBRSet


/*******************************************************************************
*
* intLevelSet - set the interrupt level (for 68K processors)
*
* This routine changes the interrupt mask in the status register to take
* on the value specified by <level>.  Interrupts are locked out at or below
* that level.  The level must be in the range 0 - 7.
*
* WARNING
* Do not call VxWorks system routines with interrupts locked.
* Violating this rule may re-enable interrupts unpredictably.
*
* RETURNS: The previous interrupt level (0 - 7).
*
* int intLevelSet
*    (
*    int level	/* new interrupt level mask, 0 - 7 *
*    )
*/

_intLevelSet:
	link	a6,#0
	movew	sr,d0		/* get old sr into d0 */
	andl	#0xf8ff,d0	/* clear interrupt mask in saved sr */
	movel	a6@(ARG1),d1	/* get new level into d1 */
	andl	#0x7,d1		/* clear all but interrupt mask */
	lsll	#8,d1		/* get level into high order byte */
	orl	d0,d1		/* combine with saved status reg contents */
	movew	sr,d0		/* remember status register */
	movew	d1,sr		/* set status register */

	lsrl	#8,d0		/* shift interrupt level to low bits */
	andl	#0x7,d0		/* clear all but interrupt mask */
	unlk	a6
	rts

/*******************************************************************************
*
* intLock - lock out interrupts
*
* This routine disables interrupts.  The interrupt level is set to the
* lock-out level set by intLockLevelSet().  The default lock-out level is
* the highest value.  The routine returns an architecture-dependent lock-out
* key for the interrupt level prior to the call, and this should be passed back
* to the routine intUnlock() to enable interrupts.
*
* WARNINGS
* Do not call VxWorks system routines with interrupts locked.
* Violating this rule may re-enable interrupts unpredictably.
*
* The routine intLock() can be called from either interrupt or task level.
* When called from a task context, the interrupt lock level is part of the
* task context.  Locking out interrupts does not prevent rescheduling.
* Thus, if a task locks out interrupts and invokes kernel services that
* cause the task to block (e.g., taskSuspend() or taskDelay()) or that cause a
* higher priority task to be ready (e.g., semGive() or taskResume()), then
* rescheduling will occur and interrupts will be unlocked while other tasks
* run.  Rescheduling may be explicitly disabled with taskLock().
*
* EXAMPLE
* .CS
*     lockKey = intLock ();
*
*      ...
*
*     intUnlock (lockKey);
* .CE
*
* RETURNS
* An architecture-dependent lock-out key for the interrupt level
* prior to the call; the interrupt field mask, on the MC680x0 family.
*
* SEE ALSO: intUnlock(), taskLock()

* int intLock ()

*/

_intLock:
	movew	sr,d1
	movew	d1,a0
	andl	#0xf8ff,d1
	movew	_intLockMask,d0
	orl	d0,d1
	movew	d1,sr
	movew	a0,d0
	rts

/*******************************************************************************
*
* intUnlock - cancel interrupt locks
*
* This routine re-enables interrupts that have been disabled by the routine
* intLock().  Use the architecture-dependent lock-out key obtained from the
* preceding intLock() call.
*
* RETURNS: N/A
*
* SEE ALSO: intLock()

* void intUnlock
*	(
*	int lockKey
*	)

*/

_intUnlock:
	movew	a7@(0x6),d0
	movew	d0,sr
	rts

/*******************************************************************************
*
* intVBRSet - set the vector base register
*
* This routine should only be called in supervisor mode.
* It is not used on the M68000.
*
* NOMANUAL

* void intVBRSet (baseAddr)
*      FUNCPTR *baseAddr;	/* vector base address *

*/

_intVBRSet:
	link	a6,#0
	/*
	 * MCF5206 errata IP1, MOVEC to VBR fails if a7 is not used as
	 * the source operand.
	 */
	movew	sr,d0				/* current SR */
	movew	_intLockIntSR,d1		/* LOCK INTERRUPTS */
	movew	d1,sr
	movel	a7,d1				/* save current SP */
	movel	a6@(ARG1),a7			/* put base address in a7 */
	movec	a7,vbr				/* set VBR */
	movel	d1,a7				/* restore SP */
	movew	d0,sr				/* restore SR */

	unlk	a6
	rts
