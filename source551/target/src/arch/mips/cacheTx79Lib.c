/* cacheTx79Lib.c - Toshiba Tx79 cache management library */

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
01b,30sep02,jmt  Modify to resolve code review issues
01a,14aug02,jmt  derived from cacheTx49Lib.c (01b,09may02,jmt).
*/

/*
DESCRIPTION
This library contains architecture-specific cache library functions for
the Toshiba Tx79 architecture.  The Tx79 utilizes a fixed-size instruction
and data cache that operates in write-back mode.  The cache is two-way set
associative and the library allows the cache and cache line size to vary.

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
LOCAL STATUS	cacheTx79Flush (CACHE_TYPE cache, void * pVirtAdrs,
			        size_t bytes);
LOCAL STATUS	cacheTx79Invalidate (CACHE_TYPE cache, void * pVirtAdrs, 
                                     size_t bytes);
LOCAL STATUS	cacheTx79Clear (CACHE_TYPE cache, void * pVirtAdrs, 
                                size_t bytes);
LOCAL STATUS 	cacheTx79TextUpdate (void * address, size_t bytes);

/* imports */

IMPORT void	sysWbFlush (void);

/* imports from cacheMipsLib.c */
IMPORT void *	cacheMipsMalloc (size_t bytes);
IMPORT STATUS	cacheMipsFree (void * pBuf);
IMPORT void * 	cacheMipsPhysToVirt (void * address);
IMPORT void * 	cacheMipsVirtToPhys (void * address);
IMPORT STATUS	cacheMipsPipeFlush (void);

/* imports from cacheTx79ALib.s */
IMPORT void     cacheTx79DCFlushInvalidate(void * address, size_t byteCount);
IMPORT void     cacheTx79DCFlushInvalidateAll(void);
IMPORT void     cacheTx79DCInvalidate(void * address, size_t byteCount);
IMPORT void     cacheTx79DCInvalidateAll(void);
IMPORT void     cacheTx79DCFlush(void * address, size_t byteCount);
IMPORT void     cacheTx79DCFlushAll(void);
IMPORT void     cacheTx79PTextUpdate(void * address, size_t byteCount);
IMPORT void     cacheTx79PTextUpdateAll(void);
IMPORT void     cacheTx79ICInvalidate(void * address, size_t byteCount);
IMPORT void     cacheTx79ICInvalidateAll(void);

#ifdef IS_KSEGM
IMPORT void	cacheTx79Sync (void * vAddr, UINT len);
IMPORT void	cacheTx79VirtPageFlush (UINT asid, void * vAddr, UINT len);

IMPORT VOIDFUNCPTR _func_mipsCacheSync;
IMPORT VOIDFUNCPTR _func_mmuMipsVirtPageFlush;
#endif /* IS_KSEGM */

/* globals */

IMPORT UINT32 cacheTx79ICacheSize;      /* Instruction Cache Size */
IMPORT UINT32 cacheTx79DCacheSize;      /* Data Cache Size */
IMPORT UINT32 cacheTx79ICacheLineSize;  /* Instruction Cache Line Size */
IMPORT UINT32 cacheTx79DCacheLineSize;  /* Data Cache Line Size */

/**************************************************************************
*
* cacheTx79LibInit - initialize the Tx79 cache library
*
* This routine initializes the function pointers for the Tx79 cache
* library.  The board support package can select this cache library 
* by assigning the function pointer <sysCacheLibInit> to
* cacheTx79LibInit().
*
* RETURNS: OK.
*/

STATUS cacheTx79LibInit
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

    cacheTx79ICacheSize = iCacheSize;
    cacheTx79DCacheSize = dCacheSize;
    cacheTx79ICacheLineSize = iCacheLineSize;
    cacheTx79DCacheLineSize = dCacheLineSize;

    /* setup Cache Library functions for this library */

    cacheLib.enableRtn = NULL;	/* cacheEnable() */
    cacheLib.disableRtn = NULL;	/* cacheDisable() */

    cacheLib.lockRtn = NULL;                     /* cacheLock */
    cacheLib.unlockRtn = NULL;                   /* cacheUnlock */

    cacheLib.flushRtn = cacheTx79Flush;          /* cacheFlush() */
    cacheLib.pipeFlushRtn = cacheMipsPipeFlush;	 /* cachePipeFlush() */
    cacheLib.textUpdateRtn = cacheTx79TextUpdate;/* cacheTextUpdate() */

    cacheLib.invalidateRtn = cacheTx79Invalidate;/* cacheInvalidate() */
    cacheLib.clearRtn = cacheTx79Clear;          /* cacheClear() */

    cacheLib.dmaMallocRtn = (FUNCPTR) cacheMipsMalloc;  /* cacheDmaMalloc() */
    cacheLib.dmaFreeRtn = cacheMipsFree;                /* cacheDmaFree() */

#ifdef IS_KSEGM
    if (!IS_KSEGM(cacheTx79LibInit))
	{
	cacheLib.dmaVirtToPhysRtn = (FUNCPTR) cacheMipsVirtToPhys;
	cacheLib.dmaPhysToVirtRtn = (FUNCPTR) cacheMipsPhysToVirt;
	_func_mipsCacheSync = (VOIDFUNCPTR) cacheTx79Sync;
	}
    else
	{
	_func_mipsCacheSync = (VOIDFUNCPTR) KM_TO_K0(cacheTx79Sync);
	_func_mmuMipsVirtPageFlush = (VOIDFUNCPTR) cacheTx79VirtPageFlush;
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
* cacheTx79Flush - flush all or some entries in a cache
*
* This routine flushes (writes to memory)  all or some of the entries in the
* specified cache.
*
* RETURNS: OK, or ERROR if the cache type is invalid or the cache control
* is not supported.
*/

LOCAL STATUS	cacheTx79Flush
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
		cacheTx79DCFlushAll ();
	    else
		cacheTx79DCFlush (pVirtAdrs, bytes);
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
* cacheTx79Clear - flush and invalidate all or some entries in a cache
*
* This routine flushes (writes to memory) and invalidates all or some of
* the entries in the specified cache.
*
* RETURNS: OK, or ERROR if the cache type is invalid or the cache control
* is not supported.
*/

LOCAL STATUS	cacheTx79Clear
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
		cacheTx79DCFlushInvalidateAll ();
	    else
		cacheTx79DCFlushInvalidate (pVirtAdrs, bytes);
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
* cacheTx79Invalidate - invalidate all or some entries in a cache
*
* This routine invalidates all or some of the entries in the
* specified cache.
*
* RETURNS: OK, or ERROR if the cache type is invalid or the cache control
* is not supported.
*/

LOCAL STATUS	cacheTx79Invalidate
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
		cacheTx79DCInvalidateAll ();
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
		    cacheTx79DCFlushInvalidate(pVirtAdrs, bytesSec1);

		/* if there are any, Invalidate full cache lines */

		if (bytesSec2 > 0)
		    cacheTx79DCInvalidate (pSec2, bytesSec2);

		/* if end does not completely fill a cache line
		 * flush invalidate partial line
		 */

		if (bytesSec3 > 0)
		    cacheTx79DCFlushInvalidate(pSec3, bytesSec3);
		}
	    break;
	case INSTRUCTION_CACHE:
	    if (bytes == ENTIRE_CACHE)
		cacheTx79ICInvalidateAll ();
	    else
		cacheTx79ICInvalidate (pVirtAdrs, bytes);
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
* cacheTx79TextUpdate - flush and invalidate updated text section
*
* This routine flushes and invalidates the specified text section so that
* the correct updated text is executed.
*
* NOMANUAL
*/

LOCAL STATUS cacheTx79TextUpdate
    (
    void * address,                     /* Physical address */
    size_t bytes 			/* bytes to invalidate */
    )
    {
    if ((bytes != ENTIRE_CACHE) &&
        ((address == NULL) || (bytes == 0) || IS_KSEG1(address)))
        return (OK);

    if (bytes == ENTIRE_CACHE)
       cacheTx79PTextUpdateAll ();
    else
       cacheTx79PTextUpdate (address, bytes);

    return (OK);
    }
