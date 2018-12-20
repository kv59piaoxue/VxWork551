/* cacheSh7700Lib.c - Hitachi SH7700 cache management library */

/* Copyright 1996-2001 Wind River Systems, Inc. */
#include "copyright_wrs.h"

/*
modification history
--------------------
01p,23nov01,hk  removed checking vmLibInfo.vmLibInstalled in cacheSh7700DmaFree
		and cacheSh7700P2DmaFree for INCLUDE_MMU_BASIC (SPR 71807).
01p,24oct01,zl  fixes for doc builds.
01o,27feb01,hk  add Hitachi to library description.
01n,07dec00,hk  set cacheMmuAvailable to T/F depending on data cache mode.
01m,21nov00,hk  changed to ignore instMode in cacheSh7700LibInit(). changed
		cacheLib.invalidateRtn to cacheSh7700Clear() in copyback mode.
		made cacheSh7700Disable() NMI-safe.
01l,20aug00,hk  moved critical operations to cacheSh7700ALib. made cache tag
		operations more precise. improved cacheSh7700P2DmaMalloc().
		added cache dump tools.
01k,06feb98,jmc renamed CACHE_WRITEBACK_P1 to CACHE_COPYBACK_P1.
01j,30jan98,jmc revised cacheSh7700LibInit() to set CCR bit CCR_WRITE_BACK_P1
		if mode is CACHE_WRITEBACK_P1, write-back cache for P1 region,
		SH7709 only.
01i,12jan98,hk  fixed docs for cacheSh7700LibInit(), changed two to next.
01h,22mar97,hk  reviewed documentation.
01g,16feb97,hk  added support for SH7702. changed CCR_RAM_MODE to CCR_2WAY_MODE.
01f,19jan97,hk  disabled & invalidated cache at a time in cacheSh7700LibInit().
                removed address range check from cacheArchInvalidate() and
                cacheArchClear(). supported CACHE_2WAY_MODE in cacheArchClear().
                Deleted intLock() in cacheArchClear(). specified DATA_CACHE in
                cacheArchDmaMallocP2 instead of 0.
01e,18jan97,hk  made cacheArchXXX local, and registered P2 address to cacheLib
                structure. added CACHE_COPYBACK and CACHE_DMA_BYPASS_P[013].
                simplified cacheArchEnable(). added cacheArchInvalidate().
                added cache entry purge code. made cacheArchDmaMalloc/Free()
                to use mmu and renamed non-mmu version as xxxP2(). cacheTest().
01d,30dec96,hk  made cacheLib.textUpdateRtn NULL for copyback support. updated
                address space macro names for cacheShLib.h-01n.
01c,25sep96,hk  cacheArchClear() clears whole cache.(temporal)
01b,05sep96,hk  take no action to enable/disable INSTRUCTION_CACHE. substituted
		macros to magic numbers in cacheArchDmaMalloc/cacheArchDmaFree.
01a,23aug96,hk  derived from cacheSh7604Lib.c-01q.
*/

/*
DESCRIPTION
This library contains architecture-specific cache library functions for
the Hitachi SH7700 architecture.  There is a 8-Kbyte (2-Kbyte for SH7702)
mixed instruction and data cache that operates in write-through or
write-back (copyback) mode.  The 8-Kbyte cache can be divided into
4-Kbyte cache and 4-Kbyte memory.  Cache line size is fixed at 16 bytes,
and the cache address array holds physical addresses as cache tags.
Cache entries may be "flushed" by accesses to the address array in privileged
mode.  There is a write-back buffer which can hold one line of cache entry,
and the completion of write-back cycle is assured by accessing to any cache
through region.

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

IMPORT void cacheSh7700CCRSetOp (UINT32 ccr);
IMPORT UINT32 cacheSh7700CCRGet (void);
IMPORT STATUS cacheSh7700OnOp (BOOL on);
IMPORT void cacheSh7700CFlushOp (void);
IMPORT void cacheSh7700AFlushOp (UINT32 from, UINT32 to);
IMPORT void cacheSh7700MFlushOp (UINT32 *pt, int ix, UINT32 from, UINT32 to);

/* local definitions */

#define CAC_RAM_ADRS		0x7f000000
#define CAC_RAM_SIZE		4096

#define CAC_ADRS_ARRAY		0xf0000000
#define CAC_DATA_ARRAY		0xf1000000

#define CAC_DATA_SIZE		8192
#define CAC_LINE_SIZE		16


/* SH7700 Cache Control Register bit define */
#define CCR_2WAY_MODE		0x00000020	/* 4KB 2-way cache + 4KB RAM */
#define CCR_1WAY_MODE		0x00000010	/* 2KB direct mapped cache */
#define CCR_CACHE_FLUSH		0x00000008	/* no write back */
#define CCR_WRITE_BACK_P1	0x00000004	/* set P1 to write-back */
#define CCR_WRITE_THRU		0x00000002
#define CCR_CACHE_ENABLE	0x00000001


/* forward declarations */

LOCAL STATUS cacheSh7700Enable (CACHE_TYPE cache);
LOCAL STATUS cacheSh7700Disable (CACHE_TYPE cache);
LOCAL STATUS cacheSh7700Clear (CACHE_TYPE cache, void *from, size_t bytes);
LOCAL STATUS cacheSh7700Invalidate (CACHE_TYPE cache, void *from, size_t bytes);
LOCAL void * cacheSh7700DmaMalloc (size_t bytes);
LOCAL STATUS cacheSh7700DmaFree (void * pBuf);
LOCAL void * cacheSh7700P2DmaMalloc (size_t bytes);
LOCAL STATUS cacheSh7700P2DmaFree (void * pBuf);

/* local function pointers to relocate cacheSh7700ALib entries */

LOCAL VOIDFUNCPTR cacheSh7700CCRSet = (VOIDFUNCPTR)0x1234;
LOCAL FUNCPTR     cacheSh7700On     =     (FUNCPTR)0x1234;
LOCAL VOIDFUNCPTR cacheSh7700CFlush = (VOIDFUNCPTR)0x1234;
LOCAL VOIDFUNCPTR cacheSh7700AFlush = (VOIDFUNCPTR)0x1234;
LOCAL VOIDFUNCPTR cacheSh7700MFlush = (VOIDFUNCPTR)0x1234;


/******************************************************************************
*
* cacheSh7700LibInit - initialize the SH7700 cache library
* 
* This routine initializes the cache library for the Hitachi SH7700 processor.
* It initializes the function pointers and configures the caches to the
* specified cache modes.  Modes should be set before caching is enabled.
* If two complementary flags are set (enable/disable), no action is taken
* for any of the input flags.
*
* The following caching modes are available for the SH7700 processor:
*
* .TS
* tab(|);
* l l l l.
* | SH7700:| CACHE_WRITETHROUGH  | (cache for instruction and data)
* |        | CACHE_COPYBACK      | (cache for instruction and data)
* |        | CACHE_COPYBACK_P1   | (copy-back cache for P1, SH7709 only)
* |        | CACHE_2WAY_MODE     | (4KB 2-way cache + 4KB RAM)
* |        | CACHE_1WAY_MODE     | (2KB direct mapped cache, SH7702 only)
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

STATUS cacheSh7700LibInit
    (
    CACHE_MODE	instMode,	/* instruction cache mode (ignored) */
    CACHE_MODE	dataMode	/* data cache mode */
    )
    {
    /* setup function pointers for cache library (declared in funcBind.c) */

    cacheLib.enableRtn          = cacheSh7700Enable;
    cacheLib.disableRtn         = cacheSh7700Disable;

    cacheLib.lockRtn            = NULL;
    cacheLib.unlockRtn          = NULL;

    /* Flush and invalidate are the same in COPYBACK mode.  Setting the flush
     * bit in the CCR doesn't do a write-back, so call cacheSh7700Clear if
     * using COPYBACK (write-back) mode.
     */
    if (dataMode & (CACHE_COPYBACK | CACHE_COPYBACK_P1))
	{
	cacheLib.flushRtn	= cacheSh7700Clear;
	cacheLib.invalidateRtn	= cacheSh7700Clear;
	}
    else
	{
	cacheLib.flushRtn	= NULL;
	cacheLib.invalidateRtn	= cacheSh7700Invalidate;
	}

    cacheLib.clearRtn           = cacheSh7700Clear;

    cacheLib.textUpdateRtn      = NULL;		/* inst/data mixed cache */
    cacheLib.pipeFlushRtn       = NULL;

    /* setup P2 function pointers for cache sensitive operations */

    cacheSh7700CCRSet		= (VOIDFUNCPTR)(((UINT32)cacheSh7700CCRSetOp
				& SH7700_PHYS_MASK) | SH7700_P2_BASE);
    cacheSh7700On		= (FUNCPTR)(((UINT32)cacheSh7700OnOp
				& SH7700_PHYS_MASK) | SH7700_P2_BASE);
    cacheSh7700CFlush		= (VOIDFUNCPTR)(((UINT32)cacheSh7700CFlushOp
				& SH7700_PHYS_MASK) | SH7700_P2_BASE);
    cacheSh7700AFlush		= (VOIDFUNCPTR)(((UINT32)cacheSh7700AFlushOp
				& SH7700_PHYS_MASK) | SH7700_P2_BASE);
    cacheSh7700MFlush		= (VOIDFUNCPTR)(((UINT32)cacheSh7700MFlushOp
				& SH7700_PHYS_MASK) | SH7700_P2_BASE);

    /* select cache-safe malloc/free routines for DMA buffer */

    if (dataMode &
        (CACHE_DMA_BYPASS_P0 | CACHE_DMA_BYPASS_P1 | CACHE_DMA_BYPASS_P3))
	{
	cacheLib.dmaMallocRtn   = (FUNCPTR)cacheSh7700P2DmaMalloc;
	cacheLib.dmaFreeRtn     = cacheSh7700P2DmaFree;
	cacheMmuAvailable	= TRUE;		/* for cacheFuncsSet() */
	}
    else
	{
	cacheLib.dmaMallocRtn   = (FUNCPTR)cacheSh7700DmaMalloc;
	cacheLib.dmaFreeRtn     = cacheSh7700DmaFree;
	cacheMmuAvailable	= FALSE;	/* needs MMU support for cache
						   safe allocation */
	}

    cacheLib.dmaVirtToPhysRtn	= NULL;
    cacheLib.dmaPhysToVirtRtn	= NULL;

    /* check for parameter errors */

    if ((dataMode & ~(CACHE_WRITETHROUGH | CACHE_COPYBACK | CACHE_2WAY_MODE |
             CACHE_DMA_BYPASS_P0 | CACHE_DMA_BYPASS_P1 | CACHE_DMA_BYPASS_P3 |
             CACHE_1WAY_MODE | CACHE_COPYBACK_P1)) ||
	((dataMode & CACHE_WRITETHROUGH)  && (dataMode & CACHE_COPYBACK))     ||
	((dataMode & CACHE_DMA_BYPASS_P0) && (dataMode & CACHE_DMA_BYPASS_P1))||
	((dataMode & CACHE_DMA_BYPASS_P1) && (dataMode & CACHE_DMA_BYPASS_P3))||
	((dataMode & CACHE_DMA_BYPASS_P3) && (dataMode & CACHE_DMA_BYPASS_P0))||
	((dataMode & CACHE_2WAY_MODE)     && (dataMode & CACHE_1WAY_MODE)))
	{
	errnoSet (S_cacheLib_INVALID_CACHE);
	return ERROR;
	}

    /* initialize cache modes (declared in cacheLib.c) */

    cacheDataMode	= dataMode;
    cacheDataEnabled	= FALSE;

    /* disable cache safely */

    cacheLib.disableRtn (DATA_CACHE);

    /* initialize CCR, clear on-chip RAM if available */
	{
	UINT32 ccr = 0;

	if (dataMode & CACHE_WRITETHROUGH) ccr |= CCR_WRITE_THRU;
	if (dataMode & CACHE_2WAY_MODE)    ccr |= CCR_2WAY_MODE;
	if (dataMode & CACHE_1WAY_MODE)    ccr |= CCR_1WAY_MODE;
	if (dataMode & CACHE_COPYBACK_P1)  ccr |= CCR_WRITE_BACK_P1;

	cacheSh7700CCRSet (ccr);

	if (cacheSh7700CCRGet () & CCR_2WAY_MODE)
	    bzero ((char *)CAC_RAM_ADRS, CAC_RAM_SIZE);	/* clear on-chip RAM */
	}

    return OK;
    }

/******************************************************************************
*
* cacheSh7700Enable - enable a SH7700 cache
*
* This routine invalidates and enables the specified SH7700 cache.
*              ^^^^^^^^^^^     ^^^^^^^
* RETURNS: OK, or ERROR if the specified cache type was invalid.
*
* NOMANUAL
*/

LOCAL STATUS cacheSh7700Enable
    (
    CACHE_TYPE cache
    )
    {
    STATUS status;

    switch (cache)
	{
	case DATA_CACHE:
	    if ((status = cacheSh7700On (TRUE)) == OK)
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
* cacheSh7700Disable - disable a SH7700 cache
*
* This routine flushes and disables the specified SH7700 cache.
*              ^^^^^^^     ^^^^^^^^
* RETURNS: OK, or ERROR if the specified cache type was invalid.
*
* NOMANUAL
*/

LOCAL STATUS cacheSh7700Disable
    (
    CACHE_TYPE cache
    )
    {
    STATUS status;

    switch (cache) 
	{
	case DATA_CACHE:

	    if ((status = cacheSh7700On (FALSE)) == OK)	/* flush and disable */
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
* cacheSh7700Invalidate - invalidate all or some entries from a SH7700 cache
*
* This routine invalidates all or some entries of the SH7700 cache.
*
* RETURNS: OK, or ERROR if the cache type is invalid or the cache control
* is not supported.
*
* NOMANUAL
*/

LOCAL STATUS cacheSh7700Invalidate
    (
    CACHE_TYPE cache,
    void *     from,
    size_t     bytes
    )
    {
    if (bytes == ENTIRE_CACHE)
	{
	UINT32 ccr = cacheSh7700CCRGet ();

	if ((ccr & (CCR_WRITE_BACK_P1 | CCR_WRITE_THRU)) == CCR_WRITE_THRU)
	    {
	    cacheSh7700CFlush ();
	    return OK;
	    }
	}

    return cacheSh7700Clear (cache, from, bytes);
    }

/******************************************************************************
*
* cacheSh7700Clear - clear all or some entries from a SH7700 cache
*
* This routine flushes and invalidates all or some entries of the specified
* SH7700 cache.
*
* RETURNS: OK, or ERROR if the cache type is invalid or the cache control
* is not supported.
*
* NOMANUAL
*/

LOCAL STATUS cacheSh7700Clear
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

    switch (cacheSh7700CCRGet () & (CCR_2WAY_MODE | CCR_1WAY_MODE))
	{
	case CCR_1WAY_MODE: c_size = CAC_DATA_SIZE / 4;	lastway = 0;	break;
	case CCR_2WAY_MODE: c_size = CAC_DATA_SIZE / 2;	lastway = 1;	break;
	default:	    c_size = CAC_DATA_SIZE;	lastway = 3;
	}

    if (bytes == 0)
	{
	return OK;
	}
    else if (bytes == ENTIRE_CACHE)
	{
	for (way = 0; way <= lastway; way++)
	    {
	    for (ix = 0; ix <= 0x7f0; ix += CAC_LINE_SIZE)
		{
		UINT32 *pt = (UINT32 *)(CAC_ADRS_ARRAY | (way << 11) | ix);

		cacheSh7700MFlush (pt, -1, 0, 0);
		}
	    }
	}
    else
	{
	UINT32 ca_begin = p & ~(CAC_LINE_SIZE - 1);
	UINT32 ca_end   = p + bytes - 1;

	if (bytes < c_size) /* do associative purge */
	    {
	    cacheSh7700AFlush (ca_begin, ca_end);
	    }
	else /* check every cache tag */
	    {
	    for (way = 0; way <= lastway; way++)
		{
		for (ix = 0; ix <= 0x7f0; ix += CAC_LINE_SIZE)
		    {
		    UINT32 *pt = (UINT32 *)(CAC_ADRS_ARRAY | (way << 11) | ix);

		    cacheSh7700MFlush (pt, ix, ca_begin, ca_end);
		    }
		}
	    }
	}

    return OK;
    }

/******************************************************************************
*
* cacheSh7700DmaMalloc - allocate a cache-safe buffer
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

LOCAL void *cacheSh7700DmaMalloc
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
* cacheSh7700DmaFree - free the buffer acquired by cacheSh7700DmaMalloc()
*
* This routine returns to the free memory pool a block of memory previously
* allocated with cacheSh7700DmaMalloc().  The buffer is marked cacheable.
*
* RETURNS: OK, or ERROR if cacheSh7700DmaMalloc() cannot be undone.
*
* NOMANUAL
*/

LOCAL STATUS cacheSh7700DmaFree
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
* cacheSh7700P2DmaMalloc - allocate a cache-safe buffer from P2 region
*
* This routine attempts to return a pointer to a section of memory that will
* not experience cache coherency problems.  This routine may be called when
* MMU support is NOT available for cache control.
*
* RETURNS: A pointer to a cache-safe buffer, or NULL.
*
* NOMANUAL
*/

LOCAL void *cacheSh7700P2DmaMalloc
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
* cacheSh7700P2DmaFree - free the buffer acquired by cacheSh7700P2DmaMalloc()
*
* This routine returns to the free memory pool a block of memory previously
* allocated with cacheSh7700P2DmaMalloc().
*
* RETURNS: OK, or ERROR if cacheSh7700DmaMalloc() cannot be undone.
*
* NOMANUAL
*/

LOCAL STATUS cacheSh7700P2DmaFree
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

LOCAL UINT32 va[512][5];	/* (128-entry * 4-way) * (tag[1] + data[4]) */

/******************************************************************************
*
* cacheSh7700Dump - dump SH7700 cache
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

LOCAL void cacheSh7700DumpOp (UINT32 a[][5], UINT32 ccr)
    {
    int ent, i;
    BOOL t = (ccr & CCR_2WAY_MODE) ? TRUE : FALSE;	/* TRUE if 2-way mode */

    for (ent = 0; ent < 128; ent++)
	{
	int way;
	int lastway = t ? 1 : 3;	/* 2-way mode uses way 0 and 1 */

	for (way = 0; way <= lastway; way++)
	    {
	    UINT32 tag = *(UINT32 *)(CAC_ADRS_ARRAY | (way << 11) | (ent << 4));

	    i = t ? (ent * 2 + way) : (ent * 4 + way);

	    a[i][0] = (tag & 0xfffffc03) |((ent & 0x3f)<<4) |((ent & 0x40)>>4);

	    a[i][1] = *(UINT32 *)(0xf1000000 | (way << 11) | (ent << 4));
	    a[i][2] = *(UINT32 *)(0xf1000004 | (way << 11) | (ent << 4));
	    a[i][3] = *(UINT32 *)(0xf1000008 | (way << 11) | (ent << 4));
	    a[i][4] = *(UINT32 *)(0xf100000c | (way << 11) | (ent << 4));
	    }
	}
    }

LOCAL void cacheSh7700Disp (UINT32 a[][5], UINT32 ccr)
    {
    int i;
    int lines = (ccr & CCR_2WAY_MODE) ? 256 : 512;	/* cache lines */

    quick_sort (a, lines);

    for (i = 0; i < lines; i++)
	{
	UINT32 b10 = (a[i][0] & 0x4) << 8;	/* MSB of entry selector */

	printf ("0x%08x: %08x %08x %08x %08x %s %s %s\n",
		a[i][0] & 0xfffffff0,
		a[i][1], a[i][2], a[i][3], a[i][4],
		(a[i][0] & 0x400) ^ b10 ? "!"  : " ",
		a[i][0] & 0x2           ? "U+" : "U-",
		a[i][0] & 0x1           ? "V+" : "V-");
	}
    }

void cacheSh7700ClearTest (int addr, int bytes)
    {
    UINT32 ccr = cacheSh7700CCRGet ();
    int key = intLock ();				/* LOCK INTERRUPTS */

    if ((ccr & (CCR_WRITE_BACK_P1 | CCR_WRITE_THRU)) == CCR_WRITE_THRU)
	{
	cacheSh7700CCRSet (ccr & ~CCR_CACHE_ENABLE);	/* disable caching */

	cacheSh7700Clear (INSTRUCTION_CACHE, (void *)addr, bytes);

	cacheSh7700DumpOp (va, ccr);

	cacheSh7700CCRSet (ccr);			/* restore ccr */
	intUnlock (key);				/* UNLOCK INTERRUPTS */
	cacheSh7700Disp (va, ccr);
	}
    else
	{
	UINT32 pDumpRtn
	    = ((UINT32)cacheSh7700DumpOp & SH7700_PHYS_MASK) | SH7700_P2_BASE;
	UINT32 (*a)[512][5]
	= (UINT32(*)[512][5])(((UINT32)va & SH7700_PHYS_MASK) | SH7700_P2_BASE);

	cacheSh7700Clear (INSTRUCTION_CACHE, (void *)addr, bytes);

	(* (VOIDFUNCPTR)pDumpRtn)(*a, ccr);

	intUnlock (key);				/* UNLOCK INTERRUPTS */
	cacheSh7700Disp (*a, ccr);
	}
    }

void cacheSh7700ClearTestAll ()
    {
    cacheSh7700ClearTest (0, ENTIRE_CACHE);
    }

void cacheSh7700Dump ()
    {
    cacheSh7700ClearTest (0, 0);
    }

#endif /* CACHE_DEBUG */
