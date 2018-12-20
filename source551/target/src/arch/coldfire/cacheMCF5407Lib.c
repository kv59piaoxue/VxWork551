/* cacheMCF5407Lib.c - ColdFire 5407 cache management library */

/* Copyright 1984-2000 Wind River Systems, Inc. */
#include "copyright_wrs.h"

/*
modification history
--------------------
01c,07mar03,dee  fix SPR#86341 cache problem with breakpoints
01b,02mar01,dh  Add more flexibility to cache scheme, similar to the "unified"
                 version.
01a,25oct00,dh   taken from Motorola BSP for 5407 (by Van Quache),
		 "Tornado-ised" and cleaned up
*/

/*
DESCRIPTION
The MCF5407's Harvard architecture uses separate data and instruction
caches.

INTERNAL

The MCF5407 has four access-control registers for controlling the
cache, 2 for data and 2 for instructions. In addition, the CACR
register provides default cache operations for addresses that do
not match the ranges specified in the ACRs.

It is not possible to control the cache solely with the CACR register,
because the ACRs are not sufficient to provide cache-inhibited operation
in the various external ind internal memory and I/O regions. Thus
this library has been modified from the original Motorola design.
The cache modes are set in the BSP using global variables
normalCACR and normalACR[4]. The caches are enabled and disabled
by this library using the DEC and IEC bits of CACR. In addition,
whenever the instruction cache is operated upon, the same operation
is applied to branch cache, if applicable and if the branch cache
is enabled.

Note: In the Coldfire Core: the movec instruction is unidirectional.
Control registers can be written, but not read. For this reason, we
maintain copies of these registers in memory.

See the MCF5407 Coldfire User's Manual for cache details.

For general information about caching, see the manual entry for cacheLib.

INCLUDE FILES: cacheLib.h

SEE ALSO: cacheLib, vmLib */

/* LINTLIBRARY */

#include "vxWorks.h"
#include "errnoLib.h"
#include "intLib.h"
#include "stdlib.h"
#include "cacheLib.h"
#include "private/memPartLibP.h"
#include "private/vmLibP.h"
#include "private/funcBindP.h"

/* These are the CACR bits we select for the data cache. */
#define C_CACR_DATABITS ( C_CACR_DEC | C_CACR_DW | C_CACR_DESB | \
			  C_CACR_DHLCK | C_CACR_DDCM )

/* These are the CACR bits we select for the instruction cache. */
#define C_CACR_INSTBITS ( C_CACR_BEC | C_CACR_IEC | C_CACR_DNFB | \
			  C_CACR_IHLCK | C_CACR_IDCM )
/* Note that the xCINVA and xDPI bits are NEVER selected - they are only
   set when we explicitly need to do that kind of stuff */


IMPORT ULONG	normalCACR;		/* Supplied by BSP */
IMPORT ULONG	normalACR[4];		/* Supplied by BSP */

IMPORT	void	cacheCACRSet(int);
IMPORT	void	cacheACRSet(int, int);
IMPORT	void	cacheWriteBufferFlush(void);

IMPORT	void	cacheMCF5407DataPushAll(int nlines);
IMPORT	void	cacheMCF5407DataPushLine(void* address);
IMPORT	void	cacheMCF5407InstPushAll(int nlines);
IMPORT	void	cacheMCF5407InstPushLine(void* address);

LOCAL	ULONG	currentCACR = 0;
LOCAL	ULONG	currentACR[4] = {0,0,0,0};
LOCAL	ULONG	cacheDataLineMask = 0;
LOCAL	ULONG	cacheInstLineMask = 0;
LOCAL	ULONG	cacheDataSetLength = 0;
LOCAL	ULONG	cacheInstSetLength = 0;
LOCAL	int	cacheDataLineCount = 0;
LOCAL	int	cacheInstLineCount = 0;
LOCAL	int	cacheInstEnabled = 0;

LOCAL	STATUS	cacheArchEnable(CACHE_TYPE cache);
LOCAL	STATUS	cacheArchDisable(CACHE_TYPE cache);
LOCAL	STATUS	cacheArchClear(CACHE_TYPE cache, void* address, size_t bytes);
LOCAL	STATUS	cacheArchTextUpdate(void* address, size_t bytes);
LOCAL	STATUS	cacheProbe(CACHE_TYPE cache);
LOCAL	STATUS	cacheArchFlush(cache, address, bytes);

/******************************************************************************
*
* cacheMCF5407LibInit - initialize the MCF5407 cache library
* 
* This routine initializes the cache library for Motorola ColdFire 5407
* processors.  It initializes the function pointers and configures the
* caches to the specified cache modes.  Modes should be set before caching
* is enabled.
*
* This function is called before the bss is cleared, so any variables
* assigned to must be in the data segment, or their values will be lost.
*
* RETURNS: OK.
*/
STATUS cacheMCF5407LibInit
    (
    CACHE_MODE	iMode,	/* instruction cache mode - NOT USED */
    CACHE_MODE	dMode	/* data cache mode - NOT USED */
    )
    {
    int i;

    cacheLib.enableRtn		= cacheArchEnable;
    cacheLib.disableRtn		= cacheArchDisable;
    cacheLib.lockRtn		= NULL;
    cacheLib.unlockRtn		= NULL;
    cacheLib.clearRtn		= cacheArchClear;
    cacheLib.dmaMallocRtn	= NULL;
    cacheLib.dmaFreeRtn		= NULL;
    cacheLib.dmaVirtToPhysRtn	= NULL;
    cacheLib.dmaPhysToVirtRtn	= NULL;
    cacheLib.textUpdateRtn	= cacheArchTextUpdate;
    cacheLib.flushRtn		= cacheArchFlush;
    cacheLib.invalidateRtn	= cacheArchClear;
    cacheLib.pipeFlushRtn	= (FUNCPTR)cacheWriteBufferFlush;

    cacheDataSetLength	= DATA_CACHE_SIZE / CACHE_SET_COUNT;	/* 2048 */
    cacheDataLineCount	= cacheDataSetLength / CACHE_LINE_SIZE;	/* 128 */
    cacheDataLineMask	= ((cacheDataSetLength - 1) & ~(CACHE_LINE_SIZE -1));	/* 0x07F0 */

    cacheInstSetLength	= INSTRUCTION_CACHE_SIZE / CACHE_SET_COUNT;	/* 4096 */
    cacheInstLineCount	= cacheInstSetLength / CACHE_LINE_SIZE;		/* 256 */
    cacheInstLineMask	= ((cacheInstSetLength - 1) & ~(CACHE_LINE_SIZE -1));	/* 0x0FF0 */

    /* Invalidate Data, Instruction, Branch cache */
    cacheCACRSet(C_CACR_DCINVA | C_CACR_BCINVA | C_CACR_ICINVA);

    /* Initialiase CACR and all ACRs with cache-disabled */
    currentCACR = normalCACR & ~(C_CACR_DDPI | C_CACR_IDPI |	/* dis CPUSHL */
				 C_CACR_DEC | C_CACR_DESB |	/* dis DATA */
				 C_CACR_BEC |			/* dis BRANCH */
				 C_CACR_IEC | C_CACR_DNFB );	/* dis INSTR */
    cacheCACRSet(currentCACR);
    for ( i=0; i<4; i++ )
	cacheACRSet(i, (currentACR[i] = 0));

    /* cacheDataMode, cacheDataEnabled, cacheMmu are used to configured in cacheFuncsSet */
    cacheDataMode	= dMode;	/* CACHE_MODE cacheDataMode = CACHE_DISABLED (0) (cacheLib.c) */
    cacheDataEnabled	= FALSE;	/* BOOL cacheDataEnabled = FALSE (cacheLib.c) */
    cacheMmuAvailable	= FALSE;
    cacheInstEnabled	= FALSE;

    return (OK);
    }

/******************************************************************************
*
* cacheArchEnable - enable the cache
*
* This routine enables the specified (instruction or data) cache.
*
* RETURNS: OK, or ERROR if the cache type is invalid or the cache control
* is not supported.
*
* NOMANUAL
*/
LOCAL STATUS cacheArchEnable
    (
    CACHE_TYPE	cache		/* cache to enable */
    )
    {
    int lvl;

    if ( cacheProbe(cache) != OK )
	return (ERROR);

    if ( cache == INSTRUCTION_CACHE )
	{
	if ( !cacheInstEnabled )
	    {
	    lvl = intLock();
	    currentCACR = (currentCACR & C_CACR_DATABITS) |
			  (normalCACR & C_CACR_INSTBITS );
	    cacheCACRSet(currentCACR);
	    cacheACRSet(2, (currentACR[2] = normalACR[2]));
	    cacheACRSet(3, (currentACR[3] = normalACR[3]));
	    cacheInstEnabled = TRUE;
	    intUnlock(lvl);
	    }
	}
    else
    if ( cache == DATA_CACHE )
	{
	if ( !cacheDataEnabled )
	    {
	    lvl = intLock();
	    currentCACR = (currentCACR & C_CACR_INSTBITS) |
			  (normalCACR & C_CACR_DATABITS );
	    cacheCACRSet(currentCACR);
	    cacheACRSet(0, (currentACR[0] = normalACR[0]));
	    cacheACRSet(1, (currentACR[1] = normalACR[1]));
	    cacheDataEnabled	= TRUE;
	    cacheFuncsSet();	/*Initialize cacheUsersFuncs and cacheDmaFuncs*/
	    intUnlock(lvl);
	    }
	}

    return (OK);
    }

/******************************************************************************
*
* cacheArchDisable - disable the cache
*
* This routine disables the specified (instruction or data) cache.
*
* RETURNS: OK, or ERROR if the cache type is invalid or the cache control
* is not supported.
*
* NOMANUAL
*/
LOCAL STATUS cacheArchDisable
    (
    CACHE_TYPE	cache		/* cache to disable */
    )
    {
    int lvl;

    if ( cacheProbe(cache) != OK )
	return (ERROR);

    if ( cache == DATA_CACHE )
	{
	if ( cacheDataEnabled ) 
	    {
	    lvl = intLock();
	    cacheMCF5407DataPushAll(cacheDataLineCount);	/* sets CACR to 0 */
            cacheCACRSet(0);      /* clear out entire CACR */
	    currentCACR = currentCACR & ~(C_CACR_DEC | C_CACR_DESB);
	    cacheCACRSet(currentCACR);
	    cacheDataEnabled = FALSE;
	    cacheFuncsSet();
	    intUnlock(lvl);
	    }
	}
    else
    if ( cache == INSTRUCTION_CACHE )
	{
	if ( cacheInstEnabled ) 
	    {
	    lvl = intLock();
	    currentCACR = currentCACR & ~(C_CACR_BEC | C_CACR_IEC);
	    cacheCACRSet(currentCACR);
	    cacheInstEnabled = FALSE;
	    intUnlock(lvl);
	    }
	}

    return (OK);
    }

/******************************************************************************
*
* cacheArchFlush - flush all entries from the cache
*
* This routine flushes some or all entries from the cache.
* 
* RETURNS: OK, or ERROR if the cache type is invalid or the cache control
* is not supported.
*
* NOMANUAL
*/
LOCAL STATUS cacheArchFlush
    (
    CACHE_TYPE	cache, 		/* cache to clear */
    void *	address,	/* address to clear */
    size_t	bytes		/* bytes to clear */
    )
    {
    int oldLevel;
    UINT line, end;

    if ( bytes == 0 )
	return (OK);

    if ( cacheProbe(cache) != OK )
	return (ERROR);

    if ( cache == DATA_CACHE )
	{
	if ( !cacheDataEnabled )
	    return OK;

	oldLevel = intLock ();

	/* Calculate the number of sets for data (128) */
	line = ((UINT) address) & cacheDataLineMask;
	end  = (((UINT) address) + bytes - 1) & cacheDataLineMask;

	if ( ( bytes == ENTIRE_CACHE ) ||
	     ( bytes >= cacheDataSetLength ) ||
	     ( ( line == end ) && ( bytes > CACHE_LINE_SIZE ) ) )
	    {
	    /* Push the entire cache. */
	    cacheMCF5407DataPushAll(cacheDataLineCount);
	    }
	else 
	    {
	    while (TRUE)	/* YUK! */
		{
		cacheMCF5407DataPushLine((void *)line);
		if (line == end)
		    break;
		line = (line + CACHE_LINE_SIZE) & cacheDataLineMask;
		}
	    }

	cacheWriteBufferFlush();
	intUnlock (oldLevel);
	}
    else
    if(cache == INSTRUCTION_CACHE)
	{
	if ( !cacheInstEnabled )
	    return OK;

	oldLevel = intLock();

	/* calculate number of set for instruction (256) */
	line = ((UINT) address) & cacheInstLineMask;
	end  = (((UINT) address) + bytes - 1) & cacheInstLineMask;

	if ( ( bytes == ENTIRE_CACHE ) ||
	     ( bytes >= cacheInstSetLength ) ||
	     ( ( line == end ) && ( bytes > CACHE_LINE_SIZE ) ) )
	    {
	    /* Push the entire cache. */
	    cacheCACRSet(currentCACR | C_CACR_ICINVA);
	    }
	else
	    {
	    while (TRUE)	/* YUK! */
		{
		cacheMCF5407InstPushLine ((void *) line);
		if (line == end)
		    break;
		line = (line + CACHE_LINE_SIZE) & cacheInstLineMask;
		}
	    }

	intUnlock (oldLevel);
	}

    return (OK);
}


/******************************************************************************
*
* cacheArchClear - clear all entries from the cache
*
* This routine clears some or all entries from the cache.
* 
* RETURNS: OK, or ERROR if the cache type is invalid or the cache control
* is not supported.
*
* NOMANUAL
*/
LOCAL STATUS cacheArchClear
    (
    CACHE_TYPE	cache, 		/* cache to clear */
    void *	address,	/* address to clear */
    size_t	bytes		/* bytes to clear */
    )
    {
    int lvl;

    if ( cacheProbe(cache) != OK )
	return (ERROR);

    if ( cache == DATA_CACHE )
	{
	if ( !cacheDataEnabled )
	    return OK;

	lvl = intLock();
	cacheArchFlush(cache, address, bytes);
	intUnlock(lvl);
	}
    else
    if ( cache == INSTRUCTION_CACHE )
	{
	if ( !cacheInstEnabled )
	    return OK;

	lvl = intLock();
	cacheArchFlush(cache, address, bytes);
	intUnlock(lvl);
	}

    return (OK);
    }


/******************************************************************************
*
* cacheProbe - test for the prescence of a type of cache
*
* This routine returns status with regard to the prescence of a particular
* type of cache.
*
* RETURNS: OK, or ERROR if the cache type is invalid or the cache control
* is not supported.
*
* NOMANUAL
*/
LOCAL STATUS cacheProbe
    (
    CACHE_TYPE	cache 		/* cache to test */
    )
    {
    if ((cache == INSTRUCTION_CACHE) || (cache == DATA_CACHE))
        return (OK);
    errno = S_cacheLib_INVALID_CACHE;			/* set errno */
    return (ERROR);
}

/******************************************************************************
*
* cacheArchTextUpdate - synchronize the instruction and data caches
*
* Clears the data cache to force any changes into memory, and then
* invalidates the instruction cache to make sure the newly loaded code
* can be executed.
*
* RETURNS: OK, or ERROR if the cache type is invalid or the cache control
* is not supported.
*
* NOMANUAL
*/
LOCAL STATUS cacheArchTextUpdate 
    (
    void * address,	/* virtual address */
    size_t bytes	/* number of bytes to update */
    )
    {
    if(cacheArchClear(DATA_CACHE, address, bytes) == OK)
	return (cacheInvalidate(INSTRUCTION_CACHE, address, bytes));
    else
	return ERROR;
    }
