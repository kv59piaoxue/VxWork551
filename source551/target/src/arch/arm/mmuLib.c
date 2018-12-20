/* mmuLib.c - MMU library for Advanced RISC Machines Ltd. ARM processors */

/* Copyright 1996-2002 Wind River Systems, Inc. */
#include "copyright_wrs.h"

/*
modification history
--------------------
01v,07nov02,jb   Fix for SPR 82500
01u,07nov02,jb   Conforming to coding standard
01t,22oct02,rec  SPR 81285 - set default cache state to writethrough
01s,06may02,to   reworked previous change
01r,03may02,to   fix D-cache incoherency (SPR#76622)
01q,13nov01,to   hand over global variables to mmuArchVars.c,
         localize mmuPageSize, some merge from AE,
         initialise (UK) -> initialize (US), etc.
01q,02oct01,jpd  clarified some conditional code.
01p,26jul01,scm  add extended small page table support for XScale...
01o,25jul01,scm  add support for MMU_STATE_CACHEABLE_WRITETHROUGH for
                 XScale...
01n,23jul01,scm  change XScale name to conform to coding standards...
01m,11dec00,scm  replace references to SA2 with XScale
01l,06sep00,scm  add sa2 support...
01k,10sep99,jpd  fixed mmu(Global)PageMap() bug when pages remapped (SPR #27199)
01j,15feb99,jpd  added support for ARM740T, ARM720T, ARM920T.
01i,21jan99,cdp  removed some more support for old ARM libraries.
01h,20jan99,cdp  removed support for old ARM libraries.
01g,04dec98,jpd  added support for ARM 940T, SA-1500; removed mmuIntLock();
            cdp  added support for generic ARM ARCH3/ARCH4.
01g,03feb99,wsl  add errno code to comment for mmuLibInit().
01f,09mar98.jpd  further changes for SA-1100 and similar CPUs.
01e,26jan98,jpd  cope with SA-1100: mark page tables uncacheable, add use of
         routines provided by BSP to convert VA<->PA.
01d,27oct97,kkk  took out "***EOF***" line from end of file.
01c,18sep97,jpd  defer setting of cacheDataEnabled to when MMU is turned on.
         Protect more operations from FIQ, where possible
01b,18feb97,jpd  comments/documentation reviewed.
01a,28oct96,jpd  written, based on Am29K version 01c.
*/

/*
DESCRIPTION:

mmuLib.c provides the architecture dependent routines that directly control
the memory management unit.  It provides 10 routines that are called by the
higher level architecture independent routines in vmLib.c:

mmuLibInit - initialize module
mmuTransTblCreate - create a new translation table
mmuTransTblDelete - delete a translation table.
mmuEnable - turn MMU on or off
mmuStateSet - set state of virtual memory page
mmuStateGet - get state of virtual memory page
mmuPageMap - map physical memory page to virtual memory page
mmuGlobalPageMap - map physical memory page to global virtual memory page
mmuTranslate - translate a virtual address to a physical address
mmuCurrentSet - change active translation table

Applications using the MMU will never call these routines directly; the
visible interface is supported in vmLib.c.

INTERNAL
Although this library contains code written for the ARM810 CPU, at
the time of writing, this code has not been tested fully on that CPU.
YOU HAVE BEEN WARNED.

PAGE TABLE STYLE MMUS
mmuLib supports the creation and maintenance of multiple translation tables,
one of which is the active translation table when the MMU is enabled.  Note
that VxWorks does not include a translation table as part of the task
context; individual tasks do not reside in private virtual memory.  However,
we include the facilities to create multiple translation tables so that the
user may create "private" virtual memory contexts and switch them in an
application specific manner.  New translation tables are created with a call
to mmuTransTblCreate, and installed as the active translation table with
mmuCurrentSet.  Translation tables are modified and potentially augmented
with calls to mmuPageMap and mmuStateSet. The state of portions of the
translation table can be read with calls to mmuStateGet and mmuTranslate.

The traditional VxWorks architecture and design philosophy requires that all
objects and operating systems resources be visible and accessible to all
agents (tasks, isrs, watchdog timers, etc) in the system.  This has
traditionally been ensured by the fact that all objects and data structures
reside in physical memory; thus, a data structure created by one agent may
be accessed by any other agent using the same pointer (object identifiers in
VxWorks are often pointers to data structures.) This creates a potential
problem if you have multiple virtual memory contexts.  For example, if a
semaphore is created in one virtual memory context, you must guarantee that
that semaphore will be visible in all virtual memory contexts if the
semaphore is to be accessed at interrupt level, when a virtual memory
context other than the one in which it was created may be active. Another
example is that code loaded using the incremental loader from the shell must
be accessible in all virtual memory contexts, since code is shared by all
agents in the system.

This problem is resolved by maintaining a global "transparent" mapping of
virtual to physical memory for all the contiguous segments of physical
memory (on board memory, i/o space, sections of VME space, etc) that is
shared by all translation tables; all available physical memory appears at
the same address in virtual memory in all virtual memory contexts. This
technique provides an environment that allows resources that rely on a
globally accessible physical address to run without modification in a system
with multiple virtual memory contexts.

An additional requirement is that modifications made to the state of global
virtual memory in one translation table appear in all translation tables.
For example, memory containing the text segment is made read only (to avoid
accidental corruption) by setting the appropriate writable bits in the
translation table entries corresponding to the virtual memory containing the
text segment.  This state information must be shared by all virtual memory
contexts, so that no matter what translation table is active, the text
segment is protected from corruption.  The mechanism that implements this
feature is architecture dependent, but usually entails building a section of
a translation table that corresponds to the global memory, that is shared by
all other translation tables.  Thus, when changes to the state of the global
memory are made in one translation table, the changes are reflected in all
other translation tables.

mmuLib provides a separate call for constructing global virtual memory -
mmuGlobalPageMap - which creates translation table entries that are shared
by all translation tables.  Initialization code in usrConfig makes calls to
vmGlobalMap (which in turn calls mmuGlobalPageMap) to set up global
transparent virtual memory for all available physical memory.  All calls
made to mmuGlobalPageMap must occur before any virtual memory contexts are
created; changes made to global virtual memory after virtual memory contexts
are created are not guaranteed to be reflected in all virtual memory
contexts.

Most MMU architectures will dedicate some fixed amount of virtual memory to
a minimal section of the translation table (a "segment", or "block").  This
creates a problem in that the user may map a small section of virtual memory
into the global translation tables, and then attempt to use the virtual
memory after this section as private virtual memory.  The problem is that
the translation table entries for this virtual memory are contained in the
global translation tables, and are thus shared by all translation tables.
This condition is detected by vmMap, and an error is returned, thus, the
lower level routines in mmuLib.c (mmuPageMap, mmuGlobalPageMap) need not
perform any error checking.

If supporting VxVMI, a global variable called mmuPageBlockSize should
be defined which is equal to the minimum virtual segment size.

This module supports the ARM MMU with a two level translation table:

                                            TTBR
                                             |
                                             |
    LEVEL 1                 -------------------------------------
    PAGE DESCRIPTORS        |L1PD |L1PD |L1PD |L1PD |L1PD |L1PD | ...
                            -------------------------------------
                               |     |     |     |     |     |
                               |     |     |     |     |     |
                      ----------     |     v     v     v     v
                      |              |    NULL  NULL  NULL  NULL
                      |              |
                      |              -------------------------
                      |                                      |
                      v                                      v
LEVEL2   -------------------------------      -------------------------------
PAGE     | PTE | PTE | PTE | PTE | PTE | ...  | PTE | PTE | PTE | PTE | PTE | ..
DESCRIP. -------------------------------      -------------------------------
(256/table) |     |                              |     |
            |     ----  ...                      |     ----  ...
            |        |                           |        |
            v        v                           v        v
          ----     ----                         ----     ----
         |page|   |page|                       |page|   |page|
          ----     ----                         ----     ----


The Translation Table Base Register (TTBR) points to the top level which
consists of an array of first-level page descriptors (LEVEL_1_PAGE_DESC).
These point to arrays of 256 Level 2 Page Table Entries (PTE),
which in turn point to pages.

To implement global virtual memory, a separate translation table called
mmuGlobalTransTbl is created when the module is initialized.  Calls to
mmuGlobalPageMap will augment and modify this translation table.  When new
translation tables are created, memory for the top level array of Level 1 table
descriptors is allocated and initialized by duplicating the pointers in
mmuGlobalTransTbl's top level level 1 table descriptor array.  Thus, the
new translation table will use the global
translation table's state information for portions of virtual memory that are
defined as global.  Here's a picture to illustrate:

       GLOBAL TRANS TBL		        NEW TRANS TBL

                root				     root
                 |                                    |
                 |                                    |
                 v                                    v
LEVEL 1  -------------------                  -------------------
TABLE    |L1PD |L1PD |L1PD |...               |L1PD |L1PD |L1PD |...
DESC.    -------------------                  -------------------
            |     |                              |     |
            o-------------------------------------     |
            |     |                                    |
            |     ------------                         |
            |                |                         |
            |                o--------------------------
            |                |
            v                v
LEVEL2   -------------      ------------
TABLE    | PTE | PTE |...  | PTE | PTE |...
DESCRIP. -------------      ------------
(256/table) |     |           |     |
            |     ----  ...   |     ----  ...
            |        |        |        |
            v        v        v        v
          ----     ----       ----     ----
         |page|   |page|     |page|   |page|
          ----     ----       ----     ----

Note that with this scheme, the global memory granularity is 1MB.  Each
time you map a section of global virtual memory, you dedicate at least
1MB of the virtual space to global virtual memory that will be shared
by all virtual memory contexts.

The physical memory that holds these data structures is obtained from
the system memory manager via memPartAlignedAlloc to ensure that the
memory is page aligned.  We want to protect this memory from being
corrupted, so we write protect the descriptors that we set up in the
global translation that correspond to the memory containing the
translation table data structures.  This creates a "chicken and the
egg" paradox, in that the only way we can modify these data structures
is through virtual memory that is now write protected, and we can't
write enable it because the page descriptors for that memory are in
write protected memory (confused yet?). So, you will notice that
anywhere that page descriptors are modified, we do so by locking out
interrupts, momentarily disabling the MMU protection, accessing the
memory, enabling the MMU protection, and then re-enabling interrupts
(see mmuStateSet, for example.)

USER MODIFIABLE OPTIONS:

1) Alternate memory source - A customer has special purpose hardware that
   includes separate static RAM for the MMU's translation tables.
   Thus, they require the ability to specify an alternate source of
   memory other than the system memory partition.  The global function
   pointer _func_armPageSource should be set by the BSP to point to a
   routine that returns a memory partition id that describes memory to
   be used as the source for translation table memory.  If this
   function pointer is NULL, the system memory partition will be used.
   The BSP must modify the function pointer before mmuLibInit is
   called.

2) The BSP cannot support an address mapping where virtual and physical
   addresses are the same, particularly for those areas containing page
   tables. In this case, the BSP must provide mapping functions to
   convert between virtual and physical addresses and set the function
   pointers _func_armVirtToPhys and _func_armPhysToVirt to point to
   these functions. If these function pointers are NULL, it is assumed
   that virtual addresses are equal to physical addresses in the
   initial mapping.  The BSP must modify the function pointers before
   mmuLibInit is called.


MEMORY PROTECTION UNITS (MPUS)
This library also supports Memory Protection Units (MPUs).  It is not
possible to support as flexible an interface as on page-table-style
MMUs and, in particular, VxVMI is not supported on MPUs.  Essentially
the same interfaces are supported as for vmBaseLib on page-table-style
MMUs.

On the ARM940T/740T MPUs, there is no mapping from virtual to physical
addresses, so in VxWorks terms, the virtual and physical addresses must
be the same.  Both the instruction and data spaces may be partitioned
into a maximum of eight regions, where each region is specified by a
base address and a size.  In addition, the regions must have an
alignment equal to their size with a minimum region size of 4 kbytes.
On 740T, there is only one set of regions defining the combined
instruction and data regions.  On the 940T, we make the instruction and
data region definitions the same in the MPU registers (the user just
specifies one set).  The regions may have overlapping definitions, and
there is a priority ordering from the highest (region 7) to the lowest
(region 0).  We allocate them in order from 0 upwards, so the user may
exert control over the priority of those regions.  When a region is
deleted, we shuffle any higher region definitions down, so that new
regions are always allocated at higher priority to existing regions.

The MPU cannot make regions read-only from code executing in SVC mode,
so we do not allow areas to be marked as read-only.

Only one context can be created, which is the "global" context.  Calls
to mmuPageMap and mmuGlobalPageMap become NOPs as all pages are
"mapped" all of the time (if no region is created for an address range
then it is treated as though it had been mapped in, but marked as
invalid).  All the work is really done from mmuStateSetRegion() which
is the analogue of mmuStateSet for page-table-style MMUs.  This routine
tries to allocate regions in the MPU according to the parameters
given.  The strategy is currently quite simple, but copes with some of
the obvious cases, like marking a bit of RAM as non-cacheable and then
marking it as cacheable again (this causes a new region to be created,
then deleted when the area is returned to the state of the rest of
RAM).  Attempts to create identical regions are ignored, as are
attempts to create a region that is a subset of a region whose state
matches.


SEE ALSO: vmLib
.I "ARM Architecture Reference Manual,"
.I "ARM 710A Data Sheet,"
.I "ARM 810 Data Sheet,"
.I "Digital Semiconductor SA-110 Microprocessor Technical Reference Manual."
.I "Digital Semiconductor SA-1100 Microprocessor Technical Reference Manual,"
.I "Digital Semiconductor SA-1500 Mediaprocessor Data Sheet,"
.I "ARM 940T Technical Reference Manual,"
.I "ARM 740T Data Sheet,"
.I "ARM 720T Data Sheet,"
.I "ARM 920T Technical Reference Manual,"
*/


#include "vxWorks.h"
#if !defined(ARMMMU)
    #error ARMMMU not defined
#endif
#include "string.h"
#include "stdlib.h"
#include "memLib.h"
#include "private/memPartLibP.h"
#include "private/vmLibP.h"
#include "arch/arm/mmuArmLib.h"
#include "arch/arm/intArmLib.h"
#include "mmuLib.h"
#include "errno.h"
#include "cacheLib.h"

#define LOG_MSG(X0, X1, X2, X3, X4, X5, X6)			\
	{							\
	    if (_func_logMsg != NULL)				\
		_func_logMsg(X0, X1, X2, X3, X4, X5, X6);	\
	}

#undef DEBUG

#ifdef  DEBUG
    #define LOCAL
    #include "private/funcBindP.h"		/* for _func_logMsg */

    #define MMU_DEBUG_OFF		0x0000
    #define MMU_DEBUG_MPU		0x0001

int mmuDebug = MMU_DEBUG_MPU;

    #define MMU_LOG_MSG(FLG, X0, X1, X2, X3, X4, X5, X6)	\
	{						\
	    if (mmuDebug & FLG)				\
		LOG_MSG(X0, X1, X2, X3, X4, X5, X6);	\
	}
#else /* DEBUG */

    #define MMU_LOG_MSG(FLG, X0, X1, X2, X3, X4, X5, X6)

#endif /* DEBUG */



#if (ARMMMU != ARMMMU_NONE)

/* externals */

/* defines */

/*
 * On page-table style MMUs, MMU_UNLOCK and MMU_LOCK are used to access
 * page table entries that are in virtual memory that has been
 * write-protected to protect it from being corrupted. Note that these
 * macros no longer check to see if the MMU was enabled before overriding
 * the MMU protection, as they do not need to switch the MMU off.
 *
 * On MPU-style MMUs, they are used to access region definitions within
 * the MPU registers. These cannot be done atomically, as the parts of a
 * region's definitions reside within different registers. So, the MPU
 * must be switched off while the region definitions are changed.
 */

    #if (!ARM_HAS_MPU)
        #define MMU_UNLOCK(oldLevel)					\
    {								\
    oldLevel = intIFLock ();	/* disable IRQs and FIQs */	\
    mmuDacrSet (0x3);		/* override MMU protection */	\
    }

        #define MMU_LOCK(oldLevel)					\
    {								\
    mmuDacrSet (0x1);		/* restore MMU protection */	\
    intIFUnlock (oldLevel);	/* restore IRQs and FIQs */	\
    }
    #else /* !ARM_HAS_MPU */
        #define MMU_UNLOCK(oldLevel)				\
    {							\
    oldLevel = intIFLock ();				\
    if (mmuEnabled)					\
	{						\
	cacheDClearDisable ();				\
	mmuADisable ();	/* switch off MPU */		\
	}						\
    }

        #define MMU_LOCK(oldLevel)				\
    {							\
    if (mmuEnabled)					\
	{						\
	mmuAEnable (cacheArchState);			\
	}						\
    intIFUnlock (oldLevel);				\
    }

    #endif /* (!ARM_HAS_MPU) */

/* forward declarations */


LOCAL MMU_TRANS_TBL * mmuTransTblCreate (void);
LOCAL STATUS mmuTransTblDelete (MMU_TRANS_TBL *transTbl);
LOCAL STATUS mmuEnable (BOOL enable);
LOCAL STATUS mmuStateGet (MMU_TRANS_TBL *transTbl, void *pageAddr, UINT *state);
LOCAL STATUS mmuPageMap (MMU_TRANS_TBL *transTbl, void *virtAddr,
                         void *physPage);
    #if (ARM_HAS_MPU)
LOCAL STATUS mmuGlobalPageMap (void *virtAddr, void *physPage, UINT len);
    #else
LOCAL STATUS mmuGlobalPageMap (void *virtAddr, void *physPage);
    #endif
LOCAL STATUS mmuTranslate (MMU_TRANS_TBL *transTbl, void *virtAddr,
                           void **physAddress);
LOCAL void mmuCurrentSet (MMU_TRANS_TBL *transTbl);
    #if (!ARM_HAS_MPU)
LOCAL STATUS mmuStateSet (MMU_TRANS_TBL *transTbl, void *pageAddr,
                          UINT stateMask, UINT state);
LOCAL STATUS mmuPteGet (MMU_TRANS_TBL *pTransTbl, void *virtAddr, PTE **result);
LOCAL STATUS mmuVirtualPageCreate (MMU_TRANS_TBL *thisTbl, void *virtPageAddr);
LOCAL void * mmuDummy (void * address);
    #else /* (!ARM_HAS_MPU) */
LOCAL STATUS mmuStateSetRegion (MMU_TRANS_TBL *transTbl, void *pageAddr,
                                UINT stateMask, UINT state, UINT32 size);
    #endif /* (!ARM_HAS_MPU) */

/* For the new architectures, this is local to this file */

LOCAL STATUS mmuLibInit (int pageSize);

    #if (!ARM_HAS_MPU)

/*
 * The following is not called by the higher level routines, but is
 * used internally to make setting the state of multiple pages easier.
 */

LOCAL STATUS mmuStateSetMultiple (MMU_TRANS_TBL *transTbl, void *pageAddr,
                                  UINT stateMask, UINT state, int cnt);
    #endif /* (!ARM_HAS_MPU) */

/* Used internally as well */

LOCAL STATUS mmuTransTblInit (MMU_TRANS_TBL *newTransTbl);


/* globals */


    #if (!ARM_HAS_MPU)

/*
 * We're using generic libraries now so these are local to
 * this file, and should not be accessed by users.  They are set to the
 * function pointers passed in as parameters to mmuLibInstall().
 */

LOCAL void * (* _func_armVirtToPhys) (void *) = NULL;
LOCAL void * (* _func_armPhysToVirt) (void *) = NULL;


/* locals */

/* the memory partition id for the memory source for the page tables etc. */

LOCAL PART_ID mmuPageSource = NULL;

/*
 * The global memory translation table:
 * a translation table to hold the descriptors for the global transparent
 * translation of physical to virtual memory
 */

LOCAL MMU_TRANS_TBL mmuGlobalTransTbl;

/*
 * Array of booleans used to keep track of sections of virtual memory defined
 * as global. It could be declared as BOOL *, but save space by declaring it
 * as UINT8 *. It could even be done as a bit array.
 */

LOCAL UINT8 * globalPageBlock;

/*
 * A pointer to an array , "mini-heap", of 256 second level page tables
 * (1 KB) beginning on a mmuPageSize boundary.
 */
LOCAL UINT8 *mmuSecondLevelMiniHeap = NULL;

/*
 * The index into the current mini-heap.
 */
LOCAL UINT32 mmuSecondLevelMiniHeap_Index = 0;

/*
 * The max number of second level tables within
 * a mini-heap. This is set to a default value in
 * mmuLibInit. It can be set by the bsp prior to
 * mmuLibInit being called. The actual size of the mini-heap
 * is calculated back from this value.
 */
#define mmuSecondLevelMiniHeap_Max   FN(mmu,SecondLevelMiniHeap_Max)
UINT32 mmuSecondLevelMiniHeap_Max = 0;

/*
 * Actual size, in bytes,  of the allocated mini-heap.
 * calculated in mmuLibInit after mmuSecondLevelMiniHeap_Max
 * is established.
 */
LOCAL UINT32 mmuSecondLevelMiniHeap_Size = 0;

/*
 * Size in bytes of a second level page table.
 */
        #define L2_PTE_SIZE 1024

/*
 * Number of L2 Pte entries per page.
 */
        #define L2_PTE_PER_PAGE (mmuPageSize / L2_PTE_SIZE )

/*
 * Default size of the mini-heap.
 */
        #define PAGES_PER_MINI_HEAP 4

    #endif /* !ARM_HAS_MPU */


LOCAL int mmuPageSize;  /* size of MMU pages in bytes */

LOCAL BOOL mmuEnabled;


/*
 * The table used to define the mapping between the architecture-independent
 * values (VM_*) and the architecture-specific values (MMU_*)
 */

LOCAL STATE_TRANS_TUPLE mmuStateTransArrayLocal [] =
    {
    {VM_STATE_MASK_VALID, MMU_STATE_MASK_VALID,
        VM_STATE_VALID, MMU_STATE_VALID},

    {VM_STATE_MASK_VALID, MMU_STATE_MASK_VALID,
        VM_STATE_VALID_NOT, MMU_STATE_VALID_NOT},

#if (!ARM_HAS_MPU)
    /* current MPUs do not allow us to mark pages as read-only from SVC code */

    {VM_STATE_MASK_WRITABLE, MMU_STATE_MASK_WRITABLE,
        VM_STATE_WRITABLE, MMU_STATE_WRITABLE},

    {VM_STATE_MASK_WRITABLE, MMU_STATE_MASK_WRITABLE,
        VM_STATE_WRITABLE_NOT, MMU_STATE_WRITABLE_NOT},
#endif

    {VM_STATE_MASK_CACHEABLE, MMU_STATE_MASK_CACHEABLE,
        VM_STATE_CACHEABLE, MMU_STATE_CACHEABLE},

    {VM_STATE_MASK_CACHEABLE, MMU_STATE_MASK_CACHEABLE,
        VM_STATE_CACHEABLE_NOT, MMU_STATE_CACHEABLE_NOT},

#if (ARMMMU == ARMMMU_XSCALE)
    {VM_STATE_MASK_EX_CACHEABLE, MMU_STATE_MASK_EX_CACHEABLE,
        VM_STATE_EX_CACHEABLE, MMU_STATE_EX_CACHEABLE},

    {VM_STATE_MASK_EX_CACHEABLE, MMU_STATE_MASK_EX_CACHEABLE,
        VM_STATE_EX_CACHEABLE_NOT, MMU_STATE_EX_CACHEABLE_NOT},
#endif

    {VM_STATE_MASK_BUFFERABLE, MMU_STATE_MASK_CACHEABLE,
        VM_STATE_BUFFERABLE, MMU_STATE_BUFFERABLE},

    {VM_STATE_MASK_BUFFERABLE, MMU_STATE_MASK_CACHEABLE,
        VM_STATE_BUFFERABLE_NOT, MMU_STATE_BUFFERABLE_NOT},

#if (ARMMMU == ARMMMU_XSCALE)
    {VM_STATE_MASK_EX_BUFFERABLE, MMU_STATE_MASK_EX_CACHEABLE,
        VM_STATE_EX_BUFFERABLE, MMU_STATE_EX_BUFFERABLE},

    {VM_STATE_MASK_EX_BUFFERABLE, MMU_STATE_MASK_EX_CACHEABLE,
        VM_STATE_EX_BUFFERABLE_NOT, MMU_STATE_EX_BUFFERABLE_NOT},
#endif

#if ARMCACHE_HAS_WRITETHROUGH
    {VM_STATE_MASK_CACHEABLE, MMU_STATE_MASK_CACHEABLE,
        VM_STATE_CACHEABLE_WRITETHROUGH, MMU_STATE_CACHEABLE_WRITETHROUGH},
#endif

#if ((ARMMMU == ARMMMU_SA1100) || (ARMMMU == ARMMMU_SA1500))
    {VM_STATE_MASK_CACHEABLE, MMU_STATE_MASK_CACHEABLE,
        VM_STATE_CACHEABLE_MINICACHE, MMU_STATE_CACHEABLE_MINICACHE},
#endif

#if (ARMMMU == ARMMMU_XSCALE)
    {VM_STATE_MASK_EX_CACHEABLE, MMU_STATE_MASK_EX_CACHEABLE,
        VM_STATE_CACHEABLE_MINICACHE, MMU_STATE_CACHEABLE_MINICACHE},
#endif
    };

LOCAL MMU_LIB_FUNCS mmuLibFuncsLocal =
    {
    mmuLibInit,
    mmuTransTblCreate,
    mmuTransTblDelete,
    mmuEnable,
#if (ARM_HAS_MPU)
    mmuStateSetRegion,
#else
    mmuStateSet,
#endif
    mmuStateGet,
    mmuPageMap,
    mmuGlobalPageMap,
    mmuTranslate,
    mmuCurrentSet
    };
#endif /* (ARMMMU != ARMMMU_NONE) */

IMPORT STATE_TRANS_TUPLE *mmuStateTransArray;
IMPORT int mmuStateTransArraySize;
IMPORT MMU_LIB_FUNCS mmuLibFuncs;
IMPORT int mmuPageBlockSize;

IMPORT int ffsMsb (UINT32 val);
IMPORT int ffsLsb (UINT32 val);

#if (!ARM_HAS_MPU)
IMPORT PART_ID (* _func_armPageSource) (void);
#endif /* !ARM_HAS_MPU */

/*
 * Variable used to keep desired cache enable state: layout as MMUCR
 * (variously I, Z, W and C bits for different cache/MMUs).  This is
 * used by mmuALib when enabling the MMU, to enable the appropriate cache
 * features that cannot be enabled when the MMU is disabled.  See
 * cacheArchEnable().  For example, we must disable the D-cache,
 * write-buffer and branch-prediction when disabling the MMU on most
 * cache/MMUs and need to know what to turn back on when the MMU is
 * re-enabled.
*/

IMPORT UINT32 cacheArchState;

/*
 * The function pointer is declared in a different module, and does not
 * have a unique-ified name. This is the function pointer that is set to
 * point to the initialization routine of the appropriate variant of this
 * file.
 */

IMPORT FUNCPTR sysMmuLibInit;

/*******************************************************************************
*
* mmuLibInstall - install specific ARM MMU library function pointers
*
* This routine is provided as a hook so that calling this routine
* selects the specific MMU library. It also allows any virtual <->
* physical address translation routines provide by the BSP to be passed
* to the MMU library as parameters rather than as global data.
*
* INTERNAL
* This routine is called (from sysHwInit0()), before sysHwInit has been
* called, and before BSS has been cleared.
*
* RETURNS: N/A
*
*/

void mmuLibInstall
    (
    void * (physToVirt) (void *),
    void * (virtToPhys) (void *)
    )
    {
    static BOOL initialized = FALSE;

    /* protect against being called twice */

    if (initialized)
        return;

    /*
     * Set the function pointers appropriate for the type of MMU. On 710a,
     * we must use the versions of these routines that use a soft-copy
     * of the MMU Control Register.
     */

#if (ARMMMU == ARMMMU_710A)
    mmuCrGet = mmuSoftCrGet;
    mmuModifyCr = mmuModifySoftCr;
#else
    mmuCrGet = mmuHardCrGet;
    mmuModifyCr = mmuModifyHardCr;
#endif

#if (!ARM_HAS_MPU)
    _func_armPhysToVirt = physToVirt;
    _func_armVirtToPhys = virtToPhys;
#endif /* (!ARM_HAS_MPU) */

    sysMmuLibInit = mmuLibInit;

    initialized = TRUE;

    return;

    }

/******************************************************************************
*
* mmuLibInit - initialize MMU handling module (ARM)
*
* Build a dummy translation table that will hold the page table entries
* for the global translation table.  The MMU remains disabled upon
* completion.  Note that this routine is global so that it may be referred to
* in usrConfig.c to pull in the correct mmuLib for the specific architecture.
*
* RETURNS: OK, or ERROR.
*
* ERRNO:
*  S_mmuLib_INVALID_PAGE_SIZE
*/

LOCAL STATUS mmuLibInit
    (
    int pageSize    /* system pageSize (must be 4096) */
    )
    {
#if (ARMMMU != ARMMMU_NONE)
    static BOOL initialized = FALSE;
#if (!ARM_HAS_MPU)
    LEVEL_1_DESC *  pL1;
#endif

    /* protect against being called twice */

    if (initialized)
        return OK;

#if (!ARM_HAS_MPU)

    /*
     * If the BSP has not specified a routine to set a memory partition to
     * obtain pages from, then initialize mmuPageSource to the system memory
     * partition.
     */

    if (_func_armPageSource == NULL)
        mmuPageSource = memSysPartId;
    else
        mmuPageSource = _func_armPageSource ();


    /*
     * If the BSP has not specified routines for address translation, then
     * assume that virtual and physical addresses for page table entries
     * will be identical. Install dummy translation routine.
     */

    if (_func_armPhysToVirt == NULL)
        _func_armPhysToVirt = mmuDummy;

    if (_func_armVirtToPhys == NULL)
        _func_armVirtToPhys = mmuDummy;
#endif /* !ARM_HAS_MPU */


    /* initialize the data objects that are shared with vmLib.c */

    mmuStateTransArray = &mmuStateTransArrayLocal [0];

    mmuStateTransArraySize =
    sizeof (mmuStateTransArrayLocal) / sizeof (STATE_TRANS_TUPLE);

    mmuLibFuncs = mmuLibFuncsLocal;

#if (!ARM_HAS_MPU)
    mmuPageBlockSize = PAGE_BLOCK_SIZE;
#endif

    /* We only support a 4096 byte page size */

    if (pageSize != PAGE_SIZE)
        {
        errno = S_mmuLib_INVALID_PAGE_SIZE;
        return ERROR;
        }

    mmuEnabled = ((mmuCrGet() & MMUCR_M_ENABLE) != 0);

    mmuPageSize = pageSize;


#if (!ARM_HAS_MPU)

    /*
     * Establish the maximum number of second level page table entries
     * in a "mini-heap". The default can be over ridden by placing
     * a non-zero value in mmuSecondLevelMiniHeap_Max. A value of 1
     * mmuSecondLevelMiniHeap_Max effectively disables the mini-heap.
     */
    if (mmuSecondLevelMiniHeap_Max == 0)
        mmuSecondLevelMiniHeap_Max = ((mmuPageSize * PAGES_PER_MINI_HEAP) / L2_PTE_SIZE);

    /*
     * Calculate mini-heap size in advance, making sure it is a multiple
     * of mmuPageSize.
     */
    mmuSecondLevelMiniHeap_Size = 
    ((mmuSecondLevelMiniHeap_Max * L2_PTE_SIZE) / mmuPageSize) * mmuPageSize;

    /*
     * mini-heap must be at least mmuPageSize 
     */
    if ( mmuSecondLevelMiniHeap_Size < mmuPageSize )
        mmuSecondLevelMiniHeap_Size = mmuPageSize;

    /*
     * Make sure count and size agree unless not using the mini-heap.
     */
    if ( mmuSecondLevelMiniHeap_Max != 1 )
        mmuSecondLevelMiniHeap_Max = mmuSecondLevelMiniHeap_Size / L2_PTE_SIZE;


    /*
     * Allocate the global page block array to keep track of which parts
     * of virtual memory are handled by the global translation tables.
     * Allocate on page boundary so we can write protect it.
     */

    globalPageBlock =
    (UINT8 *) memPartAlignedAlloc (mmuPageSource,
                                   NUM_L1_DESCS * sizeof(UINT8), pageSize);

    if (globalPageBlock == NULL)
        return ERROR;


    /* Set all entries to FALSE, i.e. not global */

    bzero ((char *) globalPageBlock, NUM_L1_DESCS * sizeof(UINT8));


    /*
     * Build a dummy translation table which will hold the PTEs for
     * global memory.  All real translation tables will point to this
     * one for controlling the state of the global virtual memory
     */

    /* allocate space to hold the Level 1 Descriptor Table */

    mmuGlobalTransTbl.pLevel1Table = pL1 =
                                     (LEVEL_1_DESC *) memPartAlignedAlloc (mmuPageSource, L1_TABLE_SIZE,
                                                                           L1_TABLE_SIZE);

    if (pL1 == NULL)
        return ERROR;


    /*
     * Invalidate all the Level 1 table entries. This will have the effect
     * of setting all Level 1 Descriptors to type Fault.
     */

    bzero ((char *) pL1, NUM_L1_DESCS * sizeof(LEVEL_1_DESC));
#endif /* !ARM_HAS_MPU */

    initialized = TRUE;

#endif /* ARMMMU != ARMMMU_NONE */

    return OK;

    } /* mmuLibInit() */

#if (ARMMMU != ARMMMU_NONE)

    #if (!ARM_HAS_MPU)
/******************************************************************************
*
* mmuPteGet - get the PTE for a given page (ARM)
*
* mmuPteGet traverses a translation table and returns the (virtual) address of
* the PTE for the given virtual address.
*
* RETURNS: OK or ERROR if there is no virtual space for the given address
*/

LOCAL STATUS mmuPteGet
    (
    MMU_TRANS_TBL * pTransTbl,  /* translation table */
    void *      virtAddr,   /* virtual address */
    PTE **      result      /* result is returned here */
    )
    {
    LEVEL_1_DESC *  pL1;        /* Level 1 descriptor */
    PTE *       pL2;        /* Level 2 descriptor */
    UINT        pteTableIndex;


    /* extract pointer to Level 1 Descriptor from L1 Descriptor table */

    pL1 = &pTransTbl->pLevel1Table [(UINT) virtAddr / PAGE_BLOCK_SIZE];


    /* check virtual address has a physical address */

    if (pL1->fields.type != DESC_TYPE_PAGE)
        return ERROR;


    /* Get Small Page base address from Level 1 Descriptor */

    pL2 = (PTE *) pL1->fields.addr; /* addr of page table */
    pL2 = (PTE *) ((UINT32)pL2 << L1D_TO_BASE_SHIFT);

    pL2 = _func_armPhysToVirt (pL2);

    /* pL2 now points to (in VA) base of Level 2 Descriptor Table */


    /* create index into level 2 Descriptor (PTE) table */

    pteTableIndex = (((UINT) virtAddr & PTE_INDEX_MASK) >> PTE_INDEX_SHIFT);


    /* get PTE */

    *result = &pL2 [pteTableIndex];


    return OK;

    } /* mmuPteGet() */

    #endif (!ARM_HAS_MPU)

/******************************************************************************
*
* mmuTransTblInit - initialize a new translation table (ARM)
*
* Initialize a new translation table.  The Level 1 table is copied from the
* global translation mmuGlobalTransTbl, so that we will share the global
* virtual memory with all other translation tables.
*
* RETURNS: OK or ERROR if unable to allocate memory for Level 1 table.
*/

LOCAL STATUS mmuTransTblInit
    (
    MMU_TRANS_TBL * newTransTbl /* translation table to be inited */
    )
    {
#if (!ARM_HAS_MPU)
    FAST LEVEL_1_DESC * pL1;

    /*
     * Allocate space to hold the Level 1 Descriptor table, which must
     * reside on a 16 kbyte boundary for the ARM and we want it on a page
     * boundary to be able to write-protect it as well.
     */

    newTransTbl->pLevel1Table = pL1 = (LEVEL_1_DESC *)
                                memPartAlignedAlloc (mmuPageSource, L1_TABLE_SIZE, L1_TABLE_SIZE);

    if (pL1 == NULL)
        return ERROR;


    /*
     * Copy the Level 1 descriptor table from mmuGlobalTransTbl,
     * so we get the global virtual memory.
     */

    bcopy ((char *) mmuGlobalTransTbl.pLevel1Table,
           (char *) pL1, L1_TABLE_SIZE);


    /*
     * Flush the data cache. cacheLib should have been initialized by now,
     * but even if it hasn't, it is safe to call cacheLib routines, as they
     * check before calling their function pointers.
     */

    cacheFlush (DATA_CACHE, pL1, L1_TABLE_SIZE);


    /*
     * Write protect virtual memory pointing to the the level 1 table in
     * the global translation table to ensure that it can't be corrupted.
     * Also, mark it as non-cacheable. All page tables are marked as
     * non-cacheable: there is no advantage to the MMU as the TLB
     * tree-walk hardware works direct to memory and not through the
     * cache. There is a disadvantage to us, as every time we modify
     * memory we need to flush the cache. All in all, it is easier not to
     * have the pages marked as cacheable in the first place.
     */

#if (ARMMMU == ARMMMU_XSCALE)
    mmuStateSetMultiple (&mmuGlobalTransTbl, (void *) pL1,
                         MMU_STATE_MASK_WRITABLE | MMU_STATE_MASK_CACHEABLE | \
                         MMU_STATE_MASK_EX_CACHEABLE,
                         MMU_STATE_WRITABLE_NOT  | MMU_STATE_CACHEABLE_NOT  | \
                         MMU_STATE_EX_CACHEABLE_NOT,
                         L1_DESC_PAGES);
#else
    mmuStateSetMultiple (&mmuGlobalTransTbl, (void *) pL1,
                         MMU_STATE_MASK_WRITABLE | MMU_STATE_MASK_CACHEABLE,
                         MMU_STATE_WRITABLE_NOT  | MMU_STATE_CACHEABLE_NOT,
                         L1_DESC_PAGES);
#endif

#else /* (!ARM_HAS_MPU) */

    /* clear out all the region definitions */

    bzero ((char *)newTransTbl, sizeof(MMU_TRANS_TBL));

    /* set the null definitions into the MPU */

    mmuPrrSet (newTransTbl->regs);
    mmuCcrSet (0);
    mmuWbcrSet (0);
    mmuPrSet (0);

#endif /* (!ARM_HAS_MPU) */
    return OK;

    } /* mmuTransTblInit() */

/******************************************************************************
*
* mmuTransTblCreate - create a new translation table (ARM)
*
* Create an ARM translation table.  Allocates space for the MMU_TRANS_TBL
* data structure and calls mmuTransTblInit on that object.
*
* RETURNS: address of new object or NULL if allocation failed,
*          or NULL if initialization failed.
*/

LOCAL MMU_TRANS_TBL *mmuTransTblCreate (void)
    {
    MMU_TRANS_TBL * newTransTbl;

    newTransTbl = (MMU_TRANS_TBL *) malloc (sizeof (MMU_TRANS_TBL));

    if (newTransTbl == NULL)
        return NULL;

    if (mmuTransTblInit (newTransTbl) == ERROR)
        {
        free ((char *) newTransTbl);
        return NULL;
        }

    return newTransTbl;

    } /* mmuTransTblCreate() */

/******************************************************************************
*
* mmuTransTblDelete - delete a translation table (ARM)
*
* mmuTransTblDelete deallocates all the memory used to store the translation
* table entries.  It does not deallocate physical pages mapped into the global
* virtual memory space.
*
* This routine is only called from vmLib, not from vmBaseLib.
*
* RETURNS: OK
*/

LOCAL STATUS mmuTransTblDelete
    (
    MMU_TRANS_TBL * transTbl    /* translation table to be deleted */
    )
    {
#if (!ARM_HAS_MPU)
    int         i;
    LEVEL_1_DESC *  pL1;        /* Level 1 Descriptor */
    PTE *       pPte;       /* page table entry */
    PTE *       tpPte;       /* page table entry */
    UINT32 *bHp;		/* Block Header Detector */

    pL1 = transTbl->pLevel1Table;   /* get Level 1 Descriptor table */


    /* write enable the physical pages containing Level 1 Descriptors */

    mmuStateSetMultiple (&mmuGlobalTransTbl, transTbl->pLevel1Table,
                         MMU_STATE_MASK_WRITABLE, MMU_STATE_WRITABLE,
                         L1_DESC_PAGES);


    /*
     * deallocate only non-global page blocks, deallocate in reverse order
     * to allow "unpacking" of second level page tables
     */
    pL1 += (NUM_L1_DESCS -1);
    for (i = (NUM_L1_DESCS -1); i >= 0; i--, pL1--)
        if ((pL1->fields.type == DESC_TYPE_PAGE) && !((BOOL)globalPageBlock[i]))
            {
            /* get pointer to each Page Table */

            pPte = (PTE *) (pL1->fields.addr << L1D_TO_BASE_SHIFT);

            pPte = _func_armPhysToVirt (pPte); /* conv to virtual address */

            /*
             * Check if this Pte is on a partially allocated mini-heap
             */
            if ( mmuSecondLevelMiniHeap != NULL
                 || mmuSecondLevelMiniHeap_Index < mmuSecondLevelMiniHeap_Max )
                {
                tpPte = (PTE *)(mmuSecondLevelMiniHeap + ((mmuSecondLevelMiniHeap_Index -1) * L2_PTE_SIZE));
                if ( pPte == tpPte )
                    {
                    /* From a partially allocated mini-heap, free it. */
                    mmuSecondLevelMiniHeap_Index--;
                    }
                }
            else
                tpPte = NULL;
               
            /* set the Page Table writable and cacheable */

#if (ARMMMU == ARMMMU_XSCALE)
            mmuStateSet (&mmuGlobalTransTbl, (PTE *)((int)pPte & ~(mmuPageSize - 1)),
                         MMU_STATE_MASK_WRITABLE | MMU_STATE_MASK_CACHEABLE | \
                         MMU_STATE_MASK_EX_CACHEABLE,
                         MMU_STATE_WRITABLE | MMU_STATE_CACHEABLE | \
                         MMU_STATE_EX_CACHEABLE);
#else
            mmuStateSet (&mmuGlobalTransTbl, (PTE *)((int)pPte & ~(mmuPageSize - 1)),
                         MMU_STATE_MASK_WRITABLE | MMU_STATE_MASK_CACHEABLE,
                         MMU_STATE_WRITABLE | MMU_STATE_CACHEABLE);
#endif

            bHp = (UINT32 *)pPte;

            if ( *(bHp - 1) == (mmuSecondLevelMiniHeap_Size + sizeof(BLOCK_HDR)) )
                {
                /* If on an allocated boundary */

                /* Check if this is the current mini-heap */
                if ( tpPte && tpPte == (PTE *)mmuSecondLevelMiniHeap )
                    {
                    mmuSecondLevelMiniHeap = NULL;
                    mmuSecondLevelMiniHeap_Index = 0;
                    }

                /* Free the Page Table */

                memPartFree (mmuPageSource, (char *)pPte);
                }
            }

        /* free the Level 1 Descriptor table */

    memPartFree (mmuPageSource, (char *)transTbl->pLevel1Table);

    free (transTbl);        /* free the translation table data structure */

    return OK;
#else /* !ARM_HAS_MPU */
    return ERROR;
#endif /* !ARM_HAS_MPU */
    } /* mmuTransTblDelete() */

    #if (!ARM_HAS_MPU)
/******************************************************************************
*
* mmuVirtualPageCreate - set up translation tables for a virtual page (ARM)
*
* Simply check if there's already a lower level page table that has a page
* table entry for the given virtual page.  If there isn't, create one.
*
* RETURNS: OK or ERROR if couldn't allocate space for lower level page table.
*/

LOCAL STATUS mmuVirtualPageCreate
    (
    MMU_TRANS_TBL * thisTbl,    /* translation table */
    void *      virtPageAddr    /* virtual addr to create */
    )
    {
    LEVEL_1_DESC *  pL1;    /* Level 1 descriptor entry */
    PTE *       pPte;   /* page table entry */

    /* If the virtual address already has a page table, then we've finished */

    if (mmuPteGet (thisTbl, virtPageAddr, &pPte) == OK)
        return OK;

    /*
     * The PTE doesn't exist, so create one. Allocate a "mini-heap"
     * on a page aligned boundary and parcel out the 1k chunks needed by
     * second level page table entries until they are exhausted. Then allocate
     * and parcel the next "mini-heap". In this way, memory waste is
     * significantly decreased.
     */

    if ( mmuSecondLevelMiniHeap == NULL
         || mmuSecondLevelMiniHeap_Index >= mmuSecondLevelMiniHeap_Max )
        {
        mmuSecondLevelMiniHeap = (UINT8 *) memPartAlignedAlloc (mmuPageSource,
                                                                mmuSecondLevelMiniHeap_Size,
                                                                mmuPageSize);
        if (mmuSecondLevelMiniHeap == NULL)
            return ERROR;

        mmuSecondLevelMiniHeap_Index = 0;

        /*
         * Invalidate every page table entry in the new Page Table. All will be
         * fault Level 2 descriptors.
         */
        memset ((char *) mmuSecondLevelMiniHeap, 0, mmuSecondLevelMiniHeap_Size);

        }

    /*
     * Assign a PTE from the mini-heap.
     */
    pPte = (PTE *)(mmuSecondLevelMiniHeap + (mmuSecondLevelMiniHeap_Index++ * L2_PTE_SIZE)) ;


    /*
     * If this pPte is on a page boundary, then set the cacheable
     * state.
     */

    if ( ( ((int)pPte) & (mmuPageSize - 1 )) == 0)
        {
        /*
         * mmuStateSet() will flush the cache for this page before changing
         * its state
         */

#if (ARMMMU == ARMMMU_XSCALE)

        /*
         * We use the current page instead of the current pPte
         */
        mmuStateSet (&mmuGlobalTransTbl, pPte,
                     MMU_STATE_MASK_WRITABLE | MMU_STATE_MASK_CACHEABLE | \
                     MMU_STATE_MASK_EX_CACHEABLE,
                     MMU_STATE_WRITABLE_NOT | MMU_STATE_CACHEABLE_NOT | \
                     MMU_STATE_EX_CACHEABLE_NOT);
#else

        /*
         * We use the current page instead of the current pPte
         */
        mmuStateSet (&mmuGlobalTransTbl, pPte,
                     MMU_STATE_MASK_WRITABLE | MMU_STATE_MASK_CACHEABLE,
                     MMU_STATE_WRITABLE_NOT | MMU_STATE_CACHEABLE_NOT);
#endif
        }

    /*
     * Unlock the physical pages containing the Level 1 Descriptor table,
     * so we can modify them.
     */

    mmuStateSetMultiple (&mmuGlobalTransTbl, thisTbl->pLevel1Table,
                         MMU_STATE_MASK_WRITABLE, MMU_STATE_WRITABLE,
                         L1_DESC_PAGES);

    pL1 = &thisTbl->pLevel1Table [(UINT) virtPageAddr/PAGE_BLOCK_SIZE];


    /* modify the Level 1 Descriptor to point to the new page table */

    pL1->bits = DEF_L1_PAGE;    /* Page Table descriptor, domain 0 */
    pPte = _func_armVirtToPhys (pPte); /* conv Virtual to Physical Address*/
    pL1->fields.addr = ((UINT) pPte) >> L1D_TO_BASE_SHIFT;


    /* (Re)write-protect the Level 1 Descriptor table */

    mmuStateSetMultiple (&mmuGlobalTransTbl, thisTbl->pLevel1Table,
                         MMU_STATE_MASK_WRITABLE, MMU_STATE_WRITABLE_NOT,
                         L1_DESC_PAGES);

    return OK;

    } /* mmuVirtualPageCreate() */
    #endif (!ARM_HAS_MPU)

/******************************************************************************
*
* mmuEnable - turn MMU on or off (ARM)
*
* SEE ALSO:
* .I "ARM Architecture Reference"
*
* RETURNS: OK
*/

LOCAL STATUS mmuEnable
    (
    BOOL    enable  /* TRUE to enable, FALSE to disable MMU */
    )
    {
    FAST int    oldIntLev;
    LOCAL BOOL  firstTime = TRUE;

    /*
     * We cannot unilaterally protect against FIQ as the cacheClear
     * operation may take too long.
     */

    oldIntLev = cacheArchIntLock ();

    if (enable)
        {
        /*
         * Invalidate all TLBs. If MMU is not currently on, then we
         * could be about to start using whatever has been left
         * behind in them.
         */

#if (!ARM_HAS_MPU)

        /* MPUs don't have TLBs */

        mmuTLBIDFlushAll ();
#endif

        if (firstTime)
            {
#if (!ARM_HAS_MPU)

            /*
             * Set Access Control for domain zero to 01: client i.e.
             * all accesses are checked against the Access Permissions in
             * the page table entry. We only use domain zero, Access
             * control for the other domains is set to 00: any access
             * will cause a domain fault.
             */

            mmuDacrSet (0x1);
#endif /* (!ARM_HAS_MPU) */


            /*
             * Initialize MMU Control Register. Some should have been done, in
             * order to get us here at all. However, here we will set:
             *
             * M 1 Enable MMU
             * A 0 Enable address alignment fault
             * C X (D-)Cache Enable) Controlled by cacheLib
             * W X (Write Buffer) Controlled by cacheLib
             * P X (PROG32) should have been set before here.
             * D X (DATA32) should have been set before here.
             * L X (Late abort on earlier CPUs) ignore
             * B X (Big/Little-endian) should have been set before here.
             * S 0 (System)	} SBZ on MPUs
             * R 1 (ROM)	}
             * F 0 (Should be Zero)
             * Z X (Branch prediction enable on 810) Controlled by cacheLib
             * I X (I-cache enable) Controlled by cacheLib
             */

            /* set the above and any bits needed by cacheArchLib */

            mmuModifyCr (MMU_ENABLE_VALUE | cacheArchState,
                         MMU_ENABLE_MASK  | cacheArchState);

            firstTime = FALSE;
            } else    /* not first time */
            mmuAEnable (cacheArchState);

        /*
         * Clear (flush and invalidate) the data cache (some pages may not be
         * cacheable).
         */

        cacheClear (DATA_CACHE, 0, ENTIRE_CACHE);


        /*
         * cacheEnable() may have been called before this, when the MMU was off
         * so set cacheDataEnabled accordingly, then call cacheFuncsSet() to
         * set up the appropriate function pointers.
         */

        cacheDataEnabled = ((cacheArchState & MMUCR_C_ENABLE) != 0);
        } else    /* disable */
        {
        /*
         * Clear (flush and invalidate) the data cache. Leave nothing
         * behind in the cache, which might either be dirty, or might
         * continue to be used.
         */

        cacheClear (DATA_CACHE, 0, ENTIRE_CACHE);

        mmuADisable ();

#if (!ARM_HAS_MPU)

        /* Invalidate all TLB entries: tidiness really, leave nothing behind */

        mmuTLBIDFlushAll ();
#endif /* (!ARM_HAS_MPU) */

        cacheDataEnabled = FALSE;
        }

    /* Set up function pointers appropriate to actual cache enabled state */

    cacheFuncsSet ();


    /* Invalidate the instruction cache */

    cacheInvalidate (INSTRUCTION_CACHE, 0, ENTIRE_CACHE);


    mmuEnabled = enable;

    intIFUnlock (oldIntLev);


    return OK;

    } /* mmuEnable() */

    #if (!ARM_HAS_MPU)
/******************************************************************************
*
* mmuStateSet - set state of virtual memory page (ARM)
*
* mmuStateSet is used to modify the state bits of the PTE for the given
* virtual page.  The following states are provided:
*
* MMU_STATE_VALID	MMU_STATE_VALID_NOT	 valid/invalid
* MMU_STATE_WRITABLE	MMU_STATE_WRITABLE_NOT	 writable/writeprotected
* MMU_STATE_CACHEABLE	MMU_STATE_CACHEABLE_NOT	 cacheable/not cacheable
*
* These may be OR'd together in the state parameter.  Additionally, masks
* are provided so that only specific states may be set:
*
* MMU_STATE_MASK_VALID
* MMU_STATE_MASK_WRITABLE
* MMU_STATE_MASK_CACEHABLE
*
* These may be OR'd together in the stateMask parameter.
*
* Accesses to a virtual page marked as invalid will result in a bus error.
*
* RETURNS: OK or ERROR if virtual page does not exist.
*/

LOCAL STATUS mmuStateSet
    (
    MMU_TRANS_TBL * transTbl,   /* translation table */
    void *      pageAddr,   /* page whose state to modify */
    UINT        stateMask,  /* mask of which state bits to modify */
    UINT        state       /* new state bit values */
    )
    {
    PTE *       pPte;
    int oldIntLev;

    if (mmuPteGet (transTbl, pageAddr, &pPte) != OK)
        return ERROR;


    /*
     * We are about to change the state of a page. We may be about to change
     * the page from cached to uncached, or mark it invalid, so we must clear
     * (write out to memory and invalidate from the cache) the whole page.
     */

    cacheClear (DATA_CACHE, pageAddr, mmuPageSize);

#if ARMCACHE_NOT_COHERENT

    /* On 810, this will just do an IMB */

    cacheClear (INSTRUCTION_CACHE, pageAddr, mmuPageSize);
#endif


    /* modify the PTE with MMU protection turned off and ints locked out */

    MMU_UNLOCK (oldIntLev);
    pPte->bits = (pPte->bits & ~stateMask) | (state & stateMask);
    MMU_LOCK (oldIntLev);

    /*
     * Page entry has been updated in memory so flush the entry in the TLB
     * to be sure that the TLB will be updated during the next access to this
     * address.
     */

    mmuTLBIDFlushEntry (pageAddr);

    return OK;

    } /* mmuStateSet() */

    #else /* ARM_HAS_MPU */
/******************************************************************************
*
* mmuDeleteRegion - delete memory region (ARM)
*
* This routine deletes an address region definition, shuffling the
* other (higher priority) regions down, if necessary, in an MPU.
*
* The MPU must be disabled while this routine is called.
*
* RETURNS: N/A.
*/

LOCAL void mmuDeleteRegion
    (
    MPU_REGION_REG *    regs,   /* the Protection Region Registers */
    int         region  /* the region number */
    )
    {
    int i;
    UINT32 ccr, wbcr, cpr, mask1, mask2;

    /*
     * We already have the protection region registers. Get the cache
     * control register, the write-buffer control register and the cache
     * protection registers.
     */

    ccr =  mmuCcrGet();
    wbcr = mmuWbcrGet();
    cpr =  mmuPrGet();


    /* shuffle the regions down from above this region */

    for (i = region; i < (MPU_NUM_REGIONS - 1); i++)
        regs[i].bits = regs[i+1].bits;


    /* shuffle down the contents of the other registers */

    mask1 = 0xFFFFFFFF << region;
    mask2 = 0xFFFFFFFF << (region + 1);

    ccr &= (ccr & ~mask1);
    ccr |= ((ccr & mask2) >> 1);
    wbcr &= (wbcr & ~mask1);
    wbcr |= ((wbcr & mask2) >> 1);

    mask1 = 0xFFFFFFFF << (region * 2);
    mask2 = 0xFFFFFFFF << ((region + 1) * 2);

    cpr &= (cpr & ~mask1);
    cpr |= ((cpr & mask2) >> 1);


    /* clear out the definitions for the highest numbered region */

    regs[MPU_NUM_REGIONS - 1].bits = 0;
    ccr &= ~(1 << (MPU_NUM_REGIONS - 1));
    wbcr &= ~(1 << (MPU_NUM_REGIONS - 1));
    ccr &= ~(MMU_STATE_VALID << ((MPU_NUM_REGIONS - 1) * 2));


    /* put the new values into the registers */

    mmuPrrSet (regs);
    mmuCcrSet (ccr);
    mmuWbcrSet (wbcr);
    mmuPrSet (cpr);

    return;

    } /* mmuDeleteRegion() */

/******************************************************************************
*
* mmuStateGetRegion - get state of a memory region (ARM)
*
* This routine extracts the state information for a region and returns
* it as the "architecture-specific state".
*
* No locking is performed during this routine. If the region
* definitions are changed during the execution of this routine, an
* incorrect state can be returned.
*
* RETURNS: the (architecture-specific) state.
*/

LOCAL UINT32 mmuStateGetRegion
    (
    int region  /* the region number */
    )
    {
    UINT32 regState;

    /* Get C bit from Cache Control register */

    regState = (mmuCcrGet () << (7 - region)) & MMU_STATE_CACHE_BIT;

    /* Get WB bit from Write Buffer Control Register */

    regState |= ((mmuWbcrGet () << (7 - region)) >> 1) & MMU_STATE_BUFFERABLE;

    /* Get AP bits from Protection register */

    regState |= (mmuPrGet () >> (region * 2)) & MMU_STATE_VALID;

    return regState;

    } /* mmuStateGetRegion() */

/******************************************************************************
*
* mmuRegionModify - modify a memory region (ARM)
*
* This routine modifies the definition of a region.
*
* The MPU must be disabled while this routine is called.
*
* RETURNS: N/A.
*/

LOCAL void mmuRegionModify
    (
    MPU_REGION_REG *    regs,   /* the Protection Region Registers */
    int         region, /* the region number */
    UINT32      addr,   /* start address */
    UINT32      size,   /* size of region */
    UINT32      state,  /* (architecture-dependent) state to set */
    UINT32      stateMask /* (architecture-dependent) state mask */
    )
    {
    UINT32 val;

    MMU_LOG_MSG (MMU_DEBUG_MPU,
                 "regionModify: region= 0x%X, addr= 0x%X, size= 0x%X, state= 0x%X, stateMask= 0x%X\n",
                 region, addr, size, state, stateMask, 0);

    /* Create region definition in regs array. Mark it as active */

    if (size != MMU_ENTIRE_SPACE)
        regs[region].bits = (addr & MPU_REGION_BASE_MASK) | 0x01 |
                            ((ffsLsb (size) - 2) << 1);
    else
        regs[region].bits = MPU_REGION_SIZE_MAX | 0x01;


    /* write region definitions back to MPU Protection Region Registers. */

    mmuPrrSet (regs);

    /*
     * If modifying validity, get protection register, change it
     * and set it back.
     */

    if ((stateMask & MMU_STATE_MASK_VALID) != 0)
        {
        val = mmuPrGet();
        val &= ~((state & MMU_STATE_VALID) << (region * 2));
        val |= (state & MMU_STATE_VALID) << (region * 2);
        mmuPrSet(val);
        }

    /* If modifying cacheable status, set cache control and WB control regs */

    if ((stateMask & MMU_STATE_MASK_CACHEABLE) != 0)
        {
        val = mmuCcrGet();
        if ((state & MMU_STATE_CACHE_BIT) != 0)
            {
            val |= (1 << region);
            } else
            {
            val &= ~(1<< region);
            }
        mmuCcrSet (val);

        val = mmuWbcrGet();
        if ((state & MMU_STATE_BUFFERABLE) != 0)
            {
            val |= (1 << region);
            } else
            {
            val &= ~(1<< region);
            }
        mmuWbcrSet (val);
        }

    return;

    } /* mmuRegionModify() */

/******************************************************************************
*
* mmuRegionCreate - create a new memory region (ARM)
*
* This routine creates the definition of a region.
*
* The MPU must be disabled while this routine is called.
*
* RETURNS: N/A.
*/

LOCAL STATUS mmuRegionCreate
    (
    MPU_REGION_REG *    regs,   /* the Protection Region Registers */
    UINT32      addr,   /* start address */
    UINT32      size,   /* size of region */
    UINT32      state,  /* (architecture-dependent) state to set */
    UINT32      stateMask /* (architecture-dependent) state mask*/
    )
    {
    int i;

    MMU_LOG_MSG (MMU_DEBUG_MPU, "regionCreate: addr = 0x%X, size = 0x%X, state=%x, stateMask=%x\n",
                 addr, size, state, stateMask, 0, 0);

    /* Find the first free free region, starting from the lowest priority. */

    for (i = 0; i < MPU_NUM_REGIONS; i++)
        {
        if (regs[i].fields.enable == 0)
            {
            /* then region is free; modify region */

            mmuRegionModify(regs, i, addr, size, state, stateMask);
            break;
            }
        }

    if (i == MPU_NUM_REGIONS)
        {
        /* then there was no free region */

        errno = S_vmLib_NO_FREE_REGIONS;
        return ERROR;
        }

    return OK;
    }

/******************************************************************************
*
* mmuStateSetRegion - set state of memory region (ARM)
*
* mmuStateSetRegion is used to modify the state for the given region.
* The following states are provided:
*
* MMU_STATE_VALID	MMU_STATE_VALID_NOT	 valid/invalid
* MMU_STATE_CACHEABLE	MMU_STATE_CACHEABLE_NOT	 cacheable/not cacheable
*
* These may be OR'd together in the state parameter.  Additionally, masks
* are provided so that only specific states may be set:
*
* MMU_STATE_MASK_VALID
* MMU_STATE_MASK_CACEHABLE
*
* These may be OR'd together in the stateMask parameter.
*
* Accesses to a region marked as invalid will result in a bus error.
*
* RETURNS: OK or ERROR if cannot set state of or create the region.
*/

LOCAL STATUS mmuStateSetRegion
    (
    MMU_TRANS_TBL * transTbl,   /* translation table */
    void *      startAddr,  /* start address of region */
    UINT        stateMask,  /* mask of which state bits to modify */
    UINT        state,      /* new state bit values */
    UINT        size        /* size of region */
    )
    {
#define MPU_MATCH_OTHER 1
#define MPU_MATCH_SUBSET 2
#define MPU_MATCH_EXACT 3

    int     oldIntLev = 0;      /* keep compiler quiet */
    int     i;
    UINT32  regBase, regSize;
    int     match = MPU_MATCH_OTHER, match2 = MPU_MATCH_OTHER;
    int     region1 = -1, region2 = -1;
    UINT32  addr = (UINT32) startAddr;
    STATUS  ret = OK;

    /*
     * Obviously, if the entire address space has been specified, the
     * start address should be 0!
     */

    if (size == MMU_ENTIRE_SPACE)
        {
        if (addr != 0)
            {
            errno = S_vmLib_NOT_PAGE_ALIGNED;
            return ERROR;
            }
        } else
        {
        /* check size is an exact power of two */

        if (ffsMsb(size) != ffsLsb (size))
            {
            errno = S_vmLib_NOT_PAGE_ALIGNED;
            return ERROR;
            }

        /* check start address is appropriately aligned for size */

        if ((addr % size) != 0)
            {
            errno = S_vmLib_NOT_PAGE_ALIGNED;
            return ERROR;
            }
        }

    /* modify the MPU with all interrupts locked out including FIQs */

    MMU_UNLOCK (oldIntLev);

    /* Get the Protection Region Registers (region address definitions) */

    mmuPrrGet (transTbl->regs);

    /*
     * Search all current regions for an exact address match, or a
     * region that is a superset of the region requested. Also look for a
     * second match. Search from highest numbered (highest priority)
     * region downwards.
     */

    for (i = (MPU_NUM_REGIONS - 1); i >= 0; i--)
        {
        if ((transTbl->regs[i].bits & 0x01) != 0)
            {
            /* region is enabled, extract start and size of region */

            MMU_LOG_MSG (MMU_DEBUG_MPU, "check enabled region %d\n",
                         i, 0, 0, 0, 0, 0);

            regBase = transTbl->regs[i].bits & MPU_REGION_BASE_MASK;
            regSize = (transTbl->regs[i].bits & MPU_REGION_SIZE_MASK) >> 1;
            if (regSize == (MPU_REGION_SIZE_MAX >> 1))
                regSize = MMU_ENTIRE_SPACE;
            else
                regSize = 1 << (regSize + 1);

            if (((regBase <= addr) && ((regBase + regSize) > addr)) ||
                (regSize == MMU_ENTIRE_SPACE))
                {
                /* address starts within this region; is this second match? */

                MMU_LOG_MSG (MMU_DEBUG_MPU,
                             "address 0x%X within region %X size 0x%X, regBase = 0x%X, regSize = , 0x%X\n",
                             addr, i, size, regBase, regSize, 0);

                if (region1 == -1)
                    {
                    /* not found first match yet */

                    region1 = i;
                    MMU_LOG_MSG (MMU_DEBUG_MPU, "setting region1 = %d\n",
                                 i, 0, 0, 0, 0, 0);
                    if ((regBase == addr) && (regSize == size))
                        {
                        match = MPU_MATCH_EXACT;
                        MMU_LOG_MSG (MMU_DEBUG_MPU, "setting MATCH_EXACT\n",
                                     0, 0, 0, 0, 0, 0);
                        } else
                        if (((regBase + regSize) >= (addr + size)) ||
                            (regSize == MMU_ENTIRE_SPACE))
                        {
                        MMU_LOG_MSG (MMU_DEBUG_MPU,"setting MATCH_SUBSET\n",
                                     0, 0, 0, 0, 0, 0);
                        match = MPU_MATCH_SUBSET;
                        } else
                        {
                        MMU_LOG_MSG (MMU_DEBUG_MPU, "setting MATCH_OTHER\n",
                                     0, 0, 0, 0, 0, 0);
                        match = MPU_MATCH_OTHER;
                        }
                    } else
                    {
                    if (region2 == -1)
                        {
                        MMU_LOG_MSG (MMU_DEBUG_MPU, "setting region2 = %d\n",
                                     i, 0, 0, 0, 0, 0);
                        region2 = i;
                        if (((regBase == addr) && (regSize == size)) ||
                            ((regBase + regSize) >= (addr + size)) ||
                            (regSize == MMU_ENTIRE_SPACE))
                            match2 = MPU_MATCH_SUBSET;
                        else
                            match2 = MPU_MATCH_OTHER;
                        break;
                        }
                    }
                } /* endif within region */

            } /* endif region enabled */

        } /* endfor all regions */

    MMU_LOG_MSG (MMU_DEBUG_MPU,
                 "end of checks, region1 = %d, region2 = %d, match=%d\n",
                 region1, region2, match, 0, 0, 0);

    if ((region1 != -1) && (match == MPU_MATCH_SUBSET))
        {
        /*
         * Requested region is a subset of first matching region. If
         * state matches, nothing to do, else create new region.
         */

        MMU_LOG_MSG (MMU_DEBUG_MPU, "subset match\n", 0, 0, 0, 0, 0, 0);

        if (state != mmuStateGetRegion (region1))
            {
            /* state does not match existing region */

            ret = mmuRegionCreate (transTbl->regs, addr, size,
                                   state, stateMask);
            }
        } else
        {
        MMU_LOG_MSG (MMU_DEBUG_MPU, "else 1\n", 0, 0, 0, 0, 0, 0);
        if ((region1 == -1) || (match == MPU_MATCH_OTHER))
            {
            /*
             * Either the address start specified is not present within any
             * currently defined region or the region specified overlaps a
             * current region. Take simple approach and create a new region
             * for the request.
             */

            MMU_LOG_MSG (MMU_DEBUG_MPU,
                         "no match, region1 = %d, region2 = %d, match=%d\n",
                         region1, region2, match, 0, 0, 0);

            ret = mmuRegionCreate(transTbl->regs, addr, size, state, stateMask);
            } /* endif overlap or no matching region */
        else
            {
            MMU_LOG_MSG (MMU_DEBUG_MPU, "else 2\n", 0, 0, 0, 0, 0, 0);
            if (match == MPU_MATCH_EXACT)
                {
                MMU_LOG_MSG (MMU_DEBUG_MPU, "exact match\n", 0, 0, 0, 0, 0, 0);
                /*
                 * The requested regions address range exactly matches an
                 * existing region. Is the requested state the same as the
                 * existing one? If so, nothing to do.
                 */

                if ((state & stateMask) !=
                    (mmuStateGetRegion (region1) & stateMask))
                    {
                    MMU_LOG_MSG (MMU_DEBUG_MPU,
                                 "state mismatch: state, stateMask, regionState=%x, %x, %x\n"
                                 , state, stateMask,
                                 mmuStateGetRegion (region1), 0, 0, 0);
                    MMU_LOG_MSG (MMU_DEBUG_MPU,
                                 "match2 = %d\n", match2, 0, 0, 0, 0, 0);

                    /* state does not match existing region */

                    if (match2 == MPU_MATCH_SUBSET)
                        {
                        /*
                         * Requested region's address range is a subset of
                         * another region. Is the requested state the
                         * same as the other region? If so, we can delete
                         * the first matching region.
                         */

                        if ((state & stateMask) ==
                            (mmuStateGetRegion (region2) & stateMask))
                            mmuDeleteRegion (transTbl->regs, region1);
                        } else
                        {
                        /*
                         * We must modify the state of this region whose
                         * address range matches our address range.
                         */

                        mmuRegionModify(transTbl->regs, region1, addr, size,
                                        state, stateMask);
                        }
                    }
                }
            }

        } /* endif exact match */

    MMU_LOCK (oldIntLev);

    /* No TLBs to flush */

    return ret;

    } /* mmuStateSetRegion() */

    #endif /* ARM_HAS_MPU */

    #if (!ARM_HAS_MPU)
/******************************************************************************
*
* mmuStateSetMultiple - set state of several virtual memory pages (ARM)
*
* Simply calls mmuStateSet() in a loop.  It could probably be made faster,
* by inlining mmuStateSet() and not flushing until completely done,
* but this way is probably safer.
*
* RETURNS: OK or ERROR if virtual page does not exist.
*/

LOCAL STATUS mmuStateSetMultiple
    (
    MMU_TRANS_TBL * transTbl,   /* translation table */
    void *      pageAddr,   /* page whose state to modify */
    UINT        stateMask,  /* mask of which state bits to modify */
    UINT        state,      /* new state bit values */
    int         cnt     /* number of pages to set */
    )
    {
    int i;

    for (i = 0; i < cnt; ++i)
        {
        if (mmuStateSet (transTbl, (void *) (((UINT) pageAddr) + i * PAGE_SIZE),
                         stateMask, state) == ERROR)
            return ERROR;
        }

    return OK;

    } /* mmuStateSetMultiple() */
    #endif /* (!ARM_HAS_MPU) */

/******************************************************************************
*
* mmuStateGet - get state of virtual memory page (ARM)
*
* mmuStateGet is used to retrieve the state bits of the PTE for the given
* virtual page.  The following states are provided:
*
* MMU_STATE_VALID	MMU_STATE_VALID_NOT	 valid/invalid
* MMU_STATE_WRITABLE	MMU_STATE_WRITABLE_NOT	 writable/writeprotected
* MMU_STATE_CACHEABLE	MMU_STATE_CACHEABLE_NOT	 cacheable/not cacheable
*
* these are or'ed together in the returned state.  Additionally, masks
* are provided so that specific states may be extracted from the returned state:
*
* MMU_STATE_MASK_VALID
* MMU_STATE_MASK_WRITABLE
* MMU_STATE_MASK_CACHEABLE
*
* This routine is only called from vmLib, not from vmBaseLib.
*
* RETURNS: OK or ERROR if virtual page does not exist.
*/

LOCAL STATUS mmuStateGet
    (
    MMU_TRANS_TBL * transTbl,   /* translation table */
    void *      pageAddr,   /* page whose state we're querying */
    UINT *      state       /* place to return state value */
    )
    {
#if (!ARM_HAS_MPU)
    PTE *   pPte;

    if (mmuPteGet (transTbl, pageAddr, &pPte) != OK)
        return ERROR;


    /* extract PTE */

    *state = pPte->bits;

    return OK;

#else /* (!ARM_HAS_MPU) */
    return ERROR;
#endif
    } /* mmuStateGet() */

/******************************************************************************
*
* mmuPageMap - map physical memory page to virtual memory page (ARM)
*
* The physical page address is entered into the PTE corresponding to the
* given virtual page.  The state of a newly mapped page is undefined.
*
* This routine is only called from vmLib, not from vmBaseLib.
*
* RETURNS: OK or ERROR if translation table creation failed.
*/

LOCAL STATUS mmuPageMap
    (
    MMU_TRANS_TBL * transTbl,   /* translation table */
    void *      virtAddr,   /* virtual address */
    void *      physPage    /* physical address */
    )
    {
#if (!ARM_HAS_MPU)
    PTE *   pPte;
    int     oldIntLev;

    if (mmuPteGet (transTbl, virtAddr, &pPte) != OK)
        {
        /*
         * If there is no Level 2 descriptor (PTE) for this virtual
         * address, build the translation table for it.
         */

        if (mmuVirtualPageCreate (transTbl, virtAddr) != OK)
            return ERROR;


        /* If there is still no PTE, then something's wrong */

        if (mmuPteGet (transTbl, virtAddr, &pPte) != OK)
            return ERROR;
        } else    /* (SPR #27199) */
        {
        /* there is already a PTE, so we are *re*mapping this page */

        if (mmuEnabled)
            {
            cacheClear(DATA_CACHE, virtAddr, mmuPageSize);

#if ARMCACHE_NOT_COHERENT

            /* On 810, this will just do an IMB */

            cacheInvalidate (INSTRUCTION_CACHE, virtAddr, mmuPageSize);
#endif
            }
        }

    /* Fill in L2 Descriptor type (small page) and physical address */

    MMU_UNLOCK (oldIntLev);
#if (ARMMMU == ARMMMU_XSCALE)
    pPte->fields.type = PTE_TYPE_EX_PAGE;
#else
    pPte->fields.type = PTE_TYPE_SM_PAGE;
#endif
    pPte->fields.addr = (UINT)physPage >> ADDR_TO_PAGE;
    MMU_LOCK (oldIntLev);

    /*
     * Page entry has been updated in memory so flush the entry in the TLB
     * to be sure that the TLB will be updated during the next access to this
     * address.
     */

    mmuTLBIDFlushEntry (virtAddr);

    return OK;
#else /* (!ARM_HAS_MPU) */

    /*
     * Could argue that returning ERROR is appropriate, since calling this
     * routine is inappropriate, or could argue that return OK is
     * appropriate, since all addresses are "mapped" in the MPU all the
     * time. In any case, this routine is not called from vmBaseLib
     * which is all we support on MPU processors.
     */

    return OK;
#endif /* (!ARM_HAS_MPU) */
    } /* mmuPageMap() */

/******************************************************************************
*
* mmuGlobalPageMap - map physical memory page to global virtual memory (ARM)
*
* mmuGlobalPageMap is used to map physical pages into global virtual memory
* that is shared by all virtual memory contexts.  The translation tables
* for this section of the virtual space are shared by all virtual memory
* contexts.
*
* RETURNS: OK or ERROR if no page table entry for given virtual page.
*/

LOCAL STATUS mmuGlobalPageMap
    (
    void *  virtAddr,   /* virtual address */
    void *  physAddr    /* physical address */
    #if (ARM_HAS_MPU)
    ,
    UINT    len
    #endif
    )
    {
#if (!ARM_HAS_MPU)
    PTE *   pPte;
    int     oldIntLev = 0;

    if (mmuPteGet ((MMU_TRANS_TBL *) &mmuGlobalTransTbl, virtAddr,
                   &pPte) != OK)
        {
        /* build the translation table for the virtual address */

        if (mmuVirtualPageCreate ((MMU_TRANS_TBL *) &mmuGlobalTransTbl,
                                  virtAddr) != OK)
            return ERROR;

        if (mmuPteGet ((MMU_TRANS_TBL *) &mmuGlobalTransTbl, virtAddr,
                       &pPte) != OK)
            return ERROR;


        /* The globalPageBlock array is write protected, so unprotect it */

        mmuStateSet (&mmuGlobalTransTbl, globalPageBlock,
                     MMU_STATE_MASK_WRITABLE, MMU_STATE_WRITABLE);

        globalPageBlock [(unsigned) virtAddr / PAGE_BLOCK_SIZE] = (UINT8)TRUE;

        /*
         * It might be thought that we would wish to force the write to
         * occur while the area is marked as writable. However, the
         * writable status is checked at the time of execution of the
         * instruction, not at the time of the write, so even with a
         * copyback cache, we're OK and we do not need to do a
         * cacheFlush() on globalPageBlock.  ON CURRENT CACHE
         * DESIGNS!!.
         */

        mmuStateSet (&mmuGlobalTransTbl, globalPageBlock,
                     MMU_STATE_MASK_WRITABLE, MMU_STATE_WRITABLE_NOT);
        } else    /* (SPR #27199) */
        {
        /* there is already a PTE, so we are *re*mapping this page */

        if (mmuEnabled)
            {
            cacheClear(DATA_CACHE, virtAddr, mmuPageSize);

#if ARMCACHE_NOT_COHERENT

            /* On 810, this will just do an IMB */

            cacheInvalidate (INSTRUCTION_CACHE, virtAddr, mmuPageSize);
#endif
            }
        }

    MMU_UNLOCK (oldIntLev);
#if (ARMMMU == ARMMMU_XSCALE)
    pPte->fields.type = PTE_TYPE_EX_PAGE;
#else
    pPte->fields.type = PTE_TYPE_SM_PAGE;
#endif
    pPte->fields.addr =  (UINT)physAddr >> ADDR_TO_PAGE;
    MMU_LOCK (oldIntLev);

    /*
     * Page entry has been updated in memory so flush the entry in the TLB
     * to be sure that the TLB will be updated during the next access to this
     * address.
     */

    mmuTLBIDFlushEntry (virtAddr);

#else /* (!ARM_HAS_MPU) */

    /* All addresses are "mapped" in the MPU all the time. */

    if (physAddr != virtAddr)
        {
        errno = S_vmLib_ADDRS_NOT_EQUAL;
        return ERROR;
        }

#endif /* (!ARM_HAS_MPU) */

    return OK;

    } /* mmuGlobalPageMap() */

/******************************************************************************
*
* mmuTranslate - translate a virtual address to a physical address (ARM)
*
* Traverse the translation table and extract the physical address for the
* given virtual address from the PTE corresponding to the virtual address.
*
* RETURNS: OK or ERROR if no page table entry for given virtual address.
*/

LOCAL STATUS mmuTranslate
    (
    MMU_TRANS_TBL * transTbl,   /* translation table */
    void *      virtAddr,   /* virtual address */
    void **     physAddress /* place to return result */
    )
    {
#if (!ARM_HAS_MPU)
    PTE *pPte;

    if (mmuPteGet (transTbl, virtAddr, &pPte) != OK)
        {
        errno = S_mmuLib_NO_DESCRIPTOR;
        return ERROR;
        }

    /* Get physical page base address entry from Page Table Entry */

    *physAddress = (PTE *) pPte->fields.addr;


    /* Check that it is valid */

#if (ARMMMU == ARMMMU_XSCALE)
    if (pPte->fields.type != PTE_TYPE_EX_PAGE)
#else
    if (pPte->fields.type != PTE_TYPE_SM_PAGE)
#endif
        {
        errno = S_mmuLib_INVALID_DESCRIPTOR;
        return ERROR;
        }


    /* Shift page base address up to form correct physical address */

    *physAddress = (void *) ((UINT) *physAddress << ADDR_TO_PAGE);


    /* Add the lower address bits that are not changed by the MMU */

    *physAddress = (void*) ((UINT) *physAddress +
                            ((UINT) virtAddr & ADDR_PI_MASK));
#else

    /* MPUs do not perform virtual memory translation */

    *physAddress = virtAddr;

#endif /* (!ARM_HAS_MPU) */


    return OK;

    } /* mmuTranslate() */

    #if (!ARM_HAS_MPU)
/******************************************************************************
*
* mmuMemPagesWriteDisable - write disable a table's descriptors (ARM)
*
* This routine marks memory containing translation table descriptors as read
* only to protect the descriptors from being corrupted.  This routine write
* protects all the memory used to contain a given translation table's
* descriptors and marks it as non-cacheable.
*
* RETURNS: N/A
*/

LOCAL void mmuMemPagesWriteDisable
    (
    MMU_TRANS_TBL * pTransTbl
    )
    {
    LEVEL_1_DESC *  pL1;
    PTE *       pPte;
    int         i;

    pL1 = pTransTbl->pLevel1Table;


    /* Write protect the Level 1 Table and mark as non-cacheable */

#if (ARMMMU == ARMMMU_XSCALE)
    mmuStateSetMultiple (&mmuGlobalTransTbl, (void *) pL1,
                         MMU_STATE_MASK_WRITABLE | MMU_STATE_MASK_CACHEABLE | \
                         MMU_STATE_MASK_EX_CACHEABLE,
                         MMU_STATE_WRITABLE_NOT | MMU_STATE_CACHEABLE_NOT | \
                         MMU_STATE_EX_CACHEABLE_NOT,
                         L1_DESC_PAGES);
#else
    mmuStateSetMultiple (&mmuGlobalTransTbl, (void *) pL1,
                         MMU_STATE_MASK_WRITABLE | MMU_STATE_MASK_CACHEABLE,
                         MMU_STATE_WRITABLE_NOT | MMU_STATE_CACHEABLE_NOT,
                         L1_DESC_PAGES);
#endif


    /* Write protect the Page Tables and mark as non-cacheable */

    for (i = 0; i < NUM_L1_DESCS; i++, pL1++)
        {
        if (pL1->fields.type == DESC_TYPE_PAGE)
            {
            pPte = (PTE *) (((UINT32)(pL1->fields.addr)) << L1D_TO_BASE_SHIFT);

            /* convert Physical to Virtual Address */

            pPte = _func_armPhysToVirt (pPte);

#if (ARMMMU == ARMMMU_XSCALE)
            mmuStateSet (&mmuGlobalTransTbl, (void *) pPte,
                         MMU_STATE_MASK_WRITABLE | MMU_STATE_MASK_CACHEABLE | \
                         MMU_STATE_MASK_EX_CACHEABLE,
                         MMU_STATE_WRITABLE_NOT | MMU_STATE_CACHEABLE_NOT | \
                         MMU_STATE_EX_CACHEABLE_NOT);
#else
            mmuStateSet (&mmuGlobalTransTbl, (void *) pPte,
                         MMU_STATE_MASK_WRITABLE | MMU_STATE_MASK_CACHEABLE,
                         MMU_STATE_WRITABLE_NOT | MMU_STATE_CACHEABLE_NOT);
#endif
            }
        }

    return;

    } /* mmuMemPagesWriteDisable() */

    #endif /* (!ARM_HAS_MPU) */
/******************************************************************************
*
* mmuCurrentSet - change active translation table (ARM)
*
* This routine is used to change the virtual memory context.
*
* When not using VxVMI, this routine is called only once, from
* vmBaseLibInit().
*
* RETURNS: N/A
*/

LOCAL void mmuCurrentSet
    (
    MMU_TRANS_TBL * pTransTbl   /* new active translation table */
    )
    {
    int     oldLev;
#if (!ARM_HAS_MPU)
    LOCAL BOOL  firstTime = TRUE;


    if (firstTime)
        {
        /*
         * Write protect all the pages containing the PTEs allocated for
         * the global translation table.  Need to do this because when this
         * memory is allocated, the global trans tbl doesn't exist yet,
         * so the state sets fail.
         */

        mmuMemPagesWriteDisable (&mmuGlobalTransTbl);
        mmuMemPagesWriteDisable (pTransTbl);
        mmuStateSet (&mmuGlobalTransTbl, globalPageBlock,
                     MMU_STATE_MASK_WRITABLE, MMU_STATE_WRITABLE_NOT);


        mmuTLBIDFlushAll ();    /* for safety's sake, invalidate all TLBs */

        firstTime = FALSE;
        }
#endif /* (!ARM_HAS_MPU) */


    /*
     * We would like to protect the entire following sequence from FIQs
     * as well as IRQs but cannot as the cacheClear operation may take
     * too long. However, a small sequence of operations needs
     * to be indivisible, even by FIQs, so we disable FIQs. It should not
     * take too long.
     */

    oldLev = cacheArchIntLock ();   /* Disable at least IRQs */

    /*
     * Clear (flush and invalidate) the data cache (some pages may not be
     * cacheable).
     */

    cacheClear (DATA_CACHE, 0, ENTIRE_CACHE);


    /* Invalidate the instruction cache */

    cacheInvalidate (INSTRUCTION_CACHE, 0, ENTIRE_CACHE);


    intIFLock ();           /* Disable IRQs and FIQs */


#if (!ARM_HAS_MPU)

    /*
     * Point the MMU at the new translation table: put its address in the
     * Translation Table Base Register of the MMU. We have to assume that the
     * table is correctly aligned (to a 16 kbyte boundary).
     */

    mmuTtbrSet (_func_armVirtToPhys (pTransTbl->pLevel1Table));


    /*
     * Flush all the TLB entries (both Instruction and Data TLBs) because
     * all page tables have changed.
     */

    mmuTLBIDFlushAll ();
#else /* (!ARM_HAS_MPU) */

    /* Set protection region registers in MPU from table */

    mmuPrrSet (pTransTbl->regs);

#endif /* (!ARM_HAS_MPU) */


    intIFUnlock (oldLev);       /* restore int enable state */


    return;

    } /* mmuCurrentSet() */

    #if (!ARM_HAS_MPU)
/******************************************************************************
*
* mmuDummy - dummy address translation routine
*
* This routine is used as a dummy address translation routine
*
* RETURNS: the address passed as parameter
*/

LOCAL void * mmuDummy
    (
    void *  address         /* address to be translated */
    )
    {
    return address;

    } /* mmuDummy () */

    #endif /* (!ARM_HAS_MPU) */
#endif /* ARMMMU != ARMMMU_NONE */
