/* cacheCW4011ALib.s - LSI CW4011 cache management assembly routines */

/* Copyright 1997-2001 Wind River Systems, Inc. */
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
01f,02aug01,mem  Diab integration
01e,16jul01,ros  add CofE comment
01d,08jan98,dra  Added additional support functions.
01c,06may97,dra  Rewrote _cw4011Invalidate to use cache tags.
01b,25apr97,dra	 Added _cw4011SetMode.
01a,03mar97,dra	 written, based on cacheCW4kALib.s, ver 01a.
*/

/*
DESCRIPTION
	
This file contains LSI CW4011 cache routines written in assembly language.
	
For general information about caching, see the manual entry for cacheLib.

INCLUDE FILES: cacheLib.h

SEE ALSO: cacheCW4011Lib, cacheLib,
.I "MiniRISC CW4011 Superscalar Microprocessor Core Technical Manual",
Gerry Kane:
.I "MIPS R3000 RISC Architecture"
*/

#define _ASMLANGUAGE
	
	/* includes */
	
#include "vxWorks.h"
#include "asm.h"
#include "cacheLib.h"

	/* defines */

#define DCACHE_SETS 	(CCC_DE0|CCC_DE1)
#define ALL_CACHE_SETS	(CCC_DE0|CCC_DE1|CCC_IE0|CCC_IE1)
#define TAG_UNSPEC_BITS (0x3ff)

	/* globals */
	
	.globl	_cw4011Invalidate		/* invalidate cache */
	.globl	_cw4011InvalidateAll		/* invalidate whole cache */
	.globl	_cw4011Flush			/* flush a dcache */
	.globl	_cw4011FlushAndDisable		/* flush and disable dcache */
	.globl  _cw4011ConfigGet		/* read C0_CONFIG */
	.globl  _cw4011ConfigSet		/* write C0_CONFIG */

	.text
	.set	reorder

/*****************************************************************************
*
* _cw4011Invalidate - invalidate locations in the requested CW4011 cache.
*
* This routine traverse the sets of cache lines specified in a1&a2, extracts
* the cache line tag field for each, compares this tag with the address
* range specfied in 16(sp) through 20(sp), and if the cache line contains
* data in the range, invalidates that line of data.
*
* NOTE:	This is not a user callable routine (see cacheCW4011Invalidate())
* Very little validation of the args is done (called only from cacheLib).
* 
* RETURNS: N/A
*
* NOMANUAL

* void _cw4011Invalidate
*       (
*	UINT configBits,	/@ (a0) which cache set to enable @/
*	UINT cacheLineMask,	/@ (a1) mask to extract cache line number @/
*	UINT startLine,		/@ (a2) starting cache line "address" @/
*	UINT numLines,		/@ (a3) number of candidate cache lines @/
*	UINT startAdr,		/@ 16(sp)->(v0)   inclusive base of region @/
*	UINT endAdr		/@ 20(sp)->(v1) inclusive end of region @/
*	)		
*/
	.ent	_cw4011Invalidate
_cw4011Invalidate:
	beqz	a0, invalDone			/* no cache bits? */
	beqz	a3, invalDone			/* no lines? */

	lw	v0, 16(sp)			/* lower bound in v0 */
	lw	v1, 20(sp)			/* upper bound in v1 */
	
	/* disable ints */
	mfc0	t0,C0_SR			/* unmod'd SR in t0 */
	and	t1,t0,~SR_IEC
	mtc0	t1,C0_SR

	/* switch to KSEG1  */
	la	t1, 1f				/* run uncached */
	or	t1, K1BASE
	j	t1
1:
	mfc0	t1, C0_CONFIG			/* unmod'd CONFIG in t1 */
	
	/* build masks for tag access (t2) and line invalidation (t3) */
	and	t2, t1, ~(ALL_CACHE_SETS)	/* disable current sets */
	or	t2, a0				/* enable desired sets */
	ori	t3, t2, (CCC_ISC|CCC_INV)	/* t3 used for invalidate */
	ori	t2, (CCC_ISC|CCC_TAG)		/* t2 used for tag access */

	/* loop start - test tags for each line - invalidate on match */
loop:		
	/* start of tag test */
	.set	noreorder
	mtc0	t2, C0_CONFIG
	nop	/* can't be lw/sw */
	nop	/* can't be lw/sw */
	nop	/* can't be lw/sw */
	.set	reorder
	
	lw	t4, (a2)			/* read line's tag */
	and	t5, t4, CACHETAG_VALID		/* valid? */
	beqz	t5, skip			/* skip if not valid */
	and	t4, ~TAG_UNSPEC_BITS		/* unspec bits to 0 */
	and	t5, a2, TAG_UNSPEC_BITS		/* fill in from a2... */
	or	t4, t5				/* ...to get test adr */

	/* 
  	 * test for t4 within [lower, upper].  LSBs of lower are cleared
	 * and LSBs of upper are set in the caller to avoid having to
	 * worry about edge conditions on the region endpoints.
	 */
	sltu	t5, t4, v0
	bnez	t5, skip			/* skip if < lower */
	sltu	t5, v1, t4
	bnez	t5, skip			/* skip iv > upper */
	/* end of tag test */
		
	/* start of invalidation */
	.set	noreorder
	mtc0	t3, C0_CONFIG
	nop	/* can't be lw/sw */
	nop	/* can't be lw/sw */
	nop	/* can't be lw/sw */
	.set	reorder
	sw	zero,(a2)			/* invalidate this line */
	/* end of invalidation */
	
skip:	
	addu	a2,CACHE_CW4011_LINE_SIZE  	/* next line */
	and	a2,a1				/* wrap */
	subu	a3,1			   	/* decrement numLines */
	bnez	a3,loop
	
	.set	noreorder
	mtc0	t1, C0_CONFIG			/* restore CCC */
	nop	/* can't be lw/sw */
	nop	/* can't be lw/sw */
	nop	/* can't be lw/sw */
	.set	reorder
	mtc0	t0,C0_SR			/* restore SR */
invalDone:
	j	ra
	.end	_cw4011Invalidate

/*****************************************************************************
*
* _cw4011InvalidateAll - invalidate entire requested CW4011 cache.
*
* _cw4011InvalidateAll is used to invalidate each entry in the requested
* cache.  This function is used at system startup, and whenever the caches
* are disabled, so that no stale data is present when the caches are
* subsequently enabled.
*
* NOTES: This is not a user callable routine.
*
* RETURNS: N/A
*
* NOMANUAL

* void _cw4011InvalidateAll
*       (
*	CACHE_TYPE cacheType	/@ (a0) type of cache to invalidate @/
*	UINT	   cacheMask	/@ (a1) enable mask for the caches @/
*	)		
*/
	.ent	_cw4011InvalidateAll
_cw4011InvalidateAll:	
	
	/* disable ints */
	mfc0	t7,C0_SR		/* maintain unmod'd SR in t7 */
	and	t0,t7,~SR_IEC
	mtc0	t0,C0_SR

	la	t0, 1f			/* run in uncached space */
	or	t0, K1BASE
	j	t0
1:
	/* flush instructions require that caches be enabled */
	mfc0	t6, C0_CONFIG		/* maintain unmod'd CONFIG in t6 */
	or	t0, t6, a1		/* enable requested caches */
	.set	noreorder
	mtc0	t0, C0_CONFIG
	nop	/* can't be load/store */
	nop	/* can't be load/store */
	nop	/* can't be load/store */
	.set	reorder
	
dcache_test:		
	subu	t0, a0, _DATA_CACHE	/* Invalidating data cache? */
	bnez	t0, icache_test
dcache_inv:	
	/* flush data cache */
	.set	noreorder
	flushd
	nop	/* required after "flushd" */
	nop	/* required after "flushd" */
	nop	/* required after "flushd" */
	.set	reorder
	b	invdone
	
icache_test:
	subu	t0, a0, _INSTRUCTION_CACHE
	bnez	t0, invdone
	/* flush instruction cache */
icache_inv:	
	.set	noreorder
	flushi
	nop	/* required after "flushi" */
	nop	/* required after "flushi" */
	nop	/* required after "flushi" */
	.set	reorder
	
invdone:	
	/* restore configuration and interrupt state */
	.set	noreorder
	mtc0	t6, C0_CONFIG
	nop	/* can't be load/store */
	nop	/* can't be load/store */
	nop	/* can't be load/store */
	.set	reorder
	mtc0	t7, C0_SR
	j	ra
	.end	_cw4011InvalidateAll
	

/*****************************************************************************
*
* _cw4011Flush - flush locations in the CW4011 data cache
*
* This routine flushes a3 <numLines> entries in the CW4011 cache
* given in ra0 <cacheMask>, starting at a2 <baseAddr>.  The cache
* size is implicit in ra1 <cacheLineMask>, used for wrap around.
*
* NOTE:	This is not a user callable routine (see cacheCW4011Flush())
* No validation of args (called only from cacheLib).
* 
* RETURNS: N/A
*
* NOMANUAL

* void _cw4011Flush
*       (
*	UINT	cacheMask,	/@ (a0) which cache sets to enable @/
*	UINT	cacheLineMask,  /@ (a1) mask to extract cache line number @/
*	UINT	startLine,	/@ (a2) virtAddr & cacheLineMask @/
*	UINT	numLines	/@ (a3) number of cache lines to flush @/
*       )
*/
	.ent	_cw4011Flush
_cw4011Flush:
	beqz	a0, flushDone		/* no cache bits? */
	beqz	a3, flushDone		/* no lines? */
	bnez	a2, 1f			/* if startLine */
	or	a2, K0BASE		/* else default */
1:	
	/* disable ints */
	mfc0	t7,C0_SR		/* maintain unmod'd SR in t7 */
	and	t0,t7,~SR_IEC
	mtc0	t0,C0_SR

	/* switch to KSEG1  */
	la	t0, 1f			/* run uncached */
	or	t0, K1BASE
	j	t0
1:
	/* flush (writeback) each cache line */
	.set	noreorder
	wb	0(a2)			   /* Flush */
	nop	/* three nop's required after "wb" */
	nop	/* three nop's required after "wb" */
	nop	/* three nop's required after "wb" */
	.set	reorder
	addu	a2,CACHE_CW4011_LINE_SIZE  /* next line */
	and	a2,a1			   /* wrap */
	subu	a3,1			   /* decrement numLines */
	bnez	a3,1b
	mtc0	t7,C0_SR		/* restore SR */
	
flushDone:
	j	ra			/* return the way we came */
	.end	_cw4011Flush

		
/*****************************************************************************
*
* _cw4011FlushAndDisable - flush and then disable the CW4011 data cache.
*
* This routine flushes the entire data cache, and then disables it.  

* NOTE:	This is not a user callable routine.  This routine is expected to
* be called with interrupts already locked by the caller.
* 
* RETURNS: N/A
*
* NOMANUAL

* void _cw4011FlushAndDisable
*       (
*	UINT	numLines	/@ (a0) number of cache lines to flush @/
*       )
*/
	.ent	_cw4011FlushAndDisable
_cw4011FlushAndDisable:
	li	t1, K0BASE
	
	/* switch to KSEG1  */
	la	t0, 1f			/* run uncached */
	or	t0, K1BASE
	j	t0
1:
	/* flush (writeback) each cache line */
	.set	noreorder
	wb	0(t1)			   /* Flush */
	nop	/* three nop's required after "wb" */
	nop	/* three nop's required after "wb" */
	nop	/* three nop's required after "wb" */
	.set	reorder
	addu	t1,CACHE_CW4011_LINE_SIZE  /* next line */
	subu	a0,1			   /* decrement numLines */
	bnez	a0,1b
	
	/* disable the data caches */
	mfc0	t0, C0_CONFIG
	and	t0, ~(CCC_DE0 | CCC_DE1)
	.set	noreorder
	mtc0	t0, C0_CONFIG
	nop	/* can't be load/store */
	nop	/* can't be load/store */
	nop	/* can't be load/store */
	.set	reorder

	j	ra			/* return the way we came */
	.end	_cw4011FlushAndDisable

		
/*****************************************************************************
*
* _cw4011ConfigGet - Read the C0_CONFIG register.
*
* This routine reads and returns the current contents of C0_CONFIG register.
	
* RETURNS: The current contents of the C0_CONFIG register.
*
* NOMANUAL

* void _cw4011ConfigGet()
*/

_cw4011ConfigGet:	
	.ent	_cw4011ConfigGet
	mfc0	v0, C0_CONFIG
	j	ra
	.end	_cw4011ConfigGet
		

/*****************************************************************************
*
* _cw4011ConfigSet - Set the C0_CONFIG register.
*
* This routine sets the contents of C0_CONFIG register.
	
* RETURNS: N/A.
*
* NOMANUAL

* void _cw4011ConfigSet
	(
	UINT config
	)
*/

_cw4011ConfigSet:	
	.ent	_cw4011ConfigSet
	la	t0, 1f		/* run uncached */
	or	t0, K1BASE
	j	t0
1: 
	.set	noreorder
	mtc0	a0, C0_CONFIG
	nop	/* can't be lw/sw */
	nop	/* can't be lw/sw */
	nop	/* can't be lw/sw */
	.set	reorder
	j	ra
	.end	_cw4011ConfigSet
