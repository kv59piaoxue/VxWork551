/* cacheE500ALib.s - assembly language cache handling routines */

/* Copyright 2001-2003 Wind River Systems, Inc. */

/*
modification history
--------------------
01c,02oct03,dtr  Modification to ensure cache flush contiguous.
01b,24jul03,dtr  Formal inspection fixes, remove redundant code.
01a,17dec02,dtr  created.
*/

/*
DESCRIPTION
This library contains routines to manipulate the E500 PowerPC family caches.

The E500 supports two 32KB caches, an instruction cache and a data cache.
The instruction cache and  data cache is physically indexed and physically 
tagged, so its management is relatively simple.

The cacheability of an individual page of memory is determined solely by
the TLB entry associated with the virtual address used to access it.
There are globally enable or disable bits for the instruction cache
and the the data cache.  The library depends on MMU data structures to enable
the desired cacheability state of individual regions of memory. The MMU is 
always on so the cache can be switched on at any time but during 
initialisation it is prefereable to have the cache off until MMU page 
tables are initialized because of the time waisted switched the cache on 
and off. Furthermore, the virtual memory library should be able to change
the cacheability of individual regions of their program space.

SEE ALSO: cacheLib
*/

#include "arch/ppc/mmuE500Lib.h"	
	/* externals */

	DATA_IMPORT(cachePpcReadOrigin)
	FUNC_IMPORT(cacheErrnoSet)
	DATA_IMPORT(ppcE500ICACHE_LINE_NUM) /* comes from BSP */
	DATA_IMPORT(ppcE500DCACHE_LINE_NUM) /* comes from BSP */
	DATA_IMPORT(ppcE500CACHE_ALIGN_SIZE)/* comes from BSP*/
	FUNC_EXPORT(cacheE500Enable)	  /* enable the data or instr. cache */
	FUNC_EXPORT(cacheE500Disable)	  /* disable the data or instr. cache */

#define	CACHE_ALIGN_SHIFT	5	/* Cache line size == 2**5 */
	
	_WRS_TEXT_SEG_START
	

/******************************************************************************
*
* cacheE500Enable - Enable the E500 PowerPC Instruction or Data cache
*
* This routine enables the instruction or data cache as selected by the 
* <cache> argument. 
*
* NOTE:
* This routine should never be called by the user application. Only 
* the cacheArchEnable() can call this routine. If the user application calls
* this routine directly the result is unpredictable and can crash the VxWorks
* kernel.
*
* RETURNS: OK or ERROR if the cache can not be enabled.
*
* SEE ALSO:
*.I "E500 Core Users Manual"
*
* STATUS cacheE500Enable
*     (
*     CACHE_TYPE  cache,          /@ cache to enable @/
*     )
*/

FUNC_BEGIN(cacheE500Enable)

	cmpwi	p0, _DATA_CACHE		/* if _DATA_CACHE then */
	beq	cacheE500DataEnable	/* enable Data Cache */

        /* The following instructions load the value of the L1 instruction 
	   cache status register checks to see if cache already enabled */
        
	mfspr   p1,L1CSR1
        li      p2, _PPC_L1CSR_E
	or      p2,p2,p1
	cmpw    p1,p2			/* Is instruction cache on? */
	beq	cacheArchOK		/* enabled just return OK */
	
        /* If the instruction cache isn't enabled flash invalidate the cache 
	   then enable it vi ther configration status register */
	ori     p1,p1,_PPC_L1CSR_FI     
        /* msync isync reqd before updating L1CSR1 register */
	msync
	isync
        mtspr   L1CSR1,p1		/* Flash invalidate L1 instruction 
					   cache - 1 CPU cycle */
	ori     p1,p1,_PPC_L1CSR_E      /* Enable L2 cache */
	/* msync isync reqd before updating L1CSR1 register */
        msync
	isync	
	mtspr   L1CSR1,p1		/* enable instruction cache */
	b	cacheArchOK		/* return OK */

cacheE500DataEnable:
        /* The following instructions load the value of the L1 data 
	   cache status register checks to see if cache already enabled */
	mfspr	p1, L1CSR0		/* move L1CSR0 to p1 */
        li      p2, _PPC_L1CSR_E
	or      p2,p2,p1
	cmpw    p1,p2      
	beq	cacheArchOK		/* enabled just return OK */
        /* If the data cache isn't enabled flash invalidate the cache 
	   then enable it vi ther configration status register */
	ori     p1, p1,_PPC_L1CSR_FI    
        msync
	isync
	/* msync isync reqd before updating L1CSR0 register */
        mtspr   L1CSR0,p1		/* flash invalidate data cache 
					   - 1 CPU cycle */
	ori     p1, p1,_PPC_L1CSR_E
	/* msync isync reqd before updating L1CSR0 register */
        msync
	isync	
	mtspr   L1CSR0,p1		/* enable data cache */
	b	cacheArchOK		/* return OK */
FUNC_END(cacheE500Enable)

/******************************************************************************
*
* cacheE500Disable - Disable the E500 PowerPC Instruction or Data cache.
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
*.I "E500 Core Users Manual"
*
* STATUS cacheE500Disable
*     (
*     CACHE_TYPE  cache,          /@ cache to disable @/
*     )
*
*/
FUNC_BEGIN(cacheE500Disable)
	cmpwi	p0, _DATA_CACHE		/* if _DATA_CACHE then */
	beq	cacheE500DataDisable	/* disable Data Cache */
	/* The following 8 lines disable the L1 instruction cache via 
	   masking the enable bit in the L1CSR1 register */ 
	mfspr	p1, L1CSR1			
	lis     p2,HIADJ(~_PPC_L1CSR_E)
	addi	p2,p2,LO(~_PPC_L1CSR_E)
	and     p2,p2,p1
	/* msync isync reqd before updating L1CSR1 register */
	msync				
	isync
	mtspr   L1CSR1, p2
	b     cacheArchOK	

	/* disable data cache */
cacheE500DataDisable:

	
	/*
 	 * if the MMU is enabled, the only way to disable the cache is
	 * via the MMU.
	 */

        lis     p3, HIADJ(ppcE500DCACHE_LINE_NUM)
	lwz     p3, LO(ppcE500DCACHE_LINE_NUM)(p3)

	/*
	 * p3 contains the count of cache lines to be fetched & flushed.
	 * Convert to a count of pages covered, and fetch a word from
	 * each page to ensure that all addresses involved are in
	 * the TLB so that reloads do not disrupt the flush loop.
	 * A simple shift without round-up is sufficient because
	 * the p3 value is always a multiple of the shift count.
	 */
	srwi	p2, p3, MMU_RPN_SHIFT - CACHE_ALIGN_SHIFT
	mtspr	CTR, p2
	lis	p2, HIADJ(cachePpcReadOrigin)
	lwz	p2, LO(cachePpcReadOrigin)(p2)
	li      p6,MMU_PAGE_SIZE

	/*
	 * Disable interrupts during flush, to ensure everything
	 * is marked invalid when cache is disabled.
	 */

	mfmsr	p5			/* read msr */
	INT_MASK(p5, p0)		/* mask off ce & ee bits */
	mtmsr	p0			/* DISABLE INTERRUPT */

	/*
	 * There might be a page boundary between here and the end of
	 * the function, so make sure both pages are in the I-TLB.
	 */
	b	cachePpcDisableLoadItlb
cachePpcDisableLoadDtlb:
	lbzu	p4,0(p2)
	add     p2,p2,p6
	bdnz	cachePpcDisableLoadDtlb

        mtspr   CTR, p3      /* load CTR with the number of index */

	
	
        /*
         * load up p2 with the buffer address minus
         * one cache block size
         */

	lis     p4, HIADJ(ppcE500CACHE_ALIGN_SIZE)
        lwz     p4, LO(ppcE500CACHE_ALIGN_SIZE)(p4)
	lis	p3, HIADJ(cachePpcReadOrigin)
	lwz	p3, LO(cachePpcReadOrigin)(p3)
		
	subf	p2, p4, p3 /* buffer points to text  - cache line size */

cacheE500DisableFlush:

        add	p2, p4, p2		  /* +  cache line size */
	lbzu	p3, 0(p2)	       	  /* flush the data cache block */
        bdnz    cacheE500DisableFlush     /* loop till cache ctr is zero */
	isync
	mfspr    p2,L1CSR0
	lis      p1,HIADJ(~_PPC_L1CSR_E)
	addi	 p1,p1,LO(~_PPC_L1CSR_E)
	and      p2,p2,p1		 /* Mask out the cache enable bit */
	/* msync isync reqd before updating L1CSR0 register */
        msync
	isync	
	mtspr   L1CSR0,p2		 /* disable the data cache */
	mtmsr	p5			/* restore msr */
	b	cacheArchOK		/* return OK */

cachePpcDisableLoadItlb:
	b	cachePpcDisableLoadDtlb

FUNC_END(cacheE500Disable)




