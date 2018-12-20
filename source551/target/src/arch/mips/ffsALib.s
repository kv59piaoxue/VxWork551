/* ffsALib.s - find first set function */

/* Copyright 1984-2001 Wind River Systems, Inc. */
	.data
	.globl  copyright_wind_river


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
02i,05dec01,mem  re-disable optimized version.
02h,16jul01,ros  add CofE comment
02g,20dec00,pes  Update for MIPS32/MIPS64 target combinations.
02f,19jan99,dra  re-enabled ffsMsb for LSI CW4011.
02e,19oct93,cd   removed for all MIPS processors.
02d,05jun92,ajm  'C' version has proven to be faster so we ifdef'd this out
02c,26may92,rrr  the tree shuffle
02b,04oct91,rrr  passed through the ansification filter
		  -changed VOID to void
		  -changed ASMLANGUAGE to _ASMLANGUAGE
		  -changed copyright notice
02a,04mar91,ajm   ported to R3k in constant time
01e,01oct90,dab   changed conditional compilation identifier from
		    HOST_SUN to AS_WORKS_WELL.
01d,12sep90,dab   conditionally compiled bfffo instruction as a .word
           +lpf     to make non-SUN hosts happy.
01c,09jul90,jcf   wrote ffsMsb () for 68000/68010.
01b,26jun90,jcf   changed ffs() to ffsMsb() to maintain UNIX compatibility.
01a,17jun89,jcf   written.
*/

/*
DESCRIPTION
This module defines an optimized version of the cLib.a routine ffs ().
By using a combination of a binary search and a hash table lookup the
implementation determines the first bit set in constant time.
*/

#define _ASMLANGUAGE
#include "vxWorks.h"
#include "asm.h"

/* 'C' version has proven to be faster */

#if (defined(PORTABLE) || (CPU_FAMILY==MIPS))
#define ffsALib_PORTABLE
#endif

#if 0
/* CW4011 has hardware "ffsMsb" instruction */

#if !defined(PORTABLE)
#undef ffsALib_PORTABLE
#endif	/* ! PORTABLE */
#endif

#ifndef ffsALib_PORTABLE

	/* exports */

	.globl	ffsMsb

	.text
	.set	reorder

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
	
#define WORD_TEST 16
#define HALF_TEST 8

	.ent	ffsMsb
ffsMsb:
	move	v0, zero		/* to pass result */
	beq	zero, a0, ffsNoBitSet	/* zeros means no bit is set */
#if	(CPU==CW4011)	
	ffs	v0, a0			/* v0 gets 0-based # of MSB */
	addi	v0, 1			/* API wants 1-based */
#else	/* (CPU==CW4011) */
	srl	t0, a0, WORD_TEST 	/* shift logical half word */
	bne	zero, t0, msHalf	/* not equal, upper half bit set */
lsHalf:
	srl	t0, a0, HALF_TEST 	/* test ls half word */
	bne	zero, t0, byte1		/* not equal, byte 1 has bit set */
byte0:
	move	t1, zero		/* byte 0 has bit set */
	j	calculate
byte1:
	li	t1, 8			/* byte 1 has bit set */
	j	calculate
msHalf:
	srl	t0, t0, HALF_TEST 	/* test ms half word */
	bne	zero, t0, byte3		/* not equal, byte 3 has bit set */
byte2:
	li	t1, 16			/* byte 2 has bit set */
	j	calculate
byte3:
	li	t1, 24			/* byte 3 has bit set */

calculate:

	srlv	t0, a0, t1		/* put correct byte in byte 0 */
	la	t2, ffsMsbTbl
	addu	t2, t2, t0
	lbu	v0, (t2)		/* lookup value */
	add	v0, 1			/* compensate for 0-7 return */
	add	v0, t1			/* fixup for word */
#endif	/* (CPU==CW4011) */
ffsNoBitSet:
	j	ra			/* return to sender */
	.end	ffsMsb

#endif /* ffsALib_PORTABLE */
