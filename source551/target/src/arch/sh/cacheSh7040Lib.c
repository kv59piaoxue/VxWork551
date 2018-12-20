/* cacheSh7040Lib.c - Hitachi SH7040 cache management library */

/* Copyright 1996-2001 Wind River Systems, Inc. */
#include "copyright_wrs.h"

/*
modification history
--------------------
01i,24oct01,zl   fixes for doc builds.
01h,27feb01,hk   add missing NOMANUAL to cacheSh7040Dump.
01g,09feb01,hk   lock interrupts while disabling cache.
		 rename cacheSh7040Clear to cacheSh7040Invalidate.
		 change cacheSh7040LibInit() to ignore dataMode.
01f,06aug00,hk   merged SH7040 to SH7600. made cacheSh7040Clear more precise.
01e,12jan98,hk   added notes to cacheSh7040LibInit().
01d,19jun97,hk   fixed invalidation loop in cacheArchEnable().
01c,25apr97,hk   renamed to SH7040 from SH704X.
01b,23aug96,hk   simplified as instruction cache. added CACHE_DRAM/CACHE_CS
		 [3210] to CACHE_MODE.
01a,14jan96,hk   written based on cacheSh7604Lib.c-01q.
*/

/*
DESCRIPTION
This library contains architecture-specific cache library functions for
the Hitachi SH7040 architecture. This architecture has a 1-Kbyte instruction
cache.

For general information about caching, see the manual entry for cacheLib.

INCLUDE FILES: cacheLib.h

SEE ALSO: cacheLib

INTERNAL
	< SH7040 cache programming model >

	0xfffff000:	cache address array
	0xfffff3ff:
	0xfffff400:	cache data array
	0xfffff7ff:

	< SH7040 CCR (Cache Control Register): 0xffff8740 >

	 15 14 13 12 11 10  9  8  7  6  5   4    3    2    1    0
	+--+--+--+--+--+--+--+--+--+--+--+----+----+----+----+----+
	|  |  |  |  |  |  |  |  |  |  |  | CE | CE | CE | CE | CE |
	|  |  |  |  |  |  |  |  |  |  |  |DRAM| CS3| CS2| CS1| CS0|
	+--+--+--+--+--+--+--+--+--+--+--+----+----+----+----+----+
*/

#include "vxWorks.h"
#include "errnoLib.h"
#include "cacheLib.h"
#include "intLib.h"		/* for intLock()/intUnlock() */
#include "string.h"		/* for bzero() */


/* local definitions */

#define CAC_CCR		((volatile UINT16 *)0xffff8740)
#define CCR_MASK		0x001f

#define MAX_CACHEABLE_ADRS	0x01ffffff	/* 32 Mbytes */
#define CAC_ADRS_ARRAY		0xfffff000
#define CAC_DATA_ARRAY		0xfffff400

#define CAC_DATA_SIZE		1024
#define CAC_LINE_SIZE		4

#define TAG_VALID		0x02000000
#define TAG_AMASK		0x01fffc00


/* forward declarations */

LOCAL UINT16 cacheSh7040CCRSet (UINT16 ccr);
LOCAL STATUS cacheSh7040Enable (CACHE_TYPE cache);
LOCAL STATUS cacheSh7040Disable (CACHE_TYPE cache);
LOCAL STATUS cacheSh7040Invalidate (CACHE_TYPE cache, void *from, size_t bytes);
LOCAL STATUS cacheSh7040TextUpdate (void *address, size_t bytes);


LOCAL UINT16 cacheSh7040Ccr = 0x1234;	/* This variable must have an initial
					 * value, since usrInit() clears bss
					 * segment after cacheSh7040LibInit()
					 * initializes it.
					 */

/******************************************************************************
*
* cacheSh7040LibInit - initialize the SH7040 cache library
* 
* This routine initializes the cache library for the Hitachi SH7040 processors.
* It initializes the function pointers and configures the caches to the
* specified cache modes.  Modes should be set before caching is enabled.
* If two complementary flags are set (enable/disable), no action is taken
* for any of the input flags.
*
* Next caching modes are available for the SH7040 processors:
*
* .TS
* tab(|);
* l l l l.
* | SH7040:| CACHE_WRITETHROUGH | (cache for instruction)
* |        | CACHE_SH7040_DRAM  | (enable caching for DRAM space)
* |        | CACHE_SH7040_CS3   | (enable caching for CS3 space)
* |        | CACHE_SH7040_CS2   | (enable caching for CS2 space)
* |        | CACHE_SH7040_CS1   | (enable caching for CS1 space)
* |        | CACHE_SH7040_CS0   | (enable caching for CS0 space)
* .TE
* 
* RETURNS: OK, or ERROR if the specified caching modes were invalid.
*/

STATUS cacheSh7040LibInit
    (
    CACHE_MODE	instMode,	/* instruction cache mode */
    CACHE_MODE	dataMode	/* data cache mode (ignored) */
    )
    {
    /* setup function pointers for cache library (declared in funcBind.c) */

    cacheLib.enableRtn          = cacheSh7040Enable;
    cacheLib.disableRtn         = cacheSh7040Disable;
    cacheLib.lockRtn            = NULL;
    cacheLib.unlockRtn          = NULL;
    cacheLib.flushRtn           = NULL;
    cacheLib.invalidateRtn      = cacheSh7040Invalidate;
    cacheLib.clearRtn           = cacheSh7040Invalidate;
    cacheLib.textUpdateRtn      = cacheSh7040TextUpdate;
    cacheLib.pipeFlushRtn       = NULL;
    cacheLib.dmaMallocRtn       = NULL;
    cacheLib.dmaFreeRtn         = NULL;
    cacheLib.dmaVirtToPhysRtn	= NULL;
    cacheLib.dmaPhysToVirtRtn	= NULL;

    /* check for parameter errors */

    if (instMode & ~(CACHE_WRITETHROUGH | CACHE_SH7040_DRAM | CACHE_SH7040_CS3
		     | CACHE_SH7040_CS2 | CACHE_SH7040_CS1 | CACHE_SH7040_CS0))
	{
	errnoSet (S_cacheLib_INVALID_CACHE);
	return ERROR;
	}
    else if ((instMode & (CACHE_SH7040_DRAM | CACHE_SH7040_CS3 |
		CACHE_SH7040_CS2 | CACHE_SH7040_CS1 | CACHE_SH7040_CS0)) == 0)
	{
	/* cache region is not specified, set a reasonable default */

	instMode |= CACHE_SH7040_DRAM | CACHE_SH7040_CS3 |
                CACHE_SH7040_CS2 | CACHE_SH7040_CS1 | CACHE_SH7040_CS0;
	}

    /* safely disable caches */

    cacheSh7040Disable (INSTRUCTION_CACHE);

    /* setup CCR value for cacheSh7040Enable */
	{
	cacheSh7040Ccr = 0;

	if (instMode & CACHE_SH7040_DRAM) cacheSh7040Ccr |= 0x0010;
	if (instMode & CACHE_SH7040_CS3)  cacheSh7040Ccr |= 0x0008;
	if (instMode & CACHE_SH7040_CS2)  cacheSh7040Ccr |= 0x0004;
	if (instMode & CACHE_SH7040_CS1)  cacheSh7040Ccr |= 0x0002;
	if (instMode & CACHE_SH7040_CS0)  cacheSh7040Ccr |= 0x0001;
	}

    /* clear entire cache array as 2KB on-chip RAM */

    bzero ((char *)CAC_ADRS_ARRAY, 0x400);	/* clear a-array */
    bzero ((char *)CAC_DATA_ARRAY, 0x400);	/* clear d-array */

    return OK;
    }

/******************************************************************************
*
* cacheSh7040CCRGet - get SH7040 cache control register value
*
* NOMANUAL
*/

UINT16 cacheSh7040CCRGet (void)
    {
    return *CAC_CCR;
    }

/******************************************************************************
*
* cacheSh7040CCRSet - set SH7040 cache control register to specified value
*
* RETURNS: original CCR value
*
* NOMANUAL
*/

LOCAL UINT16 cacheSh7040CCRSet (UINT16 ccr)
    {
    UINT16 itwas = *CAC_CCR;

    *CAC_CCR = ccr & CCR_MASK;

    return itwas & CCR_MASK;
    }

/******************************************************************************
*
* cacheSh7040Enable - enable a SH7040 cache
*
* This routine invalidates and enables the specified SH7040 cache.
*              ^^^^^^^^^^^     ^^^^^^^
* RETURNS: OK, or ERROR.
*
* NOMANUAL
*/

LOCAL STATUS cacheSh7040Enable
    (
    CACHE_TYPE cache
    )
    {
    if (cache == INSTRUCTION_CACHE && (cacheSh7040CCRGet () & CCR_MASK) == 0 &&
	cacheSh7040Invalidate (cache, 0, ENTIRE_CACHE) == OK)
	{
	cacheSh7040CCRSet (cacheSh7040Ccr);		/* enable cache */
	return OK;
	}
    else
	return ERROR;
    }

/******************************************************************************
*
* cacheSh7040Disable - disable a SH7040 cache
*
* This routine flushes and disables the specified SH7040 cache.
*              ^^^^^^^     ^^^^^^^^
* RETURNS: OK, or ERROR.
*
* NOMANUAL
*/

LOCAL STATUS cacheSh7040Disable
    (
    CACHE_TYPE cache
    )
    {
    if (cache == INSTRUCTION_CACHE && (cacheSh7040CCRGet () & CCR_MASK) != 0)
	{
	cacheSh7040CCRSet (0);				/* disable cache */
	return OK;
	}
    else
	return ERROR;
    }

/******************************************************************************
*
* cacheSh7040Invalidate - invalidate some entries from SH7040 cache
*
* This routine invalidates some or all entries from SH7040 cache.
*
* RETURNS: OK, or ERROR if the cache type is invalid or the cache control
* is not supported.
*
* NOMANUAL
*/

LOCAL STATUS cacheSh7040Invalidate
    (
    CACHE_TYPE cache,
    void *     from,
    size_t     bytes
    )
    {
    if (cache != INSTRUCTION_CACHE || (UINT32)from > MAX_CACHEABLE_ADRS)
	return ERROR;

    if (bytes == ENTIRE_CACHE)
	{
	UINT32 ix;
	for (ix = 0; ix <= 0x3fc; ix += CAC_LINE_SIZE)
	    {
	    int    ikey = intLock ();			/* LOCK INTERRUPTS */
	    UINT16 ckey = cacheSh7040CCRSet (0);	/* disable cache */

	    *(UINT32 *)(CAC_ADRS_ARRAY | ix) &= ~TAG_VALID; /* invalidate */

	    cacheSh7040CCRSet (ckey);			/* restore ccr */
	    intUnlock (ikey);				/* UNLOCK INTERRUPTS */
	    }
	}
    else if (bytes != 0)
	{
	UINT32 ca_begin = (UINT32)from & ~(CAC_LINE_SIZE - 1);
	UINT32 ca_end   = (UINT32)from + bytes - 1;

	if (ca_end > MAX_CACHEABLE_ADRS)
	    {
	    ca_end = MAX_CACHEABLE_ADRS;
	    bytes = ca_end - (UINT32)from + 1;
	    }

	if (bytes < CAC_DATA_SIZE) /* check corresponding cache tag */
	    {
	    UINT32 ca;
	    for (ca = ca_begin; ca <= ca_end; ca += CAC_LINE_SIZE)
		{
		UINT32 *ptag = (UINT32 *)(CAC_ADRS_ARRAY | (ca & 0x3fc));

		int    ikey = intLock ();		/* LOCK INTERRUPTS */
		UINT16 ckey = cacheSh7040CCRSet (0);	/* disable cache */

		UINT32  tag = *ptag;
		if ((tag & TAG_VALID) && (((tag ^ ca) & TAG_AMASK) == 0))
		    {
		    *ptag = tag & ~TAG_VALID;
		    }

		cacheSh7040CCRSet (ckey);		/* restore ccr */
		intUnlock (ikey);			/* UNLOCK INTERRUPTS */
		}
	    }
	else /* check every cache tag */
	    {
	    UINT32 ix;
	    for (ix = 0; ix <= 0x3fc; ix += CAC_LINE_SIZE)
		{
		UINT32 *p = (UINT32 *)(CAC_ADRS_ARRAY | ix);

		int    ikey = intLock ();		/* LOCK INTERRUPTS */
		UINT16 ckey = cacheSh7040CCRSet (0);	/* disable cache */

		UINT32 tag  = *p;
		if (tag & TAG_VALID)
		    {
		    UINT32 ca = (tag & TAG_AMASK) | ix;	/* cached address */

		    if ((ca >= ca_begin) && (ca <= ca_end))
			*p = tag & ~TAG_VALID;
		    }

		cacheSh7040CCRSet (ckey);		/* restore ccr */
		intUnlock (ikey);			/* UNLOCK INTERRUPTS */
		}
	    }
	}
    return OK;
    }

/******************************************************************************
*
* cacheSh7040TextUpdate - synchronize the SH7040 cache
*
* This routine forces the instruction cache to fetch code that may have been
* created via the data path.  Since the SH7040 caches instruction only, we
* just invalidate the instruction cache.
*
* RETURNS: OK, or ERROR if the specified address range is invalid.
*
* NOMANUAL
*/
 
LOCAL STATUS cacheSh7040TextUpdate
    (
    void  *address,
    size_t bytes
    )
    {
    return cacheSh7040Invalidate (INSTRUCTION_CACHE, address, bytes);
    }

#undef CAC_DEBUG
#ifdef CAC_DEBUG

#include "stdio.h"

LOCAL UINT32 va[256][2];		/* 256-entry * (tag[1] + data[1]) */

/******************************************************************************
*
* cacheSh7040Dump - dump SH7040 cache
*
* NOMANUAL
*/

LOCAL int partition (UINT32 a[][2], int l, int r)
    {
    int i, j, pivot;
    UINT32 t;

    i = l - 1;
    j = r;
    pivot = a[r][0] & 0x01ffffff;			/* split off V-bit */
    for (;;)
	{
	while ((a[++i][0] & 0x01ffffff) < pivot)	/* split off V-bit */
	    ;
	while (i < --j && pivot < (a[j][0] & 0x01ffffff)) /* split off V-bit */
	    ;
	if (i >= j)
	    break;
	t = a[i][0]; a[i][0] = a[j][0]; a[j][0] = t;
	t = a[i][1]; a[i][1] = a[j][1]; a[j][1] = t;
	}
    t = a[i][0]; a[i][0] = a[r][0]; a[r][0] = t;
    t = a[i][1]; a[i][1] = a[r][1]; a[r][1] = t;
    return i;
    }

LOCAL void quick_sort_1 (UINT32 a[][2], int l, int r)
    {
    int v;

    if (l >= r)
	return;

    v = partition (a, l, r);

    quick_sort_1 (a, l, v - 1);		/* sort left partial array */

    quick_sort_1 (a, v + 1, r);		/* sort right partial array */
    }

LOCAL void quick_sort (UINT32 a[][2], int n)
    {
    quick_sort_1 (a, 0, n - 1);
    }

LOCAL void cacheSh7040DumpOp (UINT32 a[][2])
    {
    int i;

    for (i = 0; i < 256; i++)
	{
	UINT32 ix = i << 2;

	a[i][0] = (*(UINT32 *)(CAC_ADRS_ARRAY | ix) & 0x03fffc00) | ix;
	a[i][1] =  *(UINT32 *)(CAC_DATA_ARRAY | ix);
	}
    }

LOCAL void cacheSh7040Disp (UINT32 a[][2])
    {
    int i;

    quick_sort (a, 256);

    for (i = 0; i < 256; i++)
	{
	printf ("0x%08x: %08x  %s\n", a[i][0] & 0x01ffffff, a[i][1],
				      a[i][0] & TAG_VALID ? "V+" : "V-");
	}
    }

void cacheSh7040ClearTest (int addr, int bytes, BOOL lock)
    {
    UINT32 (*a)[256][2] = (UINT32(*)[256][2])va;
    UINT16 ccr;

    if (lock)
	{
	ccr = cacheSh7040CCRSet (0);			/* disable cache */
	cacheClear (INSTRUCTION_CACHE, (void *)addr, bytes);
	}
    else
	{
	cacheClear (INSTRUCTION_CACHE, (void *)addr, bytes);
	ccr = cacheSh7040CCRSet (0);			/* disable cache */
	}
    cacheSh7040DumpOp (*a);
    cacheSh7040CCRSet (ccr);				/* restore ccr */
    cacheSh7040Disp (*a);
    }

void cacheSh7040ClearTestAll (BOOL lock)
    {
    cacheSh7040ClearTest (0, ENTIRE_CACHE, lock);
    }

void cacheSh7040Dump ()
    {
    cacheSh7040ClearTest (0, 0, FALSE);
    }

void cacheSh7040EnableTest ()
    {
    cacheSh7040Disable (INSTRUCTION_CACHE);
    cacheSh7040Enable (INSTRUCTION_CACHE);
    cacheSh7040Dump ();
    }

#endif /* CAC_DEBUG */
