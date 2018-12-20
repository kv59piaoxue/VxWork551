/* cacheR3kLib.c - MIPS R3000 cache management library */

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
01l,17may02,pes  Before aborting cacheTextUpdate() on null pointer, check for
                 ENTIRE_CACHE.
01k,08may02,pes  Add protection against null pointers, zero counts, and
                 requests involving kseg1 in cacheXXXTextUpdate().
01j,16jul01,ros  add CofE comment
01i,31jan00,dra  Suppress compiler warnings.
01h,22apr93,caf  ansification: pass a (void *) to free().
01g,24jan93,jdi  documentation cleanup for 5.1.
01f,01oct92,jcf  changed cacheLib interface.
01e,25aug92,jdi  documentation cleanup.
01d,04aug92,ajm  updated for new cacheLib.h defines, ansified.
01c,02aug92,jcf  changed initializations to match new cacheLib.h definitions.
01b,09jul92,ajm  added support for virtual to physical translations
01a,29jun92,ajm  written based on cacheSun4Lib.c
*/

/*
DESCRIPTION
This library contains architecture-specific cache library functions for
the MIPS R3000 architecture.  The R3000 utilizes a variable-size
instruction and data cache that operates in write-through mode.  Cache
line size also varies.  Cache tags may be invalidated on a per-word basis
by execution of a byte write to a specified word while the cache is
isolated.  See also the manual entry for cacheR3kALib.

For general information about caching, see the manual entry for cacheLib.

INCLUDE FILES: cacheLib.h

SEE ALSO: cacheR3kALib, cacheLib, Gerry Kane:
.I "MIPS R3000 RISC Architecture"
*/

#include	"vxWorks.h"
#include	"cacheLib.h"
#include	"memLib.h"
#include	"stdlib.h"
#include	"errno.h"

/* forward declarations */

LOCAL void *	cacheR3kMalloc (size_t bytes);
LOCAL STATUS	cacheR3kFree (void * pBuf);
LOCAL STATUS	cacheR3kInvalidate (CACHE_TYPE cache, void * pVirtAdrs, 
                                    size_t bytes);
LOCAL void * 	cacheR3kPhysToVirt (void * address);
LOCAL void * 	cacheR3kVirtToPhys (void * address);
LOCAL STATUS 	cacheR3kTextUpdate (void * address, size_t bytes);

/* IMPORTs from cacheR3kALib.s */
IMPORT void cacheR3kICReset (void);
IMPORT ULONG cacheR3kIsize (void);
IMPORT void cacheR3kDCReset (void);
IMPORT ULONG cacheR3kDsize (void); 
IMPORT void cacheR3kDCInvalidate (void * baseAddr, size_t bytes);
IMPORT void cacheR3kICInvalidate (void * baseAddr, size_t bytes);

/* globals */

size_t	cacheICacheSize = 0;	/* initialized so these go in .data */
size_t	cacheDCacheSize = 0;

/**************************************************************************
*
* cacheR3kLibInit - initialize the R3000 cache library
*
* This routine initializes the function pointers for the R3000 cache
* library.  The board support package can select this cache library 
* by calling this routine.
*
* RETURNS: OK.
*/

STATUS cacheR3kLibInit
    (
    CACHE_MODE	instMode,	/* instruction cache mode */
    CACHE_MODE	dataMode	/* data cache mode */
    )
    {
    cacheLib.enableRtn = NULL;			/* cacheEnable() */
    cacheLib.disableRtn =  NULL;		/* cacheDisable() */

    cacheLib.lockRtn = NULL;			/* cacheLock */
    cacheLib.unlockRtn = NULL;			/* cacheUnlock */

    cacheLib.flushRtn = NULL;			/* cacheFlush() */
    cacheLib.pipeFlushRtn = NULL;		/* cachePipeFlush() */
    cacheLib.textUpdateRtn = cacheR3kTextUpdate;/* cacheTextUpdate() */

    cacheLib.invalidateRtn = cacheR3kInvalidate;/* cacheInvalidate() */
    cacheLib.clearRtn = cacheR3kInvalidate;	/* cacheClear() */

    cacheLib.dmaMallocRtn = (FUNCPTR) cacheR3kMalloc;	/* cacheDmaMalloc() */
    cacheLib.dmaFreeRtn = cacheR3kFree;			/* cacheDmaFree() */

    cacheLib.dmaVirtToPhysRtn = (FUNCPTR) cacheR3kVirtToPhys;
    cacheLib.dmaPhysToVirtRtn = (FUNCPTR) cacheR3kPhysToVirt;

    cacheR3kICReset ();				/* reset instruction cache */
    cacheICacheSize = cacheR3kIsize ();		/* set i-cache size */
    cacheR3kDCReset ();				/* reset data cache */
    cacheDCacheSize = cacheR3kDsize ();		/* set d-cache size */

    cacheDataMode	= dataMode;		/* save dataMode for enable */
    cacheDataEnabled	= TRUE;			/* d-cache is currently on */
    cacheMmuAvailable	= TRUE;			/* mmu support is provided */

    cacheFuncsSet ();				/* update cache func ptrs */

    return (OK);
    }

/**************************************************************************
*
* cacheR3kMalloc - allocate a cache-safe buffer, if possible
*
* This routine will attempt to return a pointer to a section of memory
* that will not experience any cache coherency problems.  It also sets
* the flush and invalidate function pointers to NULL or to the respective
* flush and invalidate routines.  Since the cache is write-through, the
* flush function pointer will always be NULL.
*
* RETURNS: A pointer to the non-cached buffer, or NULL.
*/

LOCAL void * cacheR3kMalloc
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
* cacheR3kFree - free the buffer acquired by cacheMalloc ()
*
* This routine restores the non-cached buffer to its original state
* and does whatever else is necessary to undo the allocate function.
*
* RETURNS: OK, or ERROR if not able to undo cacheMalloc() operation
*/

LOCAL STATUS cacheR3kFree
    (
    void * pBuf 
    )
    {
    free ((void *) K1_TO_K0(pBuf));
    return (OK);
    }

/**************************************************************************
*
* cacheR3kInvalidate - invalidate all or some entries in a cache
*
* This routine invalidates all or some of the entries in the
* specified cache.
*
* RETURNS: OK, or ERROR if the cache type is invalid or the cache control
* is not supported.
*/

LOCAL STATUS	cacheR3kInvalidate
    (
    CACHE_TYPE	cache,			/* Cache to Invalidate */
    void *	pVirtAdrs,		/* Virtual Address */
    size_t	bytes 			/* Number of Bytes to Invalidate */
    )
    {
    switch (cache)
	{
	case DATA_CACHE:
	    cacheR3kDCInvalidate (pVirtAdrs, bytes);
	    break;
	case INSTRUCTION_CACHE:
	    cacheR3kICInvalidate (pVirtAdrs, bytes);
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
* cacheR3kVirtToPhys - virtual-to-physical address translation
*
* This routine may be attached to the CACHE_DRV structure virtToPhysRtn
* function pointer by cacheR3kMalloc().  This implies that the virtual
* memory library is not installed, and that the "cache-safe" buffer has
* been created through the use of the R3000 K1 segment.
*
* NOMANUAL
*/

LOCAL void * cacheR3kVirtToPhys
    (
    void * address                      /* Virtual address */
    )
    {
    return ((void *) K1_TO_PHYS(address));
    }

/**************************************************************************
*
* cacheR3kPhysToVirt - physical-to-virtual address translation
*
* This routine may be attached to the CACHE_DRV structure physToVirtRtn
* function pointer by cacheR3kMalloc().  This implies that the virtual
* memory library is not installed, and that the "cache-safe" buffer has
* been created through the use of the R3000 K1 segment.
*
* NOMANUAL
*/

LOCAL void * cacheR3kPhysToVirt
    (
    void * address                      /* Physical address */
    )
    {
    return ((void *) PHYS_TO_K1(address));
    }

/**************************************************************************
*
* cacheR3kTextUpdate - invalidate updated text section
*
* This routine invalidates the specified text section so that
* the correct updated text is executed.
*
* NOMANUAL
*/

LOCAL STATUS cacheR3kTextUpdate
    (
    void * address,                     /* Physical address */
    size_t bytes 			/* bytes to invalidate */
    )
    {
    if ((bytes != ENTIRE_CACHE) &&
	((address == NULL) || (bytes == 0) || IS_KSEG1(address)))
	return (OK);
    
    return (cacheR3kInvalidate (INSTRUCTION_CACHE, address, bytes));
    }


