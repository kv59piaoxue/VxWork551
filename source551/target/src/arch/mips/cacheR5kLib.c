/* cacheR5kLib.c - MIPS R5000 cache management library */

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
01f,17may02,pes  Before aborting cacheTextUpdate() on null pointer, check for
                 ENTIRE_CACHE.
01e,08may02,pes  Add protection against null pointers, zero counts, and
                 requests involving kseg1 in cacheXXXTextUpdate().
01d,16jul01,ros  add C0fE comment
01c,04jan01,tlc  Backport from Cirrus
01b,21dec00,pes  Adapt to MIPS32/MIPS64 CPU architectures
01a,07jul99,dra  Created this file based on cacheR4kLib.c.
*/

/*
DESCRIPTION
This library contains architecture-specific cache library functions for
the MIPS R5000 architecture.  The R5000 utilizes a variable-size
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
#ifdef IS_KSEGM
#include "memPartLib.h"
#include "arch/mips/mmuMipsLib.h"
#include "private/vmLibP.h"
#include "private/funcBindP.h"
#endif /* IS_KSEGM */

/* forward declarations */
LOCAL void *	cacheR5kMalloc (size_t bytes);
LOCAL STATUS	cacheR5kFree (void * pBuf);
LOCAL STATUS	cacheR5kFlush (CACHE_TYPE cache, void *	pVirtAdrs,
			       size_t bytes);
LOCAL STATUS	cacheR5kInvalidate (CACHE_TYPE cache, void * pVirtAdrs, 
                                    size_t bytes);
LOCAL void * 	cacheR5kPhysToVirt (void * address);
LOCAL void * 	cacheR5kVirtToPhys (void * address);
LOCAL STATUS 	cacheR5kTextUpdate (void * address, size_t bytes);
LOCAL STATUS	cacheR5kPipeFlush (void);

/* Imports */

IMPORT void     cacheR5kICInvalidate (void * pVirtAdrs, size_t bytes);
IMPORT void     cacheR5kICInvalidateAll (void);
IMPORT void     cacheR5kDCFlushInvalidate (void * pVirtAdrs, size_t bytes);
IMPORT void     cacheR5kDCFlushInvalidateAll (void);
IMPORT void	sysWbFlush (void);
IMPORT void	cacheR5kMmuCacheFlush (void);

#ifdef IS_KSEGM
IMPORT VOIDFUNCPTR _func_mipsCacheSync;
IMPORT VOIDFUNCPTR _func_mmuMipsVirtPageFlush;

IMPORT void	cacheR5kSync (void * vAddr, UINT len);
IMPORT void	cacheR5kVirtPageFlush (UINT asid, void * vAddr, UINT len);
#endif /* IS_KSEGM */

/* globals */

IMPORT UINT32 cacheR5kICacheSize;
IMPORT UINT32 cacheR5kDCacheSize;
IMPORT UINT32 cacheR5kSCacheSize;
IMPORT UINT32 cacheR5kICacheLineSize;
IMPORT UINT32 cacheR5kDCacheLineSize;
IMPORT UINT32 cacheR5kSCacheLineSize;

/**************************************************************************
*
* cacheR5kLibInit - initialize the R5000 cache library
*
* This routine initializes the function pointers for the R5000 cache
* library.  The board support package can select this cache library 
* by assigning the function pointer <sysCacheLibInit> to
* cacheR5kLibInit().
*
* RETURNS: OK.
*/

STATUS cacheR5kLibInit
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
    cacheR5kICacheSize = iCacheSize;
    cacheR5kDCacheSize = dCacheSize;
    cacheR5kSCacheSize = sCacheSize;
    cacheR5kICacheLineSize = iCacheLineSize;
    cacheR5kDCacheLineSize = dCacheLineSize;
    cacheR5kSCacheLineSize = sCacheLineSize;

    cacheLib.enableRtn = NULL;	/* cacheEnable() */
    cacheLib.disableRtn = NULL;	/* cacheDisable() */

    cacheLib.lockRtn = NULL;			/* cacheLock */
    cacheLib.unlockRtn = NULL;			/* cacheUnlock */

    cacheLib.flushRtn = cacheR5kFlush;		/* cacheFlush() */
    cacheLib.pipeFlushRtn = cacheR5kPipeFlush;	/* cachePipeFlush() */
    cacheLib.textUpdateRtn = cacheR5kTextUpdate;/* cacheTextUpdate() */

    cacheLib.invalidateRtn = cacheR5kInvalidate;/* cacheInvalidate() */
    cacheLib.clearRtn = cacheR5kInvalidate;	/* cacheClear() */

    cacheLib.dmaMallocRtn = (FUNCPTR) cacheR5kMalloc;	/* cacheDmaMalloc() */
    cacheLib.dmaFreeRtn = cacheR5kFree;			/* cacheDmaFree() */

#ifdef IS_KSEGM
    if (!IS_KSEGM(cacheR5kLibInit))
	{
	cacheLib.dmaVirtToPhysRtn = (FUNCPTR) cacheR5kVirtToPhys;
	cacheLib.dmaPhysToVirtRtn = (FUNCPTR) cacheR5kPhysToVirt;
	_func_mipsCacheSync = (VOIDFUNCPTR) cacheR5kSync;
	}
    else
	{
	_func_mipsCacheSync = (VOIDFUNCPTR) KM_TO_K0(cacheR5kSync);
	_func_mmuMipsVirtPageFlush = (VOIDFUNCPTR) cacheR5kVirtPageFlush;
	_func_mmuMipsVirtPageFlush = NULL;
	}
#else
    cacheLib.dmaVirtToPhysRtn = (FUNCPTR) cacheR5kVirtToPhys;
    cacheLib.dmaPhysToVirtRtn = (FUNCPTR) cacheR5kPhysToVirt;
#endif /* IS_KSEGM */
    
    cacheDataMode	= dataMode;		/* save dataMode for enable */
    cacheDataEnabled	= TRUE;			/* d-cache is currently on */
    cacheMmuAvailable	= TRUE;			/* mmu support is provided */

    cacheFuncsSet ();				/* update cache func ptrs */

    return (OK);
    }

/**************************************************************************
*
* cacheR5kMalloc - allocate a cache-safe buffer, if possible
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

LOCAL void * cacheR5kMalloc
    (
    size_t bytes 
    )
    {
    void      * pDmaBuffer;
#ifdef IS_KSEGM
    int 	pageSize;

    /* check for non-memory mapped case */
    if (IS_KSEG0(cacheR5kMalloc))
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
	cacheR5kDCFlushInvalidate (pBuffer, allocBytes);

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
* cacheR5kFree - free the buffer acquired by cacheMalloc ()
*
* This routine restores the non-cached buffer to its original state
* and does whatever else is necessary to undo the allocate function.
*
* RETURNS: OK, or ERROR if not able to undo cacheMalloc() operation
*/

LOCAL STATUS cacheR5kFree
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
	pCacheBuffer = (void*)((int)pCacheBuffer - sizeof (void *));
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
* cacheR5kFlush - flush all or some entries in a cache
*
* This routine flushes (writes to memory)  all or some of the entries in the
* specified cache.
*
* RETURNS: OK, or ERROR if the cache type is invalid or the cache control
* is not supported.
*/

LOCAL STATUS	cacheR5kFlush
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
		cacheR5kDCFlushInvalidateAll ();
	    else
		cacheR5kDCFlushInvalidate (pVirtAdrs, bytes);
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
* cacheR5kInvalidate - invalidate all or some entries in a cache
*
* This routine invalidates all or some of the entries in the
* specified cache.
*
* RETURNS: OK, or ERROR if the cache type is invalid or the cache control
* is not supported.
*/

LOCAL STATUS	cacheR5kInvalidate
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
		cacheR5kDCFlushInvalidateAll ();
	    else
		cacheR5kDCFlushInvalidate (pVirtAdrs, bytes);
	    break;
	case INSTRUCTION_CACHE:
	    if (bytes == ENTIRE_CACHE)
		cacheR5kICInvalidateAll ();
	    else
		cacheR5kICInvalidate (pVirtAdrs, bytes);
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
* cacheR5kVirtToPhys - virtual-to-physical address translation
*
* This routine may be attached to the CACHE_DRV structure virtToPhysRtn
* function pointer by cacheR5kMalloc().  This implies that the virtual
* memory library is not installed, and that the "cache-safe" buffer has
* been created through the use of the R5000 K1 segment.
*
* NOMANUAL
*/

LOCAL void * cacheR5kVirtToPhys
    (
    void * address                      /* Virtual address */
    )
    {
    return ((void *) K1_TO_PHYS(address));
    }

/**************************************************************************
*
* cacheR5kPhysToVirt - physical-to-virtual address translation
*
* This routine may be attached to the CACHE_DRV structure physToVirtRtn
* function pointer by cacheR5kMalloc().  This implies that the virtual
* memory library is not installed, and that the "cache-safe" buffer has
* been created through the use of the R5000 K1 segment.
*
* NOMANUAL
*/

LOCAL void * cacheR5kPhysToVirt
    (
    void * address                      /* Physical address */
    )
    {
    return ((void *) PHYS_TO_K1(address));
    }

/**************************************************************************
*
* cacheR5kTextUpdate - invalidate updated text section
*
* This routine invalidates the specified text section so that
* the correct updated text is executed.
*
* NOMANUAL
*/

LOCAL STATUS cacheR5kTextUpdate
    (
    void * address,                     /* Physical address */
    size_t bytes 			/* bytes to invalidate */
    )
    {
    if ((bytes != ENTIRE_CACHE) &&
	((address == NULL) || (bytes == 0) || IS_KSEG1(address)))
	return (OK);
    
    if (cacheR5kFlush (DATA_CACHE, address, bytes) != OK)
	return (ERROR);
    return (cacheR5kInvalidate (INSTRUCTION_CACHE, address, bytes));
    }


/**************************************************************************
*
* cacheR5kPipeFlush - flush R5000 write buffers to memory
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

LOCAL STATUS cacheR5kPipeFlush (void)
    {
    sysWbFlush ();
    return (OK);
    }
