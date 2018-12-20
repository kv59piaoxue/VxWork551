/* cacheR4kALib.s - MIPS R4000 cache management assembly routines */

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
01q,18jan02,agf  add explicit align directive to data section(s)
01p,06nov01,sru  reorder icache reset cache ops
01p,02aug01,mem  Diab integration
01o,16jul01,ros  add CofE comment
01n,09jul01,sru  Clear branch history buffer during IC invalidation.
01m,12feb01,sru  Adding HAZARD macros
01l,22nov00,mem  Added cacheR4kRomTextUpdate
01k,22jun00,dra  Added cache sync support, updated virt addr flushing.
01j,16jun00,dra  update for idts134
01i,14jun00,dra  generalize the mmuMipsUnMap flush of virtual page addresses
                 to all Mips architectures
01h,27mar00,dra  Added missing global decls.
01g,22mar00,dra  Moved cache size variables here.
01f,28feb00,dra  Add GTEXT, GDATA, FUNC macros to support omfDll & loader
01e,31jan00,dra  Suppress compiler warnings.
01d,31dec96,kkk  allow cache enable/disable for R4650.
01c,18apr96,rml  guarantee reset of cache policy reg for 4650
01b,24jan94,cd   Corrected cache initialisation for Orion/R4600 
01a,01oct93,cd   created.
*/

/*
DESCRIPTION
This library contains MIPS R4000 cache set-up and invalidation routines
written in assembly language.  The R4000 utilizes a variable-size
instruction and data cache that operates in write-back mode.  Cache
line size also varies. See also the manual entry for cacheR4kLib.

For general information about caching, see the manual entry for cacheLib.

INCLUDE FILES: cacheLib.h

SEE ALSO: cacheR4kLib, cacheLib
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

	.globl GTEXT(cacheR4kReset)		/* low level cache init */
	.globl GTEXT(cacheR4kRomTextUpdate)	/* cache-text-update */
	.globl GTEXT(cacheR4kDCFlushInvalidateAll) /* flush entire data cache */
	.globl GTEXT(cacheR4kDCFlushInvalidate)/* flush data cache locations */
	.globl GTEXT(cacheR4kDCInvalidateAll)	/* invalidate entire d cache */
	.globl GTEXT(cacheR4kDCInvalidate)	/* invalidate d cache locations */
	.globl GTEXT(cacheR4kICInvalidateAll)	/* invalidate i cache locations */
	.globl GTEXT(cacheR4kICInvalidate)	/* invalidate i cache locations */

	.globl GDATA(cacheR4kDCacheSize)	/* data cache size */
	.globl GDATA(cacheR4kICacheSize)	/* inst. cache size */
	.globl GDATA(cacheR4kSCacheSize)	/* secondary cache size */

	.globl GDATA(cacheR4kDCacheLineSize)    /* data cache line size */
	.globl GDATA(cacheR4kICacheLineSize)    /* inst. cache line size */
	.globl GDATA(cacheR4kSCacheLineSize)    /* secondary cache line size */
	.globl GTEXT(cacheR4kVirtPageFlush)	/* flush cache on MMU page unmap */
	.globl GTEXT(cacheR4kSync)		/* cache sync operation */
	
	.data
	.align	4
cacheR4kICacheSize:
	.word	0
cacheR4kDCacheSize:
	.word	0
cacheR4kSCacheSize:
	.word	0
cacheR4kICacheLineSize:
	.word	0
cacheR4kDCacheLineSize:
	.word	0
cacheR4kSCacheLineSize:
	.word	0
	.text
	.set	reorder

/*******************************************************************************
*
* cacheR4kReset - low level initialisation of the R4000 primary caches
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

* void cacheR4kReset (initMem)

*/
	.ent	cacheR4kReset
FUNC_LABEL(cacheR4kReset)
	
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
	.end	cacheR4kReset

/******************************************************************************
*
* cacheR4kRomTextUpdate - cache text update like functionality from the bootApp
*
*	a0	i-cache size
*	a1	i-cache line size
*	a2	d-cache size
*	a3	d-cache line size
*
* RETURNS: N/A
*

* void cacheR4kRomTextUpdate ()

*/
	.ent	cacheR4kRomTextUpdate
FUNC_LABEL(cacheR4kRomTextUpdate)
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
	.end	cacheR4kRomTextUpdate


/*******************************************************************************
*
* cacheR4kDCFlushInvalidateAll - flush entire R4000 data cache
*
* RETURNS: N/A
*

* void cacheR4kDCFlushInvalidateAll (void)

*/
	.ent	cacheR4kDCFlushInvalidateAll
FUNC_LABEL(cacheR4kDCFlushInvalidateAll)
	/* secondary cacheops do all the work if present */
	lw	a2,cacheR4kSCacheSize
	blez	a2,1f
	lw	a3,cacheR4kSCacheLineSize
	li	a0,K0BASE
	move	a1,a2
	icacheop(a0,a1,a2,a3,Index_Writeback_Inv_SD)
	b	99f

1:	lw	a2,cacheR4kDCacheSize
	blez	a2, 99f
	lw	a3,cacheR4kDCacheLineSize
	li	a0,K0BASE
	move	a1,a2
	icacheop(a0,a1,a2,a3,Index_Writeback_Inv_D)

99:	j	ra

	.end	cacheR4kDCFlushInvalidateAll

/*******************************************************************************
*
* cacheR4kDCFlush - flush R4000 data cache locations
*
* RETURNS: N/A
*

* void cacheR4kDCFlushInvalidate
*     (
*     baseAddr,		/@ virtual address @/
*     byteCount		/@ number of bytes to invalidate @/
*     )

*/
	.ent	cacheR4kDCFlushInvalidate
FUNC_LABEL(cacheR4kDCFlushInvalidate)
	/* secondary cacheops do all the work if present */
	lw	a2,cacheR4kSCacheSize
	blez	a2,1f
	lw	a3,cacheR4kSCacheLineSize
	move	a1,a2
	vcacheop(a0,a1,a2,a3,Hit_Writeback_Inv_SD)
	b	99f

1:	lw	a2,cacheR4kDCacheSize
	blez	a2, 99f
	lw	a3,cacheR4kDCacheLineSize
	vcacheop(a0,a1,a2,a3,Hit_Writeback_Inv_D)
99:	j	ra
	.end	cacheR4kDCFlushInvalidate


/*******************************************************************************
*
* cacheR4kDCInvalidateAll - invalidate entire R4000 data cache
*
* RETURNS: N/A
*

* void cacheR4kDCInvalidateAll (void)

*/
	.ent	cacheR4kDCInvalidateAll
FUNC_LABEL(cacheR4kDCInvalidateAll)
	/* secondary cacheops do all the work if present */
	lw	a2,cacheR4kSCacheSize
	blez	a2,1f
	lw	a3,cacheR4kSCacheLineSize
	li	a0,K0BASE
	move	a1,a2
	icacheop(a0,a1,a2,a3,Index_Writeback_Inv_SD)
	b	99f

1:	lw	a2,cacheR4kDCacheSize
	blez	a2, 99f
	lw	a3,cacheR4kDCacheLineSize
	li	a0,K0BASE
	move	a1,a2
	icacheop(a0,a1,a2,a3,Index_Writeback_Inv_D)

99:	j	ra

	.end	cacheR4kDCInvalidateAll

/*******************************************************************************
*
* cacheR4kDCInvalidate - invalidate R4000 data cache locations
*
* RETURNS: N/A
*

* void cacheR4kDCInvalidate
*     (
*     baseAddr,		/@ virtual address @/
*     byteCount		/@ number of bytes to invalidate @/
*     )

*/
	.ent	cacheR4kDCInvalidate
FUNC_LABEL(cacheR4kDCInvalidate)
	/* secondary cacheops do all the work if present */
	lw	a2,cacheR4kSCacheSize
	blez	a2,1f
	lw	a3,cacheR4kSCacheLineSize
	move	a1,a2
	vcacheop(a0,a1,a2,a3,Hit_Writeback_Inv_SD)
	b	99f

1:	lw	a2,cacheR4kDCacheSize
	blez	a2, 99f
	lw	a3,cacheR4kDCacheLineSize
	vcacheop(a0,a1,a2,a3,Hit_Writeback_Inv_D)
99:	j	ra
	.end	cacheR4kDCInvalidate

/*******************************************************************************
*
* cacheR4kICInvalidateAll - invalidate entire R4000 instruction cache
*
* RETURNS: N/A
*

* void cacheR4kICInvalidateAll (void)

*/
	.ent	cacheR4kICInvalidateAll
FUNC_LABEL(cacheR4kICInvalidateAll)
	/* secondary cacheops do all the work if present */
	lw	a2,cacheR4kSCacheSize
	blez	a2,1f
	lw	a3,cacheR4kSCacheLineSize
	li	a0,K0BASE
	move	a1,a2
	icacheop(a0,a1,a2,a3,Index_Writeback_Inv_SD)
	b	98f

1:	lw	a2,cacheR4kICacheSize
	blez	a2,99f
	lw	a3,cacheR4kICacheLineSize
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

	.end	cacheR4kICInvalidateAll

/*******************************************************************************
*
* cacheR4kICInvalidate - invalidate R4000 data cache locations
*
* RETURNS: N/A
*

* void cacheR4kICInvalidate
*     (
*     baseAddr,		/@ virtual address @/
*     byteCount		/@ number of bytes to invalidate @/
*     )

*/
	.ent	cacheR4kICInvalidate
FUNC_LABEL(cacheR4kICInvalidate)
	/* secondary cacheops do all the work if present */
	lw	a2,cacheR4kSCacheSize
	blez	a2,1f
	lw	a3,cacheR4kSCacheLineSize
	move	a1,a2
	vcacheop(a0,a1,a2,a3,Hit_Writeback_Inv_SD)
	b	98f

1:	lw	a2,cacheR4kICacheSize
	blez	a2, 99f
	lw	a3,cacheR4kICacheLineSize
	vcacheop(a0,a1,a2,a3,Hit_Invalidate_I)
	
98:	/* touch TLBHI register to clear the branch history buffer. This is */
	/* required for (at a minimum) the NEC Vr4122. */
	
	mfc0	a2, C0_TLBHI
	HAZARD_CP_READ
	mtc0	a2, C0_TLBHI
	HAZARD_TLB

99:	j	ra
	.end	cacheR4kICInvalidate

/******************************************************************************
*
* cacheR4kVirtPageFlush - flush one page of virtual addresses from caches
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
* void cacheR4kVirtPageFlush (UINT asid, void *vAddr, UINT pageSize);
*/
	.ent	cacheR4kVirtPageFlush
FUNC_LABEL(cacheR4kVirtPageFlush)
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
	
	lw	a2,cacheR4kDCacheSize
	blez	a2,1f

	/* Flush-invalidate primary data cache */
	move	a0, t0
	move	a1, t1
	lw	a3,cacheR4kDCacheLineSize
	vcacheop(a0,a1,a2,a3,Hit_Writeback_Inv_D)
1:
	lw	a2,cacheR4kICacheSize
	blez	a2,1f	

	/* Invalidate primary instruction cache */
	move	a0,t0
	move	a1,t1
	lw	a3,cacheR4kICacheLineSize
	vcacheop(a0,a1,a2,a3,Hit_Invalidate_I)
1:	
	/* restore the original ASID */

	mtc0	t3, C0_TLBHI		/* Restore old EntryHi  */	
	HAZARD_TLB

	mtc0	t2, C0_SR		/* restore interrupts */
	
	j	ra
	.end	cacheR4kVirtPageFlush

/******************************************************************************
*
* cacheR4kSync - sync region of memory through all caches
*
* RETURNS: N/A
*
* void cacheR4kSync (void *vAddr, UINT pageSize);
*/
	.ent	cacheR4kSync
FUNC_LABEL(cacheR4kSync)
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

	lw	a2,cacheR4kICacheSize
	blez	a2,1f	

	/* Invalidate primary instruction cache */
	move	a0,t0
	move	a1,t1
	lw	a3,cacheR4kICacheLineSize
	vcacheop(a0,a1,a2,a3,Hit_Invalidate_I)
1:
	lw	a2,cacheR4kDCacheSize
	blez	a2,1f

	/* Flush-invalidate primary data cache */
	move	a0, t0
	move	a1, t1
	lw	a3,cacheR4kDCacheLineSize
	vcacheop(a0,a1,a2,a3,Hit_Writeback_Inv_D)
1:	
	lw	a2,cacheR4kSCacheSize
	blez	a2,1f

	/* Invalidate secondary cache */
	mtc0	zero,C0_TAGLO
	mtc0	zero,C0_TAGHI
	HAZARD_CACHE_TAG

	move	a0,t0
	move	a1,t1
	lw	a3,cacheR4kSCacheLineSize
	icacheop(a0,a1,a2,a3,Index_Store_Tag_SD)
1:
	mtc0	t2, C0_SR		/* restore interrupts */
	
	j	ra
	.end	cacheR4kSync
