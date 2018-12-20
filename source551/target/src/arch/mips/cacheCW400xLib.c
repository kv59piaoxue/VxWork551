/* cacheCW400xLib.c - LSI CW400x core cache management library */

/* Copyright 1996-2001 Wind River Systems, Inc. */
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
01i,17may02,pes  Before aborting cacheTextUpdate() on null pointer, check for
                 ENTIRE_CACHE.
01h,08may02,pes  Add protection against null pointers, zero counts, and
                 requests involving kseg1 in cacheXXXTextUpdate().
01g,16jul01,ros  add CofE comment
01f,28mar01,sru  remove CW400x-specific error codes
01e,10feb98,dra  changed Init, Enable & Disable to match CW4011
01d,10dec97,dra  added cache enable/disable funcs.
01c,17oct97,dra  made cache sizes, line masks depend on BSP.
01b,05may97,dra  fixed off by 1 error in end calc, fixed test for kseg1.
01a,09apr96,dra	 created
*/

/*
DESCRIPTION
This library contains architecture-specific cache library functions
for the LSI MIPS CW400x core architecture.  

ARCHITECTURE NOTES
General:
The CW400x cache is optional, as part of the BBCC building block for
the CW400x core.  The CC supports either direct-mapped or two-way set
associative I cache; D cache is always direct-mapped.  Icache can be
1k to 64kbytes (2 32kbyte sets); Dcache can be 1k to 32k.

The CW400x does allow locking of cache lines, by entering Software
Test Mode to set the lock bit. Cache lines can be written using loads
and stores in Software Test Mode.  Cache locking is not supported in
this library.

The cache always operates in write-through mode, so all clear
type operations map onto invalidate, and flush operations flush the
write buffer.

CW400x Specific:

For general information about caching, see the manual entry for cacheLib.

INCLUDE FILES: cacheLib.h

SEE ALSO: cacheCW400xALib, cacheLib
.I "LSI MiniRisc CW400x Microprocessor Core Technical Manual" */

#include "vxWorks.h"
#include "cacheLib.h"
#include "errnoLib.h"
#include "intLib.h"
#include "memLib.h"
#include "stdlib.h"
#include "errno.h"

/* CW400x specific defines */

/* Bits for BBCC config reg to enter Software Test Mode for cache mgmt */
#define	ICACHE_INV		(CFG_DCEN|CFG_ICEN|CFG_CMODE_ITEST)
#define IS1CACHE_INV		(CFG_DCEN|CFG_ICEN|CFG_CMODE_ITEST|CFG_IS1EN)
#define	DCACHE_INV		(CFG_DCEN|CFG_CMODE_DTEST)

/* Cache line size in bytes */
#define	CACHE_LINE_SIZE		(16)

/* externals */

IMPORT void    _cw4kCacheInvalidate(UINT configBits, UINT cacheLineMask, 
			       UINT startLine, UINT numLines);

IMPORT ULONG cacheCW400xicacheSet0Size;		/* BSP-specified */
IMPORT ULONG cacheCW400xicacheSet1;		/* BSP-specified */
IMPORT ULONG cacheCW400xdcacheSize;		/* BSP-specified */

/* forward declarations */

LOCAL STATUS	cacheCW400xEnable (CACHE_TYPE cache);
LOCAL STATUS	cacheCW400xDisable (CACHE_TYPE cache);
LOCAL void 	*cacheCW400xMalloc (size_t bytes);
LOCAL STATUS	cacheCW400xFree (void *pBuf);
LOCAL int	cacheCW400xWriteBufferFlush (void);
LOCAL STATUS	cacheCW400xInvalidate (CACHE_TYPE cache, void *pVirtAdrs, 
				       size_t bytes);
LOCAL void 	*cacheCW400xPhysToVirt (void *address);
LOCAL void 	*cacheCW400xVirtToPhys (void *address);
LOCAL STATUS	cacheCW400xTextUpdate (void *address, size_t bytes);
LOCAL ULONG	cacheLineMaskGet (ULONG cacheSize, ULONG cacheLineSize);
LOCAL void 	cacheAttributesGet (CACHE_TYPE cache, ULONG *pCacheSize,
				    ULONG *pCacheLineMask,
				    ULONG *pCacheEnableSetMask);

/* globals */

/* locals */

LOCAL ULONG icacheSize = 0;		/* computed during init */
LOCAL ULONG icacheLineMask = 0;		/* computed during init */
LOCAL ULONG icacheEnableSetMask = 0;	/* computed during init */
LOCAL ULONG dcacheSize = 0;		/* computed during init */
LOCAL ULONG dcacheLineMask = 0;		/* computed during init */
LOCAL ULONG dcacheEnableSetMask = 0;	/* computed during init */

/**************************************************************************
*
* cacheCW400xLibInit - initialize the LSI CW400x cache library
*
* This routine initializes the function pointers for the CW400x cache
* library.  The board support package can select this cache library 
* by calling this routine.
*
* RETURNS: OK.
*/

STATUS cacheCW400xLibInit
    (
    CACHE_MODE	instMode,	/* instruction cache mode */
    CACHE_MODE	dataMode	/* data cache mode */
    )
    {
    cacheLib.enableRtn = cacheCW400xEnable;		/* cacheEnable() */
    cacheLib.disableRtn = cacheCW400xDisable;		/* cacheDisable() */

    cacheLib.lockRtn = NULL;			/* cacheLock */
    cacheLib.unlockRtn = NULL;			/* cacheUnlock */

    cacheLib.flushRtn = cacheCW400xWriteBufferFlush;	/* cacheFlush() */
    cacheLib.pipeFlushRtn = cacheCW400xWriteBufferFlush;/* cachePipeFlush() */
    cacheLib.textUpdateRtn = cacheCW400xTextUpdate;/* cacheTextUpdate() */

    cacheLib.invalidateRtn = cacheCW400xInvalidate;/* cacheInvalidate() */
    cacheLib.clearRtn = cacheCW400xInvalidate;	/* cacheClear() */

    cacheLib.dmaMallocRtn = (FUNCPTR) cacheCW400xMalloc;/* cacheDmaMalloc() */
    cacheLib.dmaFreeRtn = cacheCW400xFree;		/* cacheDmaFree() */

    cacheLib.dmaVirtToPhysRtn = (FUNCPTR) cacheCW400xVirtToPhys;
    cacheLib.dmaPhysToVirtRtn = (FUNCPTR) cacheCW400xPhysToVirt;

    /* Setup cacheFuncs variables */
    cacheDataMode	= dataMode;		/* save dataMode for enable */
    cacheMmuAvailable	= TRUE;			/* mmu support is provided */
    cacheDataEnabled = TRUE;			/* d-cache is currently on */
    cacheFuncsSet ();				/* update cache func ptrs */

    /* Disable the caches - do this first. */
    cacheCW400xDisable(DATA_CACHE);
    cacheCW400xDisable(INSTRUCTION_CACHE);

    /* validate provided icache sizes, and compute useful constants */
    icacheSize = cacheCW400xicacheSet0Size;

    /* not valid to have set1 present if set0 size is 0 */
    if ((icacheSize == 0) && cacheCW400xicacheSet1) 
	{
	return (ERROR);
	}

    icacheLineMask = cacheLineMaskGet (icacheSize, CACHE_LINE_SIZE);
    if (icacheSize != 0 && icacheLineMask == 0)
        {
	return (ERROR);
	}
    icacheEnableSetMask = (cacheCW400xicacheSet0Size ? CFG_ICEN : 0) |
                          (cacheCW400xicacheSet1 ? CFG_IS1EN : 0);

    /* validate provided dcache sizes, and compute useful constants */
    dcacheSize = cacheCW400xdcacheSize;
    dcacheLineMask = cacheLineMaskGet (dcacheSize, CACHE_LINE_SIZE);
    if (dcacheSize != 0 && dcacheLineMask == 0)
        {
	return (ERROR);
	}
    dcacheEnableSetMask = (cacheCW400xdcacheSize ? CFG_DCEN : 0);

    /* Invalidate the caches */
    cacheCW400xInvalidate(DATA_CACHE, 0, ENTIRE_CACHE);
    cacheCW400xInvalidate(INSTRUCTION_CACHE, 0, ENTIRE_CACHE);

    return (OK);
    }

/**************************************************************************
*
* cacheCW400xEnable - enable the specificed cache.
*
* RETURNS: OK, or ERROR if the cache type is invalid.
*/

LOCAL STATUS	cacheCW400xEnable
    (
    CACHE_TYPE	cache			/* Cache to enable */
    )
    {
    int oldLevel;
    volatile ULONG *config = CFG4000_REG;

    switch (cache)
	{
	case DATA_CACHE:
	    oldLevel = intLock ();
	    cacheCW400xInvalidate(DATA_CACHE, 0, ENTIRE_CACHE);
	    *config |= dcacheEnableSetMask;
	    intUnlock (oldLevel);
	    break;

	case INSTRUCTION_CACHE:
	    oldLevel = intLock ();
	    cacheCW400xInvalidate(INSTRUCTION_CACHE, 0, ENTIRE_CACHE);
	    *config |= icacheEnableSetMask;
	    intUnlock (oldLevel);
	    break;

	default:
	    errno = S_cacheLib_INVALID_CACHE;
	    return (ERROR);
	}
    return (OK);
    }

/**************************************************************************
*
* cacheCW400xDisable - enable the specificed cache.
*
* RETURNS: OK, or ERROR if the cache type is invalid.
*/

LOCAL STATUS	cacheCW400xDisable
    (
    CACHE_TYPE	cache			/* Cache to disable */
    )
    {
    int oldLevel;
    volatile ULONG *config = CFG4000_REG;

    /*
     * Note that the xcacheEnableSetMask variables are not used for
     * disabling the caches.  This is because while the caches may not
     * be enabled in the BSP, the still need to be disabled here.
     */
    switch (cache)
	{
	case DATA_CACHE:
	    oldLevel = intLock ();
	    *config &= ~CFG_DCEN;
	    /*
	     * At this point we would normally set cacheDataEnabled false,
	     * and then call cacheFuncsSet() to update the cache pointers,
	     * but problems have been observed with some ethernet drivers
	     * if the cache "DMA malloc" routines are not used to allocate
	     * buffers for MIPS.
	     */
	    intUnlock (oldLevel);
	    break;

	case INSTRUCTION_CACHE:
	    oldLevel = intLock ();
	    *config &= ~(CFG_ICEN | CFG_IS1EN);
	    intUnlock (oldLevel);
	    break;

	default:
	    errno = S_cacheLib_INVALID_CACHE;
	    return (ERROR);
	}
    return (OK);
    }

/**************************************************************************
*
* cacheCW400xInvalidate - invalidate all or some entries in a cache
*
* This routine invalidates all or some of the entries in the
* specified cache.
*
* RETURNS: OK, or ERROR if the cache type is invalid or the cache control
* is not supported.
*/

LOCAL STATUS	cacheCW400xInvalidate
    (
    CACHE_TYPE	cache,			/* Cache to Invalidate */
    void *	address,		/* Virtual Address */
    size_t	bytes			/* Number of Bytes to Invalidate */
    )
    {
    ULONG cacheSize;
    ULONG cacheLineMask;
    ULONG cacheEnableSetMask;
    ULONG numLines;
    ULONG line;
    ULONG end;

    if (IS_KSEG1(address) || (bytes == 0)) 
	return (OK);

    cacheAttributesGet(cache, 
		       &cacheSize, &cacheLineMask, &cacheEnableSetMask);

    /* skip if no cache present */
    if (cacheSize == 0)
	return (OK);

    /* line and end are the (inclusive) start and end cache line addresses */
    line = ((ULONG) address) & cacheLineMask;
    end = (((ULONG) address) + bytes - 1) & cacheLineMask;

    if ((bytes == ENTIRE_CACHE)
	|| (bytes >= cacheSize)
	|| ((line == end) && (bytes > CACHE_LINE_SIZE)))
        {
	/* Invalidate the entire cache */
	line = 0;
	numLines = cacheSize / CACHE_LINE_SIZE;
	}
    else
	{
	numLines = (end >= line)
	    ? (((end - line) / CACHE_LINE_SIZE) + 1)
		: (((cacheSize - (line - end)) / CACHE_LINE_SIZE) + 1);
	}

    switch (cache)
	{
	case DATA_CACHE:
	    _cw4kCacheInvalidate(DCACHE_INV, cacheLineMask, line, numLines);
	    break;

	case INSTRUCTION_CACHE:
	    _cw4kCacheInvalidate(ICACHE_INV, cacheLineMask, line, numLines);
	    if (cacheCW400xicacheSet1 != 0)
		_cw4kCacheInvalidate(IS1CACHE_INV,
				     cacheLineMask, line, numLines);
	    break;

	default:
	    errno = S_cacheLib_INVALID_CACHE;
	    return (ERROR);
	}
    return (OK);
    }

/**************************************************************************
*
* cacheCW400xMalloc - allocate a cache-safe buffer, if possible
*
* This routine will attempt to return a pointer to a section of memory
* that will not experience any cache coherency problems.  It also sets
* the flush and invalidate function pointers to NULL or to the respective
* flush and invalidate routines.  Since the cache is write-through, the
* flush function pointer will always be NULL.
*
* RETURNS: A pointer to the non-cached buffer, or NULL.
*/

LOCAL void * cacheCW400xMalloc
    (
    size_t bytes 
    )
    {
    char * pBuffer;

    if ((pBuffer = (char *) malloc (bytes)) == NULL)
	return ((void *) pBuffer);
    else
	return ((void *) K0_TO_K1(pBuffer));
    }

/**************************************************************************
*
* cacheCW400xFree - free the buffer acquired by cacheMalloc ()
*
* This routine restores the non-cached buffer to its original state
* and does whatever else is necessary to undo the allocate function.
*
* RETURNS: OK, or ERROR if not able to undo cacheMalloc() operation
*/

LOCAL STATUS cacheCW400xFree
    (
    void * pBuf 
    )
    {
    free ((void *) K1_TO_K0(pBuf));
    return (OK);
    }

/**************************************************************************
*
* cacheCW400xVirtToPhys - virtual-to-physical address translation
*
* This routine may be attached to the CACHE_DRV structure virtToPhysRtn
* function pointer by cacheCW400xMalloc().  This implies that the virtual
* memory library is not installed, and that the "cache-safe" buffer has
* been created through the use of the CW400x K1 segment.
*
* NOMANUAL
*/

LOCAL void * cacheCW400xVirtToPhys
    (
    void * address			/* Virtual address */
    )
    {
    return ((void *) K1_TO_PHYS(address));
    }

/**************************************************************************
*
* cacheCW400xPhysToVirt - physical-to-virtual address translation
*
* This routine may be attached to the CACHE_DRV structure physToVirtRtn
* function pointer by cacheCW400xMalloc().  This implies that the virtual
* memory library is not installed, and that the "cache-safe" buffer has
* been created through the use of the K1 segment.
*
* NOMANUAL
*/

LOCAL void * cacheCW400xPhysToVirt
    (
    void * address			/* Physical address */
    )
    {
    return ((void *) PHYS_TO_K1(address));
    }

/**************************************************************************
*
* cacheCW400xTextUpdate - invalidate updated text section
*
* This routine invalidates the specified text section so that
* the correct updated text is executed.
*
* NOMANUAL
*/

LOCAL STATUS cacheCW400xTextUpdate
    (
    void * address,			/* Physical address */
    size_t bytes			/* bytes to invalidate */
    )
    {
    if ((bytes != ENTIRE_CACHE) &&
	((address == NULL) || (bytes == 0) || IS_KSEG1(address)))
	return (OK);
    
    return (cacheCW400xInvalidate (INSTRUCTION_CACHE, address, bytes));
    }

/**************************************************************************
*
* cacheCW400xWriteBufferFlush - flush the write buffer
*
* This routine forces a flush of the write buffer.  Setting and then
* using a volative variable is sufficient to generate assembly code
* that will force a sequence point, and that will force the write back
* buffer to flush. Since the CW400x core cache only operates in
* writeback mode, this is sufficient to flush the cache.
*
* RETURNS: OK
*
* NOMANUAL
*/

LOCAL STATUS cacheCW400xWriteBufferFlush (void)
    {
    volatile STATUS x;

    /* The following is kludgy, but works... */
    x = OK - 1;
    return (x + 1);
    }


/**************************************************************************
*
* cacheLineMaskGet - returns cache line mask based upon cache size.
*
* This routine computes a bit mask which can be used to determine the 
* cache line address which corresponds to a memory address.  A mask 
* value of "0" is returned if the cache size is not valid.
* cacheLineMask = (CACHE_SIZE/CACHE_LINE_SIZE)-1 << log2(CACHE_LINE_SIZE)
*
* NOMANUAL
*  
*/

LOCAL ULONG cacheLineMaskGet
    (
    ULONG cacheSize,		/* in bytes */
    ULONG cacheLineSize		/* in bytes */
    )
    {
    UINT logLineSize = 0;
    UINT lsize = cacheLineSize;

    if (cacheSize == 0 || cacheLineSize == 0)
        return 0;
    
    while ((lsize = lsize >> 1) > 0)
        logLineSize++;

    return (K0BASE | (((cacheSize / cacheLineSize) - 1) << logLineSize));
    }


/**************************************************************************
*
* cacheAttributesGet - returns (globally stored) cache attributes.
*
* The globally stored cache attributes are returned to the caller via
* data pointers, based upon the requested cache type.
*
* NOMANUAL
*  
*/

LOCAL void cacheAttributesGet
    (
    CACHE_TYPE	cache,
    ULONG	*pCacheSize,
    ULONG	*pCacheLineMask,
    ULONG	*pCacheEnableSetMask
    )
    {
    switch (cache)
	{
	case DATA_CACHE:
	    *pCacheSize = dcacheSize;
	    *pCacheLineMask = dcacheLineMask;
	    *pCacheEnableSetMask = dcacheEnableSetMask;
	    break;

	case INSTRUCTION_CACHE:
	    *pCacheSize = icacheSize;
	    *pCacheLineMask = icacheLineMask;
	    *pCacheEnableSetMask = icacheEnableSetMask;
	    break;

        default:
	    *pCacheSize = 0;
	    *pCacheLineMask = 0;
	    *pCacheEnableSetMask = 0;
	    break;
	}
    }
