/* cacheTx49ALib.s - Toshiba Tx49 cache management assembly routines */

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
01b,09may02,jmt  modified to fix problems found in code review
01a,23apr02,jmt  derived from cacheR4kALib.s (01q,18jan02,agf)
*/

/*
DESCRIPTION
This library contains MIPS Tx49 cache set-up and invalidation routines
written in assembly language.  The Tx49 utilizes a variable-size
instruction and data cache that operates in write-back mode.   The cache is
four-way set associative and the library allows the cache line size to vary.
See also the manual entry for cacheTx49Lib.

For general information about caching, see the manual entry for cacheLib.

INCLUDE FILES: asm.h

SEE ALSO: cacheTx49Lib, cacheLib
*/

#define _ASMLANGUAGE
#include "vxWorks.h"
#include "asm.h"

/*
 * cacheop macro to automate cache operations
 * first some helpers...
 */
/* size = min(size, maxsize) */

#define _mincache(size, maxsize) \
	bltu	size,maxsize,9f ;	\
	move	size,maxsize ;		\
9:

/* aligns the address to the linesize */

#define _align(minaddr, maxaddr, linesize) \
	.set noat ; \
	subu	AT,linesize,1 ;	\
	not	AT ;			\
	and	minaddr,AT ;		\
	addu	maxaddr,-1 ;		\
	and	maxaddr,AT ;		\
	.set at

/* general operations */

/* do op1 on a cache line safely */

#define doop1(op1) \
	cache	op1,0(a0) ;		\
	HAZARD_CACHE
	
/* do op1 and op2 on a cache line safely */

#define doop2(op1, op2) \
	cache	op1,0(a0) ;		\
	HAZARD_CACHE      ;		\
	cache	op2,0(a0) ;		\
	HAZARD_CACHE

/* special Tx49 operations */

/* do op1 on all ways of a cache line  
 * only valid for index cache operations
 */

#define doop1_all_ways(op1) \
	cache	op1,0(a0) ;		\
	HAZARD_CACHE      ;		\
	cache	op1,1(a0) ;		\
	HAZARD_CACHE      ;		\
	cache	op1,2(a0) ;		\
	HAZARD_CACHE      ;		\
	cache	op1,3(a0) ;		\
	HAZARD_CACHE

/* do op1 and op2 on all ways of a cache line  
 * only valid for index cache operations
 */

#define doop2_all_ways(op1, op2) \
	doop1_all_ways(op1) ;		\
	doop1_all_ways(op2)

/* do op1, op2, op1 on all ways of a cache line  
 * only valid for index cache operations
 */

#define doop121_all_ways(op1,op2) \
	doop1_all_ways(op1) ;		\
	doop1_all_ways(op2) ;		\
	doop1_all_ways(op1)

/* specials for cache initialisation */
	
/* load word into a data cache line */

#define doop1lw(op1) \
	lw	zero,0(a0)

/* do op1, load word, do op1 on a cache line */

#define doop1lw1(op1) \
	cache	op1,0(a0)  ;		\
	HAZARD_CACHE	   ;		\
	lw	zero,0(a0) ;		\
	cache	op1,0(a0)  ;		\
	HAZARD_CACHE

/* do op1, op2, op1 on a cache line */

#define doop121(op1,op2) \
	cache	op1,0(a0) ;		\
	HAZARD_CACHE      ;		\
	cache	op2,0(a0) ;		\
	HAZARD_CACHE	  ;		\
	cache	op1,0(a0) ;		\
	HAZARD_CACHE

/* do tagged op on a range of addresses */

#define _oploopn(minaddr, maxaddr, linesize, tag, ops) \
	.set	noreorder ;		\
10: 	doop##tag##ops ;		\
	bne     minaddr,maxaddr,10b ;	\
	add   	minaddr,linesize ;	\
	.set	reorder

/* finally the cache operation macros */

/* do tagged op on a range of addresses, if size > 0 */

#define vcacheopn(kva, n, cacheSize, cacheLineSize, tag, ops) \
 	blez	n,11f ;			\
	addu	n,kva ;			\
	_align(kva, n, cacheLineSize) ; \
	_oploopn(kva, n, cacheLineSize, tag, ops) ; \
	sync	;				\
11:

/* do tagged op on a range of addresses up to the size of the cache */

#define icacheopn(kva, n, cacheSize, cacheLineSize, tag, ops) \
	_mincache(n, cacheSize);	\
 	blez	n,11f ;			\
	addu	n,kva ;			\
	_align(kva, n, cacheLineSize) ; \
	_oploopn(kva, n, cacheLineSize, tag, ops) ; \
	sync	;				\
11:

/* do op1 on a range of addresses */

#define vcacheop(kva, n, cacheSize, cacheLineSize, op) \
	vcacheopn(kva, n, cacheSize, cacheLineSize, 1, (op))

/* do op1 on a range of addresses, up to the size of the cache */

#define icacheop(kva, n, cacheSize, cacheLineSize, op) \
	icacheopn(kva, n, cacheSize, cacheLineSize, 1, (op))

/* do tagged op on all ways of a range of cache lines 
 * only valid for index cache ops
 */

#define icacheopn_all_ways(kva, n, cacheSize, cacheLineSize, tag, ops) \
	icacheopn(kva, n, cacheSize, cacheLineSize, tag##_all_ways, ops)

/* do op1 on all ways of a range of cache lines 
 * only valid for index cache ops
 */

#define icacheop_all_ways(kva, n, cacheSize, cacheLineSize, op) \
	icacheopn(kva, n, cacheSize, cacheLineSize, 1_all_ways, (op))


	.text

	.globl GTEXT(cacheTx49Reset)		/* low level cache init */
	.globl GTEXT(cacheTx49RomTextUpdate)	/* cache-text-update */
	.globl GTEXT(cacheTx49DCFlushInvalidateAll) /* clear entire d cache */
	.globl GTEXT(cacheTx49DCFlushInvalidate)/* clear d cache locations */
	.globl GTEXT(cacheTx49DCFlushAll)       /* flush entire d cache */
	.globl GTEXT(cacheTx49DCFlush)          /* flush d cache locations */
	.globl GTEXT(cacheTx49DCInvalidateAll)	/* invalidate entire d cache */
	.globl GTEXT(cacheTx49DCInvalidate)	/* invalidate d cache locations */
	.globl GTEXT(cacheTx49PTextUpdateAll)	/* update entire text area */
	.globl GTEXT(cacheTx49PTextUpdate)	/* update text area */
	.globl GTEXT(cacheTx49ICInvalidateAll)	/* invalidate i cache locations */
	.globl GTEXT(cacheTx49ICInvalidate)	/* invalidate i cache locations */

#ifdef IS_KSEGM
	.globl GTEXT(cacheTx49VirtPageFlush)	/* flush cache on MMU page unmap */
	.globl GTEXT(cacheTx49Sync)		/* cache sync operation */
#endif  /* IS_KSEGM */

	.globl GDATA(cacheTx49DCacheSize)	/* data cache size */
	.globl GDATA(cacheTx49ICacheSize)	/* inst. cache size */

	.globl GDATA(cacheTx49DCacheLineSize)    /* data cache line size */
	.globl GDATA(cacheTx49ICacheLineSize)    /* inst. cache line size */
	
	.data
	.align	4
cacheTx49ICacheSize:
	.word	0                /* Instruction cache size */
cacheTx49DCacheSize:
	.word	0                /* Data cache size */
cacheTx49ICacheLineSize:
	.word	0                /* Instruction cache line size */
cacheTx49DCacheLineSize:
	.word	0                /* Data cache line size */
	.text
	.set	reorder

/*******************************************************************************
*
* cacheTx49Reset - low level initialisation of the Tx49 primary caches
*
* This routine initialises the Tx49 primary caches to ensure that they
* have good parity.  It must be called by the ROM before any cached locations
* are used to prevent the possibility of data with bad parity being written to
* memory.
* To initialise the instruction cache it is essential that a source of data
* with good parity is available. If the initMem argument is set, this routine
* will initialise an area of memory starting at location zero to be used as
* a source of parity; otherwise it is assumed that memory has been
* initialised and already has good parity.
*
* Arguments
*	t0 - size of instruction cache in bytes
*	t1 - size of instruction cache line in bytes
*	t2 - size of data cache in bytes
*	t3 - size of data cache line in bytes
*
* RETURNS: N/A
*

* void cacheTx49Reset (initMem)

*/
	.ent	cacheTx49Reset
FUNC_LABEL(cacheTx49Reset)
	
	/* disable all i/u and cache exceptions */
	
	mfc0	v0,C0_SR
	HAZARD_CP_READ
	and	v1,v0,SR_BEV
	or	v1,SR_DE	# this bit unimplemented in TX49H2 core
	mtc0	v1,C0_SR
	HAZARD_CP_WRITE

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
	 *
	 * The Index operations use a Virtual Address with the lsb (bit 1-0)
	 * holding the way number (0-3).  The *_all_ways macros perform the
	 * cache operations to each way.
	 */

	/* 1: initialise icache tags */

	li	a0,K0BASE
	move	a2,t0		# icacheSize
	move	a3,t1		# icacheLineSize
	srl	a2,2		# 4 ways are processed for each address
	move	a1,a2
	icacheop_all_ways(a0,a1,a2,a3,Index_Store_Tag_I)

	/* 2: fill icache */

	li	a0,K0BASE
	move	a2,t0		# icacheSize
	move	a3,t1		# icacheLineSize
	move	a1,a2
	vcacheop(a0,a1,a2,a3,Fill_I)

	/* 3: clear icache tags */

	li	a0,K0BASE
	move	a2,t0		# icacheSize
	move	a3,t1		# icacheLineSize
	srl	a2,2		# 4 ways are processed for each address
	move	a1,a2
	icacheop_all_ways(a0,a1,a2,a3,Index_Store_Tag_I)

	/* 1: initialise dcache tags */

	li	a0,K0BASE
	move	a2,t2		# dcacheSize
	move	a3,t3		# dcacheLineSize
	srl	a2,2		# 4 ways are process for each address
	move	a1,a2
	icacheop_all_ways(a0,a1,a2,a3,Index_Store_Tag_D)

	/* 
	 * 2: fill dcache - this will load 4 lines of memory per cache line,
	 *                  one for each way.                      
	 */

	li	a0,K0BASE
	move	a2,t2		# dcacheSize
	move	a3,t3		# dcacheLineSize
	move	a1,a2
	icacheopn(a0,a1,a2,a3,1lw,(dummy))

	/* 3: clear dcache tags */

	li	a0,K0BASE
	move	a2,t2		# dcacheSize
	move	a3,t3		# dcacheLineSize
	srl	a2,2		# 4 ways are processed for each address
	move	a1,a2
	icacheop_all_ways(a0,a1,a2,a3,Index_Store_Tag_D)

	mtc0	v0,C0_SR
	HAZARD_CP_WRITE

	j	ra
	.end	cacheTx49Reset

/******************************************************************************
*
* cacheTx49PTextUpdateAll - text update for entire cache.
*
*	a0	i-cache size
*	a1	i-cache line size
*	a2	d-cache size
*	a3	d-cache line size
*
* RETURNS: N/A
*

* void cacheTx49PTextUpdateAll ()

*/
	.ent	cacheTx49PTextUpdateAll
FUNC_LABEL(cacheTx49PTextUpdateAll)

	/* run from kseg1 */

	la	t0,1f
	li	t1,KSEG2_TO_KSEG0_MASK
	and	t0,t0,t1
	or	t0,K1BASE
	j	t0
1:	

	/* Save I-cache parameters */

	move	t0,a0           # i-cache size
	move	t1,a1		# i-cache line size

	/* Check for primary data cache */

	blez	a2,99f

	/* Flush-invalidate primary data cache */

	li	a0,K0BASE
	srl	a2,2		# 4 ways are process for each address
	move	a1,a2
	icacheop_all_ways(a0,a1,a2,a3,Index_Writeback_Inv_D)
99:

	/* replace I-cache parameters */

	move	a2,t0		# i-cache size
	move	a3,t1		# i-cache line size
	
	/* Check for primary instruction cache */

	blez	a2,99f
	
	/* Invalidate primary instruction cache */

	li	a0,K0BASE
	srl	a2,2		# 4 ways are process for each address
	move	a1,a2
	icacheop_all_ways(a0,a1,a2,a3,Index_Invalidate_I)
99:
	j	ra
	.end	cacheTx49PTextUpdateAll


/******************************************************************************
*
* cacheTx49RomTextUpdate - text update for entire cache.
*
* RETURNS: N/A
*

* void cacheTx49RomTextUpdate (void)

*/
	.ent	cacheTx49RomTextUpdate
FUNC_LABEL(cacheTx49RomTextUpdate)
	SETFRAME(cacheTx49RomTextUpdate, 0)
	subu	sp, FRAMESZ(cacheTx49RomTextUpdate)
	SW	ra, FRAMERA(cacheTx49RomTextUpdate)(sp)	/* save return address */
	sw	a0, cacheTx49ICacheSize
	sw	a1, cacheTx49ICacheLineSize
	sw	a2, cacheTx49DCacheSize
	sw	a3, cacheTx49DCacheLineSize
	jal	cacheTx49PTextUpdateAll
	LW	ra, FRAMERA(cacheTx49RomTextUpdate)(sp)	/* restore return address */
	addu	sp, FRAMESZ(cacheTx49RomTextUpdate)
	j	ra
	.end	cacheTx49RomTextUpdate
	
/******************************************************************************
*
* cacheTx49PTextUpdate - text update for entire cache.
*
* RETURNS: N/A
*

* void cacheTx49PTextUpdate
*     (
*     baseAddr,		/@ virtual address @/
*     byteCount		/@ number of bytes to invalidate @/
*     )

*/
	.ent	cacheTx49PTextUpdate
FUNC_LABEL(cacheTx49PTextUpdate)

	/* run from kseg1 */

	la	t0,1f
	li	t1,KSEG2_TO_KSEG0_MASK
	and	t0,t0,t1
	or	t0,K1BASE
	j	t0
1:	

	/* Save parameters */

	move	t0,a0           # virtual address
	move	t1,a1		# number of bytes to invalidate

	/* Check for primary data cache */

	lw	a2,cacheTx49DCacheSize
	blez	a2,99f

	/* Flush-invalidate primary data cache */

	lw	a3,cacheTx49DCacheLineSize
	vcacheop(a0,a1,a2,a3,Hit_Writeback_Inv_D)
99:

	/* replace parameters */

	move	a0,t0		# virtual address
	move	a1,t1		# number of bytes to invalidate
	
	/* Check for primary instruction cache */

	lw	a2,cacheTx49ICacheSize
	blez	a2,99f
	
	/* Invalidate primary instruction cache */

	lw	a3,cacheTx49ICacheLineSize
	vcacheop(a0,a1,a2,a3,Hit_Invalidate_I)
99:
	j	ra
	.end	cacheTx49PTextUpdate


/*******************************************************************************
*
* cacheTx49DCFlushInvalidateAll - flush and invalidate entire Tx49 data cache
*
* RETURNS: N/A
*

* void cacheTx49DCFlushInvalidateAll (void)

*/
	.ent	cacheTx49DCFlushInvalidateAll
FUNC_LABEL(cacheTx49DCFlushInvalidateAll)
	lw	a2,cacheTx49DCacheSize
	blez	a2, 99f
	lw	a3,cacheTx49DCacheLineSize
	li	a0,K0BASE
	srl	a2,2		# 4 ways are process for each address
	move	a1,a2
	icacheop_all_ways(a0,a1,a2,a3,Index_Writeback_Inv_D)

99:	j	ra

	.end	cacheTx49DCFlushInvalidateAll

/*******************************************************************************
*
* cacheTx49DCFlushInvalidate - flush and invalidate Tx49 data cache locations
*
* RETURNS: N/A
*

* void cacheTx49DCFlushInvalidate
*     (
*     baseAddr,		/@ virtual address @/
*     byteCount		/@ number of bytes to invalidate @/
*     )

*/
	.ent	cacheTx49DCFlushInvalidate
FUNC_LABEL(cacheTx49DCFlushInvalidate)
	lw	a2,cacheTx49DCacheSize
	blez	a2, 99f
	lw	a3,cacheTx49DCacheLineSize
	vcacheop(a0,a1,a2,a3,Hit_Writeback_Inv_D)
99:	j	ra
	.end	cacheTx49DCFlushInvalidate


/*******************************************************************************
*
* cacheTx49DCInvalidateAll - invalidate entire Tx49 data cache.
*
* For the _tx49xx family, this function does a flush invalidate due to the
* lack of an Indexed Invalidate operation in the CACHE instruction
*
* RETURNS: N/A
*

* void cacheTx49DCInvalidateAll (void)

*/
	.ent	cacheTx49DCInvalidateAll
FUNC_LABEL(cacheTx49DCInvalidateAll)
1:	lw	a2,cacheTx49DCacheSize
	blez	a2, 99f
	lw	a3,cacheTx49DCacheLineSize
	li	a0,K0BASE
	srl	a2,2		# 4 ways are process for each address
	move	a1,a2
	icacheop_all_ways(a0,a1,a2,a3,Index_Writeback_Inv_D)

99:	j	ra

	.end	cacheTx49DCInvalidateAll

/*******************************************************************************
*
* cacheTx49DCInvalidate - invalidate Tx49 data cache locations
*
* RETURNS: N/A
*

* void cacheTx49DCInvalidate
*     (
*     baseAddr,		/@ virtual address @/
*     byteCount		/@ number of bytes to invalidate @/
*     )

*/
	.ent	cacheTx49DCInvalidate
FUNC_LABEL(cacheTx49DCInvalidate)
1:	lw	a2,cacheTx49DCacheSize
	blez	a2, 99f
	lw	a3,cacheTx49DCacheLineSize
	vcacheop(a0,a1,a2,a3,Hit_Invalidate_D)
99:	j	ra
	.end	cacheTx49DCInvalidate

/*******************************************************************************
*
* cacheTx49DCFlushAll - flushes entire Tx49 data cache.
*
* For the _tx49xx family, this function does a flush invalidate due to the
* lack of an Indexed Flush operation in the CACHE instruction
*
* RETURNS: N/A
*

* void cacheTx49DCFlushAll (void)

*/
	.ent	cacheTx49DCFlushAll
FUNC_LABEL(cacheTx49DCFlushAll)
1:	lw	a2,cacheTx49DCacheSize
	blez	a2, 99f
	lw	a3,cacheTx49DCacheLineSize
	li	a0,K0BASE
	srl	a2,2		# 4 ways are process for each address
	move	a1,a2
	icacheop_all_ways(a0,a1,a2,a3,Index_Writeback_Inv_D)

99:	j	ra

	.end	cacheTx49DCFlushAll

/*******************************************************************************
*
* cacheTx49DCFlush - flush Tx49 data cache locations
*
* RETURNS: N/A
*

* void cacheTx49DCFlush
*     (
*     baseAddr,		/@ virtual address @/
*     byteCount		/@ number of bytes to invalidate @/
*     )

*/
	.ent	cacheTx49DCFlush
FUNC_LABEL(cacheTx49DCFlush)
1:	lw	a2,cacheTx49DCacheSize
	blez	a2, 99f
	lw	a3,cacheTx49DCacheLineSize
	vcacheop(a0,a1,a2,a3,Hit_Writeback_D)
99:	j	ra
	.end	cacheTx49DCFlush

/*******************************************************************************
*
* cacheTx49ICInvalidateAll - invalidate entire Tx49 instruction cache
*
* RETURNS: N/A
*

* void cacheTx49ICInvalidateAll (void)

*/
	.ent	cacheTx49ICInvalidateAll
FUNC_LABEL(cacheTx49ICInvalidateAll)
	lw	a2,cacheTx49ICacheSize
	blez	a2,99f
	lw	a3,cacheTx49ICacheLineSize
	li	a0,K0BASE
	srl	a2,2		# 4 ways are process for each address
	move	a1,a2
	icacheop_all_ways(a0,a1,a2,a3,Index_Invalidate_I)

99:	j	ra

	.end	cacheTx49ICInvalidateAll

/*******************************************************************************
*
* cacheTx49ICInvalidate - invalidate Tx49 instruction cache locations
*
* RETURNS: N/A
*

* void cacheTx49ICInvalidate
*     (
*     baseAddr,		/@ virtual address @/
*     byteCount		/@ number of bytes to invalidate @/
*     )

*/
	.ent	cacheTx49ICInvalidate
FUNC_LABEL(cacheTx49ICInvalidate)
	lw	a2,cacheTx49ICacheSize
	blez	a2, 99f
	lw	a3,cacheTx49ICacheLineSize
	vcacheop(a0,a1,a2,a3,Hit_Invalidate_I)
	
99:	j	ra
	.end	cacheTx49ICInvalidate


#ifdef IS_KSEGM
/******************************************************************************
*
* cacheTx49VirtPageFlush - flush one page of virtual addresses from caches
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
* void cacheTx49VirtPageFlush (UINT asid, void *vAddr, UINT pageSize);
*/
	.ent	cacheTx49VirtPageFlush
FUNC_LABEL(cacheTx49VirtPageFlush)
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
	
	lw	a2,cacheTx49DCacheSize
	blez	a2,1f

	/* Flush-invalidate primary data cache */

	move	a0, t0
	move	a1, t1
	lw	a3,cacheTx49DCacheLineSize
	vcacheop(a0,a1,a2,a3,Hit_Writeback_Inv_D)
1:
	lw	a2,cacheTx49ICacheSize
	blez	a2,1f	

	/* Invalidate primary instruction cache */

	move	a0,t0
	move	a1,t1
	lw	a3,cacheTx49ICacheLineSize
	vcacheop(a0,a1,a2,a3,Hit_Invalidate_I)
1:	
	/* restore the original ASID */

	mtc0	t3, C0_TLBHI		/* Restore old EntryHi  */	
	HAZARD_TLB

	mtc0	t2, C0_SR		/* restore interrupts */
	
	j	ra
	.end	cacheTx49VirtPageFlush

/******************************************************************************
*
* cacheTx49Sync - sync region of memory through all caches
*
* RETURNS: N/A
*
* void cacheTx49Sync (void *vAddr, UINT pageSize);
*/
	.ent	cacheTx49Sync
FUNC_LABEL(cacheTx49Sync)
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

	lw	a2,cacheTx49ICacheSize
	blez	a2,1f	

	/* Invalidate primary instruction cache */

	move	a0,t0
	move	a1,t1
	lw	a3,cacheTx49ICacheLineSize
	vcacheop(a0,a1,a2,a3,Hit_Invalidate_I)
1:
	lw	a2,cacheTx49DCacheSize
	blez	a2,1f

	/* Flush-invalidate primary data cache */

	move	a0, t0
	move	a1, t1
	lw	a3,cacheTx49DCacheLineSize
	vcacheop(a0,a1,a2,a3,Hit_Writeback_Inv_D)
1:	
	mtc0	t2, C0_SR		/* restore interrupts */
	
	j	ra
	.end	cacheTx49Sync
#endif /* IS_KSEGM */
