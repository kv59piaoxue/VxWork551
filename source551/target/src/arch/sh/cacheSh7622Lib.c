/* cacheSh7622Lib.c - SH7622 cache management library */

/* Copyright 1994-2000 Wind River Systems, Inc. */
#include "copyright_wrs.h"

/*
modification history
--------------------
01d,24oct01,zl   fixes for doc builds.
01c,02may01,frf  disabled cache on cacheSh7622LibInit.
01b,11apr01,frf  modified cacheSh7622Clear function.
01a,25dec01,frf  written on cacheSh7604Lib base.
*/

/*
DESCRIPTION
This library contains architecture-specific cache library functions for
the Hitachi SH7622 instruction and data caches. 

INTERNAL
The cache enable and disable processes consist of the following actions,
executed by cacheSh7622Enable() and cacheSh7622Disable(). 

For general information about caching, see the manual entry for cacheLib.

INCLUDE FILES: cacheLib.h

SEE ALSO: cacheLib

INTERNAL
	< SH7622 cache programming model >
      
	0xf0000000:	cache address array
	0xf1000000:	cache data array


	< SH7622 CCR (Cache Control Register) >


	         31        6    5    4    3    2    1    0
    		+---+-...+---+----+----+----+----+----+----+
 0xffffffec:	| - |    | - | 0  | 0  | CF | CB | WT | CE |
       		+---+-...+---+----+----+----+----+----+----+
		                         /     |     \   \__ cache enable
                                        /      |      \
                                    cache   cache      \_ write through 
			            flush   write-back     in P0,U0,P3
				            in P1

CF : Writing 1 flushes all the cahe entrie (clears the U,V and LRU
     table). Always read 0.

CB : Indicates the cache's operating mode in area P1.
     1 = write back mode, 0 = write through mode.

WT : Indicates the cache's operating mode in area P0,U0 and P3.
     1 =  write through mode, 0 = write back mode.

CE : Cache enabled.				    
*/

#include "vxWorks.h"
#include "errnoLib.h"
#include "cacheLib.h"
#include "intLib.h"		/* for intLock()/intUnlock() */
#include "memLib.h"		/* for memalign() */
#include "stdlib.h"		/* for malloc() and free() */
#include "string.h"		/* for bzero() */

/* imports */

IMPORT UINT32 cacheSh7622CCRSetOp (UINT32 ccr);
IMPORT UINT32 cacheSh7622CCRGet (void);
IMPORT STATUS cacheSh7622CacheOnOp (BOOL on);
IMPORT void cacheSh7622CFlushOp (void);
IMPORT void cacheSh7622AFlushOp (UINT32 ca_begin, UINT32 ca_end);
IMPORT void cacheSh7622MFlushOp (UINT32 *pt, int ix,
					UINT32 ca_begin, UINT32 ca_end);

/* local definitions */

#define CCR		((volatile UINT8 *)0xffffffec)
#define CCR_KEY		0xffffffcf /* 4^  and 5^ bit to 0 when
				      modifying CCR */

#define MAX_CACHEABLE_ADRS	0xf0ffffff	/* 128 Mbytes */
#define CAC_ADRS_ARRAY 	0xf0000000
#define CAC_ADRS_SIZE  	0x01000000

#define CAC_DATA_ARRAY 	0xf1000000
#define CAC_DATA_SIZE 	0x01000000
#define CAC_LINE_SIZE  	16

/* SH7622 Cache Control Register bit define */
#define C_ENABLE    	0x00000001	/* enable cache */
#define C_WRITE_THROUGH	0x00000002	/* operating mode for area P0
					   U0 and P3
					   1:write-through
					   0:write-back */
#define C_WRITE_BACK   	0x00000004	/* operating mode for area P1
					   1:write-back
					   0:write-through */
#define C_FLUSH	   	0x00000008	/* flushes all cache entries
					   (clears V,U and LRU bits) */

/* SH7622 Cache line Adrress Array bit define */
#define CAC_A_BIT 	0x00000008     	/* comparing address  */
#define CAC_ENTRY	0x000003f0	/* mask for the entry */
#define CAC_WAY		0x00000c00	/* mask for way */
#define CAC_ADDR	0xf0000000	/* mask for addrs */
#define CAC_LRU		0x000003f0	/* mask for LRU */
#define CAC_A		0x00000008	/* mask for A bit */
#define CAC_U		0x00000002	/* mask for U bit */
#define CAC_V 		0x00000001	/* mask for V bit */
/* SH7622 Cache line Data Array bit define */
#define CDC_ADDR	0xf1000000	/* mask for addrs */
#define CDC_ENTRY	0x000003f0	/* mask for the entry */
#define CDC_WAY		0x00000c00	/* mask for way */
#define CDC_L		0x0000000c	/* mask for longs */

/* forward declarations */

LOCAL STATUS cacheSh7622Enable (CACHE_TYPE cache);
LOCAL STATUS cacheSh7622Disable (CACHE_TYPE cache);
LOCAL STATUS cacheSh7622Clear (CACHE_TYPE cache, void *from, size_t bytes);
LOCAL STATUS cacheSh7622Invalidate (CACHE_TYPE cache, void *from, size_t bytes);
LOCAL void *cacheSh7622DmaMalloc (size_t bytes);
LOCAL STATUS cacheSh7622DmaFree (void *pBuf);

/* These must be .data, .bss will be cleared */

LOCAL FUNCPTR     cacheSh7622CCRSet  = (FUNCPTR)0x1234;
LOCAL FUNCPTR     cacheSh7622CacheOn = (FUNCPTR)0x5678;
LOCAL VOIDFUNCPTR cacheSh7622CFlush  = (VOIDFUNCPTR)0x1234;
LOCAL VOIDFUNCPTR cacheSh7622AFlush  = (VOIDFUNCPTR)0x1234;
LOCAL VOIDFUNCPTR cacheSh7622MFlush  = (VOIDFUNCPTR)0x1234;

/*******************************************************************************
*
* cacheSh7622LibInit - initialize the SH7622 cache library
* 
* This routine initializes the cache library for the Hitachi SH7622 processor.
* It initializes the function pointers and configures the caches to the
* specified cache modes.  Modes should be set before caching is enabled.
* If two complementary flags are set (enable/disable), no action is taken
* for any of the input flags. Data cache and istruction cache are
* mixed together in the SH7622.
*
* Next caching modes are available for the SH7622 processor:
*
* .TS
* tab(|);
* l l l l.
* | SH7622:| CACHE_WRITETHROUGH | (cache for instruction and data)
* |        | CACHE_COPYBACK_P1  | (write-back cache for P1)
* .TE
* 
* RETURNS: OK, or ERROR if the specified caching modes were invalid.
*/

STATUS cacheSh7622LibInit
    (
    CACHE_MODE	instMode,	/* instruction cache mode */
    CACHE_MODE	dataMode	/* data cache mode */
    )
    {
    /* setup function pointers for cache library (declared in funcBind.c) */

    cacheLib.enableRtn          = cacheSh7622Enable;
    cacheLib.disableRtn         = cacheSh7622Disable;

    cacheLib.lockRtn            = NULL;
    cacheLib.unlockRtn          = NULL;

    /* Flush and invalidate are the same in COPYBACK mode.  Setting the flush
     * bit in the CCR doesn't do a write-back, so call cacheSh7622Clear if
     * using COPYBACK (write-back) mode.
     */
    if (dataMode & (CACHE_COPYBACK_P1))
	{
	cacheLib.flushRtn	= cacheSh7622Clear;
	cacheLib.invalidateRtn	= cacheSh7622Clear;
	}
    else
	{
	cacheLib.flushRtn	= NULL;
	cacheLib.invalidateRtn	= cacheSh7622Invalidate;
	}

    cacheLib.clearRtn           = cacheSh7622Clear;

    cacheLib.textUpdateRtn      = NULL;		/* inst/data mixed cache */
    cacheLib.pipeFlushRtn       = NULL;

    /* setup P2 function pointers for cache sensitive operations */

    cacheSh7622CCRSet		= (FUNCPTR)(((UINT32)cacheSh7622CCRSetOp
				& SH7622_PHYS_MASK) | SH7622_CACHE_THRU);
    cacheSh7622CacheOn		= (FUNCPTR)(((UINT32)cacheSh7622CacheOnOp
				& SH7622_PHYS_MASK) | SH7622_CACHE_THRU);    
    cacheSh7622CFlush		= (VOIDFUNCPTR)(((UINT32)cacheSh7622CFlushOp
     				& SH7622_PHYS_MASK) | SH7622_CACHE_THRU);
    cacheSh7622AFlush		= (VOIDFUNCPTR)(((UINT32)cacheSh7622AFlushOp
     				& SH7622_PHYS_MASK) | SH7622_CACHE_THRU);
    cacheSh7622MFlush     	= (VOIDFUNCPTR)(((UINT32)cacheSh7622MFlushOp
    				& SH7622_PHYS_MASK) | SH7622_CACHE_THRU);

    /* select cache-safe malloc/free routines for DMA buffer */
   
    cacheLib.dmaMallocRtn   = (FUNCPTR)cacheSh7622DmaMalloc;
    cacheLib.dmaFreeRtn     = cacheSh7622DmaFree;

    cacheLib.dmaVirtToPhysRtn	= NULL;
    cacheLib.dmaPhysToVirtRtn	= NULL;


    /* check for parameter errors */

    if ( dataMode & ~(CACHE_WRITETHROUGH | CACHE_COPYBACK_P1) )
	{
	errnoSet (S_cacheLib_INVALID_CACHE);
	return ERROR;
	}

    /* initialize cache modes (declared in cacheLib.c)
     *
     * The "cacheMmuAvailable" controls the flow of cacheFuncsSet() routine.
     * The cacheFuncsSet() is called upon turning of/off data caching, and it
     * assumes DMA buffers cannot be made non-cacheable without MMU.  SH7622
     * does not have MMU, but it can get non-cacheable buffers from cache-
     * through address space.  Hence "cacheMmuAvailable" is set to TRUE here.
     */
    cacheDataMode	= dataMode;
    cacheDataEnabled	= FALSE;
    cacheMmuAvailable	= TRUE;			/* for cacheFuncsSet() */

    /* disable cache safely */

    cacheLib.disableRtn (DATA_CACHE);

    /* initialize CCR */
        {
	UINT32 ccr = 0;

	if (dataMode & CACHE_WRITETHROUGH)
	    ccr |= C_WRITE_THROUGH;		/* write-through mode */

	if (dataMode & CACHE_COPYBACK_P1)
	    ccr |= C_WRITE_BACK;	     	/* write-back mode */

	ccr |= C_FLUSH;				/* flush cache */

	cacheSh7622CCRSet (ccr);       		/* disable cache */

	/* clear cache addrs array */
	bzero ((char *)CAC_ADRS_ARRAY, CAC_ADRS_SIZE);
	/* clear cache data array */
	bzero ((char *)CAC_DATA_ARRAY, CAC_DATA_SIZE);
	}
    return OK;
    }

/*******************************************************************************
*
* cacheSh7622Enable - enable a SH7622 cache
*
* This routine invalidates and enables the specified SH7622 cache.
*              ^^^^^^^^^^^     ^^^^^^^
* RETURNS: OK, or ERROR if the specified cache type was invalid.
*
* NOMANUAL
*/

LOCAL STATUS cacheSh7622Enable
    (
    CACHE_TYPE cache
    )
    {
    UINT32 ccr = cacheSh7622CCRGet ();
	
    if( ccr & C_ENABLE )		/* cache disabled */
      return ERROR;
      
    switch (cache)
	{
	case INSTRUCTION_CACHE:

	  cacheSh7622CacheOn (TRUE);
	  break;
	  
	case DATA_CACHE:
	    if ( cacheSh7622CacheOn (TRUE)  == OK )
		{
		cacheDataEnabled = TRUE;
		cacheFuncsSet ();	/* set cache function pointers */
		}
	    break;

	default:
	    errno = S_cacheLib_INVALID_CACHE;
	    return ERROR;
	}

    return OK;
    }

/*******************************************************************************
*
* cacheSh7622Disable - disable a SH7622 cache
*
* This routine flushes and disables the specified SH7622 cache.
*              ^^^^^^^     ^^^^^^^^
* RETURNS: OK, or ERROR if the specified cache type was invalid.
*
* NOMANUAL
*/

LOCAL STATUS cacheSh7622Disable
    (
    CACHE_TYPE cache
    )
    {
    UINT32 ccr = cacheSh7622CCRGet ();

    if ( (ccr & C_ENABLE) == 0 )
      return ERROR;

     switch (cache)
	{
	case INSTRUCTION_CACHE:

	  cacheSh7622CacheOn (FALSE);
	  break;
	  
	case DATA_CACHE:

	  if ( cacheSh7622CacheOn (FALSE) == OK )	/* flush and disable */
	    {
	    cacheDataEnabled = FALSE;
	    cacheFuncsSet ();	/* clear cache function pointers */
	    }
	  break;

	default:
	  errno = S_cacheLib_INVALID_CACHE;
	  return ERROR;
	}
   
    return OK;
    }


/*******************************************************************************
*
* cacheSh7622Invalidate - invalidate some or all entries from SH7622 cache
*
* This routine invalidates some or all entries from SH7622 cache.
*
* RETURNS: OK, or ERROR if the cache type is invalid or the cache control
* is not supported.
*
* NOMANUAL
*/

LOCAL STATUS cacheSh7622Invalidate
    (
    CACHE_TYPE cache,
    void *     from,		/* address to clear */
    size_t     bytes
    )
    {
    if (bytes == ENTIRE_CACHE)
	{
	UINT32 ccr = cacheSh7622CCRGet ();

	if ((ccr & (C_WRITE_BACK | C_WRITE_THROUGH)) == C_WRITE_THROUGH)
	    {
	    cacheSh7622CFlush ();
	    return OK;
	    }
	}

    return cacheSh7622Clear (cache, from, bytes);
    }

/******************************************************************************
*
* cacheSh7622Clear - clear all or some entries from a SH7622 cache
*
* This routine flushes and invalidates all or some entries of the specified
* SH7622 cache.
*
* RETURNS: OK, or ERROR if the cache type is invalid or the cache control
* is not supported.
*
* NOMANUAL
*/

LOCAL STATUS cacheSh7622Clear
    (
    CACHE_TYPE cache,
    void *     from,		/* address to clear */
    size_t     bytes
    )
    {
    UINT32 p = (UINT32)from;
    UINT32 ix;
    UINT32 c_size = CAC_DATA_SIZE;			/* cache size */
    int way;

    if (p >= SH7622_CACHE_THRU && p <= (SH7622_CACHE_THRU | SH7622_PHYS_MASK))
	return ERROR;					/* non-cacheable region */

    if (bytes == 0)
	{
	return OK;
	}
    else if (bytes == ENTIRE_CACHE)
	{
	for (way = 0; way <= 3; way++)
	    {
	    for (ix = 0; ix <= 0x7f0; ix += CAC_LINE_SIZE)
		{
		UINT32 *pt = (UINT32 *)(CAC_ADRS_ARRAY | (way << 12) | ix);

		cacheSh7622MFlush (pt, -1, 0, 0);
		}
	    }
	}
    else
	{
	UINT32 ca_begin = p & ~(CAC_LINE_SIZE - 1);
	UINT32 ca_end   = p + bytes - 1;

	if (bytes < c_size) /* do associative purge */
	    {
	    cacheSh7622AFlush (ca_begin, ca_end);
	    }
	else /* check every cache tag */
	    {
	    for (way = 0; way <= 3; way++)
		{
		for (ix = 0; ix <= 0x7f0; ix += CAC_LINE_SIZE)
		    {
		    UINT32 *pt = (UINT32 *)(CAC_ADRS_ARRAY | (way << 12) | ix);

		    cacheSh7622MFlush (pt, ix, ca_begin, ca_end);
		    }
		}
	    }
	}

    return OK;
    }

/*******************************************************************************
*
* cacheSh7622DmaMalloc - allocate a cache-safe buffer
*
* This routine attempts to return a pointer to a section of memory that will
* not experience cache coherency problems.  This routine is only called when
* MMU support is available for cache control.
*
* RETURNS: A pointer to a cache-safe buffer, or NULL.
*
* NOMANUAL
*/

LOCAL void *cacheSh7622DmaMalloc
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

    return (void *)((UINT32)pBuf | SH7622_CACHE_THRU); 
    }

/*******************************************************************************
*
* cacheSh7622DmaFree - free the buffer acquired by cacheSh7622DmaMalloc()
*
* This routine returns to the free memory pool a block of memory previously
* allocated with cacheSh7622DmaMalloc().  The buffer is marked cacheable.
*
* RETURNS: OK, or ERROR if cacheSh7622DmaMalloc() cannot be undone.
*
* NOMANUAL
*/

LOCAL STATUS cacheSh7622DmaFree
    (
    void *pBuf
    )
    {
    UINT32 t = (UINT32)pBuf;

    if (t < SH7622_CACHE_THRU || t > (SH7622_CACHE_THRU | MAX_CACHEABLE_ADRS))
	return ERROR;

    free ((void *)(t & MAX_CACHEABLE_ADRS));

    return OK;
    }

#undef CACHE_DEBUG
#ifdef CACHE_DEBUG


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

#include "stdio.h"

/*******************************************************************************
 *
 * cacheSh7622Dump - dump SH7622 cache
 *
 * This function dumps the memory associated to the cache in P4 area.
 * For debug purpose only.
 *
 * RETUNRS: N/A
 *
 * NOMANUAL
 */

void cacheSh7622Dump (void)
    {
    UINT32 a[512][5];		/* (256-entry * 4-way) * (tag[1] + data[4]) */
    int ent, i;
    int way;

    for (ent = 0; ent < 128; ent++)
	{
	int way;

	for (way = 0; way <= 3; way++)
	    {
	    UINT32 tagAddr;

	    i = (ent * 4 + way);

	    /* Get Address Array from zone P4 */

	    /* addr field */
	    tagAddr = *(UINT32 *)(CAC_ADRS_ARRAY |
				  (way << 12) | (ent << 4));
	    a[i][0] = (tagAddr & 0xfffffff3);
	    
	    /* data field */
	    a[i][1] = *(UINT32 *)(CAC_DATA_ARRAY |
				  (way << 12) | (ent << 4) | (0 << 2));
	    a[i][2] = *(UINT32 *)(CAC_DATA_ARRAY |
				  (way << 12) | (ent << 4) | (1 << 2));
	    a[i][3] = *(UINT32 *)(CAC_DATA_ARRAY |
				  (way << 12) | (ent << 4) | (2 << 2));
	    a[i][4] = *(UINT32 *)(CAC_DATA_ARRAY |
				  (way << 12) | (ent << 4) | (3 << 2));
	    }
	}

    quick_sort (a, 512);
    
    for (way = 0; way <=3; way++)
    	{
    	printf("\nway 0x%04x:\n\n",way);
    	for (i = 128*way; i < 128*(way+1); i++)
    	    {
	    printf ("0x%08x: %08x %08x %08x %08x  %s %s\n",
		    a[i][0] & 0x1ffffff0, a[i][1], a[i][2], a[i][3], a[i][4],
		    a[i][0] & CAC_V ? "V+" : "V-",
		    a[i][0] & CAC_U ? "U+" : "U-");
	    }
	}

    }

void cacheSh7622FlushAllTest (void)
    {
    UINT32 ccr;
    int key = intLock ();				/* LOCK INTERRUPTS */

    ccr = cacheSh7622CCRGet ();	    	/* save ccr */
  
    printf("\n Cache Control Register: 0x%8x\n",cacheSh7622CCRGet() );

    cacheSh7622Clear (INSTRUCTION_CACHE,0, ENTIRE_CACHE);

    cacheSh7622Dump ();
    
    printf("\n Cache Control Register: 0x%08x\n",cacheSh7622CCRGet() );

    printf("\n Cache Control Register: 0x%08x\n",cacheSh7622CCRGet() );

    /*cacheSh7622CCRSet (ccr);	    	/@ restore ccr */

    intUnlock (key);				/* UNLOCK INTERRUPTS */
    }

void cacheSh7622FlushTest()
  {
  int way;
  int ix;
  
  for (way = 0; way <= 3; way++)
    {
    for (ix = 0; ix <= 0x7f0; ix += CAC_LINE_SIZE)
      {
      UINT32 *pt = (UINT32 *)(CAC_ADRS_ARRAY | (way << 12) | ix);
      
      cacheSh7622MFlush (pt, -1, 0, 0);
      }
    }
  }

void cacheSh7622ClearTest (int addr, int bytes)
    {
    UINT32 ccr = cacheSh7622CCRGet ();	    	/* save ccr */

    cacheSh7622CCRSet (ccr & ~C_ENABLE);   	/* disable caching */

    cacheSh7622Invalidate (INSTRUCTION_CACHE, (void *)addr, bytes);

    cacheSh7622Dump ();

    cacheSh7622CCRSet (ccr);			/* RESTORE CCR */
    }

void cacheSh7622ClearTestAll ()
    {
    cacheSh7622ClearTest (0, ENTIRE_CACHE);
    }

#endif /* CACHE_DEBUG */
