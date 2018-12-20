/* cacheSh7729Lib.c - Hitachi SH7729 cache management library */

/* Copyright 1996-2001 Wind River Systems, Inc. */
#include "copyright_wrs.h"

/*
modification history
--------------------
01k,23nov01,hk   removed checking vmLibInfo.vmLibInstalled in cacheSh7729DmaFree
		 and cacheSh7729P2DmaFree for INCLUDE_MMU_BASIC (SPR 71807).
01k,24oct01,zl   fixes for doc builds.
01j,27feb01,hk   change HITACHI to Hitachi in library description.
01i,07dec00,hk   set cacheMmuAvailable to T/F depending on data cache mode.
01h,21nov00,hk   change to set NULL for cacheLib.flushRtn in write-through mode.
01g,18nov00,hk   made cacheSh7729Disable() NMI-safe. secured locked cache way
		 from cacheClear(ENTIRE_CACHE).
01f,17nov00,hk   fixed cache locking support: changed cacheSh7729CCR2Set() to
		 return CCR2 on SH7729R. changed cacheSh7729Load() to return
		 status. enabled cache locking in copyback mode for SH7729R.
		 added cacheSh7729CCR2Get(). reset CCR2 upon disabling cache.
		 changed cacheSh7729Lock() to disable cache before modifying
		 CCR2, and to verify cached data and return the locking status.
01e,25oct00,hk   disabled cache locking in copyback mode.
01d,11sep00,hk   moved critical operations to cacheSh7729ALib. made cache tag
		 operations more precise. improved cacheSh7729P2DmaMalloc().
		 added cache dump tools. added cacheSh7729Lock().
01c,28jan99,jmb  fix copyback mode -- "way" values were incorrect in
                 clear routine.  Also, add a writeback to cacheEnable so
                 that calling cacheEnable when cache is already enabled
                 will invalidate without hanging in copyback mode.
01b,01jul98,jmc  increased cache size to 256 entries
01a,24jun98,jmc  derived from cacheSh7700Lib.c-01k,06feb98,jmc.
*/

/*
DESCRIPTION
This library contains architecture-specific cache library functions for
the Hitachi SH7729 architecture.

The cache is 16-Kbytes (16 bytes X 256 entries X 4 ways) mixed instruction
and data cache that operates in write-through or write-back (copyback) mode.
Cache line size is fixed at 16 bytes, and the cache address array holds 
physical addresses as cache tags.  Cache entries may be "flushed" by accesses
to the address array in privileged mode.  There is a write-back buffer which
can hold one line of cache entry, and the completion of write-back cycle is
assured by accessing to any cache through region.

For general information about caching, see the manual entry for cacheLib.

INCLUDE FILES: cacheLib.h

SEE ALSO: cacheLib
*/

#include "vxWorks.h"
#include "errnoLib.h"
#include "cacheLib.h"
#include "intLib.h"			/* for intLock()/intUnlock() */
#include "memLib.h"			/* for memalign() */
#include "stdlib.h"			/* for malloc()/free() */
#include "string.h"			/* for bzero() */
#include "private/memPartLibP.h"	/* for BLOCK_TO_HDR() */
#include "private/vmLibP.h"
#include "private/funcBindP.h"		/* for _func_valloc */

/* imports */

IMPORT void cacheSh7729CCRSetOp (UINT32 ccr);
IMPORT UINT32 cacheSh7729CCRGet (void);
IMPORT UINT32 cacheSh7729CCR2SetOp (UINT32 ccr2);
IMPORT STATUS cacheSh7729OnOp (BOOL on);
IMPORT STATUS cacheSh7729LoadOp (UINT32 *p_ccr2, UINT32 from, UINT32 to);
IMPORT void cacheSh7729CFlushOp (void);
IMPORT void cacheSh7729AFlushOp (UINT32 from, UINT32 to);
IMPORT void cacheSh7729MFlushOp (UINT32 *pt, int ix, UINT32 from, UINT32 to);

/* local definitions */

#define CAC_ADRS_ARRAY		0xf0000000
#define CAC_DATA_ARRAY		0xf1000000

#define CAC_DATA_SIZE		16384
#define CAC_LINE_SIZE		16


/* SH7729 Cache Control Register bit define */
#define CCR_CACHE_FLUSH		0x00000008	/* no write back */
#define CCR_WRITE_BACK_P1	0x00000004	/* set P1 to write-back */
#define CCR_WRITE_THRU		0x00000002
#define CCR_CACHE_ENABLE	0x00000001

/* SH7729 Cache Control Register-2 bit define */
#define CCR2_LOCK_WAY2		0x00000001	/* lock way-2 */
#define CCR2_LOAD_WAY2		0x00000002	/* load way-2 */
#define CCR2_LOCK_WAY3		0x00000100	/* lock way-3 */
#define CCR2_LOAD_WAY3		0x00000200	/* load way-3 */


/* forward declarations */

LOCAL STATUS cacheSh7729Enable (CACHE_TYPE cache);
LOCAL STATUS cacheSh7729Disable (CACHE_TYPE cache);
LOCAL STATUS cacheSh7729Lock (CACHE_TYPE cache, void *from, size_t bytes);
LOCAL STATUS cacheSh7729Unlock (CACHE_TYPE cache, void *from, size_t bytes);
LOCAL STATUS cacheSh7729Clear (CACHE_TYPE cache, void *from, size_t bytes);
LOCAL STATUS cacheSh7729Invalidate (CACHE_TYPE cache, void *from, size_t bytes);
LOCAL void * cacheSh7729DmaMalloc (size_t bytes);
LOCAL STATUS cacheSh7729DmaFree (void * pBuf);
LOCAL void * cacheSh7729P2DmaMalloc (size_t bytes);
LOCAL STATUS cacheSh7729P2DmaFree (void * pBuf);

/* local function pointers to relocate cacheSh7729ALib entries */

LOCAL VOIDFUNCPTR cacheSh7729CCRSet  = (VOIDFUNCPTR)0x1234;
LOCAL FUNCPTR     cacheSh7729CCR2Set =     (FUNCPTR)0x1234;
LOCAL FUNCPTR     cacheSh7729On      =     (FUNCPTR)0x1234;
LOCAL FUNCPTR     cacheSh7729Load    =     (FUNCPTR)0x1234;
LOCAL VOIDFUNCPTR cacheSh7729CFlush  = (VOIDFUNCPTR)0x1234;
LOCAL VOIDFUNCPTR cacheSh7729AFlush  = (VOIDFUNCPTR)0x1234;
LOCAL VOIDFUNCPTR cacheSh7729MFlush  = (VOIDFUNCPTR)0x1234;

LOCAL UINT32 ccr2 = 0;		/* copy of write-only CCR2 */

/******************************************************************************
*
* cacheSh7729LibInit - initialize the SH7729 cache library
* 
* This routine initializes the cache library for the Hitachi SH7729 processor.
* It initializes the function pointers and configures the caches to the
* specified cache modes.  Modes should be set before caching is enabled.
* If two complementary flags are set (enable/disable), no action is taken
* for any of the input flags.
*
* The following caching modes are available for the SH7729 processor:
*
* .TS
* tab(|);
* l l l l.
* | SH7729:| CACHE_WRITETHROUGH  | (cache for instruction and data)
* |        | CACHE_COPYBACK      | (cache for instruction and data)
* |        | CACHE_COPYBACK_P1   | (copy-back cache for P1)
* |        | CACHE_DMA_BYPASS_P0 | (allocate DMA buffer to P2, free it to P0)
* |        | CACHE_DMA_BYPASS_P1 | (allocate DMA buffer to P2, free it to P1)
* |        | CACHE_DMA_BYPASS_P3 | (allocate DMA buffer to P2, free it to P3)
* .TE
*
* The CACHE_DMA_BYPASS_Px modes allow to allocate "cache-safe" buffers without
* MMU.  If none of CACHE_DMA_BYPASS_Px modes is specified, cacheDmaMalloc()
* returns a cache-safe buffer on logical space, which is created by the MMU.
* If CACHE_DMA_BYPASS_P0 is selected, cacheDmaMalloc() returns a cache-safe
* buffer on P2 space, and cacheDmaFree() releases the buffer to P0 space.
* Namely, if the system memory partition is located on P0, cache-safe buffers
* can be allocated and freed without MMU, by selecting CACHE_DMA_BYPASS_P0.
* 
* RETURNS: OK, or ERROR.
*/

STATUS cacheSh7729LibInit
    (
    CACHE_MODE	instMode,	/* instruction cache mode (ignored) */
    CACHE_MODE	dataMode	/* data cache mode */
    )
    {
    /* setup function pointers for cache library (declared in funcBind.c) */

    cacheLib.enableRtn          = cacheSh7729Enable;
    cacheLib.disableRtn         = cacheSh7729Disable;

    cacheLib.lockRtn		= cacheSh7729Lock;
    cacheLib.unlockRtn		= cacheSh7729Unlock;

    /* Flush and invalidate are the same in COPYBACK mode.  Setting the flush
     * bit in the CCR doesn't do a write-back, so call cacheSh7729Clear if
     * using COPYBACK (write-back) mode.
     */
    if (dataMode & (CACHE_COPYBACK | CACHE_COPYBACK_P1))
	{
	cacheLib.flushRtn	= cacheSh7729Clear;
	cacheLib.invalidateRtn	= cacheSh7729Clear;
	}
    else
	{
	cacheLib.flushRtn	= NULL;
	cacheLib.invalidateRtn	= cacheSh7729Invalidate;
	}

    cacheLib.clearRtn           = cacheSh7729Clear;

    cacheLib.textUpdateRtn      = NULL;		/* inst/data mixed cache */
    cacheLib.pipeFlushRtn       = NULL;

    /* setup P2 function pointers for cache sensitive operations */

    cacheSh7729CCRSet		= (VOIDFUNCPTR)(((UINT32)cacheSh7729CCRSetOp
				& SH7700_PHYS_MASK) | SH7700_P2_BASE);
    cacheSh7729CCR2Set		= (FUNCPTR)(((UINT32)cacheSh7729CCR2SetOp
				& SH7700_PHYS_MASK) | SH7700_P2_BASE);
    cacheSh7729On		= (FUNCPTR)(((UINT32)cacheSh7729OnOp
				& SH7700_PHYS_MASK) | SH7700_P2_BASE);
    cacheSh7729Load		= (FUNCPTR)(((UINT32)cacheSh7729LoadOp
				& SH7700_PHYS_MASK) | SH7700_P2_BASE);
    cacheSh7729CFlush		= (VOIDFUNCPTR)(((UINT32)cacheSh7729CFlushOp
				& SH7700_PHYS_MASK) | SH7700_P2_BASE);
    cacheSh7729AFlush		= (VOIDFUNCPTR)(((UINT32)cacheSh7729AFlushOp
				& SH7700_PHYS_MASK) | SH7700_P2_BASE);
    cacheSh7729MFlush		= (VOIDFUNCPTR)(((UINT32)cacheSh7729MFlushOp
				& SH7700_PHYS_MASK) | SH7700_P2_BASE);

    /* select cache-safe malloc/free routines for DMA buffer */

    if (dataMode &
        (CACHE_DMA_BYPASS_P0 | CACHE_DMA_BYPASS_P1 | CACHE_DMA_BYPASS_P3))
	{
	cacheLib.dmaMallocRtn   = (FUNCPTR)cacheSh7729P2DmaMalloc;
	cacheLib.dmaFreeRtn     = cacheSh7729P2DmaFree;
	cacheMmuAvailable	= TRUE;		/* for cacheFuncsSet() */
	}
    else
	{
	cacheLib.dmaMallocRtn   = (FUNCPTR)cacheSh7729DmaMalloc;
	cacheLib.dmaFreeRtn     = cacheSh7729DmaFree;
	cacheMmuAvailable	= FALSE;	/* needs MMU support for cache
						   safe allocation */
	}

    cacheLib.dmaVirtToPhysRtn	= NULL;
    cacheLib.dmaPhysToVirtRtn	= NULL;

    /* check for parameter errors (ignore instMode) */

    if ((dataMode & ~(CACHE_WRITETHROUGH | CACHE_COPYBACK | CACHE_COPYBACK_P1 |
            CACHE_DMA_BYPASS_P0 | CACHE_DMA_BYPASS_P1 | CACHE_DMA_BYPASS_P3)) ||
	((dataMode & CACHE_WRITETHROUGH)  && (dataMode & CACHE_COPYBACK))     ||
	((dataMode & CACHE_DMA_BYPASS_P0) && (dataMode & CACHE_DMA_BYPASS_P1))||
	((dataMode & CACHE_DMA_BYPASS_P1) && (dataMode & CACHE_DMA_BYPASS_P3))||
	((dataMode & CACHE_DMA_BYPASS_P3) && (dataMode & CACHE_DMA_BYPASS_P0)))
	{
	errnoSet (S_cacheLib_INVALID_CACHE);
	return ERROR;
	}

    /* initialize cache modes (declared in cacheLib.c) */

    cacheDataMode	= dataMode;
    cacheDataEnabled	= FALSE;

    /* disable cache safely */

    cacheLib.disableRtn (DATA_CACHE);

    /* initialize CCR and CCR2 */
	{
	UINT32 ccr = 0;

	if (dataMode & CACHE_WRITETHROUGH) ccr |= CCR_WRITE_THRU;
	if (dataMode & CACHE_COPYBACK_P1)  ccr |= CCR_WRITE_BACK_P1;

	cacheSh7729CCRSet (ccr);		/* cache is still disabled */

	cacheSh7729CCR2Set (ccr2);		/* unlock way-2 and way-3 */
	}

    return OK;
    }

/******************************************************************************
*
* cacheSh7729CCR2Get - get value of CCR2
*
* This routine returns the current value of CCR2
*
* NOMANUAL
*/

UINT32 cacheSh7729CCR2Get (void)
    {
    return ccr2;	/* return copied variable since CCR2 is write-only */
    }

/******************************************************************************
*
* cacheSh7729Enable - enable a SH7729 cache
*
* This routine invalidates and enables the specified SH7729 cache.
*              ^^^^^^^^^^^     ^^^^^^^
* RETURNS: OK, or ERROR if the specified cache type was invalid.
*
* NOMANUAL
*/

LOCAL STATUS cacheSh7729Enable
    (
    CACHE_TYPE cache
    )
    {
    STATUS status;

    switch (cache)
	{
	case DATA_CACHE:
	    if ((status = cacheSh7729On (TRUE)) == OK)
		{
		cacheDataEnabled = TRUE;
		cacheFuncsSet ();	/* set cache function pointers */
		}
	    break;

	default:
	    errno = S_cacheLib_INVALID_CACHE;

	case INSTRUCTION_CACHE:
	    status = ERROR;
	}

    return status;
    }

/******************************************************************************
*
* cacheSh7729Disable - disable a SH7729 cache
*
* This routine flushes and disables the specified SH7729 cache.
*              ^^^^^^^     ^^^^^^^^
* RETURNS: OK, or ERROR if the specified cache type was invalid.
*
* NOMANUAL
*/

LOCAL STATUS cacheSh7729Disable
    (
    CACHE_TYPE cache
    )
    {
    STATUS status;

    switch (cache) 
	{
	case DATA_CACHE:

	    if (ccr2 != 0)
		{
		ccr2 = 0;

		cacheSh7729CCR2Set (ccr2);	/* unlock way-2 and way-3 */
		}

	    if ((status = cacheSh7729On (FALSE)) == OK)	/* flush and disable */
		{
		cacheDataEnabled = FALSE;
		cacheFuncsSet ();	/* clear cache function pointers */
		}
	    break;

	default:
	    errno = S_cacheLib_INVALID_CACHE;

	case INSTRUCTION_CACHE:
	    status = ERROR;
	}

    return status;
    }

/******************************************************************************
*
* cacheSh7729Lock - lock a range of memory to specified cache way
*
* NOMANUAL
*/

LOCAL STATUS cacheSh7729Lock
    (
    CACHE_TYPE cache,
    void *     from,
    size_t     bytes
    )
    {
    UINT32 p = (UINT32)from;
    UINT32 ca_begin, ca_end;	/* address to cache */
    UINT32 da;			/* data array base address */

    if (p >= SH7700_P2_BASE && p <= (SH7700_P2_BASE | SH7700_PHYS_MASK))
	return ERROR;					/* P2 non-cacheable */
    else if (p >= SH7700_P4_BASE)
	return ERROR;					/* P4 non-cacheable */
    else if (bytes == 0)
	return OK;

    switch (cache)
	{
	case WAY2_CACHE:
	    ccr2 |= (CCR2_LOAD_WAY2 | CCR2_LOCK_WAY2);
	    da = 0xf1002000;
	    break;

	case WAY3_CACHE:
	    ccr2 |= (CCR2_LOAD_WAY3 | CCR2_LOCK_WAY3);
	    da = 0xf1003000;
	    break;

	default:
	    return ERROR;
	}

    /* normalize address range to lock */

    ca_begin = p & ~(CAC_LINE_SIZE - 1);
    ca_end   = p + bytes - 1;

    if (ca_end > ca_begin + 4095)
	ca_end = ca_begin + 4095;

    /* lock-in, update ccr2 */

    if (cacheSh7729Load (&ccr2, ca_begin, ca_end) != OK)
	return ERROR;

    /* verify locked data */

    for (p = ca_begin; p <= ca_end; p += 4)
	{
	UINT32 cached = *(UINT32 *)(da | (p & 0x00000ffc));
	UINT32 memory = *(UINT32 *)p;

	if (cached != memory)
	    return ERROR;
	}

    return OK;
    }

/******************************************************************************
*
* cacheSh7729Unlock - unlock specified cache way
*
* NOMANUAL
*/

LOCAL STATUS cacheSh7729Unlock
    (
    CACHE_TYPE cache,
    void *     from,
    size_t     bytes
    )
    {
    switch (cache)
	{
	case WAY2_CACHE: ccr2 &= ~(CCR2_LOAD_WAY2 | CCR2_LOCK_WAY2);	break;
	case WAY3_CACHE: ccr2 &= ~(CCR2_LOAD_WAY3 | CCR2_LOCK_WAY3);	break;
	default:
	    return ERROR;
	}

    cacheSh7729CCR2Set (ccr2);

    return OK;
    }

/******************************************************************************
*
* cacheSh7729Invalidate - invalidate all or some entries from a SH7729 cache
*
* This routine invalidates all or some entries of the SH7729 cache.
*
* RETURNS: OK, or ERROR if the cache type is invalid or the cache control
* is not supported.
*
* NOMANUAL
*/

LOCAL STATUS cacheSh7729Invalidate
    (
    CACHE_TYPE cache,
    void *     from,
    size_t     bytes
    )
    {
    if (bytes == ENTIRE_CACHE)
	{
	UINT32 ccr = cacheSh7729CCRGet ();

	if ((ccr & (CCR_WRITE_BACK_P1 | CCR_WRITE_THRU)) == CCR_WRITE_THRU)
	    {
	    cacheSh7729CFlush ();
	    return OK;
	    }
	}

    return cacheSh7729Clear (cache, from, bytes);
    }

/******************************************************************************
*
* cacheSh7729Clear - clear all or some entries from a SH7729 cache
*
* This routine flushes and invalidates all or some entries of the specified
* SH7729 cache.
*
* RETURNS: OK, or ERROR if the cache type is invalid or the cache control
* is not supported.
*
* NOMANUAL
*/

LOCAL STATUS cacheSh7729Clear
    (
    CACHE_TYPE cache,
    void *     from,		/* address to clear */
    size_t     bytes
    )
    {
    UINT32 p = (UINT32)from;
    UINT32 ix;
    UINT32 c_size;					/* cache size */
    int way, lastway;

    if (p >= SH7700_P2_BASE && p <= (SH7700_P2_BASE | SH7700_PHYS_MASK))
	return ERROR;					/* P2 non-cacheable */
    else if (p >= SH7700_P4_BASE)
	return ERROR;					/* P4 non-cacheable */

    c_size = CAC_DATA_SIZE;
    lastway = 3;

    if (bytes == 0)
	{
	return OK;
	}
    else if (bytes == ENTIRE_CACHE)
	{
	for (way = 0; way <= lastway; way++)
	    {
	    if ((way == 2 && (ccr2 & CCR2_LOCK_WAY2)) ||
		(way == 3 && (ccr2 & CCR2_LOCK_WAY3)))
		{
		continue;	/* skip locked way */
		}

	    for (ix = 0; ix <= 0xff0; ix += CAC_LINE_SIZE)
		{
		UINT32 *pt = (UINT32 *)(CAC_ADRS_ARRAY | (way << 12) | ix);

		cacheSh7729MFlush (pt, -1, 0, 0);
		}
	    }
	}
    else
	{
	UINT32 ca_begin = p & ~(CAC_LINE_SIZE - 1);
	UINT32 ca_end   = p + bytes - 1;

	if (bytes < c_size) /* do associative purge */
	    {
	    cacheSh7729AFlush (ca_begin, ca_end);
	    }
	else /* check every cache tag */
	    {
	    for (way = 0; way <= lastway; way++)
		{
		for (ix = 0; ix <= 0xff0; ix += CAC_LINE_SIZE)
		    {
		    UINT32 *pt = (UINT32 *)(CAC_ADRS_ARRAY | (way << 12) | ix);

		    cacheSh7729MFlush (pt, ix, ca_begin, ca_end);
		    }
		}
	    }
	}

    return OK;
    }

/******************************************************************************
*
* cacheSh7729DmaMalloc - allocate a cache-safe buffer
*
* This routine attempts to return a pointer to a section of memory that will
* not experience cache coherency problems.  This routine is only called when
* MMU support is available for cache control.
*
* INTERNAL
* We check if the cache is actually on before allocating the memory.  It is
* possible that the user wants Memory Management Unit (MMU) support but does
* not need caching.
*
* RETURNS: A pointer to a cache-safe buffer, or NULL.
*
* NOMANUAL
*/

LOCAL void *cacheSh7729DmaMalloc
    (
    size_t bytes
    )
    {
    void *pBuf;
    int   pageSize;

    if (cacheDataEnabled == FALSE)
	return malloc (bytes);		/* cache is off just allocate buffer */

    if ((pageSize = VM_PAGE_SIZE_GET ()) == ERROR)
	return NULL;

    /* make sure bytes is a multiple of pageSize */

    bytes = bytes / pageSize * pageSize + pageSize;

    if (_func_valloc == NULL || (pBuf = (void *)(*_func_valloc)(bytes)) == NULL)
        return NULL;

    VM_STATE_SET (NULL, pBuf, bytes,
                  VM_STATE_MASK_CACHEABLE, VM_STATE_CACHEABLE_NOT);

    return pBuf;
    }

/******************************************************************************
*
* cacheSh7729DmaFree - free the buffer acquired by cacheSh7729DmaMalloc()
*
* This routine returns to the free memory pool a block of memory previously
* allocated with cacheSh7729DmaMalloc().  The buffer is marked cacheable.
*
* RETURNS: OK, or ERROR if cacheSh7729DmaMalloc() cannot be undone.
*
* NOMANUAL
*/

LOCAL STATUS cacheSh7729DmaFree
    (
    void *pBuf
    )
    {
    STATUS status = OK;

    if (cacheDataEnabled)
        {
	BLOCK_HDR *pHdr = BLOCK_TO_HDR (pBuf);

        status = VM_STATE_SET (NULL, pBuf,
			       (pHdr->nWords * 2) - sizeof(BLOCK_HDR),
                               VM_STATE_MASK_CACHEABLE, VM_STATE_CACHEABLE);
        }

    free (pBuf);

    return status;
    }

/******************************************************************************
*
* cacheSh7729P2DmaMalloc - allocate a cache-safe buffer from P2 region
*
* This routine attempts to return a pointer to a section of memory that will
* not experience cache coherency problems.  This routine may be called when
* MMU support is NOT available for cache control.
*
* RETURNS: A pointer to a cache-safe buffer, or NULL.
*
* NOMANUAL
*/

LOCAL void *cacheSh7729P2DmaMalloc
    (
    size_t bytes
    )
    {
    void *pBuf;
    int alignment = VM_PAGE_SIZE_GET ();

    if (alignment != ERROR && _func_valloc != NULL)
	{
	/* adjust bytes to a multiple of MMU page size */

	bytes = bytes / alignment * alignment + alignment;

	/* get a page aligned memory */

	if ((pBuf = (void *)(*_func_valloc)(bytes)) == NULL)
	    return NULL;

	/* mark it as non-cacheable, non-writable on virtual space */

	VM_STATE_SET (NULL, pBuf, bytes,
		      VM_STATE_MASK_WRITABLE | VM_STATE_MASK_CACHEABLE,
		      VM_STATE_WRITABLE_NOT  | VM_STATE_CACHEABLE_NOT);
	}
    else
	{
	/* adjust bytes to a multiple of cache line length */

	alignment = _CACHE_ALIGN_SIZE;

	bytes = bytes / alignment * alignment + alignment;

	/* use memalign() to avoid sharing a cache-line with other buffers */

	if ((pBuf = memalign (alignment, bytes)) == NULL)
	    return NULL;
	}

    /* make sure nothing in pBuf is cached on cacheable region */

    if (cacheLib.flushRtn != NULL)
	cacheLib.flushRtn (DATA_CACHE, pBuf, bytes);

    /* relocate the buffer to P2 (mmu-bypass, non-cacheable) region */

    return (void *)(((UINT32)pBuf & SH7700_PHYS_MASK) | SH7700_P2_BASE);
    }

/******************************************************************************
*
* cacheSh7729P2DmaFree - free the buffer acquired by cacheSh7729P2DmaMalloc()
*
* This routine returns to the free memory pool a block of memory previously
* allocated with cacheSh7729P2DmaMalloc().
*
* RETURNS: OK, or ERROR if cacheSh7729DmaMalloc() cannot be undone.
*
* NOMANUAL
*/

LOCAL STATUS cacheSh7729P2DmaFree
    (
    void *pBuf
    )
    {
    STATUS status = OK;
    UINT32 p = (UINT32)pBuf;

    if (p < SH7700_P2_BASE || p > (SH7700_P2_BASE | SH7700_PHYS_MASK))
	return ERROR;

    if (cacheDataMode & CACHE_DMA_BYPASS_P0)
	p =  p & SH7700_PHYS_MASK;			/* relocate to P0 */
    else if (cacheDataMode & CACHE_DMA_BYPASS_P1)
	p = (p & SH7700_PHYS_MASK) | SH7700_P1_BASE;	/* relocate to P1 */
    else if (cacheDataMode & CACHE_DMA_BYPASS_P3)
	p = (p & SH7700_PHYS_MASK) | SH7700_P3_BASE;	/* relocate to P3 */
    else
	return ERROR;

    if (VM_PAGE_SIZE_GET () != ERROR && _func_valloc != NULL)
	{
	BLOCK_HDR *pHdr = BLOCK_TO_HDR ((void *)p);

	status = VM_STATE_SET (NULL, (void *)p,
			       (pHdr->nWords * 2) - sizeof(BLOCK_HDR),
			       VM_STATE_MASK_WRITABLE | VM_STATE_MASK_CACHEABLE,
			       VM_STATE_WRITABLE      | VM_STATE_CACHEABLE);
	}

    free ((void *)p);

    return status;
    }

#undef CACHE_DEBUG
#ifdef CACHE_DEBUG

#include "stdio.h"

LOCAL UINT32 va[1024][5];	/* (256-entry * 4-way) * (tag[1] + data[4]) */

/******************************************************************************
*
* cacheSh7729Dump - dump SH7729 cache
*
* NOMANUAL
*/

LOCAL int partition (UINT32 a[][5], int l, int r)
    {
    int i, j, pivot;
    UINT32 t;

    i = l - 1;
    j = r;
    pivot = a[r][0];
    for (;;)
	{
	while (a[++i][0] < pivot)
	    ;
	while (i < --j && pivot < a[j][0])
	    ;
	if (i >= j)
	    break;
	t = a[i][0]; a[i][0] = a[j][0]; a[j][0] = t;
	t = a[i][1]; a[i][1] = a[j][1]; a[j][1] = t;
	t = a[i][2]; a[i][2] = a[j][2]; a[j][2] = t;
	t = a[i][3]; a[i][3] = a[j][3]; a[j][3] = t;
	t = a[i][4]; a[i][4] = a[j][4]; a[j][4] = t;
	}
    t = a[i][0]; a[i][0] = a[r][0]; a[r][0] = t;
    t = a[i][1]; a[i][1] = a[r][1]; a[r][1] = t;
    t = a[i][2]; a[i][2] = a[r][2]; a[r][2] = t;
    t = a[i][3]; a[i][3] = a[r][3]; a[r][3] = t;
    t = a[i][4]; a[i][4] = a[r][4]; a[r][4] = t;
    return i;
    }

LOCAL void quick_sort_1 (UINT32 a[][5], int l, int r)
    {
    int v;

    if (l >= r)
	return;

    v = partition (a, l, r);

    quick_sort_1 (a, l, v - 1);		/* sort left partial array */

    quick_sort_1 (a, v + 1, r);		/* sort right partial array */
    }

LOCAL void quick_sort (UINT32 a[][5], int n)
    {
    quick_sort_1 (a, 0, n - 1);
    }

LOCAL void cacheSh7729DumpOp (UINT32 a[][5], UINT32 ccr)
    {
    int ent, i;

    for (ent = 0; ent < 256; ent++)
	{
	int way;
	int lastway = 3;

	for (way = 0; way <= lastway; way++)
	    {
	    UINT32 tag = *(UINT32 *)(CAC_ADRS_ARRAY | (way << 12) | (ent << 4));

	    i = ent * 4 + way;

	    a[i][0] = (tag & 0xfffffc03) |((ent & 0x3f)<<4) |((ent & 0xc0)>>4);

	    a[i][1] = *(UINT32 *)(0xf1000000 | (way << 12) | (ent << 4));
	    a[i][2] = *(UINT32 *)(0xf1000004 | (way << 12) | (ent << 4));
	    a[i][3] = *(UINT32 *)(0xf1000008 | (way << 12) | (ent << 4));
	    a[i][4] = *(UINT32 *)(0xf100000c | (way << 12) | (ent << 4));
	    }
	}
    }

LOCAL void cacheSh7729Disp (UINT32 a[][5], UINT32 ccr)
    {
    int i;
    int lines = 1024;				/* cache lines */

    quick_sort (a, lines);

    for (i = 0; i < lines; i++)
	{
	UINT32 b10 = (a[i][0] & 0xc) << 8;	/* MSB of entry selector */

	printf ("0x%08x: %08x %08x %08x %08x %s %s %s\n",
		a[i][0] & 0xfffffff0,
		a[i][1], a[i][2], a[i][3], a[i][4],
		(a[i][0] & 0xc00) ^ b10 ? "!"  : " ",
		a[i][0] & 0x2           ? "U+" : "U-",
		a[i][0] & 0x1           ? "V+" : "V-");
	}
    }

void cacheSh7729ClearTest (int addr, int bytes)
    {
    UINT32 ccr = cacheSh7729CCRGet ();
    int key = intLock ();				/* LOCK INTERRUPTS */

    if ((ccr & (CCR_WRITE_BACK_P1 | CCR_WRITE_THRU)) == CCR_WRITE_THRU)
	{
	cacheSh7729CCRSet (ccr & ~CCR_CACHE_ENABLE);	/* disable caching */

	cacheSh7729Clear (INSTRUCTION_CACHE, (void *)addr, bytes);

	cacheSh7729DumpOp (va, ccr);

	cacheSh7729CCRSet (ccr);			/* restore ccr */
	intUnlock (key);				/* UNLOCK INTERRUPTS */
	cacheSh7729Disp (va, ccr);
	}
    else
	{
	UINT32 pDumpRtn
	    = ((UINT32)cacheSh7729DumpOp & SH7700_PHYS_MASK) | SH7700_P2_BASE;
	UINT32 (*a)[1024][5]
	= (UINT32(*)[1024][5])(((UINT32)va & SH7700_PHYS_MASK)| SH7700_P2_BASE);

	cacheSh7729Clear (INSTRUCTION_CACHE, (void *)addr, bytes);

	(* (VOIDFUNCPTR)pDumpRtn)(*a, ccr);

	intUnlock (key);				/* UNLOCK INTERRUPTS */
	cacheSh7729Disp (*a, ccr);
	}
    }

void cacheSh7729ClearTestAll ()
    {
    cacheSh7729ClearTest (0, ENTIRE_CACHE);
    }

void cacheSh7729Dump ()
    {
    cacheSh7729ClearTest (0, 0);
    }

STATUS cacheSh7729LockTest (int way, int from, int bytes)
    {
    STATUS status = ERROR;

    switch (way)
      {
      case 2: status = cacheSh7729Lock (WAY2_CACHE, (void *)from, bytes); break;
      case 3: status = cacheSh7729Lock (WAY3_CACHE, (void *)from, bytes); break;
      }
    return status;
    }

STATUS cacheSh7729UnlockTest (int way)
    {
    STATUS status = ERROR;

    switch (way)
      {
      case 2: status = cacheSh7729Unlock (WAY2_CACHE, NULL, 0);	break;
      case 3: status = cacheSh7729Unlock (WAY3_CACHE, NULL, 0);	break;
      }
    return status;
    }

#endif /* CACHE_DEBUG */
