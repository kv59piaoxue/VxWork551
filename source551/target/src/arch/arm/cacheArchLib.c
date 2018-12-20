/* cacheArchLib.c - ARM cache support library */

/* Copyright 1996-2001 Wind River Systems, Inc. */
#include "copyright_wrs.h"

/*
modification history
--------------------
01v,17dec02,jb   Adding ARM 926e and ARM 102xE support
01v,20jan03,jb   Resolve SPR 82037
01u,13nov01,to   hand over global variables to cacheArchVars.c,
		 synchronize with AE, style and spelling fix,
		 initialise (UK) -> initialize (US), etc.
01t,03oct01,jpd  corrected ARM946E code (SPR #68958).
01s,26sep01,scm  XScale should support CACHE_WRITETHROUGH...
01r,19sep01,scm  XScale compatibility with visionProbe requires full
                 instruction cache flush instead of single line flush...
01q,25jul01,scm  add support for btbInvalidate...
01p,23jul01,scm  change XScale name to conform to coding standards...
01o,21jul00,jpd  added support for ARM946E.
01n,04apr00,jpd  fix bug in 920T cacheInvalidate SPR #30698 and cacheDmaMalloc
		 SPR #30697.
01m,26oct99,jpd  cacheArchLibInstall documentation changes.
01l,10sep99,jpd  add support for ARM740T, ARM720T, ARM920T.
01k,21jan99,jpd  documentation changes.
01j,20jan99,cdp  removed support for old ARM libraries.
01i,24nov98,jpd  add support for ARM 940T, SA-1100, SA-1500; add variable
		 cacheArchAlignSize; added option not to disable I-cache on
		 SA-1500; removed use of mmuIntLock; vmBaseLib cacheDmaFree now
		 marks buffer cacheable (SPR #22407); add cacheArchLibInstall();
            cdp  added support for generic ARM ARCH3/ARCH4.
01h,09mar98,jpd  added cacheLib.dmaVirtToPhys etc. setting.
01g,31oct97,jpd  fixed cache invalidation faults on 810.
01f,27oct97,kkk  took out "***EOF***" line from end of file.
01e,10oct97,jpd  Restrict include of dsmArmLib.h to 810.
01d,18sep97,jpd  Check SWI vector initialised before issuing IMB. Add
		 use of IMBRange. Defer setting of cacheDataEnabled,
		 when MMU is off. Modified FIQ protection, added
		 BSP-specific cache flush area. Added ARM7TDMI_T
		 support. Made cacheArchState, cacheArchIntMask not
		 specific to ARMSA110.
01c,03mar97,jpd  Tidied comments/documentation.
01b,29jan97,jpd  Added dummy cacheArchLibInit for ARM7TDMI.
01a,04sep96,jpd  written, based on Am29K version 01c and 68k version 03j
*/

/*
DESCRIPTION
This library contains architecture-specific cache library functions for the
ARM family instruction and data caches.  The various members of the ARM
family of processors support different cache mechanisms; thus, some
operations cannot be performed by certain processors because they lack
particular functionalities.  In such cases, the routines in this
library return ERROR.  Processor-specific constraints are addressed in
the manual entries for routines in this library.  If the caches are
unavailable or uncontrollable, the routines return ERROR.

STRONGARM CACHE FLUSHING
On ARM SA-110, the BSP must provide the (virtual) address
(sysCacheFlushReadArea) of a readable, cached block of address space,
used for nothing else, which will be read to force the D-cache to be
written out to memory.  If the BSP has an area of the address space
which is usable for this purpose, which does not actually contain
memory, it should set the pointer to that area.  If it does not, it
should allocate some RAM for this. In either case, the area must be
marked as readable and cacheable in the page tables.

On ARM SA-1100/ARM SA-1500, in addition to sysCacheFlushReadArea, the
BSP must provide the (virtual) address (sysMinicacheFlushReadArea) of a
readable, block of address space, marked as minicacheable, used for
nothing else, which will be used to force the minicache to be written
out to memory.

ARM 940T
The BSP must declare a pointer (sysCacheUncachedAdrs) to a readable,
uncached word of address space used for reading, to drain the
write-buffer.  The area containing this address must be marked as valid
and non-cacheable, and the address must be safe to read, i.e. have no
side-effects.

ARM 926EJ-S
The BSP must declare a pointer (sysCacheUncachedAdrs) to a readable,
uncached word of address space used for reading, to synchronise the
data and instruction streams in Level 2 AHB subsystems. The address
must be marked as valid and non-cacheable, and the address must be safe
to read, i.e. have no side-effects.

INTERNAL
Although this library contains code written for the ARM810 CPU, at the
time of writing, this code has not been tested fully on that CPU.
(YOU HAVE BEEN WARNED).

NOTE
All caching functions on the ARM require the MMU to be enabled,
except for XSCALE, StrongARM, ARM920T, ARM926E and ARM1020E, where
the I-cache can be enabled without enabling the MMU.  No specific
support for this mode of operation is included.

INTERNAL
There are some terminology problems. VxWorks uses the following definitions:
Clear = VxWorks "Flush" then VxWorks "Invalidate"
Flush = write out to memory = ARM "clean"
Invalidate = make cache entry invalid = ARM "flush"

INTERNAL
The cache enable and disable processes consist of the following actions,
executed by cacheArchEnable() and cacheArchDisable().  To enable
a disabled cache, first the cache is fully invalidated.  Then the cache mode
(write-through, copy-back, etc.) is configured.  Finally, the cache is turned
on.  Enabling an already enabled cache results in no operation.

INTERNAL
To disable an enabled cache, first the cache is invalidated.  However, a cache
configured in copy-back mode must first have been pushed out to memory.  Once
invalidated, the cache is turned off.  Disabling an already disabled cache
results in no operation.

For general information about caching, see the manual entry for cacheLib.

INCLUDE FILES: cacheLib.h, mmuLib.h

SEE ALSO: cacheLib, vmLib,
.I "ARM Architecture Reference Manual,"
.I "ARM 710A Data Sheet,"
.I "ARM 810 Data Sheet,"
.I "Digital Semiconductor SA-110 Microprocessor Technical Reference Manual,"
.I "Digital Semiconductor SA-1100 Microprocessor Technical Reference Manual,"
.I "Digital Semiconductor SA-1500 Mediaprocessor Data Sheet,"
.I "ARM 720T Data Sheet,"
.I "ARM 740T Data Sheet,"
.I "ARM 920T Technical Reference Manual,"
.I "ARM 926EJ-S Technical Reference Manual,"
.I "ARM 940T Technical Reference Manual."
.I "ARM 1020E Technical Reference Manual."
.I "ARM 1022E Technical Reference Manual."
*/


/* includes */

#include "vxWorks.h"
#if !defined(ARMCACHE)
#error ARMCACHE not defined
#endif

#include "errnoLib.h"
#include "cacheLib.h"
#include "arch/arm/mmuArmLib.h"
#include "arch/arm/intArmLib.h"
#if ARMCACHE_NEEDS_IMB
#include "arch/arm/dsmArmLib.h"
#include "arch/arm/excArmLib.h"
#endif
#include "stdlib.h"
#include "private/memPartLibP.h"
#include "private/vmLibP.h"
#include "private/funcBindP.h"
#include "intLib.h"

/* externals */

#if (ARM_HAS_MPU)
IMPORT int ffsMsb (UINT32 val);
#endif

/*
 * The following variables are declared outside this file in a file that is
 * not compiled in a manner such that variables end up with different names.
 */

IMPORT FUNCPTR	sysCacheLibInit;
IMPORT UINT32	cacheArchState;


/*
 * Globals.
 *
 * Those globals which have values assigned to them in cacheArchLibInit(),
 * need to be predefined, else they may be put in BSS.  Since BSS is not
 * cleared until after cacheArchLibInit() has been called, this would be a
 * problem.
 */
#if ((ARMCACHE == ARMCACHE_926E)   ||  (ARMCACHE == ARMCACHE_946E)  || \
     (ARMCACHE == ARMCACHE_1020E)  ||  (ARMCACHE == ARMCACHE_1022E))

#if ((ARMCACHE == ARMCACHE_946E)   || (ARMCACHE == ARMCACHE_1020E) || \
     (ARMCACHE == ARMCACHE_1022E))

/*
 * Mask to get cache index number from address. As it happens, this is
 * also the number we can use in the cache Flush/Clean code, to build
 * index/segment format values, as it corresponds to the largest index
 * number, already shifted to the correct place within the word.
 */

UINT32  cacheArchIndexMask = 0;
#if (ARMCACHE == ARMCACHE_1020E) || (ARMCACHE == ARMCACHE_1022E)
UINT32  cacheArchSegMask = 0;
#endif
#endif /* (ARMCACHE == ARMCACHE_946E, 1020E, 1022E) */

LOCAL UINT32 cacheDCacheSize = 0;
LOCAL UINT32 cacheICacheSize = 0;
#define D_CACHE_SIZE cacheDCacheSize
#define I_CACHE_SIZE cacheICacheSize
#endif /* (ARMCACHE == ARMCACHE_926E, 946E, 1020E, 1022E) */


/* forward declarations */

LOCAL STATUS cacheArchLibInit (CACHE_MODE instMode, CACHE_MODE dataMode);

#if ((ARMCACHE == ARMCACHE_710A)   || (ARMCACHE == ARMCACHE_720T)   || \
     (ARMCACHE == ARMCACHE_740T)   || (ARMCACHE == ARMCACHE_810)    || \
     (ARMCACHE == ARMCACHE_SA110)  || (ARMCACHE == ARMCACHE_SA1100) || \
     (ARMCACHE == ARMCACHE_SA1500) || (ARMCACHE == ARMCACHE_920T)   || \
     (ARMCACHE == ARMCACHE_926E)   || (ARMCACHE == ARMCACHE_940T)   || \
     (ARMCACHE == ARMCACHE_946E)   || (ARMCACHE == ARMCACHE_XSCALE) || \
     (ARMCACHE == ARMCACHE_1020E)  || (ARMCACHE == ARMCACHE_1022E))

LOCAL STATUS	cacheArchEnable (CACHE_TYPE cache);
LOCAL STATUS	cacheArchDisable (CACHE_TYPE cache);
LOCAL STATUS	cacheArchFlush (CACHE_TYPE cache, void * address, size_t bytes);
LOCAL STATUS	cacheArchInvalidate (CACHE_TYPE cache, void * address,
				     size_t bytes);
LOCAL STATUS	cacheArchClear (CACHE_TYPE cache, void * address, size_t bytes);
LOCAL STATUS	cacheArchTextUpdate (void * address, size_t bytes);
LOCAL void *	cacheArchDmaMalloc (size_t bytes);
LOCAL STATUS	cacheArchDmaFree (void * pBuf);
LOCAL STATUS	cacheProbe (CACHE_TYPE cache);
LOCAL BOOL	cacheIsOn (CACHE_TYPE cache);
LOCAL BOOL	cacheMmuIsOn (void);
#endif

#if ((ARMCACHE == ARMCACHE_740T)   || (ARMCACHE == ARMCACHE_810)  || \
     (ARMCACHE == ARMCACHE_920T)   || (ARMCACHE == ARMCACHE_926E) || \
     (ARMCACHE == ARMCACHE_940T)   || (ARMCACHE == ARMCACHE_946E) || \
     (ARMCACHE == ARMCACHE_XSCALE) || (ARMCACHE == ARMCACHE_1020E) || \
     (ARMCACHE == ARMCACHE_1022E))
/*
 * Cache locking capability is only present in hardware on these CPUs and
 * is not yet implemented.
 */

#if FALSE
LOCAL STATUS	cacheArchLock (CACHE_TYPE cache, void * address, size_t bytes);
LOCAL STATUS	cacheArchUnlock (CACHE_TYPE cache, void * address,
				 size_t bytes);
#endif
#endif

/*
 * Do not support the use of Branch Prediction yet, as we have not had time to
 * test it properly
 */

#undef BPRED_SUPPORT

/*******************************************************************************
*
* cacheArchLibInstall - install specific ARM cache library
*
* This routine is provided so that a call to this routine selects the
* specific cache library.  It also allows any virtual <-> physical address
* translation routines provided by the BSP to be passed to the cache
* library as parameters rather than as global data.  These are then used by
* cacheDrvVirtToPhys() and cacheDrvPhysToVirt().
*
* If the default address map is such that virtual and physical
* addresses are identical (this is normally the case with BSPs), the
* parameters to this routine can be NULL pointers.  Only where the
* default memory map is such that virtual and physical addresses are
* different, need the translation routines be provided.
*
* If the address map is such that the mapping described within the
* sysPhysMemDesc structure of the BSP is accurate, then the parameters to
* this routine can be mmuPhysToVirt and mmuVirtToPhys: two routines
* provided within the architecture code that perform the conversion based
* on the information within that structure.  If that assumption is not
* true, then the BSP must provide its own translation routines.
*
* RETURNS: N/A
*
* The specification of the translation routines is as follows:
*
* void * virtToPhys
*     (
*     void *	virtAddr  /@ virtual addr to be translated @/
*     )
*
* RETURNS: the physical address
*
* void * physToVirt
*     (
*     void *	physAddr  /@ physical addr to be translated @/
*     )
*
* RETURNS: the virtual address
*
* The caching capabilities and modes for different cache types vary
* considerably (see below).  The memory map is BSP-specific and some
* functions need knowledge of the memory map, so they have to be provided
* in the BSP.  Moreover, now that chips are being made on a
* "mix-and-match" basis, selection of the cache type is now a BSP issue.
*
* ARM 7TDMI
* No cache or MMU at all (in ARM or Thumb state).  Dummy routine
* provided, so that INCLUDE_CACHE_SUPPORT can be defined (the default BSP
* configuration).
*
* ARM 710A, 720T AND ARM 740T
* Combined instruction and data cache. Actually a write-through cache,
* but separate write-buffer could be considered to make this a
* copy-back cache if the write-buffer is enabled.  Use the
* write-through/copy-back argument to decide whether to enable write
* buffer globally.  Marking individual pages (using the MMU) as
* write-through or copy-back will control the use of the write-buffer for
* those pages if the write-buffer is enabled. Data and instruction cache
* modes must be identical.
*
* ARM 810
* Combined instruction and data cache.  Write-through and copy-back cache
* modes, but separate write-buffer could be considered to make even
* write-through a copy-back cache as all writes are buffered, when cache
* is enabled. Data and instruction cache modes must be identical.
*
* ARM SA-110
* Separate instruction and data caches.  Cache hardware only supports
* copy-back mode for data cache.
*
* ARM SA-1100/SA-1110
* Separate instruction and data caches.  Cache hardware only supports
* copy-back mode for data cache.  D-cache is 8 kbytes in size as
* opposed to 16 kbytes for SA-110 and SA-1500.  Minicache of 512 bytes.
*
* ARM SA-1500
* Separate instruction and data caches.  Cache hardware only supports
* copy-back mode for data cache.  Minicache of 1 kbytes.
*
* ARM 920T, 926E, 1020E, 1022E, AND 946E XSCALE
* Separate instruction and data caches.  The global mode of the data
* cache cannot be configured and must be copy-back.  Individual pages
* can be marked (using the MMU) as write-through or copy-back but
* separate write-buffer (which is always enabled) is used for all
* cacheable writes (even write-through).  The cache replacement
* algorithm can be set to be random or round-robin in hardware.  No
* reliance on the method should be present in this code, but it has only
* been tested in the default state (random replacement).
*
* ARM 940T
* As 920T, but no configurable cache-replacement algorithm.
*
* INTERNAL
* This routine is called (from sysHwInit0()), before cacheLibInit() has
* been called, before sysHwInit has been called, and before BSS has been
* cleared.
*
*/

void cacheArchLibInstall
    (
    void * (physToVirt) (void *), /* phys to virt addr translation rtn */
    void * (virtToPhys) (void *)  /* virt to phys addr translation rtn */
    )
    {
    static BOOL initialized = FALSE;

    /* protect against being called twice */

    if (initialized)
	return;

    /*
     * Normally, cacheArchDmaMalloc() will return addresses with the
     * same virtual to physical address mapping as the rest of the system
     * (which is normally identical), so the following two routines do
     * not need to be provided.  However, on some systems it is not
     * possible for a memory mapping to be created where virtual and
     * physical addresses are identical.  In that case, the BSP will
     * provide routines to perform this mapping, and we should use
     * them.
     */

    cacheLib.dmaPhysToVirtRtn	= (FUNCPTR) physToVirt;
    cacheLib.dmaVirtToPhysRtn	= (FUNCPTR) virtToPhys;

    /*
     * Initialize the function pointer so that the
     * architecture-independent code calls the correct code.
     */

    sysCacheLibInit = cacheArchLibInit;

    initialized = TRUE;

    return;
    }

/*******************************************************************************
*
* cacheArchLibInit - initialize ARM cache library function pointers
*
* This routine initializes the cache library for ARM processors.  It
* initializes the function pointers and configures the caches to the
* specified cache modes.  Modes should be set before caching is
* enabled.  If two complementary flags are set (enable/disable), no
* action is taken for any of the input flags.
*
* NOTE
* This routine should not be called directly from cacheLibInit() on the
* new (generic) architectures.  Instead, cacheArchLibInstall() should
* be called.
*
* INTERNAL
* This routine is called (from cacheLibInit()), before sysHwInit has
* been called, and before BSS has been cleared.
*
* RETURNS: OK always
*
*/

LOCAL STATUS cacheArchLibInit
    (
    CACHE_MODE	instMode,	/* instruction cache mode */
    CACHE_MODE	dataMode	/* data cache mode */
    )
    {
    static BOOL initialized = FALSE;
#if ((ARMCACHE == ARMCACHE_926E)   || (ARMCACHE == ARMCACHE_946E)   || \
     (ARMCACHE == ARMCACHE_1020E)  || (ARMCACHE == ARMCACHE_1022E))
    UINT32 temp, temp2, temp3;
#endif

    /* protect (silently) against being called twice */
    if (initialized)
	return OK;

#if ((ARMCACHE == ARMCACHE_710A)   || (ARMCACHE == ARMCACHE_720T)   || \
     (ARMCACHE == ARMCACHE_740T)   || (ARMCACHE == ARMCACHE_810)    || \
     (ARMCACHE == ARMCACHE_SA110)  || (ARMCACHE == ARMCACHE_SA1100) || \
     (ARMCACHE == ARMCACHE_SA1500) || (ARMCACHE == ARMCACHE_920T)   || \
     (ARMCACHE == ARMCACHE_926E)   || (ARMCACHE == ARMCACHE_940T)   || \
     (ARMCACHE == ARMCACHE_946E)   || (ARMCACHE == ARMCACHE_XSCALE) || \
     (ARMCACHE == ARMCACHE_1020E)  || (ARMCACHE == ARMCACHE_1022E))
    /*
     * Initialize the variable that we want others to use in preference
     * to the symbolic constant. Set it to the cache-type-specific value.
     */

    cacheArchAlignSize		= _CACHE_ALIGN_SIZE;

    cacheLib.enableRtn		= cacheArchEnable;
    cacheLib.disableRtn		= cacheArchDisable;

#if ((ARMCACHE == ARMCACHE_710A)   || (ARMCACHE == ARMCACHE_720T)   || \
     (ARMCACHE == ARMCACHE_SA110)  || (ARMCACHE == ARMCACHE_SA1100) || \
     (ARMCACHE == ARMCACHE_SA1500))
    /* No cache locking features available on these processors */

    cacheLib.lockRtn		= NULL;
    cacheLib.unlockRtn		= NULL;
#else
    /* 810,940T,740T,920T,926E,946E,102XE,XSCALE: cache locking not yet implemented */

    cacheLib.lockRtn		= NULL;
    cacheLib.unlockRtn		= NULL;
#endif /* (ARMCACHE == ARMCACHE_710A,720T,SA*) */

    cacheLib.flushRtn		= cacheArchFlush;
    cacheLib.invalidateRtn	= cacheArchInvalidate;
    cacheLib.clearRtn		= cacheArchClear;
    cacheLib.textUpdateRtn	= cacheArchTextUpdate;
    cacheLib.pipeFlushRtn	= (FUNCPTR) cacheArchPipeFlush;
    cacheLib.dmaMallocRtn	= (FUNCPTR) cacheArchDmaMalloc;
    cacheLib.dmaFreeRtn		= (FUNCPTR) cacheArchDmaFree;

     /* dmaVirtToPhysRtn and dmaPhysToVirt have already been set above. */

#else /* (ARMCACHE == 710A,720T,740T,810,SA*,920T,926E,940T,946E,XSCALE,102XE*/
#if (ARMCACHE != ARMCACHE_NONE)
#error CPU not supported
#endif
#endif /* (ARMCACHE == 710A,720T,740T,810,SA*,920T,926E,940T,946E,XSCALE,102XE*/

    /* check for parameter errors */

    /* None of these features are supported */

#if ((ARMCACHE == ARMCACHE_710A)   || (ARMCACHE == ARMCACHE_720T)   || \
     (ARMCACHE == ARMCACHE_740T)   || (ARMCACHE == ARMCACHE_810)    || \
     (ARMCACHE == ARMCACHE_SA110)  || (ARMCACHE == ARMCACHE_SA1100) || \
     (ARMCACHE == ARMCACHE_SA1500) || (ARMCACHE == ARMCACHE_920T)   || \
     (ARMCACHE == ARMCACHE_926E)   || (ARMCACHE == ARMCACHE_940T)   || \
     (ARMCACHE == ARMCACHE_946E)   || (ARMCACHE == ARMCACHE_XSCALE) || \
     (ARMCACHE == ARMCACHE_1020E)  || (ARMCACHE == ARMCACHE_1022E))
    if (
	(instMode & CACHE_WRITEALLOCATE)	||
	(dataMode & CACHE_WRITEALLOCATE)	||
	(instMode & CACHE_NO_WRITEALLOCATE)	||
	(dataMode & CACHE_NO_WRITEALLOCATE)	||
	(instMode & CACHE_SNOOP_ENABLE)		||
	(dataMode & CACHE_SNOOP_ENABLE)		||
	(instMode & CACHE_SNOOP_DISABLE)	||
	(dataMode & CACHE_SNOOP_DISABLE)	||
	(instMode & CACHE_BURST_ENABLE)		||
	(dataMode & CACHE_BURST_ENABLE)		||
	(instMode & CACHE_BURST_DISABLE)	||
	(dataMode & CACHE_BURST_DISABLE))
	return ERROR;
#endif

#if ((ARMCACHE == ARMCACHE_710A) || (ARMCACHE == ARMCACHE_720T) || \
     (ARMCACHE == ARMCACHE_740T) || (ARMCACHE == ARMCACHE_810))
    /* These have combined Instruction and Data caches */

    if (instMode != dataMode)
	return ERROR;
#endif

/*
 * On the following CPUs, even though it may be possible to mark pages as being
 * cached writethrough, it is not possibly to set the mode globally to
 * writethrough.
 */

#if ((ARMCACHE == ARMCACHE_810)    || (ARMCACHE == ARMCACHE_SA110)  || \
     (ARMCACHE == ARMCACHE_SA1100) || (ARMCACHE == ARMCACHE_SA1500) || \
     (ARMCACHE == ARMCACHE_920T)   || (ARMCACHE == ARMCACHE_926E)   || \
     (ARMCACHE == ARMCACHE_940T)   || (ARMCACHE == ARMCACHE_946E)   || \
     (ARMCACHE == ARMCACHE_1020E)  || (ARMCACHE == ARMCACHE_1022E))

    /* If D-cache enabled, it will be copy-back */

    if (dataMode & CACHE_WRITETHROUGH)
	return ERROR;
#endif

#if ((ARMCACHE == ARMCACHE_710A) || (ARMCACHE == ARMCACHE_740T) || \
     (ARMCACHE == ARMCACHE_720T) || (ARMCACHE == ARMCACHE_XSCALE))
    /*
     * If write-through mode, then write-buffer will not be enabled and flush
     * (write out to memory) becomes a NOP.
     */

    if (dataMode & CACHE_WRITETHROUGH)
	cacheLib.flushRtn = NULL;
#endif

#if ((ARMCACHE == ARMCACHE_926E)   || (ARMCACHE == ARMCACHE_946E)   || \
     (ARMCACHE == ARMCACHE_1020E)  || (ARMCACHE == ARMCACHE_1022E))
    /*
     * Find out what size(s) and type(s)of cache are fitted. This must
     * be done before anything else, as we will need the results in order
     * to be able to clean/flush etc.
     */

    temp = cacheIdentify();

    /* get D-cache size */

#if ((ARMCACHE == ARMCACHE_926E) || (ARMCACHE == ARMCACHE_946E))
    temp2 = (temp & 0x003C0000) >> 18;
#elif (ARMCACHE == ARMCACHE_1020E) || (ARMCACHE == ARMCACHE_1022E)
    temp2 = (temp & 0x001C0000) >> 18;
#endif

    if (temp2 == 0)
	{
#if (ARMCACHE == ARMCACHE_946E)
        /* => no D-cache is fitted */

        cacheDCacheSize = 0;
        cacheArchIndexMask = 0;

        /*
         * For the time being, simply return ERROR. Could consider setting
         * the cache flush/clean etc. function pointers to null routines.
         */

        return ERROR;
#elif (ARMCACHE == ARMCACHE_926E)
        cacheDCacheSize = 0;

        return ERROR;   /* minimum size should be 4 kbytes... */

#elif (ARMCACHE == ARMCACHE_1020E) || (ARMCACHE == ARMCACHE_1022E)
        /* D-cache is 512 kbytes in size */

/* FARKLE - This needs understanding */
        cacheDCacheSize = 512 * 1024;
#endif /* (ARMCACHE == ARMCACHE_946E) */
	}
#if ((ARMCACHE == ARMCACHE_926E) || (ARMCACHE == ARMCACHE_1020E) || \
     (ARMCACHE == ARMCACHE_1022E))
    else
        {
        /* D-cache size is 2 << (temp2 + 8) bytes. */

        cacheDCacheSize = 2 << (temp2 + 8);
        }
#endif /* (ARMCACHE == ARMCACHE_926E,1020E,1022E) */

    temp3 = (temp & 0x00003000) >> 12;

#if (ARMCACHE == ARMCACHE_946E)
    /*
     * There are (temp3 * 4) words per cache line
     * = (temp3 << 4) bytes per line.
     *
     * D-cache size is 2 << (temp2 + 8) bytes. There are 4 cache segments.
     * So, each segment is of size (2 << (temp2 + 6))
     * => number of cache lines is
     *   (2 << (temp2 + 6))/(temp << 4) or,
     *   (2 << (temp2 + 2))/temp
     */

    cacheDCacheSize = 2 << (temp2 + 8);

    cacheArchAlignSize = temp3 << 4;
    cacheArchIndexMask = ((2 << (temp2 +2))/temp3 - 1) << 5;
#elif (ARMCACHE == ARMCACHE_1020E) || (ARMCACHE == ARMCACHE_1022E)
    /*
     * There are (2 << temp3) words per cache line
     * = (2 << (temp3+2)) bytes per line.
     */

    cacheArchAlignSize = 2 << (temp3 +2);

    temp3 = (temp & 0x00038000) >> 15;

    if (temp3 == 0)
        temp3 = 1;
    else
        temp3 = 2 << (temp3 - 1);

    /*
     * associativity is temp3 =>
     * no of cache lines per segment = temp3
     *
     * So, number of segments is
     * D-cache size/cacheline size/no. of cache lines per segment
     */

    cacheArchIndexMask = (temp3 - 1) << 26;
    cacheArchSegMask = ((cacheDCacheSize / cacheArchAlignSize / temp3)- 1) << 5;
#endif /* (ARMCACHE == ARMCACHE_946E) */

    /* Get I-cache size */

#if ((ARMCACHE == ARMCACHE_926E) || (ARMCACHE == ARMCACHE_946E))
    temp2 = (temp & 0x000003C0) >> 6;
#elif (ARMCACHE == ARMCACHE_1020E) || (ARMCACHE == ARMCACHE_1022E)
    temp2 = (temp & 0x000001C0) >> 6;
#endif

    if (temp2 == 0)
	{
#if (ARMCACHE == ARMCACHE_946E)
        /* => no I-cache is fitted */

        cacheICacheSize = 0;

        /*
         * For the time being, simply return ERROR. Could consider setting
         * the cache flush/clean etc. function pointers to null routines.
         */

        return ERROR;

#elif (ARMCACHE == ARMCACHE_926E)
        cacheICacheSize = 0;

        return ERROR;   /* mimimum size should be 4 kbytes ... */

#elif (ARMCACHE == ARMCACHE_1020E) || (ARMCACHE == ARMCACHE_1022E)
/* FARKLE */
        cacheICacheSize = 512 * 1024;
#endif /* (ARMCACHE == ARMCACHE_946E) */
        }
    else
	cacheICacheSize = 2 << (temp2 + 8);

#endif /* (ARMCACHE == ARMCACHE_926E, 946E, 1020E, 1022E) */

    /*
     * Turn off and invalidate all caches. This will have been done in hardware
     * on reset, but we may not get here from reset.
     */

#if ((ARMCACHE == ARMCACHE_710A)   || (ARMCACHE == ARMCACHE_720T)   || \
     (ARMCACHE == ARMCACHE_740T)   || (ARMCACHE == ARMCACHE_810)    || \
     (ARMCACHE == ARMCACHE_SA110)  || (ARMCACHE == ARMCACHE_SA1100) || \
     (ARMCACHE == ARMCACHE_SA1500) || (ARMCACHE == ARMCACHE_920T)   || \
     (ARMCACHE == ARMCACHE_926E)   || (ARMCACHE == ARMCACHE_940T)   || \
     (ARMCACHE == ARMCACHE_946E)   || (ARMCACHE == ARMCACHE_XSCALE) || \
     (ARMCACHE == ARMCACHE_1020E)  || (ARMCACHE == ARMCACHE_1022E))
    /*
     * Clear D-cache, disable it, switch off Write Buffer (if appropriate),
     * invalidate all D-cache, drain Write Buffer.
     */

    cacheDClearDisable ();

#if ARMCACHE_NEEDS_IMB
    /*
     * We need to be able to issue an IMB instruction (a SWI). We may
     * be called here from cacheLibInit() which can occur before
     * exception handling has been initialized. So, check the SWI vector
     * does not still contain zero, (as it would after RAM has been
     * cleared) and patch a return instruction (MOVS pc,lr) into the SWI
     * vector now, if necessary, so that we can issue an IMB.
     */

    if (*(UINT32 *)EXC_OFF_SWI == 0)
	*(UINT32 *)EXC_OFF_SWI = IOP_MOVS_PC_LR;

    cacheIMB ();			/* execute IMB to flush Prefetch Unit */
#endif /* ARMCACHE_NEEDS_IMB */

#if ((ARMCACHE == ARMCACHE_SA110)  || (ARMCACHE == ARMCACHE_SA1100) || \
     (ARMCACHE == ARMCACHE_SA1500) || (ARMCACHE == ARMCACHE_920T)   || \
     (ARMCACHE == ARMCACHE_926E)   || (ARMCACHE == ARMCACHE_940T)   || \
     (ARMCACHE == ARMCACHE_946E)   || (ARMCACHE == ARMCACHE_XSCALE) || \
     (ARMCACHE == ARMCACHE_1020E)  || (ARMCACHE == ARMCACHE_1022E))

    /* Disable and clear (=flush and invalidate) I-cache */

#if (ARMCACHE == ARMCACHE_SA1500)
    /*
     * On certain revisions of the SA-1500 silicon, we must not run
     * with I-cache disabled. The startup code will have enabled the
     * I-cache, and we must not disable it here, so instead of calling
     * IClearDisable(), just invalidate all of the I-cache instead.
     */

    if ((sysCacheArchFlags & ARM_CACHE_FLAG_I_ENABLED) != 0)
	cacheIInvalidateAll();
    else
#else
	cacheIClearDisable ();
#endif /* (ARMCACHE == ARMCACHE_SA1500) */
#endif /* ARMCACHE == SA110,1100,1500,940T,920T,926E,940T,946E,XSCALE,1020E,1022E */

#endif /* 710A, 720T, 740T, 810, SA*, 920T, 926E, 940T, 946E, XSCALE, 1020E, 1022E */

    /*
     * The following code will also be produced for the "dummy"
     * cacheArchLibInit required for the ARM7TDMI.
     */

    cacheDataMode	= dataMode;	/* save dataMode for enable */
    cacheDataEnabled	= FALSE;	/* D-cache is currently off */
    cacheMmuAvailable	= FALSE;	/* No MMU yet. This will be */
					/* set true by vm(Base)LibInit() */
    initialized = TRUE;

    return OK;

    } /* cacheArchLibInit() */


/*
 * Rest of code in this file is only applicable if some form(s) of cache are
 * present.
 */

#if (ARMCACHE != ARMCACHE_NONE)

/*******************************************************************************
*
* cacheArchEnable - enable an ARM cache
*
* This routine enables the specified ARM instruction or data cache. The cache
* can only be enabled together with the MMU. Operation with the cache enabled
* (except for the I-cache on StrongARM) when the MMU is not enabled will lead
* to architecturally undefined behavior. Thus, if called to enable a D-cache
* and the MMU is not on, we merely note that we require the cache to be on and
* when the MMU is next switched on, the cache will be enabled.
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
	return ERROR;		/* invalid cache */

    if (!cacheIsOn (cache))		/* if cache not already on */
	{
#if ((ARMCACHE == ARMCACHE_710A) || (ARMCACHE == ARMCACHE_720T) || \
     (ARMCACHE == ARMCACHE_740T) || (ARMCACHE == ARMCACHE_810))
	cacheDInvalidateAll ();	/* Invalidate all cache entries */

#if ((ARMCACHE == ARMCACHE_710A) || (ARMCACHE == ARMCACHE_720T) || \
     (ARMCACHE == ARMCACHE_740T))
	if (cacheDataMode == CACHE_COPYBACK)
	    {
	    /* want ID-cache and write buffer on */

	    cacheArchState = MMUCR_C_ENABLE | MMUCR_W_ENABLE;
	    }
	else
	    {
	    /* write-through, only want ID-cache on */

	    cacheArchState = MMUCR_C_ENABLE;
	    }
#else /* it is 810 */
#ifdef BPRED_SUPPORT
	/* 810: want ID-cache, write buffer and Branch Prediction on */

	cacheArchState = MMUCR_C_ENABLE | MMUCR_W_ENABLE | MMUCR_Z_ENABLE;
#else
	/* 810: want ID-cache and write buffer on */

	cacheArchState = MMUCR_C_ENABLE | MMUCR_W_ENABLE;
#endif /* BPRED_SUPPORT */
#endif /* (ARMCACHE == ARMCACHE_710A,720T,740T) */

	/*
	 * Only actually enable the cache if MMU is already on, else it will
	 * be done later by mmuEnable(), as will the setting of
	 * cacheDataEnabled and the calling of cacheFuncsSet().
	 * Only change those bits that require setting, relying on the
	 * current state of the MMUCR.
	 */

	oldLevel = intIFLock ();
	if (cacheMmuIsOn ())
	    {
	    cacheDataEnabled = TRUE;
	    cacheFuncsSet ();
	    mmuModifyCr (cacheArchState, cacheArchState);
	    }
	intIFUnlock (oldLevel);
#endif /* (ARMCACHE == ARMCACHE_710A,810,740T,720T) */

#if ((ARMCACHE == ARMCACHE_SA110)  || (ARMCACHE == ARMCACHE_SA1100) || \
     (ARMCACHE == ARMCACHE_SA1500) || (ARMCACHE == ARMCACHE_920T)   || \
     (ARMCACHE == ARMCACHE_926E)   || (ARMCACHE == ARMCACHE_XSCALE) || \
     (ARMCACHE == ARMCACHE_1020E)  || (ARMCACHE == ARMCACHE_1022E))
	if (cache == DATA_CACHE)
	    {
	    cacheDInvalidateAll ();	/* Invalidate all cache entries */

	    /*
	     * Keep a note that we are turning D-cache and write buffer
             * on. On 920T, 926E, 1020E, 1022E, W bit is Should Be One, and will
             * remain on.
             */

	    cacheArchState = MMUCR_C_ENABLE | MMUCR_W_ENABLE;

	    /*
	     * Only actually enable the cache if MMU is already on, else it will
	     * be done later by mmuEnable(), as will the setting of
	     * cacheDataEnabled and the calling of cacheFuncsSet().
	     * Only change those bits that require setting, relying on the
	     * current state of the MMUCR.
	     */

	    oldLevel = intIFLock ();
	    if (cacheMmuIsOn ())
		{
		cacheDataEnabled = TRUE;
		cacheFuncsSet ();
		mmuModifyCr (cacheArchState, cacheArchState);
		}
	    intIFUnlock (oldLevel);
	    } /* endif data cache */
	else
	    {
	    /* Instruction cache */

	    cacheIInvalidateAll ();	/* Invalidate all cache tags */
	    mmuModifyCr (MMUCR_I_ENABLE, MMUCR_I_ENABLE); /* turn the cache on*/
	    }
#endif /* (ARMCACHE == ARMCACHE_SA*,920T,XSCALE, 1020E,1022E) */

#if ((ARMCACHE == ARMCACHE_940T) || (ARMCACHE == ARMCACHE_946E))
    /* 940T I-cache cannot be enabled without MMU */

	if (cache == DATA_CACHE)
	    {
	    cacheDInvalidateAll ();	/* Invalidate all cache entries */

	    /* Keep a note that turning D-cache on, W bit is Should Be One */

	    cacheArchState |= (MMUCR_C_ENABLE | MMUCR_W_ENABLE);
	    }
	else
	    {
	    /* Instruction cache */

	    cacheIInvalidateAll ();	/* Invalidate all cache tags */

	    cacheArchState |= MMUCR_I_ENABLE;	/* note turning I-cache on */
	    }

	/*
	 * Only actually enable either cache if MMU is already on, else it will
	 * be done later by mmuEnable(), as will the setting of
	 * cacheDataEnabled and the calling of cacheFuncsSet().
	 * Only change those bits that require setting, relying on the
	 * current state of the MMUCR.
	 */

	oldLevel = intIFLock ();
	if (cacheMmuIsOn ())
	    {
	    cacheDataEnabled = TRUE;
	    cacheFuncsSet ();
	    mmuModifyCr (cacheArchState, cacheArchState);
	    }
	intIFUnlock (oldLevel);
#endif /* (ARMCACHE == ARMCACHE_940T,946E) */

#if ARMCACHE_NEEDS_IMB
	if (cache == INSTRUCTION_CACHE)
	    /*
	     * If they've asked to enable the I-cache, we'd better flush the
	     * prefetch unit by doing an Instruction Memory Barrier (IMB
	     * instruction).
	     */

	    cacheIMB ();
#endif /* ARMCACHE_NEEDS_IMB */

	} /* endif cache not already enabled */

    return OK;

    } /* cacheArchEnable() */

/*******************************************************************************
*
* cacheArchDisable - disable an ARM cache
*
* This routine flushes, clears and disables the specified ARM instruction or
* data cache.
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
    if (cacheProbe (cache) != OK)
	return ERROR;		/* invalid cache */

    if (cacheIsOn (cache))		/* already off? */
	{
#if ((ARMCACHE == ARMCACHE_710A) || (ARMCACHE == ARMCACHE_720T) || \
     (ARMCACHE == ARMCACHE_740T) || (ARMCACHE == ARMCACHE_810))
	/* keep a note that we have disabled the cache */

	cacheArchState = 0;

	/*
	 * Clear (flush and invalidate) D-cache, drain W/Buffer, disable
	 * D-cache, switch off Write Buffer.
	 */

	cacheDClearDisable ();

	cacheDataEnabled = FALSE;	/* data cache is off */
	cacheFuncsSet ();		/* update data function ptrs */
#endif /* 710A, 720T, 740T */

#if ((ARMCACHE == ARMCACHE_SA110)  || (ARMCACHE == ARMCACHE_SA1100) || \
     (ARMCACHE == ARMCACHE_SA1500))
	if (cache == DATA_CACHE)
	    {
	    /* keep a note that we have disabled the cache */

	    cacheArchState = 0;

	    /*
	     * Clear (flush and invalidate) D-cache, drain W/Buffer, disable
	     * D-cache, switch off Write Buffer.
	     */

	    cacheDClearDisable ();

	    cacheDataEnabled = FALSE;	/* data cache is off */
	    cacheFuncsSet ();		/* update data function ptrs */
	    }
	else
	    /* Instruction cache: disable, flush I-cache and do branch */

	    cacheIClearDisable ();
#endif /* SA110, SA1100, SA1500 */

#if ((ARMCACHE == ARMCACHE_920T)   || (ARMCACHE == ARMCACHE_926E)   || \
     (ARMCACHE == ARMCACHE_940T)   || (ARMCACHE == ARMCACHE_946E)   || \
     (ARMCACHE == ARMCACHE_XSCALE) || (ARMCACHE == ARMCACHE_1020E)  || \
     (ARMCACHE == ARMCACHE_1022E))
	if (cache == DATA_CACHE)
	    {
	    /* note that we have disabled the cache. W bit is Should Be One */

	    cacheArchState &= ~MMUCR_C_ENABLE;

	    /*
	     * Clear (flush and invalidate) D-cache, drain W/Buffer, disable
	     * D-cache.
	     */

	    cacheDClearDisable ();

	    cacheDataEnabled = FALSE;	/* data cache is off */
	    cacheFuncsSet ();		/* update data function ptrs */
	    }
	else
	    {
	    /*
	     * Instruction cache: note disabling, disable, flush
	     * I-cache and do branch. On 920T, don't need to keep note
	     * of I-cache setting, only on 940T, where I-cache cannot be
	     * enabled without MMU.
	     */

#if ((ARMCACHE == ARMCACHE_940T) || (ARMCACHE == ARMCACHE_946E))
	    cacheArchState &= ~MMUCR_I_ENABLE;
#endif

	    cacheIClearDisable ();
	    }
#endif /* 920T, 926E, 940T, 946E, XSCALE, 1020E, 1022E */

#if ARMCACHE_NEEDS_IMB
	if (cache == INSTRUCTION_CACHE)
	    /*
	     * If they've asked to enable the I-cache, we'd better flush the
	     * prefetch unit by doing an Instruction Memory Barrier (IMB
	     * instruction).
	     */

	    cacheIMB ();
#endif /* ARMCACHE_NEEDS_IMB */
	} /* endif cache was on */

    return OK;

    } /* cacheArchDisable() */

/*******************************************************************************
*
* cacheArchFlush - flush entries from an ARM cache
*
* This routine flushes (writes out to memory) some or all entries from the
* specified ARM cache and drains write-buffer, if appropriate.
*
* RETURNS: OK, or ERROR if the cache type is invalid or the cache control
* is not supported.
*
* NOMANUAL
*/

LOCAL STATUS cacheArchFlush
    (
    CACHE_TYPE	cache,		/* cache to flush */
    void *	address,	/* address to flush */
    size_t	bytes		/* bytes to flush */
    )
    {
    if (cacheProbe (cache) != OK)
	return ERROR;		/* invalid cache */

#if ((ARMCACHE == ARMCACHE_710A) || (ARMCACHE == ARMCACHE_720T) || \
     (ARMCACHE == ARMCACHE_740T))
    cacheArchPipeFlush ();	/* drain W/B */
#endif

#if ((ARMCACHE == ARMCACHE_810)    || (ARMCACHE == ARMCACHE_SA110)  || \
     (ARMCACHE == ARMCACHE_SA1100) || (ARMCACHE == ARMCACHE_SA1500) || \
     (ARMCACHE == ARMCACHE_920T)   || (ARMCACHE == ARMCACHE_926E)   || \
     (ARMCACHE == ARMCACHE_940T)   || (ARMCACHE == ARMCACHE_946E)   || \
     (ARMCACHE == ARMCACHE_XSCALE) || (ARMCACHE == ARMCACHE_1020E)  || \
     (ARMCACHE == ARMCACHE_1022E))
    if (cache == DATA_CACHE)
	{
	if ((bytes == ENTIRE_CACHE) ||
#if (ARMCACHE == ARMCACHE_810)
	    /*
	     * On 810, to flush an individual address, we actually end up
	     * flushing much more. If the address range corresponds to 8
	     * segments or more, we might as well do the lot and be done with
	     * it.
	     */
	    (bytes >= (_CACHE_ALIGN_SIZE * 8)))
#endif
#if (ARMCACHE == ARMCACHE_940T)
	    /* similar arguments on 940T, for 4 segments or more */

	    (bytes >= (_CACHE_ALIGN_SIZE * 4)))
#endif
#if ((ARMCACHE == ARMCACHE_SA110)  || (ARMCACHE == ARMCACHE_SA1100) || \
     (ARMCACHE == ARMCACHE_SA1500) || (ARMCACHE == ARMCACHE_920T)   || \
     (ARMCACHE == ARMCACHE_926E)   || (ARMCACHE == ARMCACHE_946E)   || \
     (ARMCACHE == ARMCACHE_XSCALE) || (ARMCACHE == ARMCACHE_1020E)  || \
     (ARMCACHE == ARMCACHE_1022E))
	    (bytes >= D_CACHE_SIZE))
#endif
	    cacheDFlushAll ();	/* also drains W/B */
	else
	    {
	    /* not doing all the cache, do the area requested */

	    bytes += (size_t) address;
	    address = (void *) ((UINT) address & ~(_CACHE_ALIGN_SIZE - 1));

	    do
		{
		cacheDFlush (address);
		address = (void *) ((UINT) address + _CACHE_ALIGN_SIZE);
		}
	    while ((size_t) address < bytes);

	    cacheArchPipeFlush ();	/* drain write buffer */
	    }
	} /* endif data cache */

    /* else I-cache. No need to do anything as I-cache is read-only. */

#endif

    return OK;

    } /* cacheArchFlush() */

/*******************************************************************************
*
* cacheArchInvalidate - invalidate entries from an ARM cache
*
* This routine invalidates some or all entries from the specified ARM cache.
*
* RETURNS: OK, or ERROR if the cache type is invalid or the cache control
* is not supported.
*
* NOMANUAL
*/

LOCAL STATUS cacheArchInvalidate
    (

    CACHE_TYPE	cache, 		/* cache to clear */
    void *	address,	/* address to clear */
    size_t	bytes		/* bytes to clear */
    )
    {
    if (cacheProbe (cache) != OK)
	return ERROR;		/* invalid cache */

#if ((ARMCACHE == ARMCACHE_710A) || (ARMCACHE == ARMCACHE_720T) || \
     (ARMCACHE == ARMCACHE_740T))
    cacheDInvalidateAll ();	/* Cannot invalidate individual lines */
#endif

#if (ARMCACHE == ARMCACHE_810)
    /*
     * On 810, to invalidate an individual address, we actually end
     * up invalidating much more, so we need to flush it first, to avoid
     * invalidating some dirty data.  If the address range corresponds to 8
     * segments or more, we might as well do the lot and be done with it. If
     * the user has actually asked to invalidate all the cache, then we can
     * actually do an invalidate of all the cache, not a clear.
     */

    if (cache == DATA_CACHE)
	{
	if (bytes == ENTIRE_CACHE)
	    cacheDInvalidateAll();
	else
	    if (bytes >= (_CACHE_ALIGN_SIZE * 8))
		cacheDClearAll();
	    else
		{
		bytes += (size_t) address;
		address = (void *) ((UINT) address & ~(_CACHE_ALIGN_SIZE - 1));

		do
		    {
		    cacheDClear (address);
		    address = (void *) ((UINT) address + _CACHE_ALIGN_SIZE);
		    }
		while ((size_t) address < bytes);

		cacheArchPipeFlush ();	/* drain write buffer */
		}
	}
    else
	{
	/* Instruction cache */

	if (bytes == ENTIRE_CACHE)
	    cacheIMB ();	/* Execute IMB to flush Prefetch Unit */
	else
	    cacheIMBRange(address, (INSTR *) ((UINT32)address + bytes));
	}
#endif

#if ((ARMCACHE == ARMCACHE_SA110)  || \
     (ARMCACHE == ARMCACHE_SA1100) || (ARMCACHE == ARMCACHE_SA1500))
    if (cache == DATA_CACHE)
	if (bytes == ENTIRE_CACHE)
	    cacheDInvalidateAll ();
	else
	    {
	    bytes += (size_t) address;
	    address = (void *) ((UINT) address & ~(_CACHE_ALIGN_SIZE - 1));

	    do
		{
		cacheDInvalidate (address);
		address = (void *) ((UINT) address + _CACHE_ALIGN_SIZE);
		}
	    while ((size_t) address < bytes);
	    }
    else
	/* I-cache */
	cacheIInvalidateAll ();	/* Cannot invalidate individual lines */
#endif

    /*
     * The if (bytes == ENTIRE_CACHE) used to be (== ENTIRE_CACHE) ||
     * (bytes >= D_CACHE_SIZE), which would invalidate unexpected bits of
     * the cache. Fixes SPR #30698.
     */

#if ((ARMCACHE == ARMCACHE_920T)   || (ARMCACHE == ARMCACHE_926E)   || \
     (ARMCACHE == ARMCACHE_946E)   || (ARMCACHE == ARMCACHE_XSCALE) || \
     (ARMCACHE == ARMCACHE_1020E)  || (ARMCACHE == ARMCACHE_1022E))
    if (cache == DATA_CACHE)
	if (bytes == ENTIRE_CACHE)
	    cacheDInvalidateAll ();
	else
	    {
	    bytes += (size_t) address;
	    address = (void *) ((UINT) address & ~(cacheArchAlignSize - 1));

	    do
		{
		cacheDInvalidate (address);
		address = (void *) ((UINT) address + cacheArchAlignSize);
		}
	    while ((size_t) address < bytes);
	    }
    else	/* I-cache */
	if ((bytes == ENTIRE_CACHE) || (bytes >= I_CACHE_SIZE))
	    cacheIInvalidateAll ();
	else
	    {
#if (ARMCACHE == ARMCACHE_XSCALE)
	    /* visionProbe will not operate correctly with single line flushes*/
	    cacheIInvalidateAll ();
#else
	    bytes += (size_t) address;
	    address = (void *) ((UINT) address & ~(cacheArchAlignSize - 1));

	    do
		{
		cacheIInvalidate (address);
#if (ARMCACHE == ARMCACHE_XSCALE)
		btbInvalidate ();
#endif /* (ARMCACHE == ARMCACHE_XSCALE) */
		address = (void *) ((UINT) address + cacheArchAlignSize);
		}
	    while ((size_t) address < bytes);
#endif /* (ARMCACHE == XSCALE) */
	    }
#endif /* (ARMCACHE == ARMCACHE_920T,926E,946E,XSCALE,1020E,1022E) */

#if (ARMCACHE == ARMCACHE_940T)
    /*
     * On 940T, we also end up invalidating much more, so we need to
     * flush it first, to avoid invalidating some dirty data.  If the
     * address range corresponds to 4 segments or more, we might as well
     * do the lot and be done with it. If the user has actually asked to
     * invalidate all the cache, then we can actually do an invalidate of
     * all the cache, not a clear.
     */

    if (cache == DATA_CACHE)
	{
	if (bytes == ENTIRE_CACHE)
	    cacheDInvalidateAll();
	else
	    if (bytes >= (_CACHE_ALIGN_SIZE * 4))
		cacheDClearAll();
	    else
		{
		bytes += (size_t) address;
		address = (void *) ((UINT) address & ~(_CACHE_ALIGN_SIZE - 1));

		do
		    {
		    cacheDClear (address);
		    address = (void *) ((UINT) address + _CACHE_ALIGN_SIZE);
		    }
		while ((size_t) address < bytes);

		cacheArchPipeFlush ();	/* drain write buffer */
		}
	}
    else
	{
	/* Instruction cache */

	if (bytes == ENTIRE_CACHE)
	    cacheIInvalidateAll();
	else
	    if (bytes >= (_CACHE_ALIGN_SIZE * 4))
		cacheIInvalidateAll();
	    else
		{
		bytes += (size_t) address;
		address = (void *) ((UINT) address & ~(_CACHE_ALIGN_SIZE - 1));

		do
		    {
		    cacheIInvalidate (address);
		    address = (void *) ((UINT) address + _CACHE_ALIGN_SIZE);
		    }
		while ((size_t) address < bytes);
		}
	}
#endif

    return OK;

    } /* cacheArchInvalidate() */

/*******************************************************************************
*
* cacheArchClear - clear (flush and invalidate) entries from an ARM cache
*
* This routine clears some or all entries from the specified ARM cache.
*
* RETURNS: OK, or ERROR if the cache type is invalid or the cache control
* is not supported.
*
* NOMANUAL
*/

LOCAL STATUS cacheArchClear
    (
    CACHE_TYPE	cache,		/* cache to clear */
    void *	address,	/* address to clear */
    size_t	bytes		/* bytes to clear */
    )
    {
    if (cacheProbe (cache) != OK)
	return ERROR;		/* invalid cache */

#if ((ARMCACHE == ARMCACHE_710A) || (ARMCACHE == ARMCACHE_720T) || \
     (ARMCACHE == ARMCACHE_740T))
    cacheDClearAll ();	/* also drains write-buffer */
#endif

#if ((ARMCACHE == ARMCACHE_810)    || (ARMCACHE == ARMCACHE_SA110)  || \
     (ARMCACHE == ARMCACHE_SA1100) || (ARMCACHE == ARMCACHE_SA1500) || \
     (ARMCACHE == ARMCACHE_920T)   || (ARMCACHE == ARMCACHE_926E)   || \
     (ARMCACHE == ARMCACHE_940T)   || (ARMCACHE == ARMCACHE_946E)   || \
     (ARMCACHE == ARMCACHE_XSCALE) || (ARMCACHE == ARMCACHE_1020E)  || \
     (ARMCACHE == ARMCACHE_1022E))
    if (cache == DATA_CACHE)
	if ((bytes == ENTIRE_CACHE) ||
#if (ARMCACHE == ARMCACHE_810)
	/*
	 * On 810, to flush an individual address, we actually end up
	 * flushing much more. If the address range corresponds to 8
	 * segments or more, we might as well do the lot and be done with
	 * it.
	 */
	    (bytes >= (_CACHE_ALIGN_SIZE * 8)))
#endif /* (ARMCACHE == ARMCACHE_810) */

#if (ARMCACHE == ARMCACHE_940T)
	    /* similar arguments on 940T, for 4 segments or more */

	    (bytes >= (_CACHE_ALIGN_SIZE * 4)))
#endif

#if ((ARMCACHE == ARMCACHE_SA110)  || (ARMCACHE == ARMCACHE_SA1100) || \
     (ARMCACHE == ARMCACHE_SA1500) || (ARMCACHE == ARMCACHE_920T)   || \
     (ARMCACHE == ARMCACHE_926E)   || (ARMCACHE == ARMCACHE_946E)   || \
     (ARMCACHE == ARMCACHE_XSCALE) || (ARMCACHE == ARMCACHE_1020E)  || \
     (ARMCACHE == ARMCACHE_1022E))
	    (bytes >= D_CACHE_SIZE))
#endif
	    cacheDClearAll ();	/* also drains write-buffer */
	else
	    {
	    bytes += (size_t) address;
	    address = (void *) ((UINT) address & ~(_CACHE_ALIGN_SIZE - 1));

	    do
		{
		cacheDClear (address);
		address = (void *) ((UINT) address + _CACHE_ALIGN_SIZE);
		}
	    while ((size_t) address < bytes);

	    cacheArchPipeFlush ();	/* drain write buffer */
	    }
    else
	{
	/*
	 * I-cache. Cache is effectively read-only, so flush is a null
	 * operation, so only need to invalidate the cache.
	 */

#if ((ARMCACHE == ARMCACHE_SA110)  || \
     (ARMCACHE == ARMCACHE_SA1100) || (ARMCACHE == ARMCACHE_SA1500))
	cacheIInvalidateAll ();	/* Cannot clear individual lines */
#endif

#if ((ARMCACHE == ARMCACHE_920T)   || (ARMCACHE == ARMCACHE_926E)   || \
     (ARMCACHE == ARMCACHE_946E)   || (ARMCACHE == ARMCACHE_XSCALE) || \
     (ARMCACHE == ARMCACHE_1020E)  || (ARMCACHE == ARMCACHE_1022E))
	if ((bytes == ENTIRE_CACHE) || (bytes >= I_CACHE_SIZE))
	    cacheIInvalidateAll ();
	else
	    {
#if(ARMCACHE == ARMCACHE_XSCALE)
	    cacheIInvalidateAll ();
#else
	    bytes += (size_t) address;
	    address = (void *) ((UINT) address & ~(_CACHE_ALIGN_SIZE - 1));

	    do
		{
		cacheIInvalidate (address);
#if (ARMCACHE == ARMCACHE_XSCALE)
		btbInvalidate ();
#endif /* (ARMCACHE == ARMCACHE_XSCALE) */
		address = (void *) ((UINT) address + _CACHE_ALIGN_SIZE);
		}
	    while ((size_t) address < bytes);
#endif /* (ARMCACHE == ARMCACHE_XSCALE) */
	    }
#endif /* (ARMCACHE == ARMCACHE_920T,946E,XSCALE) */

#if (ARMCACHE == ARMCACHE_940T)
	if (bytes == ENTIRE_CACHE)
	    cacheIInvalidateAll();
	else
	    if (bytes >= (_CACHE_ALIGN_SIZE * 4))
		cacheIInvalidateAll();
	    else
		{
		bytes += (size_t) address;
		address = (void *) ((UINT) address & ~(_CACHE_ALIGN_SIZE - 1));

		do
		    {
		    cacheIInvalidate (address);
		    address = (void *) ((UINT) address + _CACHE_ALIGN_SIZE);
		    }
		while ((size_t) address < bytes);
		}
#endif /* (ARMCACHE == ARMCACHE_940T) */

#if ARMCACHE_NEEDS_IMB
	if (bytes == ENTIRE_CACHE)
	    cacheIMB ();		/* Execute IMB to flush Prefetch Unit */
	else
	    cacheIMBRange(address, (INSTR *) ((UINT32)address + bytes));
#endif

	} /* endelse I-cache */

#endif /* ARMCACHE == ARMCACHE_810, SA*, 920T, 940T, 946E, XSCALE, 1020E,1022E */

    return OK;

    } /* cacheArchClear() */

/*******************************************************************************
*
* cacheArchTextUpdate - synchronize the ARM instruction and data caches
*
* This routine flushes the ARM data cache and drains the write-buffer, if
* appropriate, and then invalidates the instruction cache.  The instruction
* cache is forced to fetch code that may have been created via the data path.
*
* RETURNS: OK, or ERROR if the cache type is invalid or the cache control
* is not supported.
*
* NOMANUAL
*/

LOCAL STATUS cacheArchTextUpdate
    (
    void *	address,	/* virtual address */
    size_t	bytes		/* number of bytes to update */
    )
    {
#if (ARMCACHE == ARMCACHE_810)
    int oldLevel, stat;
#endif

#if ((ARMCACHE == ARMCACHE_710A) || (ARMCACHE == ARMCACHE_740T) || \
     (ARMCACHE == ARMCACHE_720T))
    cacheArchPipeFlush ();

    return cacheArchInvalidate (INSTRUCTION_CACHE, address, bytes);
#endif

#if (ARMCACHE == ARMCACHE_810)
    /*
     * There is an argument that all we need to do here is an IMB,
     * but play safe for the moment.
     *
     * 810 is a combined ID-cache: when invalidating the "I-cache" we
     * will be invalidating the ID-cache, so we must lock interrupts
     * between cleaning the cache and invalidating it.
     */

    oldLevel = cacheArchIntLock();
    if (cacheArchFlush (DATA_CACHE, address, bytes) == OK)
	stat = cacheArchInvalidate (INSTRUCTION_CACHE, address, bytes);
    else
	stat = ERROR;
    intIFUnlock (oldLevel);

    return stat;
#endif /* (ARMCACHE == ARMCACHE_810) */

#if ((ARMCACHE == ARMCACHE_SA110)  || (ARMCACHE == ARMCACHE_SA1100) || \
     (ARMCACHE == ARMCACHE_SA1500) || (ARMCACHE == ARMCACHE_920T)   || \
     (ARMCACHE == ARMCACHE_926E)   || (ARMCACHE == ARMCACHE_940T)   || \
     (ARMCACHE == ARMCACHE_946E)   || (ARMCACHE == ARMCACHE_XSCALE) || \
     (ARMCACHE == ARMCACHE_1020E)  || (ARMCACHE == ARMCACHE_1022E))
    /* Harvard caches: should be able to invalidate the I-cache with impunity */

    if (cacheArchFlush (DATA_CACHE, address, bytes) == OK)
	return cacheArchInvalidate (INSTRUCTION_CACHE, address, bytes);
    else
	return ERROR;
#endif /* ARMCACHE = SA110,1100,1500,920T,940T,946E,XSCALE,1020E,1022E */

    } /* cacheArchTextUpdate() */

/*******************************************************************************
*
* cacheArchDmaMalloc - allocate a cache-safe buffer
*
* This routine attempts to return a pointer to a section of memory
* that will not experience cache coherency problems.  This routine
* is only called when MMU support is available for cache control.
*
* INTERNAL
* The above comment about being called only when MMU support is available is
* present in all the other architectures. It is not clear that this is
* necessarily true.
*
* INTERNAL
* We check if the cache is actually on before allocating the memory.  It
* is possible that the user wants Memory Management Unit (MMU)
* support but does not need caching.
*
* RETURNS: A pointer to a cache-safe buffer, or NULL.
*
* SEE ALSO: cacheArchDmaFree(), cacheDmaMalloc()
*
* NOMANUAL
*/

LOCAL void * cacheArchDmaMalloc
    (
    size_t	bytes	/* size of cache-safe buffer */
    )
    {
    void *	pBuf;
    int		pageSize;

    /*
     * This seems dangerous, as the buffer could be allocated and then the
     * cache could be switched on later. However, it is what the other
     * architectures do.
     */

    if (!cacheIsOn (DATA_CACHE))
	{
	/* If cache is off, just allocate buffer */

	return malloc (bytes);
	}

    if ((pageSize = VM_PAGE_SIZE_GET ()) == ERROR)
	return NULL;

    /* make sure bytes is a multiple of pageSize */

    bytes = ROUND_UP (bytes, pageSize);

#if (!ARM_HAS_MPU)
    if ((_func_valloc == NULL) ||
	((pBuf = (void *)(* _func_valloc) (bytes)) == NULL))
	return NULL;

#else /* (!ARM_HAS_MPU) */
    /*
     * On MPUs, regions must be aligned with their size, which must be
     * a power of two and at least 4k in size.
     *
     * Round up to a power of two in size.
     */

    bytes = ROUND_UP (bytes, (1 << (ffsMsb(bytes) - 1)));

    if ((_func_memalign == NULL) ||
	((pBuf = (void *)(* _func_memalign) (bytes, bytes)) == NULL))
	return NULL;

#endif /* (!ARM_HAS_MPU) */

    /*
     * Note that on MPUs we need to specify VM_STATE_VALID here, in
     * order that a new region will be created, if necessary, and that
     * that region will be marked as active, with appropriate access
     * rights. We should also free the allocate buffer and return NULL
     * if the VM_STATE_SET call fails. This fixes SPR #30697.
     */

    if (VM_STATE_SET (NULL, pBuf, bytes,
		  VM_STATE_MASK_CACHEABLE | VM_STATE_MASK_VALID,
		  VM_STATE_CACHEABLE_NOT | VM_STATE_VALID) != OK)
	{
	free (pBuf);
	return NULL;
	}

    return pBuf;

    } /* cacheArchDmaMalloc() */

/*******************************************************************************
*
* cacheArchDmaFree - free the buffer acquired by cacheArchDmaMalloc()
*
* This routine returns to the free memory pool a block of memory previously
* allocated with cacheArchDmaMalloc().  The buffer is marked cacheable.
*
* RETURNS: OK, or ERROR if cacheArchDmaMalloc() cannot be undone.
*
* SEE ALSO: cacheArchDmaMalloc(), cacheDmaFree()
*
* NOMANUAL
*/

LOCAL STATUS cacheArchDmaFree
    (
    void *	pBuf		/* ptr returned by cacheArchDmaMalloc() */
    )
    {
    BLOCK_HDR *	pHdr;		/* pointer to block header */
    STATUS	status = OK;	/* return value */

    /* changed to vmLibInstalled or BaseLibInstalled fixes SPR #22407 */

    if (cacheIsOn (DATA_CACHE) &&
	(vmLibInfo.vmLibInstalled || vmLibInfo.vmBaseLibInstalled))
	{
	pHdr = BLOCK_TO_HDR (pBuf);
	status = VM_STATE_SET (NULL,pBuf,(pHdr->nWords * 2) - sizeof(BLOCK_HDR),
			       VM_STATE_MASK_CACHEABLE, VM_STATE_CACHEABLE);
	}

    free (pBuf);	/* free buffer after modified */

    return status;

    } /* cacheArchDmaFree() */

/*******************************************************************************
*
* cacheProbe - test for the presence of a type of cache
*
* This routine returns status with regard to the presence of a particular
* type of cache.
*
* RETURNS: OK, or ERROR if the cache type is invalid or the cache control
* is not supported.
*
* CAVEATS
* On ARM710A/810/740T/720T we return present for both data and
* instruction cache as they have one mixed instruction and data cache.
*
*/

LOCAL STATUS cacheProbe
    (
    CACHE_TYPE	cache	/* cache to test */
    )
    {
    if ((cache == INSTRUCTION_CACHE) || (cache == DATA_CACHE))
	return OK;

    errno = S_cacheLib_INVALID_CACHE;	/* set errno */

    return ERROR;

    } /* cacheProbe() */

/*****************************************************************************
*
* cacheIsOn - boolean function to return state of cache
*
* This routine returns the state of the specified cache.  The cache is
* assumed to exist.
*
* RETURNS: TRUE, if specified cache is enabled, FALSE otherwise.
*/

LOCAL BOOL cacheIsOn
    (
    CACHE_TYPE	cache	/* cache to examine state */
    )
    {
#if ((ARMCACHE == ARMCACHE_940T) || (ARMCACHE == ARMCACHE_946E))
    /* return whether we have been *asked* to enable the cache in question */
    if (cache == INSTRUCTION_CACHE)
	return (cacheArchState & MMUCR_I_ENABLE);
    else
	return (cacheArchState & MMUCR_C_ENABLE);

#elif ((ARMCACHE == ARMCACHE_920T)   || (ARMCACHE == ARMCACHE_926E)   || \
       (ARMCACHE == ARMCACHE_1020E)  || (ARMCACHE == ARMCACHE_1022E))
    if (cache == INSTRUCTION_CACHE)
	{
	/* return whether actually enabled */

	return (mmuCrGet() & MMUCR_I_ENABLE);
	}
    else
	{
	/* return whether we have been asked to enable the D-cache */

	return ((cacheArchState & MMUCR_C_ENABLE) != 0);
	}
#else /* (ARMCACHE == ARMCACHE_940T,946E) */

#if ((ARMCACHE == ARMCACHE_SA110)  || (ARMCACHE == ARMCACHE_SA1100) || \
     (ARMCACHE == ARMCACHE_SA1500) || (ARMCACHE == ARMCACHE_XSCALE))
    if (cache == INSTRUCTION_CACHE)
	{
	/* return whether actually enabled */

	return (mmuCrGet() & MMUCR_I_ENABLE);
	}
    else
#endif

    /* return whether we have been asked to enable the cache */

    return ( (cacheArchState & MMUCR_C_ENABLE) != 0);
#endif /* (ARMCACHE == ARMCACHE_940T,946E) */
    }

/*****************************************************************************
*
* cacheMmuIsOn - boolean function to return state of MMU/MPU
*
* This routine returns the state of the MMU/MPU.
*
* RETURNS: TRUE  if MMU/MPU enabled,
*          FALSE if not enabled.
*/

LOCAL BOOL cacheMmuIsOn
    (
    void
    )
    {
    return ((mmuCrGet() & MMUCR_M_ENABLE) != 0);
    }

#endif /* (ARMCACHE != ARMCACHE_NONE) */
