/* cacheSh7604Lib.c - Hitachi SH7604/SH7615 cache management library */

/* Copyright 1994-2001 Wind River Systems, Inc. */
#include "copyright_wrs.h"

/*
modification history
--------------------
01w,24oct01,zl   fixes for doc builds.
01v,27feb01,hk   add Hitachi to library description.
01u,07feb01,hk   ignore instMode in cacheSh7604LibInit().
		 delete MAX_CACHEABLE_ADRS, use (SH7604_CACHE_THRU - 1).
		 change cacheLib.textUpdateRtn to NULL.
		 delete cacheSh7604Lock()/cacheSh7604Unlock().
		 move cache sensitive operations to cacheSh7604ALib.
		 change cacheSh7604Enable()/cacheSh7604Disable() more precise.
		 rename cacheSh7604Clear() to cacheSh7604Invalidate().
01t,07aug00,hk   made cacheSh7604Clear more precise. added cache dump tools.
01s,12jan98,hk   added notes to cacheSh7604LibInit().
01r,23aug96,hk   added CACHE_2WAY_MODE to CACHE_MODE. changed parameter check
		 code in cacheSh7604LibInit().
01q,14jan96,hk   deleted sysDmaXXX references. added cache purge code in
		 cacheSh7604LibInit(). fixed cacheFuncsSet() calling points.
		 deleted cacheFlush() from cacheArchTextUpdate(). added
		 error checking in cacheArchDmaMalloc()/cacheArchDmaFree().
		 replaced magic numbers by macros. restricted line-purge
		 address pointers into the proper area for cacheArchClear().
01p,24nov95,hk   supplemented documentation.
01o,21nov95,hk   updated manual pages.
01n,21nov95,hk   renamed to cacheSh7604Lib.c from caheSH7604Lib.c. SH to Sh.
01m,21nov95,hk   separated from cacheArchLib.c to cacheSH7604Lib.c. renamed
		 cacheSH7600LibInit() to cacheSH7604LibInit(). minor doc maint.
01l,27oct95,hk   fixed cacheArchClear() for line purge.
01k,16aug95,hk   separated cacheArchLibInit() to cache{SH7032|SH7604}LibInit().
01j,05jul95,hk   modified cacheArchLibInit().
01i,01jun95,hk   reworked on cacheArchLibInit,cacheArchEnable,cacheArchDisable.
		 moved cacheArchVirtToPhys/cacheArchPhysToVirt to sysLib.
01h,26may95,hk   added docs, changed cacheArchEnable()/cacheArchDisable().
01g,23may95,hk   code review.
01f,30jan95,hk   fixed cacheArchLock, cacheArchUnlock, cacheArchClear, only to
		 re-enable cache if previously enabled.  copyright year 1995.
01e,22dec94,sa   added cacheArchVirtToPhys and cacheArchPhysToVirt for SH7000.
		 fixed operation of CCR.
01d,08dec94,sa   added cacheArchPhysToVirt(), cacheArchVirtToPhys().
01c,09nov94,sa   fixed.
01b,21sep94,sa   modified.
01a,18jul94,hk   derived from 03g of 68k. Just a stub.
*/

/*
DESCRIPTION
This library contains architecture-specific cache library functions for
the Hitachi SH7604/SH7615 instruction and data mixed cache. 

INTERNAL
The cache enable and disable processes consist of the following actions,
executed by cacheSh7604Enable() and cacheSh7604Disable(). 

For general information about caching, see the manual entry for cacheLib.

INCLUDE FILES: cacheLib.h

SEE ALSO: cacheLib

INTERNAL
	< SH7604/SH7615 cache programming model >

	0x00000000:	cached region
	0x20000000:	cache through region
	0x40000000:	cache purge area
	0x60000000:	cache address array
	0xc0000000:	cache data array
	0xe0000000:	I/O area, non-cached
	0xffffffff:

	< SH7604/SH7615 CCR (Cache Control Register) >

			   0: normal op.         0: 4-way mode
			   1: cache purge        1: 2-way mode
			                 \      /
			   7    6    5    4    3    2    1    0
			+----+----+----+----+----+----+----+----+
	0xfffffe92:	| W1 | W0 | WB | CP | TW | OD | ID | CE |
			+----+----+----+----+----+----+----+----+
                            | /       \             |    \    \__ cache enable
                            00: way-0 (SH7615 only) |     \
                            01: way-1  0: Write-    |     Instruction
                            10: way-2     thru    Data      replace
                            11: way-3  1: Copy-   replace   Disable
                                          back    Disable
*/

#include "vxWorks.h"
#include "errnoLib.h"
#include "cacheLib.h"
#include "intLib.h"		/* for intLock()/intUnlock() */
#include "memLib.h"		/* for memalign() */
#include "stdlib.h"		/* for malloc() and free() */
#include "string.h"		/* for bzero() */


/* imports */

IMPORT void  cacheSh7604CCRSetOp (UINT8 value);
IMPORT UINT8 cacheSh7604CCRGet (void);
IMPORT void  cacheSh7604AInvalOp (UINT32 ca_begin, UINT32 ca_end);
IMPORT void  cacheSh7604MInvalOp (UINT32 *pt, int ix,
					UINT32 ca_begin, UINT32 ca_end);

/* local definitions */

#define CAC_ASSOCIATIVE_PURGE	0x40000000
#define CAC_ADRS_ARRAY		0x60000000
#define CAC_DATA_ARRAY		0xc0000000

#define CAC_DATA_SIZE		4096
#define CAC_LINE_SIZE		16


/* SH7604 Cache Control Register bit define */
#define MC_ENABLE		0x01	/* enable cache */
#define IC_NOLOAD		0x02	/* disable instruction replace */
#define DC_NOLOAD		0x04	/* disable data replace */
#define MC_2WAY			0x08	/* 2 way cache */
#define MC_PURGE		0x10	/* cache purge */


/* forward declarations */

LOCAL STATUS cacheSh7604Enable (CACHE_TYPE cache);
LOCAL STATUS cacheSh7604Disable (CACHE_TYPE cache);
LOCAL STATUS cacheSh7604Invalidate (CACHE_TYPE cache, void *from, size_t bytes);
LOCAL void  *cacheSh7604DmaMalloc (size_t bytes);
LOCAL STATUS cacheSh7604DmaFree (void *pBuf);

/* local function pointers to relocate cacheSh7604ALib entries */

LOCAL VOIDFUNCPTR cacheSh7604CCRSet      = (VOIDFUNCPTR)0x1234;
LOCAL VOIDFUNCPTR cacheSh7604AInvalidate = (VOIDFUNCPTR)0x1234;
LOCAL VOIDFUNCPTR cacheSh7604MInvalidate = (VOIDFUNCPTR)0x1234;

/******************************************************************************
*
* cacheSh7604LibInit - initialize the SH7604/SH7615 cache library
* 
* This routine initializes the cache library for the Hitachi SH7604/SH7615
* processor.  It initializes the function pointers and configures the caches
* to the specified cache modes.  Modes should be set before caching is enabled.
*
* The following caching modes are available for the SH7604/SH7615 processor:
*
* .TS
* tab(|);
* l l l l.
* | SH7604:| CACHE_WRITETHROUGH | (cache for instruction and data)
* |        | CACHE_2WAY_MODE    | (2KB 2-way cache + 2KB RAM)
* .TE
* 
* RETURNS: OK, or ERROR if the specified caching modes were invalid.
*/

STATUS cacheSh7604LibInit
    (
    CACHE_MODE	instMode,	/* instruction cache mode (ignored) */
    CACHE_MODE	dataMode	/* data cache mode */
    )
    {
    /* setup function pointers for cache library (declared in funcBind.c) */

    cacheLib.enableRtn          = cacheSh7604Enable;
    cacheLib.disableRtn         = cacheSh7604Disable;
    cacheLib.lockRtn            = NULL;
    cacheLib.unlockRtn          = NULL;
    cacheLib.flushRtn           = NULL;
    cacheLib.invalidateRtn      = cacheSh7604Invalidate;
    cacheLib.clearRtn           = cacheSh7604Invalidate;

    cacheLib.textUpdateRtn      = NULL;		/* inst/data mixed cache */
    cacheLib.pipeFlushRtn       = NULL;
    cacheLib.dmaMallocRtn       = (FUNCPTR)cacheSh7604DmaMalloc;
    cacheLib.dmaFreeRtn         = (FUNCPTR)cacheSh7604DmaFree;
    cacheLib.dmaVirtToPhysRtn	= NULL;
    cacheLib.dmaPhysToVirtRtn	= NULL;

    /* setup cache thru function pointers for cache sensitive operations */

    cacheSh7604CCRSet		= (VOIDFUNCPTR)((UINT32)cacheSh7604CCRSetOp
				| SH7604_CACHE_THRU);
    cacheSh7604AInvalidate	= (VOIDFUNCPTR)((UINT32)cacheSh7604AInvalOp
				| SH7604_CACHE_THRU);
    cacheSh7604MInvalidate	= (VOIDFUNCPTR)((UINT32)cacheSh7604MInvalOp
				| SH7604_CACHE_THRU);

    /* check for parameter errors (No copyback support for SH7615) */

    if (dataMode & ~(CACHE_WRITETHROUGH | CACHE_2WAY_MODE))
	{
	errnoSet (S_cacheLib_INVALID_CACHE);
	return ERROR;
	}

    /* initialize cache modes (declared in cacheLib.c)
     *
     * The "cacheMmuAvailable" controls the flow of cacheFuncsSet() routine.
     * The cacheFuncsSet() is called upon turning of/off data caching, and it
     * assumes DMA buffers cannot be made non-cacheable without MMU.  SH7604
     * does not have MMU, but it can get non-cacheable buffers from cache-
     * through address space.  Hence "cacheMmuAvailable" is set to TRUE here.
     */
    cacheDataMode	= dataMode;
    cacheDataEnabled	= FALSE;
    cacheMmuAvailable	= TRUE;			/* for cacheFuncsSet() */

    /* initialize CCR */
	{
	UINT8 ccr = MC_PURGE;

	if (dataMode & CACHE_2WAY_MODE)
	    ccr |= MC_2WAY;

	cacheSh7604CCRSet (ccr);		/* disable & purge cache */
	}

    /* clear entire D-array, it also cleans 2KB on-chip RAM in 2-way mode */

    bzero ((char *)CAC_DATA_ARRAY, CAC_DATA_SIZE);

    return OK;
    }

/******************************************************************************
*
* cacheSh7604Enable - enable a SH7604 cache
*
* This routine invalidates and enables a specified SH7604 cache.
*              ^^^^^^^^^^^     ^^^^^^^
* RETURNS: OK, or ERROR if the specified cache type was invalid.
*
* NOMANUAL
*
*  +----------------------+------------------------+------------------------+
*  |    PREVIOUS CCR      |     ENABLE I-CACHE     |     ENABLE D-CACHE     |
*  +----------------------+------------------------+------------------------+
*  | CE OD ID   (before)  | CP CE OD ID   (after)  | CP CE OD ID   (after)  |
*  +----------------------+------------------------+------------------------+
*  |  0  0  0  (disabled) |  1  1  1  0  (I-cache) |  1  1  0  1  (D-cache) |
*  |  0  0  1  (disabled) |  1  1  1  0  (I-cache) |  1  1  0  1  (D-cache) |
*  |  0  1  0  (disabled) |  1  1  1  0  (I-cache) |  1  1  0  1  (D-cache) |
*  |  0  1  1  (disabled) |  1  1  1  0  (I-cache) |  1  1  0  1  (D-cache) |
*  +----------------------+------------------------+------------------------+
*  |  1  0  0  (I/D-cache)|  0  1  0  0   (error)  |  0  1  0  0   (error)  |
*  |  1  0  1   (D-cache) |  0  1  0  0 (I/D-cache)|  0  1  0  1   (error)  |
*  |  1  1  0   (I-cache) |  0  1  1  0   (error)  |  0  1  0  0 (I/D-cache)|
*  |  1  1  1   (locked)  |  0  1  1  0  (I-cache) |  0  1  0  1  (D-cache) |
*  +----------------------+------------------------+------------------------+
*/

LOCAL STATUS cacheSh7604Enable
    (
    CACHE_TYPE cache
    )
    {
    UINT8 ccr = cacheSh7604CCRGet ();

    switch (cache)
	{
	case INSTRUCTION_CACHE:

	    if ((ccr & MC_ENABLE) == 0)			/* disabled */
		ccr |= MC_PURGE | MC_ENABLE | DC_NOLOAD;
	    else if ((ccr & IC_NOLOAD) == 0)		/* I-cache is enabled */
		return ERROR;

	    cacheSh7604CCRSet (ccr & ~IC_NOLOAD);	/* enable I-cache */
	    break;

	case DATA_CACHE:

	    if ((ccr & MC_ENABLE) == 0)			/* disabled */
		ccr |= MC_PURGE | MC_ENABLE | IC_NOLOAD;
	    else if ((ccr & DC_NOLOAD) == 0)		/* D-cache is enabled */
		return ERROR;

	    cacheSh7604CCRSet (ccr & ~DC_NOLOAD);	/* enable D-cache */
	    cacheDataEnabled = TRUE;
	    cacheFuncsSet ();		/* update cache function pointers */
	    break;

	default:
	    errno = S_cacheLib_INVALID_CACHE;
	    return ERROR;
	}

    return OK;
    }

/******************************************************************************
*
* cacheSh7604Disable - disable a SH7604 cache
*
* This routine flushes and disables a specified SH7604 cache.
*              ^^^^^^^     ^^^^^^^^
* RETURNS: OK, or ERROR if the specified cache type was invalid.
*
* NOMANUAL
*
*  +----------------------+-----------------------+-----------------------+
*  |  PREVIOUS CCR BITS   |    DISABLE I-CACHE    |    DISABLE D-CACHE    |
*  +----------------------+-----------------------+-----------------------+
*  | CE OD ID   (before)  | CP CE OD ID  (after)  | CP CE OD ID  (after)  |
*  +----------------------+-----------------------+-----------------------+
*  |  0  0  0  (disabled) |  0  0  0  0  (error)  |  0  0  0  0  (error)  |
*  |  0  0  1  (disabled) |  0  0  0  1  (error)  |  0  0  0  1  (error)  |
*  |  0  1  0  (disabled) |  0  0  1  0  (error)  |  0  0  1  0  (error)  |
*  |  0  1  1  (disabled) |  0  0  1  1  (error)  |  0  0  1  1  (error)  |
*  +----------------------+-----------------------+-----------------------+
*  |  1  0  0  (I/D-cache)|  1  1  0  1 (D-cache) |  1  1  1  0 (I-cache) |
*  |  1  0  1   (D-cache) |  0  1  0  1  (error)  |  0  0  0  0 (disable) |
*  |  1  1  0   (I-cache) |  0  0  0  0 (disable) |  0  1  1  0  (error)  |
*  |  1  1  1   (locked)  |  0  0  0  0 (disable) |  0  0  0  0 (disable) |
*  +----------------------+-----------------------+-----------------------+
*/

LOCAL STATUS cacheSh7604Disable
    (
    CACHE_TYPE cache
    )
    {
    UINT8 ccr = cacheSh7604CCRGet ();

    switch (cache) 
	{
	case INSTRUCTION_CACHE:

	    if ((ccr & MC_ENABLE) == 0)				/* disabled */
		return ERROR;
	    else if (ccr & DC_NOLOAD)			/* I-cache or locked */
		ccr &= ~(MC_ENABLE | DC_NOLOAD | IC_NOLOAD);
	    else if (ccr & IC_NOLOAD)				/* D-cache */
		return ERROR;
	    else						/* I/D-cache */
		ccr |= MC_PURGE | IC_NOLOAD;

	    cacheSh7604CCRSet (ccr);
	    break;

	case DATA_CACHE:

	    if ((ccr & MC_ENABLE) == 0)				/* disabled */
		return ERROR;
	    else if (ccr & IC_NOLOAD)			/* D-cache or locked */
		ccr &= ~(MC_ENABLE | DC_NOLOAD | IC_NOLOAD);
	    else if (ccr & DC_NOLOAD)				/* I-cache */
		return ERROR;
	    else						/* I/D-cache */
		ccr |= MC_PURGE | DC_NOLOAD;

	    cacheSh7604CCRSet (ccr);
	    cacheDataEnabled = FALSE;
	    cacheFuncsSet ();		/* update cache function pointers */
	    break;

	default:
	    errno = S_cacheLib_INVALID_CACHE;
	    return ERROR;
	}

    return OK;
    }

/******************************************************************************
*
* cacheSh7604Invalidate - invalidate some or all entries from SH7604 cache
*
* This routine invalidates some or all entries from SH7604 cache.
*
* RETURNS: OK, or ERROR if the specified address is out of cacheable region.
*
* NOMANUAL
*/

LOCAL STATUS cacheSh7604Invalidate
    (
    CACHE_TYPE  cache,
    void       *from,		/* address to clear */
    size_t      bytes
    )
    {
    UINT32 p = (UINT32)from;
    UINT8  ccr = cacheSh7604CCRGet ();

    if (p >= SH7604_CACHE_THRU)			/* non-cacheable region */
	return ERROR;

    if (bytes == ENTIRE_CACHE)
	{
	cacheSh7604CCRSet (ccr | MC_PURGE);	/* invalidate entire cache */
	}
    else if (bytes > 0)
	{
	UINT32 ca_begin = p & ~(CAC_LINE_SIZE - 1);
	UINT32 ca_end   = p + bytes - 1;

	if (ca_end >= SH7604_CACHE_THRU)
	    {
	    ca_end = SH7604_CACHE_THRU - 1;
	    bytes = ca_end - p + 1;
	    }

	if (bytes < ((ccr & MC_2WAY) ? 5120 : 10240)) /* do associative purge */
	    {
	    cacheSh7604AInvalidate (ca_begin, ca_end);
	    }
	else /* check every cache tag */
	    {
	    int way, ix;
	    int firstway = (ccr & MC_2WAY) ? 2 : 0;

	    for (way = firstway; way < 4; way++)
		{
		cacheSh7604CCRSet ((ccr & 0x3f) | (way << 6));	/* select way */

		for (ix = 0; ix <= 0x3f0; ix += CAC_LINE_SIZE)
		    {
		    UINT32 *pt = (UINT32 *)(CAC_ADRS_ARRAY | ix);

		    cacheSh7604MInvalidate (pt, ix, ca_begin, ca_end);
		    }
		}
	    cacheSh7604CCRSet (ccr);			/* RESTORE CCR */
	    }
	}
    return OK;
    }

/******************************************************************************
*
* cacheSh7604DmaMalloc - allocate a cache-safe buffer
*
* This routine attempts to return a pointer to a section of memory that will
* not experience cache coherency problems.  This routine is only called when
* MMU support is available for cache control.
*
* RETURNS: A pointer to a cache-safe buffer, or NULL.
*
* NOMANUAL
*/

LOCAL void *cacheSh7604DmaMalloc
    (
    size_t bytes
    )
    {
    void *pBuf;
    int alignment = _CACHE_ALIGN_SIZE;

    /* adjust bytes to a multiple of cache line length */

    bytes = bytes / alignment * alignment + alignment;

    /* use memalign() to avoid sharing a cache-line with other buffers */

    if ((pBuf = memalign (alignment, bytes)) == NULL)
	return NULL;

    return (void *)((UINT32)pBuf | SH7604_CACHE_THRU); 
    }

/******************************************************************************
*
* cacheSh7604DmaFree - free the buffer acquired by cacheSh7604DmaMalloc()
*
* This routine returns to the free memory pool a block of memory previously
* allocated with cacheSh7604DmaMalloc().  The buffer is marked cacheable.
*
* RETURNS: OK, or ERROR if cacheSh7604DmaMalloc() cannot be undone.
*
* NOMANUAL
*/

LOCAL STATUS cacheSh7604DmaFree
    (
    void *pBuf
    )
    {
    UINT32 p = (UINT32)pBuf;

    if (p < SH7604_CACHE_THRU || p >= CAC_ASSOCIATIVE_PURGE)
	return ERROR;

    free ((void *)(p & (SH7604_CACHE_THRU - 1)));

    return OK;
    }

#undef CACHE_DEBUG
#ifdef CACHE_DEBUG

#include "stdio.h"

LOCAL UINT32 va[256][5];	/* (64-entry * 4-way) * (tag[1] + data[4]) */

/******************************************************************************
*
* cacheSh7604Dump - dump SH7604 cache
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

LOCAL void cacheSh7604DumpOp (UINT32 a[][5], UINT32 ccr)
    {
    int ent, i;
    BOOL t = (ccr & MC_2WAY) ? TRUE : FALSE;	/* TRUE if 2-way mode */

    for (ent = 0; ent < 64; ent++)
	{
	int way;
	int firstway = t ? 2 : 0;	/* 2-way mode uses way 2 and 3 */

	for (way = firstway; way <= 3; way++)
	    {
	    UINT32 tag;

	    i = t ? (ent * 2 + way - firstway) : (ent * 4 + way);

	    cacheSh7604CCRSet ((ccr & 0x3f) | (way << 6));	/* select way */

	    tag = *(UINT32 *)(CAC_ADRS_ARRAY | (ent << 4));

	    a[i][0] = (tag & 0x1ffffc04) | (ent << 4);

	    a[i][1] = *(UINT32 *)(0xc0000000 | (way << 10) | (ent << 4));
	    a[i][2] = *(UINT32 *)(0xc0000004 | (way << 10) | (ent << 4));
	    a[i][3] = *(UINT32 *)(0xc0000008 | (way << 10) | (ent << 4));
	    a[i][4] = *(UINT32 *)(0xc000000c | (way << 10) | (ent << 4));
	    }
	}
    cacheSh7604CCRSet (ccr);			/* RESTORE CCR */
    }

LOCAL void cacheSh7604Disp (UINT32 a[][5], UINT32 ccr)
    {
    int i;
    int lines = (ccr & MC_2WAY) ? 128 : 256;		/* cache lines */

    quick_sort (a, lines);

    for (i = 0; i < lines; i++)
	{
	printf ("0x%08x: %08x %08x %08x %08x  %s\n",
		a[i][0] & 0x1ffffff0, a[i][1], a[i][2], a[i][3], a[i][4],
		a[i][0] & 0x00000004 ? "V+" : "V-");
	}
    }

void cacheSh7604ClearTest (int addr, int bytes)
    {
    UINT32 pDumpRtn = (UINT32)cacheSh7604DumpOp | SH7604_CACHE_THRU;
    UINT32 (*a)[256][5] = (UINT32(*)[256][5])((UINT32)va | SH7604_CACHE_THRU);
    UINT8 ccr = cacheSh7604CCRGet ();
    int key = intLock ();				/* LOCK INTERRUPTS */

    cacheClear (INSTRUCTION_CACHE, (void *)addr, bytes);

    (* (VOIDFUNCPTR)pDumpRtn)(*a, ccr);

    intUnlock (key);					/* UNLOCK INTERRUPTS */
    cacheSh7604Disp (*a, ccr);
    }

void cacheSh7604ClearTestAll ()
    {
    cacheSh7604ClearTest (0, ENTIRE_CACHE);
    }

void cacheSh7604Dump ()
    {
    cacheSh7604ClearTest (0, 0);
    }

#endif /* CACHE_DEBUG */
