/* cache403ALib.s - assembly language cache handling routines */

/* Copyright 1984-1996 Wind River Systems, Inc. */
	.data
	.globl  copyright_wind_river
	.long   copyright_wind_river

/*
modification history
--------------------
01h,25sep01,yvp  Fix SPR62760: Use _WRS_TEXT_SEG_START macro instead of .align
01g,08may01,pch  Add assembler abstractions (FUNC_EXPORT, FUNC_BEGIN, etc.)
01f,26feb97,tam  added support for 403GCX.
01e,29oct96,tam  added a few comments.
01d,03sep96,tam  cleanup.
01c,14mar96,tam  fixed cache403ICReset(). Removed "#if (cpu==403)" statements.
01b,03feb95,caf  cleanup.
01a,02dec94,yao  created.
*/

/*
DESCRIPTION
This library contains routines to manipulate the 403 PowerPC family caches.

SEE ALSO: cacheLib
*/


#define _ASMLANGUAGE

#include "vxWorks.h"
#include "asm.h"
#include "arch/ppc/archPpc.h"

	/* globals */

	FUNC_EXPORT(cache403ICReset)
	FUNC_EXPORT(cache403DCReset)

	_WRS_TEXT_SEG_START
	
/*******************************************************************************
*
* cache403ICReset - reset the instruction cache
*
* All ICCR bits are reset to zero after system reset.  It is necessary to
* invalid date each congruence class in the cache before regions can be 
* designed as cacheable in the ICCR.  This routine should be called once
* at boot time.
* RETURNS: N/A

* void cache403ICReset ()

*/

FUNC_LABEL(cache403ICReset)
	li	p1, _ICACHE_LINE_NUM	/* load default cache lines number */
	mfspr   p0, PVR
	rlwinm  p0, p0, 24, 24, 31      /* extract CPU ID PVR[16:23] bits */
	cmpwi   p0, _PVR_CONF_403GCX
        bne	cache403IcciNoGcx
	slwi	p1, p1, 3		/* multiplies _ICACHE_LINE_NUM by 8 */
					/* 403GCX has cache 8 times larger */
cache403IcciNoGcx:
	li	p0, 0			/* clear p0 */
	mtctr	p1
cache403Icci:
	iccci   r0, p0
	addi	p0, p0, _CACHE_ALIGN_SIZE /* bump to next line */
	bdnz	cache403Icci		/* go to invalidate */
	bclr	BO_ALWAYS, CR0_LT	/* return to the caller */

/*******************************************************************************
*
* cache403DCReset - reset the data cache
*
* All DCCR bits are reset to zero after system reset.  It is necessary to
* invalidate each congruence class in the cache before regions can be 
* designed as cacheable in the DCCR.  This routine should be called once
* at boot time.
* RETURNS: N/A

* void cache403DCReset ()

*/

FUNC_LABEL(cache403DCReset)
	li	p1, _DCACHE_LINE_NUM	/* load default cache lines number */
	mfspr   p0, PVR
	rlwinm  p0, p0, 24, 24, 31      /* extract CPU ID PVR[16:23] bits */
	cmpwi   p0, _PVR_CONF_403GCX
        bne	cache403DcciNoGcx
	slwi	p1, p1, 3		/* multiplies _ICACHE_LINE_NUM by 8 */
					/* 403GCX has cache 8 times larger */
cache403DcciNoGcx:
	li	p0, 0			/* clear p0 */
	mtctr	p1
cache403Dcci:
	dccci   r0, p0
	addi	p0, p0, _CACHE_ALIGN_SIZE /* bump to next line */
	bdnz	cache403Dcci		/* go to invalidate */
	bclr	BO_ALWAYS, CR0_LT	/* return to the caller */
