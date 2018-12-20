/* intALib.s - MIPS interrupt library assembly language routines */

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
01t,02aug01,mem  Diab integration
01s,16jul01,ros  add CofE comment
01r,08feb01,agf  Adding HAZARD macros
01q,02jan01,pes  Replace SR_IEC/SR_IE with SR_INT_ENABLE
01p,21dec00,pes  Adapt to MIPS32/MIPS64 CPU architectures
01o,19jun00,dra  work around 5432 branch bug
01n,10sep99,myz  added CW4000_16 support.
01m,19jan99,dra  added CW4000, CW4011, VR4100, VR5000 and VR5400 support.
01l,29may97,kkk  clean up some.
01k,15jul96,cah  added R4650 CPU references
01j,26jan95,rhp  doc tweaks.	
01i,18oct93,cd   added R4000 support.
01h,29sep93,caf  undid fix of SPR #2359.
01g,07jul93,yao  fixed to preserve parity error bit of status 
		 register (SPR #2359).  changed copyright notice.
01k,15sep92,jdi  ansified declarations for mangenable routines.
01j,05jun92,ajm  5.0.5 merge, note mod history changes
01i,26may92,rrr  the tree shuffle
02h,16jan92,jdi  doc tweak.
02g,14jan92,jdi  documentation cleanup.
01f,06dec91,ajm  added intCRSet and filled appropriate delay slots
01e,04oct91,rrr  passed through the ansification filter
                  -changed VOID to void
                  -changed ASMLANGUAGE to _ASMLANGUAGE
                  -changed copyright notice
01d,20may90,ajm  added intLock, intUnlock, removed intLevelSet after 
		  discusions with wind river
01c,22apr90,ajm  added intLevelAdd , intLevelSub routine
01b,10apr90,ajm  added routines intDisable, intEnable, 
		  intStatusRead, intStatusWrite
01a,10apr90,ajm  ported to mips R3000.  Derived from 04f of 68K.
*/

/*
DESCRIPTION
This library is used to support various functions associated with
interrupts from C routines.  Tasks can lock and unlock interrupts using
intLock() and intUnlock(), which enable and disable interrupts on the
MIPS CPU.  This library also provides routines to manipulate other internal
registers:  intEnable(), intDisable(), intSRGet(), intSRSet(), intCRGet(),
and intCRSet().

SEE ALSO
intLib, intArchLib

INTERNAL
The order of the instructions in these routines is critical.  Do not
reorder code inside the reorder sections unless you understand the
consequences.
*/

#define _ASMLANGUAGE
#include "vxWorks.h"
#include "asm.h"

	.globl	intEnable
	.globl	intDisable
	.globl	intCRGet
	.globl	intCRSet
	.globl	intSRGet
	.globl	intSRSet
	.globl	intUnlock
	.globl	intLock

	.text
	.set	reorder
/*******************************************************************************
*
* intEnable - enable corresponding interrupt bits on MIPS CPU
*
* This routine enables the input interrupt bits on the present status
* register of the processor.  It is strongly advised that the level
* be a combination of `SR_IBIT1' - `SR_IBIT8'.
*
* RETURNS: The previous contents of the status register.

* int intEnable
*     (
*     int level	  /* new interrupt bits (0x00 - 0xff00) *
*     )

*/

	.ent	intEnable
intEnable:
	HAZARD_VR5400
	mfc0	v0, C0_SR	/* grab present status reg	*/
	HAZARD_CP_READ
	or	t0, v0, a0	/* set interrupt bit to active	*/
	mtc0	t0, C0_SR	/* put it on the processor	*/
	j	ra
	.end	intEnable

/*******************************************************************************
*
* intDisable - disable corresponding interrupt bits on a MIPS CPU
*
* This routine disables the corresponding interrupt bits from the present 
* status register.  The macros `SR_IBIT1' - `SR_IBIT8' define bits that
* may be set.
*
* RETURNS: The previous contents of the status register.

* int intDisable
*     (
*     int level	  /* new interrupt bits (0x0 - 0xff00) *
*     )

*/

	.ent	intDisable
intDisable:
	HAZARD_VR5400
	mfc0	v0, C0_SR	/* grab present status reg	*/
	HAZARD_CP_READ
	not	a0, a0		/* complement input param	*/
	and	t0, v0, a0	/* set interrupt bit to inactive*/
	.set	noreorder
	mtc0	t0, C0_SR	/* put it on the processor	*/
	HAZARD_INTERRUPT
	.set	reorder
	j	ra
	.end	intDisable

/*******************************************************************************
*
* intCRGet - read the contents of the cause register
*
* This routine reads and returns the contents of the cause
* register.
*
* RETURNS: The contents of the cause register.

* int intCRGet ()

*/

	.ent	intCRGet
intCRGet:
	HAZARD_VR5400
	mfc0	v0, C0_CAUSE	/* grab contents of cause reg	*/
	HAZARD_CP_READ
	j	ra		/* return to caller		*/
	.end	intCRGet

/*******************************************************************************
*
* intCRSet - write the contents of the cause register
*
* This routine writes the contents of the cause register.
*
* RETURNS: N/A

* void intCRSet
*     (
*     int value      /* value to write to cause register *
*     )

*/

	.ent	intCRSet
intCRSet:
	HAZARD_VR5400
	.set	noreorder	/* grab instrn sequence control	*/
	mtc0	a0, C0_CAUSE	/* writes contents of cause reg	*/
	HAZARD_CP_WRITE
	.set	reorder
	j	ra		/* return to caller		*/
	.end	intCRSet

/*******************************************************************************
*
* intSRGet - read the contents of the status register
*
* This routine reads and returns the contents of the status
* register.
*
* RETURNS: The previous contents of the status register.

* int intSRGet ()

*/

	.ent	intSRGet
intSRGet:
	HAZARD_VR5400
	.set	noreorder
	mfc0	v0, C0_SR	/* grab contents of status reg	*/
	HAZARD_CP_READ
	.set	reorder
	j	ra		/* return to caller		*/
	.end	intSRGet

/*******************************************************************************
*
* intSRSet - update the contents of the status register
*
* This routine updates and returns the previous contents of the status
* register.
*
* RETURNS: The previous contents of the status register.

* int intSRSet
*     (
*     int value	  /* value to write to status register *
*     )

*/

	.ent	intSRSet
intSRSet:
	HAZARD_VR5400
	mfc0	v0, C0_SR	/* grab old value of status reg	*/
	.set	noreorder	/* grab instrn sequence control	*/
	mtc0	a0, C0_SR	/* install new status register	*/
	HAZARD_CP_WRITE
	.set	reorder
	j	ra		/* return to caller		*/
	.end	intSRSet

/*******************************************************************************
*
* intUnlock - cancel interrupt locks
*
* This routine re-enables interrupts that have been disabled by intLock().
* It replaces the value of the status register with the value passed by
* <statusRegister>.  This parameter is a previous value of the status
* register, returned by a preceding intLock() call.
*
* RETURNS: N/A

* void intUnlock (statusRegister)

*/

	.ent	intUnlock
intUnlock:
	HAZARD_VR5400
	mtc0	a0, C0_SR	/* put old value on the processor */
	j	ra
	.end	intUnlock

/*******************************************************************************
*
* intLock - lock out interrupts
*
* This routine disables interrupts at the master lock-out level.  This means
* no interrupt can occur even if unmasked in the IntMask bits (15-8) of the
* status register.
*
* RETURNS: The previous contents of the status register.

* int intLock ()

*/

	.ent	intLock
intLock:
	HAZARD_VR5400
	mfc0	v0, C0_SR	/* read contents of SR	*/
	HAZARD_CP_READ
	li	t1, ~SR_INT_ENABLE	/* load disable mask	*/
	and	t1, t1, v0	/* make bit 0 a 0	*/
	.set	noreorder
	mtc0	t1, C0_SR	/* put on processor	*/
	HAZARD_INTERRUPT
	.set	reorder
	j	ra
	.end	intLock
