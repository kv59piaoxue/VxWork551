/* cacheVr4131ALib.s - MIPS R4000 cache management assembly routines */

/* Copyright 1984-2002 Wind River Systems, Inc. */
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
01b,18jan02,agf  add explicit align directive to data section(s)
01b,08feb02,sru  fix vcacheop's to use a0 for start address (SPR #73187).
01a,11dec01,sru  created, based on cacheR4kALib.s
*/

/*
DESCRIPTION
This library contains MIPS  cache set-up and invalidation routines
written in assembly language for the Vr4131 processor.  The R4000 
utilizes a variable-size instruction and data cache that operates in
write-back mode.  Cache line size also varies. See also the manual 
entry for cacheVr4131Lib.

For general information about caching, see the manual entry for cacheLib.

INCLUDE FILES: cacheLib.h

SEE ALSO: cacheVr4131Lib, cacheLib
*/

#define _ASMLANGUAGE
#include "vxWorks.h"
#include "asm.h"

/*
 * cacheop macro to automate cache operations
 * first some helpers...
 */
#define _mincache(size, maxsize) \
	bltu	size,maxsize,9f ;	\
	move	size,maxsize ;		\
9:

#define _align(minaddr, maxaddr, linesize) \
	.set noat ; \
	subu	AT,linesize,1 ;	\
	not	AT ;			\
	and	minaddr,AT ;		\
	addu	maxaddr,-1 ;		\
	and	maxaddr,AT ;		\
	.set at

/* general operations */
	
#define doop1(op1) \
	cache	op1,0(a0) ;		\
	HAZARD_CACHE
	
#define doop2(op1, op2) \
	cache	op1,0(a0) ;		\
	HAZARD_CACHE      ;		\
	cache	op2,0(a0) ;		\
	HAZARD_CACHE

/* specials for cache initialisation */
	
#define doop1lw(op1) \
	lw	zero,0(a0)
	
#define doop1lw1(op1) \
	cache	op1,0(a0)  ;		\
	HAZARD_CACHE	   ;		\
	lw	zero,0(a0) ;		\
	cache	op1,0(a0)  ;		\
	HAZARD_CACHE
	
#define doop121(op1,op2) \
	cache	op1,0(a0) ;		\
	HAZARD_CACHE      ;		\
	cache	op2,0(a0) ;		\
	HAZARD_CACHE	  ;		\
	cache	op1,0(a0) ;		\
	HAZARD_CACHE

#define _oploopn(minaddr, maxaddr, linesize, tag, ops) \
	.set	noreorder ;		\
10: 	doop##tag##ops ;		\
	bne     minaddr,maxaddr,10b ;	\
	add   	minaddr,linesize ;	\
	.set	reorder

/* finally the cache operation macros */
#define vcacheopn(kva, n, cacheSize, cacheLineSize, tag, ops) \
 	blez	n,11f ;			\
	addu	n,kva ;			\
	_align(kva, n, cacheLineSize) ; \
	_oploopn(kva, n, cacheLineSize, tag, ops) ; \
11:

#define icacheopn(kva, n, cacheSize, cacheLineSize, tag, ops) \
	_mincache(n, cacheSize);	\
 	blez	n,11f ;			\
	addu	n,kva ;			\
	_align(kva, n, cacheLineSize) ; \
	_oploopn(kva, n, cacheLineSize, tag, ops) ; \
11:

#define vcacheop(kva, n, cacheSize, cacheLineSize, op) \
	vcacheopn(kva, n, cacheSize, cacheLineSize, 1, (op))

#define icacheop(kva, n, cacheSize, cacheLineSize, op) \
	icacheopn(kva, n, cacheSize, cacheLineSize, 1, (op))

	.text

	.globl GTEXT(cacheVr4131Reset)		/* low level cache init */
	.globl GTEXT(cacheVr4131RomTextUpdate)
	.globl GTEXT(cacheVr4131DCFlushInvalidateAll)
	.globl GTEXT(cacheVr4131DCFlushInvalidate)
	.globl GTEXT(cacheVr4131DCInvalidateAll)
	.globl GTEXT(cacheVr4131DCInvalidate)
	.globl GTEXT(cacheVr4131ICInvalidateAll)
	.globl GTEXT(cacheVr4131ICInvalidate)

	.globl GDATA(cacheVr4131DCacheSize)	/* data cache size */
	.globl GDATA(cacheVr4131ICacheSize)	/* inst. cache size */
	.globl GDATA(cacheVr4131SCacheSize)	/* secondary cache size */

	.globl GDATA(cacheVr4131DCacheLineSize) /* data cache line size */
	.globl GDATA(cacheVr4131ICacheLineSize) /* inst. cache line size */
	.globl GDATA(cacheVr4131SCacheLineSize) /* secondary cache line size */
	.globl GTEXT(cacheVr4131VirtPageFlush)	/* flush cache on MMU page unmap */
	.globl GTEXT(cacheVr4131Sync)		/* cache sync operation */
	
	.data
	.align	4
cacheVr4131ICacheSize:
	.word	0
cacheVr4131DCacheSize:
	.word	0
cacheVr4131SCacheSize:
	.word	0
cacheVr4131ICacheLineSize:
	.word	0
cacheVr4131DCacheLineSize:
	.word	0
cacheVr4131SCacheLineSize:
	.word	0
	.text

/*******************************************************************************
*
* cacheVr4131Reset - low level initialisation of the R4000 primary caches
*
* This routine initialises the R4000 primary caches to ensure that they
* have good parity.  It must be called by the ROM before any cached locations
* are used to prevent the possibility of data with bad parity being written to
* memory.
* To initialise the instruction cache it is essential that a source of data
* with good parity is available. If the initMem argument is set, this routine
* will initialise an area of memory starting at location zero to be used as
* a source of parity; otherwise it is assumed that memory has been
* initialised and already has good parity.
*
* RETURNS: N/A
*

* void cacheVr4131Reset (initMem)

*/
	.ent	cacheVr4131Reset
FUNC_LABEL(cacheVr4131Reset)
	
	/* disable all i/u and cache exceptions */
resetcache:
	mfc0	v0,C0_SR
	HAZARD_CP_READ
	and	v1,v0,SR_BEV
	or	v1,SR_DE
	mtc0	v1,C0_SR

	/* set invalid tag */
	mtc0	zero,C0_TAGLO
	mtc0	zero,C0_TAGHI
	HAZARD_CACHE_TAG

	/*
	 * The caches are probably in an indeterminate state, so we force
	 * good parity into them by doing an invalidate, load/fill, 
	 * invalidate for each line.  We do an invalidate of each line in
	 * the cache before we perform any fills, because we need to 
	 * ensure that each way of an n-way associative cache is invalid
	 * before performing the first Fill_I cacheop.
	 */

	/* 1: initialise icache tags */
	li	a0,K0BASE
	move	a2,t2		# icacheSize
	move	a3,t4		# icacheLineSize
	move	a1,a2
	icacheop(a0,a1,a2,a3,Index_Store_Tag_I)

	/* 2: fill icache */
	li	a0,K0BASE
	move	a2,t2		# icacheSize
	move	a3,t4		# icacheLineSize
	move	a1,a2
	icacheop(a0,a1,a2,a3,Fill_I)

	/* 3: clear icache tags */
	li	a0,K0BASE
	move	a2,t2		# icacheSize
	move	a3,t4		# icacheLineSize
	move	a1,a2
	icacheop(a0,a1,a2,a3,Index_Store_Tag_I)

	/* 1: initialise dcache tags */
	li	a0,K0BASE
	move	a2,t3		# dcacheSize
	move	a3,t5		# dcacheLineSize
	move	a1,a2
	icacheop(a0,a1,a2,a3,Index_Store_Tag_D)

	/* 2: fill dcache */
	li	a0,K0BASE
	move	a2,t3		# dcacheSize
	move	a3,t5		# dcacheLineSize
	move	a1,a2
	icacheopn(a0,a1,a2,a3,1lw,(dummy))

	/* 3: clear dcache tags */
	li	a0,K0BASE
	move	a2,t3		# dcacheSize
	move	a3,t5		# dcacheLineSize
	move	a1,a2
	icacheop(a0,a1,a2,a3,Index_Store_Tag_D)

	/* FIXME assumes unified I & D in scache */
	li	a0,K0BASE
	move	a2,t6
	move	a3,t7
	move	a1,a2
	icacheopn(a0,a1,a2,a3,1lw1,(Index_Store_Tag_SD))

	mtc0	v0,C0_SR
	HAZARD_CP_WRITE

	j	ra
	.end	cacheVr4131Reset

/******************************************************************************
*
* cacheVr4131RomTextUpdate - cache text update like functionality from the bootApp
*
*	a0	i-cache size
*	a1	i-cache line size
*	a2	d-cache size
*	a3	d-cache line size
*
* RETURNS: N/A
*

* void cacheVr4131RomTextUpdate ()

*/
	.ent	cacheVr4131RomTextUpdate
FUNC_LABEL(cacheVr4131RomTextUpdate)
	/* Save I-cache parameters */
	move	t0,a0
	move	t1,a1

	/* Check for primary data cache */
	blez	a2,99f

	/* Flush-invalidate primary data cache */
	li	a0,K0BASE
	move	a1,a2
	icacheop(a0,a1,a2,a3,Index_Writeback_Inv_D)
99:
	/* replace I-cache parameters */
	move	a2,t0
	move	a3,t1
	
	/* Check for primary instruction cache */
	blez	a0,99f
	
	/* Invalidate primary instruction cache */
	li	a0,K0BASE
	move	a1,a2
	icacheop(a0,a1,a2,a3,Index_Invalidate_I)
99:
	j	ra
	.end	cacheVr4131RomTextUpdate


/*******************************************************************************
*
* cacheVr4131DCFlushInvalidateAll - flush entire R4000 data cache
*
* RETURNS: N/A
*

* void cacheVr4131DCFlushInvalidateAll (void)

*/
	.ent	cacheVr4131DCFlushInvalidateAll
FUNC_LABEL(cacheVr4131DCFlushInvalidateAll)
	/* secondary cacheops do all the work if present */
	lw	a2,cacheVr4131SCacheSize
	blez	a2,1f
	lw	a3,cacheVr4131SCacheLineSize
	li	a0,K0BASE
	move	a1,a2
	icacheop(a0,a1,a2,a3,Index_Writeback_Inv_SD)
	b	99f

1:	lw	a2,cacheVr4131DCacheSize
	blez	a2, 99f
	lw	a3,cacheVr4131DCacheLineSize
	li	a0,K0BASE
	move	a1,a2
	icacheop(a0,a1,a2,a3,Index_Writeback_Inv_D)

99:	j	ra

	.end	cacheVr4131DCFlushInvalidateAll

/*******************************************************************************
*
* cacheVr4131DCFlush - flush R4000 data cache locations
*
* RETURNS: N/A
*

* void cacheVr4131DCFlushInvalidate
*     (
*     baseAddr,		/@ virtual address @/
*     byteCount		/@ number of bytes to invalidate @/
*     )

*/
	.ent	cacheVr4131DCFlushInvalidate
FUNC_LABEL(cacheVr4131DCFlushInvalidate)

	move	t0, a0	/* copy of virtAddr */
	move	t1, a1	/* copy of byte count */
	
	/* flush range */

	lw	a2,cacheVr4131DCacheSize
	lw	a3,cacheVr4131DCacheLineSize
	vcacheop(a0,a1,a2,a3,Hit_Writeback_D)

	/* invalidate */

	move	a0, t0	/* restore virtAddr */
	move	a1, t1	/* restore byte count */
	lw	a2,cacheVr4131DCacheSize
	lw	a3,cacheVr4131DCacheLineSize
	vcacheop(a0,a1,a2,a3,Hit_Invalidate_D)
	
	j	ra
	.end	cacheVr4131DCFlushInvalidate


/*******************************************************************************
*
* cacheVr4131DCInvalidateAll - invalidate entire R4000 data cache
*
* RETURNS: N/A
*

* void cacheVr4131DCInvalidateAll (void)

*/
	.ent	cacheVr4131DCInvalidateAll
FUNC_LABEL(cacheVr4131DCInvalidateAll)
	/* secondary cacheops do all the work if present */
	lw	a2,cacheVr4131SCacheSize
	blez	a2,1f
	lw	a3,cacheVr4131SCacheLineSize
	li	a0,K0BASE
	move	a1,a2
	icacheop(a0,a1,a2,a3,Index_Writeback_Inv_SD)
	b	99f

1:	lw	a2,cacheVr4131DCacheSize
	blez	a2, 99f
	lw	a3,cacheVr4131DCacheLineSize
	li	a0,K0BASE
	move	a1,a2
	icacheop(a0,a1,a2,a3,Index_Writeback_Inv_D)

99:	j	ra

	.end	cacheVr4131DCInvalidateAll

/*******************************************************************************
*
* cacheVr4131DCInvalidate - invalidate R4000 data cache locations
*
* RETURNS: N/A
*

* void cacheVr4131DCInvalidate
*     (
*     baseAddr,		/@ virtual address @/
*     byteCount		/@ number of bytes to invalidate @/
*     )

*/
	.ent	cacheVr4131DCInvalidate
FUNC_LABEL(cacheVr4131DCInvalidate)

	/*
	 * This routine was originally written with a Hit_Writeback_Inv_D,
	 * which did a flush/invalidate operation.  NEC then informed WRS
	 * that Hit_Writeback_Inv_D wasn't trustworthy on some CPU
	 * silicon revision, so we should use separate Writeback and
	 * Invalidate operations instead.
	 *
	 * Since NEC authorized standalone use of Invalidate, in theory
	 * this code should be able to dispense with the flush portion
	 * entirely.  But, the 4131 cache has been _so_ sensitive,
	 * that it's deemed not worth the risk to change the implementation
	 * until the changed version can be _thoroughly_ tested.
 	 */
	
	move	t0, a0	/* backup of virtAddr */
	move	t1, a1	/* backup of byteCount */

  	/* flush */

	lw	a2,cacheVr4131DCacheSize
	lw	a3,cacheVr4131DCacheLineSize
	vcacheop(a0,a1,a2,a3,Hit_Writeback_D)

	/* invalidate */

	move	a0, t0	/* restore virtAddr */
	move	a1, t1	/* restore byte count */
	lw	a2,cacheVr4131DCacheSize
	lw	a3,cacheVr4131DCacheLineSize
	vcacheop(a0,a1,a2,a3,Hit_Invalidate_D)
	
	j	ra
	.end	cacheVr4131DCInvalidate

/*******************************************************************************
*
* cacheVr4131ICInvalidateAll - invalidate entire R4000 instruction cache
*
* RETURNS: N/A
*

* void cacheVr4131ICInvalidateAll (void)

*/
	.ent	cacheVr4131ICInvalidateAll
FUNC_LABEL(cacheVr4131ICInvalidateAll)
	/* secondary cacheops do all the work if present */
	lw	a2,cacheVr4131SCacheSize
	blez	a2,1f
	lw	a3,cacheVr4131SCacheLineSize
	li	a0,K0BASE
	move	a1,a2
	icacheop(a0,a1,a2,a3,Index_Writeback_Inv_SD)
	b	98f

1:	lw	a2,cacheVr4131ICacheSize
	blez	a2,99f
	lw	a3,cacheVr4131ICacheLineSize
	li	a0,K0BASE
	move	a1,a2
	icacheop(a0,a1,a2,a3,Index_Invalidate_I)

98:	/* touch TLBHI register to clear the branch history buffer. This is */
	/* required for (at a minimum) the NEC Vr4122. */
	
	mfc0	a2, C0_TLBHI
	HAZARD_CP_READ
	mtc0	a2, C0_TLBHI
	HAZARD_TLB

99:	j	ra

	.end	cacheVr4131ICInvalidateAll

/*******************************************************************************
*
* cacheVr4131ICInvalidate - invalidate R4000 data cache locations
*
* RETURNS: N/A
*

* void cacheVr4131ICInvalidate
*     (
*     baseAddr,		/@ virtual address @/
*     byteCount		/@ number of bytes to invalidate @/
*     )

*/
	.ent	cacheVr4131ICInvalidate
FUNC_LABEL(cacheVr4131ICInvalidate)
	/* secondary cacheops do all the work if present */
	lw	a2,cacheVr4131SCacheSize
	blez	a2,1f
	lw	a3,cacheVr4131SCacheLineSize
	move	a1,a2
	vcacheop(a0,a1,a2,a3,Hit_Writeback_Inv_SD)
	b	98f

1:	lw	a2,cacheVr4131ICacheSize
	blez	a2, 99f
	lw	a3,cacheVr4131ICacheLineSize
	vcacheop(a0,a1,a2,a3,Hit_Invalidate_I)
	
98:	/* touch TLBHI register to clear the branch history buffer. This is */
	/* required for (at a minimum) the NEC Vr4122. */
	
	mfc0	a2, C0_TLBHI
	HAZARD_CP_READ
	mtc0	a2, C0_TLBHI
	HAZARD_TLB

99:	j	ra
	.end	cacheVr4131ICInvalidate

/******************************************************************************
*
* cacheVr4131VirtPageFlush - flush one page of virtual addresses from caches
*
* Change ASID, flush the appropriate cache lines from the D- and I-cache,
* and restore the original ASID.
*
* CAVEAT: This routine and the routines it calls MAY be running to clear
* cache for an ASID which is only partially mapped by the MMU. For that
* reason, the caller may want to lock interrupts.
*
* RETURNS: N/A
*
* void cacheVr4131VirtPageFlush (UINT asid, void *vAddr, UINT pageSize);
*/
	.ent	cacheVr4131VirtPageFlush
FUNC_LABEL(cacheVr4131VirtPageFlush)
	/* Save parameters */
	move	t4,a0			/* ASID to flush */
	move	t0,a1			/* beginning VA */
	move	t1,a2			/* length */

	/*
	 * When we change ASIDs, our stack might get unmapped,
	 * so use the stack now to free up some registers for use:
	 *	t0 - virtual base address of page to flush
	 *	t1 - page size
		 *	t2 - original SR
	 *	t3 - original ASID
	 *	t4 - ASID to flush
	 */

	/* lock interrupts */

	mfc0	t2, C0_SR
	HAZARD_CP_READ	
	li	t3, ~SR_INT_ENABLE
	and	t3, t2
	mtc0	t3, C0_SR
	HAZARD_INTERRUPT

	/* change the current ASID to context where page is mapped */

	mfc0	t3, C0_TLBHI		/* read current TLBHI */
	HAZARD_CP_READ
	and	t3, 0xff		/* extract ASID field */
	beq	t3, t4, 0f		/* branch if no need to change */
	mtc0	t4, C0_TLBHI		/* Store new EntryHi  */	
	HAZARD_TLB
0:
	/* clear the virtual addresses from D- and I-caches */
	
	lw	a2,cacheVr4131DCacheSize
	blez	a2,1f

	move	a0, t0
	move	a1, t1
	lw	a3,cacheVr4131DCacheLineSize
	vcacheop(a0,a1,a2,a3,Hit_Writeback_D)
	
	move	a0, t0
	move	a1, t1
	lw	a2,cacheVr4131DCacheSize
	lw	a3,cacheVr4131DCacheLineSize
	vcacheop(a0,a1,a2,a3,Hit_Invalidate_D)
1:
	lw	a2,cacheVr4131ICacheSize
	blez	a2,1f	

	/* Invalidate primary instruction cache */
	move	a0,t0
	move	a1,t1
	lw	a3,cacheVr4131ICacheLineSize
	vcacheop(a0,a1,a2,a3,Hit_Invalidate_I)
1:	
	/* restore the original ASID */

	mtc0	t3, C0_TLBHI		/* Restore old EntryHi  */	
	HAZARD_TLB

	mtc0	t2, C0_SR		/* restore interrupts */
	
	j	ra
	.end	cacheVr4131VirtPageFlush

/******************************************************************************
*
* cacheVr4131Sync - sync region of memory through all caches
*
* RETURNS: N/A
*
* void cacheVr4131Sync (void *vAddr, UINT pageSize);
*/
	.ent	cacheVr4131Sync
FUNC_LABEL(cacheVr4131Sync)
	/* Save parameters */
	move	t0,a0			/* beginning VA */
	move	t1,a1			/* length */

	/* lock interrupts */

	mfc0	t2, C0_SR
	HAZARD_CP_READ
	li	t3, ~SR_INT_ENABLE
	and	t3, t2
	mtc0	t3, C0_SR
	HAZARD_INTERRUPT

	/*
	 * starting with primary caches, push the memory
	 * block out completely
	 */
	sync

	lw	a2,cacheVr4131ICacheSize
	blez	a2,1f	

	/* Invalidate primary instruction cache */
	move	a0,t0
	move	a1,t1
	lw	a3,cacheVr4131ICacheLineSize
	vcacheop(a0,a1,a2,a3,Hit_Invalidate_I)
1:
	lw	a2,cacheVr4131DCacheSize
	blez	a2,1f

	/* Flush primary data cache */
	move	a0, t0
	move	a1, t1
	lw	a3,cacheVr4131DCacheLineSize
	vcacheop(a0,a1,a2,a3,Hit_Writeback_D)

	/* Invalidate primary data cache */
	move	a0, t0
	move	a1, t1
	lw	a2, cacheVr4131DCacheSize
	lw	a3, cacheVr4131DCacheLineSize
	vcacheop(a0,a1,a2,a3,Hit_Invalidate_D)
	
1:	
	lw	a2,cacheVr4131SCacheSize
	blez	a2,1f

	/* Invalidate secondary cache */
	mtc0	zero,C0_TAGLO
	mtc0	zero,C0_TAGHI
	HAZARD_CACHE_TAG

	move	a0,t0
	move	a1,t1
	lw	a3,cacheVr4131SCacheLineSize
	icacheop(a0,a1,a2,a3,Index_Store_Tag_SD)
1:
	mtc0	t2, C0_SR		/* restore interrupts */
	
	j	ra
	.end	cacheVr4131Sync
