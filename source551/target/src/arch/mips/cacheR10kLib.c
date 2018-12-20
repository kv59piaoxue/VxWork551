/* cacheR10kLib.c - MIPS R10000 cache management library */

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
01h,17may02,pes  Before aborting cacheTextUpdate() on null pointer, check for
                 ENTIRE_CACHE.
01g,08may02,pes  Add protection against null pointers, zero counts, and
                 requests involving kseg1 in cacheXXXTextUpdate().
01f,16jul01,ros  add CofE comment
01e,04jan01,tlc  Correct pointer arithmetic in cacheR10kFree();
01d,03jan01,tlc  Backported from Cirrus.
01c,21dec00,pes  Adapt to MIPS32/MIPS64 CPU architectures
01b,31jan00,dra  Updated init invocation.
01a,19jul99,dra  Created this file based on cacheR4kLib.c, 01e.
*/

/*
DESCRIPTION
This library contains architecture-specific cache library functions for
the MIPS R10000 architecture.  The R10000 utilizes a variable-size
instruction and data cache that operates in write-back mode.  Cache
line size also varies.  

For general information about caching, see the manual entry for cacheLib.

INCLUDE FILES: cacheLib.h

SEE ALSO: cacheLib
*/

#include "vxWorks.h"
#include "cacheLib.h"
#include "memLib.h"
#include "stdlib.h"
#include "errno.h"
#include "private/vmLibP.h"
#include "private/funcBindP.h"
#ifdef IS_KSEGM
#include "memPartLib.h"
#include "arch/mips/mmuMipsLib.h"
#endif

/* forward declarations */
LOCAL void *	cacheR10kMalloc (size_t bytes);
LOCAL STATUS	cacheR10kFree (void * pBuf);
LOCAL STATUS	cacheR10kFlush (CACHE_TYPE cache, void *	pVirtAdrs,
			       size_t bytes);
LOCAL STATUS	cacheR10kInvalidate (CACHE_TYPE cache, void * pVirtAdrs, 
                                    size_t bytes);
LOCAL void * 	cacheR10kPhysToVirt (void * address);
LOCAL void * 	cacheR10kVirtToPhys (void * address);
LOCAL STATUS 	cacheR10kTextUpdate (void * address, size_t bytes);
LOCAL STATUS	cacheR10kPipeFlush (void);
LOCAL STATUS	cacheR10kLock (CACHE_TYPE cache, void * pVirtAdrs,
			       size_t bytes);
LOCAL STATUS	cacheR10kUnlock (CACHE_TYPE cache, void * pVirtAdrs,
				 size_t bytes);

/* Imports */

IMPORT UINT32	cacheR10kICacheSize;
IMPORT UINT32	cacheR10kDCacheSize;
IMPORT UINT32	cacheR10kSCacheSize;
IMPORT UINT32	cacheR10kICacheLineSize;
IMPORT UINT32	cacheR10kDCacheLineSize;
IMPORT UINT32	cacheR10kSCacheLineSize;

IMPORT void     cacheR10kSizes (void);
IMPORT void     cacheR10kDCFlushInvalidate (void * pVirtAdrs, size_t bytes);
IMPORT void     cacheR10kDCFlushInvalidateAll (void);
IMPORT void     cacheR10kICInvalidateAll (void);
IMPORT void     cacheR10kICInvalidate (void * pVirtAdrs, size_t bytes);
IMPORT void	cacheR10kDCLock (void * pVirtAdrs, size_t bytes);
IMPORT void	cacheR10kICLock (void * pVirtAdrs, size_t bytes);
IMPORT void	sysWbFlush (void);

#ifdef IS_KSEGM
IMPORT VOIDFUNCPTR _func_mipsCacheSync;
IMPORT VOIDFUNCPTR _func_mmuMipsVirtPageFlush;

IMPORT void	cacheR10kSync (void * vAddr, UINT len);
IMPORT void	cacheR10kVirtPageFlush (UINT asid, void * vAddr, UINT pageSize);
#endif

/**************************************************************************
*
* cacheR10kLibInit - initialize the R10000 cache library
*
* This routine initializes the function pointers for the R10000 cache
* library.  The board support package can select this cache library 
* by assigning the function pointer <sysCacheLibInit> to
* cacheR10kLibInit().
*
* RETURNS: OK.
*/

STATUS cacheR10kLibInit
    (
    CACHE_MODE	instMode,	/* instruction cache mode */
    CACHE_MODE	dataMode,	/* data cache mode */
    UINT32	iCacheSize,
    UINT32	iCacheLineSize,
    UINT32	dCacheSize,
    UINT32	dCacheLineSize,
    UINT32	sCacheSize,
    UINT32	sCacheLineSize
    )
    {
    cacheR10kICacheSize = iCacheSize;
    cacheR10kDCacheSize = dCacheSize;
    cacheR10kSCacheSize = sCacheSize;
    cacheR10kICacheLineSize = iCacheLineSize;
    cacheR10kDCacheLineSize = dCacheLineSize;
    cacheR10kSCacheLineSize = sCacheLineSize;

    cacheLib.enableRtn = NULL;	/* cacheEnable() */
    cacheLib.disableRtn = NULL;	/* cacheDisable() */

    cacheLib.lockRtn = cacheR10kLock;		/* cacheLock */
    cacheLib.unlockRtn = cacheR10kUnlock;	/* cacheUnlock */

    cacheLib.flushRtn = cacheR10kFlush;		/* cacheFlush() */
    cacheLib.pipeFlushRtn = cacheR10kPipeFlush;	/* cachePipeFlush() */
    cacheLib.textUpdateRtn = cacheR10kTextUpdate;/* cacheTextUpdate() */

    cacheLib.invalidateRtn = cacheR10kInvalidate;/* cacheInvalidate() */
    cacheLib.clearRtn = cacheR10kInvalidate;	/* cacheClear() */
    cacheLib.dmaMallocRtn = (FUNCPTR) cacheR10kMalloc;	/* cacheDmaMalloc() */
    cacheLib.dmaFreeRtn = cacheR10kFree;		/* cacheDmaFree() */

#ifdef IS_KSEGM
    if (!IS_KSEGM(cacheR10kLibInit))
	{
	cacheLib.dmaVirtToPhysRtn = (FUNCPTR) cacheR10kVirtToPhys;
	cacheLib.dmaPhysToVirtRtn = (FUNCPTR) cacheR10kPhysToVirt;
	_func_mipsCacheSync = (VOIDFUNCPTR) cacheR10kSync;
	}
    else
	{
	_func_mipsCacheSync = (VOIDFUNCPTR) KM_TO_K0(cacheR10kSync);
	_func_mmuMipsVirtPageFlush = cacheR10kVirtPageFlush;
	_func_mmuMipsVirtPageFlush = NULL;
	}
#else
    cacheLib.dmaVirtToPhysRtn = (FUNCPTR) cacheR10kVirtToPhys;
    cacheLib.dmaPhysToVirtRtn = (FUNCPTR) cacheR10kPhysToVirt;
#endif
    
    cacheDataMode	= dataMode;		/* save dataMode for enable */
    cacheDataEnabled	= TRUE;			/* d-cache is currently on */
    cacheMmuAvailable	= TRUE;			/* mmu support is provided */

    cacheFuncsSet ();				/* update cache func ptrs */

    return (OK);
    }


/**************************************************************************
*
* cacheR10kMalloc - allocate a cache-safe buffer, if possible
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

LOCAL void * cacheR10kMalloc
    (
    size_t bytes 
    )
    {
    void      * pDmaBuffer;
#ifdef IS_KSEGM
    int 	pageSize;

    /* check for non-memory mapped case */
    if (IS_KSEG0(cacheR10kMalloc))
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
	allocBytes = sizeof (void *) +
	  (_CACHE_ALIGN_SIZE - 1) +
	  bytes +
	  (_CACHE_ALIGN_SIZE - 1);

	if ((pBuffer = (void *)malloc (allocBytes)) == NULL)
	    return (NULL);

	/* Flush any data that may be still sitting in the cache */
	cacheR10kDCFlushInvalidate (pBuffer, allocBytes);

	pDmaBuffer = pBuffer;

	/* allocate space for the back pointer */
	pDmaBuffer = (void *)((int)pDmaBuffer + sizeof (void *));

	/* Now align to a cache line boundary */
	pDmaBuffer = (void *)CACHE_ROUND_UP (pDmaBuffer);

	/* Store "back pointer" in previous cache line using CACHED location */
	*(((void **)pDmaBuffer)-1) = pBuffer;

	return ((void *)K0_TO_K1(pDmaBuffer));
#ifdef IS_KSEGM
	}	

    /* memory-mapped case */

    if ((pageSize = VM_PAGE_SIZE_GET ()) == ERROR)
	return (NULL);

    /* make sure bytes is a multiple of pageSize */

    bytes = bytes / pageSize * pageSize + pageSize;

    pDmaBuffer = (void *)IOBUF_ALIGNED_ALLOC (bytes, pageSize);
    if (pDmaBuffer == NULL)
	return (NULL);

    VM_STATE_SET (NULL, pDmaBuffer, bytes,
		  MMU_ATTR_CACHE_MSK, MMU_ATTR_CACHE_OFF);

    return (pDmaBuffer);
#endif /* IS_KSEGM */
    }

/**************************************************************************
*
* cacheR10kFree - free the buffer acquired by cacheMalloc ()
*
* This routine restores the non-cached buffer to its original state
* and does whatever else is necessary to undo the allocate function.
*
* RETURNS: OK, or ERROR if not able to undo cacheMalloc() operation
*/

LOCAL STATUS cacheR10kFree
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
        BLOCK_HDR * pHdr;  /* pointer to block header */

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
* cacheR10kFlush - flush all or some entries in a cache
*
* This routine flushes (writes to memory)  all or some of the entries in the
* specified cache.
*
* RETURNS: OK, or ERROR if the cache type is invalid or the cache control
* is not supported.
*/

LOCAL STATUS	cacheR10kFlush
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
	    cacheR10kPipeFlush ();
	    if (bytes == ENTIRE_CACHE)
		cacheR10kDCFlushInvalidateAll ();
	    else
		cacheR10kDCFlushInvalidate (pVirtAdrs, bytes);
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
* cacheR10kInvalidate - invalidate all or some entries in a cache
*
* This routine invalidates all or some of the entries in the
* specified cache.
*
* RETURNS: OK, or ERROR if the cache type is invalid or the cache control
* is not supported.
*/

LOCAL STATUS	cacheR10kInvalidate
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
		cacheR10kDCFlushInvalidateAll ();
	    else
		cacheR10kDCFlushInvalidate (pVirtAdrs, bytes);
	    break;
	case INSTRUCTION_CACHE:
	    if (bytes == ENTIRE_CACHE)
		cacheR10kICInvalidateAll ();
	    else
		cacheR10kICInvalidate (pVirtAdrs, bytes);
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
* cacheR10kLock - lock all or some entries in a cache
*
* This routine locks all or some of the entries in the
* specified cache.
*
* RETURNS: OK, or ERROR if the cache type is invalid or the cache control
* is not supported.
*/

LOCAL STATUS	cacheR10kLock
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
	    if (bytes > cacheR10kDCacheSize)
		return (ERROR);
	    cacheR10kDCLock (pVirtAdrs, bytes);
	    break;
	case INSTRUCTION_CACHE:
	    if (bytes > cacheR10kICacheSize)
		return (ERROR);
	    cacheR10kICLock (pVirtAdrs, bytes);
	    break;
	default:
	    errno = S_cacheLib_INVALID_CACHE;
	    return (ERROR);
        }

    return (OK);
    }

/**************************************************************************
*
* cacheR10kUnlock - unlock all or some entries in a cache
*
* This routine unlocks all or some of the entries in the
* specified cache.
*
* RETURNS: OK, or ERROR if the cache type is invalid or the cache control
* is not supported.
*/

LOCAL STATUS	cacheR10kUnlock
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
	    if (bytes > cacheR10kDCacheSize)
		return (ERROR);
	    cacheR10kInvalidate (cache, pVirtAdrs, bytes);
	    break;
	case INSTRUCTION_CACHE:
	    if (bytes > cacheR10kICacheSize)
		return (ERROR);
	    cacheR10kInvalidate (cache, pVirtAdrs, bytes);
	    break;
	default:
	    errno = S_cacheLib_INVALID_CACHE;
	    return (ERROR);
        }

    return (OK);
    }

/**************************************************************************
*
* cacheR10kVirtToPhys - virtual-to-physical address translation
*
* This routine may be attached to the CACHE_DRV structure virtToPhysRtn
* function pointer by cacheR10kMalloc().  This implies that the virtual
* memory library is not installed, and that the "cache-safe" buffer has
* been created through the use of the R10000 K1 segment.
*
* NOMANUAL
*/

LOCAL void * cacheR10kVirtToPhys
    (
    void * address                      /* Virtual address */
    )
    {
    return ((void *) K1_TO_PHYS(address));
    }

/**************************************************************************
*
* cacheR10kPhysToVirt - physical-to-virtual address translation
*
* This routine may be attached to the CACHE_DRV structure physToVirtRtn
* function pointer by cacheR10kMalloc().  This implies that the virtual
* memory library is not installed, and that the "cache-safe" buffer has
* been created through the use of the R10000 K1 segment.
*
* NOMANUAL
*/

LOCAL void * cacheR10kPhysToVirt
    (
    void * address                      /* Physical address */
    )
    {
    return ((void *) PHYS_TO_K1(address));
    }

/**************************************************************************
*
* cacheR10kTextUpdate - invalidate updated text section
*
* This routine invalidates the specified text section so that
* the correct updated text is executed.
*
* NOMANUAL
*/

LOCAL STATUS cacheR10kTextUpdate
    (
    void * address,                     /* Physical address */
    size_t bytes 			/* bytes to invalidate */
    )
    {
    if ((bytes != ENTIRE_CACHE) &&
	((address == NULL) || (bytes == 0) || IS_KSEG1(address)))
	return (OK);
    
    if (cacheR10kFlush (DATA_CACHE, address, bytes) != OK)
	return (ERROR);
    return (cacheR10kInvalidate (INSTRUCTION_CACHE, address, bytes));
    }


/**************************************************************************
*
* cacheR10kPipeFlush - flush R10000 write buffers to memory
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

LOCAL STATUS cacheR10kPipeFlush (void)
    {
    sysWbFlush ();
    return (OK);
    }
