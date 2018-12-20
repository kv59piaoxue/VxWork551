/* cacheR10kALib.s - MIPS R10000 cache management assembly routines */

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
01h,18jan02,agf  add explicit align directive to data section(s)
01g,16nov01,tlc  Reorder icache loops in reset routine.
01g,02aug01,mem  Diab integration
01f,16jul01,ros  add CoE comment
01e,12feb01,tlc  Perform HAZARD review.
01d,03jan01,tlc  Backported from Cirrus.
01c,19jun00,dra  work around 5432 branch bug
01b,24feb00,dra  added defines to aid building under standard product T2.
01a,19jul99,dra  Created this file based in cacheR4kALib.s, 01j.
*/

/*
DESCRIPTION
This library contains MIPS R10000 cache setup, size configuration,
flush and invalidation routines. The MIPS R10000 cache organization 
includes: 1) primary data cache; 2) primary instruction cache; 
3) off-chip secondary cache; The primary caches are 2-way set associative.  
The secondary cache is directly mapped.

For general information about caching, see the manual entry for cacheLib.

INCLUDE FILES: cacheLib.h

SEE ALSO: cacheR10kLib, cacheLib
*/
	
#define _ASMLANGUAGE
#include "vxWorks.h"
#include "asm.h"

	/* defines */
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
	cache	op1,0(a0)	; \
	HAZARD_CACHE
#define doop2(op1, op2) \
	cache	op1,0(a0)	; \
	HAZARD_CACHE		; \
	cache	op2,0(a0)	; \
	HAZARD_CACHE

/* Loop operation for two-way set */ 
/* associative index operations   */
#define doop10(op1) \
	cache	op1,0(a0)	;\
	HAZARD_CACHE		;\
	cache	op1,1(a0)	;\
	HAZARD_CACHE

/* specials for cache initialisation            */
/* All cache initialization is done by index ops*/
/* Two-way set associativity is considered here */
#define doop1lw(op1) \
	lw	zero,0(a0)
#define doop1lw1(op1) \
	cache	op1,0(a0)  ; \
	HAZARD_CACHE	   ; \
	cache   op1,1(a0)  ; \
	lw	zero,0(a0) ; \
	cache	op1,0(a0)  ; \
	HAZARD_CACHE	   ; \
	cache	op1,1(a0)  ; \
	HAZARD_CACHE
#define doop121(op1,op2) \
	cache	op1,0(a0)  ; \
	HAZARD_CACHE	   ; \
	cache	op1,1(a0)  ; \
	HAZARD_CACHE	   ; \
	cache	op2,0(a0)  ; \
	HAZARD_CACHE	   ; \
	cache	op2,1(a0)  ; \
	HAZARD_CACHE	   ; \
	cache	op1,0(a0)  ; \
	HAZARD_CACHE	   ; \
	cache	op1,1(a0)  ; \
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

/* Cache macro for two-way set associative cache index operations */
#define i10cacheopn(kva, n, cacheSize, cacheLineSize, tag, ops) \
	srl	cacheSize,1	; \
	_mincache(n, cacheSize)	; \
	blez	n,11f		; \
	addu	n,kva		; \
	_align(kva, n, cacheLineSize); \
	_oploopn(kva, n, cacheLineSize, tag, ops); \
11:
	
#define vcacheop(kva, n, cacheSize, cacheLineSize, op) \
	vcacheopn(kva, n, cacheSize, cacheLineSize, 1, (op))

#define icacheop(kva, n, cacheSize, cacheLineSize, op) \
	icacheopn(kva, n, cacheSize, cacheLineSize, 1, (op))

#define i10cacheop(kva, n, cacheSize, cacheLineSize, op) \
	i10cacheopn(kva, n, cacheSize, cacheLineSize, 10, (op))

	.text

	.globl  GTEXT(cacheR10kReset)		/* low level cache init    */
	.globl	GTEXT(cacheR10kRomTextUpdate)	/* cache-text-update */
	.globl	GTEXT(cacheR10kDCFlushInvalidateAll) /* flush entire d-cache    */
	.globl	GTEXT(cacheR10kDCFlushInvalidate) /* flush d-cache locations */
	.globl	GTEXT(cacheR10kICInvalidateAll)	/* inval i-cache locations */
	.globl	GTEXT(cacheR10kICInvalidate)	/* inval i-cache locations */
	.globl	GTEXT(cacheR10kSync)		/* cache sync */
	.globl	GTEXT(cacheR10kVirtPageFlush)	/* flush cache on MMU page unmap */
	.globl	GTEXT(cacheR10kDCLock)		/* data cache lock */
	.globl	GTEXT(cacheR10kICLock)		/* inst. cache lock */

	.globl	GDATA(cacheR10kDCacheSize)	/* d-cache size		*/
	.globl	GDATA(cacheR10kICacheSize)	/* i-cache size		*/
	.globl	GDATA(cacheR10kSCacheSize)	/* secondary cache size	*/

	.globl	GDATA(cacheR10kDCacheLineSize)	/* d-cache line size	*/
	.globl	GDATA(cacheR10kICacheLineSize)	/* i-cache line size	*/
	.globl	GDATA(cacheR10kSCacheLineSize)	/* s-cache line size	*/

	.data
	.align	4
cacheR10kICacheSize:
	.word	0
cacheR10kDCacheSize:
	.word	0
cacheR10kSCacheSize:
	.word	0
cacheR10kICacheLineSize:
	.word	0
cacheR10kDCacheLineSize:
	.word	0
cacheR10kSCacheLineSize:
	.word	0
	
	.text
	.set	reorder

/******************************************************************************
*
* cacheR10kReset - low level initialisation of the R10000 primary caches
*
* This routine initialises the R10000 primary caches to ensure that they
* have good parity.  It must be called by the ROM before any cached locations
* are used to prevent the possibility of data with bad parity being written to
* memory.
*
* RETURNS: N/A
*

* void cacheR10kReset (initMem)

*/
	.ent	cacheR10kReset
FUNC_LABEL(cacheR10kReset)
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

	/* 1: initialize icache tags */
	li	a0,K0BASE
	move	a2,t0		# icacheSize
	move	a3,t1		# icacheLineSize
	move	a1,a2
	i10cacheop(a0,a1,a2,a3,Index_Store_Tag_I)

	/* 2: fill icache */
	li	a0,K0BASE
	move	a2,t0		# icacheSize
	move	a3,t1		# icacheLineSize
	move	a1,a2
	icacheop(a0,a1,a2,a3,Fill_I)

	/* 3: clear icache tags */
	li	a0,K0BASE
	move	a2,t0		# icacheSize
	move	a3,t1		# icacheLineSize
	move	a1,a2
	i10cacheop(a0,a1,a2,a3,Index_Store_Tag_I)

	/* 1: initialize dcache tags */
	li	a0,K0BASE
	move	a2,t2		# dcacheSize
	move	a3,t3		# dcacheLineSize
	move	a1,a2
	i10cacheop(a0,a1,a2,a3,Index_Store_Tag_D)

	/* 1: fill dcache */
	li	a0,K0BASE
	move	a2,t2		# dcacheSize
	move	a3,t3		# dcacheLineSize
	move	a1,a2
	icacheopn(a0,a1,a2,a3,1lw,(dummy))

	/* 1: clear dcache tags */
	li	a0,K0BASE
	move	a2,t2		# dcacheSize
	move	a3,t3		# dcacheLineSize
	move	a1,a2
	i10cacheop(a0,a1,a2,a3,Index_Store_Tag_D)
	
	/* initialize secondary cache if present */
	blez	t4,1f
	
	li	a0,K0BASE
	move	a2,t4
	move	a3,t5
	move	a1,a2
	icacheopn(a0,a1,a2,a3,121,(Index_Store_Tag_SD, Create_Dirty_Exc_SD))
1:
	mtc0	v0,C0_SR
	HAZARD_CP_WRITE
	j	ra
	.end	cacheR10kReset


/******************************************************************************
*
* cacheR10kRomTextUpdate - cache text update like functionality from the bootApp
*
*	a0	i-cache size
*	a1	i-cache line size
*	a2	d-cache size
*	a3	d-cache line size
*
* RETURNS: N/A
*

* void cacheR10kRomTextUpdate ()

*/
	.ent	cacheR10kRomTextUpdate
FUNC_LABEL(cacheR10kRomTextUpdate)
	/* Save I-cache parameters */
	move	t0,a0
	move	t1,a1

	/* Check for primary data cache */
	blez	a2,99f

	/* Flush-invalidate primary data cache */
	li	a0,K0BASE
	move	a1,a2
	i10cacheop(a0,a1,a2,a3,Index_Writeback_Inv_D)
99:
	/* replace I-cache parameters */
	move	a2,t0
	move	a3,t1
	
	/* Check for primary instruction cache */
	blez	a0,99f
	
	/* Invalidate primary instruction cache */
	li	a0,K0BASE
	move	a1,a2
	i10cacheop(a0,a1,a2,a3,Index_Invalidate_I)
99:
	j	ra
	.end	cacheR10kRomTextUpdate


/******************************************************************************
*
* cacheR10kDCFlushInvalidateAll - flush entire R10000 data cache
*
* RETURNS: N/A
*

* void cacheR4kDCFlushInvalidateAll (void)

*/
	.ent	cacheR10kDCFlushInvalidateAll
FUNC_LABEL(cacheR10kDCFlushInvalidateAll)
	/* secondary cacheops do all the work if present */
	lw	a2,cacheR10kSCacheSize
	blez	a2,1f
	lw	a3,cacheR10kSCacheLineSize
	li	a0,K0BASE
	move	a1,a2
	icacheop(a0,a1,a2,a3,Index_Writeback_Inv_SD)
	b	99f

1:	lw	a2,cacheR10kDCacheSize
	lw	a3,cacheR10kDCacheLineSize
	li	a0,K0BASE
	move	a1,a2
	i10cacheop(a0,a1,a2,a3,Index_Writeback_Inv_D)

99:	j	ra

	.end	cacheR10kDCFlushInvalidateAll

	
/******************************************************************************
*
* cacheR10kDCFlushInvalidate - flush R10000 data cache locations
*
* RETURNS: N/A
*

* void cacheR10kDCFlushInvalidate
*     (
*     baseAddr,		/@ virtual address @/
*     byteCount		/@ number of bytes to invalidate @/
*     )

*/
	.ent	cacheR10kDCFlushInvalidate
FUNC_LABEL(cacheR10kDCFlushInvalidate)
	/* secondary cacheops do all the work if present */
	lw	a2,cacheR10kSCacheSize
	blez	a2,1f
	lw	a3,cacheR10kSCacheLineSize
	move	a1,a2
	vcacheop(a0,a1,a2,a3,Hit_Writeback_Inv_SD)
	b	99f

1:	lw	a2,cacheR10kDCacheSize
	lw	a3,cacheR10kDCacheLineSize
	vcacheop(a0,a1,a2,a3,Hit_Writeback_Inv_D)

99:	j	ra
	.end	cacheR10kDCFlushInvalidate


/******************************************************************************
*
* cacheR10kICInvalidateAll - invalidate entire R10000 instruction cache
*
* RETURNS: N/A
*

* void cacheR10kICInvalidateAll (void)

*/
	.ent	cacheR10kICInvalidateAll
FUNC_LABEL(cacheR10kICInvalidateAll)
	/* secondary cacheops do all the work if present */
	lw	a2,cacheR10kSCacheSize
	blez	a2,1f
	lw	a3,cacheR10kSCacheLineSize
	li	a0,K0BASE
	move	a1,a2
	icacheop(a0,a1,a2,a3,Index_Writeback_Inv_SD)
	b	99f

1:	lw	a2,cacheR10kICacheSize
	blez	a2,99f
	lw	a3,cacheR10kICacheLineSize
	li	a0,K0BASE
	move	a1,a2
	i10cacheop(a0,a1,a2,a3,Index_Invalidate_I)

99:	j	ra

	.end	cacheR10kICInvalidateAll


/******************************************************************************
*
* cacheR10kICInvalidate - invalidate R10000 instruction cache locations
*
* RETURNS: N/A
*

* void cacheR10kICInvalidate
*     (
*     baseAddr,		/@ virtual address @/
*     byteCount		/@ number of bytes to invalidate @/
*     )

*/
	.ent	cacheR10kICInvalidate
FUNC_LABEL(cacheR10kICInvalidate)
	/* secondary cacheops do all the work if present */
	lw	a2,cacheR10kSCacheSize
	blez	a2,1f
	lw	a3,cacheR10kSCacheLineSize
	move	a1,a2
	vcacheop(a0,a1,a2,a3,Hit_Writeback_Inv_SD)
	b	99f

1:	lw	a2,cacheR10kICacheSize
	lw	a3,cacheR10kICacheLineSize
	vcacheop(a0,a1,a2,a3,Hit_Invalidate_I)

99:	j	ra
	.end	cacheR10kICInvalidate
	
/******************************************************************************
*
* cacheR10kDCLock - lock R10000 data cache locations
*
* Not all architectures support this operation.
*
* RETURNS: N/A
*

* void cacheR10kDCLock
*     (
*     baseAddr,		/@ virtual address @/
*     byteCount		/@ number of bytes to invalidate @/
*     )

*/
	.ent	cacheR10kDCLock
FUNC_LABEL(cacheR10kDCLock)
	lw	a2,cacheR10kDCacheSize
	lw	a3,cacheR10kDCacheLineSize
	vcacheop(a0,a1,a2,a3,Lock_D)
	j	ra
	.end	cacheR10kDCLock

/******************************************************************************
*
* cacheR10kICLock - lock R10000 data cache locations
*
* Not all architectures support this operation.
*
* RETURNS: N/A
*

* void cacheR10kICLock
*     (
*     baseAddr,		/@ virtual address @/
*     byteCount		/@ number of bytes to invalidate @/
*     )

*/
	.ent	cacheR10kICLock
FUNC_LABEL(cacheR10kICLock)
	lw	a2,cacheR10kICacheSize
	lw	a3,cacheR10kICacheLineSize
	vcacheop(a0,a1,a2,a3,Lock_I)
	j	ra
	.end	cacheR10kICLock

/******************************************************************************
*
* cacheR10kVirtPageFlush - flush one page of virtual addresses from caches
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
* void cacheR10kVirtPageFlush (UINT asid, void *vAddr, UINT pageSize);
*/
	.ent	cacheR10kVirtPageFlush
FUNC_LABEL(cacheR10kVirtPageFlush)
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
	and	t3, 0xff		/* extract ASID field */
	beq	t3, t4, 0f		/* branch if no need to change */
	mtc0	t4, C0_TLBHI		/* Store new EntryHi  */	
	HAZARD_TLB

0:
	/* clear the virtual addresses from D- and I-caches */
	
	lw	a2,cacheR10kDCacheSize
	blez	a2,1f

	/* Flush-invalidate primary data cache */
	move	a0, t0
	move	a1, t1
	lw	a3,cacheR10kDCacheLineSize
	vcacheop(a0,a1,a2,a3,Hit_Writeback_Inv_D)
1:
	lw	a2,cacheR10kICacheSize
	blez	a2,1f	

	/* Invalidate primary instruction cache */
	move	a0,t0
	move	a1,t1
	lw	a3,cacheR10kICacheLineSize
	vcacheop(a0,a1,a2,a3,Hit_Invalidate_I)
1:	
	/* restore the original ASID */

	mtc0	t3, C0_TLBHI		/* Restore old EntryHi  */	
	HAZARD_TLB

	mtc0	t2, C0_SR		/* restore interrupts */
	
	j	ra
	.end	cacheR10kVirtPageFlush

	
/******************************************************************************
*
* cacheR10kSync - sync region of memory through all caches
*
* RETURNS: N/A
*
* void cacheR10kSync (void *vAddr, UINT pageSize);
*/
	.ent	cacheR10kSync
FUNC_LABEL(cacheR10kSync)
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

	lw	a2,cacheR10kICacheSize
	blez	a2,1f	

	/* Invalidate primary instruction cache */
	move	a0,t0
	move	a1,t1
	lw	a3,cacheR10kICacheLineSize
	vcacheop(a0,a1,a2,a3,Hit_Invalidate_I)
1:
	lw	a2,cacheR10kDCacheSize
	blez	a2,1f

	/* Flush-invalidate primary data cache */
	move	a0, t0
	move	a1, t1
	lw	a3,cacheR10kDCacheLineSize
	vcacheop(a0,a1,a2,a3,Hit_Writeback_Inv_D)
1:	
	lw	a2,cacheR10kSCacheSize
	blez	a2,1f

	/* Flush-invalidate secondary cache */
	move	a0,t0
	move	a1,t1
	lw	a3,cacheR10kSCacheLineSize
	vcacheop(a0,a1,a2,a3,Hit_Writeback_Inv_SD)	
1:
	mtc0	t2, C0_SR		/* restore interrupts */
	
	j	ra
	.end	cacheR10kSync
