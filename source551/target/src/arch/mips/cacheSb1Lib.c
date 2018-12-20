/* cacheSb1Lib.c: Cache library for Broadcom SB-1 Core (L1) Caches */

/* Copyright 2002 Wind River Systems, Inc. */
#include "copyright_wrs.h"

/*********************************************************************
* 
*  Copyright 2000,2001
*  Broadcom Corporation. All rights reserved.
* 
*  This software is furnished under license to Wind River Systems, Inc.
*  and may be used only in accordance with the terms and conditions 
*  of this license.  No title or ownership is transferred hereby.
********************************************************************* */

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
01d,17may02,pes  Before aborting cacheTextUpdate() on null pointer, check for
                 ENTIRE_CACHE.
01c,08may02,pes  Add protection against null pointers, zero counts, and
                 requests involving kseg1 in cacheXXXTextUpdate().
01b,04dec01,agf  add Broadcom copyright notice
01a,14nov01,agf  created
*/

/*
DESCRIPTION
This library contains architecture-specific cache library functions for
the Broadcom Sb1 architecture.  The Sb1 utilizes a variable-size
instruction and data cache that operates in write-back (only) mode.  Cache
line size also varies.

For general information about caching, see the manual entry for cacheLib.

INCLUDE FILES: cacheLib.h

SEE ALSO: cacheLib
*/

#include "vxWorks.h"
#include "cacheLib.h"
#include "errnoLib.h"
#include "string.h"

/* constants */
#define L1CACHE_LINESIZE	32

/* forward declarations */

LOCAL STATUS cacheSb1Clear(CACHE_TYPE cache, void *pVirtAdrs, size_t bytes);
LOCAL STATUS cacheSb1TextUpdate(void *address, size_t bytes);
LOCAL STATUS cacheSb1PipeFlush(void);
LOCAL void * cacheSb1VirtToPhys(void *address);
LOCAL void * cacheSb1PhysToVirt(void *address);


/* imports */

void cacheSb1DCFlushInvalidateAll(void);
void cacheSb1DCFlushInvalidateLines(unsigned long addr, unsigned int lines);
void cacheSb1ICInvalidateAll(void);
void cacheSb1ICInvalidateLines(unsigned int addr, unsigned int lines);
void sysWbFlush(void);


/* globals */

IMPORT size_t cacheSb1ICacheSize;
IMPORT size_t cacheSb1DCacheSize;
IMPORT size_t cacheSb1ICacheLineSize;
IMPORT size_t cacheSb1DCacheLineSize;

/**************************************************************************
*
* cacheSb1LibInit - initialize the Sb1 cache library
*
* This routine initializes the function pointers for the Sb1 cache
* library.  The board support package can select this cache library
* by assigning the function pointer <sysCacheLibInit> to
* cacheSb1LibInit().
*
* RETURNS: OK.
*/

STATUS cacheSb1LibInit
    (
    CACHE_MODE  instMode,
    CACHE_MODE  dataMode,
    UINT32      iCacheSize,
    UINT32      iCacheLineSize,
    UINT32      dCacheSize,
    UINT32      dCacheLineSize
    )
    {

    /* assembly routines assume 32 byte line sizes */
    if ( (iCacheLineSize != L1CACHE_LINESIZE) ||
         (dCacheLineSize != L1CACHE_LINESIZE) )
	{
        errnoSet(EINVAL);
        return (ERROR);
	}

    cacheSb1ICacheSize = iCacheSize;
    cacheSb1DCacheSize = dCacheSize;
    cacheSb1ICacheLineSize = iCacheLineSize;
    cacheSb1DCacheLineSize = dCacheLineSize;


    /*
     * Assumes that the cache is already reset and that K0 is set to
     * one of the Coherent modes.
     */

    cacheLib.enableRtn = NULL;
    cacheLib.disableRtn = NULL;

    cacheLib.lockRtn = NULL;
    cacheLib.unlockRtn = NULL;

    cacheLib.flushRtn = NULL;                     /* sb1 caches are coherent */
    cacheLib.pipeFlushRtn = cacheSb1PipeFlush;
    cacheLib.textUpdateRtn = cacheSb1TextUpdate;

    cacheLib.invalidateRtn = NULL;                /* sb1 caches are coherent */
    cacheLib.clearRtn = cacheSb1Clear;

    cacheLib.dmaMallocRtn = NULL;
    cacheLib.dmaFreeRtn = NULL;

    cacheLib.dmaVirtToPhysRtn = (FUNCPTR) cacheSb1VirtToPhys;
    cacheLib.dmaPhysToVirtRtn = (FUNCPTR) cacheSb1PhysToVirt;


    cacheDataMode = dataMode;
    cacheDataEnabled = TRUE;
    cacheMmuAvailable = TRUE;

    cacheFuncsSet();

    return (OK);
    }


/**************************************************************************
*
* cacheSb1Clear - clear all or some entries in a cache
*
* This routine clears all or some of the entries in the
* specified cache.
*
* RETURNS: OK, or ERROR if the cache type is invalid or the cache control
* is not supported.
*/

LOCAL STATUS cacheSb1Clear
    (
    CACHE_TYPE cache, 
    void       *pVirtAdrs, 
    size_t     bytes
    )
    {
	unsigned int start, afterend;

	if (IS_KSEG1(pVirtAdrs) || bytes == 0)
		return(OK);

	switch (cache) 
	   {
	   case DATA_CACHE:
		/* XXX cutoff based on cache size? */
		if (bytes == ENTIRE_CACHE)
		    cacheSb1DCFlushInvalidateAll();
		else 
		    {
		    /* FlushInvalidate routine always assumes 32 byte line sizes */
		    start = ((unsigned long)pVirtAdrs) & ~31;
		    afterend =
			    (((unsigned long)pVirtAdrs + bytes - 1) | 31) + 1;

		    cacheSb1DCFlushInvalidateLines(start, 
                                                   (afterend - start) / 32);
		    }
		break;

	   case INSTRUCTION_CACHE:
		/* XXX cutoff based on cache size? */
		if (bytes == ENTIRE_CACHE)
			cacheSb1ICInvalidateAll();
		else
		    {
		    /* Invalidate routine always assumes 32 byte line sizes */
		    start = ((unsigned long)pVirtAdrs) & ~31;
		    afterend =
			    (((unsigned long)pVirtAdrs + bytes - 1) | 31) + 1;

		    cacheSb1ICInvalidateLines(start,
		                              (afterend - start) / 32);
		}
		break;

	   default:
		errno = S_cacheLib_INVALID_CACHE;
		return (ERROR);
		break;
	   }

    return (OK);
    }


/**************************************************************************
*
* cacheSb1VirtToPhys - virtual-to-physical address translation
*
* This routine may be attached to the CACHE_DRV structure virtToPhysRtn
* function pointer by cacheSb1Malloc().  This implies that the virtual
* memory library is not installed, and that the "cache-safe" buffer has
* been created through the use of the Sb1 K1 segment.
*
* NOMANUAL
*/

LOCAL void * cacheSb1VirtToPhys
    (
    void * address                      /* Virtual address */
    )
    {
    return ((void *) K1_TO_PHYS(address));
    }

/**************************************************************************
*
* cacheSb1PhysToVirt - physical-to-virtual address translation
*
* This routine may be attached to the CACHE_DRV structure physToVirtRtn
* function pointer by cacheSb1Malloc().  This implies that the virtual
* memory library is not installed, and that the "cache-safe" buffer has
* been created through the use of the Sb1 K1 segment.
*
* NOMANUAL
*/

LOCAL void * cacheSb1PhysToVirt
    (
    void * address                      /* Physical address */
    )
    {
    return ((void *) PHYS_TO_K1(address));
    }


/**************************************************************************
*
* cacheSb1TextUpdate - invalidate updated text section
*
* This routine invalidates the specified text section so that
* the correct updated text is executed.
*
* NOMANUAL
*/

LOCAL STATUS cacheSb1TextUpdate
    (
    void * address,
    size_t bytes
    )
    {
    if ((bytes != ENTIRE_CACHE) &&
	((address == NULL) || (bytes == 0) || IS_KSEG1(address)))
	return (OK);

    if (cacheSb1Clear(DATA_CACHE, address, bytes) != OK)
	return (ERROR);

    sysWbFlush();
    return (cacheSb1Clear(INSTRUCTION_CACHE, address, bytes));
    }


/**************************************************************************
*
* cacheSb1PipeFlush - flush Sb1 write buffers to memory
*
* This routine forces the processor output buffers to write their contents
* to RAM.  A cache flush may have forced its data into the write buffers,
* then the buffers need to be flushed to RAM to maintain coherency.
* It simply calls the sysWbFlush routine from the BSP.
*
* RETURNS: OK.
*
* NOMANUAL
*/

STATUS cacheSb1PipeFlush
    (
    void
    )
    {
    sysWbFlush();
    return (OK);
    }
