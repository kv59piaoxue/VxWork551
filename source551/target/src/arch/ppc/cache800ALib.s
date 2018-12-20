/* cache800ALib.s - PowerPC 8xx cache management assembly routines */

/* Copyright 1984-2002 Wind River Systems, Inc. */
	.data
	.globl	copyright_wind_river
	.long	copyright_wind_river

/*
modification history
--------------------
01n,17apr02,jtp  Rename global 'buffer' to 'cacheppcReadOrigin'
01m,29oct01,dtr  SPR 63012 - use of non-volatile condition register.
01n,29oct01,gls  merged from 2_0_x (also fixes SPR #27801)
01m,25sep01,yvp  Fix SPR62760: Use _WRS_TEXT_SEG_START macro instead of .align
01l,08may01,pch  Add assembler abstractions (FUNC_EXPORT, FUNC_BEGIN, etc.)
01k,25feb99,tpr  added cacheArchPipeFlush.
01j,05may98,gls	 fixed cache disable (SPR #9752)
01i,23oct96,map  fixed cache line size from 32 to 16. (SPR #7372).
01h,15apr96,tam  fixed typo error in cachePpcEnable (SPR #6334 ).
01g,23feb96,tpr  clean up the code.
01f,06jan96,tpr  replace %hi and %lo by HI and LO.
01e,27sep95,tpr  removed MMU disable in cacheEnable() and cacheDisable().
01d,01aug95,kvk  Fixed cacheEnable added cacheDisable to support PPC604.
01c,22jun95,caf  added ifdef for PPC403, cleanup.
01b,27mar95,caf  added cacheEnable() support.
01a,30jan95,caf  created.
*/

/*
DESCRIPTION
This library contains routines to manipulate the PowerPC 8xx family cache.

INCLUDE FILES: cacheLib.h

SEE ALSO: cacheLib
*/

#define _ASMLANGUAGE
#include "vxWorks.h"
#include "asm.h"
#include "cacheLib.h"
#include "arch/ppc/ppc860.h"

/* defines */

#define CACHE_LINE_NUM 128

/* globals */
	
	DATA_IMPORT(cachePpcReadOrigin)
	FUNC_IMPORT(cacheErrnoSet)
	
	FUNC_EXPORT(cachePpcEnable)	  /* enable the data or instr. cache */
	FUNC_EXPORT(cachePpcDisable)	  /* disable the data or instr. cache */
	FUNC_EXPORT(cacheArchInvalidate)  /* invalidate the data or instr. cache*/
	FUNC_EXPORT(cacheArchFlush)	  /* flush the data or instr. cache */
	FUNC_EXPORT(cacheArchTextUpdate)  /* update the instruction cache */
	FUNC_EXPORT(cacheArchPipeFlush)	  /* flush the CPU pipe cache */

	_WRS_TEXT_SEG_START
	
/******************************************************************************
*
* cachePpcEnable - Enable the PowerPC Instruction or Data cache
*
* This routine enables the instruction or data cache as selected by the 
* <cache> argument. 
*
* NOTE:
* This routine should never be called by the user application. Only 
* the cacheArchEnable() can call this routine. If the user application calls
* this routine directly the result is impredictable and can crash VxWorks
* kernel.
*
* RETURNS: OK or ERROR if the cache can not be enabled.
*
* SEE ALSO:
*.I "PPC403GA Embedded Controller User's Manual"
*.I "PowerPC 601 RISC Microprocessor User's Manual"
*.I "PowerPC 603 RISC Microprocessor User's Manual"
*.I "PowerPC 604 RISC Microprocessor User's Manual"
*
* STATUS cachePpcEnable
*     (
*     CACHE_TYPE  cache,          /@ cache to enable @/
*     )

*/

cachePpcEnable:

	/* Select if the cache to enable is the Data or the Instruction cache */

       	cmpwi	p0, _DATA_CACHE			/* if _DATA_CACHE then*/
	beq	cache800DataEnable		/* enable Data Cache */

	/* enable an flush the Instruction cache */

	mfspr	p1, IC_CST
	rlwinm.	p2, p1, 0, 0, 0 		/* if instr. cache is already */

	bne	cacheArchOK			/* enabled just return OK */

	lis	p1, 0x0a00			/* unlock all the cache */
	isync
	mtspr	IC_CST, p1		/* Unlock the Instruction cache */
	isync

	lis	p1, 0x0c00			/* invalidate all the cache */
	isync
	mtspr	IC_CST, p1		/* Invalidate the Instruction cache */
	isync

	/*
	 * The setting of the instruction cache enable (ICE) bit must be
	 * preceded by an isync instruction to prevent the cache from being
	 * enabled or disabled while an instruction access is in progress.
	 * XXX TPR to verify.
         */

	lis	p1, 0x0200 
	isync				/* Synchronize for ICE enable */
	mtspr	IC_CST, p1		/* Enable Instruction Cache */
	
	b	cacheArchOK		/* return OK */

cache800DataEnable:			/* enable data cache code */

	mfspr	p1, DC_CST

	rlwinm.	p2, p1, 0, 0, 0		/* if data cache already enabled */
	bne	cacheArchOK		/* then exit with OK */

	lis	p1, 0x0a00
	mtspr	DC_CST, p1		/* Unlock  data cache */

	lis	p1, 0x0c00
	mtspr	DC_CST, p1		/* Invalidate data cache */

	/*
	 * The setting of the data cache enable (DCE) bit must be
	 * preceded by an sync instruction to prevent the cache from being
	 * enabled or disabled in the middle of a data access.
         */

	lis	p1, 0x0200
	sync				/* Synchronize for DCE enable */
	mtspr	DC_CST, p1		/* Enable Data Cache */

	b	cacheArchOK		/* return OK */

/******************************************************************************
*
* cachePpcDisable - Disable the PowerPC Instruction or Data cache.
*
* This routine disables the instruction or data cache as selected by the 
* <cache> argument. 
*
* NOTE:
* This routine should not be called by the user application. Only 
* the cacheArchEnable() can call this routine.
*
* RETURNS: OK or ERROR if the cache can not be disabled.
*
* SEE ALSO:
*.I "PPC403GA Embedded Controller User's Manual"
*.I "PowerPC 601 RISC Microprocessor User's Manual"
*.I "PowerPC 603 RISC Microprocessor User's Manual"
*.I "PowerPC 604 RISC Microprocessor User's Manual"

* STATUS cachePpcDisable
*     (
*     CACHE_TYPE  cache,          /@ cache to disable @/
*     )

*/
cachePpcDisable:
       	cmpwi	p0, _DATA_CACHE			/* <cache> == _DATA_CACHE ? */
	beq	cachePpcDataDisable

	/* disable instruction cache */

	mfspr	p1, IC_CST

	rlwinm.	p1, p1, 0, 0, 0		/* test if cache already disabled */
	beq	cacheArchOK		/* if yes, do nothing and return OK */


	lis	p1, 0x0400
	isync				/* Synchronize for ICE disable */
	mtspr	IC_CST,p1		/* Invalidate Instr Cache */

	b	cacheArchOK		/* return OK */
    
cachePpcDataDisable:
	
	/* disable data cache */

	mfspr	p1, DC_CST
	rlwinm.	p1, p1, 0, 0, 0	/* test if cache already disabled */
	beq	cacheArchOK	/* if yes, do nothing and return OK */
	lis	p2, 0x0a00	/* load p2 with the unlock all command value */
	sync
	
	mtspr	DC_CST, p2	/* Unlock the data cache in order to flush */

	/* 
         * The 823 and 850 have smaller caches, but performance isn't an issue
         * here (it is cacheDisable).
         */
                
        li      p3,(CACHE_LINE_NUM * 4) /* 2 sets of 128 cache lines */
        mtspr   CTR, p3                 /* load CTR with the number of index */

        /*
         * load up p2 with the buffer address minus
         * one cache block size
         */

        lis     p2,HI(cachePpcReadOrigin - _CACHE_ALIGN_SIZE)
        ori     p2,p2,LO(cachePpcReadOrigin - _CACHE_ALIGN_SIZE)

dataCacheFlushLoop:
        
        lbzu    p4, _CACHE_ALIGN_SIZE(p2) /* flush the data cache block */
        bdnz    dataCacheFlushLoop
	
	lis	p1, 0x0400	/* load p1 with value to disable cache*/
	isync			/* Synchronize for DCE disable */

	mtspr	DC_CST,p1		/* Disable Data Cache */
	
	b	cacheArchOK		/* return OK */

/******************************************************************************
*
* cacheArchInvalidate - invalidate entries in a PowerPC cache
*
* This routine invalidates some or all entries in a specified PowerPC cache.
*
* RETURNS: OK, or ERROR if the cache type is invalid or the cache control
* is not supported.
*

* STATUS cacheArchInvalidate
*     (
*     CACHE_TYPE  cache,          /@ cache to invalidate @/
*     void *      address,        /@ virtual address @/
*     size_t      bytes           /@ number of bytes to invalidate @/
*     )

* INTERNAL
* This code assumes that cache blocks are 16 bytes in size.
*/

cacheArchInvalidate:

	add	p2,p2,p1	/* bytes += address */
	clrrwi	p1,p1,4		/* round address to 16 byte boundary */
invChk:	cmpwi	cr6,p0,1	/* check cache type in p0 (reuse cr6 below) */
	beq	cr6,invDat
	cmpwi	p0,0            /* <cache> == _INSTRUCTION_CACHE ? */
	bne	cacheArchError	/* invalid cache? return ERROR */

	/* partial invalidation of instruction or data cache */

invIns:	icbi	r0,p1           /* icache block invalidate */
	b	invBottom
    
invDat: dcbi	r0,p1           /* dcache block invalidate */

invBottom:
	addi	p1,p1,_CACHE_ALIGN_SIZE	/* address += 16 */
	cmplw	p1,p2		/* (address < bytes) ? */
	bge	cacheArchOK	/* if not, return OK */
	beq	cr6,invDat	/* repeat data cache loop */
	b	invIns		/* repeat instruction cache loop */

/******************************************************************************
*
* cacheArchFlush - flush entries in a PowerPC cache
*
* This routine flushes some or all entries in a specified PowerPC cache.
*
* RETURNS: OK, or ERROR if the cache type is invalid or the cache control
* is not supported.
*

* STATUS cacheArchFlush
*     (
*     CACHE_TYPE  cache,          /@ cache to flush @/
*     void *      address,        /@ virtual address @/
*     size_t      bytes           /@ number of bytes to flush @/
*     )

* INTERNAL
* This code assumes that cache blocks are 16 bytes in size.
*/

cacheArchFlush:
      	add	p2,p2,p1	/* bytes += address */
	clrrwi	p1,p1,4		/* round address to 16 byte boundary */
       	cmpwi	p0,1		/* check cache type in p0 */
	bne	cacheArchError	/* invalid cache? return ERROR */

fluDat: dcbst	r0,p1		/* data cache flush (PPC "store") */
	addi	p1,p1,_CACHE_ALIGN_SIZE	/* address += 16 */
	cmplw	p1,p2		/* (address < bytes) ? */
	blt	fluDat		/* if so, repeat */
	b	cacheArchOK	/* return OK */

/******************************************************************************
*
* cacheArchTextUpdate - synchronize the PowerPC instruction and data caches
*
* This routine flushes the PowerPC data cache, and then invalidates the
* instruction cache.  The instruction cache is forced to fetch code that
* may have been created via the data path.
*
* RETURNS: OK, always.

* STATUS cacheArchTextUpdate
*    (
*    void * address,     /@ virtual address @/
*    size_t bytes        /@ number of bytes to update @/
*    )

* INTERNAL
* This code assumes that cache blocks are 16 bytes in size.
*
* NOMANUAL
*/

cacheArchTextUpdate:

      	add	p1,p1,p0	/* bytes += address */
	clrrwi	p0,p0,4		/* round address to 16 byte boundary */

	/* loop */

updTop:	dcbst	r0,p0		/* update memory */
	sync			/* wait for update */
	icbi	r0,p0		/* remove (invalidate) copy in icache */
	addi	p0,p0,_CACHE_ALIGN_SIZE	/* address += 16 */
	cmplw	p0,p1		/* (address < bytes) ? */
	blt	updTop		/* if so, repeat */

	isync			/* remove copy in own instruction buffer */
	b	cacheArchOK	/* return OK */

/******************************************************************************
*
* cacheArchError - set errno and return ERROR
*
* To save space, several routines exit through cacheArchError() if
* an invalid cache is specified.
*
* NOMANUAL
*/

cacheArchError:
	mfspr	r0,LR
	stw	r0,4(sp)
	stwu	sp,-16(sp)
	bl	cacheErrnoSet
	lwz	r0,20(sp)
	addi	sp,sp,16
	mtspr	LR,r0
	blr

/******************************************************************************
*
* cacheArchOK - return OK
*
* To save space, several routines exit normally through cacheArchOK().
*
* NOMANUAL
*/

cacheArchOK:
	sync			/* SYNC for good measure (multiprocessor?) */
        li      p0,OK		/* return OK */
	blr

/*******************************************************************************
*
* cacheArchPipeFlush - flush the processor pipe
*
* This functiosn force the processor pipes to be flushed.
*
* RETURNS: always OK
*
* NOMANUAL
*
*/
 
cacheArchPipeFlush:
	eieio
	sync
	li	p0, OK		/* return OK */
	blr

