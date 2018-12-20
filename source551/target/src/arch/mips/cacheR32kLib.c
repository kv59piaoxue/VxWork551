/* cacheR32kLib.c - MIPS RC32364 cache management library */

/* Copyright 1984-2001 Wind River Systems, Inc. */
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
01e,17may02,pes  Before aborting cacheTextUpdate() on null pointer, check for
                 ENTIRE_CACHE.
01d,08may02,pes  Add protection against null pointers, zero counts, and
                 requests involving kseg1 in cacheXXXTextUpdate().
01c,10dec01,d_c  Add documentation to cacheR32kLibInit
01b,16jul01,ros  add CofE comment
01a,29sep98,hsm   Created from cacheR4kLib.c
*/

/*
DESCRIPTION
This library contains architecture-specific cache library functions for
the MIPS IDT RC32364 architecture. 

For general information about caching, see the manual entry for cacheLib.

INCLUDE FILES: cacheLib.h

SEE ALSO: cacheLib
*/

#include	"vxWorks.h"
#include	"cacheLib.h"
#include	"memLib.h"
#include	"stdlib.h"
#include	"errno.h"

/* forward declarations */
LOCAL STATUS	cacheR32kEnable (CACHE_TYPE cache);
LOCAL STATUS	cacheR32kDisable (CACHE_TYPE cache);
LOCAL void *	cacheR32kMalloc (size_t bytes);
LOCAL STATUS	cacheR32kFree (void * pBuf);
LOCAL STATUS	cacheR32kFlush (CACHE_TYPE cache, void *	pVirtAdrs,
			       size_t bytes);
LOCAL STATUS	cacheR32kInvalidate (CACHE_TYPE cache, void * pVirtAdrs, 
                                    size_t bytes);
LOCAL void * 	cacheR32kPhysToVirt (void * address);
LOCAL void * 	cacheR32kVirtToPhys (void * address);
LOCAL STATUS 	cacheR32kTextUpdate (void * address, size_t bytes);
LOCAL STATUS	cacheR32kPipeFlush (void);

/* globals */

extern size_t cacheICacheSize;
extern size_t cacheDCacheSize;
extern size_t cacheICacheLineSize;
extern size_t cacheDCacheLineSize;

/**************************************************************************
*
* cacheR32kLibInit - initialize the RC32364 cache library
*
* This routine initializes the function pointers for the RC32364 cache
* library.  The board support package can select this cache library 
* by assigning the function pointer <sysCacheLibInit> to
* cacheR32kLibInit().
*
* This routine determines the cache size and cache line size
* for the instruction and data cache automatically by reading
* the CP0 configuration register. This is different than most of the
* other cache library initialization calls, which take the cache
* and line sizes as parameters.
*
* RETURNS: OK.
*/

STATUS cacheR32kLibInit
    (
    CACHE_MODE	instMode,	/* instruction cache mode */
    CACHE_MODE	dataMode	/* data cache mode */
    )
    {
    cacheLib.enableRtn = cacheR32kEnable;	/* cacheEnable() */
    cacheLib.disableRtn = cacheR32kDisable;	/* cacheDisable() */

    cacheLib.lockRtn = NULL;			/* cacheLock */
    cacheLib.unlockRtn = NULL;			/* cacheUnlock */

    cacheLib.flushRtn = cacheR32kFlush;		/* cacheFlush() */
    cacheLib.pipeFlushRtn = cacheR32kPipeFlush;	/* cachePipeFlush() */
    cacheLib.textUpdateRtn = cacheR32kTextUpdate;/* cacheTextUpdate() */

    cacheLib.invalidateRtn = cacheR32kInvalidate;/* cacheInvalidate() */
    cacheLib.clearRtn = cacheR32kInvalidate;	/* cacheClear() */

    cacheLib.dmaMallocRtn = (FUNCPTR) cacheR32kMalloc;	/* cacheDmaMalloc() */
    cacheLib.dmaFreeRtn = cacheR32kFree;			/* cacheDmaFree() */

    cacheLib.dmaVirtToPhysRtn = (FUNCPTR) cacheR32kVirtToPhys;
    cacheLib.dmaPhysToVirtRtn = (FUNCPTR) cacheR32kPhysToVirt;

    /* We assume that the cache is already reset */
    cacheR32kSizes ();				/* get the cache sizes */

    cacheDataMode	= dataMode;     	/* save dataMode for enable */
    cacheDataEnabled	= TRUE;                 /* d-cache is currently on  */
    cacheMmuAvailable	= TRUE;		        /* mmu support is provided  */
        
    cacheFuncsSet ();   			/* update cache func ptrs   */

    return (OK);
    }

/**************************************************************************
*
* cacheR32kEnable - enable RC32364 caches
* 
* This routine invalidates the cache tags for the specified
* instruction or data cache, and then enables the cache.
*
* RETURNS: OK, or ERROR if the cache type is invalid or the cache control
* is not supported.
*
* NOMANUAL
*/

STATUS cacheR32kEnable
    (
    CACHE_TYPE	cache		/* cache to enable */
    )

    {

    switch (cache)
	{
      case DATA_CACHE:
      case INSTRUCTION_CACHE:
	cacheDataEnabled = TRUE; 
	break;
      default:
	return (ERROR);
	break;
        }
    cacheR32kEnableCaches ();
    cacheFuncsSet (); 
    return (OK);
    }

/**************************************************************************
*
* cacheR32kDisable - disable RC32364 caches
*
* This routine flushes and then disables the RC32364 cache.
*
* RETURNS: OK, or ERROR if the cache type is invalid or the cache control
* is not supported.
*
* NOMANUAL
*/

STATUS cacheR32kDisable
    (
    CACHE_TYPE	cache		/* cache to disable */
    )

    {
    switch (cache)
	{
      case DATA_CACHE:
      case INSTRUCTION_CACHE:
	cacheDataEnabled = FALSE; 
	break;

      default:
	return (ERROR);
	break;
        }

    cacheR32kDisableCaches ();
    cacheFuncsSet ();  
    return (OK);
    }

/**************************************************************************
*
* cacheR32kMalloc - allocate a cache-safe buffer, if possible
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

void * cacheR32kMalloc
    (
    size_t bytes 
    )
    {
    void * pBuffer;
    void * pDmaBuffer;
    int allocBytes;

    /* Round up the allocation size so that we can store a "back pointer"
     * to the allocated buffer, align the buffer on a cache line boundary
     * and pad the buffer to a cache line boundary.
     * sizeof(void *) 		for "back pointer"
     * _CACHE_ALIGN_SIZE-1	for cache line alignment
     * _CACHE_ALIGN_SIZE-1	for cache line padding
     */
    allocBytes = sizeof (void *) +
		(_CACHE_ALIGN_SIZE - 1) +
		bytes +
		(_CACHE_ALIGN_SIZE - 1);

    if ((pBuffer = (void *)malloc (allocBytes)) == NULL)
	return (pBuffer);
    else
	{
	/* Flush any data that may be still sitting in the cache */
	cacheR32kDCFlushInvalidate (pBuffer, allocBytes);

	pDmaBuffer = pBuffer;

	/* allocate space for the back pointer */
	pDmaBuffer += sizeof (void *);

	/* Now align to a cache line boundary */
	pDmaBuffer = (void *)CACHE_ROUND_UP (pDmaBuffer);

	/* Store "back pointer" in previous cache line using CACHED location */
	*(((void **)pDmaBuffer)-1) = pBuffer;

	return ((void *)K0_TO_K1(pDmaBuffer));
	}
    }

/**************************************************************************
*
* cacheR32kFree - free the buffer acquired by cacheMalloc ()
*
* This routine restores the non-cached buffer to its original state
* and does whatever else is necessary to undo the allocate function.
*
* RETURNS: OK, or ERROR if not able to undo cacheMalloc() operation
*/

LOCAL STATUS cacheR32kFree
    (
    void * pBuf 
    )
    {
    void *pCacheBuffer;
    
    pCacheBuffer = (void *)K1_TO_K0(pBuf);
    pCacheBuffer -= sizeof (void *);
    free (*(void **)pCacheBuffer);
    return (OK);
    }

/**************************************************************************
*
* cacheR32kFlush - flush all or some entries in a cache
*
* This routine flushes (writes to memory)  all or some of the entries in the
* specified cache.
*
* RETURNS: OK, or ERROR if the cache type is invalid or the cache control
* is not supported.
*/

LOCAL STATUS	cacheR32kFlush
    (
    CACHE_TYPE	cache,			/* Cache to Invalidate */
    void *	pVirtAdrs,		/* Virtual Address */
    size_t	bytes 			/* Number of Bytes to Invalidate */
    )
    {
    if (IS_KSEG1(pVirtAdrs))
	return(OK);
    switch (cache)
	{
	case DATA_CACHE:
	    if (bytes == ENTIRE_CACHE)
		cacheR32kDCFlushInvalidateAll ();
	    else
		cacheR32kDCFlushInvalidate (pVirtAdrs, bytes);
	    break;
	default:
	    return (ERROR);
	    break;
        }

    return (OK);
    }

/**************************************************************************
*
* cacheR32kInvalidate - invalidate all or some entries in a cache
*
* This routine invalidates all or some of the entries in the
* specified cache.
*
* RETURNS: OK, or ERROR if the cache type is invalid or the cache control
* is not supported.
*/

LOCAL STATUS	cacheR32kInvalidate
    (
    CACHE_TYPE	cache,			/* Cache to Invalidate */
    void *	pVirtAdrs,		/* Virtual Address */
    size_t	bytes 			/* Number of Bytes to Invalidate */
    )
    {
    if (IS_KSEG1(pVirtAdrs))
	return(OK);
    switch (cache)
	{
	case DATA_CACHE:
	    if (bytes == ENTIRE_CACHE)
		cacheR32kDCFlushInvalidateAll ();
	    else
		cacheR32kDCFlushInvalidate (pVirtAdrs, bytes);
	    break;
	case INSTRUCTION_CACHE:
	    if (bytes == ENTIRE_CACHE)
		cacheR32kICInvalidateAll ();
	    else
		cacheR32kICInvalidate (pVirtAdrs, bytes);
	    break;
	default:
	    return (ERROR);
	    break;
        }

    return (OK);
    }

/**************************************************************************
*
* cacheR32kVirtToPhys - virtual-to-physical address translation
*
* This routine may be attached to the CACHE_DRV structure virtToPhysRtn
* function pointer by cacheDmaMalloc().  This implies that the virtual
* memory library is not installed, and that the "cache-safe" buffer has
* been created through the use of the RC32364 K1 segment.
*
* NOMANUAL
*/

LOCAL void * cacheR32kVirtToPhys
    (
    void * address                      /* Virtual address */
    )
    {
    return ((void *) K1_TO_PHYS(address));
    }

/**************************************************************************
*
* cacheR32kPhysToVirt - physical-to-virtual address translation
*
* This routine may be attached to the CACHE_DRV structure physToVirtRtn
* function pointer by cacheDmaMalloc().  This implies that the virtual
* memory library is not installed, and that the "cache-safe" buffer has
* been created through the use of the RC32364 K1 segment.
*
* NOMANUAL
*/

LOCAL void * cacheR32kPhysToVirt
    (
    void * address                      /* Physical address */
    )
    {
    return ((void *) PHYS_TO_K1(address));
    }

/**************************************************************************
*
* cacheR32kTextUpdate - invalidate updated text section
*
* This routine invalidates the specified text section so that
* the correct updated text is executed.
*
* NOMANUAL
*/

STATUS cacheR32kTextUpdate
    (
    void * address,                     /* Physical address */
    size_t bytes 			/* bytes to invalidate */
    )
    {
    if ((bytes != ENTIRE_CACHE) &&
	((address == NULL) || (bytes == 0) || IS_KSEG1(address)))
	return (OK);
    
    if (cacheR32kFlush (DATA_CACHE, address, bytes) != OK)
	return (ERROR);
    return (cacheR32kInvalidate (INSTRUCTION_CACHE, address, bytes));
    }


/**************************************************************************
*
* cacheR32kPipeFlush - flush RC32364 write buffers to memory
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

STATUS cacheR32kPipeFlush (void)
    {
    sysWbFlush ();
    return (OK);
    }

