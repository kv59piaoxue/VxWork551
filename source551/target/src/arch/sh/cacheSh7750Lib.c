/* cacheSh7750Lib.c - Hitachi SH7750 cache management library */

/* Copyright 1998-2001 Wind River Systems, Inc. */
#include "copyright_wrs.h"

/*
modification history
--------------------
02r,23nov01,hk   removed checking vmLibInfo.vmLibInstalled in cacheSh7750DmaFree
		 and cacheSh7750P2DmaFree for INCLUDE_MMU_BASIC (SPR 71807).
02q,20nov01,hk   use cacheSh7750ILineInvalidate() in I-cache clear/invalidate
		 routines for faster intVecSet() operation with MMU enabled.
02o,24oct01,zl   fixes for doc builds.
02p,09oct01,frf  fixed cacheSh7750Clear() function for non enhanced mode.
02o,03oct01,frf  modified arguments for cacheSh7750TClear/TFlush/TInvalidate() 
                 in enhanced mode.
02n,05jun01,frf  added 2way set associative mode support.
02m,04mar01,hk   fix cacheSh7750Clear/cacheSh7750Invalidate to associatively
		 invalidate I-cache entries only if MMU is turned OFF.
02l,27feb01,hk   add Hitachi to library description.
02k,06dec00,hk   change cacheFlush() to return ERROR for I-cache. change to run
		 ocbwb/ocbi/ocbp codes on cached region. change cache sensitive
		 operations to asm. refer to cacheDataEnabled in cacheSh7750Dma
		 Malloc/Free(). change flush/clear/invalidate operations accord-
		 ing to specified size. disable CCR.ORA while CCR.OCE is 0. add
		 cache test tools.
02j,21jun99,zl   enable (disable) data cache only if previously it was disabled
                 (enabled).
01i,10jun99,zl   set cacheMmuAvailable to T/F depending on data cache mode.
01h,24feb99,hk   fixed copyright year.
01g,09oct98,hk   code review: made IC/OC operations balanced.
01f,07oct98,st   changed to use cacheOCClearP2() instead of memory mapped cache 
		 configuration in cacheSh7750Clear().
		 changed ENTIRE_CACHE operation in cacheSh7750Clear().
01e,29sep98,hk   code review: forced cacheLib.flushRtn to point cacheSh7750Clear
01d,23sep98,st   changed to use memory mapped cache configuration instead of
		 cacheOCClearP2() in cacheSh7750Clear().
01c,22sep98,st   changed ENTIRE_CACHE management in cacheSh7750Clear() and
		 cacheSh7750Invalidate(). changed cast from (int) to (UINT32) in
		 cacheSh7750Flush, cacheSh7750Invalidate and cacheSh7750Clear.
01b,21sep98,hk   code review: simplified caching modes. changed to use
		 cacheCCRSetP2() instead of cacheSh7750CCRWrite().
		 renamed cacheSh7750ICInvalidate() as LOCAL cacheICInvalidate().
		 introduced cacheCCRSetP2, cacheICInvalidateP2,
		 cacheOCInvalidateP2, cacheOCClearP2.
		 changed SH7750_CACHE_MAX_ENTRY to DATA_CACHE_MAX_BYTES.
		 deleted cacheFuncsSet() from instruction cache operations.
		 changed cacheLib.flushRtn to cacheSh7750Flush().
01a,17aug98,st   derived from cacheSh7700Lib.c-01k.
*/

/*
DESCRIPTION
This library contains architecture-specific cache library functions for
the Hitachi SH7750 architecture.  There is a 8-Kbyte instruction cache and
16-Kbyte operand cache that operates in write-through or write-back (copyback)
mode.  The 16-Kbyte operand cache can be divided into 8-Kbyte cache and
8-Kbyte memory.  Cache line size is fixed at 32 bytes,
and the cache address array holds physical addresses as cache tags.
Cache entries may be "flushed" by accesses to the address array in privileged
mode.  There is a write-back buffer which can hold one line of cache entry,
and the completion of write-back cycle is assured by accessing to any cache
through region.

For general information about caching, see the manual entry for cacheLib.

INCLUDE FILES: cacheLib.h

SEE ALSO: cacheLib
*/

/* LINTLIBRARY */

#include "vxWorks.h"
#include "errnoLib.h"
#include "cacheLib.h"
#include "stdlib.h"
#include "string.h"			/* for bzero() */
#include "private/memPartLibP.h"
#include "private/vmLibP.h"
#include "private/funcBindP.h"


/* imports */

IMPORT UINT32 cacheSh7750CCRSetOp (UINT32 ccr);
IMPORT UINT32 cacheSh7750CCRGet (void);
IMPORT STATUS cacheSh7750DCacheOnOp (BOOL on);
IMPORT STATUS cacheSh7750DFlushAllOp (void);
IMPORT STATUS cacheSh7750DClearAllOp (void);
IMPORT STATUS cacheSh7750TFlushOp (UINT32 *pt, int ix, UINT32 from, UINT32 to);
IMPORT STATUS cacheSh7750TInvalOp (UINT32 *pt, int ix, UINT32 from, UINT32 to);
IMPORT STATUS cacheSh7750TClearOp (UINT32 *pt, int ix, UINT32 from, UINT32 to);
IMPORT STATUS cacheSh7750DFlush (void *from, size_t bytes);
IMPORT STATUS cacheSh7750DInvalidate (void *from, size_t bytes);
IMPORT STATUS cacheSh7750DClear (void *from, size_t bytes);
IMPORT STATUS cacheSh7750PipeFlush (void);
IMPORT STATUS cacheSh7750IInvalOp (void *from, size_t bytes);
IMPORT STATUS cacheSh7750ILineInvalOp (void *va);

/* local definitions */

#define ICACHE_ADRS_ARRAY	0xf0000000
#define ICACHE_DATA_ARRAY	0xf1000000
#define DCACHE_ADRS_ARRAY	0xf4000000
#define DCACHE_DATA_ARRAY	0xf5000000

/* SH7750 Cache Control Register bit define */
#define CCR_2WAY_EMODE		0x80000000	/* Enhanced mode */
#define CCR_IC_INDEX_ENABLE	0x00008000	/* IC index mode (4k * 2) */
#define CCR_IC_INVALIDATE	0x00000800	/* clear all V bits of IC */
#define CCR_IC_ENABLE		0x00000100	/* enable instruction cache */
#define CCR_OC_INDEX_ENABLE	0x00000080	/* OC index mode (8k * 2) */
#define CCR_OC_RAM_ENABLE	0x00000020	/* 8KB operand cache +8KB RAM */
#define CCR_OC_INVALIDATE	0x00000008	/* clear all V/U bits of OC */
#define CCR_WRITE_BACK_P1	0x00000004	/* set P1 to write-back */
#define CCR_WRITE_THRU		0x00000002	/* set P0/P3 to write-thru */

/* forward declarations */

LOCAL STATUS cacheSh7750Enable (CACHE_TYPE cache);
LOCAL STATUS cacheSh7750Disable (CACHE_TYPE cache);
LOCAL STATUS cacheSh7750Flush (CACHE_TYPE cache, void *from, size_t bytes);
LOCAL STATUS cacheSh7750Invalidate (CACHE_TYPE cache, void *from, size_t bytes);
LOCAL STATUS cacheSh7750Clear (CACHE_TYPE cache, void *from, size_t bytes);
LOCAL STATUS cacheSh7750TextUpdate (void *from, size_t bytes);
LOCAL void * cacheSh7750DmaMalloc (size_t bytes);
LOCAL STATUS cacheSh7750DmaFree (void * pBuf);
LOCAL void * cacheSh7750P2DmaMalloc (size_t bytes);
LOCAL STATUS cacheSh7750P2DmaFree (void * pBuf);

/* These must be .data, .bss will be cleared */

LOCAL FUNCPTR cacheSh7750CCRSet          = (FUNCPTR)0x1234;
LOCAL FUNCPTR cacheSh7750DCacheOn        = (FUNCPTR)0x5678;
LOCAL FUNCPTR cacheSh7750DFlushAll       = (FUNCPTR)0x1111;
LOCAL FUNCPTR cacheSh7750DClearAll       = (FUNCPTR)0x1111;
LOCAL FUNCPTR cacheSh7750TFlush          = (FUNCPTR)0x1234;
LOCAL FUNCPTR cacheSh7750TInvalidate     = (FUNCPTR)0x1234;
LOCAL FUNCPTR cacheSh7750TClear          = (FUNCPTR)0x1234;
LOCAL FUNCPTR cacheSh7750IInvalidate     = (FUNCPTR)0x1234;
LOCAL FUNCPTR cacheSh7750ILineInvalidate = (FUNCPTR)0x1234;

/******************************************************************************
*
* cacheSh7750LibInit - initialize the SH7750 cache library
* 
* This routine initializes the cache library for the Hitachi SH7750 processor.
* It initializes the function pointers and configures the caches to the
* specified cache modes.  Modes should be set before caching is enabled.
* If two complementary flags are set (enable/disable), no action is taken
* for any of the input flags.
*
* The following caching modes are available for the SH7750 processor:
*
* .TS
* tab(|);
* l l l l.
* | SH7750:| CACHE_WRITETHROUGH  |
* |        | CACHE_COPYBACK      | (copy-back cache for P0/P3, data cache only)
* |        | CACHE_COPYBACK_P1   | (copy-back cache for P1, data cache only)
* |        | CACHE_RAM_MODE      | (use half of cache as RAM, data cache only)
* |        | CACHE_2WAY_MODE     | (use RAM in 2way associ. mode, data cache only)
* |        | CACHE_A25_INDEX     | (use A25 as MSB of cache index)
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
* RETURNS: OK, or ERROR if specified cache mode is invalid.
*/

STATUS cacheSh7750LibInit
    (
    CACHE_MODE instMode,	/* instruction cache mode */
    CACHE_MODE dataMode		/* data cache mode */
    )
    {
    /* setup function pointers for cache library (declared in funcBind.c) */

    cacheLib.enableRtn          = cacheSh7750Enable;
    cacheLib.disableRtn         = cacheSh7750Disable;

    cacheLib.lockRtn            = NULL;
    cacheLib.unlockRtn          = NULL;

    /* cacheLib.flushRtn can be NULL in write-through mode,
     * but mmu may turn on copy back.
     */
    cacheLib.flushRtn		= cacheSh7750Flush;
    cacheLib.invalidateRtn      = cacheSh7750Invalidate;
    cacheLib.clearRtn		= cacheSh7750Clear;
    cacheLib.textUpdateRtn	= cacheSh7750TextUpdate;
    cacheLib.pipeFlushRtn	= cacheSh7750PipeFlush;

    /* setup P2 function pointers for cache sensitive operations */

    cacheSh7750CCRSet		= (FUNCPTR)(((UINT32)cacheSh7750CCRSetOp
				& SH7750_PHYS_MASK) | SH7750_P2_BASE);
    cacheSh7750DCacheOn		= (FUNCPTR)(((UINT32)cacheSh7750DCacheOnOp
				& SH7750_PHYS_MASK) | SH7750_P2_BASE);
    cacheSh7750DFlushAll	= (FUNCPTR)(((UINT32)cacheSh7750DFlushAllOp
				& SH7750_PHYS_MASK) | SH7750_P2_BASE);
    cacheSh7750DClearAll	= (FUNCPTR)(((UINT32)cacheSh7750DClearAllOp
				& SH7750_PHYS_MASK) | SH7750_P2_BASE);
    cacheSh7750TFlush		= (FUNCPTR)(((UINT32)cacheSh7750TFlushOp
				& SH7750_PHYS_MASK) | SH7750_P2_BASE);
    cacheSh7750TInvalidate	= (FUNCPTR)(((UINT32)cacheSh7750TInvalOp
				& SH7750_PHYS_MASK) | SH7750_P2_BASE);
    cacheSh7750TClear		= (FUNCPTR)(((UINT32)cacheSh7750TClearOp
				& SH7750_PHYS_MASK) | SH7750_P2_BASE);
    cacheSh7750IInvalidate	= (FUNCPTR)(((UINT32)cacheSh7750IInvalOp
				& SH7750_PHYS_MASK) | SH7750_P2_BASE);
    cacheSh7750ILineInvalidate	= (FUNCPTR)(((UINT32)cacheSh7750ILineInvalOp
				& SH7750_PHYS_MASK) | SH7750_P2_BASE);

    /* select cache-safe malloc/free routines for DMA buffer */

    if (dataMode &
        (CACHE_DMA_BYPASS_P0 | CACHE_DMA_BYPASS_P1 | CACHE_DMA_BYPASS_P3))
	{
	cacheLib.dmaMallocRtn   = (FUNCPTR)cacheSh7750P2DmaMalloc;
	cacheLib.dmaFreeRtn     = cacheSh7750P2DmaFree;
	cacheMmuAvailable	= TRUE;		/* for cacheFuncsSet() */
	}
    else
	{
	cacheLib.dmaMallocRtn   = (FUNCPTR)cacheSh7750DmaMalloc;
	cacheLib.dmaFreeRtn     = cacheSh7750DmaFree;
	cacheMmuAvailable	= FALSE;	/* needs MMU support for cache
						   safe allocation */
	}

    cacheLib.dmaVirtToPhysRtn	= NULL;
    cacheLib.dmaPhysToVirtRtn	= NULL;

    /* check for parameter errors */

    if ((instMode & ~(CACHE_WRITETHROUGH | CACHE_A25_INDEX)) ||
	(dataMode & ~(CACHE_WRITETHROUGH | CACHE_COPYBACK | CACHE_RAM_MODE |
             CACHE_DMA_BYPASS_P0 | CACHE_DMA_BYPASS_P1 | CACHE_DMA_BYPASS_P3 |
             CACHE_A25_INDEX | CACHE_COPYBACK_P1 | CACHE_2WAY_MODE )) ||
	((dataMode & CACHE_WRITETHROUGH)  && (dataMode & CACHE_COPYBACK))     ||
	((dataMode & CACHE_DMA_BYPASS_P0) && (dataMode & CACHE_DMA_BYPASS_P1))||
	((dataMode & CACHE_DMA_BYPASS_P1) && (dataMode & CACHE_DMA_BYPASS_P3))||
	((dataMode & CACHE_DMA_BYPASS_P3) && (dataMode & CACHE_DMA_BYPASS_P0)))
	{
	errnoSet (S_cacheLib_INVALID_CACHE);
	return ERROR;
	}

    /* initialize cache modes (declared in cacheLib.c) */

    cacheDataMode    = dataMode;
    cacheDataEnabled = FALSE;

    /* safely disable caches */

    cacheLib.disableRtn (DATA_CACHE);
    cacheLib.disableRtn (INSTRUCTION_CACHE);

    /* initialize CCR (defer CACHE_RAM_MODE setup to cacheEnable) */
	{
	UINT32 ccr = 0;

	if (dataMode & CACHE_WRITETHROUGH) ccr |= CCR_WRITE_THRU;
	if (dataMode & CACHE_COPYBACK_P1)  ccr |= CCR_WRITE_BACK_P1;
	if (dataMode & CACHE_A25_INDEX)    ccr |= CCR_OC_INDEX_ENABLE;

	if (dataMode & CACHE_2WAY_MODE) 
	  {
	  /* OC index mode cannot be used with RAM mode enabled in 
	   * the enhanced version.
	   */
	  if (dataMode & CACHE_RAM_MODE)
	      ccr &= ~CCR_OC_INDEX_ENABLE;

	  ccr |= CCR_2WAY_EMODE;
	  }

	if (instMode & CACHE_A25_INDEX)    ccr |= CCR_IC_INDEX_ENABLE;

	cacheSh7750CCRSet (ccr);	/* caches are still disabled */
	}

    return OK;
    }

/******************************************************************************
*
* cacheSh7750Enable - enable a SH7750 cache
*
* This routine invalidates the cache tags and enables the instruction or data
* cache.       ^^^^^^^^^^^                    ^^^^^^^
*
* RETURNS: OK, or ERROR if the specified cache type was invalid.
*
* NOMANUAL
*/

LOCAL STATUS cacheSh7750Enable
    (
    CACHE_TYPE cache
    )
    {
    STATUS status = ERROR;

    switch (cache)
	{
	case INSTRUCTION_CACHE:
	    {
	    UINT32 ccr = cacheSh7750CCRGet ();

	    cacheSh7750CCRSet ((ccr & ~CCR_IC_ENABLE) | CCR_IC_INVALIDATE);
	    cacheSh7750CCRSet ( ccr |  CCR_IC_ENABLE);

	    status = OK;
	    }
	    break;

	case DATA_CACHE:

	    if ((status = cacheSh7750DCacheOn (TRUE)) == OK)
		{
		if (cacheDataMode & CACHE_2WAY_MODE )
		    {
		    if (cacheDataMode & CACHE_RAM_MODE )
		      {
		      UINT32 ccr = cacheSh7750CCRGet ();

		      /* enable on-chip RAM */

		      cacheSh7750CCRSet (ccr | CCR_OC_RAM_ENABLE);

		      /* initialize on-chip RAM */

		      bzero ((char *)0x7c000000, 16384);
		      }
		    }
		else  if (cacheDataMode & CACHE_RAM_MODE )
		  {
		  UINT32 ccr = cacheSh7750CCRGet ();

		  /* enable on-chip RAM */

		  cacheSh7750CCRSet (ccr | CCR_OC_RAM_ENABLE);

		  /* initialize on-chip RAM */

		  if (ccr & CCR_OC_INDEX_ENABLE)
		    bzero ((char *)0x7dfff000, 8192);
		  else
		    bzero ((char *)0x7c001000, 8192);
		  }

		cacheDataEnabled = TRUE;
		cacheFuncsSet ();	/* update cache function pointers */
		}
	    break;

	default:
	    errno = S_cacheLib_INVALID_CACHE;
	}

    return status;
    }

/******************************************************************************
*
* cacheSh7750Disable - disable a SH7750 cache
*
* This routine flushes the cache and disables the instruction or data cache.
*              ^^^^^^^               ^^^^^^^^
* RETURNS: OK, or ERROR if the specified cache type was invalid.
*
* NOMANUAL
*/

LOCAL STATUS cacheSh7750Disable
    (
    CACHE_TYPE cache
    )
    {
    STATUS status = ERROR;

    switch (cache) 
	{
	case INSTRUCTION_CACHE:
	    {
	    UINT32 ccr = cacheSh7750CCRGet ();

	    cacheSh7750CCRSet ((ccr & ~CCR_IC_ENABLE) | CCR_IC_INVALIDATE);
	    status = OK;
	    }
	    break;

	case DATA_CACHE:

	    if ((status = cacheSh7750DCacheOn (FALSE)) == OK)
		{
		UINT32 ccr = cacheSh7750CCRGet ();

		/* Hitachi advises to clear CCR.ORA while CCR.OCE==0 */

		if (ccr & CCR_OC_RAM_ENABLE)
		    cacheSh7750CCRSet (ccr & ~CCR_OC_RAM_ENABLE);

		cacheDataEnabled = FALSE;
		cacheFuncsSet ();	/* update cache function pointers */
		}
	    break;

	default:
	    errno = S_cacheLib_INVALID_CACHE;
	}

    return status;
    }

/******************************************************************************
*
* cacheSh7750Flush - flush all or some entries in a cache
*
* This routine flushes (writes to memory) all or some of the entries in the
* specified cache.  This operation may also invalidate the cache tags.  For
* write-through caches, no work needs to be done since RAM already matches
* the cached entries.  Note that write buffers on the chip may need to be
* flushed to complete the flush.
*
* RETURNS: OK, or ERROR if the cache type is invalid or the cache control
* is not supported.
*
* NOMANUAL
*/

LOCAL STATUS cacheSh7750Flush
    (
    CACHE_TYPE cache,
    void *     from,
    size_t     bytes
    )
    {
    UINT32 p = (UINT32)from;

    if (p >= SH7750_P2_BASE && p <= (SH7750_P2_BASE | SH7750_PHYS_MASK))
	return ERROR;					/* P2 non-cacheable */
    else if (p >= SH7750_P4_BASE)
	return ERROR;					/* P4 non-cacheable */

    switch (cache)
	{
	case DATA_CACHE:
	    if (bytes == ENTIRE_CACHE)
		{
		cacheSh7750DFlushAll ();
		}
	    else
		{
		UINT32 ccr = cacheSh7750CCRGet ();

		if (ccr & CCR_2WAY_EMODE)
		    {
		    if (bytes <= ((ccr & CCR_OC_RAM_ENABLE) ? 0x80000
				  : 0x100000))
		        {
			/* use ocbwb instr. */
			cacheSh7750DFlush (from, bytes);
		        }
		    else /* check every D-cache tag */
		        {
			UINT32 ca_begin = p & 0xffffffe0;
			UINT32 ca_end   = p + bytes - 1;
			UINT32 bsel, ix, way, nMaxWay = 0x4000;

			if (ccr & CCR_OC_RAM_ENABLE)
			    nMaxWay = 0;	/* only one way */

			for (way = 0; way <= nMaxWay; way += 0x4000 )
			    {  
			    for (bsel = 0; bsel <= 0x3000; bsel += 0x1000)
			        {
				/*if ((ccr & CCR_OC_RAM_ENABLE) &&
				 *   (bsel == 0x2000) ) continue;
				 */
				
				for (ix = 0; ix <= 0xfe0; ix += 0x20)
				    {
				    UINT32 *pt;

				    pt = (UINT32 *)(DCACHE_ADRS_ARRAY |
						    way | bsel | ix);
		
				    cacheSh7750TFlush (pt, ix, ca_begin, ca_end);
				    }
				}
			    } /* way */
			} /* (ccr & CCR_OC_RAM_ENABLE) */
		    } /* (ccr & CCR_2WAY_EMODE) */
		else
		    {
		    if (bytes <= ((ccr & CCR_OC_RAM_ENABLE) ? 0x80000
				  : 0x100000))
		        {
			/* use ocbwb instr. */
			cacheSh7750DFlush (from, bytes);
			}
		    else /* check every D-cache tag */
		        {
			UINT32 ca_begin = p & 0xffffffe0;
			UINT32 ca_end   = p + bytes - 1;
			UINT32 bsel, ix;

			for (bsel = 0; bsel <= 0x3000; bsel += 0x1000)
			    {
			    if ((ccr & CCR_OC_RAM_ENABLE) &&
				(bsel == 0x1000 || bsel == 0x3000)) continue;
		
			    for (ix = 0; ix <= 0xfe0; ix += 0x20)
			        {
				UINT32 *pt;

				pt = (UINT32 *)(DCACHE_ADRS_ARRAY | bsel | ix);
		
				cacheSh7750TFlush (pt, ix, ca_begin, ca_end);
				}
			    }
			}
		    }
		} /* (bytes == ENTIRE_CACHE) */
	    cacheLib.pipeFlushRtn ();
	    break;

	default:
	    errno = S_cacheLib_INVALID_CACHE;

	case INSTRUCTION_CACHE:
	    return ERROR;		/* no flush operation for I-cache */
	}

    return OK;
    }

/******************************************************************************
*
* cacheSh7750Clear - clear all or some entries from a SH7750 cache
*
* This routine flushes and invalidates all or some entries of the specified
* SH7750 cache.
*
* RETURNS: OK, or ERROR if the cache type is invalid or the cache control
* is not supported.
*
* NOMANUAL
*/

LOCAL STATUS cacheSh7750Clear
    (
    CACHE_TYPE cache,
    void *     from,
    size_t     bytes
    )
    {
    UINT32 ccr = cacheSh7750CCRGet ();
    UINT32 p = (UINT32)from;

    if (p >= SH7750_P2_BASE && p <= (SH7750_P2_BASE | SH7750_PHYS_MASK))
	return ERROR;					/* P2 non-cacheable */
    else if (p >= SH7750_P4_BASE)
	return ERROR;					/* P4 non-cacheable */

    switch (cache)
	{
	case DATA_CACHE:
	    if (bytes == ENTIRE_CACHE)
		{
		cacheSh7750DClearAll ();
		}
	    else
		{
		if (ccr & CCR_2WAY_EMODE)
		    {
		    if (bytes <= ((ccr & CCR_OC_RAM_ENABLE) ? 0x80000
				  : 0x100000))
		        {
			/* use ocbp instr. */
			cacheSh7750DClear (from, bytes);
			}
		    else /* check every D-cache tag */
		        {
			UINT32 ca_begin = p & 0xffffffe0;
			UINT32 ca_end   = p + bytes - 1;
			UINT32 bsel, ix, way, nMaxWay = 0x4000;

			if (ccr & CCR_OC_RAM_ENABLE)
			    nMaxWay = 0;	/* only one way */

			for (way = 0; way <= nMaxWay; way += 0x4000 )
			  {  
			  for (bsel = 0; bsel <= 0x3000; bsel += 0x1000)
			    {
			    /*if ((ccr & CCR_OC_RAM_ENABLE) &&
			     *	(bsel == 0x2000) ) continue;
			     */
			    
			    for (ix = 0; ix <= 0xfe0; ix += 0x20)
			      {
			      UINT32 *pt;

			      pt = (UINT32 *)(DCACHE_ADRS_ARRAY |
					      way | bsel | ix);
		
			      cacheSh7750TClear (pt, ix, ca_begin, ca_end);
			      }
			    }
			  } /* way */
			} /* (ccr & CCR_OC_RAM_ENABLE) */
		    } /* (ccr & CCR_2WAY_EMODE) */
		else
		    {
		    if (bytes <= ((ccr & CCR_OC_RAM_ENABLE) ? 0x80000
				  : 0x100000))
		        {
			/* use ocbp instr. */
			cacheSh7750DClear (from, bytes);
			}
		    else /* check every D-cache tag */
		        {
			UINT32 ca_begin = p & 0xffffffe0;
			UINT32 ca_end   = p + bytes - 1;
			UINT32 bsel, ix;

			for (bsel = 0; bsel <= 0x3000; bsel += 0x1000)
			  {
			  if ((ccr & CCR_OC_RAM_ENABLE) &&
			      (bsel == 0x1000 || bsel == 0x3000)) continue;
		
			  for (ix = 0; ix <= 0xfe0; ix += 0x20)
			    {
			    UINT32 *pt;

			    pt = (UINT32 *)(DCACHE_ADRS_ARRAY | bsel | ix);
		
			    cacheSh7750TClear (pt, ix, ca_begin, ca_end);
			    }
			  }
			}
		    }
		}
	    cacheLib.pipeFlushRtn ();
	    break;

	case INSTRUCTION_CACHE:
	    if (bytes == ENTIRE_CACHE)
		{
		cacheSh7750CCRSet (ccr | CCR_IC_INVALIDATE);
		}
	    else
		{
		UINT32 mmucr = *(volatile UINT32 *)0xff000010;

		if (mmucr & 0x1) /* ITLB mishit voids associative invalidation*/
		    {
		    UINT32 startline = p & 0xffffffe0;
		    UINT32 endline  = (p + bytes - 1) & 0xffffffe0;

		    if (startline == endline)
			return cacheSh7750ILineInvalidate (from);
		    else
			cacheSh7750CCRSet (ccr | CCR_IC_INVALIDATE);
		    }
		else if (bytes <= 32768) /* do associative invalidation */
		    {
		    cacheSh7750IInvalidate (from, bytes);
		    }
		else /* check every I-cache tag (it takes a while) */
		    {
		    UINT32 ca_begin = p & 0xffffffe0;
		    UINT32 ca_end   = p + bytes - 1;
		    UINT32 ix, way, nMaxWay = 0;

		    if ( ccr & CCR_2WAY_EMODE )
		        nMaxWay = 0x2000;

		    for (way = 0; way <= nMaxWay; way += 0x2000)
			{
			for (ix = 0; ix <= 0x1fe0; ix += 0x20)
			    {
			    UINT32 *pt = (UINT32 *)(ICACHE_ADRS_ARRAY|way|ix);
			
			    cacheSh7750TInvalidate (pt, ix, ca_begin, ca_end);
			    }
			}
		    }
		}
	    break;

	default:
	    errno = S_cacheLib_INVALID_CACHE;
	    return ERROR;
	}

    return OK;
    }

/******************************************************************************
*
* cacheSh7750Invalidate - invalidate all or some entries from a SH7750 cache
*
* This routine invalidates all or some entries of the SH7750 cache.
* Depending on cache design, the invalidation may be similar to the flush,
* or the tags may be invalidated directly.
*
* RETURNS: OK, or ERROR if the cache type is invalid or the cache control
* is not supported.
*
* NOMANUAL
*/

LOCAL STATUS cacheSh7750Invalidate
    (
    CACHE_TYPE cache,
    void *     from,
    size_t     bytes
    )
    {
    UINT32 ccr = cacheSh7750CCRGet ();
    UINT32 p = (UINT32)from;

    if (p >= SH7750_P2_BASE && p <= (SH7750_P2_BASE | SH7750_PHYS_MASK))
	return ERROR;					/* P2 non-cacheable */
    else if (p >= SH7750_P4_BASE)
	return ERROR;					/* P4 non-cacheable */

    switch (cache)
	{
	case DATA_CACHE:
	    {
	    if (bytes == ENTIRE_CACHE)
		{
		UINT32 mmucr = *(volatile UINT32 *)0xff000010;

		if ((mmucr & 0x1) == 0 &&
		    (ccr & (CCR_WRITE_BACK_P1 | CCR_WRITE_THRU))
					     == CCR_WRITE_THRU)
		    cacheSh7750CCRSet (ccr | CCR_OC_INVALIDATE);
		else
		    cacheSh7750DClearAll ();	/* MMU may set copyback page */
		}
	    else
		{
		if (ccr & CCR_2WAY_EMODE)
		    {
		    if (bytes <= ((ccr & CCR_OC_RAM_ENABLE) ? 0x80000
				  : 0x100000))
		        {	/* use ocbi instr. */
			cacheSh7750DInvalidate (from, bytes);
			}
		    else /* check every D-cache tag */
		        {
			UINT32 bsel, ix, way, nMaxWay = 0x4000;
			UINT32 ca_begin = p & 0xffffffe0;
			UINT32 ca_end   = p + bytes - 1;
		
			if (ccr & CCR_OC_RAM_ENABLE)
			    nMaxWay = 0;	/* only one way */	

			for (way = 0; way <= nMaxWay; way += 0x4000)
			    {
			    for (bsel = 0; bsel <= 0x3000; bsel += 0x1000)
			      {
			      /*if ((ccr & CCR_OC_RAM_ENABLE) &&
			       *  (bsel == 0x2000) ) continue;
			       */
			      
			      for (ix = 0; ix <= 0xfe0; ix += 0x20)
				{
				UINT32 *pt;

				pt = (UINT32 *)(DCACHE_ADRS_ARRAY |
						way | bsel | ix);
		
				cacheSh7750TInvalidate (pt, ix,
							ca_begin, ca_end);
				}
			      }
			    }
			}
		    }
		else /* (ccr & CCR_2WAY_EMODE) */
		    {
		    if (bytes <= ((ccr & CCR_OC_RAM_ENABLE) ? 0x80000 : 0x100000))
		        {
			/* use ocbi instr. */
			cacheSh7750DInvalidate (from, bytes);
			}
		    else /* check every D-cache tag */
		        {
			UINT32 bsel, ix;
			UINT32 ca_begin = p & 0xffffffe0;
			UINT32 ca_end   = p + bytes - 1;
		
			for (bsel = 0; bsel <= 0x3000; bsel += 0x1000)
			    {
			    if ((ccr & CCR_OC_RAM_ENABLE) &&
				(bsel == 0x1000 || bsel == 0x3000)) continue;
		
			    for (ix = 0; ix <= 0xfe0; ix += 0x20)
			       {
			       UINT32 *pt;

			       pt = (UINT32 *)(DCACHE_ADRS_ARRAY | bsel | ix);
		
			       cacheSh7750TInvalidate (pt, ix, ca_begin, ca_end);
			       }
			    }
			} 
		    } /* (ccr & CCR_2WAY_EMODE) */
		} /* (bytes == ENTIRE_CACHE) */
	    }
	    break;

	case INSTRUCTION_CACHE:
	    if (bytes == ENTIRE_CACHE)
		{
		cacheSh7750CCRSet (ccr | CCR_IC_INVALIDATE);
		}
	    else
		{
		UINT32 mmucr = *(volatile UINT32 *)0xff000010;

		if (mmucr & 0x1) /* ITLB mishit voids associative invalidation*/
		    {
		    UINT32 startline = p & 0xffffffe0;
		    UINT32 endline  = (p + bytes - 1) & 0xffffffe0;

		    if (startline == endline)
			return cacheSh7750ILineInvalidate (from);
		    else
			cacheSh7750CCRSet (ccr | CCR_IC_INVALIDATE);
		    }
		else if (bytes <= 32768) /* do associative invalidation */
		    {
		    cacheSh7750IInvalidate (from, bytes);
		    }
		else /* check every I-cache tag (it takes a while) */
		    {
		    UINT32 ix, way, nMaxWay = 0;
		    UINT32 ca_begin = p & 0xffffffe0;
		    UINT32 ca_end   = p + bytes - 1;

		    if ( ccr & CCR_2WAY_EMODE )
		        nMaxWay = 0x2000;

		    for (way = 0; way <= nMaxWay; way += 0x2000)
			{
			for (ix = 0; ix <= 0x1fe0; ix += 0x20)
			    {
			    UINT32 *pt = (UINT32 *)(ICACHE_ADRS_ARRAY|way|ix);

			    cacheSh7750TInvalidate (pt, ix, ca_begin, ca_end);
			    }
			}
		    }
		}
	    break;

	default:
	    errno = S_cacheLib_INVALID_CACHE;
	    return ERROR;
	}

    return OK;
    }

/******************************************************************************
*
* cacheSh7750TextUpdate - invalidate updated text section
*
* This routine invalidates the specified text section so that
* the correct updated text is executed.
*
* NOMANUAL
*/

LOCAL STATUS cacheSh7750TextUpdate
    (
    void * from,			/* Physical address */
    size_t bytes			/* bytes to invalidate */
    )
    {
    if (cacheLib.flushRtn != NULL)
	if (cacheLib.flushRtn (DATA_CACHE, from, bytes) != OK)
	    return ERROR;

    return cacheLib.invalidateRtn (INSTRUCTION_CACHE, from, bytes);
    }

/******************************************************************************
*
* cacheSh7750DmaMalloc - allocate a cache-safe buffer
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

LOCAL void *cacheSh7750DmaMalloc
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
* cacheSh7750DmaFree - free the buffer acquired by cacheSh7750DmaMalloc()
*
* This routine returns to the free memory pool a block of memory previously
* allocated with cacheSh7750DmaMalloc().  The buffer is marked cacheable.
*
* RETURNS: OK, or ERROR if cacheSh7750DmaMalloc() cannot be undone.
*
* NOMANUAL
*/

LOCAL STATUS cacheSh7750DmaFree
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
* cacheSh7750P2DmaMalloc - allocate a cache-safe buffer from P2 region
*
* This routine attempts to return a pointer to a section of memory that will
* not experience cache coherency problems.  This routine may be called when
* MMU support is NOT available for cache control.
*
* RETURNS: A pointer to a cache-safe buffer, or NULL.
*
* NOMANUAL
*/

LOCAL void *cacheSh7750P2DmaMalloc
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

    return (void *)(((UINT32)pBuf & SH7750_PHYS_MASK) | SH7750_P2_BASE);
    }

/******************************************************************************
*
* cacheSh7750P2DmaFree - free the buffer acquired by cacheSh7750P2DmaMalloc()
*
* This routine returns to the free memory pool a block of memory previously
* allocated with cacheSh7750P2DmaMalloc().
*
* RETURNS: OK, or ERROR if cacheSh7750P2DmaMalloc() cannot be undone.
*
* NOMANUAL
*/

LOCAL STATUS cacheSh7750P2DmaFree
    (
    void *pBuf
    )
    {
    STATUS status = OK;
    UINT32 p = (UINT32)pBuf;

    if (p < SH7750_P2_BASE || p > (SH7750_P2_BASE | SH7750_PHYS_MASK))
	return ERROR;

    if (cacheDataMode & CACHE_DMA_BYPASS_P0)
	p =  p & SH7750_PHYS_MASK;			/* relocate to P0 */
    else if (cacheDataMode & CACHE_DMA_BYPASS_P1)
	p = (p & SH7750_PHYS_MASK) | SH7750_P1_BASE;	/* relocate to P1 */
    else if (cacheDataMode & CACHE_DMA_BYPASS_P3)
	p = (p & SH7750_PHYS_MASK) | SH7750_P3_BASE;	/* relocate to P3 */
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

STATUS cacheSh7750Test (CACHE_TYPE cache, int addr, int bytes, int op);

/******************************************************************************
*
* cacheSh7750Dump - dump SH7750 cache
*
* NOMANUAL
*/

STATUS cacheSh7750Dump (CACHE_TYPE cache)
    {
    return cacheSh7750Test (cache, 0, 0, OP_NONE);
    }


#include "stdio.h"
#include "intLib.h"		/* for intLock()/intUnlock() */

#undef DISPALY_CACHE_SORTED	/* display cache items sorted */ 

LOCAL UINT32 va[512][9];	/* (512-entry) * (tag[1] + data[8]) */
LOCAL UINT32 eva[1024][9];	/* (512-entry) * 2ways * (tag[1] +
				   data[8]) : enhanced mode */
LOCAL UINT32 sva[256][9];	/* (512-entry) * (tag[1] + data[8]) */
LOCAL UINT32 seva[512][9];	/* (512-entry) * 2ways * (tag[1] +
				   data[8]) : enhanced mode */

#ifdef DISPLAY_CACHE_SORTED
LOCAL int partition (UINT32 a[][9], int l, int r)
    {
    int i, j, k, pivot;
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
	for (k = 0; k < 9; k++) {t = a[i][k]; a[i][k] = a[j][k]; a[j][k] = t;}
	}
    for (k = 0; k < 9; k++) {t = a[i][k]; a[i][k] = a[r][k]; a[r][k] = t;}
    return i;
    }

LOCAL void quick_sort_1 (UINT32 a[][9], int l, int r)
    {
    int v;

    if (l >= r)
	return;

    v = partition (a, l, r);

    quick_sort_1 (a, l, v - 1);		/* sort left partial array */

    quick_sort_1 (a, v + 1, r);		/* sort right partial array */
    }

LOCAL void quick_sort (UINT32 a[][9], int n)
    {
    quick_sort_1 (a, 0, n - 1);
    }
#endif /* DISPLAY_CACHE_SORTED */

LOCAL void cacheSh7750IDumpOp (UINT32 a[][9], UINT32 ccr)
    {
    int ent, i, j, k, way;


    if ( ccr & CCR_2WAY_EMODE )
        {
        for ( way = 0; way <= 0x2000; way += 0x2000 )
            for (ent = 0, i = 0; ent <= 0x1fe0; ent += 0x20, i++)
	        {
	        UINT32 tag = *(UINT32 *)(ICACHE_ADRS_ARRAY | way | ent);
	        UINT32 dt;

	        if (ccr & CCR_IC_INDEX_ENABLE)
	            {
	            dt = (((tag ^ (ent << 13)) & 0x02000000) ||
		          ((tag ^  ent) & 0x0c00)) ? 0x4 : 0x0;
	            }
	       else
	            dt =  ((tag ^ ent) & 0x1c00) ? 0x4 : 0x0;

	       a[i + (way >> 13)*255][0] = (tag & 0xfffffc01) | (ent & 0x3e0) | dt;

	       for (j = 1, k = 0; j <= 8; j++, k += 0x4)
	           a[i + (way >> 13)*255][j] = *(UINT32 *)(ICACHE_DATA_ARRAY | way | ent | k);
	        }
        }
    else
       {      
       for (ent = 0, i = 0; ent <= 0x1fe0; ent += 0x20, i++)
	   {
	   UINT32 tag = *(UINT32 *)(ICACHE_ADRS_ARRAY | ent);
	   UINT32 dt;

	   if (ccr & CCR_IC_INDEX_ENABLE)
	       {
	       dt = (((tag ^ (ent << 13)) & 0x02000000) ||
		     ((tag ^  ent) & 0x0c00)) ? 0x4 : 0x0;
	       }
	   else
	       dt =  ((tag ^ ent) & 0x1c00) ? 0x4 : 0x0;

	   a[i][0] = (tag & 0xfffffc01) | (ent & 0x3e0) | dt;

	   for (j = 1, k = 0; j <= 8; j++, k += 0x4)
	       a[i][j] = *(UINT32 *)(ICACHE_DATA_ARRAY | ent | k);
	   }
       }
    }

LOCAL void cacheSh7750DDumpOp (UINT32 a[][9], UINT32 ccr)
    {
    int ent, i, j, k;
    UINT32 bsel, way;

    if ( ccr & CCR_2WAY_EMODE )
        {
        for ( way = 0; way <= 0x4000; way += 0x4000 )
          {
          for (i = 0, bsel = 0; bsel <= 0x3000; bsel += 0x1000)
	    {
	    if ((ccr & CCR_OC_RAM_ENABLE) && (bsel & 0x2000))
	        continue;

	    for (ent = 0; ent <= 0xfe0; ent += 0x20, i++)
	        {
	        UINT32 tag = *(UINT32 *)(DCACHE_ADRS_ARRAY |
		                         way | bsel | ent);
	        UINT32 dt;
	        UINT32 mask = (ccr & CCR_OC_RAM_ENABLE) ? 0x2c00 : 0x3c00;

		dt =  ((tag ^ (way | bsel | ent)) & mask) ? 0x4 : 0x0;

	        a[i + (way >> 14)*511][0] = (tag & 0xfffffc03) | (ent & 0x3e0) | dt;

	        for (j = 1, k = 0; j <= 8; j++, k += 0x4)
		    a[i + (way >> 14)*511][j] = *(UINT32 *)(DCACHE_DATA_ARRAY |
		                          way | bsel | ent | k);
	        }
	    }
          }
        }
    else
        {
        for (i = 0, bsel = 0; bsel <= 0x3000; bsel += 0x1000)
	    {
	    if ((ccr & CCR_OC_RAM_ENABLE) && (bsel & 0x1000))
	        continue;

	    for (ent = 0; ent <= 0xfe0; ent += 0x20, i++)
	        {
	        UINT32 tag = *(UINT32 *)(DCACHE_ADRS_ARRAY | bsel | ent);
	        UINT32 dt;
	        UINT32 mask = (ccr & CCR_OC_RAM_ENABLE) ? 0x2c00 : 0x3c00;

	        if ( ccr & CCR_OC_INDEX_ENABLE )
		    {
		    dt = (((tag ^ (ent << 12)) & 0x02000000) ||
		          ((tag ^ (bsel | ent)) & mask & 0x1fff)) ? 0x4 : 0x0;
		    }
	        else
		    dt =  ((tag ^ (bsel | ent)) & mask) ? 0x4 : 0x0;

	        a[i][0] = (tag & 0xfffffc03) | (ent & 0x3e0) | dt;

	        for (j = 1, k = 0; j <= 8; j++, k += 0x4)
		    a[i][j] = *(UINT32 *)(DCACHE_DATA_ARRAY | bsel | ent | k);
	        }
	    }
        }

    }

LOCAL void cacheSh7750IDisp (UINT32 a[][9], UINT32 ccr)
    {
    int i;
    int lines = 256;		/* cache lines */


    if ( ccr & CCR_2WAY_EMODE )
        { 
#ifdef DISPLAY_CACHE_SORTED
        quick_sort (a, lines * 2);
#else	
	/* way 0 */
	printf("\t\t********  Way  0 ************\n");
#endif	
        for (i = 0; i < lines; i++)
	    {
	    printf ("0x%08x: %08x %08x %08x %08x %08x %08x %08x %08x %s %s\n",
		    a[i][0] & 0xfffffff0,
		    a[i][1], a[i][2], a[i][3], a[i][4],
  		    a[i][5], a[i][6], a[i][7], a[i][8],
		    a[i][0] & 0x4 ? "!"  : " ",
		    a[i][0] & 0x1 ? "V+" : "V-");
	    }

#ifndef DISPLAY_CACHE_SORTED	
	/* way 1 */
	printf("\t\t********  Way  1 ************\n");
#endif	
        for (i = lines; i < lines * 2; i++)
	    {
	    printf ("0x%08x: %08x %08x %08x %08x %08x %08x %08x %08x %s %s\n",
		    a[i][0] & 0xfffffff0,
		    a[i][1], a[i][2], a[i][3], a[i][4],
  		    a[i][5], a[i][6], a[i][7], a[i][8],
		    a[i][0] & 0x4 ? "!"  : " ",
		    a[i][0] & 0x1 ? "V+" : "V-");
	    }
        }
    else
        {
#ifdef DISPLAY_CACHE_SORTED	
        quick_sort (a, lines);
#endif
	
        for (i = 0; i < lines; i++)
	    {
	    printf ("0x%08x: %08x %08x %08x %08x %08x %08x %08x %08x %s %s\n",
		    a[i][0] & 0xfffffff0,
		    a[i][1], a[i][2], a[i][3], a[i][4],
  		    a[i][5], a[i][6], a[i][7], a[i][8],
		    a[i][0] & 0x4 ? "!"  : " ",
		    a[i][0] & 0x1 ? "V+" : "V-");
	    }

         }
    }

LOCAL void cacheSh7750DDisp (UINT32 a[][9], UINT32 ccr)
    {
    int i;
    int lines = (ccr & CCR_OC_RAM_ENABLE) ? 256 : 512;	/* cache lines */

    if ( ccr & CCR_2WAY_EMODE )
        {
#ifdef DISPLAY_CACHE_SORTED
        quick_sort (a, lines * 2);
#else
	/* way 0 */
	printf("\t\t********  Way  0 ************\n");
#endif	
	for (i = 0; i < lines; i++)
	    {
	    printf ("0x%08x: %08x %08x %08x %08x %08x %08x %08x %08x %s %s %s\n",
		    a[i][0] & 0xfffffff0,
		    a[i][1], a[i][2], a[i][3], a[i][4],
		    a[i][5], a[i][6], a[i][7], a[i][8],
		    a[i][0] & 0x4 ? "!"  : " ",
		    a[i][0] & 0x2 ? "U+" : "U-",
		    a[i][0] & 0x1 ? "V+" : "V-");
	    }

#ifndef DISPLAY_CACHE_SORTED
	/* way 1 */
	printf("\t\t********  Way  1 ************\n");
#endif	
        for (i = lines; i < lines * 2; i++)
	    {
	    printf ("0x%08x: %08x %08x %08x %08x %08x %08x %08x %08x %s %s %s\n",
		    a[i][0] & 0xfffffff0,
		    a[i][1], a[i][2], a[i][3], a[i][4],
		    a[i][5], a[i][6], a[i][7], a[i][8],
		    a[i][0] & 0x4 ? "!"  : " ",
		    a[i][0] & 0x2 ? "U+" : "U-",
		    a[i][0] & 0x1 ? "V+" : "V-");
	    }
        }
    else
        {
#ifdef DISPLAY_CACHE_SORTED
        quick_sort (a, lines);
#endif
        for (i = 0; i < lines; i++)
	    {
	    printf("0x%08x: %08x %08x %08x %08x %08x %08x %08x %08x %s %s %s\n",
		    a[i][0] & 0xfffffff0,
		    a[i][1], a[i][2], a[i][3], a[i][4],
		    a[i][5], a[i][6], a[i][7], a[i][8],
		    a[i][0] & 0x4 ? "!"  : " ",
		    a[i][0] & 0x2 ? "U+" : "U-",
		    a[i][0] & 0x1 ? "V+" : "V-");
	    }
	}
    }

#define OP_NONE		0
#define OP_FLUSH	1
#define OP_CLEAR	2
#define OP_INVALIDATE	3

STATUS cacheSh7750Test (CACHE_TYPE cache, int addr, int bytes, int op)
    {
    STATUS status = OK;
    int key;
    UINT32 ccr = cacheSh7750CCRGet ();
    UINT32 (*a)[512][9] =
	(UINT32(*)[512][9])(((UINT32)va & SH7750_PHYS_MASK) | SH7750_P2_BASE);
    UINT32 (*ea)[1024][9] =
	(UINT32(*)[1024][9])(((UINT32)eva & SH7750_PHYS_MASK) | SH7750_P2_BASE);
    UINT32 pDumpRtn;

    if (cache == INSTRUCTION_CACHE)
	pDumpRtn = (UINT32)cacheSh7750IDumpOp;
    else
	pDumpRtn = (UINT32)cacheSh7750DDumpOp;

    pDumpRtn = (pDumpRtn & SH7750_PHYS_MASK) | SH7750_P2_BASE;

    key = intLock ();					/* LOCK INTERRUPTS */

    switch (op)
	{
	case OP_FLUSH:
	    status = cacheSh7750Flush (cache, (void *)addr, bytes); break;
	case OP_CLEAR:
	    status = cacheSh7750Clear (cache, (void *)addr, bytes); break;
	case OP_INVALIDATE:
	    status = cacheSh7750Invalidate (cache, (void *)addr, bytes); break;
	default:
	    status = ERROR;
	case OP_NONE:
	}

    if ( ccr & CCR_2WAY_EMODE )
	(* (VOIDFUNCPTR)pDumpRtn)(*ea, ccr);
    else
        (* (VOIDFUNCPTR)pDumpRtn)(*a, ccr);

    intUnlock (key);					/* UNLOCK INTERRUPTS */

    if (cache == INSTRUCTION_CACHE)
        if ( ccr & CCR_2WAY_EMODE )
            cacheSh7750IDisp (*ea, ccr);
	else  
            cacheSh7750IDisp (*a, ccr);
    else
        if ( ccr & CCR_2WAY_EMODE )
	    cacheSh7750DDisp (*ea, ccr);
	else
	    cacheSh7750DDisp (*a, ccr);

    return status;
    }

STATUS cacheSh7750ICTest (int op)
    {    
    STATUS status = OK;
    int key;
    UINT32 ccr = cacheSh7750CCRGet ();
    UINT32 (*a)[256][9] =
	(UINT32(*)[256][9])(((UINT32)sva & SH7750_PHYS_MASK) | SH7750_P2_BASE);
    UINT32 (*ea)[512][9] =
	(UINT32(*)[512][9])(((UINT32)seva & SH7750_PHYS_MASK) | SH7750_P2_BASE);
    UINT32 pDumpRtn;

        
    pDumpRtn = (UINT32)cacheSh7750IDumpOp;

    pDumpRtn = (pDumpRtn & SH7750_PHYS_MASK) | SH7750_P2_BASE;

    key = intLock ();					/* LOCK INTERRUPTS */


    if ( ccr & CCR_2WAY_EMODE )
        {	
	switch (op)
	  {
	  case OP_FLUSH:
	    status = cacheSh7750Flush (0, 0, ENTIRE_CACHE); break;
	  case OP_CLEAR:
	    status = cacheSh7750Clear (0, 0, ENTIRE_CACHE); break;
	  case OP_INVALIDATE:
	    status = cacheSh7750Invalidate (0, 0, ENTIRE_CACHE); break;
	  default:
	    status = ERROR;
	  case OP_NONE:
	  }
	(* (VOIDFUNCPTR)pDumpRtn)(*ea, ccr);
	}
    else
        {
	switch (op)
	  {
	  case OP_FLUSH:
	    status = cacheSh7750Flush (0, 0, ENTIRE_CACHE); break;
	  case OP_CLEAR:
	    status = cacheSh7750Clear (0, 0, ENTIRE_CACHE); break;
	  case OP_INVALIDATE:
	    status = cacheSh7750Invalidate (0, 0, ENTIRE_CACHE); break;
	  default:
	    status = ERROR;
	  case OP_NONE:
	  }	
        (* (VOIDFUNCPTR)pDumpRtn)(*a, ccr);
	}

    intUnlock (key);					/* UNLOCK INTERRUPTS */

    if ( ccr & CCR_2WAY_EMODE )
      cacheSh7750IDisp (*ea, ccr);
    else  
      cacheSh7750IDisp (*a, ccr);	

    return status;
    }

STATUS cacheSh7750OCTest (int op)
    {    
    STATUS status = OK;
    int key;
    UINT32 ccr = cacheSh7750CCRGet ();
    UINT32 (*a)[512][9] =
	(UINT32(*)[512][9])(((UINT32)va & SH7750_PHYS_MASK) | SH7750_P2_BASE);
    UINT32 (*ea)[1024][9] =
	(UINT32(*)[1024][9])(((UINT32)eva & SH7750_PHYS_MASK) | SH7750_P2_BASE);
    UINT32 pDumpRtn;

        
    pDumpRtn = (UINT32)cacheSh7750DDumpOp;

    pDumpRtn = (pDumpRtn & SH7750_PHYS_MASK) | SH7750_P2_BASE;

    key = intLock ();					/* LOCK INTERRUPTS */


    if ( ccr & CCR_2WAY_EMODE )
        {	
	switch (op)
	  {
	  case OP_FLUSH:
	    status = cacheSh7750Flush (1, 0, ENTIRE_CACHE); break;
	  case OP_CLEAR:
	    status = cacheSh7750Clear (1, 0, ENTIRE_CACHE); break;
	  case OP_INVALIDATE:
	    status = cacheSh7750Invalidate (1, 0, ENTIRE_CACHE); break;
	  default:
	    status = ERROR;
	  case OP_NONE:
	  }
	(* (VOIDFUNCPTR)pDumpRtn)(*ea, ccr);
	}
    else
        {
	switch (op)
	  {
	  case OP_FLUSH:
	    status = cacheSh7750Flush (1, 0, ENTIRE_CACHE); break;
	  case OP_CLEAR:
	    status = cacheSh7750Clear (1, 0, ENTIRE_CACHE); break;
	  case OP_INVALIDATE:
	    status = cacheSh7750Invalidate (1, 0, ENTIRE_CACHE); break;
	  default:
	    status = ERROR;
	  case OP_NONE:
	  }	
        (* (VOIDFUNCPTR)pDumpRtn)(*a, ccr);
	}

    intUnlock (key);					/* UNLOCK INTERRUPTS */

    if ( ccr & CCR_2WAY_EMODE )
      cacheSh7750DDisp (*ea, ccr);
    else  
      cacheSh7750DDisp (*a, ccr);	

    return status;
    }

STATUS cacheSh7750FlushTestAll (CACHE_TYPE cache)
    {
    return cacheSh7750Test (cache, 0, ENTIRE_CACHE, OP_FLUSH);
    }

STATUS cacheSh7750ClearTestAll (CACHE_TYPE cache)
    {
    return cacheSh7750Test (cache, 0, ENTIRE_CACHE, OP_CLEAR);
    }

STATUS cacheSh7750InvalidateTestAll (CACHE_TYPE cache)
    {
    return cacheSh7750Test (cache, 0, ENTIRE_CACHE, OP_INVALIDATE);
    }


#define TEST_BUF_SIZE	128

/******************************************************************************
*
* cacheSh7750Test2 - demonstrate cache flush/invalidate/clear differences
*
* NOMANUAL
*/

void cacheSh7750Test2 (void)
    {
    void *buf = malloc (TEST_BUF_SIZE);
    char *vp = (char *)buf;
    char *pp = (char *)(((UINT32)buf & SH7750_PHYS_MASK) | SH7750_P2_BASE);

    /* FLUSH */
    printf("\n\n\t\tCACHE FLUSH TEST\n\n");
    
    strcpy (pp, "1st message in physical memory.");
    strcpy (vp, "This is a cached message.      ");
    printf ("WRITE P0 & P2---> P0: %s P2: %s\n", vp, pp);
    cacheFlush (DATA_CACHE, vp, TEST_BUF_SIZE);
    printf ("FLUSH BY OCBWB--> P0: %s P2: %s\n", vp, pp);
    cacheFlush (DATA_CACHE, vp, TEST_BUF_SIZE);
    strcpy (pp, "2nd message in physical memory.");
    printf ("WRITE P2--------> P0: %s P2: %s\n", vp, pp);
    printf ("\n");

    strcpy (pp, "1st message in physical memory.");
    strcpy (vp, "This is a cached message.      ");
    printf ("WRITE P0 & P2---> P0: %s P2: %s\n", vp, pp);
    cacheFlush (DATA_CACHE, vp, ENTIRE_CACHE);
    printf ("FLUSH ALL TAGS--> P0: %s P2: %s\n", vp, pp);
    cacheFlush (DATA_CACHE, vp, ENTIRE_CACHE);
    strcpy (pp, "2nd message in physical memory.");
    printf ("WRITE P2--------> P0: %s P2: %s\n", vp, pp);
    printf ("\n");

    strcpy (pp, "1st message in physical memory.");
    strcpy (vp, "This is a cached message.      ");
    printf ("WRITE P0 & P2---> P0: %s P2: %s\n", vp, pp);
    cacheFlush (DATA_CACHE, vp, 0x100001);
    printf ("FLUSH TAG BY RMW> P0: %s P2: %s\n", vp, pp);
    cacheFlush (DATA_CACHE, vp, 0x100001);
    strcpy (pp, "2nd message in physical memory.");
    printf ("WRITE P2--------> P0: %s P2: %s\n", vp, pp);
    printf ("\n");

    /* INVALIDATE */
    printf("\n\n\t\tCACHE INVALIDATE TEST\n\n");    

    strcpy (pp, "1st message in physical memory.");
    strcpy (vp, "This is a cached message.      ");
    printf ("WRITE P0 & P2-----> P0: %s P2: %s\n", vp, pp);
    cacheInvalidate (DATA_CACHE, vp, TEST_BUF_SIZE);
    printf ("INVALIDATE BY OCBI> P0: %s P2: %s\n", vp, pp);
    cacheInvalidate (DATA_CACHE, vp, TEST_BUF_SIZE);
    strcpy (pp, "2nd message in physical memory.");
    printf ("WRITE P2----------> P0: %s P2: %s\n", vp, pp);
    printf ("\n");

    strcpy (pp, "1st message in physical memory.");
    strcpy (vp, "This is a cached message.      ");
    printf ("WRITE P0 & P2-----> P0: %s P2: %s\n", vp, pp);
    cacheInvalidate (DATA_CACHE, vp, ENTIRE_CACHE);
    printf ("INVALIDATE ALL TAG> P0: %s P2: %s\n", vp, pp);
    cacheInvalidate (DATA_CACHE, vp, ENTIRE_CACHE);
    strcpy (pp, "2nd message in physical memory.");
    printf ("WRITE P2----------> P0: %s P2: %s\n", vp, pp);
    printf ("\n");

    strcpy (pp, "1st message in physical memory.");
    strcpy (vp, "This is a cached message.      ");
    printf ("WRITE P0 & P2-----> P0: %s P2: %s\n", vp, pp);
    cacheInvalidate (DATA_CACHE, vp, 0x100001);
    printf ("INVALIDATE BY RMW-> P0: %s P2: %s\n", vp, pp);
    cacheInvalidate (DATA_CACHE, vp, 0x100001);
    strcpy (pp, "2nd message in physical memory.");
    printf ("WRITE P2----------> P0: %s P2: %s\n", vp, pp);
    printf ("\n");

    /* CLEAR */
    printf("\n\n\t\tCACHE CLEAR TEST\n\n");    

    strcpy (pp, "1st message in physical memory.");
    strcpy (vp, "This is a cached message.      ");
    printf ("WRITE P0 & P2---> P0: %s P2: %s\n", vp, pp);
    cacheClear (DATA_CACHE, vp, TEST_BUF_SIZE);
    printf ("CLEAR BY OCBP---> P0: %s P2: %s\n", vp, pp);
    cacheClear (DATA_CACHE, vp, TEST_BUF_SIZE);
    strcpy (pp, "2nd message in physical memory.");
    printf ("WRITE P2--------> P0: %s P2: %s\n", vp, pp);
    printf ("\n");

    strcpy (pp, "1st message in physical memory.");
    strcpy (vp, "This is a cached message.      ");
    printf ("WRITE P0 & P2---> P0: %s P2: %s\n", vp, pp);
    cacheClear (DATA_CACHE, vp, ENTIRE_CACHE);
    printf ("CLEAR ALL TAGS--> P0: %s P2: %s\n", vp, pp);
    cacheClear (DATA_CACHE, vp, ENTIRE_CACHE);
    strcpy (pp, "2nd message in physical memory.");
    printf ("WRITE P2--------> P0: %s P2: %s\n", vp, pp);
    printf ("\n");

    strcpy (pp, "1st message in physical memory.");
    strcpy (vp, "This is a cached message.      ");
    printf ("WRITE P0 & P2---> P0: %s P2: %s\n", vp, pp);
    cacheClear (DATA_CACHE, vp, 0x100001);
    printf ("CLEAR TAG BY RMW> P0: %s P2: %s\n", vp, pp);
    cacheClear (DATA_CACHE, vp, 0x100001);
    strcpy (pp, "2nd message in physical memory.");
    printf ("WRITE P2--------> P0: %s P2: %s\n", vp, pp);
    printf ("\n");

    free (buf);
    }

/******************************************************************************
*
* cacheSh7750Test3 - test cacheSh7750TextUpdate functionality
*
* NOMANUAL
*/

STATUS cacheSh7750Test3 (BOOL update)
    {
    USHORT text1 [] = { 0x000b, 0xe0ff };	/* rts; mov #-1,r0 */
    USHORT text2 [] = { 0x000b, 0xe000 };	/* rts; mov #0, r0 */

    USHORT *pCode = (USHORT *)memalign (_CACHE_ALIGN_SIZE, TEST_BUF_SIZE);

    bcopy ((char *)text1, (char *)pCode, sizeof (text1));

    cacheLib.textUpdateRtn (pCode, sizeof (text1));

    bcopy ((char *)text2, (char *)pCode, sizeof (text2));

    if (update)
	cacheLib.textUpdateRtn (pCode, sizeof (text2));

    return (* (FUNCPTR)pCode)();
    }

/******************************************************************************
*
* cacheSh7750Test4 - test write-back buffer synchronization by P2-read
*
* NOMANUAL
*/

void cacheSh7750Test4 (BOOL clear)
    {
    IMPORT int cacheSh7750SyncTest (BOOL clear, char *p0, char *p2);

    void *buf = malloc (TEST_BUF_SIZE);
    char *p0 = (char *)buf;
    char *p2 = (char *)(((UINT32)buf & SH7750_PHYS_MASK) | SH7750_P2_BASE);
    char mem;

    *p2 = 'm';
    *p0 = 'c';

    mem = cacheSh7750SyncTest (clear, p0, p2);

    printf ("cache: %c, memory: %c\n", *p0, mem);

    free (buf);
    }

__asm__ ("
	.global	_cacheSh7750SyncTest
	.type	_cacheSh7750SyncTest,@function
	.align	5
_cacheSh7750SyncTest:
	tst	r4,r4
	bt	.+4
	ocbp	@r5		! flush and invalidate cache entry
	mov.b	@r6,r0		! read P2 immediately
	rts;
	nop
");

/******************************************************************************
*
* cacheSh7750Test5 - test associative I-cache invalidation with MMU enabled
*
* This routine is currently written for big-endian only.
*
* NOMANUAL
*/

int cacheSh7750Test5
    (
    int  method,  /* 0: simple, 1: refill I-TLB, 2: invalidate whole I-cache */
    BOOL noPurge, /* 0: purge I-TLB prior to invalidate, 1: no-purge */
    int  repeat   /* times to repeat */
    )
    {
    int i, j, purgeCount;
    STATUS invalResult, testResult = ERROR;
    UINT32 ccr = cacheSh7750CCRGet ();
    int pageSize = VM_PAGE_SIZE_GET ();
    int cacheSize = (ccr & CCR_2WAY_EMODE) ? 16384 : 8192;

    /* allocate page aligned memories for testing */

    USHORT *hop     = (USHORT *)memalign (pageSize, 6*2);
    USHORT *step    = (USHORT *)memalign (pageSize, 6*2);
    USHORT *jump    = (USHORT *)memalign (pageSize, 6*2);
    USHORT *landing = (USHORT *)memalign (pageSize, 3*2);
    USHORT *test    = (USHORT *)memalign (pageSize, cacheSize);

    if (repeat <= 0 ) repeat = 1;
    else if (repeat > cacheSize/4) repeat = cacheSize/4;

    printf ("pageSize: %d, cacheSize: %d, repeat: %d\n",
		pageSize, cacheSize, repeat);
    printf ("hop: %x, step: %x, jump: %x, landing: %x, test: %x\n",
		(int)hop, (int)step, (int)jump, (int)landing, (int)test);

    /* setup 4 page jumping code to refill I-TLB with new entries */

    hop[0] = 0xd001;					/* mov.l  .+8,r0 */
    hop[1] = 0x402b;					/* jmp    @r0    */
    hop[2] = 0x7401;					/* add    #1,r4  */
    hop[3] = 0x0009;					/* nop           */
    hop[4] = (USHORT)(((int)step & 0xffff0000) >> 16);	/* .long  step   */
    hop[5] = (USHORT)( (int)step & 0x0000ffff);		/*               */
    cacheSh7750DFlush ((void *)hop, 12);
    step[0] = 0xd001;					/* mov.l  .+8,r0 */
    step[1] = 0x402b;					/* jmp    @r0    */
    step[2] = 0x7401;					/* add    #1,r4  */
    step[3] = 0x0009;					/* nop           */
    step[4] = (USHORT)(((int)jump & 0xffff0000) >> 16);	/* .long  jump   */
    step[5] = (USHORT)( (int)jump & 0x0000ffff);	/*               */
    cacheSh7750DFlush ((void *)step, 12);
    jump[0] = 0xd001;					/* mov.l  .+8,r0 */
    jump[1] = 0x402b;					/* jmp    @r0    */
    jump[2] = 0x7401;					/* add    #1,r4  */
    jump[3] = 0x0009;					/* nop           */
    jump[4] = (USHORT)(((int)landing & 0xffff0000)>>16);/* .long  landing*/
    jump[5] = (USHORT)( (int)landing & 0x0000ffff);	/*               */
    cacheSh7750DFlush ((void *)jump, 12);
    landing[0] = 0x7401;				/* add    #1,r4  */
    landing[1] = 0x000b;				/* rts           */
    landing[2] = 0x6043;				/* mov    r4,r0  */
    cacheSh7750DFlush ((void *)landing, 6);

    /* setup test codes which return ERROR */

    for (i = 0; i < cacheSize/2; i += 2)
	{
	test[i]   = 0x000b;	/* rts           */
	test[i+1] = 0xe0ff;	/* mov    #-1,r0 */
	}
    cacheSh7750DFlush ((void *)test, cacheSize);

    cacheSh7750CCRSet (ccr | CCR_IC_INVALIDATE); /* invalidate whole I-cache */

    for (i = 0, j = 0; j < repeat; i += 2, j++)
	{
	/* load test code to I-cache (I-TLB mapping is loaded too) */

	(* (FUNCPTR)&test[i])();			/* just execute it */

	/* modify test code on memory to return OK */

	test[i+1] = 0xe000;			/* put 'mov #0,r0' on D-cache */
	cacheSh7750DFlush ((void *)&test[i+1], 2);	/* push out to memory */

	/* purge test code mapping on I-TLB (skip if noPurge) */

	purgeCount = noPurge ? 0 : (* (FUNCPTR)hop)(0);	/* purge whole I-TLB */

	/* Now 'return OK' code sits on memory, but 'return ERROR' would
	 * probably stay on I-cache.  We should be able to execute 'return OK'
	 * after invalidating the 'return ERROR' on I-cache.
	 */
	if (method == 0)
	    {
	    /* I-TLB mishit voids this associative I-cache invalidation */

	    invalResult = cacheSh7750IInvalidate ((void *)&test[i+1], 2);
	    }
	else if (method == 1)
	    {
	    /* refill I-TLB before associative I-cache invalidation */

	    invalResult = cacheSh7750ILineInvalidate ((void *)&test[i+1]);
	    }
	else if (method == 2)
	    {
	    /* invalidate whole I-cache, it works but inefficient */

	    invalResult = cacheSh7750CCRSet (ccr | CCR_IC_INVALIDATE);
	    }
	else
	    invalResult = ERROR;

	/* execute the modified test code, this should return OK */

	testResult = (* (FUNCPTR)&test[i])();

	/* revert test code to return ERROR */

	test[i+1] = 0xe0ff;			/* put 'mov #-1,r0' on D-cache*/
	cacheSh7750DFlush ((void *)&test[i+1], 2);	/* push out to memory */

	/* dump results */

	printf
	    ("%d: I-TLB purge: %d, I-cache invalidate: %#x, Test result: %s\n",
	     j, purgeCount, invalResult, testResult ? "FAILED" : "PASSED");
	}

    free (test);
    free (landing);
    free (jump);
    free (step);
    free (hop);

    return testResult;
    }

#endif /* CACHE_DEBUG */
