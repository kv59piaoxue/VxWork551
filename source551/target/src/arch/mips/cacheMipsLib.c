/* cacheMipsLib.c - MIPS cache management library */

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
01g,09may02,jmt  Modifications from Tx49xx cache library review
01f,16jul01,ros  add CofE comment
01e,29mar01,mem  written.
*/

/*
DESCRIPTION
This library contains architecture-specific cache library functions for
the MIPS architecture.

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
#endif
#include "private/vmLibP.h"
#include "private/funcBindP.h"

/* forward declarations */

/* imports */

IMPORT void	sysWbFlush ();

/**************************************************************************
*
* cacheMipsMalloc - allocate a cache-safe buffer, if possible
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

void * cacheMipsMalloc
    (
    size_t bytes 
    )
    {
    void      * pDmaBuffer;
#ifdef IS_KSEGM
    int 	pageSize;
#endif

#ifdef IS_KSEGM
    /* check for non-memory mapped case */

    if (IS_KSEG0(cacheMipsMalloc))
	{
#endif
	int	allocBytes;
	void  * pBuffer;

	/* Round up the allocation size so that we can store a "back pointer"
	 * to the allocated buffer, align the buffer on a cache line boundary
	 * and pad the buffer to a cache line boundary.
	 * sizeof(void *) 		for "back pointer"
	 * _CACHE_ALIGN_SIZE-1	for cache line alignment
	 * _CACHE_ALIGN_SIZE-1	for cache line padding
	 */

	allocBytes = CACHE_ROUND_UP(sizeof (void *)) +
	  CACHE_ROUND_UP(bytes);

	if ((pBuffer = (void *)malloc (allocBytes)) == NULL)
	    return (NULL);

	/* Flush any data that may be still sitting in the cache */

	cacheClear (DATA_CACHE, pBuffer, allocBytes);
	cacheInvalidate (INSTRUCTION_CACHE, pBuffer, allocBytes);

	pDmaBuffer = pBuffer;

	/* allocate space for the back pointer */

	pDmaBuffer = (void *)((int) pDmaBuffer + sizeof (void *));

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

    /* make sure bytes is a multiple of pageSize. This calculation assumes
     * that pageSize is a power of 2.
     */

    bytes = (bytes + (pageSize - 1)) & ~(pageSize - 1);
 
    pDmaBuffer = (void *)IOBUF_ALIGNED_ALLOC (bytes, pageSize);
    if (pDmaBuffer == NULL)
	return (NULL);

    VM_STATE_SET (NULL, pDmaBuffer, bytes,
		  MMU_ATTR_CACHE_MSK, MMU_ATTR_CACHE_OFF);

    return (pDmaBuffer);
#endif
    }

/**************************************************************************
*
* cacheMipsFree - free the buffer acquired by cacheMalloc ()
*
* This routine restores the non-cached buffer to its original state
* and does whatever else is necessary to undo the allocate function.
*
* RETURNS: OK, or ERROR if not able to undo cacheMalloc() operation
*/

STATUS cacheMipsFree
    (
    void * pBuf 
    )
    {
#ifdef IS_KSEGM
    BLOCK_HDR * pHdr;		/* pointer to block header */
#endif
    STATUS	status = OK;	/* return value */
    void      * pCacheBuffer;
    
#ifdef IS_KSEGM
    /* Check for unmapped case */

    if (IS_KSEG1(pBuf))
	{
#endif
	pCacheBuffer = (void *)K1_TO_K0(pBuf);
	pCacheBuffer = (void *)((int) pCacheBuffer - sizeof (void *));
	free (*(void **)pCacheBuffer);
	return (status);
#ifdef IS_KSEGM
	}
    else
	{
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
* cacheMipsVirtToPhys - virtual-to-physical address translation
*
* This routine may be attached to the CACHE_DRV structure virtToPhysRtn
* function pointer by cacheMipsMalloc().
*
* NOMANUAL
*/

void * cacheMipsVirtToPhys
    (
    void * address                      /* Virtual address */
    )
    {
#ifdef IS_KSEGM
    void *	physAddr;
#endif
    
    if (IS_KSEG1(address))
	return ((void *) K1_TO_PHYS(address));
#ifdef IS_KSEGM
    if (VM_TRANSLATE (NULL, address, &physAddr, VIRT_TO_PHYS) == OK)
	return (physAddr); 
#endif
    return (NULL);
    }

/**************************************************************************
*
* cacheMipsPhysToVirt - physical-to-virtual address translation
*
* This routine may be attached to the CACHE_DRV structure physToVirtRtn
* function pointer by cacheMipsMalloc().
*
* NOMANUAL
*/

void * cacheMipsPhysToVirt
    (
    void * address                      /* Physical address */
    )
    {
#ifdef IS_KSEGM
    void *	virtAddr;

    if (VM_TRANSLATE (NULL, address, &virtAddr, VIRT_TO_PHYS) == OK)
	return (virtAddr); 
#endif

    /* PHYS_TO_K1() only works for lower 512M of physical memory */

    if (((ULONG) address) < K1SIZE)
	return ((void *) PHYS_TO_K1(address));

    return (NULL);
    }

/**************************************************************************
*
* cacheMipsPipeFlush - flush MIPS write buffers to memory
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

STATUS cacheMipsPipeFlush (void)
    {
    sysWbFlush ();
    return (OK);
    }
