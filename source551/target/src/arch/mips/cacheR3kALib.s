/* cacheR3kALib.s - MIPS R3000 cache management assembly routines */

/* Copyright 1984-2001 Wind River Systems, Inc. */
#include "copyright_wrs.h"

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
02l,15oct01,dgp  doc: correct synopsis formatting for doc build
02l,02aug01,mem  Diab integration
02k,16jul01,ros  add CofE comment
02j,12feb01,tlc  Perform HAZARD review.
02i,05jun00,dra  R3K R4K merge
02h,28feb00,dra  Add GTEXT, GDATA, FUNC macros to support omfDll & loader
02g,31jan00,dra  Suppress compiler warnings.
02f,27jul93,yao  when invalidating entire cache, assume default address of
		 K0BASE instead instead of zero.
02e,15feb93,jdi  made NOMANUAL: cacheR3kDCInvalidate(), cacheR3kDCReset(),
		 cacheR3kICInvalidate(), cacheR3kICReset()
02d,03feb93,jdi  fixed delimiter problem in routine headers.
02c,24jan93,jdi  documentation cleanup for 5.1.
02b,24sep92,jdi  documentation cleanup.
02a,02jul92,ajm  5.1 interface changes
01c,26may92,rrr  the tree shuffle
01b,04oct91,rrr  passed through the ansification filter
		  -changed VOID to void
		  -changed ASMLANGUAGE to _ASMLANGUAGE
		  -changed copyright notice
01a,28feb91,ajm  moved sysALib.s 4.02 routines into cacheALib.s for 5.0
*/

/*
DESCRIPTION
This library contains MIPS R3000 cache set-up and invalidation routines
written in assembly language.  The R3000 utilizes a variable-size
instruction and data cache that operates in write-through mode.  Cache
line size also varies.  Cache tags may be invalidated on a per-word basis
by execution of a byte write to a specified word while the cache is
isolated.  See also the manual entry for cacheR3kLib.

For general information about caching, see the manual entry for cacheLib.

INCLUDE FILES: cacheLib.h

SEE ALSO: cacheR3kLib, cacheLib, Gerry Kane:
.I "MIPS R3000 RISC Architecture"
*/

#define _ASMLANGUAGE
#define MINCACHE +(1*512)
#define MAXCACHE +(256*1024)
	
#include "vxWorks.h"
#include "asm.h"

	/* externals */

	.extern	VAR_DECL(cacheDCacheSize) /* data cache size */
	.extern	VAR_DECL(cacheICacheSize) /* instruction cache size */

	.text
	.set	reorder

	.globl	GTEXT(cacheR3kDCReset)		/* zero d cache, reset parity */
	.globl	GTEXT(cacheR3kICReset)		/* zero i cache, reset parity */
	.globl	GTEXT(cacheR3kDCInvalidate)	/* invalidate i cache locations */
	.globl	GTEXT(cacheR3kICInvalidate)	/* invalidate d cache locations */
	.globl	GTEXT(cacheR3kIsize)		/* size inst cache */
	.globl	GTEXT(cacheR3kDsize)		/* size data cache */

/*******************************************************************************
*
* cacheR3kDCReset - clear the R3000 data cache and reset parity
*
* SYNOPSIS
* \ss
* void cacheR3kDCReset (void)
* \se
*
* This routine zeros the R3000 data cache without knowledge of size, and
* resets the cache parity by setting the parity error bit in the 
* R3000 status register.  This routine should be called once at boot time.
*
* RETURNS: N/A
*
* NOMANUAL
*
*/

	.ent	cacheR3kDCReset
FUNC_LABEL(cacheR3kDCReset)
	la	v0, 1f			/* run uncached */
	or	v0, K1BASE
	j	v0
1:

	mfc0	t0, C0_SR		/* save status reg */

	li	v0, (SR_ISC)
	mtc0	v0, C0_SR		/* LOCK INTS and isolate data cache */
	HAZARD_INTERRUPT
	li	v0, (K0BASE | MAXCACHE)	/* largest cache entry */
	li	t1, K0BASE		/* smallest cache entry for compare */

2:	sb	zero, -4(v0)
	sb	zero, -8(v0)
	sb	zero, -12(v0)
	sb	zero, -16(v0)
	sb	zero, -20(v0)
	sb	zero, -24(v0)
	sb	zero, -28(v0)
	sb	zero, -32(v0)
	subu	v0, 32
	bne     v0, t1, 2b		/* maxcache yet */


	or	t0, t0, SR_PE		/* clear parity error bit */

	mtc0	t0, C0_SR		/* back to previous state */
	HAZARD_CP_WRITE
	j	ra			/* return cached if that's how 
					   we started */
	.end	cacheR3kDCReset

/*******************************************************************************
*
* cacheR3kICReset - clear the R3000 instruction cache and reset parity
*
* SYNOPSIS
* \ss
* void cacheR3kICReset (void)
* \se
*
* This routine zeros the R3000 instruction cache without knowledge of size, 
* and resets the cache parity by setting the parity error bit in the 
* R3000 status register.  This routine should be called once at boot time.
*
* RETURNS: N/A
*
* NOMANUAL
*
*/

	.ent	cacheR3kICReset
FUNC_LABEL(cacheR3kICReset)

	mfc0	t0, C0_SR		/* save status reg */

	la	v0, 1f			/* run uncached */
	or	v0, K1BASE
	j	v0
1:
	li	v0, (SR_ISC | SR_SWC)	/* LOCK INTS, isolate and swap cache */
	mtc0	v0, C0_SR
	HAZARD_INTERRUPT
	li	v0, (K0BASE | MAXCACHE)	/* largest cache entry */
	li	t1, K0BASE		/* smallest cache entry for compare */

2:	sb	zero, -4(v0)
	sb	zero, -8(v0)
	sb	zero, -12(v0)
	sb	zero, -16(v0)
	sb	zero, -20(v0)
	sb	zero, -24(v0)
	sb	zero, -28(v0)
	sb	zero, -32(v0)
	subu	v0, 32
	bne     v0, t1, 2b		/* maxcache yet */

	or	t0, t0, SR_PE		/* clear parity error bit */

	mtc0	t0, C0_SR		/* back to previous state */
	HAZARD_CP_WRITE
	j	ra			/* return cached if that's how we
					   started */
	.end	cacheR3kICReset

/*******************************************************************************
*
* cacheR3kDCInvalidate - invalidate locations in the R3000 data cache
* 
* SYNOPSIS
* \ss
* void cacheR3kDCInvalidate
*     (
*     baseAddr,         /@ virtual address @/
*     byteCount         /@ number of bytes to invalidate @/
*     )
* \se
*
* This routine invalidates <byteCount> entries in the R3000 data cache 
* starting at <baseAddr>.  The data cache must already be sized by the 
* time this routine is called.
*
* RETURNS: N/A
*
* NOMANUAL
*
*/

	.ent	cacheR3kDCInvalidate
FUNC_LABEL(cacheR3kDCInvalidate)
	la	v0, 1f
	or	v0, K1BASE
	j	v0			/* run uncached */

1:	lw	t1, cacheDCacheSize	/* grab data cache size */
	mfc0	t3, C0_SR		/* save status register */

	beq	t1, zero, invalDDone	/* no data cache to invalidate */
	li	v0, (SR_ISC)

	.set	noreorder
	mtc0	v0, C0_SR		/* LOCK INTS, isolate data cache */
	HAZARD_INTERRUPT
	.set	reorder

	bltu	t1, a1, 2f		/* cache is smaller than region */
					/*   so clear entire cache */
	move	t1, a1			/*   else clear byteCount bytes */
2:	bne	a0, zero, 3f

	or	a0, K0BASE		/* set default address to K0BASE */
3:	addu	t1, a0			/* ending address + 1 */
  	move	t0, a0
	la	v0, 4f
	j	v0			/* run cached for speed */

/*
*  The R3000 has one tag for each 4 byte word.  A byte write while
*  the cache is isolated invalidates the tag.
*/

4:	sb	zero, 0(t0)		/* byte writes invalidate */
	addu	t0, 8
	sb	zero, -4(t0)		/* last entry yet ? */
	bltu	t0, t1, 4b
invalDDone:
	mtc0	t3, C0_SR		/* back to previous state */
	HAZARD_CP_WRITE
	j	ra			/* return the way we came */
	.end	cacheR3kDCInvalidate

/*******************************************************************************
*
* cacheR3kICInvalidate - invalidate locations in the R3000 instruction cache
*
* SYNOPSIS
* \ss
* void cacheR3kICInvalidate
*     (
*     baseAddr,         /@ virtual address @/
*     byteCount         /@ number of bytes to invalidate @/
*     )
* \se
*
* This routine invalidates <byteCount> entries in the R3000 instruction cache 
* starting at <baseAddr>.  The instruction cache must already be sized
* by the time this routine is called.
*
* RETURNS: N/A
*
* NOMANUAL
*
*/

	.ent	cacheR3kICInvalidate
FUNC_LABEL(cacheR3kICInvalidate)
	la	v0, 1f
	or	v0, K1BASE
	j	v0			/* run uncached */

1:	lw	t1, cacheICacheSize	/* grab inst. cache size */
	mfc0	t3, C0_SR		/* save status register */

	beq	t1, zero, invalIDone	/* no icache to invalidate */
	li	v0, (SR_ISC | SR_SWC)

	.set	noreorder
	mtc0	v0, C0_SR		/* LOCK INTS, isolate and swap cache */
	HAZARD_INTERRUPT
	.set	reorder
	
	bltu	t1, a1, 2f		/* cache is smaller than region */
					/* so clear entire cache */
	
	move	t1, a1			/*   else clear byteCount bytes */
2:	bne	a0, zero, 3f
	
	or	a0, K0BASE		/* set default address to K0BASE */
3:	addu	t1, a0
	move	t0, a0

	la	v0, 4f
	j	v0			/* run cached for speed */
	

/*
*  The R3000 has one tag for each 4 byte word.  A byte write while
*  the cache is isolated invalidates the tag.
*/

4:	sb	zero, 0(t0)		/* byte writes invalidate */
	addu	t0, 8
	sb	zero, -4(t0)		/* last entry yet ? */
	bltu	t0, t1, 4b
	
invalIDone:
	mtc0	t3, C0_SR		/* back to previous state */
	HAZARD_CP_WRITE
	j	ra			/* return the way we came */
	.end	cacheR3kICInvalidate

/*******************************************************************************
*
* cacheR3kDsize - return the size of the R3000 data cache
*
* SYNOPSIS
* \ss
* ULONG cacheR3kDsize (void)
* \se
*
* This routine returns the size of the R3000 data cache.  Generally, this
* value should be placed into the value <cacheDCacheSize> for use by other 
* routines.
*
* RETURNS: The size of the data cache in bytes.
*
*/


	.ent	cacheR3kDsize
FUNC_LABEL(cacheR3kDsize)
        la      v0, 1f                  /* run uncached */
        or      v0, K1BASE
        j       v0
1:
	mfc0	t0, C0_SR		/* save status reg */

	li	v0, SR_ISC		/* LOCK INTS, isolate cache */
	mtc0	v0, C0_SR
	HAZARD_INTERRUPT
	li	v0, MINCACHE		/* smallest possible cache page */
	li	t1, MAXCACHE		/* largest possible cache page */
	li	v1, 0xfeedface		/* unique pattern to search for */
	sw	v1, K0BASE(zero)	/* write out to first cache loc */

/*
*	Begin sizing Dcache.  We have placed a known value in the
*	first cache entry.  We begin searching at mincache, and
*	continue till we reach maxcache.  If we find the value
*	we know we wrapped around, and the value in v0 should
*	be our cache size.
*/

dSize:
	lw	t2, K0BASE(v0)		/* read cached page */
	beq	t2, v1, doneDSize	/* found it ?? */
	sll	v0, 1			/* increment cache page */
	ble	v0, t1, dSize		/* maxcache yet */

doneDSize:
	sb	zero, K0BASE(zero)	/* invalidate written entry */
	mtc0	t0, C0_SR		/* back to previous state */
	HAZARD_CP_WRITE
	j	ra			/* return as we came */
	.end	cacheR3kDsize

/*******************************************************************************
*
* cacheR3kIsize - return the size of the R3000 instruction cache
*
* SYNOPSIS
* \ss
* * ULONG cacheR3kIsize (void)
* \se
* 
* This routine returns the size of the R3000 instruction cache.  Generally,
* this value should be placed into the value <cacheDCacheSize> for use by
* other routines.
*
* RETURNS: The size of the instruction cache in bytes.
*
*/

	.ent	cacheR3kIsize
FUNC_LABEL(cacheR3kIsize)
        la      v0, 1f                  /* run uncached */
        or      v0, K1BASE
        j       v0
1:
	mfc0	t0, C0_SR		/* save status reg */

	li	v0, (SR_ISC | SR_SWC)
	mtc0	v0, C0_SR		/* LOCK INTS, isolate and swap cache */
	HAZARD_INTERRUPT
	li	v0, MINCACHE		/* smallest possible cache page/2 */
	li	t1, MAXCACHE		/* largest possible cache page */
	li	v1, 0xfeedface		/* unique pattern to search for */
	sw	v1, K0BASE(zero)	/* write out to first cache loc */

/*
*	Begin sizing Icache.  We have placed a known value in the
*	first cache entry.  We begin searching at mincache, and
*	continue till we reach maxcache.  If we find the value
*	we know we wrapped around, and the value in v0 should
*	be our cache size.
*/

iSize:
	lw	t2, K0BASE(v0)		/* read cached page */
	beq	t2, v1, doneISize	/* found it ?? */
	sll	v0, 1			/* increment cache page */
	ble	v0, t1, iSize		/* maxcache yet */

doneISize:
	sb	zero, K0BASE(zero)	/* invalidate written entry */
	mtc0	t0, C0_SR		/* unisolate and unswap */
	HAZARD_CP_WRITE
	j	ra			/* return as we came */
	.end	cacheR3kIsize
