/* cacheR7kLib.c - MIPS R7000 cache management library */

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
01q,29jan03,jmt  Change cacheDmaMalloc to use memPartAlloc instead of malloc
01p,17may02,pes  Before aborting cacheTextUpdate() on null pointer, check for
                 ENTIRE_CACHE.
01o,08may02,pes  Add protection against null pointers, zero counts, and
                 requests involving kseg1 in cacheXXXTextUpdate().
01n,16jul01,ros  add CofE comment
01m,30jun00,dra  Backported from Cirrus
01l,21jun00,dra  Call underlying functions from kseg1
01k,20jun00,dra  Update DMA alloc/free for Cirrus.
01j,13jun00,dra  generalize the mmuMipsUnMap flush of virtual page addresses
                 to all Mips architectures, correct cdf file discrepancies
01i,22mar00,dra  Fixed compiler warnings.
01h,19jul99,dra  Updated cache library for R7k devices.
01g,19jul99,dra  Created this file based on cacheR5kLib.c, 01f.
01f,12jul99,dra  Updated cacheLock/cacheUnlock support for VR5400.
01e,07jul99,dra  Created this file based on cacheR4kLib.c.
01d,06apr99,dra  Added cacheLock/cacheUnlock support for VR5400.
01c,05dec96,kkk  Added missing return value to cacheR4kFlush() and
                 cacheR4kInvalidate().
01b,12oct94,caf  Tweaked documentation (SPR #3464).
01a,01oct93,cd   Derived from cacheR3kLib.c v01h.
*/

/*
DESCRIPTION
This library contains architecture-specific cache library functions for
the MIPS R7000 architecture.  The R7000 utilizes a variable-size
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
#endif

/* forward declarations */

LOCAL void *	cacheR7kMalloc (size_t bytes);
LOCAL STATUS	cacheR7kFree (void * pBuf);
LOCAL STATUS	cacheR7kFlush (CACHE_TYPE cache, void *	pVirtAdrs,
			       size_t bytes);
LOCAL STATUS	cacheR7kInvalidate (CACHE_TYPE cache, void * pVirtAdrs,
                                    size_t bytes);
LOCAL STATUS	cacheR7kClear (CACHE_TYPE cache, void *	pVirtAdrs,
			       size_t bytes);
LOCAL void * 	cacheR7kPhysToVirt (void * address);
LOCAL void * 	cacheR7kVirtToPhys (void * address);
LOCAL STATUS 	cacheR7kTextUpdate (void * address, size_t bytes);
LOCAL STATUS	cacheR7kPipeFlush (void);

/* imports */

IMPORT void	sysWbFlush ();

IMPORT void     cacheR7kDCFlush (void * pVirtAdrs, size_t bytes);
IMPORT void     cacheR7kDCFlushAll (void);
IMPORT void     cacheR7kDCInvalidate (void * pVirtAdrs, size_t bytes);
IMPORT void     cacheR7kDCInvalidateAll (void);
IMPORT void     cacheR7kDCFlushInvalidate (void * pVirtAdrs, size_t bytes);
IMPORT void     cacheR7kDCFlushInvalidateAll (void);
IMPORT void     cacheR7kICInvalidateAll (void);
IMPORT void     cacheR7kICInvalidate (void * pVirtAdrs, size_t bytes);
IMPORT void     cacheR7kPTextUpdateAll (void);
IMPORT void     cacheR7kPTextUpdate (void * pVirtAdrs, size_t bytes);

#ifdef IS_KSEGM
IMPORT VOIDFUNCPTR _func_mipsCacheSync;
IMPORT VOIDFUNCPTR _func_mmuMipsVirtPageFlush;

IMPORT void	cacheR7kSync (void * vAddr, UINT len);
IMPORT void	cacheR7kVirtPageFlush (UINT asid, void * vAddr, UINT pageSize);
#endif

/* globals */

IMPORT UINT32 cacheR7kICacheSize;
IMPORT UINT32 cacheR7kDCacheSize;
IMPORT UINT32 cacheR7kSCacheSize;
IMPORT UINT32 cacheR7kTCacheSize;
IMPORT UINT32 cacheR7kICacheLineSize;
IMPORT UINT32 cacheR7kDCacheLineSize;
IMPORT UINT32 cacheR7kSCacheLineSize;
IMPORT UINT32 cacheR7kTCacheLineSize;

/* Memory partition for cacheR7kMalloc and cacheR7kFree.
 * If NULL, use the System Partition (same as Malloc).
 */

PART_ID cacheR7kPartId = NULL;

/**************************************************************************
*
* cacheR7kLibInit - initialize the R7000 cache library
*
* This routine initializes the function pointers for the R7000 cache
* library.  The board support package can select this cache library
* by assigning the function pointer <sysCacheLibInit> to
* cacheR7kLibInit().
*
* RETURNS: OK.
*/

STATUS cacheR7kLibInit
    (
    CACHE_MODE	instMode,	/* instruction cache mode */
    CACHE_MODE	dataMode,	/* data cache mode */
    UINT32	iCacheSize,
    UINT32	iCacheLineSize,
    UINT32	dCacheSize,
    UINT32	dCacheLineSize,
    UINT32	sCacheSize,
    UINT32	sCacheLineSize,
    UINT32	tCacheSize,
    UINT32	tCacheLineSize
    )
    {
    cacheR7kICacheSize = iCacheSize;
    cacheR7kICacheLineSize = iCacheLineSize;
    cacheR7kDCacheSize = dCacheSize;
    cacheR7kDCacheLineSize = dCacheLineSize;
    cacheR7kSCacheSize = sCacheSize;
    cacheR7kSCacheLineSize = sCacheLineSize;
    cacheR7kTCacheSize = tCacheSize;
    cacheR7kTCacheLineSize = tCacheLineSize;

    cacheLib.enableRtn = NULL;	/* cacheEnable() */
    cacheLib.disableRtn = NULL;	/* cacheDisable() */

    cacheLib.lockRtn = NULL;			/* cacheLock */
    cacheLib.unlockRtn = NULL;			/* cacheUnlock */

    cacheLib.flushRtn = cacheR7kFlush;		/* cacheFlush() */
    cacheLib.pipeFlushRtn = cacheR7kPipeFlush;	/* cachePipeFlush() */
    cacheLib.textUpdateRtn = cacheR7kTextUpdate;/* cacheTextUpdate() */

    cacheLib.invalidateRtn = cacheR7kInvalidate;/* cacheInvalidate() */
    cacheLib.clearRtn = cacheR7kClear;		/* cacheClear() */

    cacheLib.dmaMallocRtn = (FUNCPTR) cacheR7kMalloc;	/* cacheDmaMalloc() */
    cacheLib.dmaFreeRtn = cacheR7kFree;			/* cacheDmaFree() */

#ifdef IS_KSEGM
    if (!IS_KSEGM(cacheR7kLibInit))
	{
	cacheLib.dmaVirtToPhysRtn = (FUNCPTR) cacheR7kVirtToPhys;
	cacheLib.dmaPhysToVirtRtn = (FUNCPTR) cacheR7kPhysToVirt;
	_func_mipsCacheSync = (VOIDFUNCPTR) cacheR7kSync;
	}
    else
	{
	_func_mipsCacheSync = (VOIDFUNCPTR) KM_TO_K0(cacheR7kSync);
	_func_mmuMipsVirtPageFlush = (VOIDFUNCPTR) cacheR7kVirtPageFlush;
	}
#else
    cacheLib.dmaVirtToPhysRtn = (FUNCPTR) cacheR7kVirtToPhys;
    cacheLib.dmaPhysToVirtRtn = (FUNCPTR) cacheR7kPhysToVirt;
#endif

    cacheDataMode	= dataMode;		/* save dataMode for enable */
    cacheDataEnabled	= TRUE;			/* d-cache is currently on */
    cacheMmuAvailable	= TRUE;			/* mmu support is provided */

    cacheFuncsSet ();				/* update cache func ptrs */

    return (OK);
    }

/**************************************************************************
*
* cacheR7kMalloc - allocate a cache-safe buffer, if possible
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

LOCAL void * cacheR7kMalloc
    (
    size_t bytes
    )
    {
    void      * pDmaBuffer;

#ifdef IS_KSEGM
    /* check for non-memory mapped case */
    if (!IS_KSEGM(cacheR7kMalloc))
	{
#endif
	int	allocBytes;
	void  * pBuffer;

	/* if NULL, set cacheR7kPartId to the system partition */
	
	if (cacheR7kPartId == NULL)
	    cacheR7kPartId = memSysPartId;

	/*
	 * Round up the allocation size so that we can store a "back pointer"
	 * to the allocated buffer, align the buffer on a cache line boundary
	 * and pad the buffer to a cache line boundary.
	 */
	allocBytes = CACHE_ROUND_UP (sizeof (void *)) + CACHE_ROUND_UP (bytes);

	if ((pBuffer =
	     (void *)memPartAlloc (cacheR7kPartId, allocBytes)) == NULL)
	    return (NULL);

	/* Flush any data that may be still sitting in the cache */
	cacheR7kDCFlushInvalidate (pBuffer, allocBytes);

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
    else
	{
	int 	pageSize;

	/* memory-mapped case */

	if ((pageSize = VM_PAGE_SIZE_GET ()) == ERROR)
	    return (NULL);

	/* make sure bytes is a multiple of pageSize. This calculation assumes
	 * that pageSize is a power of 2. */
	bytes = (bytes + (pageSize - 1)) & ~(pageSize - 1);
 
	pDmaBuffer = (void *)IOBUF_ALIGNED_ALLOC (bytes, pageSize);
	if (pDmaBuffer == NULL)
	    return (NULL);

	cacheR7kDCFlushInvalidate (pDmaBuffer, bytes);
	VM_STATE_SET (NULL, pDmaBuffer, bytes,
		      MMU_ATTR_CACHE_MSK, MMU_ATTR_CACHE_OFF);

	return (pDmaBuffer);
	}
#endif
    }

/**************************************************************************
*
* cacheR7kFree - free the buffer acquired by cacheMalloc ()
*
* This routine restores the non-cached buffer to its original state
* and does whatever else is necessary to undo the allocate function.
*
* RETURNS: OK, or ERROR if not able to undo cacheMalloc() operation
*/

LOCAL STATUS cacheR7kFree
    (
    void * pBuf
    )
    {
    void      * pCacheBuffer;
    
#ifdef IS_KSEGM
    /* Check for unmapped case */
    if (IS_KSEG1(pBuf))
	{
#endif
	pCacheBuffer = (void *)K1_TO_K0(pBuf);
	pCacheBuffer = (void *)((int)pCacheBuffer - sizeof (void *));
	memPartFree (cacheR7kPartId, *(void **)pCacheBuffer);
	return (OK);
#ifdef IS_KSEGM
	}
    else
	{
	BLOCK_HDR * pHdr;		/* pointer to block header */
	STATUS	status = OK;	/* return value */

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
#endif
    }

/**************************************************************************
*
* cacheR7kFlush - flush all or some entries in a cache
*
* This routine flushes (writes to memory)  all or some of the entries in the
* specified cache.
*
* RETURNS: OK, or ERROR if the cache type is invalid or the cache control
* is not supported.
*/

LOCAL STATUS	cacheR7kFlush
    (
    CACHE_TYPE	cache,			/* Cache to Invalidate */
    void *	pVirtAdrs,		/* Virtual Address */
    size_t	bytes 			/* Number of Bytes to Invalidate */
    )
    {
    if (IS_KSEG1(pVirtAdrs))
	return (OK);
    switch (cache)
	{
	case DATA_CACHE:
	    if (bytes == ENTIRE_CACHE)
		cacheR7kDCFlushAll ();
	    else
		cacheR7kDCFlush (pVirtAdrs, bytes);
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
* cacheR7kInvalidate - invalidate all or some entries in a cache
*
* This routine invalidates all or some of the entries in the
* specified cache.
*
* RETURNS: OK, or ERROR if the cache type is invalid or the cache control
* is not supported.
*/

LOCAL STATUS	cacheR7kInvalidate
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
		cacheR7kDCInvalidateAll ();
	    else
		cacheR7kDCInvalidate (pVirtAdrs, bytes);
	    break;
	case INSTRUCTION_CACHE:
	    if (bytes == ENTIRE_CACHE)
		cacheR7kICInvalidateAll ();
	    else
		cacheR7kICInvalidate (pVirtAdrs, bytes);
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
* cacheR7kClear - clear all or some entries in a cache
*
* This routine clears all or some of the entries in the
* specified cache.
*
* RETURNS: OK, or ERROR if the cache type is invalid or the cache control
* is not supported.
*/

LOCAL STATUS	cacheR7kClear
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
		cacheR7kDCFlushInvalidateAll ();
	    else
		cacheR7kDCFlushInvalidate (pVirtAdrs, bytes);
	    break;
	case INSTRUCTION_CACHE:
	    if (bytes == ENTIRE_CACHE)
		cacheR7kICInvalidateAll ();
	    else
		cacheR7kICInvalidate (pVirtAdrs, bytes);
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
* cacheR7kVirtToPhys - virtual-to-physical address translation
*
* This routine may be attached to the CACHE_DRV structure virtToPhysRtn
* function pointer by cacheR7kMalloc().  This implies that the virtual
* memory library is not installed, and that the "cache-safe" buffer has
* been created through the use of the R7000 K1 segment.
*
* NOMANUAL
*/

LOCAL void * cacheR7kVirtToPhys
    (
    void * address                      /* Virtual address */
    )
    {
    return ((void *) K1_TO_PHYS(address));
    }

/**************************************************************************
*
* cacheR7kPhysToVirt - physical-to-virtual address translation
*
* This routine may be attached to the CACHE_DRV structure physToVirtRtn
* function pointer by cacheR7kMalloc().  This implies that the virtual
* memory library is not installed, and that the "cache-safe" buffer has
* been created through the use of the R7000 K1 segment.
*
* NOMANUAL
*/

LOCAL void * cacheR7kPhysToVirt
    (
    void * address                      /* Physical address */
    )
    {
    return ((void *) PHYS_TO_K1(address));
    }

/**************************************************************************
*
* cacheR7kTextUpdate - invalidate updated text section
*
* This routine invalidates the specified text section so that
* the correct updated text is executed.
*
* NOMANUAL
*/

LOCAL STATUS cacheR7kTextUpdate
    (
    void * address,                     /* Physical address */
    size_t bytes 			/* bytes to invalidate */
    )
    {
    if ((bytes != ENTIRE_CACHE) &&
	((address == NULL) || (bytes == 0) || IS_KSEG1(address)))
	return (OK);
    
    if (bytes == ENTIRE_CACHE)
	cacheR7kPTextUpdateAll ();
    else
	cacheR7kPTextUpdate (address, bytes);
    return (OK);
    }


/**************************************************************************
*
* cacheR7kPipeFlush - flush R7000 write buffers to memory
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

LOCAL STATUS cacheR7kPipeFlush (void)
    {
    sysWbFlush ();
    return (OK);
    }


