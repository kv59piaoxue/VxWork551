/* cacheCW400xALib.s - LSI CW400x core cache management assembly routines */

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
01e,02aug01,mem  Diab integration
01d,16jul01,ros  add CofE comment
01c,15dec97,dra  set icache refill size to 1 word in software test mode.
01b,20oct97,dra	 minor cleanup
01a,25apr96,dra  written, based on cacheR3kALib.s, ver 02f & code from
		 motorola PMON
*/

/*
DESCRIPTION
	
This library contains LSI CW400x core cache invalidation routines
written in assembly language.  The CW400x core utilizes a variable-size
instruction (1-64k) and data cache (1-32k) that operates in write-through
mode.  Cache tags may be invalidated on a per-word basis, and if necessary
cache lines may be flushed, by execution of a word write to a specified
word while the cache is in Software Test Mode.
	
See also the manual entry for cacheCW4kLib.

For general information about caching, see the manual entry for cacheLib.


INCLUDE FILES: cacheLib.h

SEE ALSO: cacheCW400xLib, cacheLib,
.I "MiniRISC CW400x Microprocessor Core Technical Manual",
Gerry Kane:
.I "MIPS R3000 RISC Architecture"
*/

#define _ASMLANGUAGE
#include "vxWorks.h"
#include "asm.h"

#define CACHE_LINE_SIZE		(16)		/* in bytes */
	
	/* internals */
	
	.globl	_cw4kCacheInvalidate		/* invalidate a cache */

	/* externals */

	.text
	.set	reorder

/*****************************************************************************
*
* cw4kCacheInvalidate - invalidate locations in the CW400x cache
*
* This routine invalidates ra3 <numLines> entries in the CW400x cache
* given in ra0 <configBits>, starting at ra2 <baseAddr>.  The cache
* size is implicit in ra1 <cacheLineMask>, used for wrap around.
*
* NOTE:	This is not a user callable routing (see cacheCW4kInvalidate())
* No validation of args (called only from cacheLib).
* 
* RETURNS: N/A
*
* NOMANUAL

* void _cw4kCacheInvalidate
*       (
*	UINT	configBits,	/@ which cache: DCACHE, ICACHE, IS1CACHE @/
*	UINT	cacheLineMask,  /@ K0BASE | line mask @/
*	UINT	startLine,	/@ virtAddr & cacheLineMask @/
*	UINT	numLines	/@ number of cache lines to flush @/
*       )

*/
	.ent	_cw4kCacheInvalidate
_cw4kCacheInvalidate:
	beqz	a3, invalDone		/* no lines? */
	bnez	a2, 1f			/* if startLine */
	or	a2, K0BASE		/* else default */
1:	
	/* disable ints */
	.set noreorder
	mfc0	t7,C0_SR
	nop
	and	t0,t7,~SR_IEC
	mtc0	t0,C0_SR
	.set reorder

	/* switch to KSEG1  */
	la	t0, 1f			/* run uncached */
	or	t0, K1BASE
	j	t0
1:
	/* Enter Cache Software Test Mode */
	lw	t8, CFG4000_REG
	and	t0, t8, ~(CFG_CMODEMASK|CFG_ICEN|CFG_IS1EN|CFG_DCEN|CFG_ISIZEMASK)
	or	t0, a0

	sw	t0, CFG4000_REG
	lw	t0, CFG4000_REG		/* wb flush */
	addu	t0, 1			/* wb flush */
1:
	sw	zero,(a2)		/* invalidate */
	addu	a2,CACHE_LINE_SIZE	/* next line */
	and	a2,a1			/* wrap */
	subu	a3,1			/* decrement numLines */
	bnez	a3,1b

	.set noreorder
	nop
	nop
	nop
	sw	t8,CFG4000_REG		/* restore CFGREG */
	lw	t0,CFG4000_REG		/* wb flush */
	addu	t0,1			/* wb flush */
	mtc0	t7,C0_SR		/* restore SR */
	nop
	.set	reorder
	
invalDone:
	j	ra			/* return the way we came */
	.end	_cw4kCacheInvalidate
