/* cacheTx49Lib.c - Toshiba Tx49 cache management library */

/* Copyright 1984-2002 Wind River Systems, Inc. */
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
01b,09may02,jmt  modified to fix problems found in code review
01a,23apr02,jmt  derived from cacheR4kLib.c (01l,16jul01,ros).
*/

/*
DESCRIPTION
This library contains architecture-specific cache library functions for
the Toshiba Tx49 architecture.  The Tx49 utilizes a variable-size
instruction and data cache that operates in write-back mode.  The cache is
four-way set associative and the library allows the cache line size to vary.

For general information about caching, see the manual entry for cacheLib.

INCLUDE FILES: cacheLib.h

SEE ALSO: cacheLib
*/

/* includes */

#include	"vxWorks.h"
#include	"cacheLib.h"
#include	"memLib.h"
#include	"stdlib.h"
#include	"errno.h"
#include        "errnoLib.h"
#ifdef IS_KSEGM
#include        "memPartLib.h"
#include        "arch/mips/mmuMipsLib.h"
#endif /* IS_KSEGM */
#include        "private/vmLibP.h"
#include        "private/funcBindP.h"

/* forward declarations */
LOCAL STATUS	cacheTx49Flush (CACHE_TYPE cache, void * pVirtAdrs,
			        size_t bytes);
LOCAL STATUS	cacheTx49Invalidate (CACHE_TYPE cache, void * pVirtAdrs, 
                                     size_t bytes);
LOCAL STATUS	cacheTx49Clear (CACHE_TYPE cache, void * pVirtAdrs, 
                                size_t bytes);
LOCAL STATUS 	cacheTx49TextUpdate (void * address, size_t bytes);

/* imports */

IMPORT void	sysWbFlush (void);

/* imports from cacheMipsLib.c */
IMPORT void *	cacheMipsMalloc (size_t bytes);
IMPORT STATUS	cacheMipsFree (void * pBuf);
IMPORT void * 	cacheMipsPhysToVirt (void * address);
IMPORT void * 	cacheMipsVirtToPhys (void * address);
IMPORT STATUS	cacheMipsPipeFlush (void);

/* imports from cacheTx49ALib.s */
IMPORT void     cacheTx49DCFlushInvalidate(void * address, size_t byteCount);
IMPORT void     cacheTx49DCFlushInvalidateAll(void);
IMPORT void     cacheTx49DCInvalidate(void * address, size_t byteCount);
IMPORT void     cacheTx49DCInvalidateAll(void);
IMPORT void     cacheTx49DCFlush(void * address, size_t byteCount);
IMPORT void     cacheTx49DCFlushAll(void);
IMPORT void     cacheTx49PTextUpdate(void * address, size_t byteCount);
IMPORT void     cacheTx49PTextUpdateAll(size_t iCacheSize,
					size_t iCacheLineSize,
					size_t dCacheSize,
					size_t dCacheLineSize);
IMPORT void     cacheTx49ICInvalidate(void * address, size_t byteCount);
IMPORT void     cacheTx49ICInvalidateAll(void);

#ifdef IS_KSEGM
IMPORT void	cacheTx49Sync (void * vAddr, UINT len);
IMPORT void	cacheTx49VirtPageFlush (UINT asid, void * vAddr, UINT len);

IMPORT VOIDFUNCPTR _func_mipsCacheSync;
IMPORT VOIDFUNCPTR _func_mmuMipsVirtPageFlush;
#endif /* IS_KSEGM */

/* globals */

IMPORT UINT32 cacheTx49ICacheSize;      /* Instruction Cache Size */
IMPORT UINT32 cacheTx49DCacheSize;      /* Data Cache Size */
IMPORT UINT32 cacheTx49ICacheLineSize;  /* Instruction Cache Line Size */
IMPORT UINT32 cacheTx49DCacheLineSize;  /* Data Cache Line Size */

/**************************************************************************
*
* cacheTx49LibInit - initialize the Tx49 cache library
*
* This routine initializes the function pointers for the Tx49 cache
* library.  The board support package can select this cache library 
* by assigning the function pointer <sysCacheLibInit> to
* cacheTx49LibInit().
*
* RETURNS: OK.
*/

STATUS cacheTx49LibInit
    (
    CACHE_MODE	instMode,	/* instruction cache mode */
    CACHE_MODE	dataMode,	/* data cache mode */
    UINT32	iCacheSize,     /* instruction cache size */
    UINT32	iCacheLineSize, /* instruction cache line size */
    UINT32	dCacheSize,     /* data cache size */
    UINT32	dCacheLineSize  /* data cache line size */
    )
    {
    /* save cache sizes.  No secondary cache is supported */

    cacheTx49ICacheSize = iCacheSize;
    cacheTx49DCacheSize = dCacheSize;
    cacheTx49ICacheLineSize = iCacheLineSize;
    cacheTx49DCacheLineSize = dCacheLineSize;

    /* setup Cache Library functions for this library */

    cacheLib.enableRtn = NULL;	/* cacheEnable() */
    cacheLib.disableRtn = NULL;	/* cacheDisable() */

    cacheLib.lockRtn = NULL;                     /* cacheLock */
    cacheLib.unlockRtn = NULL;                   /* cacheUnlock */

    cacheLib.flushRtn = cacheTx49Flush;          /* cacheFlush() */
    cacheLib.pipeFlushRtn = cacheMipsPipeFlush;	 /* cachePipeFlush() */
    cacheLib.textUpdateRtn = cacheTx49TextUpdate;/* cacheTextUpdate() */

    cacheLib.invalidateRtn = cacheTx49Invalidate;/* cacheInvalidate() */
    cacheLib.clearRtn = cacheTx49Clear;          /* cacheClear() */

    cacheLib.dmaMallocRtn = (FUNCPTR) cacheMipsMalloc;  /* cacheDmaMalloc() */
    cacheLib.dmaFreeRtn = cacheMipsFree;                /* cacheDmaFree() */

#ifdef IS_KSEGM
    if (!IS_KSEGM(cacheTx49LibInit))
	{
	cacheLib.dmaVirtToPhysRtn = (FUNCPTR) cacheMipsVirtToPhys;
	cacheLib.dmaPhysToVirtRtn = (FUNCPTR) cacheMipsPhysToVirt;
	_func_mipsCacheSync = (VOIDFUNCPTR) cacheTx49Sync;
	}
    else
	{
	_func_mipsCacheSync = (VOIDFUNCPTR) KM_TO_K0(cacheTx49Sync);
	_func_mmuMipsVirtPageFlush = (VOIDFUNCPTR) cacheTx49VirtPageFlush;
	}
#else /* IS_KSEGM */
    cacheLib.dmaVirtToPhysRtn = (FUNCPTR) cacheMipsVirtToPhys;
    cacheLib.dmaPhysToVirtRtn = (FUNCPTR) cacheMipsPhysToVirt;
#endif /* IS_KSEGM */

    cacheDataMode	= dataMode;		/* save dataMode for enable */
    cacheDataEnabled	= TRUE;			/* d-cache is currently on */
    cacheMmuAvailable	= TRUE;			/* mmu support is provided */

    cacheFuncsSet ();				/* update cache func ptrs */

    return (OK);
    }

/**************************************************************************
*
* cacheTx49Flush - flush all or some entries in a cache
*
* This routine flushes (writes to memory)  all or some of the entries in the
* specified cache.
*
* RETURNS: OK, or ERROR if the cache type is invalid or the cache control
* is not supported.
*/

LOCAL STATUS	cacheTx49Flush
    (
    CACHE_TYPE	cache,			/* Cache to Invalidate */
    void *	pVirtAdrs,		/* Virtual Address */
    size_t	bytes 			/* Number of Bytes to Invalidate */
    )
    {
    if (IS_KSEG1 (pVirtAdrs))
	return (OK);
    switch (cache)
	{
	case DATA_CACHE:
	    if (bytes == ENTIRE_CACHE)
		cacheTx49DCFlushAll ();
	    else
		cacheTx49DCFlush (pVirtAdrs, bytes);
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
* cacheTx49Clear - flush and invalidate all or some entries in a cache
*
* This routine flushes (writes to memory) and invalidates all or some of
* the entries in the specified cache.
*
* RETURNS: OK, or ERROR if the cache type is invalid or the cache control
* is not supported.
*/

LOCAL STATUS	cacheTx49Clear
    (
    CACHE_TYPE	cache,			/* Cache to Invalidate */
    void *	pVirtAdrs,		/* Virtual Address */
    size_t	bytes 			/* Number of Bytes to Invalidate */
    )
    {
    if (IS_KSEG1 (pVirtAdrs))
	return (OK);
    switch (cache)
	{
	case DATA_CACHE:
	    if (bytes == ENTIRE_CACHE)
		cacheTx49DCFlushInvalidateAll ();
	    else
		cacheTx49DCFlushInvalidate (pVirtAdrs, bytes);
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
* cacheTx49Invalidate - invalidate all or some entries in a cache
*
* This routine invalidates all or some of the entries in the
* specified cache.
*
* RETURNS: OK, or ERROR if the cache type is invalid or the cache control
* is not supported.
*/

LOCAL STATUS	cacheTx49Invalidate
    (
    CACHE_TYPE	cache,			/* Cache to Invalidate */
    void *	pVirtAdrs,		/* Virtual Address */
    size_t	bytes 			/* Number of Bytes to Invalidate */
    )
    {
    void * pSec2;
    void * pSec3;
    int bytesSec1;
    int bytesSec2;
    int bytesSec3;
    
    if (IS_KSEG1 (pVirtAdrs))
	return (OK);
    switch (cache)
	{
	case DATA_CACHE:
	    if (bytes == ENTIRE_CACHE)
		cacheTx49DCInvalidateAll ();
	    else
		{
		/* Break up into three sections
		 *   1.  partial cache line at beginning
		 *   2.  all the full cache lines
		 *   3.  partial cache line at end
		 */

		pSec2 = (void *) CACHE_ROUND_UP(pVirtAdrs);
		pSec3 = (void *) CACHE_ROUND_DOWN((int) pVirtAdrs + bytes);
		bytesSec1 = ((int) pSec2 - (int) pVirtAdrs);
		bytesSec3 = ((int) pVirtAdrs + bytes - (int) pSec3);
		bytesSec2 = bytes - bytesSec1 - bytesSec3;

		/* if start address is not cache line aligned,
		 * flush invalidate partial line
		 */

		if (bytesSec1 > 0)
		    cacheTx49DCFlushInvalidate(pVirtAdrs, bytesSec1);

		/* if there are any, Invalidate full cache lines */

		if (bytesSec2 > 0)
		    cacheTx49DCInvalidate (pSec2, bytesSec2);

		/* if end does not completely fill a cache line
		 * flush invalidate partial line
		 */

		if (bytesSec3 > 0)
		    cacheTx49DCFlushInvalidate(pSec3, bytesSec3);
		}
	    break;
	case INSTRUCTION_CACHE:
	    if (bytes == ENTIRE_CACHE)
		cacheTx49ICInvalidateAll ();
	    else
		cacheTx49ICInvalidate (pVirtAdrs, bytes);
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
* cacheTx49TextUpdate - flush and invalidate updated text section
*
* This routine flushes and invalidates the specified text section so that
* the correct updated text is executed.
*
* NOMANUAL
*/

LOCAL STATUS cacheTx49TextUpdate
    (
    void * address,                     /* Physical address */
    size_t bytes 			/* bytes to invalidate */
    )
    {
    if ((bytes != ENTIRE_CACHE) &&
        ((address == NULL) || (bytes == 0) || IS_KSEG1(address)))
        return (OK);

    if (bytes == ENTIRE_CACHE)
       cacheTx49PTextUpdateAll (cacheTx49ICacheSize,
				cacheTx49ICacheLineSize,
				cacheTx49DCacheSize,
				cacheTx49DCacheLineSize);
    else
       cacheTx49PTextUpdate (address, bytes);

    return (OK);
    }


