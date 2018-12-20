/* vxALib.s - miscellaneous assembly language routines */

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
02q,28jan02,tlc  Add .globl vxTas_llsc.
02p,21jan02,tlc  Add vxTas_llsc() routine to provide test-and-set operation to
                 MIPS devices with load-linked, store-conditional support.
02o,02aug01,mem  Diab integration
02n,16jul01,ros  add CofE comment
02m,12feb01,tlc  Perform HAZARD review.
02l,24feb00,dra  fixed typo in setting fpscr
02k,31jan00,dra  added vxFpscrGet/vxFpscrSet.
02j,05jun92,ajm  5.0.5 merge, note mod history changes
02i,26may92,rrr  the tree shuffle
02h,14jan92,jdi  documentation cleanup.
02g,04oct91,rrr  passed through the ansification filter
                  -changed TINY and UTINY to INT8 and UINT8
                  -changed ASMLANGUAGE to _ASMLANGUAGE
                  -changed copyright notice
02f,24sep90,wmd  fixed for mangen.
02e,19nov90,ajm  added binary and hash search routines.
		 changed Mux routines to be hashed.
02d,22oct90,ajm  got rid of LEAF and END macros.
02c,22may90,ajm  moved interrupt demux routines here from excALib.s.
02b,02may90,rtp  added explicit reference to "status" external rather than 
		 forcing status into v0 in the vxMemProbeTrap and 
		 vxMemIntCheck routines.  This file is board dependent 
		 for the STAR and should be located appropropriately.
02a,23apr90,rtp  this is the R3000 assembly code version; it adds vxMemIntCheck
		 to see if level 5 memory system interrupt occurs, deletes 
		 the vxMemProbeSup function, and modifies the vxMemProbeTrap
		 to intercept the data bus exception. vxTas know in 
		 vxLib.c
01e,10apr89,dab  fixed bug in vxTas() - changed bne to bmi.
01d,01sep88,gae  documentation.
01c,05jun88,dnw  changed from kALib to vxALib.
01b,30may88,dnw  changed to v4 names.
01a,15mar88,jcf  written and soon to be redistributed.
*/

/*
DESCRIPTION
This module contains miscellaneous VxWorks support routines.

SEE ALSO: vxLib
*/

#define _ASMLANGUAGE
#include "vxWorks.h"
#include "asm.h"

	/* internals */

	.globl	vxHashSearch
	.globl	vxBinarySearch
	.globl  vxFpscrSet
	.globl  vxFpscrGet
	.globl	vxTas_llsc

	.text
	.set	reorder

/*********************************************************************
*
* vxBinarySearch - use a binary search to find set bit
*
* DESCRIPTION
* This routine uses a binary search on an 8 bit value
* to find the index of a set bit (one).  
*
* NOTE
* This binary search algorithm is used to make a deterministic 
* search for a set bit in a register.  A straight forward linear 
* search takes best case (no cache misses) 12 to 40 cycles.  If 
* we implement a hash table we need at least 256 bytes of data, 
* and if the data cache misses (and it usually will) we suffer 
* a 23 cycle penalty (best case 4 cycles, worst case 39 cycles).  
* The instruction cache on the r3k does instruction streaming so 
* even if we miss, we excecute as we are fetching in instructions.  
* Best case cycle count is 11 cycles (all in I-Cache), worst case 
* is 50 cycles (cache miss on every branch (13 cycles per) and 11 
* instructions executed.  This algorithm assumes at least one bit 
* is set.
*
* RETURNS: index of first set bit (1 - 8)
*
* int vxBinarySearch(eightBits)
*     UINT8 eightBits;	- character to return index with reference to
*
* NOMANUAL

*/

#define	LS_NIBBLE	0xf		/* 00001111 in binary */
#define	LS_2BITS	0x3		/* 00000011 in binary */
#define	LS_BIT		0x1		/* 00000001 in binary */

	.ent	vxBinarySearch
vxBinarySearch:
	andi	t0, a0, LS_NIBBLE 	/* mask 4 lsbs */
	beq	t0, zero, b8to5		/* if equal, ls 4 bits are zero */
	andi	t0, a0, LS_2BITS 	/* mask 2 lsbs */
	beq	t0, zero, b3orb4	/* if equal, ls 2 bits are zero */
	andi	t0, a0, LS_BIT		/* mask 1 lsbs */
	beq	t0, zero, bit2		/* if equal, ls bit is zero */
bit1:	li	v0, 1			/* else ls bit is set */
	j	ra			/* and return */
b8to5:
	andi	t0, a0, LS_2BITS << 4
	beq	t0, zero, b8orb7	/* if equal, bits 5 and 6 are zero */
	andi	t0, a0, LS_BIT << 4	/* mask 1 lsbs */
	beq	t0, zero, bit6		/* if equal, bit 5 is zero */
bit5:	li	v0, 5			/* else bit 5 is set */
	j	ra			/* and return */
b8orb7:	
	andi	t0, a0, LS_BIT << 6
	beq	t0, zero, bit8		/* if equal, bit 8 is zero */
bit7:	li	v0, 7			/* else bit 7 is set */
	j	ra			/* and return */
b3orb4:
	andi	t0, a0, LS_BIT << 2
	beq	t0, zero, bit4		/* if equal, bit 3 is zero */
bit3:	li	v0, 3			/* else bit 3 is set */
	j	ra			/* and return */
bit2:					/* bit 2 is set */
	li	v0, 2
	j	ra			/* and return */
bit4:					/* bit 4 is set */
	li	v0, 4
	j	ra			/* and return */
bit6:					/* bit 6 is set */
	li	v0, 6
	j	ra			/* and return */
bit8:					/* bit 8 is set */
	li	v0, 8
	j	ra			/* and return */
	.end	vxBinarySearch

/*********************************************************************
*
* vxHashSearch - use a hashtable search to find set bit
*
* DESCRIPTION
*	This routine uses a hashtable search on an 8 bit value
*	to find the index of a set bit (one).  
*
*
* RETURNS
*	index of first set bit (1 - 8)
*
* NOTE
*   This hashtable search algorithm is used to make a deterministic 
*   search for a set bit in a register.  A straight forward linear 
*   search takes best case (no cache misses) 12 to 40 cycles.  If 
*   we implement a hash table we need at least 256 bytes of data, 
*   and if the data cache misses (and it usually will) we suffer 
*   a 23 cycle penalty (best case 4 cycles, worst case 39 cycles).  
*   The instruction cache on the r3k does instruction streaming so 
*   even if we miss, we excecute as we are fetching in instructions.  
*   Best case cycle count is 11 cycles (all in I-Cache), worst case 
*   is 50 cycles (cache miss on every branch (13 cycles per) and 11 
*   instructions executed.  This algorithm assumes at least one bit 
*   is set.
*
* int vxHashSearch(eightBits)
*     UINT8 eightBits;	- character to return index with reference to
*
* NOMANUAL

*/

	.ent	vxHashSearch
vxHashSearch:
	lbu	v0, ffsLsbTbl(a0)	/* lookup value */
	add	v0, 1			/* compensate for 0-7 return */
	j	ra			/* and return   */
	.end	vxHashSearch

/******************************************************************************
*
* vxFpscrSet - set the content of FPSCR
*
* DESCRIPTION
*	Set the content of FPSCR
*
* RETURNS:	 N/A
*
* NOMANUAL
*
* void vxFpscrSet (int fpscr)
*
*/

	.ent	vxFpscrSet
vxFpscrSet:
	.set	noreorder
	ctc1	a0, C1_SR
	HAZARD_CP_WRITE
	.set	reorder
	
	j	ra
	.end	vxFpscrSet

/******************************************************************************
*
* vxFpscrGet - get the content of FPSCR
*
* DESCRIPTION
*	Get the content of FPSCR
*
* RETURNS: contents of FPSCR
*
* NOMANUAL
*
* int vxFpscrGet ()
*
*/

	.ent	vxFpscrGet
vxFpscrGet:
	.set	noreorder
	cfc1	v0, C1_SR
	HAZARD_CP_READ
	.set	reorder
	
	j	ra
	.end	vxFpscrGet

#ifdef _WRS_MIPS_LL_SC	
/******************************************************************************
*
* vxTas_llsc -  Perform a test-and-set operation using the MIPS III load-linked,
*		store-conditional instructions.
*
* DESCRIPTION
*	For MIPS CPU_FAMILIES with load-linked, store-conditional support, this
*	routine is used to perform a test-and-set operation.  CPU_FAMILIES with
*	this support have the _WRS_MIPS_LL_SC macro defined.
*
* RETURNS
*	TRUE if the value had not been set, but is now.
*	FALSE if the value was set already.
*
* NOTE
*	This implementation requires that the address be in cacheable coherent 
*	space.  There's no easy way to test for that.  (Typically, it will be true 
*	if using KSEG0 with Config:K0 set properly, but there are other conditions 
*	in which it is true which should not be excluded by this implementation.)
*
* SEE ALSO: vxLib: vxTas(), sysLib: sysBusTas()
*/
	.ent	vxTas_llsc
vxTas_llsc:	
	.set noreorder

	ori	t0, a0, 0x3
	andi	t1, a0, 0x3

	xori	t0, t0, 0x3		/* t0 = aligned address */
	xori	t1, t1, 0x3

	li	t2, 0xff
	sll	t1, t1, 0x3		/* t1 = bit shift */

	sll	t2, t2, t1		/* t2 = byte mask */

	sync				

	ll	t3, 0(t0)		/* t3 = word containing flag */
	and	t4, t2, t3		/* t4 = flag */
	bne	t4, zero, 1f		/* if already set, just fail. */

	or	t4, t2, t3		/* t4 = word with flag set. */
	sc	t4, 0(t0)		/* store it back, t0 == sc flag */
	beq	t4, zero, 1f
	nop

	/* success: flag was previously unset, and new value written.*/
	jr	ra
	li	v0, TRUE


	/* failure: flag was previously set. */
1:	jr	ra
	li	v0, FALSE
	.set reorder
	.end	vxTas_llsc	
#endif

