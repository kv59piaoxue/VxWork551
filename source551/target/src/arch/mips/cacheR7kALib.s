/* cacheR7kALib.s - MIPS R7000 cache management assembly routines */

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
01n,18jan02,agf  add explicit align directive to data section(s)
01m,02aug01,mem  Diab integration
01l,16jul01,ros  add CofE comment
01k,08feb01,agf  Adding HAZARD macros
01j,28nov00,pes  Fixed SPR #35972. Reworked cacheR7kReset to correctly
                 initialize cache ram.
01i,22nov00,mem  Added cacheR7kRomTextUpdate
01h,26oct00,pes  Fixed SPR 35097 (SR set to uninitialized value). Fixed SPR
                 33461 (QED RM7000 L3 cache not supported). Forced cache
                 functions to execute in kseg1 (uncached) address space. Split
                 and completed implementation of flush/invalidate/clear
                 functions.
01g,01aug00,dra  Include L3 cache support
01f,21jun00,dra  Inline cacheR7kDCFlushInvalidate and cacheR7kICInvalidate in
                 cacheR7kVirtPageFlush.  Add Errata workarounds.
01e,20jun00,dra  add cacheR7kPTextUpdateAll and cacheR7kPTextUpdate.
01d,14jun00,dra  generalize the mmuMipsUnMap flush of virtual page address to
                 all Mips archs
01c,05jun00,dra  R3K R4K merge
01b,28feb00,dra  Add GTEXT, GDATA, FUNC macros to support omfDll & loader
01a,08jul99,dra  Created this file based on cacheR4kALib.s.
*/

/*
DESCRIPTION
This library contains MIPS R7000 cache setup, size configuration,
flush and invalidation routines. The MIPS R7000 cache organization
includes:

    1) D-cache: Primary Data Cache (4-way set associative)
    2) I-cache: Primary Instruction Cache (4-way set associative)
    3) S-cache: on-chip Secondary Cache (4-way set associative)
    4) T-cache: off-chip Tertiary Cache controller (direct-mapped)

Since the set size is the same as the MMU page size, The D- and I-cache
are physically indexed. Since the S-cache access is not started until the
D- and I-caches are determined to have missed, the S-cache is also
physically indexed.  The T-cache is accessed only in the case of an
S-cache miss, and the lookup happens in parallel with main memory.

The presence of T- and S-caches can be sensed, and the caches
independently enabled, using Config register bits.

A S-cache Hit-style Writeback or Invalidate cache operation
automatically performs the appropriate operation on the D- and
I-caches.  The Indexed operations, however, operate independently on
the S-cache.

The RM7000 lacks a 'Hit' style cache operation for the Tertiary Cache.
Therefore, a complete cache clear is the only way to be sure that
a piece of data has been removed from the Tertiary cache.

NOTES

All routines assume that a tertiary cache operation could occur even
if the secondary cache is disabled.

For general information about caching, see the manual entry for cacheLib.

INCLUDE FILES: cacheLib.h

SEE ALSO: cacheR7kLib, cacheLib
*/

#define _ASMLANGUAGE
#include "vxWorks.h"
#include "asm.h"
#include "arch/mips/archMips.h"

	/* defines */
#define SR_INT_ENABLE		SR_IE
	
/* Defining the MACRO_SYNC symbol causes each invocation of a cacheop 
 * macro to be followed (after the last iteration) with a 'sync' 
 * instruction. The the sync instruction is to stall the execution of 
 * the processor until any outstanding writes in the write buffer 
 * have completed.
 *
 * The option of reversing this operation is maintained at this time 
 * because the final determination of benefits vs. performance
 * impact has not yet been completed.
 */
#define MACRO_SYNC

/* This macro is defined if the cacheR7kICInvalidateAll function is expected
 * to invalidate the underlying secondary and/or tertiary cache lines as well.
 * This is currently not believed to be the case. */
#undef DESCEND_ICACHE_INVALIDATE_HIERARCHY
	
/*
 * Macros for Secondary & Tertiary cache operations.  See r4000.h or 
 * archMips.h for others.
 */

#undef	CFG_SC					/* RM7000 different than R4K */

#define CFG_SC			0x80000000	/* RM7000 S-cache present */
#define CFG_SE			0x00000008	/* RM7000 S-cache enable */

#define CFG_TC			0x00020000	/* T-cache present */
#define CFG_TE			0x00001000	/* T-cache enable */

/* cache operations for invalidating T-cache */
#define Flash_Invalidate_T	0x02		/* 0	   2 */
#define Index_Store_Tag_T	0x0a		/* 2	   2 */
#define Page_Invalidate_T	0x16		/* 5	   2 */

#define LINES_PER_PAGE		128		/* for Page_Invalidate_T */
#define PAGE_SHIFT		0x07		/* log2(LINES_PER_PAGE) */

/*
 * RM7000 provides three ways of invalidating the T-cache:
 *
 *	* perform an Index_Store_Tag_T for every line in the T-cache
 *	* perform a Page_Invalidate_T for every 128 lines in the T-cache:
 *	  The CPU does a burst of 128 Index_Store_Tag_T cache operations
 *	* perform a Flash_Invalidate_T (if supported by the cache hardware)
 *
 * This library supports only one of the three modes.
 */
#define	INVALIDATE_T_MODE_INDEX	0		/* use Index_Store_Tag_T */
#define	INVALIDATE_T_MODE_PAGE	1		/* use Page_Invalidate_T */
#define	INVALIDATE_T_MODE_FLASH	2		/* use Flash_Invalidate_T */

#define INVALIDATE_T_MODE	INVALIDATE_T_MODE_PAGE

	/* globals */

	.data
	.align	4
cacheR7kICacheSize:
	.word	0			/* instruction cache size */
cacheR7kDCacheSize:
	.word	0			/* data cache size */
cacheR7kSCacheSize:
	.word	0			/* secondary cache size */
cacheR7kTCacheSize:
	.word   0			/* tertiary cache size  */
cacheR7kICacheLineSize:
	.word	0			/* instruction cache line size */
cacheR7kDCacheLineSize:
	.word	0			/* data cache line size */
cacheR7kSCacheLineSize:
	.word	0			/* secondary cache line size */
cacheR7kTCacheLineSize:
	.word	0			/* tertiary cache line size */

	.text
	.set	reorder

	.globl GTEXT(cacheR7kReset)		/* low level cache initialization */
	.globl GTEXT(cacheR7kRomTextUpdate)	/* cache-text-update for bootApp */
	.globl GTEXT(cacheR7kDCFlushAll)	/* flush entire data cache */
	.globl GTEXT(cacheR7kDCFlush)		/* flush data cache locations */
	.globl GTEXT(cacheR7kDCInvalidateAll)	 /* flush entire data cache */
	.globl GTEXT(cacheR7kDCInvalidate)	 /* flush data cache locations */
	.globl GTEXT(cacheR7kDCFlushInvalidateAll) /* flush entire data cache */
	.globl GTEXT(cacheR7kDCFlushInvalidate) /* flush data cache locations */
	.globl GTEXT(cacheR7kICInvalidateAll)	/* invalidate entire i cache  */
	.globl GTEXT(cacheR7kICInvalidate)	/* invalidate i cache loc'ns  */
	.globl GTEXT(cacheR7kPTextUpdateAll)	/* invalidate entire P-cache  */
	.globl GTEXT(cacheR7kPTextUpdate)	/* invalidate P-cache locn's  */
	.globl GTEXT(cacheR7kL2Enable)		/* enable L2 S-cache */
	.globl GTEXT(cacheR7kL2Disable)		/* disable L2 S-cache */
	.globl GTEXT(cacheR7kL3Enable)		/* enable L3 T-cache */
	.globl GTEXT(cacheR7kL3Disable)		/* disable L3 T-cache */
	
	.globl GDATA(cacheR7kDCacheSize)	/* data cache size */
	.globl GDATA(cacheR7kICacheSize)	/* inst. cache size */
	.globl GDATA(cacheR7kSCacheSize)	/* secondary cache size */
	.globl GDATA(cacheR7kTCacheSize)	/* tertiary cache size */
	.globl GDATA(cacheR7kDCacheLineSize)	/* data cache line size */
	.globl GDATA(cacheR7kICacheLineSize)	/* inst. cache line size */
	.globl GDATA(cacheR7kSCacheLineSize)	/* secondary cache line size */
	.globl GDATA(cacheR7kTCacheLineSize)	/* tertiary cache line size  */

#ifdef IS_KSEGM
	.globl GTEXT(cacheR7kVirtPageFlush)	/* flush cache on MMU page unmap */
	.globl GTEXT(cacheR7kSync)		/* sync memory through all caches */
#endif	

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
	HAZARD_CACHE ;			\
	cache	op2,0(a0) ;		\
	HAZARD_CACHE

/* specials for cache initialisation */
#define doop1lw(op1) 			\
	lw	zero,0(a0)

#define doop1lw1(op1) 			\
	cache	op1,0(a0) ;		\
	HAZARD_CACHE			\
	lw	zero,0(a0) ;		\
	cache	op1,0(a0) ;		\
	HAZARD_CACHE

#define doop121(op1,op2) 		\
	cache	op1,0(a0) ;		\
	HAZARD_CACHE ;			\
	cache	op2,0(a0) ;		\
	HAZARD_CACHE ;			\
	cache	op1,0(a0) ;		\
	HAZARD_CACHE

#define _oploopn(minaddr, maxaddr, linesize, tag, ops) \
	.set	noreorder ;		\
10: 	doop##tag##ops ;	\
	bne     minaddr,maxaddr,10b ;	\
	add   	minaddr,linesize ;	\
	.set	reorder

#ifdef MACRO_SYNC
/* finally the cache operation macros */
#define vcacheopn(kva, n, cacheSize, cacheLineSize, tag, ops) \
 	blez	n,11f ;			\
	addu	n,kva ;			\
	_align(kva, n, cacheLineSize) ; \
	_oploopn(kva, n, cacheLineSize, tag, ops) ; \
	sync ; \
11:

#define icacheopn(kva, n, cacheSize, cacheLineSize, tag, ops) \
	_mincache(n, cacheSize);	\
 	blez	n,11f ;			\
	addu	n,kva ;			\
	_align(kva, n, cacheLineSize) ; \
	_oploopn(kva, n, cacheLineSize, tag, ops) ; \
	sync ; \
11:
#else
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
#endif

#define vcacheop(kva, n, cacheSize, cacheLineSize, op) \
	vcacheopn(kva, n, cacheSize, cacheLineSize, 1, (op))

#define icacheop(kva, n, cacheSize, cacheLineSize, op) \
	icacheopn(kva, n, cacheSize, cacheLineSize, 1, (op))




/*******************************************************************************
*
* cacheR7kReset - low level initialisation of the R7000 primary caches
*
* This routine initialises the R7000 primary caches to ensure that they
* have good parity.  It must be called by the ROM before any cached locations
* are used to prevent the possibility of data with bad parity being written to
* memory.
*
* It is assumed that memory has been initialised and already has good parity.
*
* Arguments are as follows:
*	a0	type of reset
*	t0	I-cache size
*	t1	I-cache line size
*	t2	D-cache size
*	t3	D-cache line size
*	t4	S-cache size
*	t5	S-cache line size
*	t6	T-cache size
*	t7	T-cache line size
*
* RETURNS: N/A
*

* void cacheR7kReset (initMem)

*/
	.ent	cacheR7kReset
FUNC_LABEL(cacheR7kReset)

	/* disable all i/u and cache exceptions */
	mfc0	v0,C0_SR
	HAZARD_CP_READ
	and	v1,v0,SR_BEV
	or	v1,SR_DE
	mtc0	v1,C0_SR
	HAZARD_CP_WRITE

	mfc0	t8,C0_CONFIG
        HAZARD_CP_READ
	and	t9,t8,~(CFG_TE|CFG_SE)
	mtc0	t9,C0_CONFIG

	/* set tag & ecc to 0 */
	mtc0	zero,C0_TAGLO
	mtc0	zero,C0_TAGHI
	mtc0	zero,C0_ECC
        HAZARD_CP_WRITE

	/*
	 * The caches are probably in an indeterminate state,
	 * so we force good parity into them by doing an
	 * invalidate, load/fill, invalidate for each line.
	 */

	/* 
	 * Initialize primary instruction cache.
	 */
	.set	noreorder
	li	a0,K0BASE
	addu	a1,a0,t0			# limit = base + icachesize 
1:	addu	a0,t1				# icacheLineSize
	cache	Index_Store_Tag_I,-4(a0)	# clear tag
	HAZARD_CACHE
	cache	Fill_I,-4(a0)			# fill data line
	HAZARD_CACHE
	bne	a0,a1,1b
	cache	Index_Store_Tag_I,-4(a0)	# BDSLOT: clear tag
	.set	reorder

	/* 
	 * Initialize primary data cache.
	 * (for multi-way set caches, we do it in 3 passes).
	 */

	/* 1: initialise dcache tags */
	.set	noreorder
	li	a0,K0BASE
	addu	a1,a0,t2        		# limit = base + dcachesize 
1:	addu	a0,t3
	bne	a0,a1,1b
	cache	Index_Store_Tag_D,-4(a0)	# BDSLOT: clear tag
	.set	reorder

        sync

        /* 2: fill dcache data */
        .set    noreorder
        li      a0,K0BASE
        addu    a1,a0,t2                	# limit = base + dcachesize
1:      addu    a0,t3
        bne     a0,a1,1b
        lw      zero,-4(a0)                     # BDSLOT: fill line
        .set    reorder 

        sync

        /* 3: clear dcache tags */
        .set    noreorder
        li      a0,K0BASE
        addu    a1,a0,t2                	# limit = base + dcachesize
1:      addu    a0,t3
        bne     a0,a1,1b
        cache   Index_Store_Tag_D,-4(a0)        # BDSLOT: clear tag
        .set    reorder 

	/*
	 * Initialize the secondary cache
	 * (for n-way set caches, we do it in 3 passes).
         * Requires 256KB memory to provide good parity.
	 */
	blez	t4,3f		/* we're through if no scache */

        /* enable secondary cache */
        or      v1,CFG_SE
        mtc0    v1,C0_CONFIG
        HAZARD_CP_WRITE

        /* 1: initialise scache tags */
        li      a0,K0BASE
        addu    a1,a0,t4                # limit = base + scachesize
        .set    noreorder
1:      addu    a0,t5
        bne     a0,a1,1b
        cache   Index_Store_Tag_SD,-4(a0)        # BDSLOT: clear tag
        .set    reorder

        sync

        /* 1: fill scache data */
        li      a0,K0BASE
        addu    a1,a0,t4                # a1 = base + scachesize
        .set    noreorder
1:      addu    a0,t5
        bne     a0,a1,1b
        lw      zero,-4(a0)                     # BDSLOT: load line
        .set    reorder

        sync

        /* 3: clear scache tags */
        li      a0,K0BASE
        addu    a1,a0,t4                # limit = base + scachesize
        .set    noreorder
1:      addu    a0,t5
        bne     a0,a1,1b
        cache   Index_Store_Tag_SD,-4(a0)        # BDSLOT: clear tag
        .set    reorder 

	sync

	/* Enable T-cache if present */
	blez	t6,3f		/* we're through if no tcache */
	
        /* enable tertiary cache */
        or      v1,CFG_TE
        mtc0    v1,C0_CONFIG
        HAZARD_CP_WRITE

	/* Initialize T-Cache */

#if (INVALIDATE_T_MODE == INVALIDATE_T_MODE_FLASH)

	li	a0,K0BASE
	cache	Flash_Invalidate_T,0(a0)

#elif (INVALIDATE_T_MODE == INVALIDATE_T_MODE_PAGE)

	li	a0,K0BASE
	move	a2,t6
	move	a3,t7
	move	a1,a2
	sll	a3,PAGE_SHIFT
	icacheop(a0,a1,a2,a3,Page_Invalidate_T)

#elif (INVALIDATE_T_MODE == INVALIDATE_T_MODE_INDEX)

	li	a0,K0BASE
	move	a2,t6
	move	a3,t7
	move	a1,a2
	icacheop(a0,a1,a2,a3,Index_Store_Tag_T)

#else

#error "INVALIDATE_T_MODE value incorrect"

#endif /* INVALIDATE_T_MODE */

0:
3:	
	sync
	mtc0	t8,C0_CONFIG
	mtc0	v0,C0_SR
        HAZARD_CP_WRITE
	j	ra
	.end	cacheR7kReset

/*******************************************************************************
*
* cacheR7kDCFlushAll - flush entire R7000 data cache
*
* There is no way to do *only* a data cache flush, so we do a flush-invalidate.
* 
* Tertiary cache is Writethrough, so no Writeback is necessary
*
* RETURNS: N/A
*

* void cacheR7kDCFlushAll (void)

*/
	.ent	cacheR7kDCFlushAll
FUNC_LABEL(cacheR7kDCFlushAll)
	/* run from kseg1 */
	la	t0,1f
	li	t1,KSEG2_TO_KSEG0_MASK
	and	t0,t0,t1
	or	t0,K1BASE
	j	t0
1:	
	/* Check for primary data cache */
	lw	a2,cacheR7kDCacheSize
	blez	a2,1f

	/*
	 * Invalidate primary data cache
	 * Data will be flushed to next cache layer
	 */
	lw	a3,cacheR7kDCacheLineSize
	li	a0,K0BASE
	move	a1,a2
	icacheop(a0,a1,a2,a3,Index_Writeback_Inv_D)

1:
	/* check for secondary cache present & ENABLED, skip if not */
	mfc0	t8,C0_CONFIG
        HAZARD_CP_READ
	and	t9,t8,CFG_SC		/* SC=0 if S-cache is present */
	bnez	t9,1f			/* branch if S-cache is not present */
	and	t9,t8,CFG_SE
	beqz	t9,1f			/* branch if S-cache is not enabled */
	lw	a2,cacheR7kSCacheSize
	blez	a2,1f

	/* Invalidate secondary cache */
	li	a0,K0BASE
	move	a1,a2
	lw	a3,cacheR7kSCacheLineSize
	icacheop(a0,a1,a2,a3,Index_Writeback_Inv_SD)

	/* no need to flush tertiary cache: it's write through and therefore always
	 * consistent with main memory */
1:
#ifndef MACRO_SYNC
	sync
#endif
	j	ra

	.end	cacheR7kDCFlushAll

/*******************************************************************************
*
* cacheR7kDCFlush - flush R7000 data cache locations
*
* There is no way to do *only* a data cache flush, so we do a flush-invalidate.
*
* Tertiary cache is Writethrough, so no Writeback is necessary
*
* RETURNS: N/A
*
*
* void cacheR7kDCFlush
*     (
*     baseAddr,		/@ virtual address @/
*     byteCount		/@ number of bytes to invalidate @/
*     )

*/
	.ent	cacheR7kDCFlush
FUNC_LABEL(cacheR7kDCFlush)
	/* run from kseg1 */
	la	t0,1f
	li	t1,KSEG2_TO_KSEG0_MASK
	and	t0,t0,t1
	or	t0,K1BASE
	j	t0
1:	
	/* Save parameters */
	move	t0,a0
	move	t1,a1

	/* check for secondary cache present and ENABLED, skip if not */
	mfc0	t8,C0_CONFIG
        HAZARD_CP_READ
	and	t9,t8,CFG_SC		/* SC=0 if S-cache is present */
	bnez	t9,2f			/* branch if S-cache is not present */
	and	t9,t8,CFG_SE
	beqz	t9,2f			/* branch if S-cache is not enabled */
	lw	a2,cacheR7kSCacheSize
	blez	a2,2f

	/*
	 * Note: if secondary cache is present and enabled, a flush of
	 * secondary cache addresses automatically flushes corresponding
	 * primary data cache addresses.
	 */

	/* Flush-invalidate secondary data cache */
	lw	a3,cacheR7kSCacheLineSize
	vcacheop(a0,a1,a2,a3,Hit_Writeback_Inv_SD)

	b	1f

2:
	/* Check for primary data cache */
	lw	a2,cacheR7kDCacheSize
	blez	a2,1f

	/* Flush-invalidate primary data cache */
	lw	a3,cacheR7kDCacheLineSize
	vcacheop(a0,a1,a2,a3,Hit_Writeback_Inv_D)

	/* no need to flush tertiary cache: it's write through and therefore always
	 * consistent with main memory */
1:
#ifndef MACRO_SYNC
	sync
#endif
	j	ra
	.end	cacheR7kDCFlush


/*******************************************************************************
*
* cacheR7kDCInvalidateAll - flush entire R7000 data cache
*
* There is no Index_Invalidate_D or Index_Invalidate_SD function, so we 
* do an Index_Writeback_Inv_{D,SD} instead.
*
* RETURNS: N/A
*

* void cacheR7kDCInvalidateAll (void)

*/
	.ent	cacheR7kDCInvalidateAll
FUNC_LABEL(cacheR7kDCInvalidateAll)
	/* run from kseg1 */
	la	t0,1f
	li	t1,KSEG2_TO_KSEG0_MASK
	and	t0,t0,t1
	or	t0,K1BASE
	j	t0
1:	
	/* Check for primary data cache */
	lw	a2,cacheR7kDCacheSize
	blez	a2,1f

	/*
	 * Invalidate primary data cache
	 * Data will be flushed to next cache layer
	 */
	lw	a3,cacheR7kDCacheLineSize
	li	a0,K0BASE
	move	a1,a2
	icacheop(a0,a1,a2,a3,Index_Writeback_Inv_D)

1:
	/* check for secondary cache present & ENABLED, skip if not */
	mfc0	t8,C0_CONFIG
        HAZARD_CP_READ
	and	t9,t8,CFG_SC		/* SC=0 if S-cache is present */
	bnez	t9,1f			/* branch if S-cache is not present */
	and	t9,t8,CFG_SE
	beqz	t9,1f			/* branch if S-cache is not enabled */
	lw	a2,cacheR7kSCacheSize
	blez	a2,1f

	/* Invalidate secondary cache */
	li	a0,K0BASE
	move	a1,a2
	lw	a3,cacheR7kSCacheLineSize
	icacheop(a0,a1,a2,a3,Index_Writeback_Inv_SD)

1:
	/* check for T-cache present & ENABLED, skip if not */
	mfc0	t8,C0_CONFIG
        HAZARD_CP_READ
	and	t9,t8,CFG_TC		/* TC=0 if T-cache is present */
	bnez	t9,1f			/* branch if T-cache is not present */
	and	t9,t8,CFG_TE
	beqz	t9,1f			/* branch if T-cache is not enabled */
	lw	a2,cacheR7kTCacheSize
	blez	a2,1f

	/* Invalidate tertiary cache */

#if (INVALIDATE_T_MODE == INVALIDATE_T_MODE_FLASH)

	li	a0,K0BASE
	cache	Flash_Invalidate_T,0(a0)

#elif (INVALIDATE_T_MODE == INVALIDATE_T_MODE_PAGE)

	mtc0	zero,C0_TAGLO  /* Set invalid state in TagLo register */
	mtc0	zero,C0_TAGHI  /* Set invalid state in TagHi register */
	HAZARD_CACHE_TAG
	li	a0,K0BASE
	move	a1,a2
	lw	a3,cacheR7kTCacheLineSize
	sll	a3,PAGE_SHIFT
	icacheop(a0,a1,a2,a3,Page_Invalidate_T)

#elif (INVALIDATE_T_MODE == INVALIDATE_T_MODE_INDEX)

	mtc0	zero,C0_TAGLO  /* Set invalid state in TagLo register */
	mtc0	zero,C0_TAGHI  /* Set invalid state in TagHi register */
	HAZARD_CACHE_TAG
	li	a0,K0BASE
	move	a1,a2
	lw	a3,cacheR7kTCacheLineSize
	icacheop(a0,a1,a2,a3,Index_Store_Tag_T)

#else

#error "INVALIDATE_T_MODE value incorrect"

#endif /* INVALIDATE_T_MODE */

1:
	j	ra

	.end	cacheR7kDCInvalidateAll

/*******************************************************************************
*
* cacheR7kDCInvalidate - flush R7000 data cache locations
*
* RETURNS: N/A
*

* void cacheR7kDCInvalidate
*     (
*     baseAddr,		/@ virtual address @/
*     byteCount		/@ number of bytes to invalidate @/
*     )

*/
	.ent	cacheR7kDCInvalidate
FUNC_LABEL(cacheR7kDCInvalidate)
	/* run from kseg1 */
	la	t0,1f
	li	t1,KSEG2_TO_KSEG0_MASK
	and	t0,t0,t1
	or	t0,K1BASE
	j	t0
1:	
	/* Save parameters */
	move	t0,a0
	move	t1,a1

	/* check for secondary cache present and ENABLED, skip if not */
	mfc0	t8,C0_CONFIG
        HAZARD_CP_READ
	and	t9,t8,CFG_SC		/* SC=0 if S-cache is present */
	bnez	t9,1f			/* branch if S-cache is not present */
	and	t9,t8,CFG_SE
	beqz	t9,1f			/* branch if S-cache is not enabled */
	lw	a2,cacheR7kSCacheSize
	blez	a2,1f

	/*
	 * Note: if secondary cache is present and enabled, invalidating
	 * secondary cache addresses automatically invalidates corresponding
	 * primary data cache addresses.
	 */

	/* Invalidate secondary data cache */
	lw	a3,cacheR7kSCacheLineSize
	vcacheop(a0,a1,a2,a3,Hit_Invalidate_SD)

	b	3f

1:
	/* Check for primary data cache */
	lw	a2,cacheR7kDCacheSize
	blez	a2,1f

	/* Invalidate primary data cache */
	lw	a3,cacheR7kDCacheLineSize
	vcacheop(a0,a1,a2,a3,Hit_Invalidate_D)

3:
	/* check for T-cache present & ENABLED, skip if not */
	mfc0	t8,C0_CONFIG
        HAZARD_CP_READ
	and	t9,t8,CFG_TC		/* TC=0 if T-cache is present */
	bnez	t9,1f			/* branch if T-cache is not present */
	and	t9,t8,CFG_TE
	beqz	t9,1f			/* branch if T-cache is not enabled */
	lw	a2,cacheR7kTCacheSize
	blez	a2,1f

	/* Invalidate tertiary cache */

	/*
	 * ENTIRE cache must be cleared, because all T-cache operations
	 * on the R7k are Indexed (no support for virtual addresses).
	 */

#if (INVALIDATE_T_MODE == INVALIDATE_T_MODE_FLASH)

	li	a0,K0BASE
	cache	Flash_Invalidate_T,0(a0)

#elif (INVALIDATE_T_MODE == INVALIDATE_T_MODE_PAGE)

	mtc0	zero,C0_TAGLO  /* Set invalid state in TagLo register */
	mtc0	zero,C0_TAGHI  /* Set invalid state in TagHi register */
	HAZARD_CACHE_TAG
	li	a0,K0BASE
	move	a1,a2
	lw	a3,cacheR7kTCacheLineSize
	sll	a3,PAGE_SHIFT
	icacheop(a0,a1,a2,a3,Page_Invalidate_T)

#elif (INVALIDATE_T_MODE == INVALIDATE_T_MODE_INDEX)

	mtc0	zero,C0_TAGLO  /* Set invalid state in TagLo register */
	mtc0	zero,C0_TAGHI  /* Set invalid state in TagHi register */
	HAZARD_CACHE_TAG
	li	a0,K0BASE
	move	a1,a2
	lw	a3,cacheR7kTCacheLineSize
	icacheop(a0,a1,a2,a3,Index_Store_Tag_T)

#else

#error "INVALIDATE_T_MODE value incorrect"

#endif /* INVALIDATE_T_MODE */

1:
	j	ra
	.end	cacheR7kDCInvalidate

/*******************************************************************************
*
* cacheR7kDCFlushInvalidateAll - flush entire R7000 data cache
*
* Tertiary cache is Writethrough, so no Writeback is necessary
*
* RETURNS: N/A
*

* void cacheR7kDCFlushInvalidateAll (void)

*/
	.ent	cacheR7kDCFlushInvalidateAll
FUNC_LABEL(cacheR7kDCFlushInvalidateAll)
	/* run from kseg1 */
	la	t0,1f
	li	t1,KSEG2_TO_KSEG0_MASK
	and	t0,t0,t1
	or	t0,K1BASE
	j	t0
1:	
	/* Check for primary data cache */
	lw	a2,cacheR7kDCacheSize
	blez	a2,1f

	/*
	 * Invalidate primary data cache
	 * Data will be flushed to next cache layer
	 */
	lw	a3,cacheR7kDCacheLineSize
	li	a0,K0BASE
	move	a1,a2
	icacheop(a0,a1,a2,a3,Index_Writeback_Inv_D)

1:
	/* check for secondary cache present & ENABLED, skip if not */
	mfc0	t8,C0_CONFIG
        HAZARD_CP_READ
	and	t9,t8,CFG_SC		/* SC=0 if S-cache is present */
	bnez	t9,1f			/* branch if S-cache is not present */
	and	t9,t8,CFG_SE
	beqz	t9,1f			/* branch if S-cache is not enabled */
	lw	a2,cacheR7kSCacheSize
	blez	a2,1f

	/* Invalidate secondary cache */
	li	a0,K0BASE
	move	a1,a2
	lw	a3,cacheR7kSCacheLineSize
	icacheop(a0,a1,a2,a3,Index_Writeback_Inv_SD)

1:
	/* check for T-cache present & ENABLED, skip if not */
	mfc0	t8,C0_CONFIG
        HAZARD_CP_READ
	and	t9,t8,CFG_TC		/* TC=0 if T-cache is present */
	bnez	t9,1f			/* branch if T-cache is not present */
	and	t9,t8,CFG_TE
	beqz	t9,1f			/* branch if T-cache is not enabled */
	lw	a2,cacheR7kTCacheSize
	blez	a2,1f

	/* Invalidate tertiary cache */

#if (INVALIDATE_T_MODE == INVALIDATE_T_MODE_FLASH)

	li	a0,K0BASE
	cache	Flash_Invalidate_T,0(a0)

#elif (INVALIDATE_T_MODE == INVALIDATE_T_MODE_PAGE)

	mtc0	zero,C0_TAGLO  /* Set invalid state in TagLo register */
	mtc0	zero,C0_TAGHI  /* Set invalid state in TagHi register */
	HAZARD_CACHE_TAG
	li	a0,K0BASE
	move	a1,a2
	lw	a3,cacheR7kTCacheLineSize
	sll	a3,PAGE_SHIFT
	icacheop(a0,a1,a2,a3,Page_Invalidate_T)

#elif (INVALIDATE_T_MODE == INVALIDATE_T_MODE_INDEX)

	mtc0	zero,C0_TAGLO  /* Set invalid state in TagLo register */
	mtc0	zero,C0_TAGHI  /* Set invalid state in TagHi register */
	HAZARD_CACHE_TAG
	li	a0,K0BASE
	move	a1,a2
	lw	a3,cacheR7kTCacheLineSize
	icacheop(a0,a1,a2,a3,Index_Store_Tag_T)

#else

#error "INVALIDATE_T_MODE value incorrect"

#endif /* INVALIDATE_T_MODE */

1:
	j	ra

	.end	cacheR7kDCFlushInvalidateAll

/*******************************************************************************
*
* cacheR7kDCFlushInvalidate - flush R7000 data cache locations
*
* RETURNS: N/A
*

* void cacheR7kDCFlushInvalidate
*     (
*     baseAddr,		/@ virtual address @/
*     byteCount		/@ number of bytes to invalidate @/
*     )

*/
	.ent	cacheR7kDCFlushInvalidate
FUNC_LABEL(cacheR7kDCFlushInvalidate)
	/* run from kseg1 */
	la	t0,1f
	li	t1,KSEG2_TO_KSEG0_MASK
	and	t0,t0,t1
	or	t0,K1BASE
	j	t0
1:	
	/* Save parameters */
	move	t0,a0
	move	t1,a1

	/* check for secondary cache present and ENABLED, skip if not */
	mfc0	t8,C0_CONFIG
        HAZARD_CP_READ
	and	t9,t8,CFG_SC		/* SC=0 if S-cache is present */
	bnez	t9,1f			/* branch if S-cache is not present */
	and	t9,t8,CFG_SE
	beqz	t9,1f			/* branch if S-cache is not enabled */
	lw	a2,cacheR7kSCacheSize
	blez	a2,1f

	/*
	 * Note: if secondary cache is present and enabled, a flush of
	 * secondary cache addresses automatically flushes corresponding
	 * primary data cache addresses.
	 */

	/* Flush-invalidate secondary data cache */
	lw	a3,cacheR7kSCacheLineSize
	vcacheop(a0,a1,a2,a3,Hit_Writeback_Inv_SD)

	b	3f

1:
	/* Check for primary data cache */
	lw	a2,cacheR7kDCacheSize
	blez	a2,1f

	/* Flush-invalidate primary data cache */
	lw	a3,cacheR7kDCacheLineSize
	vcacheop(a0,a1,a2,a3,Hit_Writeback_Inv_D)

3:
	/* check for T-cache present & ENABLED, skip if not */
	mfc0	t8,C0_CONFIG
        HAZARD_CP_READ
	and	t9,t8,CFG_TC		/* TC=0 if T-cache is present */
	bnez	t9,1f			/* branch if T-cache is not present */
	and	t9,t8,CFG_TE
	beqz	t9,1f			/* branch if T-cache is not enabled */
	lw	a2,cacheR7kTCacheSize
	blez	a2,1f

	/* Invalidate tertiary cache */

	/*
	 * ENTIRE cache must be cleared, because all T-cache operations
	 * on the R7k are Indexed (no support for virtual addresses).
	 */

#if (INVALIDATE_T_MODE == INVALIDATE_T_MODE_FLASH)

	li	a0,K0BASE
	cache	Flash_Invalidate_T,0(a0)

#elif (INVALIDATE_T_MODE == INVALIDATE_T_MODE_PAGE)

	mtc0	zero,C0_TAGLO  /* Set invalid state in TagLo register */
	mtc0	zero,C0_TAGHI  /* Set invalid state in TagHi register */
	HAZARD_CACHE_TAG
	li	a0,K0BASE
	move	a1,a2
	lw	a3,cacheR7kTCacheLineSize
	sll	a3,PAGE_SHIFT
	icacheop(a0,a1,a2,a3,Page_Invalidate_T)

#elif (INVALIDATE_T_MODE == INVALIDATE_T_MODE_INDEX)

	mtc0	zero,C0_TAGLO  /* Set invalid state in TagLo register */
	mtc0	zero,C0_TAGHI  /* Set invalid state in TagHi register */
	HAZARD_CACHE_TAG
	li	a0,K0BASE
	move	a1,a2
	lw	a3,cacheR7kTCacheLineSize
	icacheop(a0,a1,a2,a3,Index_Store_Tag_T)

#else

#error "INVALIDATE_T_MODE value incorrect"

#endif /* INVALIDATE_T_MODE */

1:
	j	ra
	.end	cacheR7kDCFlushInvalidate


/*******************************************************************************
*
* cacheR7kICInvalidateAll - invalidate entire R7000 instruction cache
*
* RETURNS: N/A
*

* void cacheR7kICInvalidateAll (void)

*/
	.ent	cacheR7kICInvalidateAll
FUNC_LABEL(cacheR7kICInvalidateAll)
	/* run from kseg1 */
	la	t0,1f
	li	t1,KSEG2_TO_KSEG0_MASK
	and	t0,t0,t1
	or	t0,K1BASE
	j	t0
1:	
	/* Check for primary instruction cache */
	lw	a2,cacheR7kICacheSize
	blez	a2,1f

	/* Invalidate primary instruction cache */
	li	a0,K0BASE
	move	a1,a2
	lw	a3,cacheR7kICacheLineSize
	icacheop(a0,a1,a2,a3,Index_Invalidate_I)

1:
#if DESCEND_ICACHE_INVALIDATE_HIERARCHY
	/* Check for secondary cache present & ENABLED, skip if not */
	mfc0	t8,C0_CONFIG
        HAZARD_CP_READ
	and	t9,t8,CFG_SC		/* SC=0 if S-cache is present */
	bnez	t9,1f			/* branch if S-cache is not present */
	and	t9,t8,CFG_SE
	beqz	t9,1f			/* branch if S-cache is not enabled */
	lw	a2,cacheR7kSCacheSize
	blez	a2,1f

	/* Invalidate secondary cache */
	mtc0	zero,C0_TAGLO
	mtc0	zero,C0_TAGHI
	HAZARD_CACHE_TAG
	li	a0,K0BASE
	move	a1,a2
	lw	a3,cacheR7kSCacheLineSize
	icacheop(a0,a1,a2,a3,Index_Store_Tag_SD)

1:
	/* Check for T cache present & ENABLED, skip if not */
	mfc0	t8,C0_CONFIG
        HAZARD_CP_READ
	and	t9,t8,CFG_TC		/* TC=0 if T-cache is present */
	bnez	t9,1f			/* branch if T-cache is not present */
	and	t9,t8,CFG_TE
	beqz	t9,1f			/* branch if T-cache is not enabled */
	lw	a2,cacheR7kTCacheSize
	blez	a2,1f

	/* Invalidate tertiary cache */

	/*
	 * ENTIRE cache must be cleared, because all T-cache operations
	 * on the R7k are Indexed (no support for virtual addresses).
	 */

#if (INVALIDATE_T_MODE == INVALIDATE_T_MODE_FLASH)

	li	a0,K0BASE
	cache	Flash_Invalidate_T,0(a0)

#elif (INVALIDATE_T_MODE == INVALIDATE_T_MODE_PAGE)

	mtc0	zero,C0_TAGLO  /* Set invalid state in TagLo register */
	mtc0	zero,C0_TAGHI  /* Set invalid state in TagHi register */
	HAZARD_CACHE_TAG
	li	a0,K0BASE
	move	a1,a2
	lw	a3,cacheR7kTCacheLineSize
	sll	a3,PAGE_SHIFT
	icacheop(a0,a1,a2,a3,Page_Invalidate_T)

#elif (INVALIDATE_T_MODE == INVALIDATE_T_MODE_INDEX)

	mtc0	zero,C0_TAGLO  /* Set invalid state in TagLo register */
	mtc0	zero,C0_TAGHI  /* Set invalid state in TagHi register */
	HAZARD_CACHE_TAG
	li	a0,K0BASE
	move	a1,a2
	lw	a3,cacheR7kTCacheLineSize
	icacheop(a0,a1,a2,a3,Index_Store_Tag_T)

#else

#error "INVALIDATE_T_MODE value incorrect"

#endif /* INVALIDATE_T_MODE */

#endif

1:

	j	ra
	.end	cacheR7kICInvalidateAll

/*******************************************************************************
*
* cacheR7kICInvalidate - invalidate R7000 instruction cache locations
*
* RETURNS: N/A
*

* void cacheR7kICInvalidate
*     (
*     baseAddr,		/@ virtual address @/
*     byteCount		/@ number of bytes to invalidate @/
*     )

*/
	.ent	cacheR7kICInvalidate
FUNC_LABEL(cacheR7kICInvalidate)
	/* run from kseg1 */
	la	t0,1f
	li	t1,KSEG2_TO_KSEG0_MASK
	and	t0,t0,t1
	or	t0,K1BASE
	j	t0
1:	
	/* Save parameters */
	move	t0,a0
	move	t1,a1

	/* Check for primary instruction cache */
	lw	a2,cacheR7kICacheSize
	blez	a2,1f

	/* Invalidate primary instruction cache */
	lw	a3,cacheR7kICacheLineSize
	vcacheop(a0,a1,a2,a3,Hit_Invalidate_I)

1:

	j	ra
	.end	cacheR7kICInvalidate

/******************************************************************************
*
* cacheR7kPTextUpdateAll - text update for entire cache.
*
* RETURNS: N/A
*

* void cacheR7kPTextUpdateAll (void)

*/
	.ent	cacheR7kPTextUpdateAll
FUNC_LABEL(cacheR7kPTextUpdateAll)
	/* run from kseg1 */
	la	t0,1f
	li	t1,KSEG2_TO_KSEG0_MASK
	and	t0,t0,t1
	or	t0,K1BASE
	j	t0
1:	
	/* check for secondary cache present & ENABLED, skip if not */
	mfc0	t8,C0_CONFIG
        HAZARD_CP_READ
	and	t9,t8,CFG_SC		/* SC=0 if S-cache is present */
	bnez	t9,1f			/* branch if S-cache is not present */
	and	t9,t8,CFG_SE
	beqz	t9,1f			/* branch if S-cache is not enabled */
	lw	a2,cacheR7kSCacheSize
	blez	a2,1f

	/* Invalidate secondary cache */
	li	a0,K0BASE
	move	a1,a2
	lw	a3,cacheR7kSCacheLineSize
	icacheop(a0,a1,a2,a3,Index_Writeback_Inv_SD)
#ifndef MACRO_SYNC
	sync
#endif
1:	
	/* Check for primary data cache */
	lw	a2,cacheR7kDCacheSize
	blez	a2,1f

	/* Invalidate primary data cache */
	li	a0,K0BASE
	move	a1,a2
	lw	a2,cacheR7kDCacheSize
	lw	a3,cacheR7kDCacheLineSize
	icacheop(a0,a1,a2,a3,Index_Writeback_Inv_D)
#ifndef MACRO_SYNC
	sync
#endif
1:
#ifndef MACRO_SYNC
	sync
#endif
	
	/* Check for primary instruction cache */
	lw	a2,cacheR7kICacheSize
	blez	a2,1f

	/* Invalidate primary instruction cache */
	li	a0,K0BASE
	move	a1,a2
	lw	a3,cacheR7kICacheLineSize
	icacheop(a0,a1,a2,a3,Index_Invalidate_I)
#ifndef MACRO_SYNC
	sync
#endif
1:
	j	ra
	.end	cacheR7kPTextUpdateAll

/******************************************************************************
*
* cacheR7kRomTextUpdate - text update for entire cache.
*
* RETURNS: N/A
*

* void cacheR7kRomTextUpdate (void)

*/
	.ent	cacheR7kRomTextUpdate
FUNC_LABEL(cacheR7kRomTextUpdate)
	SETFRAME(cacheR7kRomTextUpdate, 0)
	subu	sp, FRAMESZ(cacheR7kRomTextUpdate)
	SW	ra, FRAMERA(cacheR7kRomTextUpdate)(sp)	/* save return address */
	sw	a0, cacheR7kICacheSize
	sw	a1, cacheR7kICacheLineSize
	sw	a2, cacheR7kDCacheSize
	sw	a3, cacheR7kDCacheLineSize
	LW	t0, FRAMEA(cacheR7kRomTextUpdate,4)(sp)
	sw	t0, cacheR7kSCacheSize
	LW	t0, FRAMEA(cacheR7kRomTextUpdate,5)(sp)
	sw	t0, cacheR7kSCacheLineSize
	LW	t0, FRAMEA(cacheR7kRomTextUpdate,6)(sp)
	sw	t0, cacheR7kTCacheSize
	LW	t0, FRAMEA(cacheR7kRomTextUpdate,7)(sp)
	sw	t0, cacheR7kTCacheLineSize
	jal	cacheR7kPTextUpdateAll
	LW	ra, FRAMERA(cacheR7kRomTextUpdate)(sp)	/* restore return address */
	addu	sp, FRAMESZ(cacheR7kRomTextUpdate)
	j	ra
	.end	cacheR7kRomTextUpdate
	
/******************************************************************************
*
* cacheR7kPTextUpdate - text update primary caches
*
* RETURNS: N/A
*

* void cacheR7kPTextUpdate
*     (
*     baseAddr,		/@ virtual address @/
*     byteCount		/@ number of bytes to invalidate @/
*     )

*/
	.ent	cacheR7kPTextUpdate
FUNC_LABEL(cacheR7kPTextUpdate)
	/* run from kseg1 */
	la	t0,1f
	li	t1,KSEG2_TO_KSEG0_MASK
	and	t0,t0,t1
	or	t0,K1BASE
	j	t0
1:	
	/* Save parameters */
	move	t0,a0
	move	t1,a1

	/* check for secondary cache present and ENABLED, skip if not */
	mfc0	t8,C0_CONFIG
        HAZARD_CP_READ
	and	t9,t8,CFG_SC		/* SC=0 if S-cache is present */
	bnez	t9,2f			/* branch if S-cache is not present */
	and	t9,t8,CFG_SE
	beqz	t9,2f			/* branch if S-cache is not enabled */
	lw	a2,cacheR7kSCacheSize
	blez	a2,2f
	
	/*
	 * Note: if secondary cache is present and enabled, a flush of
	 * secondary cache addresses automatically flushes corresponding
	 * primary data cache addresses.
	 */
	
	/* Flush-invalidate secondary data cache */
	lw	a3,cacheR7kSCacheLineSize
	vcacheop(a0,a1,a2,a3,Hit_Writeback_Inv_SD)
#ifndef MACRO_SYNC
	sync
#endif
	b	1f		/* no need to flush/invalidate primary data cache */
2:	

	/* Check for primary data cache */
	lw	a2,cacheR7kDCacheSize
	blez	a2,1f

	/* Flush-invalidate primary data cache */
	lw	a3,cacheR7kDCacheLineSize
	vcacheop(a0,a1,a2,a3,Hit_Writeback_Inv_D)
#ifndef MACRO_SYNC
	sync
#endif
1:

	/* Check for primary instruction cache */
	lw	a2,cacheR7kICacheSize
	blez	a2,1f

	/* Invalidate primary instruction cache */
	move	a0,t0
	move	a1,t1
	lw	a3,cacheR7kICacheLineSize
	vcacheop(a0,a1,a2,a3,Hit_Invalidate_I)
#ifndef MACRO_SYNC
	sync
#endif
1:
	j	ra
	.end	cacheR7kPTextUpdate


/******************************************************************************
*
* cacheR7kL2Enable - enable the L2 cache
*
* RETURNS: N/A
*
* void cacheR7kL2Enable (void)
*/
	.ent	cacheR7kL2Enable
FUNC_LABEL(cacheR7kL2Enable)
	/* run from kseg1 */
	la	t0,1f
	li	t1,KSEG2_TO_KSEG0_MASK
	and	t0,t0,t1
	or	t0,K1BASE
	j	t0
1:	
	/* Check if L2 cache already enabled */
	mfc0	t0,C0_CONFIG
        HAZARD_CP_READ
	and	t1,t0,CFG_SE
	bnez	t1,99f

	/* Check if L2 cache not present or sizes set to zero */
	and	t1,t0,CFG_SC
	bnez	t1,99f
	lw	a2,cacheR7kSCacheSize
	blez	a2,99f

	/* lock interrupts */

	mfc0	t2,C0_SR
        HAZARD_CP_READ
	li	t3,~SR_INT_ENABLE
	and	t3,t2
	mtc0	t3,C0_SR
        HAZARD_INTERRUPT

	sync

	/* invalidate L2 cache tags */
	mtc0	zero,C0_TAGLO
	mtc0	zero,C0_TAGHI
	HAZARD_CP_WRITE

	li	a0,K0BASE
	lw	a2,cacheR7kSCacheSize
	lw	a3,cacheR7kSCacheLineSize
	move	a1,a2
	icacheop(a0,a1,a2,a3,Index_Store_Tag_SD)

	/* enable the L2 cache */
	or	t1,t0,CFG_SE
	mtc0	t1,C0_CONFIG
        HAZARD_CP_WRITE

	mtc0	t2,C0_SR		/* restore interrupts */
99:	
	j	ra
	.end	cacheR7kL2Enable

/******************************************************************************
*
* cacheR7kL2Disable - Disable the L2 cache
*
* RETURNS: N/A
*
* void cacheR7kL2Disable (void)
*/
	.ent	cacheR7kL2Disable
FUNC_LABEL(cacheR7kL2Disable)
	/* run from kseg1 */
	la	t0,1f
	li	t1,KSEG2_TO_KSEG0_MASK
	and	t0,t0,t1
	or	t0,K1BASE
	j	t0
1:	
	/* Check if L2 cache already enabled */
	mfc0	t0,C0_CONFIG
        HAZARD_CP_READ
	and	t1,t0,CFG_SE
	beq	t1,zero,99f

	/* Check if L2 cache sizes set to zero */
	lw	a2,cacheR7kSCacheSize
	blez	a2,99f

	/* lock interrupts */

	mfc0	t2,C0_SR
        HAZARD_CP_READ
	li	t3,~SR_INT_ENABLE
	and	t3,t2
	mtc0	t3,C0_SR
        HAZARD_CP_WRITE

	/* Check for primary data cache */
	lw	a2,cacheR7kDCacheSize
	blez	a2,1f

	/*
	 * Invalidate primary data cache
	 * Data will be flushed to next cache layer
	 */
	lw	a3,cacheR7kDCacheLineSize
	li	a0,K0BASE
	move	a1,a2
	icacheop(a0,a1,a2,a3,Index_Writeback_Inv_D)

1:

	/* Writeback-Invalidate secondary cache */
	li	a0,K0BASE
	lw	a1,cacheR7kSCacheSize
	move	a2,a1
	lw	a3,cacheR7kSCacheLineSize
	icacheop(a0,a1,a2,a3,Index_Writeback_Inv_SD)

	/* push L2 cache completely out to memory */
#ifndef MACRO_SYNC
	sync
#endif

	/* disable the L2 cache */
	and	t1,t0,~CFG_SE
	mtc0	t1,C0_CONFIG
        HAZARD_CP_WRITE

	/* invalidate L2 cache tags */
	mtc0	zero,C0_TAGLO
	mtc0	zero,C0_TAGHI
        HAZARD_CACHE_TAG

	li	a0,K0BASE
	lw	a2,cacheR7kSCacheSize
	lw	a3,cacheR7kSCacheLineSize
	move	a1,a2
	icacheop(a0,a1,a2,a3,Index_Store_Tag_SD)

	mtc0	t2,C0_SR		/* restore interrupts */
99:	
	j	ra
	.end	cacheR7kL2Disable


/******************************************************************************
*
* cacheR7kL3Enable - enable the L3 cache
*
* RETURNS: N/A
*
* void cacheR7kL3Enable (void)
*/
	.ent	cacheR7kL3Enable
FUNC_LABEL(cacheR7kL3Enable)
	/* run from kseg1 */
	la	t0,1f
	li	t1,KSEG2_TO_KSEG0_MASK
	and	t0,t0,t1
	or	t0,K1BASE
	j	t0
1:	
	/* Check if L3 cache already enabled */
	mfc0	t0,C0_CONFIG
        HAZARD_CP_READ
	and	t1,t0,CFG_TE
	bnez	t1,99f

	/* Check if L3 cache not present or sizes set to zero */
	and	t1,t0,CFG_TC
	bnez	t1,99f
	lw	a2,cacheR7kTCacheSize
	blez	a2,99f

	/* lock interrupts */

	mfc0	t2,C0_SR
        HAZARD_CP_READ
	li	t3,~SR_INT_ENABLE
	and	t3,t2
	mtc0	t3,C0_SR
        HAZARD_INTERRUPT

	sync

	/* invalidate L3 cache tags */

#if (INVALIDATE_T_MODE == INVALIDATE_T_MODE_FLASH)

	li	a0,K0BASE
	cache	Flash_Invalidate_T,0(a0)

#elif (INVALIDATE_T_MODE == INVALIDATE_T_MODE_PAGE)

	mtc0	zero,C0_TAGLO  /* Set invalid state in TagLo register */
	mtc0	zero,C0_TAGHI  /* Set invalid state in TagHi register */
	HAZARD_CACHE_TAG
	li	a0,K0BASE
	move	a1,a2
	lw	a3,cacheR7kTCacheLineSize
	sll	a3,PAGE_SHIFT
	icacheop(a0,a1,a2,a3,Page_Invalidate_T)

#elif (INVALIDATE_T_MODE == INVALIDATE_T_MODE_INDEX)

	mtc0	zero,C0_TAGLO  /* Set invalid state in TagLo register */
	mtc0	zero,C0_TAGHI  /* Set invalid state in TagHi register */
	HAZARD_CACHE_TAG
	li	a0,K0BASE
	move	a1,a2
	lw	a3,cacheR7kTCacheLineSize
	icacheop(a0,a1,a2,a3,Index_Store_Tag_T)

#else

#error "INVALIDATE_T_MODE value incorrect"

#endif /* INVALIDATE_T_MODE */

#ifndef MACRO_SYNC
	sync
#endif

	/* enable the L3 cache */
	or	t1,t0,CFG_TE
	mtc0	t1,C0_CONFIG
        HAZARD_CP_WRITE
	sync

	mtc0	t2,C0_SR		/* restore interrupts */
99:	
	j	ra
	.end	cacheR7kL3Enable

/******************************************************************************
*
* cacheR7kL3Disable - Disable the L3 cache
*
* RETURNS: N/A
*
* void cacheR7kL2Disable (void)
*/
	.ent	cacheR7kL3Disable
FUNC_LABEL(cacheR7kL3Disable)
	/* run from kseg1 */
	la	t0,1f
	li	t1,KSEG2_TO_KSEG0_MASK
	and	t0,t0,t1
	or	t0,K1BASE
	j	t0
1:	
	/* Check if L3 cache already enabled */
	mfc0	t0,C0_CONFIG
        HAZARD_CP_READ
	and	t1,t0,CFG_TE
	beqz	t1,99f

	/* Check if L3 cache sizes set to zero */
	lw	a2,cacheR7kTCacheSize
	blez	a2,99f

	/* lock interrupts */

	mfc0	t2,C0_SR
        HAZARD_CP_READ
	li	t3,~SR_INT_ENABLE
	and	t3,t2
	mtc0	t3,C0_SR
        HAZARD_INTERRUPT

	/* Check for primary data cache */
	lw	a2,cacheR7kDCacheSize
	blez	a2,1f

	/*
	 * Invalidate primary data cache
	 * Data will be flushed to next cache layer
	 */
	lw	a3,cacheR7kDCacheLineSize
	li	a0,K0BASE
	move	a1,a2
	icacheop(a0,a1,a2,a3,Index_Writeback_Inv_D)

1:

	/* Check for secondary data cache */
	and	t1,t0,CFG_SC
	bnez	t1,1f
	and	t1,t0,CFG_SE
	beqz	t1,1f
	lw	a2,cacheR7kDCacheSize
	blez	a2,1f

	/* Writeback-Invalidate secondary cache */
	li	a0,K0BASE
	lw	a1,cacheR7kSCacheSize
	move	a2,a1
	lw	a3,cacheR7kSCacheLineSize
	icacheop(a0,a1,a2,a3,Index_Writeback_Inv_SD)

1:
	/* push L1 & L2 cache completely out to memory */
#ifndef MACRO_SYNC
	sync
#endif

	/* L3 cache is writethrough, so no writeback needed */

	/* disable the L3 cache */
	and	t1,t0,~CFG_TE
	mtc0	t1,C0_CONFIG
        HAZARD_CP_WRITE

	/* invalidate L3 cache tags */

#if (INVALIDATE_T_MODE == INVALIDATE_T_MODE_FLASH)

	li	a0,K0BASE
	cache	Flash_Invalidate_T,0(a0)

#elif (INVALIDATE_T_MODE == INVALIDATE_T_MODE_PAGE)

	mtc0	zero,C0_TAGLO  /* Set invalid state in TagLo register */
	mtc0	zero,C0_TAGHI  /* Set invalid state in TagHi register */
	HAZARD_CACHE_TAG
	li	a0,K0BASE
	move	a1,a2
	lw	a3,cacheR7kTCacheLineSize
	sll	a3,PAGE_SHIFT
	icacheop(a0,a1,a2,a3,Page_Invalidate_T)

#elif (INVALIDATE_T_MODE == INVALIDATE_T_MODE_INDEX)

	mtc0	zero,C0_TAGLO  /* Set invalid state in TagLo register */
	mtc0	zero,C0_TAGHI  /* Set invalid state in TagHi register */
	HAZARD_CACHE_TAG
	li	a0,K0BASE
	move	a1,a2
	lw	a3,cacheR7kTCacheLineSize
	icacheop(a0,a1,a2,a3,Index_Store_Tag_T)

#else

#error "INVALIDATE_T_MODE value incorrect"

#endif /* INVALIDATE_T_MODE */

	mtc0	t2,C0_SR		/* restore interrupts */
99:	
	j	ra
	.end	cacheR7kL3Disable

#ifdef IS_KSEGM
/******************************************************************************
*
* cacheR7kVirtPageFlush - flush one page of virtual addresses from caches
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
* void cacheR7kVirtPageFlush (UINT asid, void *vAddr, UINT pageSize);
*/
	.ent	cacheR7kVirtPageFlush
FUNC_LABEL(cacheR7kVirtPageFlush)
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

	mfc0	t2,C0_SR
        HAZARD_CP_READ
	li	t3,~SR_INT_ENABLE
	and	t3,t2
	mtc0	t3,C0_SR
        HAZARD_INTERRUPT

	sync

	/* change the current ASID to context where page is mapped */

	mfc0	t3, C0_TLBHI		/* read current TLBHI */
        HAZARD_CP_READ
	and	t3, 0xff		/* extract ASID field */
	beq	t3, t4, 0f		/* branch if no need to change */
	mtc0	t4, C0_TLBHI		/* Store new EntryHi  */	
        HAZARD_CP_WRITE
0:
	/* clear the virtual addresses from D- and I-caches */
	
	lw	a2,cacheR7kDCacheSize
	blez	a2,1f

	/* Flush-invalidate primary data cache */
	move	a0, t0
	move	a1, t1
	lw	a3,cacheR7kDCacheLineSize
	vcacheop(a0,a1,a2,a3,Hit_Writeback_Inv_D)
1:
	lw	a2,cacheR7kICacheSize
	blez	a2,1f	

	/* Invalidate primary instruction cache */
	move	a0,t0
	move	a1,t1
	lw	a3,cacheR7kICacheLineSize
	vcacheop(a0,a1,a2,a3,Hit_Invalidate_I)
1:	
	/* check for secondary cache */
	lw	a2,cacheR7kSCacheSize
	blez	a2,1f

	/* check for secondary cache ENABLED, skip if not */
	mfc0	t8,C0_CONFIG
        HAZARD_CP_READ
	and	t9,t8,CFG_SE
	beq	t9,zero,1f
	
	/* Flush-invalidate secondary cache */
	move	a0,t0
	move	a1,t1
	lw	a3,cacheR7kSCacheLineSize
	vcacheop(a0,a1,a2,a3,Hit_Writeback_Inv_SD)	
1:
	/* restore the original ASID */

	mtc0	t3, C0_TLBHI		/* Restore old EntryHi  */	
	mtc0	t2, C0_SR		/* restore interrupts */
        HAZARD_CP_WRITE
	
	j	ra
	.end	cacheR7kVirtPageFlush
	
/******************************************************************************
*
* cacheR7kSync - sync region of memory through all caches
*
* RETURNS: N/A
*
* void cacheR7kSync (void *vAddr, UINT pageSize);
*/
	.ent	cacheR7kSync
FUNC_LABEL(cacheR7kSync)
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

	mfc0	t2,C0_SR
        HAZARD_CP_READ
	li	t3,~SR_INT_ENABLE
	and	t3,t2
	mtc0	t3,C0_SR
        HAZARD_INTERRUPT

	/*
	 * starting with primary caches, push the memory
	 * block out completely
	 */
	sync

	lw	a2,cacheR7kICacheSize
	blez	a2,1f	

	/* Invalidate primary instruction cache */
	move	a0,t0
	move	a1,t1
	lw	a3,cacheR7kICacheLineSize
	vcacheop(a0,a1,a2,a3,Hit_Invalidate_I)
1:
	lw	a2,cacheR7kDCacheSize
	blez	a2,1f

	/* Flush-invalidate primary data cache */
	move	a0, t0
	move	a1, t1
	lw	a3,cacheR7kDCacheLineSize
	vcacheop(a0,a1,a2,a3,Hit_Writeback_Inv_D)
1:	
	lw	a2,cacheR7kSCacheSize
	blez	a2,1f

	/* check for secondary cache ENABLED, skip if not */
	mfc0	t8,C0_CONFIG
        HAZARD_CP_READ
	and	t9,t8,CFG_SE
	beq	t9,zero,1f

	/* Flush-invalidate secondary cache */
	move	a0,t0
	move	a1,t1
	lw	a3,cacheR7kSCacheLineSize
	vcacheop(a0,a1,a2,a3,Hit_Writeback_Inv_SD)	
1:
	/* Check for tertiary cache */
	lw	a2,cacheR7kTCacheSize
	blez	a2,1f

	/* Invalidate tertiary cache */
	mtc0	zero,C0_TAGLO  /* Set invalid state in TagLo register */
	mtc0	zero,C0_TAGHI  /* Set invalid state in TagHi register */
	HAZARD_CACHE_TAG
	move	a0,t0
	move	a1,t1
	lw	a3,cacheR7kTCacheLineSize
	icacheop(a0,a1,a2,a3,Index_Store_Tag_T)	
1:
	mtc0	t2, C0_SR		/* restore interrupts */
	
	j	ra
	.end	cacheR7kSync
#endif

