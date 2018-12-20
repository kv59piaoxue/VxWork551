/* cache405ALib.s - assembly language cache handling routines */

/* Copyright 1984-1996 Wind River Systems, Inc. */
	.data
	.globl  copyright_wind_river
	.long   copyright_wind_river

/*
modification history
--------------------
01i,25sep01,yvp  Fix SPR62760: Use _WRS_TEXT_SEG_START macro instead of .align
01h,08may01,pch  Add assembler abstractions (FUNC_EXPORT, FUNC_BEGIN, etc.)
01g,05oct00,sm  created
*/

/*
DESCRIPTION
This library contains routines to manipulate the 405 PowerPC family caches.
This library relies on a set of variables defined in the BSP to specify
the number of cache lines and the cache line size, since the 405 SOC can
have varying number of cache lines and the cache line size.

SEE ALSO: cacheLib
*/


#define _ASMLANGUAGE

#include "vxWorks.h"
#include "asm.h"
#include "arch/ppc/archPpc.h"

	/* globals */

	FUNC_EXPORT(cache405ICReset)
	FUNC_EXPORT(cache405DCReset)

        .extern ppc405ICACHE_LINE_NUM /* ppc405ICACHE_LINE_NUM comes from BSP */
        .extern ppc405DCACHE_LINE_NUM /* ppc405DCACHE_LINE_NUM comes from BSP */
        .extern ppc405CACHE_ALIGN_SIZE /* ppc405CACHE_ALIGN_SIZE from BSP */

	_WRS_TEXT_SEG_START
	
/*******************************************************************************
*
* cache405ICReset - reset the instruction cache
*
* All ICCR bits are reset to zero after system reset.  It is necessary to
* invalid date each congruence class in the cache before regions can be 
* designed as cacheable in the ICCR.  This routine should be called once
* at boot time.
* RETURNS: N/A

* void cache405ICReset ()

*/

FUNC_LABEL(cache405ICReset)
        lis     p1, HIADJ(ppc405ICACHE_LINE_NUM)
        lwz     p1, LO(ppc405ICACHE_LINE_NUM)(p1)

cache405IcciNoGcx:
	li	p0, 0			/* clear p0 */
	mtctr	p1

        /* load cache line size */
        lis     p1, HIADJ(ppc405CACHE_ALIGN_SIZE)
        lwz     p1, LO(ppc405CACHE_ALIGN_SIZE)(p1)

cache405Icci:
	iccci   r0, p0
        add     p0, p0, p1              /* go to next cache line */

	bdnz	cache405Icci		/* go to invalidate */
	bclr	BO_ALWAYS, CR0_LT	/* return to the caller */

/*******************************************************************************
*
* cache405DCReset - reset the data cache
*
* All DCCR bits are reset to zero after system reset.  It is necessary to
* invalidate each congruence class in the cache before regions can be 
* designed as cacheable in the DCCR.  This routine should be called once
* at boot time.
* RETURNS: N/A

* void cache405DCReset ()

*/

FUNC_LABEL(cache405DCReset)
        /* load default cache lines number */
        lis     p1, HIADJ(ppc405DCACHE_LINE_NUM)
        lwz     p1, LO(ppc405DCACHE_LINE_NUM)(p1)


cache405DcciNoGcx:
	li	p0, 0			/* clear p0 */
	mtctr	p1

        /* load cache line size */
        lis     p1, HIADJ(ppc405CACHE_ALIGN_SIZE)
        lwz     p1, LO(ppc405CACHE_ALIGN_SIZE)(p1)

cache405Dcci:
	dccci   r0, p0

        add     p0, p0, p1              /* go to next cache line */

	bdnz	cache405Dcci		/* go to invalidate */
	bclr	BO_ALWAYS, CR0_LT	/* return to the caller */
