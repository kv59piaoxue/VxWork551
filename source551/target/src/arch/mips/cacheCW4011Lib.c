/* cacheCW4011Lib.c - LSI CW4011 cache management library */

/* Copyright 1997-2001 Wind River Systems, Inc. */
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
01h,17may02,pes  Before aborting cacheTextUpdate() on null pointer, check for
                 ENTIRE_CACHE.
01g,08may02,pes  Add protection against null pointers, zero counts, and
                 requests involving kseg1 in cacheXXXTextUpdate().
01f,16jul01,ros  add CofE comment
01e,08jan98,dra  Rewritten to support cacheEnable and cacheDisable.
01d,07may97,dra  Substantially rewritten (separate flush & invalidate).
01c,22apr97,dra	 Now sets instMode and dataMode cache modes correctly.
01b,25mar97,dra  Updates to match CW4011 hardware.
01a,21feb97,dra	 created, based on cacheCW4kLib.c
*/

/*
DESCRIPTION
This library contains architecture-specific cache library functions
for the LSI MIPS CW4011 architecture.  

ARCHITECTURE NOTES
General:
The CW4011 cache is optional.  If present, both the I and D caches can
be from 1K to 16K in size; each cache can be composed of one or two
sets.  With a single set, the cache is direct mapped.  With two sets,
the cache becomes two-way set associative.  Each set can be 1K, 2K,
4K, or 8K in size, however for two-way set associative cache layouts,
both sets must be the same size.

The data cache can operate in either writethrough or copyback mode,
so support for flushing the cache is provided.

For general information about caching, see the manual entry for cacheLib.

INCLUDE FILES: cacheLib.h

SEE ALSO: cacheCW4011ALib, cacheLib
.I "LSI MiniRISC CW4011 Superscalar  Microprocessor Core Technical Manual" 
*/

/* includes */

#include "vxWorks.h"
#include "cacheLib.h"
#include "errnoLib.h"
#include "intLib.h"
#include "memLib.h"
#include "stdlib.h"
#include "errno.h"

/* defines */

#define CACHE_LINE_SIZE CACHE_CW4011_LINE_SIZE

/* externals */

IMPORT void	_cw4011InvalidateAll (CACHE_TYPE cacheType, ULONG configBits);
IMPORT void   	_cw4011Invalidate (ULONG configBits, ULONG cacheLineMask,
				   ULONG startLine, ULONG numLines,
				   ULONG startAdr, ULONG endAdr);
IMPORT void	_cw4011Flush (ULONG configBits, ULONG cacheLineMask,
			      ULONG startLine, ULONG numLines);
IMPORT void	_cw4011FlushAndDisable (ULONG configBits);
IMPORT ULONG	_cw4011ConfigGet (void);
IMPORT void	_cw4011ConfigSet (ULONG);

IMPORT ULONG	cacheCW4011icacheSet0Size;	/* BSP-specified */
IMPORT ULONG	cacheCW4011icacheSet1;		/* BSP-specified */
IMPORT ULONG	cacheCW4011dcacheSet0Size;	/* BSP-specified */
IMPORT ULONG	cacheCW4011dcacheSet1;		/* BSP-specified */

/* forward declarations */

LOCAL STATUS	cacheCW4011Enable (CACHE_TYPE cache);
LOCAL STATUS	cacheCW4011Disable (CACHE_TYPE cache);
LOCAL void 	*cacheCW4011Malloc (size_t bytes);
LOCAL STATUS	cacheCW4011Free (void *pBuf);
LOCAL STATUS	cacheCW4011Clear (CACHE_TYPE cache, void *pVirtAdrs, 
				  size_t bytes);
LOCAL STATUS	cacheCW4011Flush (CACHE_TYPE cache, void *pVirtAdrs, 
				  size_t bytes);
LOCAL STATUS	cacheCW4011WriteBufferFlush (void);
LOCAL STATUS	cacheCW4011Invalidate (CACHE_TYPE cache, void *pVirtAdrs, 
				       size_t bytes);
LOCAL void 	*cacheCW4011PhysToVirt (void *address);
LOCAL void 	*cacheCW4011VirtToPhys (void *address);
LOCAL STATUS	cacheCW4011TextUpdate (void *address, size_t bytes);
LOCAL ULONG	cacheLineMaskGet (ULONG cacheSize);
LOCAL ULONG	cacheSizeDescGet (ULONG cacheSize);
LOCAL void 	cacheAttributesGet (CACHE_TYPE cache, ULONG *pCacheSize,
				    ULONG *pCacheLineMask,
				    ULONG *pCacheEnableSetMask);

/* locals */

LOCAL ULONG	icacheSize = 0;			/* computed during init */
LOCAL ULONG	icacheLineMask = 0;		/*     "      "     "   */
LOCAL ULONG	icacheEnableSetMask = 0;	/*     "      "     "   */
LOCAL ULONG	dcacheSize = 0;			/*     "      "     "   */
LOCAL ULONG	dcacheLineMask = 0;		/*     "      "     "   */
LOCAL ULONG	dcacheEnableSetMask = 0;	/*     "      "     "   */

/**************************************************************************
*
* cacheCW4011LibInit - initialize the LSI CW4011 cache library
*
* This routine initializes the function pointers for the CW4011 cache
* library.  The board support package can select this cache library 
* by calling this routine.  The caches are assumed to be disabled 
* when this routine is called, and are left disabled.  cacheCW4011Enable
* is used to actually enable the caches.
*
* RETURNS: OK, or errors if the requested cache configuration is invalid.
*/

STATUS cacheCW4011LibInit
    (
    CACHE_MODE	instMode,	/* instruction cache mode */
    CACHE_MODE	dataMode	/* data cache mode */
    )
    {
    ULONG config;

    cacheLib.enableRtn 	      = cacheCW4011Enable;	/* cacheEnable() */
    cacheLib.disableRtn       = cacheCW4011Disable;	/* cacheDisable() */

    cacheLib.lockRtn 	      = NULL;			/* cacheLock */
    cacheLib.unlockRtn 	      = NULL;			/* cacheUnlock */

    cacheLib.flushRtn 	      = cacheCW4011Flush;	/* cacheFlush() */
    cacheLib.pipeFlushRtn     = cacheCW4011WriteBufferFlush;/*cachePipeFlush()*/
    cacheLib.textUpdateRtn    = cacheCW4011TextUpdate;	/* cacheTextUpdate() */

    cacheLib.invalidateRtn    = cacheCW4011Invalidate;	/* cacheInvalidate() */
    cacheLib.clearRtn 	      = cacheCW4011Clear;	/* cacheClear() */

    cacheLib.dmaMallocRtn     = (FUNCPTR) cacheCW4011Malloc;/*cacheDmaMalloc()*/
    cacheLib.dmaFreeRtn       = cacheCW4011Free;	/* cacheDmaFree() */

    cacheLib.dmaVirtToPhysRtn = (FUNCPTR) cacheCW4011VirtToPhys;
    cacheLib.dmaPhysToVirtRtn = (FUNCPTR) cacheCW4011PhysToVirt;

    cacheDataMode	      = dataMode;	/* save dataMode for enable */
    cacheMmuAvailable	      = TRUE;		/* mmu support is provided */

    /* validate icache size and set request */

    if ((cacheCW4011icacheSet0Size == 0) && cacheCW4011icacheSet1)
	{
	errno = S_cacheLib_CACHE_SET_SIZE_MISMATCH;
	return (ERROR);
	}
    icacheSize = cacheCW4011icacheSet0Size;
    icacheLineMask = cacheLineMaskGet (icacheSize);
    if (icacheSize && (icacheLineMask == 0))
	{
	errno = S_cacheLib_INVALID_CACHE_LINE_SIZE;
	return (ERROR);
	}

    /* enable the icache only if requested */

    if (instMode != CACHE_DISABLED)
	{
	icacheEnableSetMask = (cacheCW4011icacheSet0Size ? CCC_IE0 : 0) |
	                      (cacheCW4011icacheSet1     ? CCC_IE1 : 0);
	}

    /* validate provided dcache sizes, and compute useful constants */

    if ((cacheCW4011dcacheSet0Size == 0) && cacheCW4011dcacheSet1)
	{
	errno = S_cacheLib_CACHE_SET_SIZE_MISMATCH;
	return (ERROR);
	}
    dcacheSize = cacheCW4011dcacheSet0Size;
    dcacheLineMask = cacheLineMaskGet (dcacheSize);
    if (dcacheSize && (dcacheLineMask == 0))
	{
	errno = S_cacheLib_INVALID_CACHE_LINE_SIZE;
	return (ERROR);
	}

    /* enable the dcache only if requested */
    if (dataMode != CACHE_DISABLED)
	{
	dcacheEnableSetMask = (cacheCW4011dcacheSet0Size ? CCC_DE0 : 0) |
	                      (cacheCW4011dcacheSet1     ? CCC_DE1 : 0);
	}

    /* set cacheDataEnabled TRUE in all cases, since this sets up the
     * appropriate pointers for the cache DMA malloc routines.
     */

    cacheDataEnabled = TRUE;
    cacheFuncsSet ();

    /* set the cache configuration, leaving the caches disabled */

    config = _cw4011ConfigGet ();
    config &= ~(CCC_ISIZE_MASK | CCC_DSIZE_MASK | CCC_WB);
    if (dcacheSize)
	config |= cacheSizeDescGet(dcacheSize) << CCC_DSIZE_LSHIFT;
    if (icacheSize)
	config |= cacheSizeDescGet(icacheSize) << CCC_ISIZE_LSHIFT;
    if (dataMode == CACHE_COPYBACK)
	config |= CCC_WB;
    _cw4011ConfigSet (config);

    /* invalidate the cache entries */

    if (dcacheSize)
	_cw4011InvalidateAll (DATA_CACHE, dcacheEnableSetMask);
    if (icacheSize)
	_cw4011InvalidateAll (INSTRUCTION_CACHE, icacheEnableSetMask);

    return (OK);
    }


/**************************************************************************
*
* cacheCW4011Enable - enable the specificed cache.
*
* cacheCW4011Enable is used to enable the instruction and data caches.
*
* RETURNS: OK, or ERROR if the cache type is invalid.
*/

LOCAL STATUS cacheCW4011Enable
    (
    CACHE_TYPE cache			/* Cache to enable */
    )
    {
    int oldLevel;
    ULONG config;

    switch (cache)
	{
	case DATA_CACHE:
	    oldLevel = intLock ();
	    config = _cw4011ConfigGet ();

	    if ((dcacheEnableSetMask == 0) ||	/* skip if nothing to enable */
		(config & dcacheEnableSetMask))	/* skip if already enabled */
		{
		intUnlock (oldLevel);
		return (OK);
		}
	    /* cache disabled and known to be invalid; just enable it */
	    _cw4011ConfigSet (config | dcacheEnableSetMask);
	    cacheDataEnabled = TRUE;		/* d-cache is currently on */
	    cacheFuncsSet ();			/* update cache func ptrs */
	    intUnlock (oldLevel);
	    break;

	case INSTRUCTION_CACHE:
	    oldLevel = intLock ();
	    config = _cw4011ConfigGet ();
	    if ((icacheEnableSetMask == 0) ||	/* skip if nothing to enable */
		(config & icacheEnableSetMask))	/* skip if already enabled */
		{
		intUnlock (oldLevel);
		return (OK);
		}
	    /* cache disabled and known to be invalid; just enable it */
	    _cw4011ConfigSet (config | icacheEnableSetMask);
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
* cacheCW4011Disable - disable the specificed cache.
*
* cacheCW4011Disable is used to disable the instruction and data caches.
*
* RETURNS: OK, or ERROR if the cache type is invalid.
*/

LOCAL STATUS cacheCW4011Disable
    (
    CACHE_TYPE	cache			/* Cache to disable */
    )
    {
    int oldLevel;
    ULONG config;
    ULONG dcacheDisableSetMask = CCC_DE0 | CCC_DE1;
    ULONG icacheDisableSetMask = CCC_IE0 | CCC_IE1;

    /*
     * Note that the xcacheEnableSetMask variables are not used for
     * disabling the caches.  This is because while the caches may not
     * be enabled in the BSP, they still need to be disabled here.
     */
    switch (cache)
	{
	case DATA_CACHE:
	    oldLevel = intLock ();
	    config = _cw4011ConfigGet ();
	    if ((config & dcacheDisableSetMask) == 0)  /* skip if disabled */
		{
		intUnlock (oldLevel);
		return (OK);
		}
	    /* atomically flush and disable cache if copyback is enabled */
	    if (config & CCC_WB)
		_cw4011FlushAndDisable (dcacheSize / CACHE_LINE_SIZE);
	    else
		_cw4011ConfigSet (config & ~dcacheDisableSetMask);
	    _cw4011InvalidateAll (DATA_CACHE, dcacheEnableSetMask);
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
	    config = _cw4011ConfigGet ();
	    if ((config & icacheDisableSetMask) == 0)  /* skip if disabled */
		{
		intUnlock (oldLevel);
		return (OK);
		}
	    _cw4011ConfigSet (config & ~icacheDisableSetMask);
	    _cw4011InvalidateAll (INSTRUCTION_CACHE, icacheEnableSetMask);
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
* cacheCW4011Clear - flush and invalidate all or some entries in a cache
*
* This routine flushes and invalidates all or some of the entries in the
* specified cache.
*
* RETURNS: OK, or ERROR if an error occurs during the clear operation.
*/

LOCAL STATUS cacheCW4011Clear
    (
    CACHE_TYPE	cache,			/* Cache to clear */
    void *	address,		/* Virtual Address */
    size_t	bytes			/* Number of Bytes to clear */
    )
    {
    ULONG oldLevel;
    STATUS status = OK;

    if (cache == INSTRUCTION_CACHE)
	status = cacheCW4011Invalidate (cache, address, bytes);
    else if (cache == DATA_CACHE)
	{
	if (bytes == ENTIRE_CACHE)
	    {
	    /* disable atomically flushes and invalidates the cache */
	    (void) cacheCW4011Disable (DATA_CACHE);
	    (void) cacheCW4011Enable (DATA_CACHE);
	    status = OK;
	    }
	else
	    {
	    oldLevel = intLock();
	    status = cacheCW4011Flush (cache, address, bytes);
	    if (status == OK)
		status = cacheCW4011Invalidate (cache, address, bytes);
	    intUnlock (oldLevel);
	    }
	}
    return (status);
    }


/**************************************************************************
*
* cacheCW4011Invalidate - invalidate all or some entries in a cache
*
* This routine invalidates all or some of the entries in the
* specified cache.
*
* RETURNS: OK.  Unsupported requests are silently ignored.
*
*/

LOCAL STATUS cacheCW4011Invalidate
    (
    CACHE_TYPE	cache,			/* Cache to Invalidate */
    void *	address,		/* Virtual Address */
    size_t	bytes			/* Number of Bytes to Invalidate */
    )
    {
    ULONG line;
    ULONG end;
    ULONG numLines;
    ULONG firstByte;
    ULONG lastByte;
    ULONG cacheSize;
    ULONG cacheLineMask;
    ULONG cacheEnableSetMask;

    /* silently ignore regions which aren't cacheable or are empty */
    if (IS_KSEG1(address) || (bytes == 0))
	return (OK);

    /* silently ignore unsupported cache types */
    if ((cache != DATA_CACHE) && (cache != INSTRUCTION_CACHE))
	return (OK);

    cacheAttributesGet(cache, 
		       &cacheSize, &cacheLineMask, &cacheEnableSetMask);

    /* skip if no cache present */
    if (cacheSize == 0)
	return (OK);

    /* line and end are the (inclusive) start and end cache line addresses */
    line = ((ULONG) address) & cacheLineMask;
    end = (((ULONG) address) + bytes - 1) & cacheLineMask;

    /* determine the number of cache lines we need to (possibly) invalidate  */
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
    /*
     * firstByte and lastByte are the (inclusive) endpoints of the memory
     * region which will have its cache lines flushed.  firstByte is 
     * rounded down to the lower cache line boundary, and lastByte is 
     * rounded up to the upper cache line boundary.  This allows the test
     * in the invalidate inner loop to avoid masking the lower bits of
     * each cache line tag. 
     */
    firstByte = (ULONG) address & ~(CACHE_LINE_SIZE - 1);
    lastByte = ((ULONG) address + bytes - 1) | (CACHE_LINE_SIZE - 1);

    /* the cache tags store physical addresses, so massage the range
       to match this. */
    firstByte = K0_TO_PHYS (firstByte);
    lastByte = K0_TO_PHYS (lastByte);

    if (cache == INSTRUCTION_CACHE)
	{
	/* invalidate instruction cache set 0 (if present) */
	if (cacheEnableSetMask & CCC_IE0)
	    _cw4011Invalidate (CCC_IE0, cacheLineMask,
			       line, numLines, firstByte, lastByte);

	/* invalidate instruction set 1 (if present) */
	if (cacheEnableSetMask & CCC_IE1)
	    _cw4011Invalidate (CCC_IE1, cacheLineMask,
			       line, numLines, firstByte, lastByte);
	}
    else if (cache == DATA_CACHE)
	{
	/* invalidate data cache set 0 (if present) */
	if (cacheEnableSetMask & CCC_DE0)
	    _cw4011Invalidate (CCC_DE0, cacheLineMask,
			       line, numLines, firstByte, lastByte);

	/* invalidate data set 1 (if present) */
	if (cacheEnableSetMask & CCC_DE1)
	    _cw4011Invalidate (CCC_DE1, cacheLineMask,
			       line, numLines, firstByte, lastByte);
	}
    return (OK);
    }

/**************************************************************************
*
* cacheCW4011Flush - flush all or some entries in a cache
*
* This routine flushes all or some of the entries in the specified cache.
*
* RETURNS: OK.  Unsupported requests are silently ignored.
*/

LOCAL STATUS cacheCW4011Flush
    (
    CACHE_TYPE	cache,			/* Cache to Invalidate */
    void *	address,		/* Virtual Address */
    size_t	bytes			/* Number of Bytes to Invalidate */
    )
    {
    ULONG line;
    ULONG end;
    ULONG numLines;

    if (cache != DATA_CACHE)  /* only data cache supports copyback */
	return (OK);

    /* silently ignore regions which aren't cacheable or are empty */
    if (IS_KSEG1(address) || (bytes == 0)) 
	return (OK);

    if (dcacheSize == 0)  /* skip if no cache present */
	return (OK);

    /* line and end are the (inclusive) start and end cache line addresses */
    line = ((ULONG) address) & dcacheLineMask;
    end = (((ULONG) address) + bytes - 1) & dcacheLineMask;

    /* determine the number of cache lines we need to (possibly) invalidate  */
    if ((bytes == ENTIRE_CACHE)
	|| (bytes >= dcacheSize)
	|| ((line == end) && (bytes > CACHE_LINE_SIZE)))
        {
	/* Invalidate the entire cache */
	line = 0;
	numLines = dcacheSize / CACHE_LINE_SIZE;
	}
    else
	{
	numLines = (end >= line)
	    ? (((end - line) / CACHE_LINE_SIZE) + 1)
		: (((dcacheSize - (line - end)) / CACHE_LINE_SIZE) + 1);
	}
    _cw4011Flush (dcacheEnableSetMask, dcacheLineMask, line, numLines);
    return (OK);
    }

/**************************************************************************
*
* cacheCW4011WriteBufferFlush - flush the write buffer
*
* This routine forces a flush of the write buffer.  Setting and then
* using a volative variable is sufficient to generate assembly code
* that will force a sequence point, and that will force the write back
* buffer to flush.
*
* RETURNS: OK
*
* NOMANUAL
*/

LOCAL STATUS cacheCW4011WriteBufferFlush (void)
    {
    volatile STATUS x;

    /* The following is kludgy, but works... */
    x = OK - 1;
    return (x + 1);
    }


/**************************************************************************
*
* cacheCW4011Malloc - allocate a cache-safe buffer, if possible
*
* This routine will attempt to return a pointer to a section of memory
* that will not experience any cache coherency problems.
*
* INTERNAL
* This function is complicated somewhat because the cache can operate in
* copyback mode and we need to avoid problems from writebacks of adjacent
* cached lines; we also need to remember the pointer returned by malloc so
* that we can free it if required.
*
* RETURNS: A pointer to the non-cached buffer, or NULL.
*/

LOCAL void * cacheCW4011Malloc
    (
    size_t bytes 
    )
    {
    void * pBuffer;
    char * pDmaBuffer;
    int allocBytes;

    /* Round up the allocation size so that we can store a "back pointer"
     * to the allocated buffer, align the buffer on a cache line boundary
     * and pad the buffer to a cache line boundary.
     * sizeof(void *) 		for "back pointer"
     * CACHE_LINE_SIZE-1	for cache line alignment
     * CACHE_LINE_SIZE-1	for cache line padding
     */
    allocBytes = sizeof (void *) + 
      		 (CACHE_LINE_SIZE - 1) +
		 bytes + 
      	 	 (CACHE_LINE_SIZE - 1);

    if ((pBuffer = (void *)malloc (allocBytes)) == NULL)
	return (pBuffer);
    else
	{
	/* Flush any data that may be still sitting in the cache */
	cacheCW4011Clear (DATA_CACHE, pBuffer, allocBytes);

	pDmaBuffer = (char *) pBuffer;

	/* allocate space for the back pointer */
	pDmaBuffer += sizeof (void *);

	/* Now align to a cache line boundary */
	pDmaBuffer = (char *) ROUND_UP (pDmaBuffer, CACHE_LINE_SIZE);

	/* Store "back pointer" in previous cache line using CACHED location */
	*(((char **)pDmaBuffer)-1) = pBuffer;

	return ((void *)K0_TO_K1(pDmaBuffer));
	}
    }

/**************************************************************************
*
* cacheCW4011Free - free the buffer acquired by cacheMalloc ()
*
* This routine will attempt to return a pointer to a section of memory
* that will not experience any cache coherency problems.
*
* INTERNAL
* This function is complicated somewhat because the cache operates in
* copyback mode and we need to avoid problems from writebacks of adjacent
* cached lines; we also need to remember the pointer returned by malloc so
* that we can free it if required.
*
* RETURNS: A pointer to the non-cached buffer, or NULL.
*/

LOCAL STATUS cacheCW4011Free
    (
    void * pBuf 
    )
    {
    char *pCacheBuffer;
    
    pCacheBuffer = (char *)K1_TO_K0(pBuf);
    pCacheBuffer -= sizeof (void *);
    free (*(void **)pCacheBuffer);
    return (OK);
    }

/**************************************************************************
*
* cacheCW4011VirtToPhys - virtual-to-physical address translation
*
* This routine may be attached to the CACHE_DRV structure virtToPhysRtn
* function pointer by cacheCW4011Malloc().  This implies that the virtual
* memory library is not installed, and that the "cache-safe" buffer has
* been created through the use of the CW4011 K1 segment.
*
* RETURNS: The physical address of the provided virtual address
*
* NOMANUAL
*/

LOCAL void * cacheCW4011VirtToPhys
    (
    void * address			/* Virtual address */
    )
    {
    return ((void *) K1_TO_PHYS(address));
    }

/**************************************************************************
*
* cacheCW4011PhysToVirt - physical-to-virtual address translation
*
* This routine may be attached to the CACHE_DRV structure physToVirtRtn
* function pointer by cacheCW4011Malloc().  This implies that the virtual
* memory library is not installed, and that the "cache-safe" buffer has
* been created through the use of the CW4011 K1 segment.
*
* RETURNS: The virtual address of the provided physical address
*
* NOMANUAL
*/

LOCAL void * cacheCW4011PhysToVirt
    (
    void * address			/* Physical address */
    )
    {
    return ((void *) PHYS_TO_K1(address));
    }

/**************************************************************************
*
* cacheCW4011TextUpdate - invalidate updated text section
*
* This routine invalidates the specified text section so that the
* correct updated text is executed.  Since writeback caching can
* be enabled, a flush of the data cache is also required, in case
* the newly-written instructions are still contained within a 
* dirty data cache line.
*
* RETURNS: OK, or ERROR if an error occurs during processing.
*
* NOMANUAL
*  
*/

LOCAL STATUS cacheCW4011TextUpdate
    (
    void * address,			/* Physical address */
    size_t bytes			/* bytes to invalidate */
    )
    {
    STATUS status;

    if ((bytes != ENTIRE_CACHE) &&
	((address == NULL) || (bytes == 0) || IS_KSEG1(address)))
	return (OK);
    
    status = cacheCW4011Flush (DATA_CACHE, address, bytes);
    if (status != OK)
	return (status);
    return cacheCW4011Invalidate (INSTRUCTION_CACHE, address, bytes);
    }


/**************************************************************************
*
* cacheLineMaskGet - returns cache line mask based upon cache size.
*
* This routine computes a bit mask which can be used to determine the 
* cache line address which corresponds to a memory address.  A mask 
* value of "0" is returned if the cache size is not valid.

* RETURNS: A cache line bitmask for the requested cache size.
*
* NOMANUAL
*  
*/

LOCAL ULONG cacheLineMaskGet
  (
  ULONG cacheSize
  )
  {
  switch (cacheSize)
      {
      case 1024:
	  return (K0BASE | (0x1f << 5));

      case 2048:
	  return (K0BASE | (0x3f << 5));

      case 4096:
	  return (K0BASE | (0x7f << 5));

      case 8192:
	  return (K0BASE | (0xff << 5));
      }
  return (0); /* unrecognized cache size */
  }


/**************************************************************************
*
* cacheSizeDescGet - returns description bits for the requested cache size.
*
* This routine compares the requested cache size with the sizes supported
* by the CW4011, and returns the bitmask describing the cache size in the
* lower bits of the return value.  This mask must be appropriately shifted
* by the caller before being loaded into the cache configuration register.
*
* RETURNS: The two-bit configuration value for the requested cache size.
*
* NOMANUAL
*  
*/

LOCAL ULONG cacheSizeDescGet
  (
  ULONG cacheSize
  )
  {
  switch (cacheSize)
      {
      case 1024:
	  return (CCC_SIZE_1K);

      case 2048:
	  return (CCC_SIZE_2K);

      case 4096:
	  return (CCC_SIZE_4K);

      case 8192:
	  return (CCC_SIZE_8K);
      }
  return (0); /* unrecognized cache size */
  }


/**************************************************************************
*
* cacheAttributesGet - returns (globally stored) cache attributes.
*
* The globally stored cache attributes are returned to the caller via
* data pointers, based upon the requested cache type.
*
* RETURNS: N/A
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
