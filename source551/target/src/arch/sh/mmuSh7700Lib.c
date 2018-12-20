/* mmuSh7700Lib.c - Hitachi SH7700 MMU support library */

/* Copyright 1996-2001 Wind River Systems, Inc. */
#include "copyright_wrs.h"

/*
modification history
--------------------
01q,27feb01,hk   review on-line manual pages.
01p,03aug00,hk   got rid of globalPageBlock/localMmuCr/mmuEnabled. inlined
		 MMU_UNLOCK/MMU_LOCK. disabled caching translation table on
		 virtual space. changed mmuEnable() to call mmuOn() from P1.
		 merged mmuOn()/mmuOff() and put it in mmuSh7700ALib. changed
		 mmuStateSet()/mmuPageMap() to modify PTE from P2. changed
		 mmuGlobalPageMap() to use mmuPageMap(). reduced mmuTranslate().
		 changed mmuCurrentSet() to modify TTB and flush TLB from P2.
		 moved mmuTLBFlushOp() to mmuSh7700ALib. added TLB dump tools.
01o,09oct98,hk   added cacheClear in mmuTransTblInit and mmuVirtualPageCreate.
01n,08oct98,hk   splitted again as mmuSh7750Lib. added mmuTransTblSpace.
01m,29sep98,hk   merged MMU_STATE_MASK_WRITETHROUGH to MMU_STATE_MASK_CACHEABLE.
		 deleted reference to cacheDataMode in mmuStateSet().
01l,22sep98,hms  changed mmuStateTransArrayLocal[] to support PTEL's 
                 WT(WriteThrough) bit.
                 added include file cacheShLib.h for use SH7750_PHYS_MASK,
                 SH7750_P2_BASE def.
                 modified comments. optimized.
01k,17sep98,hk   merged mmuSh7750Lib.c.
01j,14sep98,hms  (mmuSh7750Lib.c) modified comments. optimized.
01i,17aug98,hms  (mmuSh7750Lib.c) derived from mmuSh7700Lib.c-01h.
01h,25jul97,hk   doc. corrected mmu30LibInit to mmuSh7700LibInit.
01g,27apr97,hk   added CACHE_DRV_FLUSH in mmuPageAlloc().
01f,03feb97,hk   moved TTB def for manual page.
01e,18jan97,hk   added TLB init code in mmuSh7700LibInit(). added clear code
                 for PTEL table in mmuVirtualPageCreate().
01d,30dec96,hk   used intVecBaseGet() for mmuPageAlloc().
01c,28dec96,hk   code review.
01b,25dec96,hk   comment review. moved mmuEnable, mmuOn, mmuOff, mmuTLBFlush,
                 and localMmucr to mmuSh7700ALib. made mmuEnabled global.
                 gathered physical address mask code to mmuPageAlloc().
01a,08jul96,wt   derived from mmu30Lib.c.(01l?)
*/

/*
DESCRIPTION:

mmuLib.c provides the architecture dependent routines that directly control
the memory management unit.  It provides 10 routines that are called by the
higher level architecture independent routines in vmLib.c: 

mmuLibInit        - initialize module
mmuTransTblCreate - create a new translation table
mmuTransTblDelete - delete a translation table.
mmuEnable         - turn mmu on or off
mmuStateSet       - set state of virtual memory page
mmuStateGet       - get state of virtual memory page
mmuPageMap        - map physical memory page to virtual memory page
mmuGlobalPageMap  - map physical memory page to global virtual memory page
mmuTranslate      - translate a virtual address to a physical address
mmuCurrentSet     - change active translation table

Applications using the mmu will never call these routines directly; 
the visable interface is supported in vmLib.c.

mmuLib supports the creation and maintenance of multiple translation tables,
one of which is the active translation table when the mmu is enabled.
Note that VxWorks does not include a translation table as part of the task
context;  individual tasks do not reside in private virtual memory.  However,
we include the facilities to create multiple translation tables so that
the user may create "private" virtual memory contexts and switch them in an
application specific manner.  New
translation tables are created with a call to mmuTransTblCreate, and installed
as the active translation table with mmuCurrentSet.  Translation tables
are modified and potentially augmented with calls to mmuPageMap and mmuStateSet.
The state of portions of the translation table can be read with calls to
mmuStateGet and mmuTranslate.

The traditional VxWorks architecture and design philosophy requires that all
objects and operating systems resources be visable and accessable to all agents
(tasks, isrs, watchdog timers, etc) in the system.  This has traditionally been
insured by the fact that all objects and data structures reside in physical 
memory; thus, a data structure created by one agent may be accessed by any
other agent using the same pointer (object identifiers in VxWorks are often
pointers to data structures.) This creates a potential
problem if you have multiple virtual memory contexts.  For example, if a
semaphore is created in one virtual memory context, you must gurantee that
that semaphore will be visable in all virtual memory contexts if the semaphore
is to be accessed at interrupt level, when a virtual memory context other than
the one in which it was created may be active. Another example is that
code loaded using the incremental loader from the shell must be accessable
in all virtual memory contexts, since code is shared by all agents in the
system.

This problem is resolved by maintaining a global "transparent" mapping
of virtual to physical memory for all the contiguous segments of physical
memory (on board memory, i/o space, sections of vme space, etc) that is shared
by all translation tables;  all available  physical memory appears at the same 
address in virtual memory in all virtual memory contexts. This technique 
provides an environment that allows
resources that rely on a globally accessable physical address to run without
modification in a system with multiple virtual memory contexts.

An additional requirement is that modifications made to the state of global 
virtual memory in one translation table appear in all translation tables.  For
example, memory containing the text segment is made read only (to avoid
accidental corruption) by setting the appropriate writeable bits in the 
translation table entries corresponding to the virtual memory containing the 
text segment.  This state information must be shared by all virtual memory 
contexts, so that no matter what translation table is active, the text segment
is protected from corruption.  The mechanism that implements this feature is
architecture dependent, but usually entails building a section of a 
translation table that corresponds to the global memory, that is shared by
all other translation tables.  Thus, when changes to the state of the global
memory are made in one translation table, the changes are reflected in all
other translation tables.

mmuLib provides a seperate call for constructing global virtual memory -
mmuGlobalPageMap - which creates translation table entries that are shared
by all translation tables.  Initialization code in usrConfig makes calls
to vmGlobalMap (which in turn calls mmuGlobalPageMap) to set up global 
transparent virtual memory for all
available physical memory.  All calls made to mmuGlobaPageMap must occur before
any virtual memory contexts are created;  changes made to global virtual
memory after virtual memory contexts are created are not guaranteed to be
reflected in all virtual memory contexts.

Most mmu architectures will dedicate some fixed amount of virtual memory to 
a minimal section of the translation table (a "segment", or "block").  This 
creates a problem in that the user may map a small section of virtual memory
into the global translation tables, and then attempt to use the virtual memory
after this section as private virtual memory.  The problem is that the 
translation table entries for this virtual memory are contained in the global 
translation tables, and are thus shared by all translation tables.  This 
condition is detected by vmMap, and an error is returned, thus, the lower
level routines in mmuLib.c (mmuPageMap, mmuGlobalPageMap) need not perform
any error checking.

A global variable called mmuPageBlockSize should be defined which is equal to 
the minimum virtual segment size.

This module supports the SH7700 mmu with a two level translation table:

.CS
			    root
			     |
			     |
            --------------------------------
 top level  | td | td | td | td | td | td | ... 
            --------------------------------
	       |    |    |    |    |    |    
	       |    |    |    |    |    |    
      ----------    |    v    v    v    v
      |         -----   NULL NULL NULL NULL
      |         |
      v         v
     ------     ------
l   | ptel |   | ptel |
o    ------     ------
w   | ptel |   | ptel |    
e    ------     ------
r   | ptel |   | ptel |
l    ------     ------
e   | ptel |   | ptel |
v    ------     ------
e     .         .
l     .         .
      .         .
.CE

where the top level consists of an array of pointers (Table Descriptors)
held within a single
4k page.  These point to arrays of PTEL (Page Table Entry Low) arrays in
the lower level.  Each of these lower level arrays is also held within a single
4k page, and describes a virtual space of 4MB (each page
descriptor is 4 bytes, so we get 1024 of these in each array, and each page
descriptor maps a 4KB page - thus 1024 * 4096 = 4MB.)  

To implement global virtual memory, a seperate translation table called 
mmuGlobalTransTbl is created when the module is initialized.  Calls to 
mmuGlobalPageMap will augment and modify this translation table.  When new
translation tables are created, memory for the top level array of td's is
allocated and initialized by duplicating the pointers in mmuGlobalTransTbl's
top level td array.  Thus, the new translation table will use the global
translation table's state information for portions of virtual memory that are
defined as global.  Here's a picture to illustrate:

.CS
	         GLOBAL TRANS TBL		      NEW TRANS TBL

 		       root				   root
		        |				    |
		        |				    |
            -------------------------           -------------------------
 top level  | td1 | td2 | NULL| NULL|           | td1 | td2 | NULL| NULL|
            -------------------------           -------------------------
	       |     |     |     |                 |     |     |     |   
	       |     |     |     |                 |     |     |     |  
      ----------     |     v     v        ----------     |     v     v
      |         ------    NULL  NULL      |		 |    NULL  NULL
      |         |			  |		 |
      o------------------------------------		 |
      |		|					 |
      |		o-----------------------------------------
      |		|
      v         v
     ------     ------   
l   | ptel |   | ptel |
o    ------     ------
w   | ptel |   | ptel |     
e    ------     ------
r   | ptel |   | ptel |
l    ------     ------
e   | ptel |   | ptel |
v    ------     ------
e     .         .
l     .         .
      .         .
.CE

Note that with this scheme, the global memory granularity is 4MB.  Each time
you map a section of global virtual memory, you dedicate at least 4MB of 
the virtual space to global virtual memory that will be shared by all virtual
memory contexts.

The physcial memory that holds these data structures is obtained from the
system memory manager via memalign to insure that the memory is page
aligned.  We want to protect this memory from being corrupted,
so we invalidate the descriptors that we set up in the global translation
that correspond to the memory containing the translation table data structures.
This creates a "chicken and the egg" paradox, in that the only way we can
modify these data structures is through virtual memory that is now invalidated,
and we can't validate it because the page descriptors for that memory are
in invalidated memory (confused yet?)
So, you will notice that anywhere that page table descriptors (ptel's)
are modified, we do so by locking out interrupts, momentarily disabling the
mmu, accessing the memory with its physical address, enabling the mmu, and
then re-enabling interrupts (see mmuStateSet, for example.)

USER MODIFIABLE OPTIONS:

1) Memory fragmentation - mmuLib obtains memory from the system memory
   manager via memalign to contain the mmu's translation tables.  This memory
   was allocated a page at a time on page boundries.  Unfortunately, in the
   current memory management scheme, the memory manager is not able to allocate
   these pages contiguously.  Building large translation tables (ie, when
   mapping large portions of virtual memory) causes excessive fragmentation
   of the system memory pool.  An attempt to alleviate this has been installed
   by providing a local buffer of page aligned memory;  the user may control
   the buffer size by manipulating the global variable mmuNumPagesInFreeList.
   By default, mmuPagesInFreeList is set to 8.

2) Alternate memory source - A customer has special purpose hardware that
   includes seperate static RAM for the mmu's translation tables.  Thus, they
   require the ability to specify an alternate source of memory other than
   memalign.  A global variable has been created that points to the memory
   partition to be used as the source for translation table memory; by default,
   it points to the system memory partition.  The user may modify this to 
   point to another memory partition before mmuSh7700LibInit is called.
*/


#include "vxWorks.h"
#include "string.h"
#include "intLib.h"
#include "stdlib.h"
#include "memLib.h"
#include "private/memPartLibP.h"
#include "private/vmLibP.h"
#include "arch/sh/mmuSh7700Lib.h"
#include "mmuLib.h"
#include "errno.h"
#include "cacheLib.h"

/* imports */

IMPORT STATE_TRANS_TUPLE *mmuStateTransArray;		/* vmLib.c */
IMPORT int                mmuStateTransArraySize;	/* vmLib.c */
IMPORT MMU_LIB_FUNCS      mmuLibFuncs;			/* vmLib.c */
IMPORT int                mmuPageBlockSize;		/* vmLib.c */

IMPORT INT32 mmuCrSetOp (INT32 val);
IMPORT INT32 mmuOnOp (BOOL enable);
IMPORT void mmuTLBFlushOp (void *v_addr);
IMPORT void mmuATTRSetOp (UINT32 *pPte, UINT32 stateMask, UINT32 state, void *v_addr);
IMPORT void mmuPPNSetOp (UINT32 *pPte, void *p_addr, void *v_addr);
IMPORT void mmuTTBSetOp (PTE *p_addr);

/* forward declarations */
 
LOCAL MMU_TRANS_TBL *mmuTransTblCreate ();
LOCAL STATUS mmuTransTblInit (MMU_TRANS_TBL *transTbl);
LOCAL STATUS mmuTransTblDelete (MMU_TRANS_TBL *transTbl);
LOCAL STATUS mmuVirtualPageCreate (MMU_TRANS_TBL *transTbl, void *v_addr);
LOCAL STATUS mmuEnable (BOOL enable);
LOCAL STATUS mmuStateGet (MMU_TRANS_TBL *transTbl, void *v_addr, UINT *state);
LOCAL STATUS mmuStateSet (MMU_TRANS_TBL *transTbl, void *v_addr, UINT stateMask, UINT state);
LOCAL STATUS mmuPageMap (MMU_TRANS_TBL *transTbl, void *v_addr, void *p_addr);
LOCAL STATUS mmuGlobalPageMap (void *v_addr, void *p_addr);
LOCAL STATUS mmuTranslate (MMU_TRANS_TBL *transTbl, void *v_addr, void **p_addr);
LOCAL STATUS mmuPteGet (MMU_TRANS_TBL *transTbl, void *v_addr, PTE **result);
LOCAL void mmuCurrentSet (MMU_TRANS_TBL *transTbl);
LOCAL void mmuTblWriteDisable (MMU_TRANS_TBL *transTbl);
LOCAL char *mmuPageAlloc (MMU_TRANS_TBL *transTbl);

/* globals */

int     mmuPageSize;
int     mmuNumPagesInFreeList = 8;
PART_ID mmuPageSource = NULL;
UINT32	mmuTransTblSpace = SH7700_P2_BASE;

/* local function pointers to relocate mmuSh7700ALib entries */

LOCAL FUNCPTR     mmuCrSet	=     (FUNCPTR)0x1234;
LOCAL FUNCPTR     mmuOn		=     (FUNCPTR)0x1234;
LOCAL VOIDFUNCPTR mmuTLBFlush	= (VOIDFUNCPTR)0x1234;
LOCAL VOIDFUNCPTR mmuATTRSet	= (VOIDFUNCPTR)0x1234;
LOCAL VOIDFUNCPTR mmuPPNSet	= (VOIDFUNCPTR)0x1234;
LOCAL VOIDFUNCPTR mmuTTBSet	= (VOIDFUNCPTR)0x1234;

/* a translation table to hold the descriptors for the global transparent
 * translation of physical to virtual memory 
 */

LOCAL MMU_TRANS_TBL mmuGlobalTransTbl;

/* initially, the current trans table is a dummy table with mmu disabled */

LOCAL MMU_TRANS_TBL *mmuCurrentTransTbl = &mmuGlobalTransTbl;


LOCAL STATE_TRANS_TUPLE mmuStateTransArrayLocal [] =		/* vmLibP.h */
    {

    {VM_STATE_MASK_VALID,             MMU_STATE_MASK_VALID,
     VM_STATE_VALID,                  MMU_STATE_VALID},

    {VM_STATE_MASK_VALID,             MMU_STATE_MASK_VALID, 
     VM_STATE_VALID_NOT,              MMU_STATE_VALID_NOT},

    {VM_STATE_MASK_WRITABLE,          MMU_STATE_MASK_WRITABLE,
     VM_STATE_WRITABLE,               MMU_STATE_WRITABLE},

    {VM_STATE_MASK_WRITABLE,          MMU_STATE_MASK_WRITABLE,
     VM_STATE_WRITABLE_NOT,           MMU_STATE_WRITABLE_NOT},

    {VM_STATE_MASK_CACHEABLE,         MMU_STATE_MASK_CACHEABLE,
     VM_STATE_CACHEABLE,              MMU_STATE_CACHEABLE},
#if (CPU==SH7750)
    {VM_STATE_MASK_CACHEABLE,         MMU_STATE_MASK_CACHEABLE,
     VM_STATE_CACHEABLE_WRITETHROUGH, MMU_STATE_CACHEABLE_WRITETHROUGH},
#endif
    {VM_STATE_MASK_CACHEABLE,         MMU_STATE_MASK_CACHEABLE,
     VM_STATE_CACHEABLE_NOT,          MMU_STATE_CACHEABLE_NOT}

    };

LOCAL MMU_LIB_FUNCS mmuLibFuncsLocal =				/* vmLibP.h */
    {
    mmuSh7700LibInit,		/* FUNCPTR mmuLibInit;        */
    mmuTransTblCreate,		/* MMU_TRANS_TBL_ID (*mmuTransTblCreate) (); */
    mmuTransTblDelete,		/* FUNCPTR mmuTransTblDelete; */
    mmuEnable,			/* FUNCPTR mmuEnable;         */
    mmuStateSet,		/* FUNCPTR mmuStateSet;       */
    mmuStateGet,		/* FUNCPTR mmuStateGet;       */
    mmuPageMap,			/* FUNCPTR mmuPageMap;        */
    mmuGlobalPageMap,		/* FUNCPTR mmuGlobalPageMap;  */
    mmuTranslate,		/* FUNCPTR mmuTranslate;      */
    mmuCurrentSet		/* VOIDFUNCPTR mmuCurrentSet; */
    };

/******************************************************************************
*
* mmuSh7700LibInit - initialize module
*
* Build a dummy translation table that will hold the page table entries for
* the global translation table.  The mmu remains disabled upon
* completion.  Note that this routine is global so that it may be referenced
* in usrConfig.c to pull in the correct mmuLib for the specific architecture.
*
* RETURNS: OK or ERROR
*/

STATUS mmuSh7700LibInit 
    (
    int pageSize
    )
    {
    PTE *v_page;
    int i;

    mmuCrSet = (FUNCPTR)(((UINT32)mmuCrSetOp
				& SH7700_PHYS_MASK) | SH7700_P1_BASE);
    mmuOn = (FUNCPTR)(((UINT32)mmuOnOp
				& SH7700_PHYS_MASK) | SH7700_P1_BASE);
    mmuTLBFlush = (VOIDFUNCPTR)(((UINT32)mmuTLBFlushOp
				& SH7700_PHYS_MASK) | SH7700_P2_BASE);
    mmuATTRSet = (VOIDFUNCPTR)(((UINT32)mmuATTRSetOp
				& SH7700_PHYS_MASK) | SH7700_P2_BASE);
    mmuPPNSet = (VOIDFUNCPTR)(((UINT32)mmuPPNSetOp
				& SH7700_PHYS_MASK) | SH7700_P2_BASE);
    mmuTTBSet = (VOIDFUNCPTR)(((UINT32)mmuTTBSetOp
				& SH7700_PHYS_MASK) | SH7700_P2_BASE);

    mmuCrSet (0x00000104);	/* reset mmu (SV=1 TI=1 AT=0) */

    /* if the user has not specified a memory partition to obtain pages 
     * from (by initializing mmuPageSource), then initialize mmuPageSource
     * to the system memory partition.
     */
    if (mmuPageSource == NULL)
	mmuPageSource = memSysPartId;

    /* initialize the data objects that are shared with vmLib.c */

    mmuStateTransArray = &mmuStateTransArrayLocal [0];
    mmuStateTransArraySize =
		sizeof(mmuStateTransArrayLocal) / sizeof(STATE_TRANS_TUPLE);
    mmuLibFuncs = mmuLibFuncsLocal;
    mmuPageBlockSize = PAGE_BLOCK_SIZE;

    if (pageSize != 4096)
	{
	errno = S_mmuLib_INVALID_PAGE_SIZE;
	return ERROR;
	}

    mmuPageSize = pageSize;

    /* build a dummy translation table which will hold the pte's for
     * global memory.  All real translation tables will point to this
     * one for controling the state of the global virtual memory.
     */

    lstInit (&mmuGlobalTransTbl.memFreePageList);

    mmuGlobalTransTbl.memBlocksUsedArray =
	calloc (MMU_BLOCKS_USED_SIZE, sizeof(void *));		/* 64 x 4 */

    if (mmuGlobalTransTbl.memBlocksUsedArray == NULL)
	return ERROR;

    mmuGlobalTransTbl.memBlocksUsedIndex = 0;
    mmuGlobalTransTbl.memBlocksUsedSize  = MMU_BLOCKS_USED_SIZE;

    /* allocate a page to hold the upper level descriptor array */

    mmuGlobalTransTbl.vUpperTbl = v_page = 
	(PTE *)mmuPageAlloc (&mmuGlobalTransTbl);

    if (v_page == NULL)
	return ERROR;

    for (i = 0; i < UPPER_TBL_SIZE; i++)
	v_page[i].pte.td.asint = -1;	/* invalidate all descriptors */

    /* write back the upper level table onto physical memory */

    cacheClear (DATA_CACHE, v_page, UPPER_TBL_SIZE * sizeof(PTE));

    return OK;
    }

/******************************************************************************
*
* mmuTransTblCreate - create a new translation table.
*
* create a translation table.  Allocates space for the MMU_TRANS_TBL
* data structure and calls mmuTransTblInit on that object.  
*
* RETURNS: address of new object or NULL if allocation failed,
*          or NULL if initialization failed.
*/

LOCAL MMU_TRANS_TBL *mmuTransTblCreate ()
    {
    MMU_TRANS_TBL *transTbl = (MMU_TRANS_TBL *)malloc (sizeof(MMU_TRANS_TBL));

    if (transTbl == NULL)
	return NULL;

    if (mmuTransTblInit (transTbl) == ERROR)
	{
	free ((char *)transTbl);
	return NULL;
	}

    return transTbl;
    }

/******************************************************************************
*
* mmuTransTblInit - initialize a new translation table 
*
* Initialize a new translation table.  The upper level is copied from the
* global translation mmuGlobalTransTbl, so that we will share the global
* virtual memory with all other translation tables.
*
* NOTE: This routine is called from mmuTransTblCreate() only.
* 
* RETURNS: OK or ERROR if unable to allocate memory for upper level.
*/

LOCAL STATUS mmuTransTblInit 
    (
    MMU_TRANS_TBL *transTbl
    )
    {
    PTE *v_page;		/* virtual address of upper page table */

    lstInit (&transTbl->memFreePageList);

    transTbl->memBlocksUsedArray = calloc (MMU_BLOCKS_USED_SIZE,sizeof(void *));

    if (transTbl->memBlocksUsedArray == NULL)
	return ERROR;

    transTbl->memBlocksUsedIndex = 0;
    transTbl->memBlocksUsedSize  = MMU_BLOCKS_USED_SIZE;

    /* allocate a page to hold the upper level descriptor array */

    transTbl->vUpperTbl = v_page = (PTE *)mmuPageAlloc (transTbl);

    if (v_page == NULL)
	return ERROR;

    /* copy the upperlevel table from mmuGlobalTransTbl,
     * so we get the global virtual memory 
     */

    bcopy ((char *)mmuGlobalTransTbl.vUpperTbl, (char *)v_page, mmuPageSize);

    /* write back the upper table onto physical memory */

    cacheClear (DATA_CACHE, v_page, mmuPageSize);

    /* write protect virtual memory pointing to the the upper level table in 
     * the global translation table to insure that it can't be corrupted 
     */
    mmuStateSet (&mmuGlobalTransTbl, (void *)v_page, 
		 MMU_STATE_MASK_WRITABLE | MMU_STATE_MASK_CACHEABLE,
		 MMU_STATE_WRITABLE_NOT  | MMU_STATE_CACHEABLE_NOT);
    return OK;
    }

/******************************************************************************
*
* mmuTransTblDelete - delete a translation table.
* 
* mmuTransTblDelete deallocates all the memory used to store the translation
* table entries.  It does not deallocate physical pages mapped into the
* virtual memory space.
*
* RETURNS: OK
*/

LOCAL STATUS mmuTransTblDelete 
    (
    MMU_TRANS_TBL *transTbl
    )
    {
    int i;

    /* write enable the physical page containing the upper level pte */

    mmuStateSet (&mmuGlobalTransTbl, transTbl->vUpperTbl, 
		 MMU_STATE_MASK_WRITABLE, MMU_STATE_WRITABLE);

    /* free all the blocks of pages in memBlocksUsedArray */

    for (i = 0; i < transTbl->memBlocksUsedIndex; i++)
	free (transTbl->memBlocksUsedArray[i]);

    free (transTbl->memBlocksUsedArray);

    /* free the translation table data structure */

    free (transTbl);

    return OK;
    }

/******************************************************************************
*
* mmuVirtualPageCreate - set up translation tables for a virtual page
*
* simply check if there's already a lower level ptel array that has a
* pte for the given virtual page.  If there isn't, create one.
*
* RETURNS OK or ERROR if couldn't allocate space for lower level ptel array.
*/

LOCAL STATUS mmuVirtualPageCreate 
    (
    MMU_TRANS_TBL *transTbl,
    void *v_addr			/* virtual addr to create */
    )
    {
    PTE *vUpperPte;
    PTE *v_page;
    PTE *dummy;
    UINT i;

    if (mmuPteGet (transTbl, v_addr, &dummy) == OK)
	return OK;

    v_page = (PTE *)mmuPageAlloc (transTbl);		/* virtual address */

    if (v_page == NULL)
	return ERROR;

    /* invalidate every page in the new page block */

    for (i = 0; i < LOWER_TBL_SIZE; i++)
	{
	v_page[i].pte.l.bits              = 0;
#if (CPU==SH7700)
	v_page[i].pte.l.fields.ppn        = -1;
	v_page[i].pte.l.fields.valid      = 0;
	v_page[i].pte.l.fields.protection = 0; 
	v_page[i].pte.l.fields.size       = 1; /* 4k bytes page */
	v_page[i].pte.l.fields.cachable   = 0; 
	v_page[i].pte.l.fields.dirty      = 1;
	v_page[i].pte.l.fields.share      = 0;
#elif (CPU==SH7750)
	v_page[i].pte.l.fields.ppn        = -1;
	v_page[i].pte.l.fields.valid      = 0;
	v_page[i].pte.l.fields.size1      = 0; /* 4k bytes page */
	v_page[i].pte.l.fields.protection = 0; 
	v_page[i].pte.l.fields.size2      = 1; /* 4k bytes page */
	v_page[i].pte.l.fields.cachable   = 0; 
	v_page[i].pte.l.fields.dirty      = 1;
	v_page[i].pte.l.fields.share      = 0;
	v_page[i].pte.l.fields.wt         = 0;
#endif
	}

    /* write back the lower level table onto physical memory */

    cacheClear (DATA_CACHE, v_page, LOWER_TBL_SIZE * sizeof(PTE));

    /* write protect the new physical page containing the pte's
     * for this new page block
     */
    mmuStateSet (&mmuGlobalTransTbl, v_page, 
   		 MMU_STATE_MASK_WRITABLE | MMU_STATE_MASK_CACHEABLE,
		 MMU_STATE_WRITABLE_NOT  | MMU_STATE_CACHEABLE_NOT); 

    /* unlock the physical page containing the upper level pte,
     * so we can modify it
     */
    mmuStateSet (&mmuGlobalTransTbl, transTbl->vUpperTbl,
                 MMU_STATE_MASK_WRITABLE, MMU_STATE_WRITABLE);

    vUpperPte = &transTbl->vUpperTbl [(UINT)v_addr / PAGE_BLOCK_SIZE];

    /* modify the upperLevel pte to point to the new lowerLevel pte */

    vUpperPte->pte.td.adrs
	= (PAGE_DESC *)(((UINT32)v_page & SH7700_PHYS_MASK) | mmuTransTblSpace);

    /* write back the upperLevel pte onto physical memory */

    cacheClear (DATA_CACHE, vUpperPte, sizeof(PTE));

    /* write protect the upper level pte table */

    mmuStateSet (&mmuGlobalTransTbl, transTbl->vUpperTbl,
                 MMU_STATE_MASK_WRITABLE | MMU_STATE_MASK_CACHEABLE,
		 MMU_STATE_WRITABLE_NOT  | MMU_STATE_CACHEABLE_NOT);

    mmuTLBFlush (v_addr);
    return OK;
    }

/******************************************************************************
*
* mmuEnable - turn mmu on or off
* 
*/

LOCAL STATUS mmuEnable
    (
    BOOL enable
    )
    {
    int key = intLock ();	/* LOCK INTERRUPTS */

    mmuOn (enable);

    intUnlock (key);		/* UNLOCK INTERRUPTS */

    return OK;
    }

/******************************************************************************
*
* mmuStateGet - get state of virtual memory page
*
* mmuStateGet is used to retrieve the state bits of the pte for the given
* virtual page.  The following states are provided:
*
* MMU_STATE_VALID 	MMU_STATE_VALID_NOT	 valid/invalid
* MMU_STATE_WRITABLE 	MMU_STATE_WRITABLE_NOT	 writable/writeprotected
* MMU_STATE_CACHEABLE 	MMU_STATE_CACHEABLE_NOT	 notcachable/cachable
* MMU_STATE_CACHEABLE_WRITETHROUGH		 write through(SH7750)
*
* these are or'ed together in the returned state.  Additionally, masks
* are provided so that specific states may be extracted from the returned state:
*
* MMU_STATE_MASK_VALID 
* MMU_STATE_MASK_WRITABLE
* MMU_STATE_MASK_CACHEABLE
*
* RETURNS: OK or ERROR if virtual page does not exist.
*/

LOCAL STATUS mmuStateGet 
    (
    MMU_TRANS_TBL *transTbl,
    void *v_addr,		/* page whose state we're querying */
    UINT *state			/* place to return state value */
    )
    {
    PTE *pPhys;

    if (mmuPteGet (transTbl, v_addr, &pPhys) != OK)
	return ERROR;

    *state = pPhys->pte.l.bits; 

    return OK;
    }

/******************************************************************************
*
* mmuStateSet - set state of virtual memory page
*
* mmuStateSet is used to modify the state bits of the pte for the given
* virtual page.  The following states are provided:
*
* MMU_STATE_VALID 	MMU_STATE_VALID_NOT	 valid/invalid
* MMU_STATE_WRITABLE 	MMU_STATE_WRITABLE_NOT	 writable/writeprotected
* MMU_STATE_CACHEABLE 	MMU_STATE_CACHEABLE_NOT	 notcachable/cachable
* MMU_STATE_CACHEABLE_WRITETHROUGH	       	 write through (SH7750)
*
* these may be or'ed together in the state parameter.  Additionally, masks
* are provided so that only specific states may be set:
*
* MMU_STATE_MASK_VALID 
* MMU_STATE_MASK_WRITABLE
* MMU_STATE_MASK_CACHEABLE
*
* These may be or'ed together in the stateMask parameter.  
*
* Accesses to a virtual page marked as invalid will result in a bus error.
*
* RETURNS: OK or ERROR if virtual page does not exist.
*/

LOCAL STATUS mmuStateSet 
    (
    MMU_TRANS_TBL *transTbl,
    void *v_addr,		/* virtual page whose state to modify */ 
    UINT stateMask,		/* mask of which state bits to modify */
    UINT state			/* new state bit values */
    )
    {
    int key;
    PTE *pPte;			/* physical address of PTE on memory */

    if (mmuPteGet (transTbl, v_addr, &pPte) != OK)
	return ERROR;

    /* modify the pte with mmu turned off and interrupts locked out */

    key = intLock ();

    mmuATTRSet (pPte, stateMask, state, v_addr);

    intUnlock (key);

    return OK;
    }

/******************************************************************************
*
* mmuPageMap - map physical memory page to virtual memory page
*
* The physical page address is entered into the pte corresponding to the
* given virtual page.  The state of a newly mapped page is undefined. 
*
* RETURNS: OK or ERROR if translation table creation failed. 
*/

LOCAL STATUS mmuPageMap 
    (
    MMU_TRANS_TBL *transTbl,
    void *v_addr,
    void *p_addr			/* physical address  */
    )
    {
    int key;
    PTE *pPte;

    if (mmuPteGet (transTbl, v_addr, &pPte) != OK)
	{
	/* build the translation table for the virtual address */

	if (mmuVirtualPageCreate (transTbl, v_addr) != OK)
	    return ERROR;

	if (mmuPteGet (transTbl, v_addr, &pPte) != OK)
	    return ERROR;
	}

    key = intLock ();

    mmuPPNSet (pPte, p_addr, v_addr);

    intUnlock (key);

    return OK;
    }

/******************************************************************************
*
* mmuGlobalPageMap - map physical memory page to global virtual memory page
*
* mmuGlobalPageMap is used to map physical pages into global virtual memory
* that is shared by all virtual memory contexts.  The translation tables
* for this section of the virtual space are shared by all virtual memory
* contexts.
*
* RETURNS: OK or ERROR if no pte for given virtual page.
*/

LOCAL STATUS mmuGlobalPageMap 
    (
    void *v_addr,
    void *p_addr
    )
    {
    return (mmuPageMap (&mmuGlobalTransTbl, v_addr, p_addr));
    }

/******************************************************************************
*
* mmuTranslate - translate a virtual address to a physical address
*
* Traverse the translation table and extract the physical address for the
* given virtual address from the pte corresponding to the virtual address.
*
* RETURNS: OK or ERROR if no pte for given virtual address.
*/

LOCAL STATUS mmuTranslate 
    (
    MMU_TRANS_TBL *transTbl,
    void  *v_addr,
    void **p_addr		/* put physical address here */
    )
    {
    PTE *pPhys;

    if (mmuPteGet (transTbl, v_addr, &pPhys) != OK)
	{
	errno = S_mmuLib_NO_DESCRIPTOR; 
	return ERROR;
	}

    if (pPhys->pte.l.fields.valid == 0)
	{
	errno = S_mmuLib_INVALID_DESCRIPTOR;
	return ERROR;
	}

    *p_addr = (void *)((pPhys->pte.l.fields.ppn << 10) +
		       ((UINT32)v_addr & PAGE_OFFSET_MASK));
    return OK;
    }

/******************************************************************************
*
* mmuPteGet - get the pte for a given page
*
* mmuPteGet traverses a translation table and returns the (physical) address
* of the pte for the given virtual address.
*
* RETURNS: OK or ERROR if there is no virtual space for the given address 
*/

LOCAL STATUS mmuPteGet 
    (
    MMU_TRANS_TBL *transTbl,
    void *v_addr,
    PTE **result			/* return result here */
    )
    {
    PTE *lowerPtr = &transTbl->vUpperTbl [(UINT)v_addr / PAGE_BLOCK_SIZE];
    PTE *pa_LowTbl = (PTE *)(lowerPtr->pte.td.adrs);
    int  index;

    if ((UINT)pa_LowTbl == 0xffffffff)
	return ERROR;

    index = ((UINT)v_addr >> BITS_PAGE_OFFSET) & (LOWER_TBL_SIZE - 1);

    *result = &pa_LowTbl [index];

    return OK;
    }

/******************************************************************************
*
* mmuCurrentSet - change active translation table
*
* mmuCurrentSet is used to change the virtual memory context.  Load the TTB
* (translation table base) register with the given translation table.
*/

LOCAL void mmuCurrentSet 
    (
    MMU_TRANS_TBL *transTbl		/* new active tranlation table */
    ) 
    {
    int key;
    static BOOL firstTime = TRUE;

    if (firstTime)
	{
	mmuTblWriteDisable (&mmuGlobalTransTbl);
	mmuTblWriteDisable (transTbl);
	firstTime = FALSE;
	}

    key = intLock ();					/* LOCK INTERRUPTS */

    mmuTTBSet ((PTE *)(((UINT32)transTbl->vUpperTbl
			& SH7700_PHYS_MASK) | mmuTransTblSpace));

    mmuCurrentTransTbl = transTbl;

    intUnlock (key);					/* UNLOCK INTERRUPTS */
    }

/******************************************************************************
*
* mmuTblWriteDisable - write disable memory holding a table's descriptors
*
* Memory containing translation table descriptors is marked as read only
* to protect the descriptors from being corrupted.  This routine write protects
* all the memory used to contain a given translation table's descriptors.
*
* NOTE: This routine is called from mmuCurrentSet() only.
*/

LOCAL void mmuTblWriteDisable
    (
    MMU_TRANS_TBL *transTbl
    )
    {
    int i;

    for (i = 0; i < UPPER_TBL_SIZE; i++)
	{
	UINT32 p_addr = (UINT32)transTbl->vUpperTbl[i].pte.td.adrs;

	if (p_addr != 0xffffffff)
	    mmuStateSet (transTbl, (void *)((p_addr & SH7700_PHYS_MASK)
			 | ((UINT32)transTbl->vUpperTbl & ~SH7700_PHYS_MASK)),
			 MMU_STATE_MASK_WRITABLE | MMU_STATE_MASK_CACHEABLE,
			 MMU_STATE_WRITABLE_NOT  | MMU_STATE_CACHEABLE_NOT);
	}

    mmuStateSet (transTbl, transTbl->vUpperTbl,
		 MMU_STATE_MASK_WRITABLE | MMU_STATE_MASK_CACHEABLE,
		 MMU_STATE_WRITABLE_NOT  | MMU_STATE_CACHEABLE_NOT);
    }

/******************************************************************************
*
* mmuPageAlloc - allocate a page of physical memory
*
*/

LOCAL char *mmuPageAlloc 
    (
    MMU_TRANS_TBL *transTbl
    )
    {
    char *v_page;
    int   i;

    if ((v_page = (char *)lstGet (&transTbl->memFreePageList)) == NULL)
	{
	v_page = memPartAlignedAlloc (mmuPageSource,		/* partId */
				      mmuPageSize * mmuNumPagesInFreeList,
								/* bytes */
				      mmuPageSize);		/* alignment */
	if (v_page == NULL)
	    return NULL;

	if (transTbl->memBlocksUsedIndex >= transTbl->memBlocksUsedSize)
	    {
	    void *newArray;

	    /* realloc the array */

	    transTbl->memBlocksUsedSize *= 2;

	    newArray = realloc (transTbl->memBlocksUsedArray, 
				sizeof(void *) * transTbl->memBlocksUsedSize);

	    if (newArray == NULL)
		{
		transTbl->memBlocksUsedSize /= 2;
		return NULL;	
		}

	    transTbl->memBlocksUsedArray = (void **)newArray;
	    }

	transTbl->memBlocksUsedArray [transTbl->memBlocksUsedIndex++] = 
	      (void *)v_page; 

	for (i = 0; i < mmuNumPagesInFreeList; i++, v_page += mmuPageSize)
	    lstAdd (&transTbl->memFreePageList, (NODE *)v_page);

	v_page = (char *)lstGet (&transTbl->memFreePageList);
	}

    return v_page;
    }

#undef MMU_DEBUG
#ifdef MMU_DEBUG
/******************************************************************************
*
* mmuTLBDump - dump TLB contents
*
* NOMANUAL
*/

LOCAL int partition (UINT32 a[][2], int l, int r)
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

#include "stdio.h"

LOCAL void mmuTLBDumpOp ()
    {
    UINT32 a[128][2];		/* (32-entry * 4-way) * (v_addr | p_addr) */
    UINT32 ent;
    int i;

    for (ent = 0; ent < 32; ent++)
	{
	int way;

	for (way = 0; way < 4; way++)
	    {
	    UINT32 aa = *(UINT32 *)(0xf2000000 | (ent << 12) | (way << 8));
	    UINT32 da = *(UINT32 *)(0xf3000000 | (ent << 12) | (way << 8));

	    a[ent * 4 + way][0] = (aa & 0xfffe0fff) | (ent << 12);	/* va */
	    a[ent * 4 + way][1] = da;					/* pa */
	    }
	}

    quick_sort (a, 128);

    for (i = 0; i < 128; i++)
	{
	printf ("va: 0x%08x -> pa: 0x%08x  %s %s %s %s %s %s\n",
		a[i][0] & 0xfffff000, a[i][1] & 0xfffffc00,
		a[i][1] & 0x00000100 ? "V+" : "V-",
		a[i][1] & 0x00000020 ? "W+" : "W-",
		a[i][1] & 0x00000008 ? "C+" : "C-",
		a[i][1] & 0x00000004 ? "D+" : "D-",
		a[i][1] & 0x00000002 ? "S+" : "S-",
		a[i][1] & 0x00000010 ? "4k" : "1k");
	}
    }

void mmuTLBDump ()
    {
    UINT32 pfunc = ((UINT32)mmuTLBDumpOp & SH7700_PHYS_MASK) | SH7700_P2_BASE;

    (* (VOIDFUNCPTR)pfunc)();
    }

void mmuTLBFlushTestAll ()
    {
    mmuOn (0);

    mmuTLBFlush (ENTIRE_TLB);

    mmuTLBDump ();

    mmuOn (1);
    }

void mmuTLBFlushTest (int v_addr)
    {
    mmuOn (0);

    mmuTLBFlush (v_addr);

    mmuTLBDump ();

    mmuOn (1);
    }
#endif /* MMU_DEBUG */
