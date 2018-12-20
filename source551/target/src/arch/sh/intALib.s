/* intALib.s - interrupt library assembly language routines */

/* Copyright 1994-2000 Wind River Systems, Inc. */

	.data
	.global	_copyright_wind_river
	.long	_copyright_wind_river

/*
modification history
--------------------
01y,14sep00,hk   added intSRGet()/intSRSet().
01x,21aug00,hk   merge SH7729 to SH7700. merge SH7410 and SH7040 to SH7600.
01w,10apr00,hk   got rid of .ptext section. deleted intBlock.
01v,28mar00,hk   added .type directive to function names.
01u,17mar00,zl   made use of alignment macro _ALIGN_TEXT
01t,08jun99,zl   added .ptext attribute "ax"
01s,16sep98,hk   code review.
01r,16jul98,st   added SH7750 support.
01r,07may98,jmc  added support for SH-DSP and SH3-DSP.
01q,25apr97,hk   changed SH704X to SH7040.
01p,03mar97,hk   changed intUnlock() to preserve M/Q/S/T bits in current SR.
                 saved two bytes by changing XFFFFFF0F to XFF0F.
01o,20jan97,hk   restored intBlock() but kept disabled. migrated to .ptext.
01n,13dec96,hk   deleted unnecessary code pointed by wt in intLevelSet().
		 optimized code order in intLock().
01m,07dec96,hk   deleted intBlock() for SH7700.
01l,24sep96,hk   fixed intLevelSet() and intLock() for lower mask.(SPR #H1005)
01k,17sep96,hk   added intBlock() for SH7700. changed code align base to 1.
01j,27jul96,hk   reviewed #if readability.
01i,07jun96,hk   added support for SH7700.
01h,02jul95,hk   documentation review.
01g,22may95,hk   improved intLevelSet.
01f,06apr95,hk   trying to improve performance. copyright 1995.
01e,18oct94,hk   refined intLevelSet, intLock.
01d,27sep94,hk   renamed INTLOCKMASK to DATA_INTLOCKMASK. enabled intUnlock.
                 fixed intLevelSet, intLock.
01c,26sep94,hk   fixed intLockMask fetch.
01b,18sep94,hk   nop'd intUnlock for debug.
01a,18jul94,hk   derived from 05k of 68k.
*/

/*
DESCRIPTION
This library supports various functions associated with interrupts from C
routines.  The routine intLevelSet() changes the current interrupt level
of the processor.

NOTE SH77XX:
This library does not have to be in P1/P2, since it does not change
MD or BL bits in the status register.
*/

#define _ASMLANGUAGE
#include "vxWorks.h"
#include "asm.h"

	/* globals */

	.global	_intLevelSet
	.global	_intLock
	.global	_intUnlock
	.global	_intVBRSet
	.global	_intSRGet
	.global	_intSRSet

	.text

/******************************************************************************
*
* intLevelSet - set the interrupt level (for SH processors)
*
* This routine changes the interrupt mask in the status register to take
* on the value specified by <level>.  The level must be in the range 0 - 15.
* This locks out interrupts at or below that level.
*
* RETURNS: The previous interrupt level (0 - 15).
*
* SEE ALSO: sysVwTrap()

* int intLevelSet
*     (
*     int level		/@ new interrupt level mask, 0 - 15 @/
*     )

* INTERNAL:	This routine is not called in VxWorks/SH 5.1.1.
*/
	.align	_ALIGN_TEXT
	.type	_intLevelSet,@function

_intLevelSet:				/* r4: 0x_______n  */
	mov.w	XFF0F,r1;		/* r1: 0xffffff0f (sign extended) */
	shll2	r4
	shll2	r4
	extu.b	r4,r4			/* r4: 0x000000n0  */
	stc	sr,r0			/* r0: (old sr)    */
	and	r0,r1			/* r1: 0x______0_  */
	or	r1,r4			/* r4: 0x______n_  */
	ldc	r4,sr			/* LOCK INTERRUPTS */
	extu.b	r0,r0			/* r0: 0x000000m_  */
	shlr2	r0
	rts;
	shlr2	r0			/* r0: 0x0000000m  */

/******************************************************************************
*
* intLock - lock out interrupts
*
* This routine disables interrupts.  The interrupt level is set to the
* lock-out level set by intLockLevelSet().  The default lock-out level is
* the highest value.  The routine returns an architecture-dependent lock-out
* key for the interrupt level prior to the call, and this should be passed back
* to the routine intUnlock() to enable interrupts.
*
* IMPORTANT CAVEAT
* The routine intLock() can be called from either interrupt or task level.
* When called from a task context, the interrupt lock level is part of the
* task context.  Locking out interrupts does not prevent rescheduling.
* Thus, if a task locks out interrupts and invokes kernel services that
* cause the task to block (e.g., taskSuspend() or taskDelay()) or causes a
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
* prior to the call.
*
* SEE ALSO: intUnlock(), taskLock()

* int intLock (void)

*/
	.align	_ALIGN_TEXT
	.type	_intLock,@function

_intLock:
	mov.l	IntLockMask,r1;
	stc	sr,r0			/* r0: get old sr */
	mov.l	@r1,r2;			/* r2: 0x000000e0 */
	mov.w	XFF0F,r1;		/* r1: 0xffffff0f (sign extended) */
	and	r0,r1			/* r1: 0x______0_ */
	or	r2,r1			/* r1: 0x______e_ */
#if	(CPU==SH7600 || CPU==SH7000)
	rts;
	ldc	r1,sr
#else
	ldc	r1,sr			/* LOCK INTERRUPTS */
	rts;				/* r0: rtn old sr */
	nop
#endif

		.align	2
IntLockMask:	.long	_intLockMask

/******************************************************************************
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
*     (
*     int lockKey
*     )

*/
	.align	_ALIGN_TEXT
	.type	_intUnlock,@function

_intUnlock:				/* r4: old sr     */
	mov	r4,r0
	and	#0xf0,r0		/* r0: 0x000000m0 */
	mov.w	XFF0F,r1;		/* r1: 0xffffff0f (sign extended) */
	stc	sr,r2			/* r2: current sr */
	and	r1,r2			/* r2: 0x??????0? */
	or	r0,r2			/* r2: new sr     */
#if	(CPU==SH7600 || CPU==SH7000)
	rts;
	ldc	r2,sr
#else
	ldc	r2,sr
	rts;
	nop
#endif

		.align	1
XFF0F:		.word	0xff0f

/******************************************************************************
*
* intVBRSet - set the vector base register
*
* This routine is called from intVecBaseSet().  This should not be called
* directly by user.
*
* NOMANUAL

* void intVBRSet
*     (
*     FUNCPTR *baseAddr		/@ vector base address @/
*     )

*/
	.align	_ALIGN_TEXT
	.type	_intVBRSet,@function

_intVBRSet:			/* r4: baseAddr */
	rts;
	ldc	r4,vbr

/******************************************************************************
*
* intSRGet - get the status register
*
* NOMANUAL

* int intSRGet (void)

*/
	.type	_intSRGet,@function

_intSRGet:
	rts;
	stc	sr,r0		/* return current SR value */

/******************************************************************************
*
* intSRSet - set the status register
*
* NOMANUAL

* void intSRSet
*     (
*     int value			/@ new SR value @/
*     )

*/
	.type	_intSRSet,@function

_intSRSet:
#if	(CPU==SH7600 || CPU==SH7000)
	rts;
	ldc	r4,sr
#else
	ldc	r4,sr		/* set new SR value */
	rts;
	nop
#endif
