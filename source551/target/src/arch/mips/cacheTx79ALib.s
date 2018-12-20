/* cacheTx79ALib.s - Toshiba Tx79 cache management assembly routines */

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
01d,19nov02,jmt  Delete references to cacheTx79BCacheLineSize and
                 cacheTx79BCacheSize
01c,07nov02,jmt  Modified to resolve issues during integration
01b,30sep02,jmt  Modify to resolve code review issues
01a,14aug02,jmt  derived from cacheTx49ALib.s (01b,09may02,jmt)
*/

/*
DESCRIPTION
This library contains MIPS Tx79 cache set-up and invalidation routines
written in assembly language.  The Tx79 utilizes a fixed-size instruction 
and data cache that operates in write-back mode.   The cache is two-way set 
associative.  
	
The library allows the cache and cache line size to vary.  The values are
set on initialization of the library.
See also the manual entry for cacheTx79Lib.

For general information about caching, see the manual entry for cacheLib.

INCLUDE FILES: asm.h

SEE ALSO: cacheTx79Lib, cacheLib
*/

#define _ASMLANGUAGE
#include "vxWorks.h"
#include "asm.h"

/*
 * cache OpCodes
 */ 
#define Tx79_Index_Load_Tag_I		0x00
#define Tx79_Index_Load_Data_I		0x01
#define Tx79_Index_Load_BTAC_B		0x02
#define Tx79_Index_Store_Tag_I		0x04
#define Tx79_Index_Store_Data_I		0x05
#define Tx79_Index_Store_BTAC_B		0x06
#define Tx79_Index_Invalidate_I		0x07
#define Tx79_Hit_Invalidate_B		0x0A
#define Tx79_Hit_Invalidate_I		0x0B
#define Tx79_BTAC_Flush_B		0x0C
#define Tx79_Fill_I			0x0E
#define Tx79_Index_Load_Tag_D		0x10
#define Tx79_Index_Load_Data_D		0x11
#define Tx79_Index_Store_Tag_D		0x12
#define Tx79_Index_Store_Data_D		0x13
#define Tx79_Index_Writeback_Inv_D	0x14
#define Tx79_Index_Invalidate_D		0x16
#define Tx79_Hit_Writeback_Inv_D	0x18
#define Tx79_Hit_Invalidate_D		0x1A
#define Tx79_Hit_Writeback_D		0x1C

/*
 * cacheop macro to automate cache operations
 * first some helpers...
 */

#define SYNCP \
	.word	0x0000040f	/* sync.p */ 

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

/* do op1 on a data and instruction cache line safely */

#define doop1(op1) \
	cache	op1,0(a0) 
	
/* do writeback op1 on a data cache line safely */

#define doopdw1(op1) \
	cache	op1,0(a0) ;		\
	sync 
	
/* do op1 on the BTAC cache line safely */

#define doopb1(op1) \
	SYNCP ;				\
	cache	op1,0(a0) ;		\
	SYNCP
	
/* specials for cache initialisation */
	
/* load word into a data cache line */

#define doop1lw(op1) \
	lw	zero,0(a0)

/* special Tx79 operations */

/* do fill op on a instruction cache line safely */

#define doopfilli1(op1) \
	cache	op1,0(a0) ;		\
	sync

/* do writeback op1 on all ways of a data cache line  
 * only valid for index cache operations
 */

#define doopdw1_all_ways(op1) \
	cache	op1,0(a0) ;		\
	sync		  ;		\
	cache	op1,1(a0)

/* do op1 on all ways of a data and instruction cache line  
 * only valid for index cache operations
 */

#define doop1_all_ways(op1) \
	cache	op1,0(a0) ;		\
	cache	op1,1(a0)

/* do tagged op on a range of instruction cache addresses */

#define _opiloopn(minaddr, maxaddr, linesize, tag, ops) \
	.set	noreorder ;		\
	SYNCP ;				\
10: 	doop##tag##ops ;		\
	SYNCP ;				\
	bne     minaddr,maxaddr,10b ;	\
	add   	minaddr,linesize ;	\
	.set	reorder

/* do tagged op on a range of data cache addresses */

#define _opdloopn(minaddr, maxaddr, linesize, tag, ops) \
	.set	noreorder ;		\
	sync ;				\
10: 	doop##tag##ops ;		\
	sync ;				\
	bne     minaddr,maxaddr,10b ;	\
	add   	minaddr,linesize ;	\
	.set	reorder

/* do tagged writeback op on a range of data cache addresses */

#define _opdwloopn(minaddr, maxaddr, linesize, tag, ops) \
	.set	noreorder ;		\
	sync ;				\
10: 	doop##tag##ops ;		\
	sync ;				\
	bne     minaddr,maxaddr,10b ;	\
	add   	minaddr,linesize ;	\
	.set	reorder

/* finally the cache operation macros */

/* do tagged op on a range of addresses up to the size of the cache */

#define icacheopn(kva, n, cacheSize, cacheLineSize, tag, ops, type) \
	_mincache(n, cacheSize);	\
 	blez	n,11f ;			\
	addu	n,kva ;			\
	_align(kva, n, cacheLineSize) ; \
	_op##type##loopn(kva, n, cacheLineSize, tag, ops) ; \
11:

/* do tagged op on a range of addresses, if size > 0 */

#define vcacheopn(kva, n, cacheSize, cacheLineSize, tag, ops, type) \
 	blez	n,11f ;			\
	addu	n,kva ;			\
	_align(kva, n, cacheLineSize) ; \
	_op##type##loopn(kva, n, cacheLineSize, tag, ops) ; \
11:

/* do op1 on a range of instruction or data cache lines 
 * only valid for index cache ops
 */

#define icacheop(kva, n, cacheSize, cacheLineSize, op, type) \
	icacheopn(kva, n, cacheSize, cacheLineSize, 1, (op), type)

/* do op1 on all ways of a range of data or instruction cache lines 
 * only valid for index cache ops
 */

#define icacheop_all_ways(kva, n, cacheSize, cacheLineSize, op, type) \
	icacheopn(kva, n, cacheSize, cacheLineSize, 1_all_ways, (op), type)

/* do op1 on all ways of a range of data cache lines 
 * only valid for index cache ops
 */

#define icacheopdw_all_ways(kva, n, cacheSize, cacheLineSize, op) \
	icacheopn(kva, n, cacheSize, cacheLineSize, dw1_all_ways, (op), dw)

/* do op on a range of addresses on instruction or data cache */

#define vcacheop(kva, n, cacheSize, cacheLineSize, op, type) \
	vcacheopn(kva, n, cacheSize, cacheLineSize, 1, (op), type) 

/* do writeback op on a range of addresses on data cache */

#define vcacheopdw(kva, n, cacheSize, cacheLineSize, op) \
	vcacheopn(kva, n, cacheSize, cacheLineSize, dw1, (op), dw) 

/* do FILL op on a range of addresses on instruction cache */

#define vcachefilliop(kva, n, cacheSize, cacheLineSize, op) \
	vcacheopn(kva, n, cacheSize, cacheLineSize, filli1, (op), i) 



	.text

	.globl GTEXT(cacheTx79Reset)		/* low level cache init */
	.globl GTEXT(cacheTx79RomTextUpdate)	/* cache-text-update */
	.globl GTEXT(cacheTx79DCFlushInvalidateAll) /* clear entire d cache */
	.globl GTEXT(cacheTx79DCFlushInvalidate)/* clear d cache locations */
	.globl GTEXT(cacheTx79DCFlushAll)       /* flush entire d cache */
	.globl GTEXT(cacheTx79DCFlush)          /* flush d cache locations */
	.globl GTEXT(cacheTx79DCInvalidateAll)	/* invalidate entire d cache */
	.globl GTEXT(cacheTx79DCInvalidate)	/* invalidate d cache locations */
	.globl GTEXT(cacheTx79PTextUpdateAll)	/* update entire text area */
	.globl GTEXT(cacheTx79PTextUpdate)	/* update text area */
	.globl GTEXT(cacheTx79ICInvalidateAll)	/* invalidate i cache locations */
	.globl GTEXT(cacheTx79ICInvalidate)	/* invalidate i cache locations */

#ifdef IS_KSEGM
	.globl GTEXT(cacheTx79VirtPageFlush)	/* flush cache on MMU page unmap */
	.globl GTEXT(cacheTx79Sync)		/* cache sync operation */
#endif  /* IS_KSEGM */

	.globl GDATA(cacheTx79DCacheSize)	/* data cache size */
	.globl GDATA(cacheTx79ICacheSize)	/* inst. cache size */

	.globl GDATA(cacheTx79DCacheLineSize)    /* data cache line size */
	.globl GDATA(cacheTx79ICacheLineSize)    /* inst. cache line size */
	
	.data
	.align	4
cacheTx79ICacheSize:
	.word	0                /* Instruction cache size */
cacheTx79DCacheSize:
	.word	0                /* Data cache size */
cacheTx79ICacheLineSize:
	.word	0                /* Instruction cache line size */
cacheTx79DCacheLineSize:
	.word	0                /* Data cache line size */
	.text
	.set	reorder

/*******************************************************************************
*
* cacheTx79Reset - low level initialisation of the Tx79 primary caches
*
* This routine initialises the Tx79 primary caches to ensure that they
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

* void cacheTx79Reset (initMem)

*/
	.ent	cacheTx79Reset
FUNC_LABEL(cacheTx79Reset)
	
	/* disable all i/u and cache exceptions */
	
	mfc0	v0,C0_SR
	HAZARD_CP_READ
	and	v1,v0,SR_BEV
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
	 * The Index operations use a Virtual Address with the lsb (bit 0)
	 * holding the way number (0-1).  The *_all_ways macros perform the
	 * cache operations to each way.
	 */

	/* 1: initialise icache tags */

	li	a0,K0BASE
	move	a2,t0		# icacheSize
	move	a3,t1		# icacheLineSize
	srl	a2,1		# 2 ways are processed for each address
	move	a1,a2
	icacheop_all_ways(a0,a1,a2,a3,Tx79_Index_Store_Tag_I,i)

	/* 2: fill icache */

	li	a0,K0BASE
	move	a2,t0		# icacheSize
	move	a3,t1		# icacheLineSize
	move	a1,a2
	vcachefilliop(a0,a1,a2,a3,Tx79_Fill_I)

	/* 3: clear icache tags */

	li	a0,K0BASE
	move	a2,t0		# icacheSize
	move	a3,t1		# icacheLineSize
	srl	a2,1		# 2 ways are processed for each address
	move	a1,a2
	icacheop_all_ways(a0,a1,a2,a3,Tx79_Index_Store_Tag_I,i)

	/* 1: initialise BTAC tags */

	li	a0,K0BASE
	doopb1(Tx79_BTAC_Flush_B)

	/* 1: initialise dcache tags */

	li	a0,K0BASE
	move	a2,t2		# dcacheSize
	move	a3,t3		# dcacheLineSize
	srl	a2,1		# 2 ways are process for each address
	move	a1,a2
	icacheop_all_ways(a0,a1,a2,a3,Tx79_Index_Store_Tag_D,d)

	/* 
	 * 2: fill dcache - this will load 2 lines of memory per cache line,
	 *                  one for each way.                      
	 */

	li	a0,K0BASE
	move	a2,t2		# dcacheSize
	move	a3,t3		# dcacheLineSize
	move	a1,a2
	icacheopn(a0,a1,a2,a3,1lw,(dummy),d)

	/* 3: clear dcache tags */

	li	a0,K0BASE
	move	a2,t2		# dcacheSize
	move	a3,t3		# dcacheLineSize
	srl	a2,1		# 2 ways are processed for each address
	move	a1,a2
	icacheop_all_ways(a0,a1,a2,a3,Tx79_Index_Store_Tag_D,d)

	mtc0	v0,C0_SR
	HAZARD_CP_WRITE

	j	ra
	.end	cacheTx79Reset

/******************************************************************************
*
* cacheTx79PTextUpdateAll - text update for entire cache.
*
* RETURNS: N/A
*

* void cacheTx79PTextUpdateAll ()

*/
	.ent	cacheTx79PTextUpdateAll
FUNC_LABEL(cacheTx79PTextUpdateAll)

	/* run from kseg1 */

	la	t0,1f
	li	t1,KSEG2_TO_KSEG0_MASK
	and	t0,t0,t1
	or	t0,K1BASE
	j	t0
1:	

	/* Flush-invalidate primary data cache */

	lw	a2,cacheTx79DCacheSize
	blez	a2,99f				/* Check for primary d-cache */
	
	lw	a3,cacheTx79DCacheLineSize
	li	a0,K0BASE
	srl	a2,1		/* 2 ways are process for each address */
	move	a1,a2
	icacheopdw_all_ways(a0,a1,a2,a3,Tx79_Index_Writeback_Inv_D)
99:

	/* Invalidate primary instruction cache */

	lw	a2,cacheTx79ICacheSize
	blez	a2,99f				/* Check for primary i-cache */
	
	lw	a3,cacheTx79ICacheLineSize
	li	a0,K0BASE
	srl	a2,1		/* 2 ways are process for each address */
	move	a1,a2
	icacheop_all_ways(a0,a1,a2,a3,Tx79_Index_Invalidate_I,i)
99:

	/* Invalidate primary BTAC */

	li	a0,K0BASE
	doopb1(Tx79_BTAC_Flush_B)

	j	ra
	.end	cacheTx79PTextUpdateAll


/******************************************************************************
*
* cacheTx79RomTextUpdate - text update for entire cache.
*
* RETURNS: N/A
*

* void cacheTx79RomTextUpdate (void)

*/
	.ent	cacheTx79RomTextUpdate
FUNC_LABEL(cacheTx79RomTextUpdate)
	
	/* save return address */
	
	SETFRAME(cacheTx79RomTextUpdate, 0)
	subu	sp, FRAMESZ(cacheTx79RomTextUpdate)
	SW	ra, FRAMERA(cacheTx79RomTextUpdate)(sp)	

	/* Save the passed in parameters */
	
	sw	a0, cacheTx79ICacheSize
	sw	a1, cacheTx79ICacheLineSize
	sw	a2, cacheTx79DCacheSize
	sw	a3, cacheTx79DCacheLineSize

	/* Call PTextUpdateAll */
	
	jal	cacheTx79PTextUpdateAll

	/* restore return address */
	
	LW	ra, FRAMERA(cacheTx79RomTextUpdate)(sp)	
	addu	sp, FRAMESZ(cacheTx79RomTextUpdate)
	
	j	ra
	.end	cacheTx79RomTextUpdate
	
/******************************************************************************
*
* cacheTx79PTextUpdate - text update for entire cache.
*
* RETURNS: N/A
*

* void cacheTx79PTextUpdate
*     (
*     baseAddr,		/@ virtual address @/
*     byteCount		/@ number of bytes to invalidate @/
*     )

*/
	.ent	cacheTx79PTextUpdate
FUNC_LABEL(cacheTx79PTextUpdate)

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

	/* Flush-invalidate primary data cache */

	lw	a2,cacheTx79DCacheSize
	blez	a2,99f				/* Check for primary d-cache */

	lw	a3,cacheTx79DCacheLineSize
	vcacheopdw(a0,a1,a2,a3,Tx79_Hit_Writeback_Inv_D)
99:

	/* replace parameters */

	move	a0,t0		# virtual address
	move	a1,t1		# number of bytes to invalidate
	
	/* Invalidate primary instruction cache */

	lw	a2,cacheTx79ICacheSize
	blez	a2,99f				/* Check for primary i-cache */
	
	lw	a3,cacheTx79ICacheLineSize
	vcacheop(a0,a1,a2,a3,Tx79_Hit_Invalidate_I,i)
99:

	/* Invalidate primary BTAC - not required */

	j	ra
	.end	cacheTx79PTextUpdate


/*******************************************************************************
*
* cacheTx79DCFlushInvalidateAll - flush and invalidate entire Tx79 data cache
*
* RETURNS: N/A
*

* void cacheTx79DCFlushInvalidateAll (void)

*/
	.ent	cacheTx79DCFlushInvalidateAll
FUNC_LABEL(cacheTx79DCFlushInvalidateAll)

	/* Flush Invalidate the primary Data cache */

	lw	a2,cacheTx79DCacheSize		/* get D-cache size */
	blez	a2, 99f				/* Check for primary D-cache */
	
	lw	a3,cacheTx79DCacheLineSize	/* get D-cache line size */
	li	a0,K0BASE
	srl	a2,1		/* 2 ways are process for each address */
	move	a1,a2				/* operate on full cache */
	icacheopdw_all_ways(a0,a1,a2,a3,Tx79_Index_Writeback_Inv_D)

99:	j	ra

	.end	cacheTx79DCFlushInvalidateAll

/*******************************************************************************
*
* cacheTx79DCFlushInvalidate - flush and invalidate Tx79 data cache locations
*
* RETURNS: N/A
*

* void cacheTx79DCFlushInvalidate
*     (
*     baseAddr,		/@ virtual address @/
*     byteCount		/@ number of bytes to invalidate @/
*     )

*/
	.ent	cacheTx79DCFlushInvalidate
FUNC_LABEL(cacheTx79DCFlushInvalidate)

	/* Flush Invalidate a block of primary Data cache */

	lw	a2,cacheTx79DCacheSize		/* get D-cache size */
	blez	a2, 99f				/* Check for primary D-cache */
	
	lw	a3,cacheTx79DCacheLineSize	/* get D-cache line size */
	vcacheopdw(a0,a1,a2,a3,Tx79_Hit_Writeback_Inv_D)
99:	j	ra
	.end	cacheTx79DCFlushInvalidate


/*******************************************************************************
*
* cacheTx79DCInvalidateAll - invalidate entire Tx79 data cache.
*
* For the _tx79xx family, this function does a flush invalidate due to the
* lack of an Indexed Invalidate operation in the CACHE instruction
*
* RETURNS: N/A
*

* void cacheTx79DCInvalidateAll (void)

*/
	.ent	cacheTx79DCInvalidateAll
FUNC_LABEL(cacheTx79DCInvalidateAll)

	/* Invalidate the primary Data cache */

	lw	a2,cacheTx79DCacheSize		/* get D-cache size */
	blez	a2, 99f				/* Check for primary D-cache */
	
	lw	a3,cacheTx79DCacheLineSize	/* get D-cache line size */
	li	a0,K0BASE
	srl	a2,1		/* 2 ways are process for each address */
	move	a1,a2				/* operate on full cache */
	icacheopdw_all_ways(a0,a1,a2,a3,Tx79_Index_Writeback_Inv_D)

99:	j	ra

	.end	cacheTx79DCInvalidateAll

/*******************************************************************************
*
* cacheTx79DCInvalidate - invalidate Tx79 data cache locations
*
* RETURNS: N/A
*

* void cacheTx79DCInvalidate
*     (
*     baseAddr,		/@ virtual address @/
*     byteCount		/@ number of bytes to invalidate @/
*     )

*/
	.ent	cacheTx79DCInvalidate
FUNC_LABEL(cacheTx79DCInvalidate)

	/* Invalidate a block of primary Data cache */

	lw	a2,cacheTx79DCacheSize		/* get D-cache size */
	blez	a2, 99f				/* Check for primary D-cache */
	lw	a3,cacheTx79DCacheLineSize	/* get D-cache line size */
	vcacheop(a0,a1,a2,a3,Tx79_Hit_Invalidate_D,d)
99:	
	j	ra
	.end	cacheTx79DCInvalidate

/*******************************************************************************
*
* cacheTx79DCFlushAll - flushes entire Tx79 data cache.
*
* For the _tx79xx family, this function does a flush invalidate due to the
* lack of an Indexed Flush operation in the CACHE instruction
*
* RETURNS: N/A
*

* void cacheTx79DCFlushAll (void)

*/
	.ent	cacheTx79DCFlushAll
FUNC_LABEL(cacheTx79DCFlushAll)

	/* Flush the full primary Data cache */

	lw	a2,cacheTx79DCacheSize		/* get D-cache size */
	blez	a2, 99f				/* Check for primary D-cache */
	lw	a3,cacheTx79DCacheLineSize	/* get D-cache line size */
	li	a0,K0BASE
	srl	a2,1		/* 2 ways are process for each address */
	move	a1,a2				/* operate on full cache */
	icacheopdw_all_ways(a0,a1,a2,a3,Tx79_Index_Writeback_Inv_D)

99:	j	ra

	.end	cacheTx79DCFlushAll

/*******************************************************************************
*
* cacheTx79DCFlush - flush Tx79 data cache locations
*
* RETURNS: N/A
*

* void cacheTx79DCFlush
*     (
*     baseAddr,		/@ virtual address @/
*     byteCount		/@ number of bytes to invalidate @/
*     )

*/
	.ent	cacheTx79DCFlush
FUNC_LABEL(cacheTx79DCFlush)

	/* Flush block from primary Data cache */

	lw	a2,cacheTx79DCacheSize		/* get D-cache size */
	blez	a2, 99f				/* Check for primary D-cache */
	lw	a3,cacheTx79DCacheLineSize	/* get D-cache line size */
	vcacheopdw(a0,a1,a2,a3,Tx79_Hit_Writeback_D)
99:	
	j	ra
	.end	cacheTx79DCFlush

/*******************************************************************************
*
* cacheTx79ICInvalidateAll - invalidate entire Tx79 instruction cache
*
* RETURNS: N/A
*

* void cacheTx79ICInvalidateAll (void)

*/
	.ent	cacheTx79ICInvalidateAll
FUNC_LABEL(cacheTx79ICInvalidateAll)

	/* Invalidate primary Instruction cache */

	lw	a2,cacheTx79ICacheSize		/* get I-cache size */
	blez	a2,99f				/* Check for primary I-cache */
	
	lw	a3,cacheTx79ICacheLineSize	/* get I-cache line size */
	li	a0,K0BASE
	srl	a2,1		/* 2 ways are process for each address */
	move	a1,a2
	icacheop_all_ways(a0,a1,a2,a3,Tx79_Index_Invalidate_I,i)
99:

	/* Invalidate primary BTAC */

	li	a0,K0BASE
	doopb1(Tx79_BTAC_Flush_B)

	j	ra

	.end	cacheTx79ICInvalidateAll

/*******************************************************************************
*
* cacheTx79ICInvalidate - invalidate Tx79 instruction cache locations
*
* RETURNS: N/A
*

* void cacheTx79ICInvalidate
*     (
*     baseAddr,		/@ virtual address @/
*     byteCount		/@ number of bytes to invalidate @/
*     )

*/
	.ent	cacheTx79ICInvalidate
FUNC_LABEL(cacheTx79ICInvalidate)

	/* Save parameters */

	move	t0,a0           # virtual address
	move	t1,a1		# number of bytes to invalidate

	/* Invalidate block of primary Instruction cache */

	lw	a2,cacheTx79ICacheSize		/* get I-cache size */
	blez	a2, 99f				/* Check for primary I-cache */
	
	lw	a3,cacheTx79ICacheLineSize	/* get I-cache line size */
	vcacheop(a0,a1,a2,a3,Tx79_Hit_Invalidate_I,i)
99:	

	/* Invalidate primary BTAC - not required */

	j	ra
	.end	cacheTx79ICInvalidate


#ifdef IS_KSEGM
/******************************************************************************
*
* cacheTx79VirtPageFlush - flush one page of virtual addresses from caches
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
* void cacheTx79VirtPageFlush (UINT asid, void *vAddr, UINT pageSize);
*/
	.ent	cacheTx79VirtPageFlush
FUNC_LABEL(cacheTx79VirtPageFlush)
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
	
	lw	a2,cacheTx79DCacheSize
	blez	a2,1f

	/* Flush-invalidate primary data cache */

	move	a0, t0
	move	a1, t1
	lw	a3,cacheTx79DCacheLineSize
	vcacheopdw(a0,a1,a2,a3,Tx79_Hit_Writeback_Inv_D)
1:
	lw	a2,cacheTx79ICacheSize
	blez	a2,1f	

	/* Invalidate primary instruction cache */

	move	a0,t0
	move	a1,t1
	lw	a3,cacheTx79ICacheLineSize
	vcacheop(a0,a1,a2,a3,Tx79_Hit_Invalidate_I,i)
1:	

	/* Invalidate primary BTAC - not required */

	/* restore the original ASID */

	mtc0	t3, C0_TLBHI		/* Restore old EntryHi  */	
	HAZARD_TLB

	mtc0	t2, C0_SR		/* restore interrupts */
	
	j	ra
	.end	cacheTx79VirtPageFlush

/******************************************************************************
*
* cacheTx79Sync - sync region of memory through all caches
*
* RETURNS: N/A
*
* void cacheTx79Sync (void *vAddr, UINT pageSize);
*/
	.ent	cacheTx79Sync
FUNC_LABEL(cacheTx79Sync)
	
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

	/* Invalidate primary instruction cache */

	lw	a2,cacheTx79ICacheSize		/* get I-cache size */
	blez	a2,1f				/* Check for primary i-cache */

	move	a0,t0				/* restore virtual addr */
	move	a1,t1				/* restore length */
	lw	a3,cacheTx79ICacheLineSize	/* get I-cache line size */
	vcacheop(a0,a1,a2,a3,Tx79_Hit_Invalidate_I,i)
1:

	/* Invalidate primary BTAC - not required */

	/* Flush-invalidate primary data cache */

	lw	a2,cacheTx79DCacheSize		/* get D-cache size */
	blez	a2,1f				/* Check for primary d-cache */

	move	a0, t0				/* restore virtual addr */
	move	a1, t1				/* restore length */
	lw	a3,cacheTx79DCacheLineSize	/* get D-cache line size */
	vcacheopdw(a0,a1,a2,a3,Tx79_Hit_Writeback_Inv_D)
1:	
	mtc0	t2, C0_SR		/* restore interrupts */
	
	j	ra
	.end	cacheTx79Sync
#endif /* IS_KSEGM */

