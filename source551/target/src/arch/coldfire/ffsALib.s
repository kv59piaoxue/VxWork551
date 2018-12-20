/* ffsALib.s - find first set function */

/* Copyright 1984-2000 Wind River Systems, Inc. */
	.data
	.globl  _copyright_wind_river
	.long   _copyright_wind_river


/*
modification history
--------------------
01b,14jun00,dh   add public _ffs to support some stuff that seems to need it.
01a,17mar00,dra  Created from T1.0.1 ColdFire and T2 m68k ports.
*/

/*
DESCRIPTION
This library implements ffsMsb() which returns the most significant bit set. By
taking advantage of the BFFFO instruction of 68020 processors and later, the
implementation determines the first bit set in constant time.  For 68000/68010
ffsMsb() utilizes a lookup table to perform the operation.
*/

#define _ASMLANGUAGE
#include "vxWorks.h"
#include "asm.h"


#if (defined(PORTABLE))
#define ffsALib_PORTABLE
#endif

#ifndef ffsALib_PORTABLE

	/* exports */

	.globl	_ffsMsb
	.globl	_ffs

	.text
	.even


/*******************************************************************************
*
* ffsMsb - find first set bit (searching from the most significant bit)
*
* This routine finds the first bit set in the argument passed it and
* returns the index of that bit.  Bits are numbered starting
* at 1 from the least signifficant bit.  A return value of zero indicates that
* the value passed is zero.
*

* void ffsMsb (i)
*     int i;       /* argument to find first set bit in *

*/

_ffsMsb:
_ffs:
	link	a6,#0

	lea	_ffsMsbTbl,a1		/* lookup table address in a1 */
	clrl	d0			/* clear out d0 */
	movew	a6@(ARG1),d0		/* put msw into d0 */
	jeq 	ffsLsw			/* if zero, try the lsw */
	cmpl	#0x100,d0		/* compare msw to 0x100 */
	jcs 	ffsMswLsb		/* if unsigned less than, then MswLsb */
	lsrl	#8,d0			/* shift Msb to Lsb of d0 */
	moveb	a1@(0,d0:l),d0		/* find first bit set of d0[0:1] */
	addl	#25,d0			/* add bit offset to MswMsb (25) */
	jra 	ffsDone			/* d0 contains bit number */

ffsMswLsb:
	moveb	a1@(0,d0:l),d0		/* find first bit set of d0[0:1] */
	addl	#17,d0			/* add bit offset to MswLsb (17) */
	jra 	ffsDone			/* d0 contains bit number */

ffsLsw:
	moveb	a6@(ARG1+2),d0		/* put LswMsb in d0 */
	jeq 	ffsLswLsb		/* if zero, try LswLsb */
	moveb	a1@(0,d0:l),d0		/* find first bit set of d0[0:1] */
	addl	#9,d0			/* add bit offset to LswMsb (9) */
	jra 	ffsDone			/* d0 contains bit number */
ffsLswLsb:
	movel	a6@(ARG1),d0		/* put LswLsb in d0 */
	jeq 	ffsDone			/* no bit set so return 0 */
	moveb	a1@(0,d0:l),d0		/* find first bit set of d0[0:1] */
	addl	#1,d0			/* add bit offset to LswLsb (1) */

ffsDone:
	unlk	a6
	rts

#endif	/* ! ffsALib_PORTABLE */
