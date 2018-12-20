/* cache4kcLib.c - MIPS 4kc cache management library */

/* Copyright 2001 Wind River Systems, Inc. */
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
01f,17may02,pes  Before aborting cacheTextUpdate() on null pointer, check for
                 ENTIRE_CACHE.
01e,08may02,pes  Add protection against null pointers, zero counts, and
                 requests involving kseg1 in cacheXXXTextUpdate().
01d,16jul01,ros  add CofE comment
01c,13jun01,pes  Add support for writeback caches.
01b,03jan01,zmm  Fix undefined reference to _func_mipsCacheSync
01a,11sep00,dra  Created this file based on cacheR5kLib.c.
*/

/*
DESCRIPTION
This library contains architecture-specific cache library functions for
the MIPS 4kc architecture.  The 4kc utilizes a variable-size
instruction and data cache that operates in write-through mode.  Cache
line size also varies.

For general information about caching, see the manual entry for cacheLib.

INCLUDE FILES: cacheLib.h

SEE ALSO: cacheLib
*/

#include	"vxWorks.h"
#include	"cacheLib.h"
#include	"memLib.h"
#include	"stdlib.h"
#include	"errno.h"
#include	"private/vmLibP.h"
#include	"private/funcBindP.h"
#ifdef IS_KSEGM
#include	"arch/mips/mmuMipsLib.h"
#include	"memPartLib.h"
#endif

/* forward declarations */
LOCAL void *	cache4kcMalloc (size_t bytes);
LOCAL STATUS	cache4kcFree (void * pBuf);
LOCAL STATUS	cache4kcFlush (CACHE_TYPE cache, void *	pVirtAdrs,
			       size_t bytes);
LOCAL STATUS	cache4kcClear (CACHE_TYPE cache, void *	pVirtAdrs,
			       size_t bytes);
LOCAL STATUS	cache4kcInvalidate (CACHE_TYPE cache, void * pVirtAdrs, 
                                    size_t bytes);
LOCAL void * 	cache4kcPhysToVirt (void * address);
LOCAL void * 	cache4kcVirtToPhys (void * address);
LOCAL STATUS 	cache4kcTextUpdate (void * address, size_t bytes);
LOCAL STATUS	cache4kcPipeFlush (void);

/* Imports */

IMPORT void	sysWbFlush (void);

IMPORT void     cache4kcDCFlush (void * pVirtAdrs, size_t bytes);
IMPORT void     cache4kcDCFlushAll (void);
IMPORT void     cache4kcDCInvalidate (void * pVirtAdrs, size_t bytes);
IMPORT void     cache4kcDCInvalidateAll (void);
IMPORT void     cache4kcDCFlushInvalidate (void * pVirtAdrs, size_t bytes);
IMPORT void     cache4kcDCFlushInvalidateAll (void);
IMPORT void     cache4kcICInvalidate (void * pVirtAdrs, size_t bytes);
IMPORT void     cache4kcICInvalidateAll (void);
IMPORT void     cache4kcPTextUpdateAll (void);
IMPORT void     cache4kcPTextUpdate (void * pVirtAdrs, size_t bytes);

IMPORT VOIDFUNCPTR _func_mipsCacheSync;
IMPORT VOIDFUNCPTR _func_mmuMipsVirtPageFlush;

IMPORT void	cache4kcSync (void * vAddr, UINT len);
IMPORT void	cache4kcVirtPageFlush (UINT asid, void * vAddr, UINT len);

/* globals */

IMPORT size_t cache4kcICacheSize;
IMPORT size_t cache4kcDCacheSize;
IMPORT size_t cache4kcICacheLineSize;
IMPORT size_t cache4kcDCacheLineSize;

/**************************************************************************
*
* cache4kcLibInit - initialize the 4kc cache library
*
* This routine initializes the function pointers for the 4kc cache
* library.  The board support package can select this cache library 
* by assigning the function pointer <sysCacheLibInit> to
* cache4kcLibInit().
*
* RETURNS: OK.
*/

STATUS cache4kcLibInit
    (
    CACHE_MODE	instMode,	/* instruction cache mode */
    CACHE_MODE	dataMode,	/* data cache mode */
    UINT32	iCacheSize,
    UINT32	iCacheLineSize,
    UINT32	dCacheSize,
    UINT32	dCacheLineSize
    )
    {
    cache4kcICacheSize = iCacheSize;
    cache4kcDCacheSize = dCacheSize;
    cache4kcICacheLineSize = iCacheLineSize;
    cache4kcDCacheLineSize = dCacheLineSize;

    cacheLib.enableRtn = NULL;	/* cacheEnable() */
    cacheLib.disableRtn = NULL;	/* cacheDisable() */

    cacheLib.lockRtn = NULL;			/* cacheLock */
    cacheLib.unlockRtn = NULL;			/* cacheUnlock */

    cacheLib.flushRtn = cache4kcFlush;		/* cacheFlush() */
    cacheLib.pipeFlushRtn = cache4kcPipeFlush;	/* cachePipeFlush() */
    cacheLib.textUpdateRtn = cache4kcTextUpdate;/* cacheTextUpdate() */

    cacheLib.invalidateRtn = cache4kcInvalidate;/* cacheInvalidate() */
    cacheLib.clearRtn = cache4kcClear;		/* cacheClear() */

    cacheLib.dmaMallocRtn = (FUNCPTR) cache4kcMalloc;	/* cacheDmaMalloc() */
    cacheLib.dmaFreeRtn = cache4kcFree;			/* cacheDmaFree() */

#ifdef IS_KSEGM
    if (!IS_KSEGM(cache4kcLibInit))
	{
	cacheLib.dmaVirtToPhysRtn = (FUNCPTR) cache4kcVirtToPhys;
	cacheLib.dmaPhysToVirtRtn = (FUNCPTR) cache4kcPhysToVirt;
	_func_mipsCacheSync = (VOIDFUNCPTR) cache4kcSync;
	}
    else
	{
	_func_mipsCacheSync = (VOIDFUNCPTR) KM_TO_K0(cache4kcSync);
	_func_mmuMipsVirtPageFlush = (VOIDFUNCPTR) cache4kcVirtPageFlush;
	}
#else
    cacheLib.dmaVirtToPhysRtn = (FUNCPTR) cache4kcVirtToPhys;
    cacheLib.dmaPhysToVirtRtn = (FUNCPTR) cache4kcPhysToVirt;
#endif
    
    cacheDataMode	= dataMode;		/* save dataMode for enable */
    cacheDataEnabled	= TRUE;			/* d-cache is currently on */
    cacheMmuAvailable	= TRUE;			/* mmu support is provided */

    cacheFuncsSet ();				/* update cache func ptrs */

    return (OK);
    }

/**************************************************************************
*
* cache4kcMalloc - allocate a cache-safe buffer, if possible
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

LOCAL void * cache4kcMalloc
    (
    size_t bytes 
    )
    {
    void      * pDmaBuffer;

#ifdef IS_KSEGM
    /* check for non-memory mapped case */
    if (IS_KSEG0(cache4kcMalloc))
	{
#endif /* IS_KSEGM */
	int	allocBytes;
	void  * pBuffer;

	/* Round up the allocation size so that we can store a "back pointer"
	 * to the allocated buffer, align the buffer on a cache line boundary
	 * and pad the buffer to a cache line boundary.
	 * sizeof(void *) 		for "back pointer"
	 * _CACHE_ALIGN_SIZE-1	for cache line alignment
	 * _CACHE_ALIGN_SIZE-1	for cache line padding
	 */
	allocBytes = CACHE_ROUND_UP (sizeof (void *)) + CACHE_ROUND_UP (bytes);

	if ((pBuffer = (void *)malloc (allocBytes)) == NULL)
	    return (NULL);

	/* Flush any data that may be still sitting in the cache */
	cache4kcDCFlushInvalidate (pBuffer, allocBytes);

	pDmaBuffer = pBuffer;

	/* allocate space for the back pointer */
	pDmaBuffer = (void *)((int)pDmaBuffer + sizeof (void *));

	/* Now align to a cache line boundary */
	pDmaBuffer = (void *)CACHE_ROUND_UP (pDmaBuffer);

	/* Store "back pointer" in previous cache line using CACHED location */
	*(((void **)pDmaBuffer)-1) = pBuffer;

	return ((void *)K0_TO_K1(pDmaBuffer));
#ifdef IS_KESGM
	}
    else
	{
	int	pageSize;

	/* memory-mapped case */

	if ((pageSize = VM_PAGE_SIZE_GET ()) == ERROR)
	    return (NULL);

	/* make sure bytes is a multiple of pageSize. This calculation assumes
	 * that pageSize is a power of 2. */
	bytes = (bytes + (pageSize - 1)) & ~(pageSize - 1);

	pDmaBuffer = (void *)IOBUF_ALIGNED_ALLOC (bytes, pageSize);
	if (pDmaBuffer == NULL)
	    return (NULL);

	cache4kcDCFlushInvalidate (pDmaBuffer, bytes);
	VM_STATE_SET (NULL, pDmaBuffer, bytes,
		      MMU_ATTR_CACHE_MSK, MMU_ATTR_CACHE_OFF);

	return (pDmaBuffer);
	}
#endif /* IS_KSEGM */
    }

/**************************************************************************
*
* cache4kcFree - free the buffer acquired by cacheMalloc ()
*
* This routine restores the non-cached buffer to its original state
* and does whatever else is necessary to undo the allocate function.
*
* RETURNS: OK, or ERROR if not able to undo cacheMalloc() operation
*/

LOCAL STATUS cache4kcFree
    (
    void * pBuf 
    )
    {
    void      * pCacheBuffer;
#ifdef IS_KSEGM
    STATUS	status = OK;	/* return value */
    
    /* Check for unmapped case */
    if (IS_KSEG1(pBuf))
	{
#endif /* IS_KSEGM */
	pCacheBuffer = (void *)K1_TO_K0(pBuf);
	pCacheBuffer = (void *)((int)pCacheBuffer - sizeof (void *));
	free (*(void **)pCacheBuffer);
#ifdef IS_KSEGM
	}
    else
	{
	BLOCK_HDR * pHdr;		/* pointer to block header */

	if (vmLibInfo.vmLibInstalled)
	    {
	    pHdr = BLOCK_TO_HDR (pBuf);

	    /*
	     * XXX - cache mode is set back to the default one. This may be
	     * a problem since we do not know if the original cache mode was either 
	     * COPY_BACK or WRITETHROUGH.
	     */

	    status = VM_STATE_SET (NULL, pBuf, BLOCK_SIZE (pHdr),
				   MMU_ATTR_CACHE_MSK, MMU_ATTR_CACHE_DEFAULT);
	    }
	IOBUF_FREE (pBuf);		/* free buffer after modified */

	return (status);
	}
#endif /* IS_KSEGM */
    return (OK);
    }

/**************************************************************************
*
* cache4kcFlush - flush all or some entries in a cache
*
* This routine flushes (writes to memory)  all or some of the entries in the
* specified cache.
*
* RETURNS: OK, or ERROR if the cache type is invalid or the cache control
* is not supported.
*/

LOCAL STATUS	cache4kcFlush
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
		cache4kcDCFlushAll ();
	    else
		cache4kcDCFlush (pVirtAdrs, bytes);
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
* cache4kcInvalidate - invalidate all or some entries in a cache
*
* This routine invalidates all or some of the entries in the
* specified cache.
*
* RETURNS: OK, or ERROR if the cache type is invalid or the cache control
* is not supported.
*/

LOCAL STATUS	cache4kcInvalidate
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
		cache4kcDCInvalidateAll ();
	    else
		cache4kcDCInvalidate (pVirtAdrs, bytes);
	    break;
	case INSTRUCTION_CACHE:
	    if (bytes == ENTIRE_CACHE)
		cache4kcICInvalidateAll ();
	    else
		cache4kcICInvalidate (pVirtAdrs, bytes);
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
* cache4kcClear - clear all or some entries in a cache
*
* This routine clears all or some of the entries in the
* specified cache.
*
* RETURNS: OK, or ERROR if the cache type is invalid or the cache control
* is not supported.
*/

LOCAL STATUS	cache4kcClear
    (
    CACHE_TYPE	cache,			/* Cache to clear */
    void *	pVirtAdrs,		/* Virtual Address */
    size_t	bytes 			/* Number of Bytes to clear */
    )
    {
    if (IS_KSEG1(pVirtAdrs))
	return(OK);
    switch (cache)
	{
	case DATA_CACHE:
	    if (bytes == ENTIRE_CACHE)
		cache4kcDCFlushInvalidateAll ();
	    else
		cache4kcDCFlushInvalidate (pVirtAdrs, bytes);
	    break;
	case INSTRUCTION_CACHE:
	    if (bytes == ENTIRE_CACHE)
		cache4kcICInvalidateAll ();
	    else
		cache4kcICInvalidate (pVirtAdrs, bytes);
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
* cache4kcVirtToPhys - virtual-to-physical address translation
*
* This routine may be attached to the CACHE_DRV structure virtToPhysRtn
* function pointer by cache4kcMalloc().  This implies that the virtual
* memory library is not installed, and that the "cache-safe" buffer has
* been created through the use of the 4kc K1 segment.
*
* NOMANUAL
*/

LOCAL void * cache4kcVirtToPhys
    (
    void * address                      /* Virtual address */
    )
    {
    return ((void *) K1_TO_PHYS(address));
    }

/**************************************************************************
*
* cache4kcPhysToVirt - physical-to-virtual address translation
*
* This routine may be attached to the CACHE_DRV structure physToVirtRtn
* function pointer by cache4kcMalloc().  This implies that the virtual
* memory library is not installed, and that the "cache-safe" buffer has
* been created through the use of the 4kc K1 segment.
*
* NOMANUAL
*/

LOCAL void * cache4kcPhysToVirt
    (
    void * address                      /* Physical address */
    )
    {
    return ((void *) PHYS_TO_K1(address));
    }

/**************************************************************************
*
* cache4kcTextUpdate - invalidate updated text section
*
* This routine invalidates the specified text section so that
* the correct updated text is executed.
*
* NOMANUAL
*/

LOCAL STATUS cache4kcTextUpdate
    (
    void * address,                     /* Physical address */
    size_t bytes 			/* bytes to invalidate */
    )
    {
    if ((bytes != ENTIRE_CACHE) &&
	((address == NULL) || (bytes == 0) || IS_KSEG1(address)))
	return (OK);
    
    if (bytes == ENTIRE_CACHE)
	cache4kcPTextUpdateAll ();
    else
	cache4kcPTextUpdate (address, bytes);
    return (OK);
    }


/**************************************************************************
*
* cache4kcPipeFlush - flush 4kc write buffers to memory
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

STATUS cache4kcPipeFlush (void)
    {
    sysWbFlush ();
    return (OK);
    }
