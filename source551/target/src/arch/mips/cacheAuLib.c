/* cacheAuLib.c - Alchemy Au cache management library */

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
01d,14may02,zmm  Global au1000 name changes, SPR 77333. 
                 Before aborting cacheTextUpdate() on null pointer, check for
                 ENTIRE_CACHE. Add protection against null pointers, zero counts,
                 and requests involving kseg1 in cacheXXXTextUpdate(), SPR 76694.
01c,15nov01,zmm  Changed cacheAu1000Malloc and cacheAu1000Free to allocate
                 buffer in kseg0.
01b,16jul01,ros  add CofE comment
01a,10jul01,mem  written.
*/

/*
DESCRIPTION
This library contains architecture-specific cache library functions for
the Alchemy Au architecture.  The Au utilizes a variable-size
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
LOCAL void *	cacheAuMalloc (size_t bytes);
LOCAL STATUS	cacheAuFree (void * pBuf);
LOCAL STATUS	cacheAuFlush (CACHE_TYPE cache, void *	pVirtAdrs,
			       size_t bytes);
LOCAL STATUS	cacheAuClear (CACHE_TYPE cache, void *	pVirtAdrs,
			       size_t bytes);
LOCAL STATUS	cacheAuInvalidate (CACHE_TYPE cache, void * pVirtAdrs, 
                                    size_t bytes);
LOCAL void * 	cacheAuPhysToVirt (void * address);
LOCAL void * 	cacheAuVirtToPhys (void * address);
LOCAL STATUS 	cacheAuTextUpdate (void * address, size_t bytes);
LOCAL STATUS	cacheAuPipeFlush (void);

/* Imports */

IMPORT void	sysWbFlush (void);

IMPORT void     cacheAuDCFlush (void * pVirtAdrs, size_t bytes);
IMPORT void     cacheAuDCFlushAll (void);
IMPORT void     cacheAuDCInvalidate (void * pVirtAdrs, size_t bytes);
IMPORT void     cacheAuDCInvalidateAll (void);
IMPORT void     cacheAuDCFlushInvalidate (void * pVirtAdrs, size_t bytes);
IMPORT void     cacheAuDCFlushInvalidateAll (void);
IMPORT void     cacheAuICInvalidate (void * pVirtAdrs, size_t bytes);
IMPORT void     cacheAuICInvalidateAll (void);
IMPORT void     cacheAuPTextUpdateAll (void);
IMPORT void     cacheAuPTextUpdate (void * pVirtAdrs, size_t bytes);

IMPORT VOIDFUNCPTR _func_mipsCacheSync;
IMPORT VOIDFUNCPTR _func_mmuMipsVirtPageFlush;

IMPORT void	cacheAuSync (void * vAddr, UINT len);
IMPORT void	cacheAuVirtPageFlush (UINT asid, void * vAddr, UINT len);

/* globals */

IMPORT size_t cacheAuICacheSize;
IMPORT size_t cacheAuDCacheSize;
IMPORT size_t cacheAuICacheLineSize;
IMPORT size_t cacheAuDCacheLineSize;

/**************************************************************************
*
* cacheAuLibInit - initialize the Au cache library
*
* This routine initializes the function pointers for the Au cache
* library.  The board support package can select this cache library 
* by assigning the function pointer <sysCacheLibInit> to
* cacheAuLibInit().
*
* RETURNS: OK.
*/

STATUS cacheAuLibInit
    (
    CACHE_MODE	instMode,	/* instruction cache mode */
    CACHE_MODE	dataMode,	/* data cache mode */
    UINT32	iCacheSize,
    UINT32	iCacheLineSize,
    UINT32	dCacheSize,
    UINT32	dCacheLineSize
    )
    {
    cacheAuICacheSize = iCacheSize;
    cacheAuDCacheSize = dCacheSize;
    cacheAuICacheLineSize = iCacheLineSize;
    cacheAuDCacheLineSize = dCacheLineSize;

    cacheLib.enableRtn = NULL;	/* cacheEnable() */
    cacheLib.disableRtn = NULL;	/* cacheDisable() */

    cacheLib.lockRtn = NULL;			/* cacheLock */
    cacheLib.unlockRtn = NULL;			/* cacheUnlock */

    cacheLib.flushRtn = cacheAuFlush;		/* cacheFlush() */
    cacheLib.pipeFlushRtn = cacheAuPipeFlush;	/* cachePipeFlush() */
    cacheLib.textUpdateRtn = cacheAuTextUpdate;/* cacheTextUpdate() */

    cacheLib.invalidateRtn = cacheAuInvalidate;/* cacheInvalidate() */
    cacheLib.clearRtn = cacheAuClear;		/* cacheClear() */

    cacheLib.dmaMallocRtn = (FUNCPTR) cacheAuMalloc;	/* cacheDmaMalloc() */
    cacheLib.dmaFreeRtn = cacheAuFree;			/* cacheDmaFree() */

#ifdef IS_KSEGM
    if (!IS_KSEGM(cacheAuLibInit))
	{
	cacheLib.dmaVirtToPhysRtn = (FUNCPTR) cacheAuVirtToPhys;
	cacheLib.dmaPhysToVirtRtn = (FUNCPTR) cacheAuPhysToVirt;
	_func_mipsCacheSync = (VOIDFUNCPTR) cacheAuSync;
	}
    else
	{
	_func_mipsCacheSync = (VOIDFUNCPTR) KM_TO_K0(cacheAuSync);
	_func_mmuMipsVirtPageFlush = (VOIDFUNCPTR) cacheAuVirtPageFlush;
	}
#else
    cacheLib.dmaVirtToPhysRtn = (FUNCPTR) cacheAuVirtToPhys;
    cacheLib.dmaPhysToVirtRtn = (FUNCPTR) cacheAuPhysToVirt;
#endif
    
    cacheDataMode	= dataMode;		/* save dataMode for enable */
    cacheDataEnabled	= TRUE;			/* d-cache is currently on */
    cacheMmuAvailable	= TRUE;			/* mmu support is provided */

    cacheFuncsSet ();				/* update cache func ptrs */

    return (OK);
    }

/**************************************************************************
*
* cacheAuMalloc - allocate a cache-safe buffer, if possible
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

LOCAL void * cacheAuMalloc
    (
    size_t bytes 
    )
    {
    void      * pDmaBuffer;

#ifdef IS_KSEGM
    /* check for non-memory mapped case */
    if (IS_KSEG0(cacheAuMalloc))
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
	cacheAuDCFlushInvalidate (pBuffer, allocBytes);

	pDmaBuffer = pBuffer;

	/* allocate space for the back pointer */
	pDmaBuffer = (void *)((int)pDmaBuffer + sizeof (void *));

	/* Now align to a cache line boundary */
	pDmaBuffer = (void *)CACHE_ROUND_UP (pDmaBuffer);

	/* Store "back pointer" in previous cache line using CACHED location */
	*(((void **)pDmaBuffer)-1) = pBuffer;

	return ((void *)(pDmaBuffer));
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

	cacheAuDCFlushInvalidate (pDmaBuffer, bytes);
	VM_STATE_SET (NULL, pDmaBuffer, bytes,
		      MMU_ATTR_CACHE_MSK, MMU_ATTR_CACHE_OFF);

	return (pDmaBuffer);
	}
#endif /* IS_KSEGM */
    }

/**************************************************************************
*
* cacheAuFree - free the buffer acquired by cacheMalloc ()
*
* This routine restores the non-cached buffer to its original state
* and does whatever else is necessary to undo the allocate function.
*
* RETURNS: OK, or ERROR if not able to undo cacheMalloc() operation
*/

LOCAL STATUS cacheAuFree
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
	pCacheBuffer = (void *)(pBuf);
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
* cacheAuFlush - flush all or some entries in a cache
*
* This routine flushes (writes to memory)  all or some of the entries in the
* specified cache.
*
* RETURNS: OK, or ERROR if the cache type is invalid or the cache control
* is not supported.
*/

LOCAL STATUS	cacheAuFlush
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
		cacheAuDCFlushAll ();
	    else
		cacheAuDCFlush (pVirtAdrs, bytes);
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
* cacheAuInvalidate - invalidate all or some entries in a cache
*
* This routine invalidates all or some of the entries in the
* specified cache.
*
* RETURNS: OK, or ERROR if the cache type is invalid or the cache control
* is not supported.
*/

LOCAL STATUS	cacheAuInvalidate
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
		cacheAuDCInvalidateAll ();
	    else
		cacheAuDCInvalidate (pVirtAdrs, bytes);
	    break;
	case INSTRUCTION_CACHE:
	    if (bytes == ENTIRE_CACHE)
		cacheAuICInvalidateAll ();
	    else
		cacheAuICInvalidate (pVirtAdrs, bytes);
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
* cacheAuClear - clear all or some entries in a cache
*
* This routine clears all or some of the entries in the
* specified cache.
*
* RETURNS: OK, or ERROR if the cache type is invalid or the cache control
* is not supported.
*/

LOCAL STATUS	cacheAuClear
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
		cacheAuDCFlushInvalidateAll ();
	    else
		cacheAuDCFlushInvalidate (pVirtAdrs, bytes);
	    break;
	case INSTRUCTION_CACHE:
	    if (bytes == ENTIRE_CACHE)
		cacheAuICInvalidateAll ();
	    else
		cacheAuICInvalidate (pVirtAdrs, bytes);
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
* cacheAuVirtToPhys - virtual-to-physical address translation
*
* This routine may be attached to the CACHE_DRV structure virtToPhysRtn
* function pointer by cacheAuMalloc().  This implies that the virtual
* memory library is not installed, and that the "cache-safe" buffer has
* been created through the use of the Au K1 segment.
*
* NOMANUAL
*/

LOCAL void * cacheAuVirtToPhys
    (
    void * address                      /* Virtual address */
    )
    {
    return ((void *) K1_TO_PHYS(address));
    }

/**************************************************************************
*
* cacheAuPhysToVirt - physical-to-virtual address translation
*
* This routine may be attached to the CACHE_DRV structure physToVirtRtn
* function pointer by cacheAuMalloc().  This implies that the virtual
* memory library is not installed, and that the "cache-safe" buffer has
* been created through the use of the Au K1 segment.
*
* NOMANUAL
*/

LOCAL void * cacheAuPhysToVirt
    (
    void * address                      /* Physical address */
    )
    {
    return ((void *) PHYS_TO_K1(address));
    }

/**************************************************************************
*
* cacheAuTextUpdate - invalidate updated text section
*
* This routine invalidates the specified text section so that
* the correct updated text is executed.
*
* NOMANUAL
*/

LOCAL STATUS cacheAuTextUpdate
    (
    void * address,                     /* Physical address */
    size_t bytes 			/* bytes to invalidate */
    )
    {
    if ((bytes != ENTIRE_CACHE) &&
        ((address == NULL) || (bytes == 0) || IS_KSEG1(address)))
	return (OK);

    if (bytes == ENTIRE_CACHE)
	cacheAuPTextUpdateAll ();
    else
	cacheAuPTextUpdate (address, bytes);
    return (OK);
    }


/**************************************************************************
*
* cacheAuPipeFlush - flush Au write buffers to memory
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

STATUS cacheAuPipeFlush (void)
    {
    sysWbFlush ();
    return (OK);
    }
