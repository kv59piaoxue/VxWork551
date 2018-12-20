/* cacheAuALib.s - Alchemy Au cache management assembly routines */

/* Copyright 2001 Wind River Systems, Inc. */
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
01f,17may02,zmm  Global au1000 name changes. SPR 77333.
01e,18jan02,agf  add explicit align directive to data section(s)
01d,16nov01,tlc  Reorder icache loops in reset routine.
01d,02aug01,mem  Diab integration
01c,16jul01,ros  add CofE comment
01b,16jul01,pes  Fixed bug in cacheAu1000PTextUpdate.
01a,10jul01,mem  written.
*/

/*
DESCRIPTION
This library contains Alchemy Au cache set-up and invalidation routines
written in assembly language.  The Au utilizes a variable-size
instruction and data cache that operates in write-through mode.  Cache
line size also varies. See also the manual entry for cacheAuLib.

For general information about caching, see the manual entry for cacheLib.

INCLUDE FILES: cacheLib.h

SEE ALSO: cacheAuLib, cacheLib
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
#define doop1(op1) 			\
	cache	op1,0(a0) ;		\
	HAZARD_CACHE

#define doop2(op1, op2) 		\
	cache	op1,0(a0) ;		\
	HAZARD_CACHE	  ;		\
	cache	op2,0(a0) ;		\
	HAZARD_CACHE

#define doop1lw(op1)			\
	lw	zero,0(a0)

#define doop1lw1(op1)			\
	cache	op1,0(a0) ;		\
	HAZARD_CACHE	  ;		\
	lw	zero,0(a0);		\
	cache	op1,0(a0) ;		\
	HAZARD_CACHE

#define doop121(op1,op2)		\
	cache	op1,0(a0) ;		\
	HAZARD_CACHE	  ;		\
	cache	op2,0(a0) ;		\
	HAZARD_CACHE	  ;		\
	cache	op1,0(a0) ;		\
	HAZARD_CACHE

#define _oploopn(minaddr, maxaddr, linesize, tag, ops) \
	.set	noreorder ;		\
10: 	doop##tag##ops ;	\
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

	/* globals */

	.text

	.globl GTEXT(cacheAuReset)		/* low level cache init */
	.globl GTEXT(cacheAuRomTextUpdate)	/* cache-text-update */
	.globl GTEXT(cacheAuDCFlushAll)	/* flush entire data cache */
	.globl GTEXT(cacheAuDCFlush)		/* flush data cache locations */
	.globl GTEXT(cacheAuDCInvalidateAll)	 /* flush entire data cache */
	.globl GTEXT(cacheAuDCInvalidate)	 /* flush data cache locations */
	.globl GTEXT(cacheAuDCFlushInvalidateAll)/* flush entire data cache */
	.globl GTEXT(cacheAuDCFlushInvalidate)	/* flush data cache locations */
	.globl GTEXT(cacheAuICInvalidateAll)	/* invalidate entire inst cache */
	.globl GTEXT(cacheAuICInvalidate)	/* invalidate inst. cache */
	.globl GTEXT(cacheAuPTextUpdateAll)	/* invalidate entire P-cache  */
	.globl GTEXT(cacheAuPTextUpdate)	/* invalidate P-cache locn's  */
	.globl GTEXT(cacheAuVirtPageFlush)	/* flush cache on MMU page unmap */
	.globl GTEXT(cacheAuSync)		/* cache sync operation */

	.globl GDATA(cacheAuDCacheSize)	/* data cache size */
	.globl GDATA(cacheAuICacheSize)	/* inst. cache size */

	.globl GDATA(cacheAuDCacheLineSize)	/* data cache line size */
	.globl GDATA(cacheAuICacheLineSize)	/* inst. cache line size */

	.data
	.align	4
cacheAuICacheSize:
	.word	0			/* instruction cache size */
cacheAuDCacheSize:
	.word	0			/* data cache size */
cacheAuICacheLineSize:
	.word	0			/* instruction cache line size */
cacheAuDCacheLineSize:
	.word	0			/* data cache line size */

	.text
	.set	reorder
/******************************************************************************
*
* cacheAuReset - low level initialisation of the Au caches
*
* This routine initialises the Au caches to ensure that all entries are
* marked invalid.  It must be called by the ROM before any cached locations
* are used to prevent the possibility of uninitialized data being written to
* memory.
*
* Arguments
*	t0 - size of instruction cache in bytes
*	t1 - size of instruction cache line in bytes
*	t2 - size of data cache in bytes
*	t3 - size of data cache line in bytes
*
* RETURNS: N/A
*

* void cacheAuReset 

*/
	.ent	cacheAuReset
FUNC_LABEL(cacheAuReset)
	/* disable all i/u and cache exceptions */
	mfc0	v0,C0_SR
	HAZARD_CP_READ
	and	v1,v0,SR_BEV
	or	v1,v0,SR_DE
	mtc0	v1,C0_SR
	
	/* set tag & ecc to 0 */
	mtc0	zero,C0_TAGLO
	mtc0	zero,C0_TAGHI
	mtc0	zero,C0_ECC
	HAZARD_CP_WRITE
	
	/*
	 * The caches are probably in an indeterminate state, so we force
	 * good parity into them by doing an invalidate, load/fill, 
	 * invalidate for each line.  We do an invalidate of each line in
	 * the cache before we perform any fills, because we need to 
	 * ensure that each way of an n-way associative cache is invalid
	 * before performing the first Fill_I cacheop.
	 */
	
	/* 1: initialize icache tags */ 
	li	a0,K0BASE
	move	a2,t0		# icacheSize
	move	a3,t1		# icacheLineSize
	move	a1,a2
	icacheop(a0,a1,a2,a3,Index_Store_Tag_I)

	/* 2: fill icache */
	li	a0,K0BASE
	move	a2,t0		# icacheSize
	move	a3,t1		# icacheLineSize
	move	a1,a2
	icacheop(a0,a1,a2,a3,Fill_I)

	/* 1: clear icache tags */ 
	li	a0,K0BASE
	move	a2,t0		# icacheSize
	move	a3,t1		# icacheLineSize
	move	a1,a2
	icacheop(a0,a1,a2,a3,Index_Store_Tag_I)

	/* 1: initialize dcache tags */
	li	a0,K0BASE
	move	a2,t2		# dcacheSize
	move	a3,t3		# dcacheLineSize
	move	a1,a2
	icacheop(a0,a1,a2,a3,Index_Store_Tag_D)
	
	/* 2: fill dcache */
	li	a0,K0BASE
	move	a2,t2		# dcacheSize
	move	a3,t3		# dcacheLineSize
	move	a1,a2
	icacheopn(a0,a1,a2,a3,1lw,(dummy))

	/* 3: clear dcache tags */
	li	a0,K0BASE
	move	a2,t2		# dcacheSize
	move	a3,t3		# dcacheLineSize
	move	a1,a2
	icacheop(a0,a1,a2,a3,Index_Store_Tag_D)

	mtc0	v0,C0_SR
        HAZARD_CP_WRITE
	j	ra
	.end	cacheAuReset

/*******************************************************************************
*
* cacheAuDCFlushAll - flush entire data cache
*
* There is no way to do *only* a data cache flush, so we do a flush-invalidate.
* 
* RETURNS: N/A
*

* void cacheAuDCFlushAll (void)

*/
	.ent	cacheAuDCFlushAll
FUNC_LABEL(cacheAuDCFlushAll)
	/* run from kseg1 */
	la	t0,1f
	li	t1,KSEG2_TO_KSEG0_MASK
	and	t0,t0,t1
	or	t0,K1BASE
	j	t0
1:	
	/* Check for primary data cache */
	lw	a2,cacheAuDCacheSize
	blez	a2,99f

	/*
	 * Flush (actually, flush/invalidate) primary data cache
	 */
	lw	a3,cacheAuDCacheLineSize
	li	a0,K0BASE
	move	a1,a2
	icacheop(a0,a1,a2,a3,Index_Writeback_Inv_D)
99:	
	j	ra

	.end	cacheAuDCFlushAll

/*******************************************************************************
*
* cacheAuDCFlush - flush data cache locations
*
* There is no way to do *only* a data cache flush, so we do a flush-invalidate.
*
* RETURNS: N/A
*
*
* void cacheAuDCFlush
*     (
*     baseAddr,		/@ virtual address @/
*     byteCount		/@ number of bytes to invalidate @/
*     )

*/
	.ent	cacheAuDCFlush
FUNC_LABEL(cacheAuDCFlush)
	/* run from kseg1 */
	la	t0,1f
	li	t1,KSEG2_TO_KSEG0_MASK
	and	t0,t0,t1
	or	t0,K1BASE
	j	t0
1:	
	/* Check for primary data cache */
	lw	a2,cacheAuDCacheSize
	blez	a2,99f

	/* Flush-invalidate primary data cache */
	lw	a3,cacheAuDCacheLineSize
	vcacheop(a0,a1,a2,a3,Hit_Writeback_Inv_D)
	
99:	j	ra
	.end	cacheAuDCFlush


/*******************************************************************************
*
* cacheAuDCInvalidateAll - flush entire R7000 data cache
*
* There is no Index_Invalidate_D function, so we do an 
* Index_Writeback_Inv_D instead.
*
* RETURNS: N/A
*

* void cacheAuDCInvalidateAll (void)

*/
	.ent	cacheAuDCInvalidateAll
FUNC_LABEL(cacheAuDCInvalidateAll)
	/* run from kseg1 */
	la	t0,1f
	li	t1,KSEG2_TO_KSEG0_MASK
	and	t0,t0,t1
	or	t0,K1BASE
	j	t0
1:	
	/* Check for primary data cache */
	lw	a2,cacheAuDCacheSize
	blez	a2,99f

	/* Flush-invalidate primary data cache */
	lw	a3,cacheAuDCacheLineSize
	li	a0,K0BASE
	move	a1,a2
	icacheop(a0,a1,a2,a3,Index_Writeback_Inv_D)
	
99:	j	ra

	.end	cacheAuDCInvalidateAll

/*******************************************************************************
*
* cacheAuDCInvalidate - flush data cache locations
*
* RETURNS: N/A
*
* void cacheAuDCInvalidate
*     (
*     baseAddr,		/@ virtual address @/
*     byteCount		/@ number of bytes to invalidate @/
*     )

*/
	.ent	cacheAuDCInvalidate
FUNC_LABEL(cacheAuDCInvalidate)
	/* run from kseg1 */
	la	t0,1f
	li	t1,KSEG2_TO_KSEG0_MASK
	and	t0,t0,t1
	or	t0,K1BASE
	j	t0
1:	
	/* Check for primary data cache */
	lw	a2,cacheAuDCacheSize
	blez	a2,99f

	/* Invalidate primary data cache */
	lw	a3,cacheAuDCacheLineSize
	vcacheop(a0,a1,a2,a3,Hit_Invalidate_D)

99:	j	ra
	.end	cacheAuDCInvalidate

/******************************************************************************
*
* cacheAuRomTextUpdate - cache text update like functionality from the bootApp
*
*	a0	i-cache size
*	a1	i-cache line size
*	a2	d-cache size
*	a3	d-cache line size
*
* RETURNS: N/A
*

* void cacheAuRomTextUpdate ()

*/
	.ent	cacheAuRomTextUpdate
FUNC_LABEL(cacheAuRomTextUpdate)
	/* Save I-cache parameters */
	move	t0,a0
	move	t1,a1

	/* Check for primary data cache */
	blez	a2,99f

	/* Flush-invalidate primary data cache */
	li	a0,K0BASE
	move	a1,a2
	icacheop(a0,a1,a2,a3,Index_Writeback_Inv_D)
	sync
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
	sync
99:
	j	ra
	.end	cacheAuRomTextUpdate

/******************************************************************************
*
* cacheAuDCFlushInvalidateAll - flush entire Au data cache
*
* RETURNS: N/A
*

* void cacheAuDCFlushInvalidateAll (void)

*/
	.ent	cacheAuDCFlushInvalidateAll
FUNC_LABEL(cacheAuDCFlushInvalidateAll)
	/* run from kseg1 */
	la	t0,1f
	li	t1,KSEG2_TO_KSEG0_MASK
	and	t0,t0,t1
	or	t0,K1BASE
	j	t0
1:	
	/* Check for primary data cache */
	lw	a2,cacheAuDCacheSize
	blez	a2,99f

	/* Flush-invalidate primary data cache */
	lw	a3,cacheAuDCacheLineSize
	li	a0,K0BASE
	move	a1,a2
	icacheop(a0,a1,a2,a3,Index_Writeback_Inv_D)
	
99:	j	ra
	.end	cacheAuDCFlushInvalidateAll

/******************************************************************************
*
* cacheAuDCFlushInvalidate - flush Au data cache locations
*
* RETURNS: N/A
*

* void cacheAuDCFlushInvalidate
*     (
*     baseAddr,		/@ virtual address @/
*     byteCount		/@ number of bytes to invalidate @/
*     )

*/
	.ent	cacheAuDCFlushInvalidate
FUNC_LABEL(cacheAuDCFlushInvalidate)
	/* run from kseg1 */
	la	t0,1f
	li	t1,KSEG2_TO_KSEG0_MASK
	and	t0,t0,t1
	or	t0,K1BASE
	j	t0
1:	
	/* Check for primary data cache */
	lw	a2,cacheAuDCacheSize
	blez	a2,99f

	/* Flush-invalidate primary data cache */
	lw	a3,cacheAuDCacheLineSize
	vcacheop(a0,a1,a2,a3,Hit_Writeback_Inv_D)

99:	j	ra
	.end	cacheAuDCFlushInvalidate

/******************************************************************************
*
* cacheAuICInvalidateAll - invalidate entire Au instruction cache
*
* RETURNS: N/A
*

* void cacheAuICInvalidateAll (void)

*/
	.ent	cacheAuICInvalidateAll
FUNC_LABEL(cacheAuICInvalidateAll)
	/* run from kseg1 */
	la	t0,1f
	li	t1,KSEG2_TO_KSEG0_MASK
	and	t0,t0,t1
	or	t0,K1BASE
	j	t0
1:	
	/* Check for primary instruction cache */
	lw	a2,cacheAuICacheSize
	blez	a2,99f

	/* Invalidate primary instruction cache */
	lw	a3,cacheAuICacheLineSize
	li	a0,K0BASE
	move	a1,a2
	icacheop(a0,a1,a2,a3,Index_Invalidate_I)

99:	j	ra

	.end	cacheAuICInvalidateAll

/******************************************************************************
*
* cacheAuICInvalidate - invalidate Au instruction cache locations
*
* RETURNS: N/A
*

* void cacheAuICInvalidate
*     (
*     baseAddr,		/@ virtual address @/
*     byteCount		/@ number of bytes to invalidate @/
*     )

*/
	.ent	cacheAuICInvalidate
FUNC_LABEL(cacheAuICInvalidate)
	/* run from kseg1 */
	la	t0,1f
	li	t1,KSEG2_TO_KSEG0_MASK
	and	t0,t0,t1
	or	t0,K1BASE
	j	t0
1:	
	/* Check for primary instruction cache */
	lw	a2,cacheAuICacheSize
	blez	a2,99f	

	/* Invalidate primary instruction cache */
	lw	a3,cacheAuICacheLineSize
	vcacheop(a0,a1,a2,a3,Hit_Invalidate_I)

99:	j	ra
	.end	cacheAuICInvalidate

/******************************************************************************
*
* cacheAuPTextUpdateAll - text update for entire cache.
*
* RETURNS: N/A
*

* void cacheAuPTextUpdateAll (void)

*/
	.ent	cacheAuPTextUpdateAll
FUNC_LABEL(cacheAuPTextUpdateAll)
	/* run from kseg1 */
	la	t0,1f
	li	t1,KSEG2_TO_KSEG0_MASK
	and	t0,t0,t1
	or	t0,K1BASE
	j	t0
1:	
	/* Check for primary data cache */
	lw	a2,cacheAuDCacheSize
	blez	a2,1f

	/* Invalidate primary data cache */
	li	a0,K0BASE
	move	a1,a2
	lw	a2,cacheAuDCacheSize
	lw	a3,cacheAuDCacheLineSize
	icacheop(a0,a1,a2,a3,Index_Writeback_Inv_D)
1:
	/* Check for primary instruction cache */
	lw	a2,cacheAuICacheSize
	blez	a2,99f

	/* Invalidate primary instruction cache */
	li	a0,K0BASE
	move	a1,a2
	lw	a3,cacheAuICacheLineSize
	icacheop(a0,a1,a2,a3,Index_Invalidate_I)
	
99:	j	ra
	.end	cacheAuPTextUpdateAll

/******************************************************************************
*
* cacheAuPTextUpdate - text update primary caches
*
* RETURNS: N/A
*

* void cacheAuPTextUpdate
*     (
*     baseAddr,		/@ virtual address @/
*     byteCount		/@ number of bytes to invalidate @/
*     )

*/
	.ent	cacheAuPTextUpdate
FUNC_LABEL(cacheAuPTextUpdate)
	/* run from kseg1 */
	la	t0,1f
	li	t1,KSEG2_TO_KSEG0_MASK
	and	t0,t0,t1
	or	t0,K1BASE
	j	t0
1:	
	/* Check for primary data cache */
	lw	a2,cacheAuDCacheSize
	blez	a2,1f

	/* save input parameters */
	move	t0, a0
	move	t1, a1
	
	/* Flush-invalidate primary data cache */
	lw	a3,cacheAuDCacheLineSize
	vcacheop(a0,a1,a2,a3,Hit_Writeback_Inv_D)
1:

	/* Check for primary instruction cache */
	lw	a2,cacheAuICacheSize
	blez	a2,99f

	/* Invalidate primary instruction cache */
	move	a0,t0
	move	a1,t1
	lw	a3,cacheAuICacheLineSize
	vcacheop(a0,a1,a2,a3,Hit_Invalidate_I)

99:	j	ra
	.end	cacheAuPTextUpdate


/******************************************************************************
*
* cacheAuVirtPageFlush - flush one page of virtual addresses from caches
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
* void cacheAuVirtPageFlush (UINT asid, void *vAddr, UINT pageSize);
*/
	.ent	cacheAuVirtPageFlush
FUNC_LABEL(cacheAuVirtPageFlush)
	/* run from kseg1 */
	la	t0,1f
	li	t1,KSEG2_TO_KSEG0_MASK
	and	t0,t0,t1
	or	t0,K1BASE
	j	t0
1:	
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
	
	lw	a2,cacheAuDCacheSize
	blez	a2,1f

	/* Flush-invalidate primary data cache */
	move	a0, t0
	move	a1, t1
	lw	a3,cacheAuDCacheLineSize
	vcacheop(a0,a1,a2,a3,Hit_Writeback_Inv_D)
1:
	lw	a2,cacheAuICacheSize
	blez	a2,1f	

	/* Invalidate primary instruction cache */
	move	a0,t0
	move	a1,t1
	lw	a3,cacheAuICacheLineSize
	vcacheop(a0,a1,a2,a3,Hit_Invalidate_I)
1:	
	/* restore the original ASID */

	mtc0	t3, C0_TLBHI		/* Restore old EntryHi  */	
	mtc0	t2, C0_SR		/* restore interrupts */
	HAZARD_TLB
	
	j	ra
	.end	cacheAuVirtPageFlush

/******************************************************************************
*
* cacheAuSync - sync region of memory through all caches
*
* RETURNS: N/A
*
* void cacheAuSync (void *vAddr, UINT pageSize);
*/
	.ent	cacheAuSync
FUNC_LABEL(cacheAuSync)
	/* run from kseg1 */
	la	t0,1f
	li	t1,KSEG2_TO_KSEG0_MASK
	and	t0,t0,t1
	or	t0,K1BASE
	j	t0
1:	
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

	lw	a2,cacheAuICacheSize
	blez	a2,1f	

	/* Invalidate primary instruction cache */
	move	a0,t0
	move	a1,t1
	lw	a3,cacheAuICacheLineSize
	vcacheop(a0,a1,a2,a3,Hit_Invalidate_I)
1:
	lw	a2,cacheAuDCacheSize
	blez	a2,1f

	/* Flush-invalidate primary data cache */
	move	a0, t0
	move	a1, t1
	lw	a3,cacheAuDCacheLineSize
	vcacheop(a0,a1,a2,a3,Hit_Writeback_Inv_D)
1:
	mtc0	t2, C0_SR		/* restore interrupts */
	
	j	ra
	.end	cacheAuSync
