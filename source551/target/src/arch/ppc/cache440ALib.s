/* cache440ALib.s - assembly language cache handling routines */

/* Copyright 2001-2003 Wind River Systems, Inc. */
	.data
	.globl  copyright_wind_river
	.long   copyright_wind_river

/*
modification history
--------------------
01b,23jan03,jtp  SPR 83907 disable CE as well as EE in cache440Disable
01a,17apr02,jtp  created based on cache405ALib.s
*/

/*
DESCRIPTION
This library contains routines to manipulate the 440 PowerPC family caches.

The 440 supports two 32KB caches, an instruction cache and a data cache.
The instruction cache is physically indexed, virtually tagged and hence
is at potential risk of cache synonyms. The data cache is physically
indexed and physically tagged, so its management is relatively simple.

The cacheability of an individual page of memory is determined solely by
the TLB entry associated with the virtual address used to access it.
There are globally enable or disable bits for the instruction cache
differently from the data cache.  Therefore, this library depends on MMU
data structures to enable the desired cacheability state of individual
regions of memory, and directly modifies the TLB Entry registers on the
processor to implement cache enable/disable. It can only perform this
function after the MMU library has been initialized. As a result,
application programmers must configure the MMU in order to use the cache
library.  Furthermore, the virtual memory library should be to change
the cacheability of individual regions of their program space.

SEE ALSO: cacheLib
*/


#define _ASMLANGUAGE

/* includes */

#include "vxWorks.h"
#include "asm.h"
#include "arch/ppc/archPpc.h"
#include "arch/ppc/mmu440Lib.h"

/* defines */

#define TLB_W_BIT	20
#define TLB_I_BIT	21
#define TLB_V_BIT	22
#define _CACHE_SIZE	32768

/* externals */

	DATA_IMPORT(cache440Enabled)
	DATA_IMPORT(cache440ToEnable)
	DATA_IMPORT(cachePpcReadOrigin)
	DATA_IMPORT(mmuPpcTlbMin)
	DATA_IMPORT(mmu440StaticTlbArray)

/* globals */

	FUNC_EXPORT(cache440ICReset)
	FUNC_EXPORT(cache440DCReset)
	FUNC_EXPORT(cache440Enable)
	FUNC_EXPORT(cache440Disable)

	_WRS_TEXT_SEG_START
	
/*******************************************************************************
*
* cache440ICReset - reset the instruction cache
*
* After reset, it is necessary to invalidate all instructions in the cache
* before regions can be designed as cacheable via MMU page table entries.  This
* routine should be called once at boot time.
* RETURNS: N/A

* void cache440ICReset ()

*/

FUNC_BEGIN(cache440ICReset)
	iccci   r0, r0
	blr
FUNC_END(cache440ICReset)

/*******************************************************************************
*
* cache440DCReset - reset the data cache
*
* After reset, it is necessary to invalidate all data in the cache before
* regions can be designed as cacheable via MMU page table entries.  This
* routine should be called once at boot time.
* RETURNS: N/A

* void cache440DCReset ()

*/

FUNC_BEGIN(cache440DCReset)
	dccci	r0, r0
	blr
FUNC_END(cache440DCReset)


/***********************************************************************
*
* cache440Enable - enable caching for all static & dynamic mapping
*
* First, go through the list of static TLB entries provided to
* mmuLibInit() and activate caching in any of them for which caching
* was desired.  Second, instruct the miss handler that caching is
* turned on, and invalidate all dynamic TLB entries in the CPU.
* When dynamic MMU entries are reloaded, they will be cache-enabled.
*
* Note that the PPC440 does not allow different global cache enable
* control of the Data and Instruction caches. It is centered around a
* memory model of selecting cache attributes by program address only.
*
* The cache440Enable function assumes that mmu440StaticTlbEntry array
* accurately describes the present configuration of the TLB entries,
* with the exception that the cache state of each entry is presently
* W=0 I=1 (Caching Inhibited). The cache states from the array
* are used to enable the desired W, I settings.
*

* STATUS cache440Enable
*     (
*     CACHE_TYPE cache			/@ ignored @/
*     )

*/

FUNC_BEGIN(cache440Enable)

	/*
	 * if cache is already enabled, don't enable it again
	 */

	lis	r3, HI(cache440Enabled)
	ori	r3, r3, LO(cache440Enabled)
	lwz	r3, 0(r3)
	li	r4, TRUE
	cmpw	r3, r4
	beq	enableOK

	/*
	 * if we haven't called mmu440LibInit yet, simply remember the
	 * cache needs to be enabled later after we call it.
	 */

	lis	r3, HI(mmuPpcTlbMin)
	ori	r3, r3, LO(mmuPpcTlbMin)
	lwz	r3, 0(r3)
	cmpwi	r3, 0
	bne	enableStart

	lis	r5, HI(cache440ToEnable)
	ori	r5, r5, LO(cache440ToEnable)
	lis	r4, 0
	ori	r4, r4, TRUE
	stw	r4, 0(r5)

	b	enableOK

enableStart:
	/*
	 * r3 = mmuPpcTlbMin
	 * r4 = TLB entry index
	 * r5 = mmuStaticTlbArray entry address
	 * r8 = TLB entry word 2 value
	 * r7 = desiredWord2 from mmu440StaticTlbArray
	 */

	li	r4, 0
	lis	r5, HI(mmu440StaticTlbArray)
	ori	r5, r5, LO(mmu440StaticTlbArray)
	lwz	r5, 0(r5)

enableLoop:
	cmpw	r4, r3			/* TLB entry index >= mmuPpcTlbMin? */
	beq	enableLoopDone		/* if so, we're done, skip ahead */

	/*
	 * word2 = readTlbEntryWord2 & ~(W|I)
	 * word2 |= (attr & (W|I))
	 */
	tlbre	r8, r4, 2		/* load current TLB entry word 2 */
	rlwinm	r8, r8, 0, TLB_I_BIT+1, TLB_W_BIT-1 /* reset the W and I bits */
	lwz	r7, 12(r5)		/* load desired attribute info */
	rlwinm	r7, r7, 0, TLB_W_BIT, TLB_I_BIT /* reset all but W and I bits */
	or	r8, r8, r7		/* combine word 2 with desired W,I */
	tlbwe	r8, r4, 2		/* save to hw TLB entry word 2 */

	/*
	 * loop bottom
	 */

	addi	r4, r4, 1		/* increment TLB entry index */
	addi	r5, r5, 16		/* advance to next static entry */
	b	enableLoop

enableLoopDone:

	isync				/* flush new static TLB entries to hw */

	/*
	 * inform the miss routine that cache is enabled
	 */

	lis	r3, HI(cache440Enabled)
	ori	r3, r3, LO(cache440Enabled)
	li	r5, TRUE
	stw	r5, 0(r3)

	/*
	 * invalidate all dynamic (miss-allocated) TLB entries
	 */

	li	r3, N_TLB_ENTRIES

enableInvLoop:
	cmpw	r4, r3			/* TLB entry index >= N_TLB_ENTRIES */
	beq	enableInvDone		/* if so, we're done, skip ahead */

	/*
	 * word0 = readTlbEntryWord0 & ~(V)
	 */
	tlbre	r5, r4, 0		/* load current TLB entry word 0 */
	rlwinm	r5, r5, 0, TLB_V_BIT+1, TLB_V_BIT-1 /* reset the V bit */
	tlbwe	r5, r4, 0		/* save to register TLB entry word 0 */

	/*
	 * loop bottom
	 */

	addi	r4, r4, 1		/* increment TLB entry index */
	b	enableInvLoop

enableInvDone:
	isync				/* flush new dynamic TLB entries to hw */

enableOK:
	li	r3, OK
	blr
FUNC_END(cache440Enable)

/***********************************************************************
*
* cache440Disable - disable caching for all static & dynamic mapping
*
* First, go through the list of static TLB entries provided to
* mmuLibInit() and deactivate caching in any of them for which caching
* was enabled.  Second, instruct the miss handler that caching is
* turned off, and invalidate all dynamic TLB entries in the CPU.
* When dynamic MMU entries are reloaded, they will be cache-disabled.
*
* Note that the PPC440 does not allow different global cache enable
* control of the Data and Instruction caches. It is centered around a
* memory model of selecting cache attributes by program address only.

* STATUS cache440Disable
*     (
*     CACHE_TYPE cache			/@ ignored @/
*     )

*/

FUNC_BEGIN(cache440Disable)

	/*
	 * if cache is already disabled, don't disable it again
	 */

	lis	r3, HI(cache440Enabled)
	ori	r3, r3, LO(cache440Enabled)
	lwz	r3, 0(r3)
	li	r4, FALSE
	cmpw	r3, r4
	beq	disableOK

	/*
	 * if data MMU 'enabled', the cache may only be disabled via MMU
	 */

	mfmsr	r4
	andi.	r4, r4, _PPC_MSR_DS
	beq	disableStart

disableError:
	li	r3, ERROR	/* it's set, so do nothing, return error */
	blr

disableStart:

	mfmsr	r6		/* save msr for restoration later */
	INT_MASK(r6,r3)
	mtmsr	r3		/* lock external interrupts */
	isync			/* synchronize instruction context */

	/*
	 * inform the miss routine that cache is disabled
	 */

	lis	r3, HI(cache440Enabled)
	ori	r3, r3, LO(cache440Enabled)
	li	r5, FALSE
	stw	r5, 0(r3)

	/*
	 * retrieve the count of static TLB entries
	 */

	lis	r3, HI(mmuPpcTlbMin)
	ori	r3, r3, LO(mmuPpcTlbMin)
	lwz	r3, 0(r3)

	/*
	 * Flush entire data cache. Use the memory region from
	 * cachePpcReadOrigin to cachePpcReadOrigin + cache_size as
	 * the source of address locations.  Note that the PPC
	 * data cache is physically index and physically tagged,
	 * so doing a load from memory of a cache's worth of data will
	 * correctly flush out the cache contents.
	 */

	lis	r4, HI(cachePpcReadOrigin)
	ori	r4, r4, LO(cachePpcReadOrigin)
	lwz	r4, 0(r4)

	lis	r5, HI(_CACHE_SIZE)
	ori	r5, r5, LO(_CACHE_SIZE)
	add	r5, r4, r5

disableFlushLoop:
	cmpw	r4, r5			/* addr >= origin + cache size?  */
	beq	disableFlushDone	/* yes, skip forward, done w/loop */

	lwz	r0, 0(r4)		/* flush cache line data */

	/* loop bottom */

	addi	r4, r4, _CACHE_ALIGN_SIZE
	b	disableFlushLoop

disableFlushDone:

	/*
	 * r3 = mmuPpcTlbMin
	 * r4 = TLB entry index
	 * r5 = word 2 value
	 */

	li	r4, 0

disableLoop:
	cmpw	r4, r3
	beq	disableLoopDone

	tlbre	r5, r4, 2		/* read TLB entry word 2 */
	rlwinm	r5, r5, 0, TLB_W_BIT+1, TLB_W_BIT-1	/* turn off W */
	ori	r5, r5, MMU_STATE_CACHEABLE_NOT
	tlbwe	r5, r4, 2		/* write TLB entry word 2 */

	addi	r4, r4, 1
	b	disableLoop

disableLoopDone:
    	isync				/* flush new static TLB entries to hw */

	/*
	 * invalidate all dynamic (miss-allocated) TLB entries
	 */

	li	r3, N_TLB_ENTRIES

disableInvLoop:
	cmpw	r4, r3			/* TLB entry index >= N_TLB_ENTRIES */
	beq	disableInvDone		/* if so, we're done, skip ahead */

	/*
	 * word0 = readTlbEntryWord0 & ~(V)
	 */

	tlbre	r5, r4, 0		/* load current TLB entry word 0 */
	rlwinm	r5, r5, 0, TLB_V_BIT+1, TLB_V_BIT-1 /* reset the V bit */
	tlbwe	r5, r4, 0		/* save to register TLB entry word 0 */

	/*
	 * loop bottom
	 */

	addi	r4, r4, 1		/* increment TLB entry index */
	b	disableInvLoop

disableInvDone:
	isync				/* flush new dynamic TLB entries to hw */

	dccci	0,0			/* invalidate D-cache */
	iccci	0,0			/* invalidate I-cache too */

	mtmsr	r6			/* restore external interrupts */

disableOK:
	li	r3, OK
	blr
FUNC_END(cache440Disable)
