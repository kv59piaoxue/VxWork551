/* cacheMCF5204Lib.c - ColdFire 5204 cache management library */

/* Copyright 1984-2000 Wind River Systems, Inc. */
#include "copyright_wrs.h"

/*
modification history
--------------------
01c,27jun00,dh   updated to Tornado 2.0
01b,05may97,mem  fixed off by one error.
01a,02jan96,kab  written, based on cacheMCF5202Lib.c
*/

/*
DESCRIPTION
The MCF5204 ColdFire processor uses an instruction cache only design,
and is missing many of the cache control instructions common to other
members of the 68k family.

INTERNAL
The cache enable and disable processes consist of the following
actions, executed by cacheArchEnable() and cacheArchDisable().  To
enable a disabled cache, first the cache is fully invalidated.  Then
the cache mode (write-through, copy-back, etc.) is configured.
Finally, the cache is turned on.  Enabling an already enabled cache
results in no operation.

To disable an enabled instruction cache requires only that the CENB bit
be set.  Disabling an already disabled cache results in no operation.

Control of cache mode is mostly left to the ACR registers which are
set by the BSP.  The initial (default) setting of the CACR register is
controlled by the variable "initialCACR" which must be provided by the
BSP.

Note: In the Coldfire Core: the movec instruction is unidirectional.
Control registers can be read, but not written.

For the CPUSH, the only variant supported is the CPUSHL (Ax)
instruction.  However, unlike previous members of the 68K family, the
contents of the address register is different. The least 4 significant
bits denotes the cache set, beyond the four least signifcant bits is
the cache line pointer.

See the MCF5204 Coldfire User's Manual for cache details.

For general information about caching, see the manual entry for cacheLib.

INCLUDE FILES: cacheLib.h

SEE ALSO: cacheLib, vmLib */

/* LINTLIBRARY */

#include "vxWorks.h"
#include "errnoLib.h"
#include "cacheLib.h"
#include "stdlib.h"
#include "private/memPartLibP.h"
#include "private/vmLibP.h"
#include "private/funcBindP.h"

/* defines - MCF5204 specific */

#define CACHE_SIZE		512
#define CACHE_SETS		1
#define CACHE_LENGTH		(CACHE_SIZE/CACHE_SETS)
#define CACHE_LINE_SHIFT	4
#define CACHE_LINE_SIZE		(1 << CACHE_LINE_SHIFT)
#define CACHE_LINE_MASK		0x01f0

#define cacheIsOn()	((currentCACR & C_CACR_ENABLE) != 0)
#define cacheSet(VALUE, MASK) \
	cacheCACRSet (currentCACR = ((currentCACR & ~(MASK)) | (VALUE)))

/* forward declarations */

IMPORT void	cache5204PushLine (void * address);

IMPORT ULONG	initialCACR;

/* locals */

ULONG currentCACR = 0;		/* current cache control register value */

/* forward declarations */

LOCAL STATUS cacheProbe (CACHE_TYPE cache);

LOCAL STATUS cacheArchEnable (CACHE_TYPE cache);
LOCAL STATUS cacheArchDisable (CACHE_TYPE cache);
LOCAL STATUS cacheArchInvalidate (CACHE_TYPE cache, 
				  void * address, size_t bytes);
LOCAL STATUS cacheArchTextUpdate (void * address, size_t bytes);

/******************************************************************************
*
* cacheMCF5204LibInit - initialize the MCF5204 cache library
* 
* This routine initializes the cache library for Motorola MCF5204
* processor.  It initializes the function pointers and configures the
* cache.  The cache mode arguments have no effect.
*
* This function is called before the bss is cleared, so any variables
* assigned to must be in the data segment, or their values will be lost.
*
* RETURNS: OK.
*/

STATUS cacheMCF5204LibInit
    (
    CACHE_MODE	iMode,	/* instruction cache mode */
    CACHE_MODE	dMode	/* data cache mode */
    )
    {
    cacheLib.enableRtn		= cacheArchEnable;
    cacheLib.disableRtn		= cacheArchDisable;
    cacheLib.lockRtn		= NULL;
    cacheLib.unlockRtn		= NULL;
    cacheLib.clearRtn		= cacheArchInvalidate;
    cacheLib.dmaMallocRtn	= NULL;
    cacheLib.dmaFreeRtn		= NULL;
    cacheLib.dmaVirtToPhysRtn	= NULL;
    cacheLib.dmaPhysToVirtRtn	= NULL;
    cacheLib.textUpdateRtn	= cacheArchTextUpdate;
    cacheLib.flushRtn		= NULL;
    cacheLib.invalidateRtn	= cacheArchInvalidate;
    cacheLib.pipeFlushRtn	= NULL;

    /* Make sure the cache is off, and invalidate it */
    cacheCACRSet (C_CACR_CINVA);

    currentCACR = initialCACR & ~C_CACR_ENABLE;

    /* Disable CPUSH invalidation */
    currentCACR |= C_CACR_DPI;

    cacheMmuAvailable	= FALSE;		/* no mmu */

    return (OK);
    }

/******************************************************************************
*
* cacheArchEnable - enable a MCF5204 cache
*
* This routine enables the specified MCF5204 cache.
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

    if (cacheProbe (cache) != OK)
	return (ERROR);

    if (!cacheIsOn ())
	{
	/* turn the cache on */
	lvl = intLock ();
	cacheSet (C_CACR_ENABLE, C_CACR_ENABLE);
	cacheFuncsSet ();
	intUnlock (lvl);
	}
    return (OK);
    }

/******************************************************************************
*
* cacheArchDisable - disable the MCF5204 cache
*
* This routine disables the specified MCF5204 cache.
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

    if (cacheProbe (cache) != OK)
	return (ERROR);

    if (cacheIsOn ())
	{
	/* disable/push/invalidate */
	lvl = intLock ();
	currentCACR &= ~C_CACR_ENABLE;
	cacheSet (currentCACR, currentCACR);
	cacheFuncsSet ();
	intUnlock (lvl);
	}
    return (OK);
    }

/******************************************************************************
*
* cacheArchInvalidate - invalidate entries in a MCF5204 cache
*
* This routine invalidates some or all entries.
*
* RETURNS: OK, or ERROR if the cache type is invalid or the cache control
* is not supported.
*
* NOMANUAL
*/

LOCAL STATUS cacheArchInvalidate
    (
    CACHE_TYPE	cache, 		/* cache to invalidate */
    void *	address,	/* virtual address */
    size_t	bytes		/* number of bytes to invalidate */
    )
    {
    UINT line, end;

    if (bytes == 0)
	return (OK);
    if (cacheProbe (cache) != OK)
	return (ERROR);				/* invalid cache */

    line = ((UINT) address) & CACHE_LINE_MASK;
    end = (((UINT) address) + bytes - 1) & CACHE_LINE_MASK;

    if ((bytes == ENTIRE_CACHE)
	|| (bytes >= CACHE_LENGTH)
	|| ((line == end) && (bytes > CACHE_LINE_SIZE)))
        {
	/* Invalidate the entire cache */
	cacheCACRSet (currentCACR | C_CACR_CINVA);
	}
    else
	{
	cacheSet (0, C_CACR_DPI);		/* enable CPUSH invalidation */
	while (1)
	    {
	    cacheMCF5204PushLine (line);
	    if (line == end)
		break;
	    line = (line + CACHE_LINE_SIZE) & CACHE_LINE_MASK;
	    }
	cacheSet (C_CACR_DPI, C_CACR_DPI);
	}
    return (OK);
    }

/******************************************************************************
*
* cacheProbe - test for the presence of a type of cache
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
    if (cache == INSTRUCTION_CACHE)
        return (OK);
    errno = S_cacheLib_INVALID_CACHE;			/* set errno */
    return (ERROR);
    }

/******************************************************************************
*
* cacheArchTextUpdate - synchronize the MCF5204 instruction cache
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
    return cacheArchInvalidate (INSTRUCTION_CACHE, address, bytes);
    }

