/* cacheColdUnifiedLib.c - ColdFire unified cache management library */

/* Copyright 1984-2000 Wind River Systems, Inc. */
#include "copyright_wrs.h"

/*
modification history
--------------------
01d,02mar01,dh  Fix bug introduces in cacheArchInvalidate()
01c,31jan01,dh   revert to older method of cache control, but allow more
		 flexibility in the BSP
01b,15jan01,dh   major hack - maybe it'll work now?
01a,06may98,mem  written, based on 01b cacheMCF5202Lib.c
*/

/*
DESCRIPTION
Several of the ColdFire processors use a unified instruction and data
cache design (of differing sizes).  In addition, many of the cache
control instructions common to other members of the 68k family are
missing.

INTERNAL
The cache enable and disable processes consist of the following
actions, executed by cacheArchEnable() and cacheArchDisable().  To
enable a disabled cache, first the cache is fully invalidated.  Then
the cache mode (write-through, copy-back, etc.) is configured.
Finally, the cache is turned on.  Enabling an already enabled cache
results in no operation.

To disable an enabled cache, first the cache is invalidated.  However,
a cache configured in copy-back mode must first have been pushed out
to memory.  Once invalidated, the cache is turned off.  Disabling an
already disabled cache results in no operation.

The cache mode can be controlled separately for the 3 memory regions
specified by the 2 ACRs and "the rest" (CACR). For this reason the
cache mode values supplied to cacheColdUnifiedLibInit() are not
used. Instead, the BSP must provide a variable "normalCACR" and
an array "normalACR[2]" which contain the required modes and address
ranges for the respective registers. Changing the cache mode
at runtime is simply a matter of disabling the cache, changing
these variables, then re-enabling the cache.

Note: In the Coldfire Core: the movec instruction is unidirectional.
Control registers can be written, but not read. For this reason, we
keep RAM copies of the contents of CACR and the ACRs.

For the CPUSH, the only variant supported is the CPUSHL (Ax)
instruction.  However, unlike previous members of the 68K family, the
contents of the address register is different. The least 4 significant
bits denotes the cache set, beyond the four least signifcant bits is
the cache line pointer.

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

/* defines */

#define CACHE_SET_COUNT		4
#define CACHE_LINE_SHIFT	4
#define CACHE_LINE_SIZE		(1 << CACHE_LINE_SHIFT)

/* externs */

IMPORT ULONG	_cfCacheSize;			/* cache size - set by BSP */
IMPORT ULONG	normalCACR;
IMPORT ULONG	normalACR[2];


IMPORT  void    cacheCACRSet(int);
IMPORT  void    cacheACRSet(int, int);
IMPORT  void    cacheWriteBufferFlush(void);

IMPORT void	cacheColdUnifiedPushAll (int nlines);
IMPORT void	cacheColdUnifiedPushLine (void * address);
IMPORT void	cacheColdUnifiedDataDisable (int nlines);

/* locals */

/* These must be in DATA as the cache is initialized before bss is cleared. */
ULONG currentCACR = 0;		/* current cache control register value */
ULONG currentACR[2] = {0,0};
LOCAL ULONG	cacheLineMask = 0;
LOCAL ULONG	cacheSetLength = 0;
LOCAL int	cacheLineCount = 0;

/* forward declarations */

LOCAL STATUS cacheProbe (CACHE_TYPE cache);
LOCAL STATUS cacheArchEnable (CACHE_TYPE cache);
LOCAL STATUS cacheArchDisable (CACHE_TYPE cache);
LOCAL STATUS cacheArchClear (CACHE_TYPE cache, 
			     void * address, size_t bytes);
LOCAL STATUS cacheArchInvalidate (CACHE_TYPE cache, 
				  void * address, size_t bytes);
LOCAL STATUS cacheArchFlush (CACHE_TYPE cache,
			     void * address, size_t bytes);
LOCAL STATUS cacheArchTextUpdate (void * address, size_t bytes);

#define setCacheModes(e) \
    currentCACR = normalCACR & ~C_CACR_DPI; \
    if (!e) currentCACR &= ~(C_CACR_ENABLE | C_CACR_ESB); \
    cacheCACRSet(currentCACR); \
    cacheACRSet(0, (currentACR[0] = normalACR[0])); \
    cacheACRSet(1, (currentACR[1] = normalACR[1]));

/******************************************************************************
*
* cacheColdUnifiedLibInit - initialize the ColdFire unified cache library
* 
* This routine initializes the cache library for Motorola ColdFire
* processors.  It initializes the function pointers and configures the
* caches to the specified cache modes.  Modes should be set before caching
* is enabled.  If two complementary flags are set (enable/disable), no
* action is taken for any of the input flags.
*
* This function is called before the bss is cleared, so any variables
* assigned to must be in the data segment, or their values will be lost.
*
* RETURNS: OK.
*/

STATUS cacheColdUnifiedLibInit
    (
    CACHE_MODE	iMode,	/* instruction cache mode (not used) */
    CACHE_MODE	dMode	/* data cache mode (not used) */
    )
    {
    /* Make sure the BSP set the cache size */
    if (_cfCacheSize == 0)
	return (ERROR);

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
    cacheLib.invalidateRtn	= cacheArchInvalidate;
    cacheLib.pipeFlushRtn	= (FUNCPTR) cacheWriteBufferFlush;

    /* Compute the cache line mask */
    cacheSetLength = _cfCacheSize / CACHE_SET_COUNT;
    cacheLineMask = ((cacheSetLength - 1) & ~(CACHE_LINE_SIZE - 1));
    cacheLineCount = cacheSetLength / CACHE_LINE_SIZE;

    /* Make sure the cache is off, and invalidate it */
    cacheCACRSet(C_CACR_CINVA);
    setCacheModes(FALSE);

    cacheDataMode	= dMode;		/* save dataMode for enable */
    cacheDataEnabled	= FALSE;		/* d-cache is currently off */
    cacheMmuAvailable	= FALSE;		/* no mmu yet */

    return (OK);
    }

/******************************************************************************
*
* cacheArchEnable - enable the cache
*
* This routine enables the specified 68K instruction or data cache.
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
    int oldLevel;

    if (cacheProbe (cache) != OK)
	return (ERROR);

    if ( !cacheDataEnabled )
	{
	/* turn the cache on */
	oldLevel = intLock ();
	setCacheModes(TRUE);
	cacheDataEnabled = TRUE;
	cacheFuncsSet ();
	intUnlock (oldLevel);
	}
    return (OK);
    }

/******************************************************************************
*
* cacheArchDisable - disable the cache
*
* This routine disables the specified 68K instruction or data cache.
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
    int oldLevel;

    if (cacheProbe (cache) != OK)
	return (ERROR);

    if ( cacheDataEnabled )
	{
	/* disable/push/invalidate */
	oldLevel = intLock ();
	cacheColdUnifiedDataDisable(cacheLineCount);	/* sets CACR to 0 */
	setCacheModes(FALSE);
	cacheDataEnabled = FALSE;
	cacheFuncsSet ();
	intUnlock (oldLevel);
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

    if (bytes == 0)
	return (OK);
    if (cacheProbe(cache) != OK)
	return (ERROR);
    if (!cacheDataEnabled)
	return (OK);

    line = ((UINT) address) & cacheLineMask;
    end = (((UINT) address) + bytes - 1) & cacheLineMask;

    oldLevel = intLock ();
    if ((bytes == ENTIRE_CACHE)
	|| (bytes >= cacheSetLength)
	|| ((line == end) && (bytes > CACHE_LINE_SIZE)))
        {
	/* Push the entire cache. */
	cacheColdUnifiedPushAll (cacheLineCount);
	}
    else
	{
	while (TRUE)
	    {
	    cacheColdUnifiedPushLine ((void *) line);
	    if (line == end)
		break;
	    line = (line + CACHE_LINE_SIZE) & cacheLineMask;
	    }
	}
    /* flush write buffer */
    cacheWriteBufferFlush ();
    intUnlock (oldLevel);

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
    int oldLevel;

    if (cacheProbe(cache) != OK)
	return (ERROR);
    if (!cacheDataEnabled)
	return (OK);

    oldLevel = intLock ();
    /* Enable CPUSH invalidation. */
    cacheCACRSet(currentCACR | C_CACR_DPI);

    /* Flush and invalidate the entries. */
    cacheArchFlush (cache, address, bytes);

    /* Disable CPUSH invalidation. */
    cacheCACRSet(currentCACR);
    intUnlock (oldLevel);

    return (OK);
    }

/******************************************************************************
*
* cacheArchInvalidate - invalidate entries in a cache
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
    int oldLevel;
    UINT line, end;

    if (bytes == 0)
	return (OK);
    if (cacheProbe (cache) != OK)
	return (ERROR);				/* invalid cache */
    if (!cacheDataEnabled)
	return (OK);

    line = ((UINT) address) & cacheLineMask;
    end = (((UINT) address) + bytes - 1) & cacheLineMask;

    oldLevel = intLock ();
    if ((bytes == ENTIRE_CACHE)
	|| (bytes >= cacheSetLength)
	|| ((line == end) && (bytes > CACHE_LINE_SIZE)))
        {
	/* Invalidate the entire cache */
	cacheCACRSet (currentCACR | C_CACR_CINVA);
	}
    else
	{
	while (TRUE)
	    {
	    cacheColdUnifiedPushLine ((void *) line);
	    if (line == end)
		break;
	    line = (line + CACHE_LINE_SIZE) & cacheLineMask;
	    }
	/* flush write buffer */
	cacheWriteBufferFlush ();
	}

    intUnlock (oldLevel);

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
    if ((cache==INSTRUCTION_CACHE) || (cache==DATA_CACHE))
        return (OK);
    errno = S_cacheLib_INVALID_CACHE;			/* set errno */
    return (ERROR);
    }

/******************************************************************************
*
* cacheArchTextUpdate - synchronize the instruction and data caches
*
* The cache uses a unified cache structure, but we still need to flush
* out to memory so intVecSet() will work correctly.
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
    return (cacheArchClear (DATA_CACHE, address, bytes));
    }
