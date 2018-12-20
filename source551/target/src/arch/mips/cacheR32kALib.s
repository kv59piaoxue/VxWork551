/* cacheR32kALib.s - IDT RC32364 cache management assembly routines */

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
01e,18jan02,agf  add explicit align directive to data section(s)
01d,16nov01,tlc  Reorder icache loops in reset routine.
01d,02aug01,mem  Diab integration
01c,16jul01,ros  add CofE comment
01b,12jun01,mem  Remove CPU tests.
01a,28sep98,hsm  Created from cacheR4kAlib.s
*/

/*
DESCRIPTION
This library contains IDT RC32364 cache set-up and invalidation routines
written in assembly language.
See also the manual entry for cacheR32kLib.

For general information about caching, see the manual entry for cacheLib.

INCLUDE FILES: cacheLib.h

SEE ALSO: cacheR32kLib, cacheLib
*/

#define _ASMLANGUAGE
#include "vxWorks.h"
#include "asm.h"

	/* globals */

	.data
	.align	4
cacheICacheSize:
	.word	-1			/* instruction cache size */
cacheDCacheSize:
	.word	-1			/* data cache size */
cacheICacheLineSize:
	.word	-1			/* instruction cache line size */
cacheDCacheLineSize:
	.word	-1			/* data cache line size */

	.text
	.set	reorder

	.globl	cacheR32kSizes		/* set cache sizes */
	.globl  cacheR32kReset		/* low level cache initialisation */
	.globl  cacheR32kEnableCaches	/* enable primary caches */
	.globl  cacheR32kDisableCaches	/* disable primary caches */
	.globl	cacheR32kDCFlushInvalidateAll /* flush entire data cache */
	.globl	cacheR32kDCFlushInvalidate/* flush data cache locations */
	.globl	cacheR32kDCInvalidateAll	/* invalidate entire data cache */
	.globl	cacheR32kDCInvalidate	/* invalidate data cache locations */
	.globl	cacheR32kICInvalidateAll	/* invalidate inst. cache locations */
	.globl	cacheR32kICInvalidate	/* invalidate inst. cache locations */

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
	cache	op1,0(a0)
#define doop2(op1, op2) \
	cache	op1,0(a0) ;		\
	nop ;				\
	cache	op2,0(a0)

/* specials for cache initialisation */
#define doop1lw(op1) \
	lw	zero,0(a0)
#define doop1lw1(op1) \
	cache	op1,0(a0) ;		\
	lw	zero,0(a0) ;		\
	cache	op1,0(a0)
#define doop121(op1,op2) \
	cache	op1,0(a0) ;		\
	nop;				\
	cache	op2,0(a0) ;		\
	nop;				\
	cache	op1,0(a0)

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

/*******************************************************************************
*
* _cacheR32kSizes - return the sizes of the RC32364 caches
*
* NOMANUAL
*/

	.ent	_cacheR32kSizes
_cacheR32kSizes:
	/* the config register contains the primary cache sizes */
	mfc0	t0,C0_CONFIG

	/* calculate the primary instruction cache size */
	and	t1,t0,CFG_ICMASK
	srl	t1,CFG_ICSHIFT
	li	t2,0x200
	sll	t2,t1			/* 2^(9+IC) */

	/* set the primary instruction cache line size */
	li	t4,32
	and	t1,t0,CFG_IB
	bnez	t1,1f
	li	t4,16
1:	

	/* calculate the primary data cache size */
	and	t1,t0,CFG_DCMASK
	srl	t1,CFG_DCSHIFT
	li	t3,0x200
	sll	t3,t1			/* 2^(9+DC) */

	/* set the primary data cache line size */
	li	t5,32
	and	t1,t0,CFG_DB
	bnez	t1,1f
	li	t5,16
1:	


	j	ra
	.end	_cacheR32kSizes


/*******************************************************************************
*
* cacheR32kSizes - store the sizes of the RC32364 caches
*
* RETURNS: N/A

* void cacheR32kSizes (void)

*/
	.ent	cacheR32kSizes
cacheR32kSizes:
	move	v0,ra
	bal	_cacheR32kSizes
	move	ra,v0

	sw	t2,cacheICacheSize
	sw	t3,cacheDCacheSize
	sw	t4,cacheICacheLineSize
	sw	t5,cacheDCacheLineSize
	j	ra
	.end	cacheR32kSizes


/*******************************************************************************
*
* cacheR32kReset - low level initialisation of the RC32364 primary caches
*
* This routine initialises the RC32364 primary caches to ensure that they
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

* void cacheR32kReset (initMem)

*/
	.ent	cacheR32kReset
cacheR32kReset:
	/*
 	 * First work out the sizes
	 */
	move	v0,ra
	bal	_cacheR32kSizes
	move	ra,v0
	
	beqz	a0,resetcache

	/*
	 * Calculate the maximum cache size
	 * max(t2,t3,t6)
	 */
	move	v0,t2
	bge	v0,t3,1f
	move	v0,t3
1:	blez	v0,resetcache

	/* now clear that much memory starting from zero */
	li	a0,K1BASE
	addu	a1,a0,v0

2:	sw	zero,0(a0)
	sw	zero,4(a0)
	sw	zero,8(a0)
	sw	zero,12(a0)
	sw	zero,16(a0)
	sw	zero,20(a0)
	sw	zero,24(a0)
	sw	zero,28(a0)
	addu	a0,32
	bltu	a0,a1,2b
	
	/* disable all i/u and cache exceptions */
resetcache:
	mfc0	v0,C0_SR
	and	v1,v0,SR_BEV
	or	v1,SR_DE
	mtc0	v1,C0_SR

	/* set invalid tag */
	mtc0	zero,C0_TAGLO

	/*
	 * The caches are probably in an indeterminate state,
	 * so we force good parity into them by doing an
	 * invalidate, load/fill, invalidate for each line.
	 */

	/* initialize icache tags */
	li	a0,K0BASE
	move	a2,t2		# icacheSize
	move	a3,t4		# icacheLineSize
	move	a1,a2
	icacheop(a0,a1,a2,a3,Index_Store_Tag_I)

	/* fill icache */
	li	a0,K0BASE
	move	a2,t2		# icacheSize
	move	a3,t4		# icacheLineSize
	move	a1,a2
	icacheop(a0,a1,a2,a3,Fill_I)
	
	/* clear icache tags */
	li	a0,K0BASE
	move	a2,t2		# icacheSize
	move	a3,t4		# icacheLineSize
	move	a1,a2
	icacheop(a0,a1,a2,a3,Index_Store_Tag_I)
	
	/* To support Orion/R4600, we initialise the data cache in 3 passes */

	/* 1: initialise dcache tags */
	li	a0,K0BASE
	move	a2,t3		# dcacheSize
	move	a3,t5		# dcacheLineSize
	move	a1,a2
	icacheop(a0,a1,a2,a3,Index_Store_Tag_D)

	/* 1: initialise dcache tags */
	li	a0,K0BASE
        ori     a0,0x1000
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

	/* 2: fill dcache */
	li	a0,K0BASE
        ori     a0,0x1000
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

	/* 3: clear dcache tags */
	li	a0,K0BASE
        ori     a0,0x1000
	move	a2,t3		# dcacheSize
	move	a3,t5		# dcacheLineSize
	move	a1,a2
	icacheop(a0,a1,a2,a3,Index_Store_Tag_D)

	mtc0	v0,C0_SR

	j	ra
	.end	cacheR32kReset

/*******************************************************************************
*
* cacheR32kEnableCaches - enable the RC32364 caches
*
* RETURNS: N/A
*

* void cacheR32kEnableCaches (void)

*/
	.ent	cacheR32kEnableCaches
cacheR32kEnableCaches:
	la	t0, 1f
	or	t0, K1BASE
	j	t0

1:	
	mfc0	t0, C0_CONFIG
	and	t0, ~CFG_K0MASK
	or	t0, CFG_C_NONCOHERENT
	mtc0	t0, C0_CONFIG
	j	ra

	.end	cacheR32kEnableCaches

/*******************************************************************************
*
* cacheR32kDisableCaches - disable the RC32364 caches
*
* RETURNS: N/A
*

* void cacheR32kDisableCaches (void)

*/
	.ent	cacheR32kDisableCaches
cacheR32kDisableCaches:
	SETFRAME(cacheR32kDisableCaches,0)
	subu	sp, FRAMESZ(cacheR32kDisableCaches)	/* need some stack */
	SW	ra, FRAMERA(cacheR32kDisableCaches)(sp)	/* save ra */

	jal	cacheR32kDCFlushInvalidateAll

	la	t0, 1f
	or	t0, K1BASE
	j	t0
1:	
	mfc0	t0, C0_CONFIG
	and	t0, ~CFG_K0MASK
	or	t0, CFG_C_UNCACHED
	mtc0	t0, C0_CONFIG
	HAZARD_CP_WRITE
	HAZARD_CP_WRITE
	LW	ra, FRAMERA(cacheR32kDisableCaches)(sp)
	addu	sp, FRAMESZ(cacheR32kDisableCaches)
	j	ra
	.end	cacheR32kDisableCaches

/*******************************************************************************
*
* cacheR32kDCFlushInvalidateAll - flush entire RC32364 data cache
*
* RETURNS: N/A
*

* void cacheR32kDCFlushInvalidateAll (void)

*/
	.ent	cacheR32kDCFlushInvalidateAll
cacheR32kDCFlushInvalidateAll:

1:	lw	a2,cacheDCacheSize
	lw	a3,cacheDCacheLineSize
	li	a0,K0BASE
	move	a1,a2
	icacheop(a0,a1,a2,a3,Index_Writeback_Inv_D)

1:	lw	a2,cacheDCacheSize
	lw	a3,cacheDCacheLineSize
	li	a0,K0BASE
        ori     a0,0x1000
	move	a1,a2
	icacheop(a0,a1,a2,a3,Index_Writeback_Inv_D)
	j	ra

	.end	cacheR32kDCFlushInvalidateAll

/*******************************************************************************
*
* cacheR32kDCFlush - flush RC32364 data cache locations
*
* RETURNS: N/A
*

* void cacheR32kDCFlushInvalidate
*     (
*     baseAddr,		/@ virtual address @/
*     byteCount		/@ number of bytes to invalidate @/
*     )

*/
	.ent	cacheR32kDCFlushInvalidate
cacheR32kDCFlushInvalidate:

1:	lw	a2,cacheDCacheSize
	lw	a3,cacheDCacheLineSize
	vcacheop(a0,a1,a2,a3,Hit_Writeback_Inv_D)

	j	ra
	.end	cacheR32kDCFlushInvalidate


/*******************************************************************************
*
* cacheR32kDCInvalidateAll - invalidate entire RC32364 data cache
*
* RETURNS: N/A
*

* void cacheR32kDCInvalidateAll (void)

*/
	.ent	cacheR32kDCInvalidateAll
cacheR32kDCInvalidateAll:

1:	lw	a2,cacheDCacheSize
	lw	a3,cacheDCacheLineSize
	li	a0,K0BASE
	move	a1,a2
	icacheop(a0,a1,a2,a3,Index_Writeback_Inv_D)

1:	lw	a2,cacheDCacheSize
	lw	a3,cacheDCacheLineSize
	li	a0,K0BASE
        ori     a0,0x1000
	move	a1,a2
	icacheop(a0,a1,a2,a3,Index_Writeback_Inv_D)
	j	ra

	.end	cacheR32kDCInvalidateAll

/*******************************************************************************
*
* cacheR32kDCInvalidate - invalidate RC32364 data cache locations
*
* RETURNS: N/A
*

* void cacheR32kDCInvalidate
*     (
*     baseAddr,		/@ virtual address @/
*     byteCount		/@ number of bytes to invalidate @/
*     )

*/
	.ent	cacheR32kDCInvalidate
cacheR32kDCInvalidate:

1:	lw	a2,cacheDCacheSize
	lw	a3,cacheDCacheLineSize
	vcacheop(a0,a1,a2,a3,Hit_Writeback_Inv_D)
	j	ra
	.end	cacheR32kDCInvalidate

/*******************************************************************************
*
* cacheR32kICInvalidateAll - invalidate entire RC32364 instruction cache
*
* RETURNS: N/A
*

* void cacheR32kICInvalidateAll (void)

*/
	.ent	cacheR32kICInvalidateAll
cacheR32kICInvalidateAll:

1:	lw	a2,cacheICacheSize
	lw	a3,cacheICacheLineSize
	li	a0,K0BASE
	move	a1,a2
	icacheop(a0,a1,a2,a3,Index_Invalidate_I)

	j	ra

	.end	cacheR32kICInvalidateAll

/*******************************************************************************
*
* cacheR32kICInvalidate - invalidate RC32364 data cache locations
*
* RETURNS: N/A
*

* void cacheR32kICInvalidate
*     (
*     baseAddr,		/@ virtual address @/
*     byteCount		/@ number of bytes to invalidate @/
*     )

*/
	.ent	cacheR32kICInvalidate
cacheR32kICInvalidate:

1:	lw	a2,cacheICacheSize
	lw	a3,cacheICacheLineSize
	vcacheop(a0,a1,a2,a3,Hit_Invalidate_I)

	j	ra
	.end	cacheR32kICInvalidate
