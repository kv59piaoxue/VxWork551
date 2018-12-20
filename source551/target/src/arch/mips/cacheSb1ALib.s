/* cacheSb1ALib.s: Assembly routines for Broadcom SB-1 Core (L1 and L2) Caches */

/* Copyright 2002 Wind River Systems, Inc. */
        .data
        .globl  copyright_wind_river

/* 
*  Copyright 2000,2001
*  Broadcom Corporation. All rights reserved.
* 
*  This software is furnished under license to Wind River Systems, Inc.
*  and may be used only in accordance with the terms and conditions 
*  of this license.  No title or ownership is transferred hereby.
*/

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
01e,24jun02,pgh  Add the L2 cache code from the BSP.
01d,18jan02,agf  add explicit align directive to data section(s)
01c,04dec01,agf  add Broadcom copyright notice
01b,03dec01,agf  remove unnecessry assembler directives
01a,14nov01,agf  created.
*/

/*
DESCRIPTION
This library contains Broadcom Sb1 cache set-up and invalidation routines
written in assembly language.  The Sb1 utilizes a variable-size
instruction and data cache that operates in write-back (only) mode.  At 
this time, this code assumes 32-byte cache lines.  See also the manual 
entry for cacheSb1Lib.

This library contains Broadcom BCM1250 L2 cache set-up and invalidation 
routines written in assembly language. It relies on registers only since DRAM 
may not be active yet.  This code assumes the line size is always 32 bytes.

For general information about caching, see the manual entry for cacheLib.

INCLUDE FILES: cacheLib.h

SEE ALSO: cacheSb1Lib, cacheLib
*/


#define _ASMLANGUAGE
#include "vxWorks.h"
#include "asm.h"

#include "drv/multi/bcm1250Lib.h"


	/* constants */

#define L1CACHE_NUMWAYS     4
#define L1CACHE_NUMIDX      256
#define L1CACHE_LINESIZE    32
#define L1CACHE_IDXHIGH     (L1CACHE_LINESIZE*L1CACHE_NUMWAYS*L1CACHE_NUMIDX)

#define L2CACHE_LINESIZE    32
#define L2C_ENTRIES_PER_WAY 4096
#define L2C_NUM_WAYS        4


    /* macros */

#define PHYS_TO_XKSEG_CACHED(x)   (0xa100000000000000|(x))
#define PHYS_TO_XKSEG_UNCACHED(x) (0x9000000000000000|(x))

/* in archMips.h these macros are not assembler friendly, so fix for here */

#undef  PHYS_TO_K0
#define PHYS_TO_K0(x)   (K0BASE | (x))
#undef  PHYS_TO_K1
#define PHYS_TO_K1(x)   (K1BASE | (x))


	/* globals */

	.text

	.globl	GTEXT(cacheSb1Reset)
	.globl	GTEXT(cacheSb1DCFlushInvalidateAll)
	.globl	GTEXT(cacheSb1DCFlushInvalidateLines)
	.globl	GTEXT(cacheSb1ICInvalidateAll)
	.globl	GTEXT(cacheSb1ICInvalidateLines)
	.globl	GTEXT(sb1CacheExcVec)

	.globl	GDATA(cacheSb1ICacheSize)
	.globl	GDATA(cacheSb1DCacheSize)

	.globl	GDATA(cacheSb1ICacheLineSize)
	.globl	GDATA(cacheSb1DCacheLineSize)

        .data
	.align	4
cacheSb1ICacheSize:
        .word   0                       /* instruction cache size */
cacheSb1DCacheSize:
        .word   0                       /* data cache size */
cacheSb1ICacheLineSize:
        .word   0                       /* instruction cache line size */
cacheSb1DCacheLineSize:
        .word   0                       /* data cache line size */


	.text

/******************************************************************************
*
* cacheSb1Reset - low level initialisation of the Sb1 L1 caches
*
* This routine initialises the Sb1 L1 caches to ensure that all entries are
* marked invalid.  It must be called by the ROM before any cached locations
* are used to prevent the possibility of uninitialized data being written to
* memory.
*
* Arguments
*       t0 - size of instruction cache in bytes
*       t1 - size of instruction cache line in bytes
*       t2 - size of data cache in bytes
*       t3 - size of data cache line in bytes
*
* RETURNS: N/A
*

* void cacheSb1Reset

*/
        .ent    cacheSb1Reset
FUNC_LABEL(cacheSb1Reset)
        /* disable all i/u and cache exceptions */
        mfc0    v0,C0_SR
        HAZARD_CP_READ
        and     v1,v0,SR_BEV
        or      v1,v0,SR_DE
        mtc0    v1,C0_SR

        /* set tag & ecc to 0 */
        mtc0    zero,C0_TAGLO
        mtc0    zero,C0_TAGHI
        mtc0    zero,C0_ECC
        HAZARD_CP_WRITE

        /* Initialize the instruction cache */
        li      t2,K1BASE
        li      t3,L1CACHE_IDXHIGH

        add     t0,t2,t3
        .align  4
1:      cache   Index_Store_Tag_I, 0(t2)
        addu    t2,L1CACHE_LINESIZE
        bne     t0,t2,1b

        /* dmtc0   zero,C0_TAGLO,2 */
        /* dmtc0   zero,C0_TAGHI,2 */
        .word   0x40a0e002
        .word   0x40a0e802

        li      t2,K1BASE
        add     t0,t2,t3
        .align  4
1:      cache   Index_Store_Tag_D, 0(t2)
        addu    t2,L1CACHE_LINESIZE
        bne     t0,t2,1b

        mtc0    v0,C0_SR
        HAZARD_CP_WRITE
        j       ra
        .end    cacheSb1Reset


/*******************************************************************************
*
* cacheSb1DCFlushInvalidateAll - flush entire Sb1 data cache
*
* RETURNS: N/A
*

* void cacheSb1DCFlushInvalidateAll (void)

*/
        .ent    cacheSb1DCFlushInvalidateAll
FUNC_LABEL(cacheSb1DCFlushInvalidateAll)

	li	a0, K0BASE
	lw	t1, cacheSb1DCacheSize
	.set noreorder
1:	beqz	t1, 2f
	subu	t1, t1, 8
	cache	Index_Writeback_Inv_D, 0*L1CACHE_LINESIZE(a0)
	cache	Index_Writeback_Inv_D, 1*L1CACHE_LINESIZE(a0)
	cache	Index_Writeback_Inv_D, 2*L1CACHE_LINESIZE(a0)
	cache	Index_Writeback_Inv_D, 3*L1CACHE_LINESIZE(a0)
	cache	Index_Writeback_Inv_D, 4*L1CACHE_LINESIZE(a0)
	cache	Index_Writeback_Inv_D, 5*L1CACHE_LINESIZE(a0)
	cache	Index_Writeback_Inv_D, 6*L1CACHE_LINESIZE(a0)
	cache	Index_Writeback_Inv_D, 7*L1CACHE_LINESIZE(a0)
	b	1b
	addu	a0, a0, 8*L1CACHE_LINESIZE
	.set reorder
2:
	j	ra
	.end	cacheSb1DCFlushInvalidateAll


/*******************************************************************************
*
* cacheSb1DCFlushInvalidateLines - flush selected  Sb1 data cache lines
*
* RETURNS: N/A
*

* void cacheSb1DCFlushInvalidateLines (unsigned int addr, unsigned int lines)

*/
        .ent    cacheSb1DCFlushInvalidateLines
FUNC_LABEL(cacheSb1DCFlushInvalidateLines)

	.set noreorder
1:
	subu	a1, a1, 1
	cache	Hit_Writeback_Inv_D, 0(a0)
	bnez	a1, 1b
	addu	a0, a0, L1CACHE_LINESIZE
	.set reorder

	j	ra
	.end	cacheSb1DCFlushInvalidateLines



/*******************************************************************************
*
* cacheSb1ICFlushInvalidateAll - flush entire Sb1 instruction cache
*
* RETURNS: N/A
*

* void cacheSb1ICFlushInvalidateAll (void)

*/
        .ent    cacheSb1ICInvalidateAll
FUNC_LABEL(cacheSb1ICInvalidateAll)

	li	a0, K0BASE
	lw	t1, cacheSb1ICacheSize
	.set noreorder
1:	beqz	t1, 2f
	subu	t1, t1, 8
	cache	Index_Invalidate_I, 0*L1CACHE_LINESIZE(a0)
	cache	Index_Invalidate_I, 1*L1CACHE_LINESIZE(a0)
	cache	Index_Invalidate_I, 2*L1CACHE_LINESIZE(a0)
	cache	Index_Invalidate_I, 3*L1CACHE_LINESIZE(a0)
	cache	Index_Invalidate_I, 4*L1CACHE_LINESIZE(a0)
	cache	Index_Invalidate_I, 5*L1CACHE_LINESIZE(a0)
	cache	Index_Invalidate_I, 6*L1CACHE_LINESIZE(a0)
	cache	Index_Invalidate_I, 7*L1CACHE_LINESIZE(a0)
	b	1b
	addu	a0, a0, 8*L1CACHE_LINESIZE
	.set reorder
2:
	j	ra
	.end	cacheSb1ICInvalidateAll


/*******************************************************************************
*
* cacheSb1DCFlushInvalidateLines - flush selected Sb1 instruction cache lines
*
* RETURNS: N/A
*

* void cacheSb1ICFlushInvalidateLines (unsigned int addr, unsigned int lines)

*/
        .ent    cacheSb1ICInvalidateLines
FUNC_LABEL(cacheSb1ICInvalidateLines)
	.set noreorder
1:
	subu	a1, a1, 1
	cache	Hit_Invalidate_I, 0(a0)
	bnez	a1, 1b
	addu	a0, a0, L1CACHE_LINESIZE
	.set reorder

	j	ra
	.end	cacheSb1ICInvalidateLines


/*******************************************************************************
*
* sb1CacheExcVec - Special cache error handler for SB1
*
* RETURNS: N/A
*

* not a user callable routine

*/
        .ent    sb1CacheExcVec
FUNC_LABEL(sb1CacheExcVec)
        /*
         * This is a very bad place to be.  Our cache error
         * detection has triggered.  If we have write-back data
         * in the cache, we may not be able to recover.  As a
         * first-order desperate measure, turn off KSEG0 cacheing.
         */
        .set    noat
        /* look for signature of spurious CErr */
        mfc0    k1, C0_ECC
        lui     k0, 0x4000
        bne     k0, k1,real_cerr
        .word   0x401bd801         /* mfc0    k1,C0_CACHERR,1 */
        lui     k0, 0xffe0
        and     k1, k0,k1
        lui     k0, 0x0200
        bne     k0, k1,real_cerr

        /* clear/unlock the registers */
        mtc0    zero, C0_ECC
        .word   0x4080d801         /* mtc0    zero,C0_CACHERR,1 */
        eret

real_cerr:
        b       real_cerr
        .end sb1CacheExcVec 

/******************************************************************************
*
* sb1L2CacheInit - Initialize the L2 Cache tags to be "invalid"
*
* void sb1L2CacheInit (void) 
*  	   
*  Registers used:
*  	   t0,t1,t2
*/
	.globl	sb1L2CacheInit
	.ent	sb1L2CacheInit
FUNC_LABEL(sb1L2CacheInit)

	/* Save the old status register, and set the KX bit. */

		mfc0	t2,C0_SR
		or	t1,t2,SR_KX
		mtc0	t1,C0_SR
		HAZARD_CP_WRITE
	/*
	  Start the index at the base of the cache management
	  area, but leave the address bit for "Valid" zero.
	  Note that the management tags are at 00_D000_0000,
	  which cannot be expressed with the PHYS_TO_K1 macro,
	  so well need to use a 64-bit address to get to it.
	*/
		dli	t0,PHYS_TO_XKSEG_UNCACHED(A_L2C_MGMT_TAG_BASE)

	/* Loop through each entry and each way */

		li	t1,L2C_ENTRIES_PER_WAY*L2C_NUM_WAYS
	/*
	  Write a zero to the cache management register at each
	  address.
	*/
		.align 4
1:		sd	zero,(t0)
                sd      zero,1*L2CACHE_LINESIZE(t0)
                sd      zero,2*L2CACHE_LINESIZE(t0)
                sd      zero,3*L2CACHE_LINESIZE(t0)
                daddiu  t0,t0,(4*L2CACHE_LINESIZE)
		subu    t1,t1,4
                bne     t1,zero,1b

	/* Restore old KX bit setting */

		mtc0	t2,C0_SR
		HAZARD_CP_WRITE

		j	ra		

	.end	sb1L2CacheInit


/******************************************************************************
*
* sb1L2CacheDisable - Convert the entire L2 Cache into static memory, 
*
* void sb1L2CacheDisable (void) 
*  	   
*  Registers used:
*  	   t0,t1
*/

	.globl	sb1L2CacheDisable
	.ent	sb1L2CacheDisable
FUNC_LABEL(sb1L2CacheDisable)

	/*
          Configure the L2 cache as SRAM (all ways disabled except one)
          Do a memory reference at the "way_disable" address
          to switch it off.
          Warning: do NOT try to configure all of the ways off - you
          must leave at least one way active!  This code leaves
          way #3 active and gives ways 0..2 to the program.
	*/
                li      t0,PHYS_TO_K1(A_L2_MAKEDISABLE(0x07))
                ld      t0,(t0)
	/*
	  Use the result of the load to stall the pipe here.
	  Ref sec 5.4.2
	  XXX is this necessary for global enable/disable operations?
	*/
		addu	t0,t0,t0

	/* Re-write all the tags */

		b	sb1L2CacheInit

	.end	sb1L2CacheDisable


/******************************************************************************
*
* sb1L2CacheEnable - Convert the L2 Cache into a functioning cache memory
*
* void sb1L2CacheEnable (void) 
*  	   
*  Registers used:
*  	   t0,t1
*/

	.globl	sb1L2CacheEnable
	.ent	sb1L2CacheEnable
FUNC_LABEL(sb1L2CacheEnable)

	/*
	  Configure the L2 cache as Cache (all ways enabled)
	  Do a memory reference at the "way_disable" address
	  to switch it on.
	*/
		li	t0,PHYS_TO_K1(A_L2_MAKEDISABLE(0x0))
		ld	t0,(t0)
	/*
	  Use the result of the load to stall the pipe here.
	  Ref sec 5.4.2
	  XXX is this necessary for global enable/disable operations?
	*/
		addu	t0,t0,t0

	/* Re-write all the tags */

		b	sb1L2CacheInit

	.end	sb1L2CacheEnable


/******************************************************************************
*
* sb1L2CacheFlush - force all dirty lines to be written back to memory
*
* int sb1L2CacheFlush (void) 
*  	   
*  Registers used:
*  	   t0,t1,t2,t3,t4,t5,t6,t7,a0
*
*  RETURNS: number of lines flushed
*/

	.globl	sb1L2CacheFlush
	.ent	sb1L2CacheFlush
FUNC_LABEL(sb1L2CacheFlush)

        /* Save the old status register, and set the KX bit. */

                mfc0    a0,C0_SR
                or      t1,a0,SR_KX
                mtc0    t1,C0_SR
                HAZARD_CP_WRITE

        /*
          Set the BERR bits in both memory controllers.  We re
          going to do cacheable reads where there is no memory.
        */

                li      t0,PHYS_TO_K1(A_MC_REGISTER(0,R_MC_CONFIG))
                ld      t6,0(t0)
                dli     t1,(M_MC_BERR_DISABLE | M_MC_ECC_DISABLE)
                or      t1,t1,t6
                sd      t1,0(t0)

                li      t0,PHYS_TO_K1(A_MC_REGISTER(1,R_MC_CONFIG))
                ld      t7,0(t0)
                dli     t1,(M_MC_BERR_DISABLE | M_MC_ECC_DISABLE)
                or      t1,t1,t7
                sd      t1,0(t0)
	/*
          Start the index at the base of the cache management area.
          Note that the management tags are at 00_D000_0000,
          which cannot be expressed with the PHYS_TO_K1 macro,
          so well need to use a 64-bit address to get to it.
	*/
                dli     t0,PHYS_TO_XKSEG_UNCACHED(A_L2C_MGMT_TAG_BASE)
                li      t2,PHYS_TO_K1(A_L2_READ_ADDRESS)

        /* Loop through each entry and each way */

                li      t1,L2C_ENTRIES_PER_WAY*L2C_NUM_WAYS
                move    v0,zero
	/*
          Do a read at the cache management address to set the
          A_L2_READ_TAG register.
	*/
1:              ld      t3,0(t0)		/*this sets the register.*/
                daddi   t3,t3,0			/*Do an ALU op to ensure ordering*/
		ld      t4,0(t2)                /*Get the tag*/
                li      t5,M_L2C_TAG_DIRTY
                and     t5,t4,t5                /*Test the dirty bit*/
                beq     t5,zero,2f              /*don t flush this line*/

        /*
          The way that we re looking at now will be the victim, so all we
          need to do is a cacheable read at any address that does *not*
          match this tag.  To do this, we re going to OR in some bits
          into the physical address to put it way outside the memory area.
          Then do a cacheable read.  The current way will be replaced
          with the garbage data.  We ll pick PA 30_0000_0000 in the middle
          of the 520GB memory expansion area for this purpose.
        */

                add     v0,1                    /*count this line (debug)*/

                dli     t5,(M_L2C_TAG_TAG|M_L2C_TAG_INDEX)
                and     t4,t4,t5                /*Have a physical address*/
                dli     t5,PHYS_TO_XKSEG_CACHED(0x3000000000)
                or      t4,t4,t5
                ld      t4,0(t4)                /*Do a read.*/
                daddi   t4,t4,1                 /*Use it in an ALU op.*/

2:		daddiu  t0,t0,L2CACHE_LINESIZE     
                subu    t1,t1,1
                bne     t1,zero,1b


        /*
          Now, reinit the entire cache.  Of course, we could just
          reinit the lines we flushed, but this routine is mucking
          the entire cache anyway, so it doesn t matter.
        */


                dli     t0,PHYS_TO_XKSEG_UNCACHED(A_L2C_MGMT_TAG_BASE)
                li      t1,L2C_ENTRIES_PER_WAY*L2C_NUM_WAYS
	/*
          Write a zero to the cache management register at each
          address.
	*/
1:              sd      zero,0(t0)
                sd      zero,1*L2CACHE_LINESIZE(t0)
                sd      zero,2*L2CACHE_LINESIZE(t0)
                sd      zero,3*L2CACHE_LINESIZE(t0)
                daddiu  t0,t0,(4*L2CACHE_LINESIZE) 
                subu    t1,t1,4
                bne     t1,zero,1b

        
	/* Restore the old MC register values */
        
                li      t0,PHYS_TO_K1(A_MC_REGISTER(0,R_MC_CONFIG))
                sd      t6,0(t0)
                li      t0,PHYS_TO_K1(A_MC_REGISTER(1,R_MC_CONFIG))
                sd      t7,0(t0)

       
        /* Restore old KX bit setting */

                mtc0    a0,C0_SR
                HAZARD_CP_WRITE

                j       ra              /*return to caller*/

	.end	sb1L2CacheFlush

